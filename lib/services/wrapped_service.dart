import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../services/logger_service.dart';

class WrappedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LoggerService _logger = LoggerService();

  /// Wrapped analiz verilerini Firestore'a kaydetme
  /// Bu metot, wrapped analiz verilerini, ilgili içeriği ve dosya türünü kaydeder
  Future<bool> saveWrappedAnalysis({
    required List<Map<String, String>> summaryData,
    required String fileContent,
    required bool isTxtFile,
  }) async {
    try {
      // Kullanıcı kontrolü
      final user = _auth.currentUser;
      if (user == null) {
        _logger.e('Wrapped veri kaydetme hatası: Oturum açmış kullanıcı yok');
        return false;
      }

      // JSON formatına dönüştürme
      final String encodedData = jsonEncode(summaryData);

      // Firestore'a kaydetme
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wrapped_analyses')
          .doc('current_analysis')
          .set({
        'summaryData': encodedData,
        'fileContent': fileContent,
        'isTxtFile': isTxtFile,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _logger.i('${summaryData.length} wrapped analiz sonucu Firestore\'a kaydedildi');
      return true;
    } catch (e) {
      _logger.e('Wrapped veri kaydetme hatası: $e');
      return false;
    }
  }

  /// Wrapped analiz verilerini Firestore'dan getirme
  Future<Map<String, dynamic>?> getWrappedAnalysis() async {
    try {
      // Kullanıcı kontrolü
      final user = _auth.currentUser;
      if (user == null) {
        _logger.e('Wrapped veri getirme hatası: Oturum açmış kullanıcı yok');
        return null;
      }

      // Firestore'dan verileri al
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wrapped_analyses')
          .doc('current_analysis')
          .get();

      if (!doc.exists || doc.data() == null) {
        _logger.i('Wrapped analiz sonucu bulunamadı');
        return null;
      }

      final data = doc.data()!;
      
      // JSON verisini ayrıştırma
      final String encodedData = data['summaryData'] as String;
      final List<dynamic> decodedData = jsonDecode(encodedData);
      
      final List<Map<String, String>> summaryData = List<Map<String, String>>.from(
        decodedData.map((item) => Map<String, String>.from(item))
      );

      return {
        'summaryData': summaryData,
        'fileContent': data['fileContent'] as String,
        'isTxtFile': data['isTxtFile'] as bool,
      };
    } catch (e) {
      _logger.e('Wrapped veri getirme hatası: $e');
      return null;
    }
  }

  /// Wrapped analiz verilerini Firestore'dan silme
  Future<bool> deleteWrappedAnalysis() async {
    try {
      // Kullanıcı kontrolü
      final user = _auth.currentUser;
      if (user == null) {
        _logger.e('Wrapped veri silme hatası: Oturum açmış kullanıcı yok');
        return false;
      }

      // Firestore'dan verileri sil
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wrapped_analyses')
          .doc('current_analysis')
          .delete();

      _logger.i('Wrapped analiz sonucu Firestore\'dan silindi');
      return true;
    } catch (e) {
      _logger.e('Wrapped veri silme hatası: $e');
      return false;
    }
  }

  /// Wrapped analiz verilerinin var olup olmadığını kontrol etme
  Future<bool> hasWrappedAnalysis() async {
    try {
      // Kullanıcı kontrolü
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      // Firestore'dan belgeyi kontrol et
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wrapped_analyses')
          .doc('current_analysis')
          .get();

      return doc.exists;
    } catch (e) {
      _logger.e('Wrapped veri kontrolü hatası: $e');
      return false;
    }
  }
} 