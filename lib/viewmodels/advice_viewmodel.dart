import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../services/logger_service.dart';
import '../models/analysis_result_model.dart';

class AdviceViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AiService _aiService = AiService();
  final LoggerService _logger = LoggerService();
  
  Map<String, dynamic>? _adviceCard;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Chat ile ilgili özellikler
  List<AdviceChat> _chats = [];
  AdviceChat? _currentChat;
  List<ChatMessage> _currentMessages = [];

  // Getters
  Map<String, dynamic>? get adviceCard => _adviceCard;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasAdviceCard => _adviceCard != null;
  
  // Chat getters
  List<AdviceChat> get chats => _chats;
  AdviceChat? get currentChat => _currentChat;
  List<ChatMessage> get currentMessages => _currentMessages;
  bool get hasCurrentChat => _currentChat != null;
  
  // Son alınan tavsiye tarihi için key
  static const String _lastAdviceDateKey = 'last_advice_date';

  // Günlük tavsiye kartını alma
  Future<void> getDailyAdviceCard(String userId) async {
    _setLoading(true);
    try {
      // Önce bugün alınmış bir kart var mı diye kontrol et
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final QuerySnapshot existingSnapshot = await _firestore
          .collection('advice_cards')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      // Bugün alınmış bir kart varsa, onu göster
      if (existingSnapshot.docs.isNotEmpty) {
        _adviceCard = existingSnapshot.docs.first.data() as Map<String, dynamic>;
        _adviceCard!['id'] = existingSnapshot.docs.first.id;
        _logger.i('Mevcut günlük tavsiye kartı bulundu.');
        notifyListeners();
        return;
      }
      
      // Yeni tavsiye kartı al
      _logger.i('Yeni günlük tavsiye kartı alınıyor.');
      final advice = await _aiService.getDailyAdviceCard(userId);
      
      if (advice.containsKey('error')) {
        _setError(advice['error']);
        return;
      }
      
      // Kullanıcı ID'si ekle
      advice['userId'] = userId;
      
      // Firestore'a kaydet
      final docRef = await _firestore.collection('advice_cards').add(advice);
      
      // ID'yi ekle
      advice['id'] = docRef.id;
      
      // Güncel tavsiyeyi ayarla
      _adviceCard = advice;
      
      _logger.i('Yeni günlük tavsiye kartı alındı.');
      notifyListeners();
    } catch (e) {
      _setError('Tavsiye kartı alınırken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Tavsiye geçmişini alma
  Future<List<Map<String, dynamic>>> getAdviceHistory(String userId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('advice_cards')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      
      final List<Map<String, dynamic>> history = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      
      return history;
    } catch (e) {
      _setError('Tavsiye geçmişi alınırken hata oluştu: $e');
      return [];
    }
  }
  
  // İlişki tavsiyesi chat fonksiyonları
  
  // Kullanıcının sohbetlerini yükleme
  Future<void> loadChats(String userId) async {
    _setLoading(true);
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('advice_chats')
          .where('userId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .get();
      
      _chats = snapshot.docs
          .map((doc) => AdviceChat.fromFirestore(doc))
          .toList();
      
      _logger.i('Sohbetler yüklendi. Toplam: ${_chats.length}');
      notifyListeners();
    } catch (e) {
      _setError('Sohbetler yüklenirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Yeni sohbet oluşturma
  Future<String?> createChat(String userId, String initialMessage) async {
    _setLoading(true);
    try {
      // Yeni belge referansı oluştur
      final docRef = _firestore.collection('advice_chats').doc();
      final timestamp = DateTime.now();
      
      // İlk kullanıcı mesajını oluştur
      final userMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        content: initialMessage,
        role: 'user',
        timestamp: timestamp,
      );
      
      // Yeni sohbet nesnesi
      final chat = AdviceChat(
        id: docRef.id,
        userId: userId,
        messages: [userMessage],
        createdAt: timestamp,
        updatedAt: timestamp,
        title: _generateChatTitle(initialMessage),
      );
      
      // Firestore'a kaydet
      await docRef.set(chat.toMap());
      
      // Sohbeti yükle ve API'den cevap al
      _currentChat = chat;
      _currentMessages = [userMessage];
      notifyListeners();
      
      // AI'dan cevap al
      await sendMessage(userId, initialMessage, chat.id);
      
      _logger.i('Yeni sohbet oluşturuldu. ID: ${chat.id}');
      return chat.id;
    } catch (e) {
      _setError('Sohbet oluşturulurken hata oluştu: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  // Sohbete mesaj gönderme
  Future<void> sendMessage(String userId, String content, String chatId) async {
    _setLoading(true);
    try {
      _logger.i('Mesaj gönderiliyor. ChatID: $chatId');
      
      // Kullanıcı mesajı
      final userMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        content: content,
        role: 'user',
        timestamp: DateTime.now(),
      );
      
      // API'ye göndermek için sohbet geçmişini hazırla
      final chatHistory = _currentMessages.map((m) => m.toApiFormat()).toList();
      
      // Kullanıcı mesajını Firestore'a ekle
      if (_currentChat == null || _currentChat!.id != chatId) {
        await loadChat(chatId);
      }
      
      // Kullanıcı mesajını geçici olarak listeye ekle
      _currentMessages.add(userMessage);
      notifyListeners();
      
      // AI'dan cevap al
      final response = await _aiService.getRelationshipAdvice(content, chatHistory);
      
      if (response.containsKey('error')) {
        _setError(response['error']);
        return;
      }
      
      // AI cevabını oluştur
      final modelMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'ai',
        content: response['answer'],
        role: 'model',
        timestamp: DateTime.now(),
      );
      
      // Mesajları Firestore'a kaydet
      final batch = _firestore.batch();
      
      // Güncellenmiş mesaj listesini oluştur
      final updatedMessages = [..._currentMessages, modelMessage];
      
      // Sohbeti güncelle
      final updatedChat = AdviceChat(
        id: chatId,
        userId: userId,
        messages: updatedMessages,
        createdAt: _currentChat!.createdAt,
        updatedAt: DateTime.now(),
        title: _currentChat!.title,
      );
      
      // Firestore belgesini güncelle
      batch.set(_firestore.collection('advice_chats').doc(chatId), updatedChat.toMap());
      await batch.commit();
      
      // Yerel durumu güncelle
      _currentChat = updatedChat;
      _currentMessages = updatedMessages;
      
      // Chat listesini güncelle
      final index = _chats.indexWhere((c) => c.id == chatId);
      if (index != -1) {
        _chats[index] = updatedChat;
      } else {
        _chats.insert(0, updatedChat);
      }
      
      _logger.i('Mesaj gönderildi ve cevap alındı. ChatID: $chatId');
      notifyListeners();
    } catch (e) {
      _setError('Mesaj gönderilirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Belirli bir sohbeti yükleme
  Future<void> loadChat(String chatId) async {
    _setLoading(true);
    try {
      final DocumentSnapshot doc = await _firestore.collection('advice_chats').doc(chatId).get();
      
      if (doc.exists) {
        _currentChat = AdviceChat.fromFirestore(doc);
        _currentMessages = _currentChat!.messages;
        _logger.i('Sohbet yüklendi. ID: $chatId, Mesaj sayısı: ${_currentMessages.length}');
        notifyListeners();
      } else {
        _setError('Sohbet bulunamadı');
      }
    } catch (e) {
      _setError('Sohbet yüklenirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Sohbeti silme
  Future<void> deleteChat(String chatId) async {
    _setLoading(true);
    try {
      // Firestore'dan sil
      await _firestore.collection('advice_chats').doc(chatId).delete();
      
      // Yerel listeden kaldır
      _chats.removeWhere((chat) => chat.id == chatId);
      
      // Eğer mevcut sohbet buysa temizle
      if (_currentChat?.id == chatId) {
        _currentChat = null;
        _currentMessages = [];
      }
      
      _logger.i('Sohbet silindi. ID: $chatId');
      notifyListeners();
    } catch (e) {
      _setError('Sohbet silinirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Sohbet başlığı oluşturma
  String _generateChatTitle(String message) {
    // Kısa mesajları doğrudan başlık olarak kullan
    if (message.length < 30) {
      return message;
    }
    
    // Uzun mesajları kısalt
    return '${message.substring(0, 27)}...';
  }
  
  // Mevcut sohbeti temizleme
  void clearCurrentChat() {
    _currentChat = null;
    _currentMessages = [];
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