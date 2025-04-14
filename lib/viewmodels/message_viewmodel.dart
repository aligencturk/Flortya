import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/message.dart';
import '../models/analysis_result_model.dart';
import '../services/ai_service.dart';
import '../services/logger_service.dart';
import '../services/notification_service.dart';

class MessageViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AiService _aiService = AiService();
  final LoggerService _logger = LoggerService();
  final NotificationService _notificationService = NotificationService();
  
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

  // Kullanıcının mesajlarını yükleme
  Future<void> loadMessages(String userId) async {
    _setLoading(true);
    
    // UserId kontrolü
    if (userId.isEmpty) {
      _setError('Mesajları yüklemek için kullanıcı kimliği gerekli');
      _setLoading(false);
      return;
    }
    
    // Önceki mesaj ve analiz sonucunu temizle
    clearCurrentMessage();
    
    try {
      _logger.i('Mesajlar yükleniyor. UserId: $userId');
      
      final QuerySnapshot snapshot = await _firestore
          .collection('messages')
          .where('userId', isEqualTo: userId)
          .orderBy('sentAt', descending: true)
          .get();
      
      _messages = snapshot.docs
          .map((doc) {
            // Doküman verilerini al ve ID değerini ekle
            final data = doc.data() as Map<String, dynamic>;
            // Firestore döküman ID'sini mesaj ID'si olarak atayalım
            data['id'] = doc.id;
            return Message.fromMap(data);
          })
          .toList();
      
      _logger.i('Mesajlar yüklendi. Toplam: ${_messages.length}');
      notifyListeners();
    } catch (e) {
      _logger.e('Mesajlar yüklenirken hata oluştu: $e');
      _setError('Mesajlar yüklenirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Yeni mesaj ekleme
  Future<void> addMessage(String content, String userId) async {
    if (content.trim().isEmpty) {
      _setError('Mesaj boş olamaz');
      return;
    }
    
    if (userId.isEmpty) {
      _setError('Mesaj eklemek için kullanıcı kimliği gerekli');
      return;
    }
    
    _setLoading(true);
    _setError(null);
    
    try {
      // Yeni mesaj oluştur
      final message = Message(
        id: '',  // Firestore tarafından otomatik atanacak
        content: content,
        sentAt: DateTime.now(),
        sentByUser: true,
        userId: userId,
      );
      
      // Firestore'a ekle
      final Map<String, dynamic> messageData = message.toMap();
      // id alanını Firestore'a gönderirken hariç tutalım, Firestore otomatik oluşturacak
      messageData.remove('id');
      
      DocumentReference docRef = await _firestore.collection('messages').add(messageData);
      
      // ID ile birlikte mesajı güncelle
      final messageWithId = message.copyWith(id: docRef.id);
      
      // Mesajı yerel listeye ekle
      _messages.insert(0, messageWithId);
      
      // Mevcut mesajı güncelle
      _currentMessage = messageWithId;
      
      _logger.i('Yeni mesaj eklendi. ID: ${docRef.id}');
      notifyListeners();
      
      // Mesajı analiz et
      await analyzeMessage(docRef.id);
      
    } catch (e) {
      _logger.e('Mesaj eklenirken hata oluştu: $e');
      _setError('Mesaj eklenirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Belirli bir mesajı alma
  Future<void> getMessage(String messageId) async {
    // ID boş kontrolü ekle
    if (messageId.isEmpty) {
      _setError('Geçersiz mesaj ID');
      return;
    }
    
    _setLoading(true);
    _logger.i('Mesaj alınıyor. ID: $messageId');
    
    // Önceki analiz sonucunu temizle
    _currentAnalysisResult = null;
    
    try {
      // Önce yerel olarak arayalım
      final localMessage = _messages.firstWhere(
        (msg) => msg.id == messageId,
        orElse: () => null as Message,
      );
      
      if (localMessage != null) {
        _logger.i('Mesaj yerel listede bulundu. ID: $messageId');
        _currentMessage = localMessage;
        notifyListeners();
        return;
      }
      
      // Yerel listede bulunamadıysa Firestore'dan alalım
      final DocumentSnapshot doc = await _firestore.collection('messages').doc(messageId).get();
      
      if (doc.exists) {
        // Doküman verilerini al ve ID değerini ekle
        final data = doc.data() as Map<String, dynamic>;
        
        // Firestore döküman ID'sini mesaj ID'si olarak atayalım
        if (!data.containsKey('id') || data['id'] == null || data['id'].toString().isEmpty) {
          _logger.w('Firestore mesajında ID alanı eksik. Döküman ID kullanılıyor: ${doc.id}');
          data['id'] = doc.id;
        }
        
        _currentMessage = Message.fromMap(data);
        
        // Mesaj yerel listede yoksa ekleyelim
        if (!_messages.any((m) => m.id == _currentMessage!.id)) {
          _messages.add(_currentMessage!);
          _logger.i('Mesaj yerel listeye eklendi. ID: ${_currentMessage!.id}');
        }
        
        notifyListeners();
      } else {
        _logger.e('Mesaj bulunamadı. ID: $messageId');
        _setError('Mesaj bulunamadı');
      }
    } catch (e) {
      _logger.e('Mesaj alınırken hata oluştu: $e');
      _setError('Mesaj alınırken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Yeni bir analiz başlatırken önceki analiz sonuçlarını temizleme
  void _startNewAnalysis() {
    _currentMessage = null;
    _currentAnalysisResult = null;
    notifyListeners();
  }

  // Mesajı analiz etme
  Future<void> analyzeMessage(String messageId) async {
    try {
      // Mesaj ID'si boş mu kontrol et
      if (messageId.isEmpty) {
        print('HATA: analyzeMessage fonksiyonuna boş messageId gönderildi');
        _notificationService.showErrorNotification('Mesaj analizi başarısız', 'Geçersiz mesaj ID');
        return;
      }

      // Önce mesajı bul
      Message? targetMessage;
      
      // Önce yerel liste içinde ara
      targetMessage = _messages.firstWhere(
        (msg) => msg.id == messageId,
        orElse: () => Message(
          id: '',
          content: '',
          sentAt: DateTime.now(),
          sentByUser: true,
        ),
      );
      
      // Mesaj bulunamadıysa
      if (targetMessage.id.isEmpty) {
        print('HATA: $messageId ID\'li mesaj bulunamadı');
        _notificationService.showErrorNotification('Mesaj analizi başarısız', 'Mesaj bulunamadı');
        return;
      }
      
      // UI için yükleniyor durumunu ayarla
      _isLoading = true;
      notifyListeners();
      
      print('$messageId ID\'li mesaj analiz ediliyor...');
      
      // AI servisi ile analiz et
      final analysisResult = await _aiService.analyzeMessage(targetMessage.content);
      
      if (analysisResult != null) {
        // Mesajı güncelle
        final updatedMessage = targetMessage.copyWith(
          isAnalyzed: true,
          analysisResult: analysisResult,
        );
        
        // Firestore'u güncelle
        await _firestore.collection('messages').doc(messageId).update({
          'isAnalyzed': true,
          'analysisResult': analysisResult.toMap(),
        });
        
        print('$messageId ID\'li mesaj başarıyla analiz edildi ve Firestore güncellendi');
        
        // Yerel listeyi güncelle
        final index = _messages.indexWhere((msg) => msg.id == messageId);
        if (index != -1) {
          _messages[index] = updatedMessage;
          _currentMessage = updatedMessage;
          notifyListeners();
        }
        
        _notificationService.showSuccessNotification('Analiz tamamlandı', 'Mesaj başarıyla analiz edildi');
      } else {
        print('HATA: $messageId ID\'li mesaj için AI analizi başarısız oldu');
        _notificationService.showErrorNotification('Analiz başarısız', 'AI servisi mesajı analiz edemedi');
      }
    } catch (e) {
      print('HATA: Mesaj analizi sırasında beklenmeyen hata: $e');
      _notificationService.showErrorNotification('Analiz başarısız', 'Beklenmeyen hata: $e');
    } finally {
      // Yükleniyor durumunu temizle
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mesaj görselini yükleme
  Future<void> uploadMessageImage(String messageId, File imageFile) async {
    // ID boş kontrolü ekle
    if (messageId.isEmpty) {
      _setError('Görsel yükleme için geçersiz mesaj ID');
      return;
    }
    
    if (imageFile == null) {
      _setError('Yüklenecek görsel bulunamadı');
      return;
    }
    
    try {
      _logger.i('Mesaj görseli yükleniyor. ID: $messageId');
      
      // Storage referansı oluştur
      final storageRef = _storage.ref().child('message_images/$messageId.jpg');
      
      // Görseli yükle
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() => null);
      
      // İndirme URL'sini al
      final imageUrl = await snapshot.ref.getDownloadURL();
      
      // Firestore'da mesajı güncelle
      await _firestore.collection('messages').doc(messageId).update({
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
      
      notifyListeners();
    } catch (e) {
      _setError('Görsel yüklenirken hata oluştu: $e');
    }
  }

  // Mesaj analiz sonucunu alma
  Future<void> getAnalysisResult(String messageId) async {
    // ID boş kontrolü ekle
    if (messageId.isEmpty) {
      _setError('Geçersiz mesaj ID');
      return;
    }
    
    _setLoading(true);
    _logger.i('Analiz sonucu alınıyor. ID: $messageId');
    
    try {
      // Önce mevcut mesaj varsa ve analiz sonucu da varsa direkt kullan
      if (_currentMessage != null && _currentMessage!.id == messageId && _currentMessage!.analysisResult != null) {
        _logger.i('Analiz sonucu mevcut mesajdan alındı. ID: $messageId');
        _currentAnalysisResult = _currentMessage!.analysisResult;
        notifyListeners();
        return;
      }
      
      // Yerel listede bu ID'li mesajı ara
      final localMessage = _messages.firstWhere(
        (msg) => msg.id == messageId && msg.analysisResult != null,
        orElse: () => null as Message,
      );
      
      if (localMessage != null) {
        _logger.i('Analiz sonucu yerel listede bulundu. ID: $messageId');
        _currentAnalysisResult = localMessage.analysisResult;
        notifyListeners();
        return;
      }
      
      // Yukarıdaki yöntemlerle bulunamadıysa Firestore'dan çek
      final DocumentSnapshot doc = await _firestore.collection('messages').doc(messageId).get();
      
      if (doc.exists) {
        // Doküman verilerini al ve ID değerini ekle
        final data = doc.data() as Map<String, dynamic>;
        
        // Firestore döküman ID'sini mesaj ID'si olarak ekle
        if (!data.containsKey('id') || data['id'] == null || data['id'].toString().isEmpty) {
          data['id'] = doc.id;
        }
        
        final message = Message.fromMap(data);
        
        // Mevcut mesajı güncelle
        _currentMessage = message;
        
        if (message.analysisResult != null) {
          _currentAnalysisResult = message.analysisResult;
          _logger.i('Analiz sonucu Firestore\'dan alındı. ID: $messageId');
          notifyListeners();
        } else {
          _logger.w('Analiz sonucu bulunamadı. ID: $messageId');
          _setError('Analiz sonucu bulunamadı');
        }
      } else {
        _logger.e('Mesaj bulunamadı. ID: $messageId');
        _setError('Mesaj bulunamadı');
      }
    } catch (e) {
      _logger.e('Analiz sonucu alınırken hata oluştu: $e');
      _setError('Analiz sonucu alınırken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Mesajı silme
  Future<void> deleteMessage(String messageId) async {
    // ID boş kontrolü ekle
    if (messageId.isEmpty) {
      _setError('Silme işlemi için geçersiz mesaj ID');
      return;
    }
    
    _setLoading(true);
    try {
      // Mesajı Firestore'dan sil
      await _firestore.collection('messages').doc(messageId).delete();
      
      // Varsa resmi sil
      try {
        await _storage.ref().child('message_images/$messageId.jpg').delete();
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
      
      notifyListeners();
    } catch (e) {
      _setError('Mesaj silinirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Mevcut mesajı temizleme
  void clearCurrentMessage() {
    _currentMessage = null;
    _currentAnalysisResult = null;
    notifyListeners();
  }

  // Yükleme durumunu ayarlama
  void _setLoading(bool loading) {
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

  // Tüm mesajları Firebase'den çek
  Future<void> getMessages() async {
    try {
      setLoading(true);
      
      // Firebase'den mesajları al
      final messagesCollection = await FirebaseFirestore.instance
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .get();
      
      // Mesajları listeye dönüştür
      _messages = messagesCollection.docs.map((doc) {
        // Döküman ID'sini doğrudan Message nesnesine geçir
        return Message.fromMap(doc.data(), doc.id);
      }).toList();
      
      print('Mesajlar başarıyla yüklendi. Toplam: ${_messages.length}');
      
      // Test için ilk birkaç mesajın ID'lerini yazdır
      if (_messages.isNotEmpty) {
        for (int i = 0; i < min(3, _messages.length); i++) {
          print('Mesaj $i - ID: "${_messages[i].id}", İçerik: ${_messages[i].content.substring(0, min(20, _messages[i].content.length))}...');
        }
      }
      
      notifyListeners();
    } catch (e) {
      print('Mesajları getirirken hata: $e');
      NotificationService.instance.showErrorNotification('Mesajlar yüklenemedi', 'Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.');
    } finally {
      setLoading(false);
    }
  }
} 