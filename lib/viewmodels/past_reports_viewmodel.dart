import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/past_report_model.dart';
import '../viewmodels/report_viewmodel.dart';

class PastReportsViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ReportViewModel _reportViewModel;
  
  List<PastReport> _reports = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Yapıcı metod
  PastReportsViewModel(this._reportViewModel);

  // Getters
  List<PastReport> get reports => _reports;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasReports => _reports.isNotEmpty;

  // Yükleme ve hata yardımcı metodları
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    if (error != null) {
      _isLoading = false;
    }
    notifyListeners();
  }

  // Kullanıcının tüm geçmiş raporlarını yükleme
  Future<void> loadUserReports(String userId) async {
    _setLoading(true);
    try {
      // Kullanıcının tüm raporlarını al
      final reportsSnapshot = await _firestore
          .collection('relationship_reports')
          .where('userId', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();
      
      List<PastReport> loadedReports = [];
      
      for (final reportDoc in reportsSnapshot.docs) {
        final report = PastReport.fromFirestore(
          reportDoc,
          questions: _reportViewModel.questions,
        );
        loadedReports.add(report);
      }
      
      _reports = loadedReports;
      notifyListeners();
      
    } catch (e) {
      _setError('Geçmiş raporlar yüklenirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Belirli bir raporu ID'ye göre getirme
  PastReport? getReportById(String reportId) {
    try {
      return _reports.firstWhere(
        (report) => report.id == reportId,
      );
    } catch (e) {
      return null;
    }
  }
  
  // Tüm rapor verilerini silme (verileri sıfırla için)
  Future<void> clearAllReports(String userId) async {
    _setLoading(true);
    try {
      // Burada raporları temizleme işlemi yapılacak
      // Not: Gerçek silme işlemi ReportViewModel içinde yapılacak
      _reports = [];
      notifyListeners();
    } catch (e) {
      _setError('Raporlar silinirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }
} 