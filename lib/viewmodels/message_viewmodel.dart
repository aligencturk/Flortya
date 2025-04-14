import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../models/analysis_result_model.dart';
import '../services/ai_service.dart';

class MessageViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AiService _aiService = AiService();
  
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
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('messages')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();
      
      _messages = snapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .toList();
      
      notifyListeners();
    } catch (e) {
      _setError('Mesajlar yüklenirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Yeni mesaj oluşturma
  Future<void> createMessage(String userId, String content) async {
    _setLoading(true);
    try {
      // Gönderme zamanını al
      final timestamp = DateTime.now();
      
      // Yeni belge referansı oluştur
      final docRef = _firestore.collection('messages').doc();
      
      // Mesaj nesnesini oluştur
      final message = Message(
        id: docRef.id,
        userId: userId,
        content: content,
        timestamp: timestamp,
      );
      
      // Firestore'a kaydet
      await docRef.set(message.toFirestore());
      
      // Mesajı listeye ekle
      _messages.insert(0, message);
      
      // Mevcut mesajı ayarla
      _currentMessage = message;
      
      notifyListeners();
    } catch (e) {
      _setError('Mesaj oluşturulurken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Belirli bir mesajı alma
  Future<void> getMessage(String messageId) async {
    _setLoading(true);
    try {
      final DocumentSnapshot doc = await _firestore.collection('messages').doc(messageId).get();
      
      if (doc.exists) {
        _currentMessage = Message.fromFirestore(doc);
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

  // Mesajı analiz etme
  Future<void> analyzeMessage(Message message) async {
    _setLoading(true);
    _currentAnalysisResult = null;
    try {
      final result = await _aiService.analyzeMessage(message);
      
      if (result != null) {
        _currentAnalysisResult = result;
        _currentMessage = message.copyWith(isAnalyzed: true);
        
        // Mesajları güncelle
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = _currentMessage!;
        }
        
        notifyListeners();
      } else {
        _setError('Mesaj analiz edilemedi');
      }
    } catch (e) {
      _setError('Mesaj analizi sırasında hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Mesaj analiz sonucunu alma
  Future<void> getAnalysisResult(String messageId) async {
    _setLoading(true);
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('analysis_results')
          .where('messageId', isEqualTo: messageId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        _currentAnalysisResult = AnalysisResult.fromFirestore(snapshot.docs.first);
        notifyListeners();
      } else {
        _setError('Analiz sonucu bulunamadı');
      }
    } catch (e) {
      _setError('Analiz sonucu alınırken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Mesajı silme
  Future<void> deleteMessage(String messageId) async {
    _setLoading(true);
    try {
      // Mesajı Firestore'dan sil
      await _firestore.collection('messages').doc(messageId).delete();
      
      // İlişkili analiz sonuçlarını bul ve sil
      final QuerySnapshot analysisSnapshot = await _firestore
          .collection('analysis_results')
          .where('messageId', isEqualTo: messageId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in analysisSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
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
  void _setError(String error) {
    _errorMessage = error;
    debugPrint(error);
    notifyListeners();
  }

  // Hata mesajını temizleme
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
} 