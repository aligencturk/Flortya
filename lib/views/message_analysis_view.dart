import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/message_viewmodel.dart';
import '../widgets/analysis_result_box.dart';
import '../widgets/custom_button.dart';
import '../models/analysis_result_model.dart';


class MessageAnalysisView extends StatefulWidget {
  const MessageAnalysisView({Key? key}) : super(key: key);

  @override
  State<MessageAnalysisView> createState() => _MessageAnalysisViewState();
}

// Sınıf seviyesinde statik değişken tanımlama
// Bu flag tüm uygulamada bir kez mesajların yüklendiğinden emin olmak için kullanılır
// Sonsuz döngüyü engellemek için önemli
class _MessageAnalysisViewState extends State<MessageAnalysisView> {
  static bool _messagesLoaded = false; // Sınıf seviyesinde tanımlandı
  
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showDetailedAnalysis = false;
  File? _selectedImage;
  bool _isImageMode = false;
  bool _isProcessingImage = false;
  String? _extractedText;
  
  @override
  void initState() {
    super.initState();
    
    // Bir kez çağırma garantisi
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Detaylı analiz görünümünü kapat
      setState(() {
        _showDetailedAnalysis = false;
      });
      
      // Eğer daha önce mesajlar yüklenmediyse yükle
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (!_messagesLoaded && authViewModel.user != null) {
        debugPrint('initState - İlk kez mesaj yükleniyor - User ID: ${authViewModel.user!.id}');
        _loadMessages();
        _messagesLoaded = true; // Statik flag'i güncelle
      } else {
        debugPrint('initState - Mesajlar daha önce yüklenmiş, tekrar yükleme atlanıyor');
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Mesaj yükleme - iyileştirildi
  Future<void> _loadMessages() async {
    if (!mounted) return;
    
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    
    // Mesajlar zaten yüklenmişse çık
    if (messageViewModel.messages.isNotEmpty) {
      debugPrint('Mesajlar zaten yüklenmiş (${messageViewModel.messages.length} adet)');
      return;
    }
    
    // Kullanıcı kontrolü
    if (authViewModel.user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesajlarınızı yüklemek için lütfen giriş yapın'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      debugPrint('Tek seferlik yükleme başlıyor...');
      await messageViewModel.loadMessages(authViewModel.user!.id);
      
      if (!mounted) return;
      
      debugPrint('Mesaj yükleme tamamlandı. Mesaj sayısı: ${messageViewModel.messages.length}');
      
      if (messageViewModel.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesajlar yüklenirken hata: ${messageViewModel.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesajlar yüklenirken beklenmeyen hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Resim seçme
  Future<void> _pickImage() async {
    setState(() {
      _isProcessingImage = true;
    });
    
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,  // En yüksek kalitede görüntü almak için
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        setState(() {
          _selectedImage = imageFile;
        });

        // OCR ile metin çıkarma - kullanıcıya gösterilmeyecek, sadece backend'e gönderilecek
        try {
          
          setState(() {
            _extractedText = _extractedText;
            _isProcessingImage = false;
          });
          
          // Kullanıcıya sadece resmin yüklendiği bilgisini ver, içeriği gösterme
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Görsel başarıyla yüklendi. Şimdi açıklama ekleyebilir veya direkt analiz edebilirsiniz.'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } catch (e) {
          setState(() {
            _isProcessingImage = false;
            // OCR başarısız olsa bile resmi kullanabilmek için metni boş ayarla
            _extractedText = "";
          });
          
          // Hata durumunda kullanıcıya bilgi ver
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Görüntü yüklendi ancak metin çıkarılamadı. Yine de analiz için kullanabilirsiniz.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        setState(() {
          _isProcessingImage = false;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Görüntü seçme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Mesajı gönderme ve analiz etme
  void _sendMessage() {
    final viewModel = Provider.of<MessageViewModel>(context, listen: false);
    String messageText = _messageController.text.trim();
    
    if ((messageText.isEmpty && _selectedImage == null) || _isProcessingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text('Lütfen bir mesaj girin veya resim seçin')),
            ],
          ),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    // Önceki analiz sonuçlarını temizle
    viewModel.clearCurrentMessage();
    
    setState(() {
      _isProcessingImage = true;
    });

    String messageContent = '';
    
    if (_selectedImage != null) {
      // Görsel modu için içerik oluştur (OCR çıktısı direkt gönderilecek)
      messageContent = "Görsel Analizi: ";
      
      // OCR metni varsa ekle (kullanıcıya göstermeden AI'a gönder)
      if (_extractedText != null && _extractedText!.isNotEmpty) {
        messageContent += "\n---- OCR Metni ----\n$_extractedText\n---- OCR Metni Sonu ----";
      } else {
        messageContent += "\n(Görüntüden metin çıkarılamadı)";
      }
      
      // Kullanıcı açıklaması varsa ekle
      if (messageText.isNotEmpty) {
        messageContent += "\nKullanıcı Açıklaması: $messageText";
      }
    } else {
      // Sadece metin gönderiliyor
      messageContent = messageText;
    }

    _analyzeMessage(messageContent);
  }

  // Mesajı analiz etme işlemi
  Future<void> _analyzeMessage(String messageContent) async {
    // Boş mesaj kontrolü
    if (messageContent.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir mesaj yazın veya bir görsel seçin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    if (authViewModel.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesaj analizi için giriş yapmanız gerekiyor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isProcessingImage = true;
    });
    
    try {
      // Yeni mesaj oluştur
      final message = await messageViewModel.addMessage(
        messageContent,
        analyze: false, // Önce mesajı ekle, sonra analiz et
      );
      
      if (message == null) {
        throw Exception('Mesaj eklenirken bir hata oluştu');
      }
      
      // Resim varsa yükle
      if (_selectedImage != null) {
        try {
          await messageViewModel.uploadMessageImage(message.id, _selectedImage!);
        } catch (imageError) {
          // Görsel yüklenmese bile analize devam edebiliriz
          debugPrint('Görsel yüklenirken hata: $imageError');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Görsel yüklenemedi, ancak analiz devam edecek: ${imageError.toString().substring(0, min(50, imageError.toString().length))}...'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      // Mesajı analiz et
      try {
        final success = await messageViewModel.analyzeMessage(message.id);
        if (!success) {
          throw Exception(messageViewModel.errorMessage ?? 'Analiz sırasında bir hata oluştu');
        }
        
        // Analiz başarılı olduysa, analiz sonucunu göster
        setState(() {
          _showDetailedAnalysis = true;
        });
        
      } catch (analysisError) {
        throw Exception('Analiz hatası: $analysisError');
      }

      // Mesaj listesini yenile
      if (authViewModel.user != null) {
        await messageViewModel.loadMessages(authViewModel.user!.id);
      }

      // Giriş alanlarını temizle
      setState(() {
        _messageController.clear();
        _selectedImage = null;
        _extractedText = null;
        _isProcessingImage = false;
      });
      
      // Debug amaçlı kontroller
      debugPrint('ViewModel sonrası analiz sonucu: ${messageViewModel.hasAnalysisResult}');
      debugPrint('ViewModel sonrası mesaj: ${messageViewModel.hasCurrentMessage}');
      
      // Ekstra bir yeniden çizim çağrısı ekleyelim
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('HATA - Mesaj analizi sırasında: $e');
      String errorMessage = 'Mesaj analizi sırasında hata oluştu';
      
      // Daha spesifik hata mesajları
      if (e.toString().contains('API anahtarı eksik')) {
        errorMessage = 'API bağlantı sorunu: Yapay zeka servisi bağlantısı kurulamıyor';
      } else if (e.toString().contains('Internet connection')) {
        errorMessage = 'İnternet bağlantı sorunu: Lütfen bağlantınızı kontrol edin';
      } else if (e.toString().contains('timed out')) {
        errorMessage = 'Sunucu yanıt vermiyor: Analiz zaman aşımına uğradı';
      } else if (e.toString().contains('Permission')) {
        errorMessage = 'Dosya erişim hatası: Resim dosyası erişilemez';
      } else {
        // Hata detayı ekle ama çok uzun olmasın
        String shortError = e.toString();
        if (shortError.length > 80) {
          shortError = shortError.substring(0, 80) + '...';
        }
        errorMessage = '$errorMessage: $shortError';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Tekrar Dene',
            textColor: Colors.white,
            onPressed: () {
              if (messageViewModel.currentMessage != null) {
                _analyzeMessage(messageContent);
              }
            },
          ),
        ),
      );
      
      setState(() {
        _isProcessingImage = false;
      });
    }
  }

  // Mod değiştirme
  void _toggleMode() {
    setState(() {
      _isImageMode = !_isImageMode;
      // Eğer resim modu kapatılıyorsa, seçili resmi temizle
      if (!_isImageMode) {
        _selectedImage = null;
        _extractedText = null;
      }
      _messageController.clear();
    });
    
    // Debug log
    debugPrint('Görüntü modu: $_isImageMode');
    
    // Kullanıcıya mod değişikliği bildirimi
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isImageMode 
          ? 'Görsel moduna geçildi. Resim seçebilirsiniz.' 
          : 'Metin moduna geçildi.'),
        duration: const Duration(seconds: 2),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  // Bilgi diyaloğunu gösteren metod
  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Mesaj Analizi Hakkında', style: TextStyle(color: Color(0xFF9D3FFF))),
          content: const SingleChildScrollView(
            child: ListBody(
              children: [
                Text('Bu araç, mesajlarınızı analiz ederek anlam ve duygu değerlendirmesi yapar.'),
                SizedBox(height: 8),
                Text('Nasıl kullanılır:'),
                Text('1. Analiz etmek istediğiniz metni girin veya görsel seçin'),
                Text('2. "Mesajı Analiz Et" butonuna tıklayın'),
                Text('3. Analiz sonuçlarını görüntüleyin ve isterseniz kaydedin'),
                SizedBox(height: 8),
                Text('Not: Analiz işlemi birkaç saniye sürebilir.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Anladım', style: TextStyle(color: Color(0xFF9D3FFF))),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: const Color(0xFF352269),
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
          titleTextStyle: const TextStyle(color: Color(0xFF9D3FFF), fontSize: 18, fontWeight: FontWeight.bold),
        );
      },
    );
  }

  // Analiz sonucunu kaydetme metodu
  void _saveAnalysis(BuildContext context) {
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    if (messageViewModel.currentMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kaydedilecek analiz bulunamadı'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      // Analizi kaydedildi olarak işaretleme işlemi burada yapılacak
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analiz sonuçları başarıyla kaydedildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Analiz kaydedilemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageViewModel = Provider.of<MessageViewModel>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF4A2A80),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const Text(
                    'Mesaj Analizi',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    onPressed: () {
                      _showInfoDialog(context);
                    },
                  ),
                ],
              ),
            ),
            
            // Ana içerik
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF352269),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Analiz için mesaj girişi kartı
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Analiz Edilecek Mesaj',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Mesaj girişi
                          Container(
                            height: 150,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: TextField(
                              controller: _messageController,
                              maxLines: null,
                              expands: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Analiz etmek istediğiniz mesajı girin...',
                                hintStyle: TextStyle(color: Colors.white60),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Görsel seçimi özelliği
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9D3FFF).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.photo_library_outlined,
                                      color: Colors.white.withOpacity(0.9),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Görsel Seçimi',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Switch(
                                      value: _isImageMode,
                                      onChanged: (value) {
                                        setState(() {
                                          _isImageMode = value;
                                          if (!value) {
                                            _selectedImage = null;
                                            _extractedText = null;
                                          }
                                        });
                                      },
                                      activeColor: const Color(0xFF9D3FFF),
                                    ),
                                  ],
                                ),
                                
                                if (_isImageMode) ...[
                                  const SizedBox(height: 8),
                                  if (_selectedImage == null) ...[
                                    GestureDetector(
                                      onTap: _isProcessingImage ? null : _pickImage,
                                      child: Container(
                                        height: 100,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
                                        ),
                                        child: _isProcessingImage
                                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF9D3FFF)))
                                            : Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.add_photo_alternate,
                                                    color: Colors.white.withOpacity(0.7),
                                                    size: 40,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    'Görsel seçmek için tıklayın',
                                                    style: TextStyle(color: Colors.white70),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ] else ...[
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Image.file(
                                            _selectedImage!,
                                            height: 150,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _selectedImage = null;
                                                _extractedText = null;
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF9D3FFF).withOpacity(0.9),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Analiz butonu
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.psychology_outlined),
                              label: Text(
                                messageViewModel.isLoading ? 'Analiz Ediliyor...' : 'Mesajı Analiz Et',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9D3FFF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              onPressed: messageViewModel.isLoading ? null : _sendMessage,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Analiz sonucu veya analiz bekleniyor göstergesi
                    Expanded(
                      child: messageViewModel.isLoading
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D3FFF)),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Mesajınız analiz ediliyor...',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Bu işlem biraz zaman alabilir',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : messageViewModel.currentAnalysisResult != null
                              ? _buildAnalysisResult(context, messageViewModel)
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.message_outlined,
                                        size: 64,
                                        color: const Color(0xFF9D3FFF).withOpacity(0.3),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Henüz analiz yapılmadı',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Mesajınızı girin ve "Analiz Et" butonuna tıklayın',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Analiz sonuçlarını gösteren widget
  Widget _buildAnalysisResult(BuildContext context, MessageViewModel viewModel) {
    final result = viewModel.currentAnalysisResult!;
    
    // aiResponse içinden gerekli değerleri al
    final int overallScore = _getOverallScore(result);
    final Map<String, int> categoryScores = _getCategoryScores(result);
    final String summary = _getSummary(result);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF9D3FFF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
      ),
      child: ListView(
        children: [
          // Başlık
          const Text(
            'Analiz Sonucu',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          
          // Genel Skor
          Row(
            children: [
              const Text(
                'Genel Skor:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getSentimentColor(overallScore),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$overallScore%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          Divider(color: const Color(0xFF9D3FFF).withOpacity(0.3), height: 24),
          
          // Kategori skorları
          ...categoryScores.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${entry.value}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: entry.value / 100,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(_getSentimentColor(entry.value)),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }).toList(),
          
          Divider(color: const Color(0xFF9D3FFF).withOpacity(0.3), height: 24),
          
          // Özet ve tavsiyeler
          const Text(
            'Özet ve Tavsiyeler',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Analizi Kaydet butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text(
                'Bu Analizi Kaydet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D3FFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: () {
                _saveAnalysis(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  // AnalysisResult'dan genel skoru al
  int _getOverallScore(AnalysisResult result) {
    try {
      // aiResponse içerisinden skoru al, yoksa varsayılan değer kullan
      return result.aiResponse['overallScore'] ?? result.severity;
    } catch (e) {
      debugPrint('Genel skor alınamadı: $e');
      return result.severity;
    }
  }

  // AnalysisResult'dan kategori skorlarını al
  Map<String, int> _getCategoryScores(AnalysisResult result) {
    try {
      final Map<String, dynamic> rawScores = result.aiResponse['categoryScores'] ?? {};
      // String ve int'e dönüştür
      return rawScores.map((key, value) => 
          MapEntry(key, value is int ? value : (value is double ? value.round() : 0)));
    } catch (e) {
      debugPrint('Kategori skorları alınamadı: $e');
      // Varsayılan kategoriler
      return {
        'Duygusal İletişim': result.severity,
        'Dil Kullanımı': 50,
        'İlişki Etkisi': 50,
      };
    }
  }

  // AnalysisResult'dan özeti al
  String _getSummary(AnalysisResult result) {
    try {
      return result.aiResponse['summary'] ?? 
             'Bu mesajda ${result.emotion} duygusu ve ${result.tone} tonu tespit edildi. ' +
             'Bu tür mesajlar ilişkiyi ${result.severity < 50 ? 'olumsuz' : 'olumlu'} etkileyebilir.';
    } catch (e) {
      debugPrint('Özet alınamadı: $e');
      return 'Analiz sonucu detayları gösterilemiyor.';
    }
  }

  // Duygu skoruna göre renk belirleme
  Color _getSentimentColor(int score) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFF8BC34A);
    if (score >= 40) return const Color(0xFFFF9800);
    if (score >= 20) return const Color(0xFFFF5722);
    return const Color(0xFFF44336);
  }
} 