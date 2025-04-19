import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../services/ai_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../viewmodels/past_reports_viewmodel.dart';

class ReportViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AiService _aiService = AiService();
  
  final List<String> _questions = [
    'İlişkinizdeki en büyük sorun nedir?',
    'Partnerinizle nasıl iletişim kuruyorsunuz?',
    'İlişkinizde sizi en çok ne mutlu ediyor?',
    'İlişkinizde gelecek beklentileriniz neler?',
    'İlişkinizde değiştirmek istediğiniz bir şey var mı?',
    'İlişkinizde ne sıklıkla görüşüyorsunuz?',
  ];
  
  List<String> _answers = ['', '', '', '', '', ''];
  int _currentQuestionIndex = 0;
  Map<String, dynamic>? _reportResult;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _comments = [];

  // İlişki geçmişi sınıf değişkeni
  List<Map<String, dynamic>>? _relationshipHistory;

  // Getters
  List<String> get questions => _questions;
  List<String> get answers => _answers;
  int get currentQuestionIndex => _currentQuestionIndex;
  String get currentQuestion {
    // Güvenlik kontrolü ekleyerek 5. indekse uygun erişim sağlayalım
    if (_currentQuestionIndex >= 0 && _currentQuestionIndex < _questions.length) {
      return _questions[_currentQuestionIndex];
    } else if (_currentQuestionIndex == 5) {
      // 6. soru için sabit bir metin döndürelim
      return 'İlişkinizde ne sıklıkla görüşüyorsunuz?';
    } else {
      return 'Bilinmeyen soru';
    }
  }
  Map<String, dynamic>? get reportResult => _reportResult;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasReport => _reportResult != null;
  bool get isLastQuestion => _currentQuestionIndex == 5;
  bool get allQuestionsAnswered => !_answers.any((answer) => answer.isEmpty);
  List<Map<String, dynamic>> get comments => _comments;

  // Cevap kaydetme
  void saveAnswer(String answer) {
    _answers[_currentQuestionIndex] = answer;
    notifyListeners();
  }

  // Sonraki soruya geçme
  void nextQuestion() {
    if (_currentQuestionIndex < 5) {
      _currentQuestionIndex++;
      notifyListeners();
    }
  }

  // Önceki soruya dönme
  void previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      notifyListeners();
    }
  }

  // Belirli bir soruya gitme
  void goToQuestion(int index) {
    if (index >= 0 && index < _questions.length) {
      _currentQuestionIndex = index;
      notifyListeners();
    }
  }

  // İlişki raporu oluşturma
  Future<void> generateReport(String userId) async {
    if (!allQuestionsAnswered) {
      _setError('Lütfen tüm soruları yanıtlayın');
      return;
    }
    
    _setLoading(true);
    try {
      final report = await _aiService.generateRelationshipReport(_answers);
      
      if (report.containsKey('error')) {
        _setError(report['error']);
        return;
      }
      
      // Raporu sakla
      _reportResult = report;
      
      // Firestore'a kaydet
      await _saveReportToFirestore(userId, report);
      
      notifyListeners();
    } catch (e) {
      _setError('Rapor oluşturulurken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Raporu Firestore'a kaydetme
  Future<void> _saveReportToFirestore(String userId, Map<String, dynamic> report) async {
    try {
      await _firestore.collection('relationship_reports').add({
        'userId': userId,
        'answers': _answers,
        'report': report['report'],
        'relationship_type': report['relationship_type'],
        'suggestions': report['suggestions'],
        'created_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Rapor kaydedilirken hata oluştu: $e');
    }
  }

  // Kullanıcının raporlarını yükleme
  Future<void> loadUserReports(String userId) async {
    _setLoading(true);
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('relationship_reports')
          .where('userId', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        
        _reportResult = {
          'report': data['report'],
          'relationship_type': data['relationship_type'],
          'suggestions': data['suggestions'],
          'created_at': (data['created_at'] as Timestamp).toDate().toIso8601String(),
          'reportId': doc.id, // Rapor ID'sini kaydet
        };
        
        // Cevapları da yükle
        if (data['answers'] != null) {
          final List<dynamic> savedAnswers = data['answers'];
          _answers = savedAnswers.map((answer) => answer.toString()).toList();
        }
        
        // Rapor yorumlarını yükle
        await loadReportComments(doc.id);
        
        // İlişki geçmişini temizle (yeni rapor için yeniden yüklenecek)
        _relationshipHistory = null;
        
        notifyListeners();
      }
    } catch (e) {
      _setError('Raporlar yüklenirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Rapor yorumlarını yükleme
  Future<void> loadReportComments(String reportId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('relationship_reports')
          .doc(reportId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .get();
      
      _comments = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'comment': data['comment'],
          'userId': data['userId'],
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
          'aiResponse': data['aiResponse'],
        };
      }).toList();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Yorumlar yüklenirken hata oluştu: $e');
    }
  }
  
  // Yorum gönderme
  Future<void> sendComment(String userId, String comment) async {
    if (_reportResult == null || !_reportResult!.containsKey('reportId')) {
      _setError('Rapor bulunamadı');
      return;
    }
    
    final String reportId = _reportResult!['reportId'];
    _setLoading(true);
    
    try {
      // Kullanıcı yorumunu Firestore'a ekle
      final docRef = await _firestore
          .collection('relationship_reports')
          .doc(reportId)
          .collection('comments')
          .add({
            'comment': comment,
            'userId': userId,
            'timestamp': Timestamp.now(),
            'aiResponse': '',  // AI yanıtı başlangıçta boş
          });
      
      // AI'dan yanıt al
      final Map<String, dynamic> response = await _aiService.getCommentResponse(
        comment, 
        _reportResult!['report'], 
        _reportResult!['relationship_type']
      );
      
      // AI yanıtını güncelle
      if (!response.containsKey('error')) {
        await _firestore
            .collection('relationship_reports')
            .doc(reportId)
            .collection('comments')
            .doc(docRef.id)
            .update({
              'aiResponse': response['answer'],
            });
        
        // Yorumları tekrar yükle
        await loadReportComments(reportId);
      } else {
        _setError(response['error']);
      }
      
    } catch (e) {
      _setError('Yorum gönderilirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Raporu sıfırlama
  void resetReport() {
    _answers = List.filled(_questions.length, '');
    _currentQuestionIndex = 0;
    _reportResult = null;
    _errorMessage = null;
    _comments = [];
    _relationshipHistory = null;
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

  // İlişki gelişim geçmişini alma
  Future<List<Map<String, dynamic>>> getRelationshipHistory() async {
    if (_relationshipHistory != null) {
      return _relationshipHistory!;
    }
    
    try {
      final userId = _reportResult != null && _reportResult!.containsKey('userId') 
          ? _reportResult!['userId'] 
          : null;
      
      if (userId == null) {
        return _generateFakeGraphData(); // Gerçek veri yoksa demo veri göster
      }
      
      final QuerySnapshot snapshot = await _firestore
          .collection('relationship_reports')
          .where('userId', isEqualTo: userId)
          .orderBy('created_at', descending: false)
          .get();
      
      if (snapshot.docs.isEmpty) {
        return _generateFakeGraphData();
      }
      
      // İlişki gelişim verilerini hazırla
      _relationshipHistory = [];
      
      // Son 5 raporu al (veya daha az varsa tümünü)
      final docs = snapshot.docs.length > 5 
          ? snapshot.docs.sublist(snapshot.docs.length - 5) 
          : snapshot.docs;
      
      for (var i = 0; i < docs.length; i++) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;
        
        final relationshipType = data['relationship_type'] ?? 'Belirsiz';
        final date = (data['created_at'] as Timestamp).toDate();
        
        // İlişki tipine göre değer belirleme
        int value = _calculateRelationshipScore(relationshipType);
        
        _relationshipHistory!.add({
          'value': value,
          'label': '${date.day}/${date.month}',
          'type': relationshipType,
        });
      }
      
      return _relationshipHistory!;
    } catch (e) {
      debugPrint('İlişki geçmişi yüklenirken hata oluştu: $e');
      return _generateFakeGraphData();
    }
  }
  
  // İlişki tipine göre puan hesaplama
  int _calculateRelationshipScore(String relationshipType) {
    final Map<String, int> typeScores = {
      'Güven Odaklı': 85,
      'Tutkulu': 75,
      'Uyumlu': 80,
      'Dengeli': 90,
      'Mesafeli': 60,
      'Kaçıngan': 50,
      'Endişeli': 55,
      'Çatışmalı': 40,
      'Kararsız': 60,
      'Gelişmekte Olan': 70,
      'Sağlıklı': 95,
      'Zorlayıcı': 45,
    };
    
    return typeScores[relationshipType] ?? 65;
  }
  
  // Demo veri oluşturma (henüz gerçek veri yoksa)
  List<Map<String, dynamic>> _generateFakeGraphData() {
    // Şu anki raporu kullan
    final currentType = _reportResult != null 
        ? _reportResult!['relationship_type'] as String? ?? 'Gelişmekte Olan'
        : 'Gelişmekte Olan';
        
    final currentScore = _calculateRelationshipScore(currentType);
    
    // Şu anki tarih
    final now = DateTime.now();
    
    // Sahte gelişim verileri oluştur (geçmişten şimdiye)
    return [
      {
        'value': max(30, currentScore - 30), // En düşük 30 puan
        'label': '${now.day-20}/${now.month}',
        'type': 'Mesafeli',
      },
      {
        'value': max(40, currentScore - 20),
        'label': '${now.day-15}/${now.month}',
        'type': 'Kararsız',
      },
      {
        'value': max(50, currentScore - 10),
        'label': '${now.day-10}/${now.month}',
        'type': 'Gelişmekte Olan',
      },
      {
        'value': max(60, currentScore - 5),
        'label': '${now.day-5}/${now.month}',
        'type': 'Gelişmekte Olan',
      },
      {
        'value': currentScore,
        'label': 'Bugün',
        'type': currentType,
      },
    ];
  }

  // Tüm rapor verilerini silme (verileri sıfırla için)
  Future<void> clearAllReports(String userId) async {
    _setLoading(true);
    try {
      // Kullanıcının raporlarını al
      final reportsSnapshot = await _firestore
          .collection('relationship_reports')
          .where('userId', isEqualTo: userId)
          .get();
      
      // Batch işlemi başlat
      WriteBatch batch = _firestore.batch();
      
      // Her raporu silme işlemine ekle
      for (var doc in reportsSnapshot.docs) {
        // Önce yorumları sil
        final commentsSnapshot = await _firestore
            .collection('relationship_reports')
            .doc(doc.id)
            .collection('comments')
            .get();
            
        for (var commentDoc in commentsSnapshot.docs) {
          batch.delete(commentDoc.reference);
        }
        
        // Sonra rapor belgesini sil
        batch.delete(doc.reference);
      }
      
      // Batch işlemini uygula
      await batch.commit();
      
      // Yerel verileri temizle
      _reportResult = null;
      _answers = ['', '', '', '', '', ''];
      _currentQuestionIndex = 0;
      _comments = [];
      _relationshipHistory = null;
      
      // Geçmiş raporlar ViewModel'i varsa onu da temizle
      final context = _comments.isNotEmpty 
          ? _comments.first['context'] as BuildContext?
          : null;
          
      if (context != null) {
        try {
          final pastReportsViewModel = Provider.of<PastReportsViewModel>(context, listen: false);
          await pastReportsViewModel.clearAllReports(userId);
        } catch (e) {
          debugPrint('PastReportsViewModel temizleme hatası: $e');
        }
      }
      
      notifyListeners();
      debugPrint('Tüm raporlar başarıyla silindi');
      
    } catch (e) {
      _setError('Raporlar silinirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }
} 