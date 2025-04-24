import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/advice_chat.dart';
import '../models/chat_message.dart';
import '../models/relationship_quote.dart';
import '../services/ai_service.dart';
import '../services/logger_service.dart';
import '../services/notification_service.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class AdviceViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final AiService _aiService;
  final LoggerService _logger;
  final NotificationService _notificationService;
  
  Map<String, dynamic>? _adviceCard;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Chat ile ilgili özellikler
  List<AdviceChat> _chats = [];
  AdviceChat? _currentChat;
  List<ChatMessage> _currentMessages = [];

  // Koç alıntısı ile ilgili özellikler
  RelationshipQuote? _dailyQuote;
  bool _isLoadingQuote = false;
  String? _quoteErrorMessage;
  
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
  // ignore: unused_field
  static const String _lastAdviceDateKey = 'last_advice_date';

  Timer? _dailyAdviceTimer;

  // Getters
  RelationshipQuote? get dailyQuote => _dailyQuote;
  bool get isLoadingQuote => _isLoadingQuote;
  String? get quoteErrorMessage => _quoteErrorMessage;
  bool get hasQuote => _dailyQuote != null;
  
  // Constructor
  AdviceViewModel({
    required FirebaseFirestore firestore,
    required AiService aiService,
    required LoggerService logger,
    required NotificationService notificationService,
  }) : _firestore = firestore,
       _aiService = aiService,
       _logger = logger,
       _notificationService = notificationService;

  // Günlük tavsiye kartını alma
  Future<void> getDailyAdviceCard(String userId) async {
    _setLoading(true);
    try {
      // Her zaman yeni tavsiye kartı al, cache mekanizmasını atlıyoruz
      _logger.i('Yeni günlük tavsiye kartı alınıyor.');
      final advice = await _aiService.getDailyAdviceCard(userId);
      
      if (advice.containsKey('error')) {
        _setError(advice['error']);
        return;
      }
      
      // Kullanıcı ID'si ekle
      advice['userId'] = userId;
      
      // Önce bugün alınmış kartları temizle
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final QuerySnapshot existingSnapshot = await _firestore
          .collection('advice_cards')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      
      // Eski kayıtları sil
      final batch = _firestore.batch();
      for (final doc in existingSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      // Yeni kaydı ekle
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
  
  // Yeni tavsiye alma
  Future<void> getDailyAdvice(String userId, {bool force = false}) async {
    _setLoading(true);
    try {
      // Yeni tavsiye kartı al
      _logger.i('Kullanıcı için yeni tavsiye kartı alınıyor.');
      final advice = await _aiService.getDailyAdviceCard(userId);
      
      if (advice.containsKey('error')) {
        _setError(advice['error']);
        return;
      }
      
      // Kaynak bilgisini ekle - eğer yoksa varsayılan değer
      if (!advice.containsKey('source') || advice['source'] == null) {
        advice['source'] = 'Yapay Zeka Asistanı';
      }
      
      // Kullanıcı ID'si ekle
      advice['userId'] = userId;
      
      // Tarih bilgisi ekle
      advice['timestamp'] = Timestamp.now();
      
      // Firestore'a kaydet
      final docRef = await _firestore.collection('advice_cards').add(advice);
      
      // ID'yi ekle
      advice['id'] = docRef.id;
      
      // Güncel tavsiyeyi ayarla
      _adviceCard = advice;
      
      _logger.i('Yeni tavsiye kartı alındı. Kaynak: ${advice['source']}');
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
    _logger.e('AdviceViewModel hatası: $error');
    notifyListeners();
  }

  // Hata mesajını temizleme
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> initializeViewModel() async {
    await fetchDailyAdviceAndQuote();
    _setupDailyAdviceRefresh();
  }
  
  Future<void> fetchDailyAdviceAndQuote() async {
    try {
      // Kullanıcı bilgisini alma
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        _logger.w('Kullanıcı giriş yapmamış, günlük veriler alınamadı');
        return;
      }
      
      _logger.i('Günlük tavsiye ve ilişki koçu alıntısı yükleme başlatılıyor...');
      
      // Yükleme durumlarını güncelle (bildirimleri tetiklemek için)
      _setLoading(true);
      _setLoadingQuote(true);
      
      // Hem tavsiye kartını hem de ilişki koçu alıntısını getir (paralel)
      await Future.wait([
        getDailyAdviceCard(userId),
        getDailyRelationshipQuote(userId)
      ]);
      
      // Alıntı alınamadıysa tekrar dene
      if (!hasQuote) {
        _logger.i('İlişki koçu alıntısı alınamadı, tekrar deneniyor...');
        await Future.delayed(const Duration(seconds: 3));
        await getDailyRelationshipQuote(userId);
      }
      
      _logger.i('Günlük tavsiye ve ilişki koçu alıntısı başarıyla alındı');
      
      // Alıntı hala alınamadıysa, kullanıcıya bilgilendirme yap
      if (!hasQuote) {
        _logger.w('İlişki koçu alıntısı alınamadı, kullanıcıya bilgilendirme yapılıyor');
        _notificationService.showLocalNotification(
          'Tavsiye Verisi Hazırlanıyor',
          'Günlük tavsiyeler hazırlanırken bir gecikme olabilir. Lütfen daha sonra kontrol ediniz.'
        );
      }
    } catch (e) {
      _logger.e('Günlük veriler alınırken hata: $e');
    } finally {
      _setLoading(false);
      _setLoadingQuote(false);
    }
  }
  
  void _setupDailyAdviceRefresh() {
    // Mevcut Timer'ı iptal et
    _dailyAdviceTimer?.cancel();
    
    // Gece yarısından 1 dakika sonrası için tarih belirle (00:01)
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 1);
    
    // Bir sonraki yenilemeye kadar olan süreyi hesapla
    final timeUntilRefresh = nextMidnight.difference(now);
    
    _logger.i('Günlük tavsiye otomatik yenileme zamanı: ${nextMidnight.toString()} (${timeUntilRefresh.inHours} saat ${timeUntilRefresh.inMinutes % 60} dakika sonra)');
    
    // Timer'ı ayarla
    _dailyAdviceTimer = Timer(timeUntilRefresh, () {
      _refreshDailyAdvice();
    });
  }
  
  Future<void> _refreshDailyAdvice() async {
    _logger.i('Günlük tavsiye kartları yenileniyor...');
    await fetchDailyAdviceAndQuote();
    
    // Bildirim gönder
    _notificationService.showDailyAdviceNotification(
      'Yeni Günlük Tavsiyeler',
      'Bugün için yeni tavsiye kartlarınız hazır!'
    );
    
    // Bir sonraki gün için timer'ı yeniden ayarla
    _setupDailyAdviceRefresh();
  }

  // Zamanlayıcıyı başlat
  void startDailyAdviceTimer(String userId) {
    // Önce varsa eski timer'ı temizle
    _dailyAdviceTimer?.cancel();
    
    // Her gün gece yarısından 1 dakika sonra (00:01) çalışacak zamanlayıcı
    _logger.i('Günlük tavsiye kartı zamanlayıcısı başlatılıyor');
    
    // Gece yarısından 1 dakika sonrası için tarih belirle
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 1);
    
    // İlk tetikleme için gereken süreyi hesapla
    final initialDelay = nextMidnight.difference(now);
    
    _logger.i('Sonraki otomatik tavsiye yenilemesi: ${nextMidnight.toString()}');
    
    // İlk tetikleme için bir kerelik zamanlayıcı
    _dailyAdviceTimer = Timer(initialDelay, () {
      // İlk çalışmadan sonra günlük olarak tekrarla
      refreshDailyAdviceCard(userId);
      
      // Günlük tekrarlanan zamanlayıcı - her gün gece yarısından 1 dakika sonra
      _dailyAdviceTimer = Timer.periodic(const Duration(days: 1), (_) {
        refreshDailyAdviceCard(userId);
      });
    });
  }
  
  // Günlük tavsiye kartını yenile
  Future<void> refreshDailyAdviceCard(String userId) async {
    _logger.i('Otomatik günlük tavsiye kartı ve alıntı yenileniyor');
    try {
      // Hem tavsiye kartını hem de ilişki koçu alıntısını yenile
      await Future.wait([
        getDailyAdviceCard(userId),
        getDailyRelationshipQuote(userId)
      ]);
      
      // Bildirim gönder
      _notificationService.showDailyAdviceNotification(
        'Günlük Tavsiye Hazır!', 
        'Bugünkü tavsiye ve alıntın hazır. Görmek için tıkla!'
      );
      
      _logger.i('Günlük tavsiye ve alıntı başarıyla yenilendi');
    } catch (e) {
      _logger.e('Otomatik tavsiye yenilenirken hata: $e');
    }
  }

  // Danışma cevabı alma
  Future<String?> getAdvice(String question, String userId) async {
    _setLoading(true);
    try {
      _logger.i('Danışma cevabı alınıyor. Soru: $question');
      
      // Soruyu boşluk kontrolü
      if (question.trim().isEmpty) {
        _setError('Geçerli bir soru girin');
        return null;
      }
      
      // Boş bir chat geçmişi oluştur
      final List<Map<String, dynamic>> emptyHistory = [];
      
      // AI'dan cevap al
      final response = await _aiService.getRelationshipAdvice(question, emptyHistory);
      
      if (response.containsKey('error')) {
        _setError(response['error']);
        return null;
      }
      
      if (response.containsKey('answer')) {
        final advice = response['answer'] as String;
        
        // Yanıtı Firestore'a kaydet
        await _saveAdviceToFirestore(question, advice, userId);
        
        _logger.i('Danışma cevabı başarıyla alındı');
        return advice;
      } else {
        _setError('Cevap alınamadı');
        return null;
      }
    } catch (e) {
      _logger.e('Danışma cevabı alınırken hata: $e');
      _setError('Danışma cevabı alınırken hata oluştu: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  // Danışma yanıtını Firestore'a kaydet
  Future<void> _saveAdviceToFirestore(String question, String advice, String userId) async {
    try {
      await _firestore.collection('user_advices').add({
        'userId': userId,
        'question': question,
        'advice': advice,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      _logger.i('Danışma yanıtı Firestore\'a kaydedildi');
    } catch (e) {
      _logger.e('Danışma yanıtı kaydedilirken hata: $e');
    }
  }

  // Günlük ilişki koçu alıntısını getir
  Future<void> getDailyRelationshipQuote(String userId) async {
    _setLoadingQuote(true);
    try {
      _logger.i('Yeni günlük ilişki koçu alıntısı alınıyor.');
      
      // 3 kez deneme yap, her denemede 3 saniye bekle
      Map<String, dynamic>? quoteData;
      int maxAttempts = 3;
      
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        _logger.i('İlişki koçu alıntısı alma denemesi: $attempt');
        quoteData = await _aiService.getDailyRelationshipQuote();
        
        // Başarılı ise döngüden çık
        if (!quoteData.containsKey('error')) {
          _logger.i('Alıntı başarıyla alındı, denemede: $attempt');
          break;
        }
        
        // Son deneme değilse bekle ve tekrar dene
        if (attempt < maxAttempts) {
          _logger.w('Deneme $attempt başarısız: ${quoteData['error']}. Tekrar deneniyor...');
          await Future.delayed(const Duration(seconds: 3));
        }
      }
      
      // Tüm denemeler sonucunda hala hata varsa
      if (quoteData == null || quoteData.containsKey('error')) {
        _logger.w('Alıntı alınırken hata: ${quoteData?['error'] ?? 'Bilinmeyen hata'}');
        _setQuoteError(quoteData?['error'] ?? 'Alıntı alınamadı');
        _dailyQuote = null;
        return;
      }

      // Gelen veride gerekli alanların varlığını kontrol et
      if (!quoteData.containsKey('title') || !quoteData.containsKey('content') || !quoteData.containsKey('source') ||
          quoteData['title'] == null || quoteData['content'] == null || quoteData['source'] == null ||
          (quoteData['title'].toString().trim().isEmpty) || 
          (quoteData['content'].toString().trim().isEmpty) || 
          (quoteData['source'].toString().trim().isEmpty)) {
        final String errorMessage = 'AI servisinden gelen alıntı verisi eksik veya geçersiz (boşluk olabilir).';
        _logger.w('$errorMessage Gelen Veri: $quoteData');
        _setQuoteError(errorMessage);
        _dailyQuote = null;
        return;
      }
      
      // Kullanıcı ID'si ekle
      quoteData['userId'] = userId;
      
      // Önce bugün alınmış alıntıları temizle
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final QuerySnapshot existingSnapshot = await _firestore
          .collection('relationship_quotes')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      
      // Eski kayıtları sil
      final batch = _firestore.batch();
      for (final doc in existingSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      // Yeni kaydı ekle
      final docRef = await _firestore.collection('relationship_quotes').add(quoteData);
      
      // ID'yi ekle
      quoteData['id'] = docRef.id;
      
      // Alıntıyı oluştur
      _dailyQuote = RelationshipQuote.fromFirestore(quoteData);
      
      _logger.i('Yeni günlük ilişki koçu alıntısı alındı.');
      notifyListeners();
    } catch (e) {
      _logger.e('İlişki koçu alıntısı alınırken hata oluştu: $e');
      _setQuoteError('İlişki koçu alıntısı alınırken hata oluştu: $e');
      _dailyQuote = null;
    } finally {
      _setLoadingQuote(false);
    }
  }
  
  // Yeni ilişki koçu alıntısı alma
  Future<void> refreshRelationshipQuote(String userId) async {
    _setLoadingQuote(true);
    try {
      // Yeni alıntı al
      _logger.i('Kullanıcı için yeni ilişki koçu alıntısı alınıyor.');
      final quoteData = await _aiService.getDailyRelationshipQuote();
      
      if (quoteData.containsKey('error')) {
        _logger.w('Alıntı alınırken hata: ${quoteData['error']}');
        _setQuoteError(quoteData['error']);
        _dailyQuote = null;
        return;
      }

      // Gelen veride gerekli alanların varlığını kontrol et (refresh için de ekleyelim)
      if (!quoteData.containsKey('title') || !quoteData.containsKey('content') || !quoteData.containsKey('source') ||
          quoteData['title'] == null || quoteData['content'] == null || quoteData['source'] == null ||
          (quoteData['title'].toString().trim().isEmpty) || 
          (quoteData['content'].toString().trim().isEmpty) || 
          (quoteData['source'].toString().trim().isEmpty)) {
        final String errorMessage = 'AI servisinden gelen yenilenmiş alıntı verisi eksik veya geçersiz.';
        _logger.w('$errorMessage Gelen Veri: $quoteData');
        _setQuoteError(errorMessage);
        _dailyQuote = null;
        return;
      }
      
      // Kullanıcı ID'si ekle
      quoteData['userId'] = userId;
      
      // Firestore'a kaydet
      final docRef = await _firestore.collection('relationship_quotes').add(quoteData);
      
      // ID'yi ekle
      quoteData['id'] = docRef.id;
      
      // Alıntıyı oluştur
      _dailyQuote = RelationshipQuote.fromFirestore(quoteData);
      
      _logger.i('Yeni ilişki koçu alıntısı alındı.');
      notifyListeners();
    } catch (e) {
      _logger.e('İlişki koçu alıntısı alınırken hata oluştu: $e');
      _setQuoteError('İlişki koçu alıntısı alınırken hata oluştu: $e');
      _dailyQuote = null;
    } finally {
      _setLoadingQuote(false);
    }
  }
  
  // Alıntı yükleme durumunu ayarlama
  void _setLoadingQuote(bool loading) {
    _isLoadingQuote = loading;
    notifyListeners();
  }

  // Alıntı hata mesajını ayarlama
  void _setQuoteError(String error) {
    _quoteErrorMessage = error;
    _logger.e('İlişki koçu alıntısı hatası: $error');
    notifyListeners();
  }

  // Alıntı hata mesajını temizleme
  void clearQuoteError() {
    _quoteErrorMessage = null;
    notifyListeners();
  }

  // Veritabanında mevcut günlük tavsiyeleri ve ilişki koçu alıntılarını temizle
  Future<void> clearDailyData(String userId) async {
    _setLoading(true);
    _setLoadingQuote(true);
    try {
      _logger.i('Veritabanındaki tüm tavsiye ve alıntı verileri temizleniyor...');
      
      // Advice Cards temizleme - tüm kayıtları sil
      final QuerySnapshot adviceSnapshot = await _firestore
          .collection('advice_cards')
          .where('userId', isEqualTo: userId)
          .get();
      
      // Relationship Quotes temizleme - tüm kayıtları sil
      final QuerySnapshot quoteSnapshot = await _firestore
          .collection('relationship_quotes')
          .where('userId', isEqualTo: userId)
          .get();
      
      // Batch yazma işlemi
      final batch = _firestore.batch();
      
      // Advice Cards silme
      for (final doc in adviceSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Relationship Quotes silme
      for (final doc in quoteSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Batch işlemini uygula
      await batch.commit();
      
      // Yerel değişkenleri temizle
      _adviceCard = null;
      _dailyQuote = null;
      
      _logger.i('Veritabanı başarıyla temizlendi. Silinen kayıt sayısı: ${adviceSnapshot.docs.length + quoteSnapshot.docs.length}');
      notifyListeners();
      
      // Yeni verileri yükle
      await fetchDailyAdviceAndQuote();
    } catch (e) {
      _logger.e('Veritabanı temizlenirken hata: $e');
      _setError('Veriler temizlenirken bir hata oluştu: $e');
    } finally {
      _setLoading(false);
      _setLoadingQuote(false);
    }
  }

  @override
  void dispose() {
    _dailyAdviceTimer?.cancel();
    super.dispose();
  }
}