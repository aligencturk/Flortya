import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/advice_chat.dart';
import '../models/chat_message.dart';
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
  
  // Premium kullanıcılar için yeni tavsiye alma
  Future<void> getDailyAdvice(String userId, {bool isPremium = false, bool force = false}) async {
    // Premium kontrolünü daha katı yapıyoruz
    if (!isPremium) {
      // _setError çağrısını kaldırıyoruz, sadece loglama yapıp çıkıyoruz.
      // _setError('Bu özellik sadece premium kullanıcılar için kullanılabilir.');
      _logger.w('Premium olmayan kullanıcı tavsiye yenileme denemesi: $userId');
      // Hata durumunda mevcut tavsiye kartını silmiyoruz, böylece ekranda görünmeye devam eder
      return;
    }
    
    _setLoading(true);
    try {
      // Yeni tavsiye kartı al
      _logger.i('Premium kullanıcı için yeni tavsiye kartı alınıyor.');
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
      
      _logger.i('Yeni premium tavsiye kartı alındı.');
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
    await fetchDailyAdvice();
    _setupDailyAdviceRefresh();
  }
  
  Future<void> fetchDailyAdvice() async {
    try {
      // Kullanıcı bilgisini alma
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        _logger.w('Kullanıcı giriş yapmamış, günlük tavsiye alınamadı');
        return;
      }
      
      await getDailyAdviceCard(userId);
      _logger.i('Günlük tavsiye başarıyla alındı');
    } catch (e) {
      _logger.e('Günlük tavsiye alınırken hata: $e');
      _setError('Günlük tavsiye alınırken bir hata oluştu');
    }
  }
  
  void _setupDailyAdviceRefresh() {
    // Mevcut Timer'ı iptal et
    _dailyAdviceTimer?.cancel();
    
    // Bugün için saat 10:00'u belirle
    final now = DateTime.now();
    final tenAM = DateTime(now.year, now.month, now.day, 10, 0);
    
    // Eğer saat 10:00'u geçtiyse, yarın için ayarla
    Duration timeUntilTenAM;
    if (now.isAfter(tenAM)) {
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowTenAM = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0);
      timeUntilTenAM = tomorrowTenAM.difference(now);
    } else {
      timeUntilTenAM = tenAM.difference(now);
    }
    
    _logger.i('Günlük tavsiye yenileme zamanı: ${timeUntilTenAM.inHours} saat ${timeUntilTenAM.inMinutes % 60} dakika sonra');
    
    // Timer'ı ayarla
    _dailyAdviceTimer = Timer(timeUntilTenAM, () {
      _refreshDailyAdvice();
    });
  }
  
  Future<void> _refreshDailyAdvice() async {
    _logger.i('Günlük tavsiye kartları yenileniyor...');
    await fetchDailyAdvice();
    
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
    
    // Her gün saat 10:00'da çalışacak bir zamanlayıcı oluştur
    _logger.i('Günlük tavsiye kartı zamanlayıcısı başlatılıyor');
    
    // Sonraki saat 10:00'u hesapla
    final now = DateTime.now();
    final today10AM = DateTime(now.year, now.month, now.day, 10, 0);
    
    // Eğer saat 10:00'u geçmişsek, yarının saat 10:00'unu hedefle
    final nextRefreshTime = now.isAfter(today10AM) 
        ? today10AM.add(const Duration(days: 1)) 
        : today10AM;
    
    // İlk tetikleme için gereken süreyi hesapla
    final initialDelay = nextRefreshTime.difference(now);
    
    _logger.i('Sonraki tavsiye kartı yenilemesi: ${nextRefreshTime.toString()}');
    
    // İlk tetikleme için bir kerelik zamanlayıcı
    _dailyAdviceTimer = Timer(initialDelay, () {
      // İlk çalışmadan sonra günlük olarak tekrarla
      refreshDailyAdviceCard(userId);
      
      // Günlük tekrarlanan zamanlayıcı
      _dailyAdviceTimer = Timer.periodic(const Duration(days: 1), (_) {
        refreshDailyAdviceCard(userId);
      });
    });
  }
  
  // Günlük tavsiye kartını yenile
  Future<void> refreshDailyAdviceCard(String userId) async {
    _logger.i('Otomatik günlük tavsiye kartı yenileniyor');
    try {
      await getDailyAdviceCard(userId);
      
      // Bildirim gönder
      _notificationService.showDailyAdviceNotification(
        'Günlük Tavsiye Hazır!', 
        'Bugünkü tavsiye kartın hazır. Görmek için tıkla!'
      );
      
      _logger.i('Günlük tavsiye kartı başarıyla yenilendi');
    } catch (e) {
      _logger.e('Otomatik tavsiye kartı yenilenirken hata: $e');
    }
  }

  @override
  void dispose() {
    _dailyAdviceTimer?.cancel();
    super.dispose();
  }
}