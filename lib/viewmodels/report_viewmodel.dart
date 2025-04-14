import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/ai_service.dart';

class ReportViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AiService _aiService = AiService();
  
  List<String> _questions = [
    'İlişkinizdeki en büyük sorun nedir?',
    'Partnerinizle nasıl iletişim kuruyorsunuz?',
    'İlişkinizde sizi en çok ne mutlu ediyor?',
    'İlişkinizde gelecek beklentileriniz neler?',
    'İlişkinizde değiştirmek istediğiniz bir şey var mı?',
  ];
  
  List<String> _answers = ['', '', '', '', ''];
  int _currentQuestionIndex = 0;
  Map<String, dynamic>? _reportResult;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _comments = [];

  // Getters
  List<String> get questions => _questions;
  List<String> get answers => _answers;
  int get currentQuestionIndex => _currentQuestionIndex;
  String get currentQuestion => _questions[_currentQuestionIndex];
  Map<String, dynamic>? get reportResult => _reportResult;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasReport => _reportResult != null;
  bool get isLastQuestion => _currentQuestionIndex == _questions.length - 1;
  bool get allQuestionsAnswered => !_answers.any((answer) => answer.isEmpty);
  List<Map<String, dynamic>> get comments => _comments;

  // Cevap kaydetme
  void saveAnswer(String answer) {
    _answers[_currentQuestionIndex] = answer;
    notifyListeners();
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
    _answers = ['', '', '', '', ''];
    _currentQuestionIndex = 0;
    _reportResult = null;
    _comments = [];
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