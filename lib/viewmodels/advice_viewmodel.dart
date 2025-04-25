import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/message_coach_analysis.dart';
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
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Mesaj Koçu ile ilgili özellikler
  MesajKocuAnalizi? _mesajAnalizi;
  bool _isAnalyzing = false;
  int _ucretlizAnalizSayisi = 0;

  // Mesaj Koçu getters
  MesajKocuAnalizi? get mesajAnalizi => _mesajAnalizi;
  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;
  bool get hasAnalizi => _mesajAnalizi != null;
  int get ucretlizAnalizSayisi => _ucretlizAnalizSayisi;
  bool get analizHakkiVar => _ucretlizAnalizSayisi < MesajKocuAnalizi.ucretlizAnalizSayisi;
  bool get isLoading => _isLoading;
  
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

  // Mesaj Koçu analizi yapma
  Future<void> analyzeMesaj(String messageText, String userId) async {
    _setAnalyzing(true);
    _setError(null);
    _mesajAnalizi = null;
    notifyListeners();
    
    try {
      _logger.i('Mesaj analizi yapılıyor...');
      
      // Kullanıcının bugün kalan ücretsiz analiz sayısını kontrol et
      if (!analizHakkiVar) {
        _setError('Ücretsiz analiz hakkınız doldu. Premium üyelik için profil ayarlarınızı kontrol edin.');
        return;
      }
      
      // Analiz yap
      final result = await _aiService.getMesajKocuAnalizi(messageText);
      
      if (result.containsKey('error')) {
        _setError(result['error']);
        return;
      }
      
      // Analiz modelini oluştur
      final analiz = MesajKocuAnalizi.fromJson(result);
      _mesajAnalizi = analiz;
      
      // Veritabanına kaydet
      await _saveAnalysisToFirestore(analiz, messageText, userId);
      
      // Kullanılan ücretsiz analiz sayısını artır
      await _incrementAnalysisCount(userId);
      
      _logger.i('Mesaj analizi başarıyla tamamlandı');
      
      notifyListeners();
    } catch (e) {
      _setError('Mesaj analizi yapılırken hata oluştu: $e');
    } finally {
      _setAnalyzing(false);
    }
  }
  
  // İlişki danışma tavsiyesi alma
  Future<Map<String, dynamic>> getAdvice(String question) async {
    try {
      _logger.d('Danışma talebi: $question');
      
      // İlişki danışmanlığı yanıtı al
      final Map<String, dynamic> response = await _aiService.getRelationshipAdvice(question, null);
      
      if (response.containsKey('error')) {
        _logger.w('Danışma yanıtı alınamadı: ${response['error']}');
        return {'error': response['error']};
      }
      
      return response;
    } catch (e) {
      _logger.e('Danışma işlemi sırasında hata: $e');
      return {'error': 'Danışma yanıtı alınamadı: $e'};
    }
  }
  
  // Firestore'a analiz sonucunu kaydetme
  Future<void> _saveAnalysisToFirestore(MesajKocuAnalizi analiz, String messageText, String userId) async {
    try {
      final data = analiz.toFirestore();
      data['userId'] = userId;
      data['messageText'] = messageText;
      data['timestamp'] = Timestamp.now();
      
      await _firestore.collection('message_coach_analyses').add(data);
    } catch (e) {
      _logger.e('Analiz kaydedilirken hata: $e');
    }
  }
  
  // Kullanıcının bugün yaptığı analiz sayısını kontrol etme ve artırma
  Future<void> _incrementAnalysisCount(String userId) async {
    try {
      // Bugünün tarihini al (saat bilgisini sıfırla)
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      // Kullanıcının bugün yaptığı analizleri sorgula
      final QuerySnapshot analysisSnapshot = await _firestore
          .collection('message_coach_analyses')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      
      _ucretlizAnalizSayisi = analysisSnapshot.docs.length;
      
      _logger.i('Bugün yapılan analiz sayısı: $_ucretlizAnalizSayisi');
      notifyListeners();
    } catch (e) {
      _logger.e('Analiz sayısı kontrol edilirken hata: $e');
    }
  }
  
  // Kullanıcının bugün yaptığı analiz sayısını yükleme
  Future<void> loadAnalysisCount(String userId) async {
    try {
      if (userId.isEmpty) return;
      
      // Bugünün tarihini al (saat bilgisini sıfırla)
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      // Kullanıcının bugün yaptığı analizleri sorgula
      final QuerySnapshot analysisSnapshot = await _firestore
          .collection('message_coach_analyses')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      
      _ucretlizAnalizSayisi = analysisSnapshot.docs.length;
      
      _logger.i('Bugün yapılan analiz sayısı yüklendi: $_ucretlizAnalizSayisi');
      notifyListeners();
    } catch (e) {
      _logger.e('Analiz sayısı yüklenirken hata: $e');
    }
  }
  
  // Kullanıcının geçmiş analizlerini getirme
  Future<List<Map<String, dynamic>>> getAnalysisHistory(String userId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('message_coach_analyses')
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
      _setError('Analiz geçmişi alınırken hata oluştu: $e');
      return [];
    }
  }
  
  // Kullanıcının tüm verilerini temizleme
  Future<void> clearUserData(String userId) async {
    try {
      // Mesaj Koçu analizlerini temizle
      final QuerySnapshot analyses = await _firestore
          .collection('message_coach_analyses')
          .where('userId', isEqualTo: userId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in analyses.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      // Yerel verileri sıfırla
      _mesajAnalizi = null;
      _ucretlizAnalizSayisi = 0;
      
      notifyListeners();
      _logger.i('Kullanıcı verileri temizlendi: $userId');
    } catch (e) {
      _logger.e('Kullanıcı verileri temizlenirken hata: $e');
      _setError('Veriler temizlenirken hata oluştu: $e');
    }
  }
  
  // Yardımcı metodlar
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  void _setAnalyzing(bool value) {
    _isAnalyzing = value;
    notifyListeners();
  }
  
  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }
  
  // Kullanıcı oturumu kapandığında
  void onUserSignOut() {
    _mesajAnalizi = null;
    _ucretlizAnalizSayisi = 0;
    _errorMessage = null;
    notifyListeners();
  }
  
  // Analiz sonucunu sıfırlama
  void resetAnalysisResult() {
    _mesajAnalizi = null;
    _errorMessage = null;
    notifyListeners();
  }
  
  // Hata mesajını sıfırla
  void resetError() {
    _errorMessage = null;
    notifyListeners();
    _logger.d('Hata mesajı sıfırlandı');
  }
}