import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/message.dart';
import '../models/analysis_result_model.dart' as analysis;
import '../models/user_model.dart';
import '../models/analysis_type.dart'; // Analysis tipi için import
import '../services/ai_service.dart';
import '../services/logger_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../controllers/home_controller.dart';
import 'package:provider/provider.dart';
import '../viewmodels/past_analyses_viewmodel.dart';
import 'package:file_selector/file_selector.dart';
import '../services/ocr_service.dart';
import 'dart:math';
import 'package:flutter/material.dart';

// Extension to add firstWhereOrNull functionality
extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class MessageViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AiService _aiService = AiService();
  final LoggerService _logger = LoggerService();
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  ProfileViewModel? _profileViewModel;
  
  // İlk yükleme denemesinin yapılıp yapılmadığını takip eden bayrak (static değil)
  bool _isFirstLoadCompleted = false;
  
  List<Message> _messages = [];
  Message? _currentMessage;
  analysis.AnalysisResult? _currentAnalysisResult;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Message> get messages => _messages;
  Message? get currentMessage => _currentMessage;
  analysis.AnalysisResult? get currentAnalysisResult => _currentAnalysisResult;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasCurrentMessage => _currentMessage != null;
  bool get hasAnalysisResult => _currentAnalysisResult != null;
  bool get isFirstLoadCompleted => _isFirstLoadCompleted;
  
  // Aktif mesajın txt dosyası analizi olup olmadığını kontrol eden getter
  bool get isTxtAnalysis {
    // TEST AMAÇLI - HER DURUMDA BUTONU GÖSTER - KALDIRILDI
    // return true;

    // --> GÜNCELLENECEK KOD BAŞLANGICI
    // _currentMessage null ise veya analysisSource text değilse false döner.
    return _currentMessage?.analysisSource == AnalysisSource.text;
    // <-- GÜNCELLENECEK KOD SONU

    /* Orijinal kod:
    if (_currentMessage == null || _currentMessage!.content.isEmpty) {
      return false;
    }
    
    // TXT dosyası analizi kontrolü
    final String content = _currentMessage!.content.toLowerCase();
    return content.contains('.txt') || 
           content.contains('metin dosyası') || 
           content.contains('txt dosya');
    */
  }

  // Mesajları yükleme işlemi
  Future<void> loadMessages(String userId) async {
    // İlk yükleme denemesi zaten yapıldıysa veya şu anda yükleniyorsa tekrar yükleme atlanıyor.
    if (_isFirstLoadCompleted || _isLoading) {
      _logger.i('İlk yükleme denemesi yapıldı veya zaten yükleniyor, tekrar yükleme atlanıyor.');
      return;
    }
    
    // Yükleme denemesini başlatıldı olarak işaretle
    _isFirstLoadCompleted = true; 
    _isLoading = true;
    _errorMessage = null;
    // Yükleme başladığında UI'ı hemen güncelle
    notifyListeners(); 
    
    try {
      _logger.i('Mesajlar yükleniyor. Kullanıcı ID: $userId');
      
      if (userId.isEmpty) {
        _errorMessage = 'Oturumunuz bulunamadı. Lütfen tekrar giriş yapın.';
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      // Tüm mesajları boşalt
      _messages.clear();
      
      final CollectionReference messagesRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('messages');
      
      // Mesajları Firebase'den yükle
      try {
        // Önce timestamp ile sıralama dene
        _logger.i('timestamp ile mesajlar yükleniyor');
        
        QuerySnapshot? snapshot;
        
        try {
          snapshot = await messagesRef
              .orderBy('timestamp', descending: true)
              .get();
        } catch (e) {
          _logger.w('timestamp ile sıralama başarısız oldu: $e');
          snapshot = null;
        }
        
        // Timestamp başarısız olursa createdAt dene
        if (snapshot == null || snapshot.docs.isEmpty) {
          try {
            _logger.i('createdAt ile mesajlar yükleniyor');
            snapshot = await messagesRef
                .orderBy('createdAt', descending: true)
                .get();
          } catch (e) {
            _logger.w('createdAt ile sıralama başarısız oldu: $e');
            snapshot = null;
          }
        }
        
        // Hala başarısız ise sentAt dene
        if (snapshot == null || snapshot.docs.isEmpty) {
          try {
            _logger.i('sentAt ile mesajlar yükleniyor');
            snapshot = await messagesRef
                .orderBy('sentAt', descending: true)
                .get();
          } catch (e) {
            _logger.w('sentAt ile sıralama başarısız oldu: $e');
            // Sıralama olmadan direkt alma
            _logger.i('Sıralama olmadan mesajlar alınıyor');
            snapshot = await messagesRef.get();
          }
        }
        
        // Mesajları işle
        if (snapshot.docs.isNotEmpty) {
          _logger.i('Mesajlar koleksiyonunda ${snapshot.docs.length} mesaj bulundu');
          List<Message> newMessages = snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id; // ID ekleniyor
            return Message.fromMap(data, docId: doc.id);
          }).toList();
          
          _messages = newMessages;
        } else {
          _logger.i('Kullanıcı için mesaj bulunamadı: $userId');
        }
      } catch (e) {
        _logger.e('Mesaj yükleme hatası', e);
      }
      
      // Log
      _logger.i('Mesaj yükleme tamamlandı. Toplam: ${_messages.length} mesaj');
      
    } catch (e) {
      _logger.e('Mesajlar yüklenirken bir hata oluştu', e);
      _errorMessage = 'Mesajlar yüklenirken bir hata oluştu: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Yeni mesaj ekleme
  Future<Message?> addMessage(String content, {String? imageUrl, String? imagePath, bool analyze = false}) async {
    try {
      _logger.i('Mesaj ekleniyor: $content');
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      // Kullanıcı kimliğini kontrol et
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        _logger.e('Mesaj eklenemedi: Kullanıcı oturumu bulunamadı');
        _errorMessage = 'Mesaj gönderilemedi: Lütfen tekrar giriş yapın';
        _isLoading = false;
        notifyListeners();
        return null;
      }
      
      _logger.i('Kullanıcı kimliği: $userId');
      
      // Kullanıcı belgesini kontrol et ve gerekirse oluştur
      final userDocRef = _firestore.collection('users').doc(userId);
      final userDoc = await userDocRef.get();
      
      if (!userDoc.exists) {
        _logger.i('Kullanıcı belgesi bulunamadı, yeni oluşturuluyor: $userId');
        // Kullanıcı bilgilerini al
        final user = _authService.currentUser!;
        
        // Kullanıcı belgesini oluştur
        await userDocRef.set({
          'uid': userId,
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'createdAt': Timestamp.now(),
          'lastActive': Timestamp.now(),
          'messageCount': 0,
        });
        
        _logger.i('Kullanıcı belgesi başarıyla oluşturuldu');
      } else {
        _logger.i('Mevcut kullanıcı belgesi bulundu: $userId');
        // Kullanıcı son aktif zamanını güncelle
        await userDocRef.update({
          'lastActive': Timestamp.now(),
        });
      }
      
      // Mesaj belgesini oluştur
      final timestamp = Timestamp.now();
      final messageData = {
        'content': content,
        'imageUrl': imageUrl ?? '',
        'imagePath': imagePath ?? '',
        'timestamp': timestamp,
        'userId': userId,
        'isAnalyzed': false,
        'isAnalyzing': false,
        'createdAt': timestamp,
        'updatedAt': timestamp,
      };
      
      // Kullanıcının mesajlar koleksiyonuna ekle
      final messagesCollectionRef = userDocRef.collection('messages');
      final docRef = await messagesCollectionRef.add(messageData);
      
      _logger.i('Mesaj Firestore\'a kaydedildi: ${docRef.id}');
      
      // Kullanıcının mesaj sayısını artır
      await userDocRef.update({
        'messageCount': FieldValue.increment(1),
      });
      
      // Yeni oluşturulan mesajı al
      final message = Message.fromMap(messageData, docId: docRef.id);
      
      // Mesajı yerel listeye ekle
      _messages.add(message);
      _currentMessage = message;
      
      _isLoading = false;
      notifyListeners();
      
      _logger.i('Mesaj başarıyla eklendi, Mesaj ID: ${message.id}');
      
      // İstenirse mesajı analize gönder
      if (analyze) {
        _logger.i('Mesaj analiz için gönderiliyor');
        analyzeMessage(message.id);
      }
      
      return message;
    } catch (e, stackTrace) {
      _logger.e('Mesaj eklenirken hata oluştu', e, stackTrace);
      _errorMessage = 'Mesaj eklenirken bir hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Belirli bir mesajı alma
  Future<Message?> getMessage(String messageId) async {
    if (messageId.isEmpty) {
      _logger.e('getMessage - Boş messageId ile çağrıldı');
      _setError('Geçersiz mesaj ID');
      return null;
    }
    
    try {
      // Önce yerel listede ara
      final index = _messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        _currentMessage = _messages[index];
        return _messages[index];
      }
      
      // Yerel listede bulunamazsa Firestore'dan çek
      _logger.i('Mesaj yerel listede bulunamadı. Firestore\'dan çekiliyor. ID: $messageId');
      
      // Kullanıcı ID'si gerekli
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        _setError('Oturumunuz bulunamadı');
        return null;
      }
      
      // Mesaj belgesini al
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('messages')
          .doc(messageId)
          .get();
      
      if (doc.exists) {
        // Doküman verilerini al ve ID değerini ekleyerek mesaj oluştur
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        // Document ID'yi map'e ekle
        data['id'] = doc.id;
        
        _currentMessage = Message.fromMap(data, docId: messageId);
        notifyListeners();
        return _currentMessage;
      } else {
        _logger.e('$messageId ID\'li mesaj Firestore\'da bulunamadı');
        _setError('Mesaj bulunamadı');
        return null;
      }
    } catch (e) {
      _logger.e('Mesaj alınırken hata oluştu', e);
      _setError('Mesaj alınırken hata oluştu: $e');
      return null;
    }
  }

  // Yeni bir analiz başlatırken önceki analiz sonuçlarını temizleme
  void _startNewAnalysis() {
    _currentMessage = null;
    _currentAnalysisResult = null;
    notifyListeners();
  }

  // Mesajı analiz et
  Future<bool> analyzeMessage(String messageId) async {
    try {
      _logger.i('Mesaj analizi başlatılıyor: $messageId');
      
      // Kullanıcı kimliğini kontrol et
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        _logger.e('Mesaj analiz edilemedi: Kullanıcı oturumu bulunamadı');
        _errorMessage = 'Analiz yapılamadı: Lütfen tekrar giriş yapın';
        notifyListeners();
        return false;
      }
      
      // Mesaj ID'sini doğrula
      if (messageId.isEmpty) {
        _logger.e('Geçersiz mesaj ID: boş');
        _errorMessage = 'Analiz yapılamadı: Geçersiz mesaj';
        notifyListeners();
        return false;
      }
      
      _logger.i('Mesaj analizi için kullanıcı: $userId, mesaj ID: $messageId');
      
      // Önce yerel listede mesajı ara
      Message? message = _messages.firstWhereOrNull((m) => m.id == messageId);
      
      // Yerel listede bulunamadıysa Firestore'dan al
      if (message == null) {
        _logger.i('Mesaj yerel listede bulunamadı, Firestore\'dan alınıyor');
        
        // Önce users koleksiyonunu kontrol et
        final userDocRef = _firestore.collection('users').doc(userId);
        final userDoc = await userDocRef.get();
        
        if (!userDoc.exists) {
          _logger.e('Kullanıcı belgesi bulunamadı: $userId');
          _errorMessage = 'Analiz yapılamadı: Kullanıcı verisi bulunamadı';
          notifyListeners();
          return false;
        }
        
        // Mesaj belgesini al
        final messageDocRef = userDocRef.collection('messages').doc(messageId);
        final messageDoc = await messageDocRef.get();
        
        if (!messageDoc.exists) {
          _logger.e('Mesaj belgesi bulunamadı: $messageId');
          _errorMessage = 'Analiz yapılamadı: Mesaj bulunamadı';
          notifyListeners();
          return false;
        }
        
        // Mesajı oluştur
        final messageData = messageDoc.data() as Map<String, dynamic>;
        message = Message.fromMap(messageData, docId: messageId);
        _messages.add(message); // Yerel listeye ekle
      }
      
      // Analiz durumunu güncelle
      _logger.i('Mesaj analiz durumu güncelleniyor: $messageId');
      
      // Firestore'daki durumu güncelle
      final messageRef = _firestore.collection('users').doc(userId).collection('messages').doc(messageId);
      await messageRef.update({
        'isAnalyzing': true,
        'updatedAt': Timestamp.now(),
      });
      
      // Yerel listedeki mesajı güncelle
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(isAnalyzing: true);
        _currentMessage = _messages[index];
        notifyListeners();
      }
      
      // Mesaj içeriğini hazırla
      final content = message.content.trim();
      if (content.isEmpty) {
        _logger.e('Mesaj içeriği boş, analiz edilemez');
        await messageRef.update({
          'isAnalyzing': false,
          'isAnalyzed': true,
          'errorMessage': 'Mesaj içeriği boş',
          'updatedAt': Timestamp.now(),
        });
        
        // Yerel listeyi güncelle
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            isAnalyzing: false, 
            isAnalyzed: true,
            errorMessage: 'Mesaj içeriği boş',
          );
          _currentMessage = _messages[index];
          notifyListeners();
        }
        
        _errorMessage = 'Analiz yapılamadı: Mesaj içeriği boş';
        notifyListeners();
        return false;
      }
      
      // API'ye gönder ve sonucu al
      _logger.i('AI servisine analiz isteği gönderiliyor');
      final analysisResult = await _aiService.analyzeMessage(content);
      
      // Sonucu kontrol et
      if (analysisResult == null) {
        _logger.e('AI servisinden analiz sonucu alınamadı');
        
        // Firestore belgesini güncelle
        await messageRef.update({
          'isAnalyzing': false,
          'isAnalyzed': true,
          'errorMessage': 'AI servisi yanıt vermedi',
          'updatedAt': Timestamp.now(),
        });
        
        // Yerel listeyi güncelle
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            isAnalyzing: false, 
            isAnalyzed: true,
            errorMessage: 'AI servisi yanıt vermedi',
          );
          _currentMessage = _messages[index];
        }
        
        _errorMessage = 'Analiz yapılamadı: AI servisi yanıt vermedi';
        notifyListeners();
        return false;
      }
      
      _logger.i('Analiz sonucu alındı, Firestore güncelleniyor');
      
      // Sonucu Firestore'a kaydet
      await messageRef.update({
        'isAnalyzing': false,
        'isAnalyzed': true,
        'analysisResult': analysisResult.toMap(),
        'errorMessage': null,
        'updatedAt': Timestamp.now(),
        'isSaved': true, // Analiz otomatik kaydedildi olarak işaretlenir
      });
      
      // Yerel listedeki mesajı güncelle
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isAnalyzing: false,
          isAnalyzed: true,
          analysisResult: analysisResult,
          errorMessage: null,
          analysisSource: AnalysisSource.image, // Analiz kaynağını ayarla
        );
        _currentMessage = _messages[index];
        // Geçerli analiz sonucunu da güncelle
        _currentAnalysisResult = analysisResult;
      }
      
      // Analiz sonucunu kullanıcı profiline de kaydet
      await _updateUserProfileWithAnalysis(userId, analysisResult);
      
      _logger.i('Mesaj analizi tamamlandı ve kullanıcı profiline kaydedildi: $messageId');
      notifyListeners();
      
      return true;
    } catch (e, stackTrace) {
      _logger.e('Mesaj analizi sırasında hata oluştu', e, stackTrace);
      
      // Hata durumunda Firestore'u güncellemeye çalış
      try {
        final userId = _authService.currentUser?.uid;
        if (userId != null && messageId.isNotEmpty) {
          final messageRef = _firestore.collection('users').doc(userId).collection('messages').doc(messageId);
          await messageRef.update({
            'isAnalyzing': false,
            'isAnalyzed': true,
            'errorMessage': e.toString(),
            'updatedAt': Timestamp.now(),
          });
        }
      } catch (updateError) {
        _logger.e('Hata sonrası Firestore güncellemesi başarısız oldu', updateError);
      }
      
      // Yerel listeyi güncelle
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isAnalyzing: false,
          isAnalyzed: true,
          errorMessage: e.toString(),
        );
        _currentMessage = _messages[index];
      }
      
      _errorMessage = 'Mesaj analizi sırasında hata oluştu: $e';
      notifyListeners();
      return false;
    }
  }

  // Analiz sonucunu kullanıcı profiline kaydetme
  Future<void> _updateUserProfileWithAnalysis(String userId, analysis.AnalysisResult analysisResult) async {
    try {
      _logger.i('Analiz sonucu kullanıcı profiline kaydediliyor: $userId');
      
      // İlişki puanı ve kategori puanlarını hesapla
      final Map<String, dynamic> analizVerileri = {
        'mesajIcerigi': _currentMessage?.content ?? '',
        'duygu': analysisResult.emotion,
        'niyet': analysisResult.intent,
        'ton': analysisResult.tone,
        'mesajYorumu': analysisResult.aiResponse['mesajYorumu'] ?? '',
      };
      
      // Kullanıcı profilini çek
      DocumentReference userRef = _firestore.collection('users').doc(userId);
      DocumentSnapshot<Map<String, dynamic>> userDoc = await userRef.get() as DocumentSnapshot<Map<String, dynamic>>;
      
      // Kullanıcı modeli yoksa oluştur
      if (!userDoc.exists) {
        _logger.w('Kullanıcı belgesi bulunamadı, analiz kaydedilemedi: $userId');
        return;
      }
      
      // Kullanıcı modelini oluştur
      UserModel userModel = UserModel.fromFirestore(userDoc);
      
      // Analiz hizmeti ile ilişki durumunu analiz et
      final analizSonucuMap = await _aiService.iliskiDurumuAnaliziYap(userId, analizVerileri);
      
      // Map'i AnalizSonucu nesnesine dönüştür
      final AnalizSonucu analizSonucu = AnalizSonucu.fromMap(analizSonucuMap);
      
      // Kullanıcı modelini güncelle
      final UserModel guncelKullanici = userModel.analizSonucuEkle(analizSonucu);
      
      // Firestore'a kaydet
      await userRef.update({
        'sonAnalizSonucu': analizSonucu.toMap(),
        'analizGecmisi': FieldValue.arrayUnion([analizSonucu.toMap()]),
      });
      
      _logger.i('Kullanıcı profili başarıyla güncellendi. İlişki puanı: ${analizSonucu.iliskiPuani}');
      
      // Ana sayfayı güncelle - HomeController ile güvenli bir şekilde
      try {
        // Null-aware operatör kullanarak context değerine erişiyoruz
        final context = _profileViewModel?.context;
        if (context != null && context.mounted) {
          try {
            final homeController = Provider.of<HomeController>(context, listen: false);
            await homeController.anaSayfayiGuncelle(); // HomeController'ın mevcut metodunu kullan
            _logger.i('Ana sayfa yeni analiz sonucuyla güncellendi');
          } catch (e) {
            _logger.w('HomeController ile güncelleme hatası: $e');
          }
        } else {
          _logger.w('Context null veya artık geçerli değil');
        }
      } catch (e) {
        _logger.w('Ana sayfa güncellenirken hata oluştu: $e');
      }
    } catch (e) {
      _logger.w('Analiz sonucu kullanıcı profiline kaydedilirken hata oluştu', e);
    }
  }

  // Mesaj görselini yükleme
  Future<void> uploadMessageImage(String messageId, File imageFile) async {
    // ID boş kontrolü ekle
    if (messageId.isEmpty) {
      _errorMessage = 'Görsel yükleme için geçersiz mesaj ID';
      return;
    }
    
    // Kullanıcı ID'si gerekli
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      _errorMessage = 'Oturumunuz bulunamadı';
      return;
    }
    
    try {
      _isLoading = true;
      notifyListeners();
      
      _logger.i('Mesaj görseli yükleniyor. ID: $messageId');
      
      // Storage referansı oluştur
      final storageRef = _storage.ref().child('message_images/$userId/$messageId.jpg');
      
      // Görseli yükle
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() => null);
      
      // İndirme URL'sini al
      final imageUrl = await snapshot.ref.getDownloadURL();
      
      // Firestore'da mesajı güncelle - Koleksiyon yolu düzeltildi
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('messages')
          .doc(messageId)
          .update({
        'imageUrl': imageUrl,
      });
      
      // Yerel mesajı güncelle
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(imageUrl: imageUrl);
        
        if (_currentMessage?.id == messageId) {
          _currentMessage = _currentMessage!.copyWith(imageUrl: imageUrl);
        }
      }
      
      _logger.i('Mesaj görseli başarıyla yüklendi. ID: $messageId');
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Görsel yüklenirken hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Resim mesajını analiz etme
  Future<bool> analyzeImageMessage(File imageFile, {String receiverId = '', String messageType = 'image', String? replyMessageId, String? otherUserId}) async {
    try {
      _logger.i('Görsel analizi başlatılıyor...');
      _isLoading = true;
      _errorMessage = null;
      _currentAnalysisResult = null; // Eski analiz sonucunu temizle
      notifyListeners();
      
      // Kullanıcı kimlik kontrolü
      final String? userId = _authService.currentUser?.uid;
      if (userId == null) {
        _logger.e('Kullanıcı giriş yapmamış, görsel analizi yapılamıyor');
        _errorMessage = 'Lütfen önce giriş yapınız';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Dosya kontrolü
      if (!await imageFile.exists()) {
        _logger.e('Görsel dosyası bulunamadı: ${imageFile.path}');
        _errorMessage = 'Görsel dosyası bulunamadı';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Dosya bilgilerini logla
      final fileStats = await imageFile.stat();
      _logger.i('Görsel analizi başlatıldı: ${imageFile.path}');
      _logger.i('Görsel boyutu: ${(fileStats.size / 1024).toStringAsFixed(2)} KB');
      
      // OCR servisi örneği oluştur
      final OCRService ocrService = OCRService();
      
      // OCR ile metin çıkarma işlemi
      _logger.i('OCR işlemi başlatılıyor...');
      String? extractedText = await ocrService.extractTextFromImage(imageFile);
      
      if (extractedText == null || extractedText.isEmpty) {
        _logger.e('OCR servisi metin çıkaramadı');
        extractedText = "---- Görüntüden çıkarılan metin ----\n[Görüntüden metin çıkarılamadı]\n---- Çıkarılan metin sonu ----";
      }
      
      _logger.i('OCR işlemi tamamlandı, çıkarılan metin uzunluğu: ${extractedText.length} karakter');
      _logger.i('OCR sonucu (ilk 100 karakter): ${extractedText.length > 100 ? extractedText.substring(0, 100) + '...' : extractedText}');
      
      // Firebase Storage'a görsel yükleme
      _logger.i('Görsel Firebase Storage\'a yükleniyor...');
      final String imageUrl = await _storage.ref().child('messages/${DateTime.now().millisecondsSinceEpoch}.jpg').putFile(imageFile).then((taskSnapshot) => taskSnapshot.ref.getDownloadURL());
      _logger.i('Görsel yüklendi: $imageUrl');
      
      // Rastgele mesaj ID oluştur
      final String messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
      
      final Timestamp timestamp = Timestamp.now();
      
      // Mesaj oluşturma
      final Map<String, dynamic> messageData = {
        'id': messageId,
        'content': extractedText,
        'imageUrl': imageUrl,
        'timestamp': timestamp,
        'sentAt': timestamp,
        'userId': userId,
        'sentByUser': true,
        'isAnalyzed': false,
        'isAnalyzing': true,
        'receiverId': receiverId,
        'messageType': messageType,
        'replyMessageId': replyMessageId,
      };
      
      // Firestore'a mesajı ekleme
      _logger.i('Mesaj Firestore\'a ekleniyor...');
      DocumentReference docRef = await _firestore.collection('users').doc(userId).collection('messages').add(messageData);
      _logger.i('Mesaj Firestore\'a eklendi: ${docRef.id}');
      
      // Mesaj nesnesini oluştur
      Message message = Message.fromMap(messageData, docId: docRef.id);
      
      // Yerel listeye ekle
      _messages.add(message);
      _currentMessage = message;
      notifyListeners();
      
      // AI analizi için içerik hazırlama
      String aiAnalysisContent = '';
      if (extractedText.isNotEmpty) {
        _logger.i('AI analizi için içerik hazırlanıyor...');
        
        // Çıkarılan metni analiz et
        aiAnalysisContent = 'Görüntüden çıkarılan metin: $extractedText\n\n';
        
        _logger.i('AI analizi için içerik hazırlandı, uzunluk: ${aiAnalysisContent.length} karakter');
        _logger.d('AI analizi için içerik (ilk 100 karakter): ${aiAnalysisContent.length > 100 ? aiAnalysisContent.substring(0, 100) + '...' : aiAnalysisContent}');
        
        // Görsel analizinden çıkarılan metni ilet 
        analysis.AnalysisResult? analysisResult = await _aiService.analyzeMessage(aiAnalysisContent);
        
        if (analysisResult != null) {
          _logger.i('AI mesaj analizi tamamlandı, sonuç alındı');
          
          // Analiz sonucunu Firestore'a kaydet
          await docRef.update({
            'analysisResult': analysisResult.toMap(),
            'isAnalyzing': false,
            'isAnalyzed': true,
            'updatedAt': Timestamp.now(),
          });
          
          // Yerel listedeki mesajı güncelle
          final index = _messages.indexWhere((m) => m.id == docRef.id);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              isAnalyzing: false,
              isAnalyzed: true,
              analysisResult: analysisResult,
              analysisSource: AnalysisSource.image, // Analiz kaynağını ayarla
            );
            _currentMessage = _messages[index];
            _currentAnalysisResult = analysisResult;
          }
          
          _logger.i('Analiz sonucu Firestore\'a kaydedildi');
          
          // Analiz tamamlandı durumunu bildir
          _isLoading = false;
          notifyListeners();
          
          return true;
        } else {
          _logger.w('AI mesaj analizi sonuç döndürmedi');
          
          // Analiz başarısız olduğunda güncelleme yap
          await docRef.update({
            'isAnalyzing': false,
            'isAnalyzed': true,
            'errorMessage': 'Analiz sonucu alınamadı',
            'updatedAt': Timestamp.now(),
          });
          
          // Yerel listedeki mesajı güncelle
          final index = _messages.indexWhere((m) => m.id == docRef.id);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              isAnalyzing: false,
              isAnalyzed: true,
              errorMessage: 'Analiz sonucu alınamadı',
              analysisSource: AnalysisSource.image, // Analiz kaynağını ayarla
            );
            _currentMessage = _messages[index];
          }
          
          // Hata durumunu bildir
          _isLoading = false;
          _errorMessage = 'Analiz sonucu alınamadı';
          notifyListeners();
          
          return false;
        }
      } else {
        _logger.w('OCR ile metin çıkarılamadı, AI analizi yapılamadı');
        
        // OCR başarısız olduğunda güncelleme yap
        await docRef.update({
          'isAnalyzing': false,
          'isAnalyzed': true,
          'errorMessage': 'Görüntüden metin çıkarılamadı',
          'updatedAt': Timestamp.now(),
        });
        
        // Yerel listedeki mesajı güncelle
        final index = _messages.indexWhere((m) => m.id == docRef.id);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            isAnalyzing: false,
            isAnalyzed: true,
            errorMessage: 'Görüntüden metin çıkarılamadı',
            analysisSource: AnalysisSource.image, // Analiz kaynağını ayarla
          );
          _currentMessage = _messages[index];
        }
        
        // Hata durumunu bildir
        _isLoading = false;
        _errorMessage = 'Görüntüden metin çıkarılamadı';
        notifyListeners();
        
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('Görsel analizi sırasında hata oluştu: $e');
      _logger.e('Stack trace: $stackTrace');
      _errorMessage = 'Görsel analizi sırasında hata: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Yeni eklenen - Metin dosyasını analiz etme
  Future<analysis.AnalysisResult?> analyzeTextFileMessage(XFile textFile) async {
    try {
      _logger.i('Metin dosyası analizi başlatılıyor...');
      
      // Kullanıcı kimliğini kontrol et
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        _logger.e('Metin dosyası analiz edilemedi: Kullanıcı oturumu bulunamadı');
        _errorMessage = 'Analiz yapılamadı: Lütfen tekrar giriş yapın';
        notifyListeners();
        return null;
      }
      
      _isLoading = true;
      notifyListeners();
      
      // Dosya içeriğini oku
      final bytes = await textFile.readAsBytes();
      final content = String.fromCharCodes(bytes);
      
      if (content.isEmpty) {
        _logger.e('Metin dosyası boş');
        _errorMessage = 'Metin dosyası boş';
        _isLoading = false;
        notifyListeners();
        return null;
      }
      
      // Metin mesajını oluştur
      final message = await addMessage(
        content,
        analyze: true, // Otomatik olarak analiz edilecek
      );
      
      if (message == null) {
        _logger.e('Metin mesajı oluşturulamadı');
        _errorMessage = 'Metin mesajı oluşturulamadı';
        _isLoading = false;
        notifyListeners();
        return null;
      }
      
      // Metin analizi yapılıyor
      final analysisResult = await _aiService.analyzeMessage(content);
      
      if (analysisResult == null) {
        _logger.e('Metin analiz sonucu alınamadı');
        _isLoading = false;
        notifyListeners();
        return null;
      }
      
      // Analiz sonucunu Firestore'a kaydet
      final messageRef = _firestore.collection('users').doc(userId).collection('messages').doc(message.id);
      await messageRef.update({
        'isAnalyzing': false,
        'isAnalyzed': true,
        'analysisResult': analysisResult.toMap(),
        'updatedAt': Timestamp.now(),
      });
      
      // Yerel listedeki mesajı güncelle
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isAnalyzing: false,
          isAnalyzed: true,
          analysisResult: analysisResult,
          analysisSource: AnalysisSource.text, // Analiz kaynağını ayarla
        );
        _currentMessage = _messages[index];
        _currentAnalysisResult = analysisResult;
      }
      
      _isLoading = false;
      notifyListeners();
      
      return analysisResult;
    } catch (e, stackTrace) {
      _logger.e('Metin dosyası analizi sırasında hata oluştu', e, stackTrace);
      _errorMessage = 'Metin dosyası analizi sırasında hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Mesaj analiz sonucunu alma
  Future<analysis.AnalysisResult?> getAnalysisResult(String messageId) async {
    // ID boş kontrolü ekle
    if (messageId.isEmpty) {
      _errorMessage = 'Geçersiz mesaj ID';
      notifyListeners();
      return null;
    }
    
    // Kullanıcı ID'si gerekli
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      _errorMessage = 'Oturumunuz bulunamadı';
      notifyListeners();
      return null;
    }
    
    _isLoading = true;
    notifyListeners();
    _logger.i('Analiz sonucu alınıyor. ID: $messageId');
    
    try {
      // Önce mevcut mesaj varsa ve analiz sonucu da varsa direkt kullan
      if (_currentMessage != null && _currentMessage!.id == messageId && _currentMessage!.analysisResult != null) {
        _logger.i('Analiz sonucu mevcut mesajdan alındı. ID: $messageId');
        _currentAnalysisResult = _currentMessage!.analysisResult;
        _isLoading = false;
        notifyListeners();
        return _currentAnalysisResult;
      }
      
      // Yerel listede bu ID'li mesajı ara
      final message = await getMessage(messageId);
      
      if (message != null && message.analysisResult != null) {
        _logger.i('Analiz sonucu yerel listede/Firestore\'dan alınan mesajda bulundu. ID: $messageId');
        _currentAnalysisResult = message.analysisResult;
        _currentMessage = message;
        _isLoading = false;
        notifyListeners();
        return message.analysisResult;
      }
      
      // Yukarıdaki yöntemlerle bulunamadıysa Firestore'dan çek - Koleksiyon yolu düzeltildi
      final DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('messages')
          .doc(messageId)
          .get();
      
      if (doc.exists) {
        // Doküman verilerini al ve ID değerini ekleyerek mesaj oluştur
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        // Document ID'yi map'e ekle
        data['id'] = doc.id;
        
        final message = Message.fromMap(data, docId: messageId);
        
        // Mevcut mesajı güncelle
        _currentMessage = message;
        
        if (message.analysisResult != null) {
          _currentAnalysisResult = message.analysisResult;
          _logger.i('Analiz sonucu Firestore\'dan alındı. ID: $messageId');
          _isLoading = false;
          notifyListeners();
          return message.analysisResult;
        } else {
          _logger.w('Analiz sonucu bulunamadı. ID: $messageId');
          _errorMessage = 'Analiz sonucu bulunamadı';
          _isLoading = false;
          notifyListeners();
          return null;
        }
      } else {
        _logger.e('Mesaj bulunamadı. ID: $messageId');
        _errorMessage = 'Mesaj bulunamadı';
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _logger.e('Analiz sonucu alınırken hata oluştu: $e');
      _errorMessage = 'Analiz sonucu alınırken hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Mesajı silme
  Future<void> deleteMessage(String messageId) async {
    // ID boş kontrolü ekle
    if (messageId.isEmpty) {
      _errorMessage = 'Silme işlemi için geçersiz mesaj ID';
      return;
    }
    
    // Kullanıcı ID'si gerekli
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      _errorMessage = 'Oturumunuz bulunamadı';
      return;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Mesajı Firestore'dan sil - Koleksiyon yolu düzeltildi
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('messages')
          .doc(messageId)
          .delete();
      
      // Varsa resmi sil
      try {
        await _storage.ref().child('message_images/$userId/$messageId.jpg').delete();
      } catch (e) {
        // Resim olmayabilir, hatayı görmezden gel
        _logger.w('Resim silinirken hata oluştu: $e');
      }
      
      // Yerel listeden kaldır
      _messages.removeWhere((message) => message.id == messageId);
      
      // Eğer mevcut mesaj buysa temizle
      if (_currentMessage?.id == messageId) {
        _currentMessage = null;
        _currentAnalysisResult = null;
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Mesaj silinirken hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mevcut mesajı temizleme
  void clearCurrentMessage() {
    try {
      debugPrint('clearCurrentMessage çağrıldı');
      
      // Eğer zaten null ise gereksiz bildirim yapma
      if (_currentMessage == null && _currentAnalysisResult == null) {
        debugPrint('Temizlenecek mesaj veya analiz sonucu yok, işlem atlanıyor');
        return;
      }
      
      debugPrint('Mevcut mesaj ve analiz sonucu temizleniyor');
      _currentMessage = null;
      _currentAnalysisResult = null;
      
      notifyListeners();
      debugPrint('Mesaj ve analiz sonucu başarıyla temizlendi');
    } catch (e) {
      debugPrint('Mesaj temizleme işlemi sırasında hata: $e');
      // Hata durumunda yapılacak işlemler
      _setError('Mesaj temizlenirken beklenmeyen bir hata oluştu: $e');
    }
  }

  // Yükleme durumunu ayarlama
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Hata mesajını ayarlama
  void _setError(String? error) {
    _errorMessage = error;
    if (error != null) {
      _logger.e(error);
    }
    notifyListeners();
  }

  // Hata mesajını temizleme
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ProfileViewModel ataması için metod
  void setProfileViewModel(ProfileViewModel profileViewModel) {
    _profileViewModel = profileViewModel;
  }

  // Tüm mesajları silme
  Future<void> clearAllData(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Tüm veri türlerini temizle
      await _clearMessageAnalysisData(userId);
      await _clearRelationshipEvaluationData(userId);
      await _clearConsultationData(userId);
      
      // Yerel listeyi temizle
      _messages.clear();
      _currentMessage = null;
      _currentAnalysisResult = null;
      
      _isLoading = false;
      notifyListeners();
      
      _logger.i('Tüm veriler başarıyla silindi');
      
    } catch (e) {
      _logger.e('Veri silme hatası', e);
      _errorMessage = 'Veriler silinirken bir hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sadece mesaj analizlerini silme
  Future<void> clearMessageAnalysisData(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _clearMessageAnalysisData(userId);
      
      // Yerel mesaj analizi verilerini temizle
      _currentAnalysisResult = null;
      
      // Mesajlardan analiz sonuçlarını temizle (ancak mesajların kendisini silme)
      for (var i = 0; i < _messages.length; i++) {
        if (_messages[i].analysisResult != null) {
          _messages[i] = _messages[i].copyWith(
            analysisResult: null,
            isAnalyzed: false,
            isAnalyzing: false
          );
        }
      }
      
      if (_currentMessage?.analysisResult != null) {
        _currentMessage = _currentMessage?.copyWith(
          analysisResult: null,
          isAnalyzed: false,
          isAnalyzing: false
        );
      }
      
      _isLoading = false;
      notifyListeners();
      
      _logger.i('Mesaj analizi verileri başarıyla silindi');
      
    } catch (e) {
      _logger.e('Mesaj analizi verilerini silme hatası', e);
      _errorMessage = 'Mesaj analizi verileri silinirken bir hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Sadece ilişki değerlendirmelerini silme
  Future<void> clearRelationshipEvaluationData(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _clearRelationshipEvaluationData(userId);
      
      _isLoading = false;
      notifyListeners();
      
      _logger.i('İlişki değerlendirme verileri başarıyla silindi');
      
    } catch (e) {
      _logger.e('İlişki değerlendirme verilerini silme hatası', e);
      _errorMessage = 'İlişki değerlendirme verileri silinirken bir hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Sadece danışma verilerini silme
  Future<void> clearConsultationData(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _clearConsultationData(userId);
      
      _isLoading = false;
      notifyListeners();
      
      _logger.i('Danışma verileri başarıyla silindi');
      
    } catch (e) {
      _logger.e('Danışma verilerini silme hatası', e);
      _errorMessage = 'Danışma verileri silinirken bir hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // İç kullanım için mesaj analizi temizleme
  Future<void> _clearMessageAnalysisData(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    
    // Mesajlardaki analiz sonuçlarını temizleme
    final messagesRef = userRef.collection('messages');
    final messageSnapshot = await messagesRef.where('isAnalyzed', isEqualTo: true).get();
    
    // Batch işlemi başlat
    WriteBatch batch = _firestore.batch();
    
    // Her bir mesajı güncelle
    for (var doc in messageSnapshot.docs) {
      batch.update(doc.reference, {
        'analysisResult': null,
        'isAnalyzed': false,
        'isAnalyzing': false,
        'updatedAt': Timestamp.now(),
      });
    }
    
    // Ayrıca message_analyses koleksiyonunu temizle
    final analysesRef = userRef.collection('message_analyses');
    final analysesSnapshot = await analysesRef.get();
    
    for (var doc in analysesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    // Batch işlemini uygula
    await batch.commit();
    
    // Geçmiş analizler için de temizleme işlemi
    final pastAnalysesViewModel = _profileViewModel?.context != null
        ? Provider.of<PastAnalysesViewModel>(_profileViewModel!.context!, listen: false)
        : null;
    
    if (pastAnalysesViewModel != null) {
      await pastAnalysesViewModel.clearAllAnalyses(userId);
    }
  }
  
  // İç kullanım için ilişki değerlendirme temizleme
  Future<void> _clearRelationshipEvaluationData(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    
    // İlişki değerlendirme koleksiyonu
    final evaluationsRef = userRef.collection('relationship_evaluations');
    final evaluationsSnapshot = await evaluationsRef.get();
    
    // Batch işlemi başlat
    WriteBatch batch = _firestore.batch();
    
    // Her bir değerlendirmeyi sil
    for (var doc in evaluationsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    // Batch işlemini uygula
    await batch.commit();
    
    // Profil ViewModel'de ilişki değerlendirme verilerini temizle
    // Not: Profil ViewModel'de clearRelationshipEvaluations metodu olmayabilir
    // Bu nedenle bu kısmı şimdilik kaldırıyoruz
    /* 
    final profileViewModel = _profileViewModel?.context != null
        ? Provider.of<ProfileViewModel>(_profileViewModel!.context!, listen: false)
        : null;
    
    if (profileViewModel != null) {
      profileViewModel.clearRelationshipEvaluations();
    }
    */
  }
  
  // İç kullanım için danışma verileri temizleme
  Future<void> _clearConsultationData(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    
    // Danışma koleksiyonu
    final consultationsRef = userRef.collection('consultations');
    final consultationsSnapshot = await consultationsRef.get();
    
    // Batch işlemi başlat
    WriteBatch batch = _firestore.batch();
    
    // Her bir danışmayı sil
    for (var doc in consultationsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    // Batch işlemini uygula
    await batch.commit();
  }

  // Mevcut analiz işlemlerini sıfırla
  void resetCurrentAnalysis() {
    _logger.i('Mevcut analiz durumu sıfırlanıyor');
    _currentMessage = null;
    _currentAnalysisResult = null;
    notifyListeners();
  }

  // Analiz sonucunu kullanıcı profiline kaydetme (dışarıdan erişilebilir)
  Future<void> updateUserProfileWithAnalysis(String userId, analysis.AnalysisResult analysisResult, AnalysisType analysisType) async {
    try {
      _logger.i('${analysisType.name} analiz sonucu kullanıcı profiline kaydediliyor: $userId');
      
      // İlişki puanı ve kategori puanlarını hesapla
      final Map<String, dynamic> analizVerileri = {
        'mesajIcerigi': analysisType == AnalysisType.consultation ? analysisResult.aiResponse['mesaj'] ?? '' : _currentMessage?.content ?? '',
        'duygu': analysisResult.emotion,
        'niyet': analysisResult.intent,
        'ton': analysisResult.tone,
        'mesajYorumu': analysisResult.aiResponse['mesajYorumu'] ?? '',
      };
      
      // Kullanıcı profilini çek
      DocumentReference userRef = _firestore.collection('users').doc(userId);
      DocumentSnapshot<Map<String, dynamic>> userDoc = await userRef.get() as DocumentSnapshot<Map<String, dynamic>>;
      
      // Kullanıcı modeli yoksa oluştur
      if (!userDoc.exists) {
        _logger.w('Kullanıcı belgesi bulunamadı, analiz kaydedilemedi: $userId');
        return;
      }
      
      // Kullanıcı modelini oluştur
      UserModel userModel = UserModel.fromFirestore(userDoc);
      
      // Analiz hizmeti ile ilişki durumunu analiz et
      final analizSonucuMap = await _aiService.iliskiDurumuAnaliziYap(userId, analizVerileri);
      
      // Map'i AnalizSonucu nesnesine dönüştür
      final AnalizSonucu analizSonucu = AnalizSonucu.fromMap(analizSonucuMap);
      
      // Kullanıcı modelini güncelle
      final UserModel guncelKullanici = userModel.analizSonucuEkle(analizSonucu);
      
      // Firestore'a kaydet
      await userRef.update({
        'sonAnalizSonucu': analizSonucu.toMap(),
        'analizGecmisi': FieldValue.arrayUnion([analizSonucu.toMap()]),
      });
      
      _logger.i('Kullanıcı profili başarıyla güncellendi. İlişki puanı: ${analizSonucu.iliskiPuani}');
      
      // Ana sayfayı güncelle - HomeController ile güvenli bir şekilde
      try {
        // Null-aware operatör kullanarak context değerine erişiyoruz
        final context = _profileViewModel?.context;
        if (context != null && context.mounted) {
          try {
            final homeController = Provider.of<HomeController>(context, listen: false);
            await homeController.anaSayfayiGuncelle(); // HomeController'ın mevcut metodunu kullan
            _logger.i('Ana sayfa yeni analiz sonucuyla güncellendi');
          } catch (e) {
            _logger.w('HomeController ile güncelleme hatası: $e');
          }
        } else {
          _logger.w('Context null veya artık geçerli değil');
        }
      } catch (e) {
        _logger.w('Ana sayfa güncellenirken hata oluştu: $e');
      }
    } catch (e) {
      _logger.w('Analiz sonucu kullanıcı profiline kaydedilirken hata oluştu', e);
    }
  }
}