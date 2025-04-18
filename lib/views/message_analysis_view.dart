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
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:file_picker/file_picker.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/message_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../widgets/analysis_result_box.dart';
import '../widgets/custom_button.dart';
import '../models/analysis_result_model.dart';
import '../models/user_model.dart';
import '../services/input_service.dart';  // Türkçe karakter desteği için
import '../services/ocr_service.dart';

// Mesaj tipi enum'u - sınıf dışında tanımlanmalı
enum MessageType { text, image, chatFile, none }

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
  final FocusNode _messageFocusNode = FocusNode(); // FocusNode ekledim
  bool _showDetailedAnalysis = false;
  
  // State değişkenleri
  MessageType _selectedMessageType = MessageType.none;
  File? _selectedImage;
  File? _selectedChatFile;
  String? _extractedText;
  String? _chatFileContent;
  bool _isProcessingFile = false;
  
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
      
      // Türkçe karakter girişini aktifleştir
      _messageFocusNode.addListener(_onFocusChange);
      
      // Eğer daha önce mesajlar yüklenmediyse yükle
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final profileViewModel = Provider.of<ProfileViewModel>(context, listen: false);
      
      // Kullanıcı profili yükleniyor
      if (authViewModel.user != null) {
        profileViewModel.loadUserProfile();
      }
      
      if (!_messagesLoaded && authViewModel.user != null) {
        debugPrint('initState - İlk kez mesaj yükleniyor - User ID: ${authViewModel.user!.id}');
        _loadMessages();
        _messagesLoaded = true; // Statik flag'i güncelle
      } else {
        debugPrint('initState - Mesajlar daha önce yüklenmiş, tekrar yükleme atlanıyor');
      }
    });
  }

  // FocusNode değişimini dinleyen metod ekledim
  void _onFocusChange() {
    if (_messageFocusNode.hasFocus) {
      // Sadece autofill işlemini tamamla, fazla müdahale etme
      InputService.activateSystemKeyboard(context);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.removeListener(_onFocusChange);
    _messageFocusNode.dispose();
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
      _isProcessingFile = true;
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
          // OCR servisi oluştur ve metni çıkar
          final ocrService = OCRService();
          final extractedText = await ocrService.extractTextFromImage(imageFile);
          
          if (extractedText != null && extractedText.isNotEmpty) {
            // Mesaj içeriğindeki bölümleri belirle
            final messageParts = await ocrService.identifyMessageParts(extractedText);
            
            // Görüntüden çıkarılan metni kaydet (çıktı için düzenlenmiş)
            String formattedOcrText = "---- Görüntüden çıkarılan metin ----\n";
            
            // Tüm OCR metnini ekle
            formattedOcrText += extractedText;
            
            // Analiz için metin parçalarını ekle (ama yönsüz olarak)
            if (messageParts != null && messageParts.isNotEmpty) {
              formattedOcrText += "\n\n---- Mesaj içeriği ----\n";
              
              // Konuşmacıları yön belirtmeden ekle (sağdaki/soldaki yerine)
              messageParts.forEach((speaker, message) {
                if (speaker != 'general') {
                  formattedOcrText += "Konuşmacı: $speaker\nMesaj: $message\n\n";
                }
              });
              
              // Genel metin varsa ekle
              if (messageParts.containsKey('general')) {
                formattedOcrText += "Genel metin: ${messageParts['general']}\n";
              }
            }
            
            formattedOcrText += "---- Çıkarılan metin sonu ----";
            
            setState(() {
              _extractedText = formattedOcrText;
              _isProcessingFile = false;
            });
            
            // Kaynakları serbest bırak
            ocrService.dispose();
          } else {
            setState(() {
              _isProcessingFile = false;
              // OCR başarısız oldu, boş metin ekle
              _extractedText = "---- Görüntüden metin çıkarılamadı ----";
            });
          }
          
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
            _isProcessingFile = false;
            // OCR başarısız olsa bile resmi kullanabilmek için metni boş ayarla
            _extractedText = "---- OCR hatası: $e ----";
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
          _isProcessingFile = false;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessingFile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Görüntü seçme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Sohbet dosyası seçme fonksiyonu
  Future<void> _pickChatFile() async {
    setState(() {
      _isProcessingFile = true;
    });
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      
      if (result != null) {
        File file = File(result.files.single.path!);
        setState(() {
          _selectedChatFile = file;
        });
        
        // Dosya içeriğini oku
        try {
          final content = await file.readAsString();
          setState(() {
            _chatFileContent = content;
          });
          
          // Kullanıcıya başarı mesajı göster
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Sohbet dosyası başarıyla yüklendi. Şimdi analiz edebilirsiniz.'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } catch (e) {
          setState(() {
            _chatFileContent = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dosya okunamadı: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      
      setState(() {
        _isProcessingFile = false;
      });
    } catch (e) {
      setState(() {
        _isProcessingFile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dosya seçme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Mesajı gönderme ve analiz etme güncellendi
  void _sendMessage() {
    final viewModel = Provider.of<MessageViewModel>(context, listen: false);
    String messageText = _messageController.text.trim();
    
    bool hasContent = messageText.isNotEmpty || 
                     _selectedImage != null || 
                     (_selectedChatFile != null && _chatFileContent != null);
    
    if (!hasContent || _isProcessingFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text('Lütfen bir mesaj girin, görsel veya sohbet dosyası seçin')),
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
      _isProcessingFile = true;
    });

    String messageContent = '';
    
    if (_selectedMessageType == MessageType.image && _selectedImage != null) {
      // Görsel modu için içerik oluştur
      messageContent = "Görsel Analizi: ";
      
      if (_extractedText != null && _extractedText!.isNotEmpty) {
        messageContent += "\n---- OCR Metni ----\n$_extractedText\n---- OCR Metni Sonu ----";
      } else {
        messageContent += "\n(Görüntüden metin çıkarılamadı)";
      }
      
      // Kullanıcı açıklaması varsa ekle
      if (messageText.isNotEmpty) {
        messageContent += "\nKullanıcı Açıklaması: $messageText";
      }
    } else if (_selectedMessageType == MessageType.chatFile && _selectedChatFile != null && _chatFileContent != null) {
      // Sohbet dosyası modu için içerik oluştur
      messageContent = "Sohbet Dosyası Analizi: ";
      
      // Dosya içeriğini ekle
      messageContent += "\n---- Sohbet Metni ----\n$_chatFileContent\n---- Sohbet Metni Sonu ----";
      
      // Kullanıcı açıklaması varsa ekle
      if (messageText.isNotEmpty) {
        messageContent += "\nKullanıcı Notu: $messageText";
      }
    } else {
      // Normal metin modu
      messageContent = messageText;
    }

    _analyzeMessage(messageContent);
  }

  // Mesajı analiz etme işlemi
  Future<void> _analyzeMessage(String messageContent) async {
    // Boş mesaj kontrolü
    if (messageContent.trim().isEmpty && _selectedImage == null && _selectedChatFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir mesaj yazın veya bir görsel veya sohbet dosyası seçin'),
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
      _isProcessingFile = true;
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
        _selectedChatFile = null;
        _extractedText = null;
        _chatFileContent = null;
        _isProcessingFile = false;
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
        _isProcessingFile = false;
      });
    }
  }

  // Temizleme fonksiyonu
  void _resetSelections() {
    setState(() {
      _selectedMessageType = MessageType.none;
      _selectedImage = null;
      _selectedChatFile = null;
      _extractedText = null;
      _chatFileContent = null;
      _messageController.clear();
    });
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
                            child: TextFormField(
                              controller: _messageController,
                              focusNode: _messageFocusNode,
                              maxLines: null,
                              expands: true,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.newline,
                              enableInteractiveSelection: true,
                              onChanged: (value) {
                                // Bu satırı değiştirmeyin - sadece Dart'ın 
                                // Türkçe karakterleri kabul ettiğinden emin oluyoruz
                                final containsTurkish = value.contains(RegExp(r'[ğüşöçıĞÜŞÖÇİ]'));
                                if (containsTurkish) {
                                  debugPrint('Türkçe karakter algılandı: $value');
                                }
                              },
                              decoration: const InputDecoration(
                                hintText: 'Analiz etmek istediğiniz mesajı girin...',
                                hintStyle: TextStyle(color: Colors.white60),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Yasal uyarı notu
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  "ℹ️",
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Not: Uygulamada sunulan içerikler yol gösterici niteliktedir, bağlayıcı değildir.",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Mesaj Tipi Seçimi
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
                                      Icons.category_outlined,
                                      color: Colors.white.withOpacity(0.9),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Mesaj Tipi Seç',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Seçenekler satırı
                                Row(
                                  children: [
                                    // Metin seçeneği
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedMessageType = 
                                              _selectedMessageType == MessageType.text ? 
                                              MessageType.none : MessageType.text;
                                            
                                            if (_selectedMessageType == MessageType.text) {
                                              _selectedImage = null;
                                              _selectedChatFile = null;
                                              _extractedText = null;
                                              _chatFileContent = null;
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: _selectedMessageType == MessageType.text 
                                                ? const Color(0xFF9D3FFF) 
                                                : Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _selectedMessageType == MessageType.text
                                                  ? Colors.white.withOpacity(0.5)
                                                  : Colors.white.withOpacity(0.2),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.text_fields,
                                                color: Colors.white.withOpacity(0.9),
                                                size: 20,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Metin',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.9),
                                                  fontWeight: _selectedMessageType == MessageType.text
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    const SizedBox(width: 8),
                                    
                                    // Görsel seçeneği
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedMessageType = 
                                              _selectedMessageType == MessageType.image ? 
                                              MessageType.none : MessageType.image;
                                            
                                            if (_selectedMessageType == MessageType.image) {
                                              _selectedChatFile = null;
                                              _chatFileContent = null;
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: _selectedMessageType == MessageType.image
                                                ? const Color(0xFF9D3FFF)
                                                : Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _selectedMessageType == MessageType.image
                                                  ? Colors.white.withOpacity(0.5)
                                                  : Colors.white.withOpacity(0.2),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.photo_camera,
                                                color: Colors.white.withOpacity(0.9),
                                                size: 20,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Görsel',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.9),
                                                  fontWeight: _selectedMessageType == MessageType.image
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    const SizedBox(width: 8),
                                    
                                    // Sohbet dosyası seçeneği
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedMessageType = 
                                              _selectedMessageType == MessageType.chatFile ? 
                                              MessageType.none : MessageType.chatFile;
                                            
                                            if (_selectedMessageType == MessageType.chatFile) {
                                              _selectedImage = null;
                                              _extractedText = null;
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: _selectedMessageType == MessageType.chatFile
                                                ? const Color(0xFF9D3FFF)
                                                : Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _selectedMessageType == MessageType.chatFile
                                                  ? Colors.white.withOpacity(0.5)
                                                  : Colors.white.withOpacity(0.2),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.chat_outlined,
                                                color: Colors.white.withOpacity(0.9),
                                                size: 20,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Sohbet',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.9),
                                                  fontWeight: _selectedMessageType == MessageType.chatFile
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                // Görsel seçimi alanı
                                if (_selectedMessageType == MessageType.image) ...[
                                  const SizedBox(height: 16),
                                  if (_selectedImage == null) ...[
                                    GestureDetector(
                                      onTap: _isProcessingFile ? null : _pickImage,
                                      child: Container(
                                        height: 100,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
                                        ),
                                        child: _isProcessingFile
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
                                
                                // Sohbet dosyası seçimi alanı
                                if (_selectedMessageType == MessageType.chatFile) ...[
                                  const SizedBox(height: 16),
                                  if (_selectedChatFile == null) ...[
                                    GestureDetector(
                                      onTap: _isProcessingFile ? null : _pickChatFile,
                                      child: Container(
                                        height: 100,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
                                        ),
                                        child: _isProcessingFile
                                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF9D3FFF)))
                                            : Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.upload_file,
                                                    color: Colors.white.withOpacity(0.7),
                                                    size: 40,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    'Sohbet dosyası (.txt) seçmek için tıklayın',
                                                    style: TextStyle(color: Colors.white70),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ] else ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.insert_drive_file,
                                                color: Colors.white.withOpacity(0.9),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _selectedChatFile!.path.split('/').last,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedChatFile = null;
                                                    _chatFileContent = null;
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF9D3FFF).withOpacity(0.9),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          if (_chatFileContent != null && _chatFileContent!.isNotEmpty) ...[
                                            const Text(
                                              'Önizleme:',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.05),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              height: 80,
                                              child: SingleChildScrollView(
                                                child: Text(
                                                  _chatFileContent!.length > 500
                                                      ? '${_chatFileContent!.substring(0, 500)}...'
                                                      : _chatFileContent!,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
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
                                messageViewModel.isLoading || _isProcessingFile 
                                    ? 'Analiz Ediliyor...' 
                                    : 'Mesajı Analiz Et',
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
                              onPressed: (messageViewModel.isLoading || _isProcessingFile) ? null : _sendMessage,
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
    
    // AI yanıtından gerekli değerleri doğrudan al
    final String duygu = result.emotion;
    final String niyet = result.intent;
    final String mesajYorumu = result.aiResponse['mesajYorumu'] ?? 'Yorum bulunamadı';
    final List<String> cevapOnerileri = List<String>.from(result.aiResponse['cevapOnerileri'] ?? []);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Duygu Çözümlemesi
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  const Row(
                    children: [
                      Icon(Icons.mood, color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Duygu Çözümlemesi',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // İçerik
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      duygu,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Niyet Yorumu
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  const Row(
                    children: [
                      Icon(Icons.psychology, color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Niyet Yorumu',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // İçerik
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      mesajYorumu,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Cevap Önerileri
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Cevap Önerileri',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // İçerik
                  Column(
                    children: [...cevapOnerileri.map((oneri) => _buildSuggestionItem(oneri)).toList()],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Yasal uyarı notu
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Text(
                    "ℹ️",
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Not: Uygulamada sunulan içerikler yol gösterici niteliktedir, bağlayıcı değildir.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
          ],
        ),
      ),
    );
  }
  
  // Öneri öğesi widget'ı
  Widget _buildSuggestionItem(String oneri) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF9D3FFF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.reply,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              oneri,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
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
} 