import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/message.dart';
import '../models/analysis_result_model.dart';
import '../services/ai_service.dart';
import '../services/logger_service.dart';

class MessageViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AiService _aiService = AiService();
  final LoggerService _logger = LoggerService();
  
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
          .map((doc) => Message.fromMap(doc.data() as Map<String, dynamic>))
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
      DocumentReference docRef = await _firestore.collection('messages').add(message.toMap());
      
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
    
    // Önceki analiz sonucunu temizle
    _currentAnalysisResult = null;
    
    try {
      final DocumentSnapshot doc = await _firestore.collection('messages').doc(messageId).get();
      
      if (doc.exists) {
        _currentMessage = Message.fromMap(doc.data() as Map<String, dynamic>);
        notifyListeners();
      } else {
        _setError('Mesaj bulunamadı');
      }
    } catch (e) {
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
    // Eğer messageId boşsa işlemi durdur
    if (messageId.isEmpty) {
      _setError('Analiz için geçerli bir mesaj ID\'si gerekli');
      return;
    }
    
    // İlgili mesajı bul
    Message? message;
    try {
      message = _messages.firstWhere((m) => m.id == messageId);
    } catch (e) {
      // Mesaj bulunamadı
    }
    
    if (message == null) {
      _setError('Belirtilen ID ile mesaj bulunamadı: $messageId');
      return;
    }
    
    _setLoading(true);
    try {
      _logger.i('Mesaj analizi başlatılıyor. ID: $messageId');
      
      final result = await _aiService.analyzeMessage(message.content);
      
      if (result != null) {
        // Analiz sonucunu mesaja ekle
        final updatedMessage = message.copyWith(
          analysisResult: result,
          isAnalyzed: true,
        );
        
        // Firestore'da güncelle
        await _firestore.collection('messages').doc(messageId).update({
          'isAnalyzed': true,
          'analysisResult': result.toMap(),
        });
        
        // Mesajlar listesinde güncelle
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          _messages[index] = updatedMessage;
        }
        
        // Mevcut mesajı güncelle
        _currentMessage = updatedMessage;
        
        _logger.i('Mesaj analizi tamamlandı. ID: $messageId');
        
        // UI'ı güncelle
        notifyListeners();
      }
    } catch (e) {
      _logger.e('Mesaj analizi sırasında hata oluştu: $e');
      _setError('Mesaj analizi sırasında hata oluştu: $e');
    } finally {
      _setLoading(false);
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
    try {
      final DocumentSnapshot doc = await _firestore.collection('messages').doc(messageId).get();
      
      if (doc.exists) {
        final message = Message.fromMap(doc.data() as Map<String, dynamic>);
        if (message.analysisResult != null) {
          _currentAnalysisResult = message.analysisResult;
          notifyListeners();
        } else {
          _setError('Analiz sonucu bulunamadı');
        }
      } else {
        _setError('Mesaj bulunamadı');
      }
    } catch (e) {
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
} 