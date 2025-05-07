import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../services/ai_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../viewmodels/past_reports_viewmodel.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class ReportViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AiService _aiService = AiService();
  
  // Statik sorular (sadece yedek olarak tutuyoruz, artık kullanılmayacak)
  final List<String> _fallbackQuestions = [
    'Partnerinizin duygularınıza değer verdiğini düşünüyor musunuz?',
    'İlişkinizde isteklerinizi açıkça ifade edebildiğinizi hissediyor musunuz?',
    'Partnerinize tamamen güvendiğinizi söyleyebilir misiniz?',
    'İlişkinizde yeterince takdir edildiğinizi düşünüyor musunuz?',
    'Partnerinizle gelecek planlarınızın uyumlu olduğuna inanıyor musunuz?',
    'İlişkinizde kendinizi özgür hissettiğinizi düşünüyor musunuz?',
    'Partnerinizle ortak ilgi alanlarınızın yeterli olduğunu düşünüyor musunuz?',
    'İlişkinizde sorunları etkili şekilde çözebildiğinize inanıyor musunuz?',
    'Partnerinizin sizi her konuda desteklediğini hissediyor musunuz?',
    'İlişkinizde sevgi gösterme biçimlerinizin uyumlu olduğunu düşünüyor musunuz?',
    'Partnerinizle olan iletişiminizin sağlıklı olduğunu düşünüyor musunuz?',
    'İlişkinizde yeterince saygı gördüğünüzü hissediyor musunuz?',
    'Partnerinizle birlikte geçirdiğiniz zamanın yeterli olduğunu düşünüyor musunuz?',
    'İlişkinizde fedakarlıkların karşılıklı olduğuna inanıyor musunuz?',
    'Partnerinizin ailenizle ilişkilerinin iyi olduğunu düşünüyor musunuz?',
  ];
  
  // Yapay zeka tarafından üretilen sorular
  List<String> _questions = [];
  
  // Sorular ne zaman yenilenecek
  DateTime? _nextQuestionUpdateTime;
  Timer? _countdownTimer;
  
  // Geri sayım süresi (saniye cinsinden)
  int _remainingTimeInSeconds = 0;
  
  List<String> _answers = [];
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
    if (_questions.isEmpty) {
      return "Sorular yükleniyor...";
    }
    
    if (_currentQuestionIndex >= 0 && _currentQuestionIndex < _questions.length) {
      return _questions[_currentQuestionIndex];
    } else {
      return "Bilinmeyen soru";
    }
  }
  
  Map<String, dynamic>? get reportResult => _reportResult;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasReport => _reportResult != null;
  bool get isLastQuestion => _currentQuestionIndex == _questions.length - 1;
  bool get allQuestionsAnswered => _answers.length == _questions.length && !_answers.any((answer) => answer.isEmpty);
  List<Map<String, dynamic>> get comments => _comments;
  
  // Geri sayım için getters
  int get remainingDays => _remainingTimeInSeconds ~/ 86400;
  int get remainingHours => (_remainingTimeInSeconds % 86400) ~/ 3600;
  int get remainingMinutes => (_remainingTimeInSeconds % 3600) ~/ 60;
  int get remainingSeconds => _remainingTimeInSeconds % 60;
  bool get questionsNeedUpdate => _nextQuestionUpdateTime == null || DateTime.now().isAfter(_nextQuestionUpdateTime!);
  DateTime? get nextUpdateTime => _nextQuestionUpdateTime;
  
  // Constructor
  ReportViewModel() {
    _initializeQuestions();
  }
  
  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
  
  // Soruları başlat
  Future<void> _initializeQuestions() async {
    _setLoading(true);
    
    try {
      // SharedPreferences'dan soruları ve güncelleme zamanını yükle
      final prefs = await SharedPreferences.getInstance();
      final savedQuestions = prefs.getStringList('relationship_questions');
      final nextUpdateTimeMillis = prefs.getInt('next_question_update_time');
      
      if (nextUpdateTimeMillis != null) {
        _nextQuestionUpdateTime = DateTime.fromMillisecondsSinceEpoch(nextUpdateTimeMillis);
      }
      
      // Eğer kaydedilmiş sorular varsa ve güncelleme zamanı gelmemişse, onları kullan
      if (savedQuestions != null && savedQuestions.isNotEmpty && !questionsNeedUpdate) {
        _questions = savedQuestions;
        _initializeAnswers();
        _startCountdownTimer();
      } else {
        // Değilse, yeni sorular üret
        await _generateNewQuestions();
      }
    } catch (e) {
      debugPrint('Sorular yüklenirken hata oluştu: $e');
      _questions = _fallbackQuestions;
      _initializeAnswers();
    } finally {
      _setLoading(false);
    }
  }
  
  // Yeni sorular üret
  Future<void> _generateNewQuestions() async {
    try {
      // Yapay zekadan 15 yeni soru üret
      final newQuestions = await _aiService.generateRelationshipQuestions();
      
      if (newQuestions.isNotEmpty) {
        _questions = newQuestions;
        
        // Bir hafta sonrası için güncelleme zamanı ayarla
        _nextQuestionUpdateTime = DateTime.now().add(const Duration(days: 7));
        
        // Soruları ve güncelleme zamanını locale kaydet
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('relationship_questions', _questions);
        await prefs.setInt('next_question_update_time', _nextQuestionUpdateTime!.millisecondsSinceEpoch);
        
        // Cevapları sıfırla
        _initializeAnswers();
        
        // Geri sayım sayacını başlat
        _startCountdownTimer();
        
        notifyListeners();
      } else {
        // Yapay zeka soru üretemediyse yedek soruları kullan
        _questions = _fallbackQuestions;
        _initializeAnswers();
      }
    } catch (e) {
      debugPrint('Yeni sorular üretilirken hata oluştu: $e');
      _questions = _fallbackQuestions;
      _initializeAnswers();
    }
  }
  
  // Cevapları sıfırla
  void _initializeAnswers() {
    _answers = List.filled(_questions.length, '');
  }
  
  // Geri sayım sayacını başlat
  void _startCountdownTimer() {
    if (_nextQuestionUpdateTime == null) return;
    
    // Şu anki zaman ile sonraki güncelleme zamanı arasındaki farkı hesapla
    final now = DateTime.now();
    final difference = _nextQuestionUpdateTime!.difference(now);
    
    // Kalan süreyi saniye cinsinden ayarla
    _remainingTimeInSeconds = difference.inSeconds > 0 ? difference.inSeconds : 0;
    
    // Varsa önceki sayacı iptal et
    _countdownTimer?.cancel();
    
    // Yeni sayacı başlat
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTimeInSeconds > 0) {
        _remainingTimeInSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
        _generateNewQuestions();
      }
    });
  }

  // Cevap kaydetme
  void saveAnswer(String answer) {
    if (_currentQuestionIndex < _answers.length) {
      _answers[_currentQuestionIndex] = answer;
      notifyListeners();
    }
  }

  // Sonraki soruya geçme
  void nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
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
    try {
      debugPrint('resetReport çağrıldı');
      
      // Mevcut durumu kaydetme
      final hadData = _answers.any((answer) => answer.isNotEmpty) || 
                       _reportResult != null || 
                       _comments.isNotEmpty || 
                       _relationshipHistory != null;
      
      debugPrint('Rapor verileri temizleniyor...');
      _initializeAnswers();
      _currentQuestionIndex = 0;
      _reportResult = null;
      _errorMessage = null;
      _comments = [];
      _relationshipHistory = null;
      
      if (hadData) {
        notifyListeners();
        debugPrint('Rapor verileri başarıyla temizlendi ve UI güncellemesi bildirildi');
      } else {
        debugPrint('Temizlenecek rapor verisi yoktu, UI bildirimi yapılmadı');
      }
    } catch (e) {
      debugPrint('Rapor sıfırlama işleminde hata: $e');
      
      // Hata olsa da temizlemeye çalış
      try {
        _initializeAnswers();
        _currentQuestionIndex = 0;
        _reportResult = null;
        _errorMessage = 'Rapor sıfırlanırken hata oluştu: $e';
        _comments = [];
        _relationshipHistory = null;
        notifyListeners();
        debugPrint('Hata sonrası temizleme tamamlandı');
      } catch (innerError) {
        debugPrint('Hata sonrası temizleme işleminde ikinci bir hata: $innerError');
      }
    }
  }
  
  // Cevapları yeniden başlat
  void resetAnswers() {
    _initializeAnswers();
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