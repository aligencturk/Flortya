import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/message_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../services/input_service.dart';  // Türkçe karakter desteği için
import '../services/ocr_service.dart';

// Mesaj tipi enum'u - sınıf dışında tanımlanmalı
enum MessageType { text, image, chatFile, none }

class MessageAnalysisView extends StatefulWidget {
  const MessageAnalysisView({super.key});

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
  bool _isMessageTypeExpanded = true; // Mesaj tipi alanının açık/kapalı olma durumu
  
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
          _isMessageTypeExpanded = false; // Dosya yüklendiğinde paneli kapat
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

  // İzinleri kontrol et ve iste
  Future<bool> _checkAndRequestPermissions() async {
    // Android 13 sonrası için dosya izinlerini kontrol et
    bool hasPermission = false;
    
    try {
      debugPrint('İzinler kontrol ediliyor...');
      
      // İlgili izinleri kontrol et
      final status = await Permission.storage.status;
      final mediaStatus = await Permission.mediaLibrary.status;
      
      debugPrint('Storage izin durumu: $status');
      debugPrint('Media Library izin durumu: $mediaStatus');
      
      // İzin durumlarına göre işlem yap
      if (status.isGranted || mediaStatus.isGranted) {
        hasPermission = true;
      } else {
        // İzinleri iste
        final result = await [
          Permission.storage,
          Permission.mediaLibrary,
        ].request();
        
        // Sonuçları kontrol et
        if (result[Permission.storage]!.isGranted || 
            result[Permission.mediaLibrary]!.isGranted) {
          hasPermission = true;
        }
      }
      
      debugPrint('İzin durumu: $hasPermission');
      return hasPermission;
    } catch (e) {
      debugPrint('İzin kontrolü sırasında hata: $e');
      return false;
    }
  }

  // Sohbet dosyası seçme fonksiyonu - image_picker kullanarak
  Future<void> _pickChatFile() async {
    if (!mounted) return;

    setState(() {
      _isProcessingFile = true;
    });
    
    try {
      // Dosya izinleri kontrolü
      final hasPermission = await _checkAndRequestPermissions();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dosya izinleri verilmedi. Lütfen ayarlardan izin verin.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isProcessingFile = false;
          });
        }
        return;
      }
      
      // ImagePicker ile dosya seçimine izin ver
      // XFile tipinde olduğu için önce normal dosyaya dönüştürmemiz gerekiyor
      try {
        final XFile? pickedFile = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        
        if (pickedFile == null) {
          debugPrint('Dosya seçilmedi');
          if (mounted) {
            setState(() {
              _isProcessingFile = false;
            });
          }
          return;
        }
        
        final String path = pickedFile.path;
        if (path.isEmpty) {
          throw Exception('Geçersiz dosya yolu');
        }
        
        debugPrint('Seçilen dosya: $path');
        
        // Dosya uzantısını kontrol etmeden önce TXT içeriği gösterilecek
        // Uzantı önemli değil, içerik okunabilirse yeterli
        
        // Dosyayı oku
        final file = File(path);
        final exists = await file.exists();
        
        if (!exists) {
          throw Exception('Dosya bulunamadı');
        }
        
        try {
          final String content = await file.readAsString();
          
          if (!mounted) return;
          
          if (content.isEmpty) {
            throw Exception('Dosya boş veya içerik okunamadı');
          }
          
          setState(() {
            _selectedChatFile = file;
            _chatFileContent = content;
            _selectedMessageType = MessageType.chatFile;
            _isProcessingFile = false;
            _isMessageTypeExpanded = false; // Dosya yüklendiğinde paneli kapat
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Dosya başarıyla yüklendi. Şimdi analiz edebilirsiniz.'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } catch (readError) {
          debugPrint('Dosya okuma hatası: $readError');
          if (mounted) {
            setState(() {
              _isProcessingFile = false;
              _selectedChatFile = null;
              _chatFileContent = null;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Dosya okunamadı: ${readError.toString().substring(0, min(50, readError.toString().length))}...'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (pickError) {
        debugPrint('Dosya seçme hatası: $pickError');
        if (mounted) {
          setState(() {
            _isProcessingFile = false;
            _selectedChatFile = null;
            _chatFileContent = null;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dosya seçilemedi: ${pickError.toString().substring(0, min(50, pickError.toString().length))}...'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Genel hata: $e');
      if (mounted) {
        setState(() {
          _isProcessingFile = false;
          _selectedChatFile = null;
          _chatFileContent = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İşlem sırasında bir hata oluştu: ${e.toString().substring(0, min(50, e.toString().length))}...'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Metin sohbet dosyası oluşturma (emülatör için alternatif çözüm)
  void _createChatFileFromText() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController chatTextController = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF352269),
          title: const Text(
            'WhatsApp Sohbet İçeriği Girin', 
            style: TextStyle(color: Colors.white, fontSize: 18)
          ),
          content: Container(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sohbet içeriğini aşağıdaki formatta girin:', 
                    style: TextStyle(color: Colors.white70, fontSize: 14)
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '[16.04.2024 22:14] Ahmet: Merhaba\n[16.04.2024 22:15] Sen: Nasılsın?',
                      style: TextStyle(
                        color: Colors.white60, 
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: chatTextController,
                    maxLines: 10,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Sohbet metnini yapıştırın...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF9D3FFF)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('İptal', style: TextStyle(color: Colors.white70)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D3FFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Ekle'),
              onPressed: () {
                if (chatTextController.text.trim().isNotEmpty) {
                  if (mounted) {
                    setState(() {
                      _chatFileContent = chatTextController.text.trim();
                      _selectedChatFile = null; // Dosya olmadığı için null
                      _selectedMessageType = MessageType.chatFile; // Sohbet modunu aktif et
                      _isMessageTypeExpanded = false; // Metin eklendiğinde paneli kapat
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sohbet içeriği başarıyla eklendi'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lütfen sohbet metni girin'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Mesajı gönderme ve analiz etme güncellendi
  void _sendMessage() async {
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
      _showDetailedAnalysis = false; // Analiz başlangıcında sonuç görünümünü kapat
    });

    String messageContent = '';
    
    if (_selectedMessageType == MessageType.image && _selectedImage != null) {
      // Görsel modu için içerik oluştur
      messageContent = "Görsel Analizi: ";
      
      if (_extractedText != null && _extractedText!.isNotEmpty) {
        final extractedText = _extractedText ?? '';
        messageContent += "\n---- OCR Metni ----\n$extractedText\n---- OCR Metni Sonu ----";
      } else {
        messageContent += "\n(Görüntüden metin çıkarılamadı)";
      }
      
      // Kullanıcı açıklaması varsa ekle
      if (messageText.isNotEmpty) {
        messageContent += "\nKullanıcı Açıklaması: $messageText";
      }
    } else if (_selectedMessageType == MessageType.chatFile && (_chatFileContent != null)) {
      // Sohbet dosyası modu için içerik oluştur
      messageContent = "Sohbet Dosyası Analizi: ";
      
      // Dosya içeriğini ekle
      final chatContent = _chatFileContent ?? '';
      messageContent += "\n---- Sohbet Metni ----\n$chatContent\n---- Sohbet Metni Sonu ----";
      
      // Kullanıcı açıklaması varsa ekle
      if (messageText.isNotEmpty) {
        messageContent += "\nKullanıcı Notu: $messageText";
      }
    } else {
      // Normal metin modu - Kullanıcı sadece metin yazdığında
      messageContent = messageText;
    }

    // Analiz sürecini başlat ve minimum 2 saniyelik yükleme deneyimi sağla
    _analyzeMessage(messageContent);
  }

  // Mesajı analiz etme işlemi
  void _analyzeMessage(String messageContent) async {
    // Boş mesaj kontrolü
    if (messageContent.trim().isEmpty && _selectedImage == null && _selectedChatFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen bir mesaj yazın veya bir görsel veya sohbet dosyası seçin'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    if (authViewModel.user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesaj analizi için giriş yapmanız gerekiyor'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // Analiz sürecinin başladığını göster
    if (mounted) {
      setState(() {
        _isProcessingFile = true;
      });
    }
    
    // Yükleme ekranının minimum süresini belirle (2 saniye)
    final startTime = DateTime.now();
    
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
          final selectedImage = _selectedImage; // Local değişkene kopyala
          if (selectedImage != null) {
            await messageViewModel.uploadMessageImage(message.id, selectedImage);
          }
        } catch (imageError) {
          // Görsel yüklenmese bile analize devam edebiliriz
          debugPrint('Görsel yüklenirken hata: $imageError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Görsel yüklenemedi, ancak analiz devam edecek: ${imageError.toString().substring(0, min(50, imageError.toString().length))}...'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }

      // Mesajı analiz et
      try {
        final success = await messageViewModel.analyzeMessage(message.id);
        if (!success) {
          throw Exception(messageViewModel.errorMessage ?? 'Analiz sırasında bir hata oluştu');
        }
      } catch (analysisError) {
        throw Exception('Analiz hatası: $analysisError');
      }

      // Mesaj listesini yenile
      if (authViewModel.user != null) {
        await messageViewModel.loadMessages(authViewModel.user!.id);
      }

      // En az 2 saniye süren bir yükleme göster
      final endTime = DateTime.now();
      final elapsedMilliseconds = endTime.difference(startTime).inMilliseconds;
      final minimumLoadingTime = 2000; // 2 saniye
      
      if (elapsedMilliseconds < minimumLoadingTime) {
        await Future.delayed(
          Duration(milliseconds: minimumLoadingTime - elapsedMilliseconds)
        );
      }

      // Giriş alanlarını temizle ve sonuç ekranına geç
      if (mounted) {
        setState(() {
          _messageController.clear();
          _selectedImage = null;
          _selectedChatFile = null;
          _extractedText = null;
          _chatFileContent = null;
          _isProcessingFile = false;
          _showDetailedAnalysis = true; // Sonuçları göster
        });
      }
      
      // Debug amaçlı kontroller
      debugPrint('ViewModel sonrası analiz sonucu: ${messageViewModel.hasAnalysisResult}');
      debugPrint('ViewModel sonrası mesaj: ${messageViewModel.hasCurrentMessage}');
      
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
          shortError = '${shortError.substring(0, 80)}...';
        }
        errorMessage = '$errorMessage: $shortError';
      }
      
      // En az 2 saniye süren bir yükleme göster
      final endTime = DateTime.now();
      final elapsedMilliseconds = endTime.difference(startTime).inMilliseconds;
      final minimumLoadingTime = 2000; // 2 saniye
      
      if (elapsedMilliseconds < minimumLoadingTime) {
        await Future.delayed(
          Duration(milliseconds: minimumLoadingTime - elapsedMilliseconds)
        );
      }
      
      if (mounted) {
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
                          
                          const SizedBox(height: 8),
                          
                          // Bilgi ipucu ekle
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9D3FFF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Metin yazarak veya görsel/sohbet dosyası yükleyerek analiz yapabilirsiniz.",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
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
                                
                                // Metin girişinde eğer değer boş değilse ve dosya yüklü değilse
                                // mesaj tipi panelini kapat
                                if (value.trim().isNotEmpty && 
                                    _selectedImage == null && 
                                    _selectedChatFile == null && 
                                    _chatFileContent == null) {
                                  setState(() {
                                    _isMessageTypeExpanded = false;
                                  });
                                } else if (value.trim().isEmpty && 
                                    _selectedImage == null && 
                                    _selectedChatFile == null && 
                                    _chatFileContent == null) {
                                  // Metin boşalırsa ve dosya da yoksa paneli tekrar aç
                                  setState(() {
                                    _isMessageTypeExpanded = true;
                                  });
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
                          
                          // Mesaj Tipi Seçimi - Açılır/Kapanır Panel
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9D3FFF).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Başlık ve açma/kapama ikonu
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isMessageTypeExpanded = !_isMessageTypeExpanded;
                                    });
                                  },
                                  child: Row(
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
                                      const Spacer(),
                                      // Açma/kapama ikonu
                                      Icon(
                                        _isMessageTypeExpanded 
                                            ? Icons.keyboard_arrow_up 
                                            : Icons.keyboard_arrow_down,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Panel içeriği (Açılır/Kapanır)
                                AnimatedCrossFade(
                                  duration: const Duration(milliseconds: 300),
                                  crossFadeState: _isMessageTypeExpanded
                                      ? CrossFadeState.showFirst
                                      : CrossFadeState.showSecond,
                                  firstChild: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 12),
                                      
                                      // Seçenekler satırı - Metin seçeneği kaldırıldı, sadece 2 seçenek var
                                      Row(
                                        children: [
                                          // Görsel seçeneği
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  if (_selectedMessageType == MessageType.image) {
                                                    _selectedMessageType = MessageType.none;
                                                  } else {
                                                    _selectedMessageType = MessageType.image;
                                                    _selectedChatFile = null;
                                                    _chatFileContent = null;
                                                    // Mesaj tipi seçildikten sonra otomatik olarak paneli kapat
                                                    _isMessageTypeExpanded = false;
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
                                                  if (_selectedMessageType == MessageType.chatFile) {
                                                    _selectedMessageType = MessageType.none;
                                                  } else {
                                                    _selectedMessageType = MessageType.chatFile;
                                                    _selectedImage = null;
                                                    _extractedText = null;
                                                    // Mesaj tipi seçildikten sonra otomatik olarak paneli kapat
                                                    _isMessageTypeExpanded = false;
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
                                    ],
                                  ),
                                  secondChild: const SizedBox.shrink(), // Kapalı durumda boş alan
                                ),
                              ],
                            ),
                          ),
                          
                          // Seçilen mesaj tipine göre dosya yükleme alanları
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
                              // Yüklenen görsel bilgi alanı
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Color(0xFF9D3FFF), size: 24),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Görsel yüklendi ve analize hazır',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white70),
                                      onPressed: () {
                                        setState(() {
                                          _selectedImage = null;
                                          _extractedText = null;
                                          // Dosya kaldırıldığında paneli tekrar aç
                                          _isMessageTypeExpanded = true;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                          
                          if (_selectedMessageType == MessageType.chatFile) ...[
                            const SizedBox(height: 16),
                            if (_selectedChatFile == null && _chatFileContent == null) ...[
                              Row(
                                children: [
                                  // Dosya Seçme Butonu
                                  Expanded(
                                    flex: 1,
                                    child: GestureDetector(
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
                                                size: 30,
                                              ),
                                              const SizedBox(height: 8),
                                              const Text(
                                                'Dosya Seç (.txt)',
                                                style: TextStyle(color: Colors.white70),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Metin Giriş Butonu
                                  Expanded(
                                    flex: 1,
                                    child: GestureDetector(
                                      onTap: _isProcessingFile ? null : _createChatFileFromText,
                                      child: Container(
                                        height: 100,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.edit_document,
                                              color: Colors.white.withOpacity(0.7),
                                              size: 30,
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Metin Olarak Gir',
                                              style: TextStyle(color: Colors.white70),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              // Yüklenen sohbet dosyası bilgi alanı
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Color(0xFF9D3FFF), size: 24),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Sohbet içeriği yüklendi ve analize hazır',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white70),
                                      onPressed: () {
                                        setState(() {
                                          _selectedChatFile = null;
                                          _chatFileContent = null;
                                          // Dosya kaldırıldığında paneli tekrar aç
                                          _isMessageTypeExpanded = true;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Sohbet önizleme alanı
                              if (_chatFileContent != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  constraints: const BoxConstraints(maxHeight: 100),
                                  child: SingleChildScrollView(
                                    child: Text(
                                      (() {
                                        final content = _chatFileContent;
                                        if (content == null) return '';
                                        return content.length > 500
                                            ? '${content.substring(0, 500)}...'
                                            : content;
                                      })(),
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
                          ],
                          
                          const SizedBox(height: 20),
                          
                          // Analiz Et butonu
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: (_isProcessingFile || !_isAnalyzeButtonEnabled()) 
                                ? null 
                                : _sendMessage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9D3FFF),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _isProcessingFile
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Analiz Yapılıyor...',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'Analiz Et',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          
                          // Analiz et butonu altındaki not
                          if (!_isProcessingFile && !_showDetailedAnalysis)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Metni girin veya dosya yükleyin, ardından analiz için tıklayın',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Analiz sonucu veya analiz bekleniyor göstergesi
                    Expanded(
                      child: messageViewModel.isLoading || _isProcessingFile
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D3FFF)),
                                    strokeWidth: 3.0,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Mesajınız analiz ediliyor...',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Yapay zeka modelimiz mesajınızı inceliyor.\nLütfen bekleyin...',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : messageViewModel.currentAnalysisResult != null && _showDetailedAnalysis
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
    // Null kontrolü ile güvenli erişim sağlayalım
    final analysisResult = viewModel.currentAnalysisResult;
    if (analysisResult == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Analiz sonucu bulunamadı',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    
    // AI yanıtından gerekli değerleri doğrudan al
    final String duygu = analysisResult.emotion;
    final String niyet = analysisResult.intent;
    final String mesajYorumu = analysisResult.aiResponse['mesajYorumu'] ?? 'Yorum bulunamadı';
    final List<String> cevapOnerileri = List<String>.from(analysisResult.aiResponse['cevapOnerileri'] ?? []);
    
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
                    children: [...cevapOnerileri.map((oneri) => _buildSuggestionItem(oneri))],
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

  // Bilgi diyaloğunu göster
  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF352269),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mesaj Analizi Hakkında',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: Colors.white.withOpacity(0.2), thickness: 1),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bilgi başlığı
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9D3FFF).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lightbulb_outline,
                        color: Colors.white.withOpacity(0.9),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Nasıl Kullanılır?',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Kullanım adımları listesi
                _buildInfoStep(1, 'Metin girin, görsel veya sohbet dosyası yükleyin'),
                _buildInfoStep(2, '"Analiz Et" butonuna tıklayın'),
                _buildInfoStep(3, 'İlişkinizle ilgili analizleri ve önerileri görün'),
                
                const SizedBox(height: 16),
                
                // Yeni analiz yöntemi bilgisi
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D3FFF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.new_releases_outlined,
                            color: Colors.white.withOpacity(0.9),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Yeni Özellik',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Artık dosya yüklemeden doğrudan metin girerek de analiz yapabilirsiniz! Partnerinizle yaşadığınız durumu veya düşüncelerinizi yazın, "Analiz Et" butonuna tıklayın.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Uyarı metni
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber.withOpacity(0.9),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Önemli Bilgi',
                            style: TextStyle(
                              color: Colors.amber.withOpacity(0.9),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bu analiz sonuçları yol gösterici niteliktedir ve profesyonel psikolojik danışmanlık yerine geçmez. Ciddi ilişki sorunları için lütfen bir uzmana başvurun.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }
  
  // Bilgi adımı için helper widget
  Widget _buildInfoStep(int stepNumber, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF9D3FFF).withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Analiz butonunun aktif olup olmadığını kontrol eden yardımcı fonksiyon
  bool _isAnalyzeButtonEnabled() {
    // İşlem sürüyorsa buton pasif olmalı
    if (_isProcessingFile) {
      return false;
    }
    
    // Sadece metin girişi yeterli - Diğer modlarda dosya yüklenmiş olmalı
    if (_messageController.text.trim().isNotEmpty) {
      return true;
    }
    
    // Seçili mesaj tipine göre içerik kontrolü yap
    switch (_selectedMessageType) {
      case MessageType.text:
        // Metin modu için: metin boş olmamalı
        return _messageController.text.trim().isNotEmpty;
      case MessageType.image:
        // Görsel modu için: görsel seçilmiş olmalı
        return _selectedImage != null;
      case MessageType.chatFile:
        // Sohbet dosyası modu için: ya dosya seçilmiş ve içeriği yüklenmiş olmalı
        // ya da chatFileContent doğrudan manuel olarak girilmiş olmalı
        return (_selectedChatFile != null || _chatFileContent != null);
      case MessageType.none:
      default:
        // Hiçbir mod seçilmemişse: sadece metin varsa aktif olsun
        return _messageController.text.trim().isNotEmpty;
    }
  }
} 