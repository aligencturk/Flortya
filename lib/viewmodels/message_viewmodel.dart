import 'dart:io';
import 'dart:async'; // StreamSubscription için import eklendi
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
import '../services/encryption_service.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../controllers/home_controller.dart';
import '../controllers/message_coach_controller.dart'; // MessageCoachController eklendi
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
  bool _isAnalysisCancelled = false;

  // Getters
  List<Message> get messages => _messages;
  Message? get currentMessage => _currentMessage;
  analysis.AnalysisResult? get currentAnalysisResult => _currentAnalysisResult;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasCurrentMessage => _currentMessage != null;
  bool get hasAnalysisResult => _currentAnalysisResult != null;
  bool get isFirstLoadCompleted => _isFirstLoadCompleted;
  
  // Wrapped verisi olup olmadığını kontrol eden getter
  bool get hasWrappedData {
    // Eğer mesaj varsa ve en az bir analiz yapılmışsa wrapped verisinin olduğunu kabul ediyoruz
    return _messages.isNotEmpty && _messages.any((message) => message.analysisResult != null);
  }
  
  // Wrapped analiz verilerini getirir
  Future<List<Map<String, String>>> getWrappedAnalysis() async {
    try {
      _logger.i('Wrapped analizi hazırlanıyor...');
      
      // Analiz sonucu olan mesajları filtrele
      final analyzedMessages = _messages.where((message) => message.analysisResult != null).toList();
      
      if (analyzedMessages.isEmpty) {
        _logger.w('Analiz edilmiş mesaj bulunamadı.');
        return [];
      }
      
      // En son analiz edilen mesajı al
      final latestAnalyzedMessage = analyzedMessages.first; // Mesajlar zaten tarihe göre sıralı
      final aiResponse = latestAnalyzedMessage.analysisResult?.aiResponse ?? {};
      
      // Özet verileri oluştur
      List<Map<String, String>> summaryData = [
        {
          'title': '✨ İlişki Özeti',
          'comment': aiResponse['mesajYorumu']?.toString() ?? 'İlişkiniz analiz edildi.',
        },
        {
          'title': '💌 Mesaj Analizi',
          'comment': 'Mesaj analiziniz hazır! Duygusal ton: ${latestAnalyzedMessage.analysisResult?.emotion ?? "Nötr"}',
        },
        {
          'title': '💬 İletişim Tarzınız',
          'comment': aiResponse['iletisimTarzi']?.toString() ?? 'İletişiminiz analiz edildi.',
        },
        {
          'title': '🌟 Güçlü Yönleriniz',
          'comment': aiResponse['gucluyonler']?.toString() ?? 'Mesajlarınızda olumlu bir ton tespit edildi.',
        },
        {
          'title': '🔍 Gelişim Alanlarınız',
          'comment': aiResponse['gelisimAlanlari']?.toString() ?? 'İletişim stilinizi geliştirmeye devam edin.',
        },
      ];
      
      return summaryData;
    } catch (e) {
      _logger.e('Wrapped analizi hazırlanırken hata oluştu', e);
      return [];
    }
  }
  
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
      
      // Temel mesaj verilerini önce değişkene ekleyelim
      final Map<String, dynamic> messageData = {};
      
      // İçeriği temizle ve kontrollerini yap
      String safeContent = content;
      
      // Kontrol karakterlerini temizle (çok uzun içeriği kısaltma işlemini kaldırıyoruz)
      safeContent = safeContent.replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'), '');
      
      // Zorunlu alanları ekle
      messageData['content'] = safeContent;
      messageData['userId'] = userId;
      messageData['timestamp'] = FieldValue.serverTimestamp();
      messageData['createdAt'] = FieldValue.serverTimestamp();
      messageData['updatedAt'] = FieldValue.serverTimestamp();
      messageData['isAnalyzed'] = false;
      messageData['isAnalyzing'] = false;
      
      // Opsiyonel alanları sadece null değilse ekle
      if (imageUrl != null && imageUrl.isNotEmpty) {
        messageData['imageUrl'] = imageUrl;
      } else {
        messageData['imageUrl'] = ''; // Boş string olarak ayarla, null gönderme
      }
      
      if (imagePath != null && imagePath.isNotEmpty) {
        messageData['imagePath'] = imagePath;
      } else {
        messageData['imagePath'] = ''; // Boş string olarak ayarla, null gönderme
      }
      
      // Hata ayıklama
      print("\n==== FIRESTORE'A GÖNDERİLECEK VERİLER ====");
      messageData.forEach((key, value) {
        print("$key: ${value.runtimeType} = $value");
      });
      print("=========================================\n");
      
      try {
        // Kullanıcının mesajlar koleksiyonuna ekle
        final messagesCollectionRef = userDocRef.collection('messages');
        
        // Firestore'a ekle
        print("Firestore add() işlemi başlıyor...");
        
        // Sadece özel karakterleri temizle, içeriği kısaltma
        final cleanContent = safeContent.replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'), '');
        
        // Firestore'a eklenecek verileri hazırla
        final cleanMessageData = Map<String, dynamic>.from(messageData);
        cleanMessageData['content'] = cleanContent;
        
        // CHUNKING: Çok büyük içerikler için parçalı kaydetme stratejisi
        Message resultMessage;
        
        if (cleanContent.length > 800000) {
          _logger.i('İçerik ${cleanContent.length} karakter. Parçalı kaydetme yapılacak.');
          
          // Ana içeriği kısalt
          cleanMessageData['content'] = 'Büyük boyutlu metin (${cleanContent.length} karakter)';
          cleanMessageData['hasChunks'] = true;
          cleanMessageData['chunksCount'] = 0; // İlk başta 0, daha sonra güncellenecek
          
          // Ana mesajı önce ekle, ardından parçaları ekleyeceğiz
          final docRef = await messagesCollectionRef.add(cleanMessageData);
          _logger.i('Ana mesaj kaydedildi: ${docRef.id}');
          
          // Metni parçalara ayır - 750 KB parçalar halinde
          const int chunkSize = 750000;
          int offset = 0;
          int chunkIndex = 0;
          
          while (offset < cleanContent.length) {
            int end = offset + chunkSize;
            if (end > cleanContent.length) {
              end = cleanContent.length;
            }
            
            String chunk = cleanContent.substring(offset, end);
            
            // Parçayı kaydet
            await messagesCollectionRef.doc(docRef.id).collection('chunks').doc('chunk_$chunkIndex').set({
              'content': chunk,
              'index': chunkIndex,
              'timestamp': FieldValue.serverTimestamp()
            });
            
            _logger.i('Parça ${chunkIndex} kaydedildi (${chunk.length} karakter)');
            
            offset = end;
            chunkIndex++;
          }
          
          // Ana mesajı güncelle
          await messagesCollectionRef.doc(docRef.id).update({
            'chunksCount': chunkIndex
          });
          
          _logger.i('Toplam $chunkIndex parçada kaydedildi');
          
          // Yeni oluşturulan mesajı al
          resultMessage = Message.fromMap({
            'content': cleanContent, // Yerel uygulamada tam içerik tutulabilir
            'imageUrl': imageUrl ?? '',
            'imagePath': imagePath ?? '',
            'timestamp': timestamp,
            'userId': userId,
            'isAnalyzed': false,
            'isAnalyzing': analyze,
            'createdAt': timestamp,
            'updatedAt': timestamp,
            'hasChunks': true,
            'chunksCount': chunkIndex
          }, docId: docRef.id);
        }
        else {
          // Normal kaydetme - içerik çok büyük değilse
          final docRef = await messagesCollectionRef.add(cleanMessageData);
          print("Firestore add() işlemi başarılı! Belge ID: ${docRef.id}");
          _logger.i('Mesaj Firestore\'a kaydedildi: ${docRef.id}');
          
          // Kullanıcının mesaj sayısını artır
          await userDocRef.update({
            'messageCount': FieldValue.increment(1),
          });
          
          // Yeni oluşturulan mesajı al
          resultMessage = Message.fromMap({
            'content': safeContent,
            'imageUrl': imageUrl ?? '',
            'imagePath': imagePath ?? '',
            'timestamp': timestamp,
            'userId': userId,
            'isAnalyzed': false,
            'isAnalyzing': analyze,
            'createdAt': timestamp,
            'updatedAt': timestamp,
          }, docId: docRef.id);
        }
        
        // Mesajı yerel listeye ekle
        _messages.add(resultMessage);
        _currentMessage = resultMessage;
        
        _isLoading = false;
        notifyListeners();
        
        _logger.i('Mesaj başarıyla eklendi, Mesaj ID: ${resultMessage.id}');
        
        // İstenirse mesajı analize gönder
        if (analyze) {
          _logger.i('Mesaj analiz için gönderiliyor');
          analyzeMessage(resultMessage.id);
        }
        
        return resultMessage;
        
      } catch (firestoreError) {
        print("\n❌ FIRESTORE HATASI ❌");
        print("Hata mesajı: $firestoreError");
        
        // Invalid-argument hatası için detaylı inceleme
        if (firestoreError.toString().contains('invalid-argument')) {
          print("\n📋 INVALID ARGUMENT HATASI ANALİZİ");
          print("Bu hata genellikle verilerde geçersiz değerler olduğunda oluşur.");
          print("Özellikle şu değerlere dikkat edin:");
          print("1. Null değerler - bazı Firestore yapılandırmalarında null değerler sorun çıkarabilir");
          print("2. Boş alan adları - alan adları boş olamaz");
          print("3. Nokta içeren alan adları - örn: 'user.name' şeklinde alan adları kullanılamaz");
          print("4. Desteklenmeyen veri tipleri - Firestore sadece şunları destekler: String, Number, Boolean, Map, Array, Null, Timestamp, Geopoint, Reference");
        }
        
        print("❌ HATA SONU ❌\n");
        throw firestoreError; // Hatayı yeniden fırlat
      }
      
    } catch (e, stackTrace) {
      _logger.e('Mesaj eklenirken hata oluştu', e, stackTrace);
      print('Hata: $e');
      print('Stack Trace: $stackTrace');
      
      // Hatayı ayrıştır
      String errorMsg = e.toString();
      if (errorMsg.contains('invalid-argument')) {
        _errorMessage = 'Firestore veri formatı hatası: Geçersiz alan adı veya değer kullanımı';
        print("\n⚠️ Veri formatı hatası! Geçersiz alan adı veya desteklenmeyen veri tipi kullanımı.");
        print("Message.toMap() metodunu kontrol edin ve null değerleri temizleyin.");
      } else {
        _errorMessage = 'Mesaj eklenirken bir hata oluştu: $e';
      }
      
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



  // Mesajı analiz et (messageId ile)
  Future<bool> analyzeMessage(String messageIdOrContent) async {
    try {
      _logger.i('Mesaj analizi başlatılıyor');
      
      // Kullanıcı kimliğini kontrol et
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        _logger.e('Mesaj analiz edilemedi: Kullanıcı oturumu bulunamadı');
        _errorMessage = 'Analiz yapılamadı: Lütfen tekrar giriş yapın';
        notifyListeners();
        return false;
      }
      
      // Firestore'da mesaj ID'si ile eşleşen belge var mı kontrol et
      bool isMessageId = false;
      Message? message;
      String messageId = '';
      String content = messageIdOrContent;
      
      try {
      // Önce yerel listede mesajı ara
        message = _messages.firstWhereOrNull((m) => m.id == messageIdOrContent);
      
        // Yerel listede bulunamadıysa Firestore'dan ara
      if (message == null) {
          final messageDocRef = _firestore.collection('users').doc(userId).collection('messages').doc(messageIdOrContent);
          final messageDoc = await messageDocRef.get();
        
          if (messageDoc.exists) {
            isMessageId = true;
            messageId = messageIdOrContent;
            
            // Mesajı oluştur
            final messageData = messageDoc.data() as Map<String, dynamic>;
            message = Message.fromMap(messageData, docId: messageId);
            _messages.add(message); // Yerel listeye ekle
            content = message.content;
          }
        } else {
          isMessageId = true;
          messageId = messageIdOrContent;
          content = message.content;
        }
      } catch (e) {
        _logger.i('messageIdOrContent bir mesaj ID\'si değil, içerik olarak işlenecek: ${e.toString().substring(0, min(50, e.toString().length))}');
        isMessageId = false;
        }
        
      // Eğer mesaj ID'si değilse, yeni bir mesaj oluştur
      if (!isMessageId) {
        _logger.i('Yeni mesaj oluşturuluyor');
        // Metin mesajını oluştur
        message = await addMessage(
          content,
          analyze: false, // Analizi sonradan manuel yapacağız
        );
        
        if (message == null) {
          _logger.e('Mesaj oluşturulamadı');
          _errorMessage = 'Mesaj oluşturulamadı';
          notifyListeners();
          return false;
        }
        
        messageId = message.id;
      }
      
      // Analiz durumunu güncelle
      _logger.i('Mesaj analiz durumu güncelleniyor: $messageId');
      
      // Firestore'daki durumu güncelle
      final messageRef = _firestore.collection('users').doc(userId).collection('messages').doc(messageId);
      await messageRef.update({
        'isAnalyzing': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Yerel listedeki mesajı güncelle
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(isAnalyzing: true);
        _currentMessage = _messages[index];
        notifyListeners();
      }
      
      // Mesaj içeriğini hazırla
      if (content.trim().isEmpty) {
        _logger.e('Mesaj içeriği boş, analiz edilemez');
        await messageRef.update({
          'isAnalyzing': false,
          'isAnalyzed': true,
          'errorMessage': 'Mesaj içeriği boş',
          'updatedAt': FieldValue.serverTimestamp(),
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
      
      // İptal kontrolü
      if (_isAnalysisCancelled) {
        _logger.i('Analiz iptal edildi, işlem durduruluyor');
        return false;
      }
      
      // API'ye gönder ve sonucu al
      _logger.i('AI servisine analiz isteği gönderiliyor');
      final analysisResult = await _aiService.analyzeMessage(content);
      
      // Analiz sonrası iptal kontrolü
      if (_isAnalysisCancelled) {
        _logger.i('Analiz tamamlandı ama iptal edildi, sonuç kaydedilmeyecek');
        return false;
      }
      
      // Sonucu kontrol et
      if (analysisResult == null) {
        _logger.e('AI servisinden analiz sonucu alınamadı');
        
        // Firestore belgesini güncelle
        await messageRef.update({
          'isAnalyzing': false,
          'isAnalyzed': true,
          'errorMessage': 'AI servisi yanıt vermedi',
          'updatedAt': FieldValue.serverTimestamp(),
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
      
      // Sonucu Firestore'a kaydet (şifreli)
      final encryptedAnalysisResult = EncryptionService().encryptJson(analysisResult.toMap());
      await messageRef.update({
        'isAnalyzing': false,
        'isAnalyzed': true,
        'analysisResult': encryptedAnalysisResult,
        'updatedAt': FieldValue.serverTimestamp(),
        'analysisSource': isMessageId ? 'normal' : 'text', // Text dosyası analizi ise source değeri text olacak
      });
      
      // Yerel listedeki mesajı güncelle
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isAnalyzing: false,
          isAnalyzed: true,
          analysisResult: analysisResult,
          errorMessage: null,
          analysisSource: isMessageId ? AnalysisSource.normal : AnalysisSource.text, // Analiz kaynağını ayarla
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
      print('Analiz Hatası: $e');
      print('Analiz Stack Trace: $stackTrace');
      
      // Hata türünü tespit et
      String errorMsg = e.toString();
      if (errorMsg.contains('failed-precondition') || errorMsg.contains('index')) {
        print('⚠️ INDEX HATASI TESPIT EDILDI! ⚠️');
        print('Bu hata genellikle Firestore\'da gerekli indexlerin oluşturulmadığını gösterir.');
        print('Çözüm: Firebase konsolunda Firestore > Indexes bölümüne gidin ve gerekli indexleri ekleyin.');
        print('Veya konsolda görünen URL\'yi ziyaret edin.');
        
        _errorMessage = 'Firestore index hatası: Yöneticinize başvurun';
      } else if (errorMsg.contains('invalid-argument')) {
        print('⚠️ INVALID ARGUMENT HATASI TESPIT EDILDI! ⚠️');
        print('Bu hata genellikle Firestore\'a uygun olmayan veri göndermeye çalıştığınızı gösterir.');
        print('Lütfen veri yapılarını kontrol edin (null değerler, özel karakterler, desteklenmeyen tipler).');
      }
      
      // Hata durumunda varsayılan değerler
      bool isExistingMessageId = false;
      String messageIdentifier = '';
      
      // Eğer messageIdOrContent bir UUID formatındaysa, ID olarak kabul edebiliriz
      if (messageIdOrContent.length > 20) {
        isExistingMessageId = true;
        messageIdentifier = messageIdOrContent;
      }
      
      // Hata durumunda Firestore'u güncellemeye çalış
      try {
        final userId = _authService.currentUser?.uid;
        if (userId != null && messageIdOrContent.isNotEmpty) {
          // Eğer messageIdOrContent bir içerikse (yani messageId değilse) hata raporu gönderemeyiz
          if (isExistingMessageId) {
            final messageRef = _firestore.collection('users').doc(userId).collection('messages').doc(messageIdentifier);
          await messageRef.update({
            'isAnalyzing': false,
            'isAnalyzed': true,
            'errorMessage': e.toString(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          }
        }
      } catch (updateError) {
        _logger.e('Hata sonrası Firestore güncellemesi başarısız oldu', updateError);
      }
      
      // Yerel listeyi güncelle
      if (isExistingMessageId) {
        final index = _messages.indexWhere((m) => m.id == messageIdentifier);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isAnalyzing: false,
          isAnalyzed: true,
          errorMessage: e.toString(),
        );
        _currentMessage = _messages[index];
        }
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
      
      // Analiz türünü belirle
      AnalysisType analizTuru = AnalysisType.other;
      
      // Mesaj Koçu kontrolü
      if (analysisResult.aiResponse.containsKey('direktYorum') || 
          analysisResult.aiResponse.containsKey('sohbetGenelHavasi')) {
        analizTuru = AnalysisType.messageCoach;
        _logger.i('Mesaj Koçu analizi tespit edildi, kullanıcı profili güncellenmeyecek');
        return;
      }
      
      // İlişki değerlendirmesi kontrolü
      if (analysisResult.aiResponse.containsKey('relationship_type') ||
          analysisResult.aiResponse.containsKey('relationshipType')) {
        analizTuru = AnalysisType.relationshipEvaluation;
        _logger.i('İlişki Değerlendirmesi tespit edildi, kullanıcı profili güncellenmeyecek');
        return;
      }
      
      // AnalysisSource'a göre türü belirle
      if (_currentMessage != null) {
        if (_currentMessage!.analysisSource == AnalysisSource.text) {
          analizTuru = AnalysisType.txtFile;
        } else if (_currentMessage!.analysisSource == AnalysisSource.image) {
          analizTuru = AnalysisType.image;
        }
      }
      
      // Eğer tür hala belirlenemediyse, devam etmeyelim
      if (analizTuru == AnalysisType.other) {
        _logger.w('Analiz türü belirlenemedi, kullanıcı profili güncellenmeyecek');
        return;
      }
      
      // Kullanıcı profilini çek
      DocumentReference userRef = _firestore.collection('users').doc(userId);
      DocumentSnapshot<Map<String, dynamic>> userDoc = await userRef.get() as DocumentSnapshot<Map<String, dynamic>>;
      
      // Kullanıcı modeli yoksa oluştur
      if (!userDoc.exists) {
        _logger.w('Kullanıcı belgesi bulunamadı, analiz kaydedilemedi: $userId');
        return;
      }
      
      
      // Analiz hizmeti ile ilişki durumunu analiz et
      final analizSonucuMap = await _aiService.iliskiDurumuAnaliziYap(userId, analizVerileri);
      
      // Map'i AnalizSonucu nesnesine dönüştür
      final AnalizSonucu analizSonucu = AnalizSonucu.fromMap(analizSonucuMap);
      
      // Kullanıcı modelini güncelle
      
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
      _logger.i('OCR sonucu (ilk 100 karakter): ${extractedText.length > 100 ? '${extractedText.substring(0, 100)}...' : extractedText}');
      
      // Firebase Storage'a görsel yükleme
      String imageUrl = '';
      try {
        _logger.i('Görsel Firebase Storage\'a yükleniyor...');
        // Dosya boyutunu kontrol et
        final fileSize = await imageFile.length();
        _logger.i('Yüklenecek dosya boyutu: ${(fileSize / 1024).toStringAsFixed(2)} KB');
        
        if (fileSize > 10 * 1024 * 1024) {
          // 10MB'dan büyük dosyalar için sıkıştırma veya boyut kontrolü yapılabilir
          _logger.w('Dosya boyutu çok büyük (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB)');
        }
        
        // Dosya yükleme işlemi
        final uploadTask = _storage.ref().child('messages/${DateTime.now().millisecondsSinceEpoch}.jpg').putFile(imageFile);
        
        // Yükleme ilerlemesini izleme - try-catch bloğu içinde ve opsiyonel olarak
        try {
          StreamSubscription<TaskSnapshot>? progressSubscription;
          progressSubscription = uploadTask.snapshotEvents.listen(
            (TaskSnapshot snapshot) {
              try {
                if (snapshot.totalBytes > 0) { // Sıfıra bölme hatasını önle
                  final progress = snapshot.bytesTransferred / snapshot.totalBytes;
                  _logger.i('Yükleme ilerlemesi: ${(progress * 100).toStringAsFixed(2)}%');
                }
              } catch (progressError) {
                _logger.w('İlerleme hesaplama hatası: $progressError');
              }
            },
            onError: (e) {
              _logger.e('Yükleme işlemi dinleme hatası: $e');
              // Dinleme hatası olduğunda subscription'ı iptal et
              progressSubscription?.cancel();
            },
            onDone: () {
              // İşlem tamamlandığında subscription'ı iptal et
              progressSubscription?.cancel();
              _logger.i('Yükleme izleme tamamlandı');
            },
            cancelOnError: false, // Hata olduğunda otomatik iptal etme
          );
        } catch (listenError) {
          // Dinleme hatası ana işlemi etkilemesin
          _logger.w('Yükleme izleme başlatılamadı: $listenError');
        }
        
        // Yükleme tamamlandığında URL alma - bu kısım dinleme hatasından etkilenmez
        final taskSnapshot = await uploadTask;
        imageUrl = await taskSnapshot.ref.getDownloadURL();
        _logger.i('Görsel yüklendi: $imageUrl');
      } catch (storageError) {
        _logger.e('Firebase Storage hatası: ${storageError.toString()}', storageError);
        
        // Hata türünü analiz et
        if (storageError.toString().contains('unauthorized') || 
            storageError.toString().contains('not-authorized')) {
          _errorMessage = 'Depolama izninde sorun var: Lütfen giriş yapın';
        } else if (storageError.toString().contains('quota')) {
          _errorMessage = 'Depolama kotası aşıldı';
        } else if (storageError.toString().contains('network')) {
          _errorMessage = 'Ağ hatası: İnternet bağlantınızı kontrol edin';
        } else {
          _errorMessage = 'Dosya yükleme hatası: ${storageError.toString()}';
        }
        
        // Dosya yükleme hatası durumunda boş URL ile devam et ve hata durumunu not al
        _logger.i('Dosya yükleme hatası nedeniyle boş URL ile devam ediliyor');
      }
      
      // Rastgele mesaj ID oluştur
      final String messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
      
      final Timestamp timestamp = Timestamp.now();
      
      // Mesaj oluşturma
      final Map<String, dynamic> messageData = {
        'id': messageId,
        'content': extractedText,
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
      
      // Resim URL'i boş değilse ekle
      if (imageUrl.isNotEmpty) {
        messageData['imageUrl'] = imageUrl;
      } else {
        // Resim yüklenemedi durumunu işaretle
        messageData['imageUploadFailed'] = true;
        messageData['errorMessage'] = _errorMessage ?? 'Görsel yüklemesi başarısız oldu';
      }
      
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
        aiAnalysisContent = extractedText;
        
        _logger.i('AI analizi için içerik hazırlandı, uzunluk: ${aiAnalysisContent.length} karakter');
        _logger.d('AI analizi için içerik (ilk 100 karakter): ${aiAnalysisContent.length > 100 ? '${aiAnalysisContent.substring(0, 100)}...' : aiAnalysisContent}');
        
        // Görsel analizinden çıkarılan metni ilet 
        try {
          _logger.i('AI analizi için görüntüden çıkarılan metin gönderiliyor...');
          
          // API çağrısını daha sağlam hale getir
          analysis.AnalysisResult? analysisResult;
          try {
            // Yetkilendirme kontrolü ve hata işleme iyileştirmesi
            if (_authService.currentUser == null) {
              _logger.e('Kullanıcı oturumu bulunamadı');
              throw Exception('Yetkilendirme bilgileri eksik. Lütfen tekrar giriş yapın.');
            }
            
            // İçerik uzunluğunu kontrol et ve kısalt (eğer aşırı büyükse)
            // Görsel analizi için kısaltma işlemini kaldırdık
            
            // HTTP istek ile detaylı hata yakalama
            analysisResult = await _aiService.analyzeMessage(aiAnalysisContent);
            _logger.i('AI servisi yanıt verdi');
          } catch (apiError) {
            _logger.e('AI servisi çağrısında hata oluştu: ${apiError.toString()}', apiError);
            
            // Hata durumunu daha detaylı analiz et
            String errorDetails = apiError.toString();
            
            // HTTP hata kodlarını kontrol et ve daha açıklayıcı mesajlar oluştur
            if (errorDetails.contains('401') || errorDetails.contains('403')) {
              _errorMessage = 'Yetkilendirme hatası: Lütfen tekrar giriş yapın';
            } else if (errorDetails.contains('400')) {
              _errorMessage = 'İstek formatında hata: Görüntü metni çok uzun veya uygun formatta değil';
            } else if (errorDetails.contains('timeout') || errorDetails.contains('SocketException')) {
              _errorMessage = 'Bağlantı hatası: İnternet bağlantınızı kontrol edin';
            } else {
              _errorMessage = 'API hatası: ${apiError.toString().substring(0, apiError.toString().length > 50 ? 50 : apiError.toString().length)}';
            }
            
            // Null döndürme, hata durumunda işleme devam edecek
            analysisResult = null;
          }
          
          if (analysisResult != null) {
            _logger.i('AI mesaj analizi tamamlandı, sonuç alındı');
            
            try {
              // Analiz sonucunu Firestore'a kaydet (şifreli)
              final encryptedAnalysisResult = EncryptionService().encryptJson(analysisResult.toMap());
              await docRef.update({
                'analysisResult': encryptedAnalysisResult,
                'isAnalyzing': false,
                'isAnalyzed': true,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              
              _logger.i('Analiz sonucu şifreli olarak Firestore\'a kaydedildi');
            } catch (dbError) {
              _logger.e('Firestore güncelleme hatası: ${dbError.toString()}', dbError);
              // Veritabanı hatası olsa bile devam et
            }
            
            // Yerel listedeki mesajı güncelle
            final index = _messages.indexWhere((m) => m.id == docRef.id);
            if (index != -1) {
              _messages[index] = _messages[index].copyWith(
                isAnalyzing: false,
                isAnalyzed: true,
                analysisResult: analysisResult,
                analysisSource: AnalysisSource.image, // Görüntü analizi kaynağını ayarla
              );
              _currentMessage = _messages[index];
              _currentAnalysisResult = analysisResult;
            }
            
            // Kullanıcı profiline kaydetmeyi dene
            try {
              // Analiz sonucunu kullanıcı profiline de kaydet
              await _updateUserProfileWithAnalysis(userId, analysisResult);
              _logger.i('Analiz sonucu kullanıcı profiline kaydedildi');
            } catch (profileError) {
              _logger.e('Kullanıcı profili güncelleme hatası: ${profileError.toString()}', profileError);
              // Profil hatası olsa bile işlemi tamamla
            }
            
            _isLoading = false;
            notifyListeners();
            return true;
          } else {
            _logger.w('AI mesaj analizi sonuç döndürmedi');
            
            // Analiz başarısız olduğunda güncelleme yap
            try {
              await docRef.update({
                'isAnalyzing': false,
                'isAnalyzed': true,
                'errorMessage': _errorMessage ?? 'Analiz sonucu alınamadı',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } catch (updateError) {
              _logger.e('Analiz başarısız - Firestore güncelleme hatası: ${updateError.toString()}', updateError);
            }
            
            // Yerel listedeki mesajı güncelle
            final index = _messages.indexWhere((m) => m.id == docRef.id);
            if (index != -1) {
              _messages[index] = _messages[index].copyWith(
                isAnalyzing: false,
                isAnalyzed: true,
                errorMessage: _errorMessage ?? 'Analiz sonucu alınamadı',
                analysisSource: AnalysisSource.image, // Analiz kaynağını ayarla
              );
              _currentMessage = _messages[index];
            }
            
            // Hata durumunu bildir
            _isLoading = false;
            _errorMessage ??= 'Analiz sonucu alınamadı';
            notifyListeners();
            
            return false;
          }
        } catch (analysisError) {
          _logger.e('Analiz sırasında beklenmeyen bir hata oluştu: ${analysisError.toString()}', analysisError);
          
          // Hata durumunda Firestore'u güncelle
          try {
            await docRef.update({
              'isAnalyzing': false,
              'isAnalyzed': false,
              'errorMessage': 'Analiz sırasında hata: ${analysisError.toString()}',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            
            // Yerel listedeki mesajı güncelle
            final index = _messages.indexWhere((m) => m.id == docRef.id);
            if (index != -1) {
              _messages[index] = _messages[index].copyWith(
                isAnalyzing: false,
                isAnalyzed: false,
                errorMessage: 'Analiz sırasında hata: ${analysisError.toString()}',
              );
              _currentMessage = _messages[index];
            }
          } catch (updateError) {
            _logger.e('Hata durumunda Firestore güncelleme hatası: ${updateError.toString()}', updateError);
          }
          
          _isLoading = false;
          _errorMessage = 'Analiz sırasında hata oluştu: ${analysisError.toString()}';
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
          'updatedAt': FieldValue.serverTimestamp(),
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
      String content = String.fromCharCodes(bytes);
      
      if (content.isEmpty) {
        _logger.e('Metin dosyası boş');
        _errorMessage = 'Metin dosyası boş';
        _isLoading = false;
        notifyListeners();
        return null;
      }
      
      // TXT İÇERİĞİNİ TEMİZLE - Firestore invalid-argument hatalarını önlemek için
      try {
        _logger.i('Metin içeriği temizleniyor...');
        
        // Metin içeriğini satırlara ayır ve sorunlu satırları temizle
        List<String> lines = content.split('\n');
        List<String> cleanLines = [];
        
        for (int i = 0; i < lines.length; i++) {
          String line = lines[i];
          
          // Boş satırları atla
          if (line.trim().isEmpty) {
            continue;
          }
          
          // Unicode karakterleri temizle - potansiyel sorunlu emojiler veya bozuk karakterler
          try {
            // Özel Unicode karakter kontrolü
            line = line.replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'), ''); // Kontrol karakterleri
          } catch (e) {
            _logger.w('Unicode temizleme hatası satır $i: $e');
            // Sorunlu karakterleri temizleyemiyorsak, satırı atlayalım
            continue;
          }
          
          cleanLines.add(line);
        }
        
        // Temizlenmiş içeriği tekrar birleştir
        content = cleanLines.join('\n');
        
        // Sonuç çok kısaysa uyarı
        if (content.isEmpty) {
          _logger.e('Temizleme sonrası metin içeriği boş kaldı');
          _errorMessage = 'Metin içeriği geçersiz karakterler içeriyor veya çok kısa';
          _isLoading = false;
          notifyListeners();
          return null;
        }
        
        _logger.i('Metin içeriği başarıyla temizlendi: ${content.length} karakter');
      } catch (cleanError) {
        _logger.e('Metin temizleme hatası', cleanError);
        // Temizleme hatası olsa bile devam ediyoruz, çünkü belki dosya zaten temizdir
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
      
      // Analiz sonucunu Firestore'a kaydet (şifreli)
      final messageRef = _firestore.collection('users').doc(userId).collection('messages').doc(message.id);
      final encryptedAnalysisResult = EncryptionService().encryptJson(analysisResult.toMap());
      await messageRef.update({
        'isAnalyzing': false,
        'isAnalyzed': true,
        'analysisResult': encryptedAnalysisResult,
        'updatedAt': FieldValue.serverTimestamp(),
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
      
      // Ana sayfayı güncelle
      try {
        if (_profileViewModel?.context != null && _profileViewModel!.context!.mounted) {
          final homeController = Provider.of<HomeController>(_profileViewModel!.context!, listen: false);
          await homeController.anaSayfayiGuncelle();
          _logger.i('Ana sayfa veri temizleme sonrası güncellendi');
        }
      } catch (e) {
        _logger.w('Ana sayfayı güncelleme hatası: $e');
      }
      
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
        'updatedAt': FieldValue.serverTimestamp(),
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
    
    // Mesaj Koçu analizlerini de temizle
    final messageCoachRef = userRef.collection('message_coach_analyses');
    final messageCoachSnapshot = await messageCoachRef.get();
    
    // Her bir mesaj koçu analizini sil
    for (var doc in messageCoachSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    // Batch işlemini uygula
    await batch.commit();
    
    // MessageCoachController'daki verileri sıfırla
    try {
      if (_profileViewModel?.context != null) {
        final messageCoachController = Provider.of<MessageCoachController>(_profileViewModel!.context!, listen: false);
        messageCoachController.analizSonuclariniSifirla();
        messageCoachController.analizGecmisiniSifirla();
        _logger.i('MessageCoachController verileri başarıyla sıfırlandı');
      }
    } catch (e) {
      _logger.w('MessageCoachController sıfırlama hatası: $e');
    }
  }

  // Mevcut analiz işlemlerini sıfırla
  void resetCurrentAnalysis() {
    _logger.i('Mevcut analiz durumu sıfırlanıyor');
    _currentMessage = null;
    _currentAnalysisResult = null;
    _isAnalysisCancelled = false;
    notifyListeners();
  }
  
  // Analizi iptal et
  void cancelAnalysis() {
    _logger.i('MessageViewModel: Analiz iptal ediliyor');
    _isAnalysisCancelled = true;
    _isLoading = false;
    _aiService.cancelAnalysis(); // AiService'deki analizi de iptal et
    notifyListeners();
  }

  // Analiz sonucunu kullanıcı profiline kaydetme (dışarıdan erişilebilir)
  Future<void> updateUserProfileWithAnalysis(String userId, analysis.AnalysisResult analysisResult, AnalysisType analysisType) async {
    try {
      _logger.i('${analysisType.name} analiz sonucu kullanıcı profiline kaydediliyor: $userId');
      
      // Sadece Mesaj Analizi türlerinin (görsel, txt dosyası ve danışma) ana sayfayı güncellemesine izin ver
      // Diğer analiz türleri için ana sayfayı güncelleme
      if (analysisType != AnalysisType.image && 
          analysisType != AnalysisType.txtFile && 
          analysisType != AnalysisType.consultation) {
        _logger.i('${analysisType.name} için kullanıcı profili güncellenmeyecek');
        return;
      }
      
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
      
      // ÖNEMLİ: Danışma sonuçlarını analyses koleksiyonuna da kaydet
      if (analysisType == AnalysisType.consultation) {
        try {
          // Analiz sonucunu analyses koleksiyonuna ekle (şifreli)
          final encryptedAnalysisData = EncryptionService().encryptJson(analysisResult.toMap());
          await userRef.collection('analyses').doc(analysisResult.id).set({
            'encryptedData': encryptedAnalysisData,
            'type': analysisType.toString(),
            'createdAt': FieldValue.serverTimestamp(),
          });
          _logger.i('Danışma analiz sonucu şifreli olarak analyses koleksiyonuna kaydedildi.');
        } catch (e) {
          _logger.e('Danışma sonucu analyses koleksiyonuna kaydedilirken hata: $e');
        }
      }
      
      
      // Analiz hizmeti ile ilişki durumunu analiz et
      final analizSonucuMap = await _aiService.iliskiDurumuAnaliziYap(userId, analizVerileri);
      
      // Map'i AnalizSonucu nesnesine dönüştür
      final AnalizSonucu analizSonucu = AnalizSonucu.fromMap(analizSonucuMap);
      
      
      // Firestore'a kaydet (şifreli)
      final encryptedSonAnalizSonucu = EncryptionService().encryptJson(analizSonucu.toMap());
      final encryptedAnalizVerisi = EncryptionService().encryptJson(analizSonucu.toMap());
      await userRef.update({
        'sonAnalizSonucu': encryptedSonAnalizSonucu,
        'analizGecmisi': FieldValue.arrayUnion([encryptedAnalizVerisi]),
      });
      
      _logger.i('Kullanıcı profili başarıyla güncellendi. İlişki puanı: ${analizSonucu.iliskiPuani}');
      
      // Ana sayfayı güncelle - HomeController ile güvenli bir şekilde
      try {
        // Null-aware operatör kullanarak context değerine erişiyoruz
        final context = _profileViewModel?.context;
        if (context != null && context.mounted) {
          try {
            final homeController = Provider.of<HomeController>(context, listen: false);
            await homeController.anaSayfayiGuncelle();
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
      _logger.e('Analiz sonucu kullanıcı profiline kaydedilirken hata oluştu', e);
    }
  }

  // Kullanıcının belirli tipteki analiz sonuçlarını getir
  Future<List<analysis.AnalysisResult>> getUserAnalysisResults(String userId, {AnalysisType? analysisType}) async {
    List<analysis.AnalysisResult> results = [];
    
    try {
      final userDocRef = _firestore.collection('users').doc(userId);
      
      // Önce kullanıcının olup olmadığını kontrol et
      final userDoc = await userDocRef.get();
      if (!userDoc.exists) {
        return [];
      }
      
      // Analizler alt koleksiyonunu al
      QuerySnapshot querySnapshot;
      if (analysisType != null) {
        // Belirli tipteki analizleri getir
        querySnapshot = await userDocRef
            .collection('analyses')
            .where('type', isEqualTo: analysisType.toString())
            .orderBy('createdAt', descending: true)
            .get();
      } else {
        // Tüm analizleri getir
        querySnapshot = await userDocRef
            .collection('analyses')
            .orderBy('createdAt', descending: true)
            .get();
      }
      
      // Analiz sonuçlarını dön
      results = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return analysis.AnalysisResult.fromMap(data);
      }).toList();
      
      return results;
    } catch (e) {
      _logger.e('Analiz sonuçları getirilirken hata: $e');
      return [];
    }
  }

  // Yardımcı Fonksiyonlar
  
 

  
  }