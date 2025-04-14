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
import '../services/ocr_service.dart';
import '../models/message.dart';
import '../widgets/chat_bubble.dart';
import '../models/analysis_result_model.dart';
import '../constants/colors.dart';
import '../constants/text_styles.dart';
import '../models/text_recognition_script.dart' as local;

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
  final OcrService _ocrService = OcrService();
  String? _extractedText;
  
  // Artık dil seçimi kaldırıldı - Sadece Latin/Türkçe destekleniyor
  local.TextRecognitionScript _selectedScript = local.TextRecognitionScript.latin;

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
    _ocrService.dispose();
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
          String extractedText = await _ocrService.metniOku(imageFile);
          
          setState(() {
            _extractedText = extractedText;
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

  @override
  Widget build(BuildContext context) {
    final messageViewModel = Provider.of<MessageViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);
    final theme = Theme.of(context);
    
    // Build metodu için debug bilgisi - rebuild tespiti için önemli
    // debugPrint('MessageAnalysisView - build çağrıldı');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesaj Analizi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Metin/Görsel modu geçiş butonu
          IconButton(
            icon: Icon(_isImageMode ? Icons.text_fields : Icons.image),
            onPressed: _toggleMode,
            tooltip: _isImageMode ? 'Metin Moduna Geç' : 'Görsel Moduna Geç',
          ),
        ],
      ),
      backgroundColor: messageViewModel.hasCurrentMessage ? theme.colorScheme.primary : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Analiz sonucu gösterimi veya giriş formu
            if (messageViewModel.hasCurrentMessage && messageViewModel.hasAnalysisResult)
              // Analiz Sonucu Gösterimi
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: Colors.white,
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView(
                          child: _buildAnalysisResult(),
                        ),
                      ),
                    ),
                    // Geçmiş Analizlere Dön Butonu
                    InkWell(
                      onTap: () {
                        messageViewModel.clearCurrentMessage();
                        setState(() {
                          _showDetailedAnalysis = false;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Geçmiş Analizlere Dön',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              // Yeni Form ve Liste Görünümü - Tab bazlı
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      // Tab Bar
                      Container(
                        color: theme.colorScheme.primary,
                        child: TabBar(
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.create),
                              text: 'Yeni Analiz',
                            ),
                            Tab(
                              icon: Icon(Icons.history),
                              text: 'Geçmiş',
                            ),
                          ],
                          indicatorColor: Colors.white,
                          labelColor: Colors.white,
                        ),
                      ),
                      
                      // Tab İçerikleri
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Yeni Analiz Formu
                            Container(
                              padding: const EdgeInsets.all(16.0),
                              color: Colors.white,
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Partnerden gelen mesaj bilgisi
                                    Text(
                                      'Partnerinizden gelen mesajı aşağıya girin ve analiz edin.',
                                      style: Theme.of(context).textTheme.bodyLarge,
                                      textAlign: TextAlign.center,
                                    ),
                                    
                                    const SizedBox(height: 24),
                                    
                                    // Eğer görsel modundaysa resim yükleme butonu göster
                                    if (_isImageMode) ...[
                                      // Kullanıcı yönlendirme metni
                                      Text(
                                        'Analiz etmek istediğiniz görüntüyü yükleyin:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 12),
                                      
                                      // Resim seçme butonu - Daha belirgin
                                      Container(
                                        width: double.infinity,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                        ),
                                        child: InkWell(
                                          onTap: _isProcessingImage ? null : _pickImage,
                                          borderRadius: BorderRadius.circular(12),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.photo_library,
                                                size: 36,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                _isProcessingImage ? 'İşleniyor...' : 'Resim Seçmek İçin Tıklayın',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      
                                      // Seçilmiş resmi göster
                                      if (_selectedImage != null) ...[
                                        const SizedBox(height: 16),
                                        Container(
                                          constraints: const BoxConstraints(
                                            minHeight: 200,
                                            maxHeight: 400,
                                          ),
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.file(
                                              _selectedImage!,
                                              width: double.infinity,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      
                                      const SizedBox(height: 24),
                                    ],
                                    
                                    // Mesaj/Açıklama Girişi - her modda göster
                                    if (_isImageMode) ...[
                                      // Görsel modu için bilgi metni
                                      Text(
                                        _selectedImage != null
                                          ? 'Görsel hakkında açıklama ekleyin:'
                                          : 'Resim seçtikten sonra açıklama ekleyebilirsiniz:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    
                                    TextField(
                                      controller: _messageController,
                                      maxLines: 4,
                                      decoration: InputDecoration(
                                        hintText: _isImageMode 
                                            ? 'Resim ile ilgili ek bilgi yazabilirsiniz...' 
                                            : 'Mesajı buraya yazın...',
                                        prefixIcon: const Icon(Icons.message),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                        ),
                                        filled: true,
                                        fillColor: theme.colorScheme.surface,
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 24),
                                    
                                    // Analiz Butonu
                                    CustomButton(
                                      text: 'Mesajı Analiz Et',
                                      onPressed: _isProcessingImage ? () {} : _sendMessage,
                                      icon: Icons.psychology,
                                      isLoading: messageViewModel.isLoading || _isProcessingImage,
                                      isFullWidth: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Geçmiş Analizler Listesi
                            Container(
                              padding: const EdgeInsets.all(16.0),
                              color: Colors.white,
                              child: messageViewModel.isLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : _buildHistoryList(),
                            ),
                          ],
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
  Widget _buildAnalysisResult() {
    final messageViewModel = Provider.of<MessageViewModel>(context);
    
    if (messageViewModel.isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Mesaj analiz ediliyor...')
            ],
          ),
        ),
      );
    }
    
    if (messageViewModel.hasAnalysisResult && messageViewModel.currentAnalysisResult != null) {
      // Mesaj içeriğini sadeleştir
      String displayMessage = messageViewModel.currentMessage?.content ?? '';
      
      // Eğer "Görsel Analizi:" ile başlıyorsa, sadece "Kullanıcı Açıklaması:" kısmını göster
      if (displayMessage.startsWith('Görsel Analizi:')) {
        // Kullanıcı Açıklaması bölümünü bul
        final userCommentIndex = displayMessage.indexOf('Kullanıcı Açıklaması:');
        if (userCommentIndex >= 0) {
          // Kullanıcı Açıklaması: kısmını al
          displayMessage = displayMessage.substring(userCommentIndex + 'Kullanıcı Açıklaması:'.length).trim();
        } else {
          // Kullanıcı açıklaması yoksa sadece görsel bilgisini göster
          displayMessage = "[Görsel analizi]";
        }
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analiz Sonucu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Mesaj İçeriği - Sadeleştirilmiş
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mesaj:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(displayMessage),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Analiz Sonucu Kutusu
          AnalysisResultBox(
            result: messageViewModel.currentAnalysisResult!,
            showDetailedInfo: _showDetailedAnalysis,
            onTap: () {
              setState(() {
                _showDetailedAnalysis = !_showDetailedAnalysis;
              });
            },
          ),
        ],
      ).animate().fadeIn(duration: 400.ms);
    } else if (messageViewModel.errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                messageViewModel.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox(); // Boş durum
  }
  
  // Geçmiş analizler listesi
  Widget _buildHistoryList() {
    final messageViewModel = Provider.of<MessageViewModel>(context);
    
    if (messageViewModel.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz analiz yapılmamış',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Analiz için bir mesaj girin veya görsel yükleyin',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: messageViewModel.messages.length,
      itemBuilder: (context, index) {
        final message = messageViewModel.messages[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              message.content.length > 30 
                  ? '${message.content.substring(0, 30)}...' 
                  : message.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(message.sentAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            trailing: message.isAnalyzed
              ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
              : Icon(Icons.circle_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
            onTap: () async {
              // Mesaj kimliğini kontrol et ve log al
              print('Tıklanan mesaj ID: "${message.id}"');
              print('Mesaj içeriği: ${message.content}');
              print('Analiz edilmiş mi? ${message.isAnalyzed}');
              
              // ID'nin geçerli olup olmadığını kontrol et
              if (message.id.isEmpty || message.id == 'null' || message.id == 'undefined') {
                print('HATA: Geçersiz mesaj ID: "${message.id}"');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Geçersiz mesaj ID. Bu mesaj işlenemiyor.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              try {
                if (message.isAnalyzed) {
                  // Eğer mesaj zaten analiz edildiyse, sonucu göster
                  final result = await messageViewModel.getAnalysisResult(message.id);
                  if (result != null) {
                    // Analiz sonucu görüntüleme sayfasına git
                    setState(() {
                      _showDetailedAnalysis = true;
                    });
                  } else {
                    print('HATA: Analiz sonucu bulunamadı, ID: ${message.id}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Analiz sonucu yüklenirken bir hata oluştu.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  // Eğer mesaj henüz analiz edilmediyse, analiz et
                  final success = await messageViewModel.analyzeMessage(message.id);
                  if (success) {
                    // Analiz başarılıysa, mesajı güncelle ve sonuçları göster
                    final updatedMessage = await messageViewModel.getMessage(message.id);
                    if (updatedMessage != null) {
                      setState(() {
                        _showDetailedAnalysis = true;
                      });
                    } else {
                      print('HATA: Güncellenmiş mesaj bulunamadı, ID: ${message.id}');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mesaj yüklenirken bir hata oluştu.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } else {
                    print('HATA: Mesaj analizi başarısız, ID: ${message.id}');
                  }
                }
              } catch (e) {
                // Hata yakalama ve logla
                print('HATA: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('İşlem sırasında hata: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ).animate().fadeIn(duration: 300.ms, delay: (50 * index).ms).slideX(begin: 0.2, end: 0);
      },
    );
  }

  // Tarih formatını düzenleme
  String _formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }
} 