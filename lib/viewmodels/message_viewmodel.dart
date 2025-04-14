import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/message.dart';
import '../models/analysis_result_model.dart';
import '../services/ai_service.dart';
import '../services/logger_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

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
  
  // İlk yükleme denemesinin yapılıp yapılmadığını takip eden bayrak (static değil)
  bool _isFirstLoadCompleted = false;
  
  List<Message> _messages = [];
  Message? _currentMessage;
  AnalysisResult? _currentAnalysisResult;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Message> get messages => _messages;
  Message? get currentMessage => _currentMessage;
  AnalysisResult? get currentAnalysisResult => _currentAnalysisResult;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasCurrentMessage => _currentMessage != null;
  bool get hasAnalysisResult => _currentAnalysisResult != null;
  bool get isFirstLoadCompleted => _isFirstLoadCompleted;

  // Mesajları yükleme işlemi
  Future<void> loadMessages(String userId) async {
    // İlk yükleme denemesi zaten yapıldıysa veya şu anda yükleniyorsa tekrar yapma
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
        if (snapshot != null && snapshot.docs.isNotEmpty) {
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
      });
      
      // Yerel listedeki mesajı güncelle
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isAnalyzing: false,
          isAnalyzed: true,
          analysisResult: analysisResult,
          errorMessage: null,
        );
        _currentMessage = _messages[index];
        // Geçerli analiz sonucunu da güncelle
        _currentAnalysisResult = analysisResult;
      }
      
      _logger.i('Mesaj analizi tamamlandı: $messageId');
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

  // Mesaj görselini yükleme
  Future<void> uploadMessageImage(String messageId, File imageFile) async {
    // ID boş kontrolü ekle
    if (messageId.isEmpty) {
      _errorMessage = 'Görsel yükleme için geçersiz mesaj ID';
      return;
    }
    
    if (imageFile == null) {
      _errorMessage = 'Yüklenecek görsel bulunamadı';
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

  // Mesaj analiz sonucunu alma
  Future<AnalysisResult?> getAnalysisResult(String messageId) async {
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
        // Doküman verilerini al ve ID değerini ekle
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
    // Eğer zaten null ise gereksiz bildirim yapma
    if (_currentMessage == null && _currentAnalysisResult == null) {
      return;
    }
    
    _currentMessage = null;
    _currentAnalysisResult = null;
    notifyListeners();
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
} 