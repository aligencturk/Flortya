import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';

class AdviceViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AiService _aiService = AiService();
  
  Map<String, dynamic>? _dailyAdvice;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  Map<String, dynamic>? get dailyAdvice => _dailyAdvice;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasAdvice => _dailyAdvice != null;

  // Son alınan tavsiye tarihi için key
  static const String _lastAdviceDateKey = 'last_advice_date';

  // Günlük tavsiye kartını alma
  Future<void> getDailyAdvice(String userId, {bool isPremium = false, bool force = false}) async {
    // Daha önce alınmış tavsiye varsa ve bugün alınmışsa tekrar alma
    if (!force && await _hasAdviceForToday()) {
      // Firestore'dan mevcut tavsiyeyi yükle
      await _loadLatestAdvice(userId);
      return;
    }
    
    // Premium kullanıcı değilse ve zorla istenmediyse kontrol et
    if (!isPremium && !force) {
      // Bugün alınmamış olsa bile premium kullanıcı değilse
      // haftada sadece 1 tavsiye alabilsin
      if (!await _canGetWeeklyAdvice()) {
        _setError('Premium kullanıcı olmadığınız için haftada sadece 1 tavsiye alabilirsiniz');
        return;
      }
    }
    
    _setLoading(true);
    try {
      final advice = await _aiService.getDailyAdviceCard(userId);
      
      if (advice.containsKey('error')) {
        _setError(advice['error']);
        return;
      }
      
      // Tavsiyeyi sakla
      _dailyAdvice = advice;
      
      // Firestore'a kaydet
      await _saveAdviceToFirestore(userId, advice);
      
      // Son tavsiye alma tarihini güncelle
      await _updateLastAdviceDate();
      
      notifyListeners();
    } catch (e) {
      _setError('Tavsiye kartı alınırken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  // En son tavsiyeyi Firestore'dan yükleme
  Future<void> _loadLatestAdvice(String userId) async {
    _setLoading(true);
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('advice_cards')
          .where('userId', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        
        _dailyAdvice = {
          'advice': data['advice'],
          'title': data['title'],
          'created_at': (data['created_at'] as Timestamp).toDate().toIso8601String(),
        };
        
        notifyListeners();
      }
    } catch (e) {
      _setError('Tavsiye kartı yüklenirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Tavsiyeyi Firestore'a kaydetme
  Future<void> _saveAdviceToFirestore(String userId, Map<String, dynamic> advice) async {
    try {
      await _firestore.collection('advice_cards').add({
        'userId': userId,
        'advice': advice['advice'],
        'title': advice['title'],
        'created_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Tavsiye kartı kaydedilirken hata oluştu: $e');
    }
  }

  // Bugün için zaten tavsiye alınmış mı kontrol etme
  Future<bool> _hasAdviceForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAdviceDate = prefs.getString(_lastAdviceDateKey);
    
    if (lastAdviceDate == null) return false;
    
    final today = DateTime.now().toIso8601String().split('T')[0]; // Sadece tarih kısmı
    final lastDate = lastAdviceDate.split('T')[0]; // Sadece tarih kısmı
    
    return today == lastDate;
  }

  // Haftalık tavsiye hakkı var mı kontrol etme
  Future<bool> _canGetWeeklyAdvice() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAdviceDate = prefs.getString(_lastAdviceDateKey);
    
    if (lastAdviceDate == null) return true;
    
    final lastDate = DateTime.parse(lastAdviceDate);
    final now = DateTime.now();
    
    // Son alınan tavsiyeden bu yana 7 gün geçmiş mi
    return now.difference(lastDate).inDays >= 7;
  }

  // Son tavsiye alma tarihini güncelleme
  Future<void> _updateLastAdviceDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAdviceDateKey, DateTime.now().toIso8601String());
  }

  // Kullanıcının tüm tavsiye kartlarını yükleme
  Future<List<Map<String, dynamic>>> loadUserAdviceHistory(String userId) async {
    _setLoading(true);
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('advice_cards')
          .where('userId', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();
      
      final adviceHistory = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'advice': data['advice'],
          'title': data['title'],
          'created_at': (data['created_at'] as Timestamp).toDate().toIso8601String(),
        };
      }).toList();
      
      return adviceHistory;
    } catch (e) {
      _setError('Tavsiye geçmişi yüklenirken hata oluştu: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // Tavsiyeyi sıfırlama
  void resetAdvice() {
    _dailyAdvice = null;
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