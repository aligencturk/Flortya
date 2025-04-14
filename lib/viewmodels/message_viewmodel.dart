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
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('messages')
          .where('userId', isEqualTo: userId)
          .orderBy('sentAt', descending: true)
          .get();
      
      _messages = snapshot.docs
          .map((doc) => Message.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      
      notifyListeners();
    } catch (e) {
      _setError('Mesajlar yüklenirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Yeni mesaj ekleme
  Future<void> addMessage(Message message) async {
    _setLoading(true);
    try {
      _logger.i('Yeni mesaj ekleniyor. ID: ${message.id}');
      
      // Firestore'a kaydet
      await _firestore.collection('messages').doc(message.id).set(message.toMap());
      
      // Mesajı listeye ekle
      _messages.insert(0, message);
      
      // Mevcut mesajı ayarla
      _currentMessage = message;
      
      _logger.i('Mesaj başarıyla eklendi. ID: ${message.id}');
      
      notifyListeners();
    } catch (e) {
      _setError('Mesaj eklenirken hata oluştu: $e');
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

  // Mesajı analiz etme
  Future<void> analyzeMessage(Message message) async {
    _setLoading(true);
    _currentAnalysisResult = null;
    try {
      _logger.i('Mesaj analizi başlatılıyor. ID: ${message.id}');
      
      final result = await _aiService.analyzeMessage(message.content);
      
      if (result != null) {
        _currentAnalysisResult = result;
        
        // Mesajı güncelle
        final updatedMessage = message.copyWith(
          isAnalyzed: true,
          analysisResult: result
        );
        
        // Firestore'da güncelle
        await _firestore.collection('messages').doc(message.id).update({
          'isAnalyzed': true,
          'analysisResult': result.toMap(),
        });
        
        // Mesajları güncelle
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = updatedMessage;
        }
        
        _currentMessage = updatedMessage;
        
        _logger.i('Mesaj analizi tamamlandı. ID: ${message.id}');
        
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

  // Mesaj görselini yükleme
  Future<void> uploadMessageImage(String messageId, File imageFile) async {
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
  void _setError(String error) {
    _errorMessage = error;
    _logger.e(error);
    notifyListeners();
  }

  // Hata mesajını temizleme
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
} 