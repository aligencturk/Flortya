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

class MessageViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AiService _aiService = AiService();
  final LoggerService _logger = LoggerService();
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  
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
    try {
      _isLoading = true;
      notifyListeners();
      
      if (userId.isEmpty) {
        _errorMessage = 'Oturumunuz bulunamadı. Lütfen tekrar giriş yapın.';
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      print('Mesajlar yükleniyor. Kullanıcı ID: $userId');
      
      QuerySnapshot snapshot = await _firestore
          .collection('messages')
          .where('userId', isEqualTo: userId)
          .orderBy('sentAt', descending: true)
          .get();
      
      _messages = snapshot.docs.map((doc) {
        // Belge ID'sini direkt olarak ilet ve bunu map'e de ekle
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        // Document ID'yi map'e ekle - bu çok önemli
        data['id'] = doc.id;  
        return Message.fromMap(data, docId: doc.id);
      }).toList();
      
      print('${_messages.length} mesaj yüklendi. İlk mesaj ID: ${_messages.isNotEmpty ? _messages.first.id : "yok"}');
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Mesajlar yüklenirken bir hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Yeni mesaj ekleme
  Future<String> addMessage(String content, {String? imageUrl}) async {
    try {
      final userId = _authService.currentUser?.uid;
      
      if (userId == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Önce Firestore'a ekleyip belge ID'sini alalım
      DocumentReference docRef = await _firestore.collection('messages').add({
        'content': content,
        'sentAt': Timestamp.now(),
        'sentByUser': true,
        'isAnalyzed': false,
        'userId': userId,
        'imageUrl': imageUrl,
      });

      // Belge ID'sini alıp, mesaj nesnesini oluşturalım
      final message = Message(
        id: docRef.id, // Firestore'un oluşturduğu ID
        content: content,
        sentAt: DateTime.now(),
        sentByUser: true,
        isAnalyzed: false,
        imageUrl: imageUrl,
        userId: userId,
      );
      
      // Mesajı yerel listeye ekleyelim
      _messages.insert(0, message);
      notifyListeners();
      
      print('Yeni mesaj eklendi. ID: ${message.id}');
      return message.id; // ID'yi döndür
    } catch (e) {
      _errorMessage = 'Mesaj eklenirken bir hata oluştu: $e';
      notifyListeners();
      rethrow;
    }
  }

  // Belirli bir mesajı alma
  Future<Message?> getMessage(String messageId) async {
    if (messageId.isEmpty) {
      print('HATA: getMessage - Boş messageId ile çağrıldı');
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
      print('Mesaj yerel listede bulunamadı. Firestore\'dan çekiliyor. ID: $messageId');
      final doc = await _firestore.collection('messages').doc(messageId).get();
      
      if (doc.exists) {
        // Doküman verilerini al ve ID değerini ekleyerek mesaj oluştur
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        // Document ID'yi map'e ekle
        data['id'] = doc.id;
        
        _currentMessage = Message.fromMap(data, docId: doc.id);
        notifyListeners();
        return _currentMessage;
      } else {
        print('HATA: $messageId ID\'li mesaj Firestore\'da bulunamadı.');
        _setError('Mesaj bulunamadı');
        return null;
      }
    } catch (e) {
      print('HATA: Mesaj alınırken hata oluştu: $e');
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
    if (messageId.isEmpty) {
      notifyListeners();
      _errorMessage = 'Geçersiz mesaj ID';
      _isLoading = false;
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      print('Mesaj analizi başlatılıyor. Mesaj ID: $messageId');
      
      // Önce yerel mesaj listesinde ara
      Message? message = _messages.firstWhere((m) => m.id == messageId, 
                                          orElse: () => Message(id: '', content: '', sentAt: DateTime.now(),
                                          sentByUser: false, userId: ''));
      
      // Eğer mesaj bulunamadıysa veya ID boşsa, Firestore'dan getir
      if (message.id.isEmpty) {
        print('Mesaj yerel listede bulunamadı. Firestore\'dan getiriliyor...');
        final DocumentSnapshot docSnapshot = await _firestore.collection('messages').doc(messageId).get();
        
        if (!docSnapshot.exists) {
          print('HATA: Mesaj Firestore\'da bulunamadı. ID: $messageId');
          _errorMessage = 'Mesaj bulunamadı';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        
        final Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        data['id'] = docSnapshot.id; // Belge ID'sini ekleyelim
        message = Message.fromMap(data, docId: docSnapshot.id);
      }
      
      // Mesajı işaretleyerek analiz edildiğini belirt
      final updatedMessage = message.copyWith(isAnalyzing: true);
      
      // Yerel listeyi güncelle
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        _messages[index] = updatedMessage;
      } else {
        _messages.add(updatedMessage);
      }
      notifyListeners();

      // AI servisi ile analiz et
      final analysisResult = await _aiService.analyzeMessage(message.content);

      // Firestore'da güncelle
      await _firestore.collection('messages').doc(messageId).update({
        'analysisResult': analysisResult?.toMap(),
        'isAnalyzing': false,
        'isAnalyzed': true,
      });

      // Başarılı analiz sonrası mesajı güncelle
      final finalMessage = message.copyWith(
        analysisResult: analysisResult,
        isAnalyzing: false,
        isAnalyzed: true,
      );
      
      // Yerel listeyi güncelle
      final finalIndex = _messages.indexWhere((m) => m.id == messageId);
      if (finalIndex >= 0) {
        _messages[finalIndex] = finalMessage;
      }
      
      // Mevcut mesaj ve sonucu ayarla
      _currentMessage = finalMessage;
      _currentAnalysisResult = analysisResult;
      
      notifyListeners();
      
      print('Mesaj analizi tamamlandı. Mesaj ID: $messageId');
      return true;
    } catch (e) {
      print('HATA: Mesaj analizi sırasında hata oluştu: $e');
      
      // Hata durumunda mesajı güncelle
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        _messages[index] = _messages[index].copyWith(
          isAnalyzing: false,
          errorMessage: 'Analiz sırasında hata: ${e.toString()}',
        );
      }
      
      _errorMessage = 'Analiz sırasında hata oluştu: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
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
      _errorMessage = 'Görsel yüklenirken hata oluştu: $e';
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
      
      // Yukarıdaki yöntemlerle bulunamadıysa Firestore'dan çek
      final DocumentSnapshot doc = await _firestore.collection('messages').doc(messageId).get();
      
      if (doc.exists) {
        // Doküman verilerini al ve ID değerini ekle
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        // Document ID'yi map'e ekle
        data['id'] = doc.id;
        
        final message = Message.fromMap(data, docId: doc.id);
        
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
    
    _isLoading = true;
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
      _errorMessage = 'Mesaj silinirken hata oluştu: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mevcut mesajı temizleme
  void clearCurrentMessage() {
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