import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Oturum açmış kullanıcıyı getir
  Future<UserModel?> getCurrentUser() async {
    // Oturum kontrolü
    if (_auth.currentUser == null) return null;
    
    try {
      // Kullanıcı belgesini al
      final doc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
      
      if (!doc.exists) return null;
      
      // UserModel nesnesine dönüştür
      return UserModel.fromFirestore(doc);
    } catch (e) {
      print('Kullanıcı verileri alınırken hata oluştu: $e');
      return null;
    }
  }

  /// Son analiz sonucunu güncelle
  Future<bool> updateSonAnalizSonucu(AnalizSonucu analizSonucu) async {
    // Oturum kontrolü
    if (_auth.currentUser == null) return false;
    
    try {
      // Firestore'a kaydet
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update({
        'sonAnalizSonucu': analizSonucu.toMap(),
      });
      
      return true;
    } catch (e) {
      print('Son analiz sonucu güncellenirken hata oluştu: $e');
      return false;
    }
  }

  /// Analiz geçmişine yeni analiz ekle
  Future<bool> addToAnalizGecmisi(AnalizSonucu analizSonucu) async {
    // Oturum kontrolü
    if (_auth.currentUser == null) return false;
    
    try {
      // Firestore'a kaydet
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update({
        'analizGecmisi': FieldValue.arrayUnion([analizSonucu.toMap()]),
        'sonAnalizSonucu': analizSonucu.toMap(),
      });
      
      return true;
    } catch (e) {
      print('Analiz geçmişi güncellenirken hata oluştu: $e');
      return false;
    }
  }

  /// Kullanıcı profilini tam olarak güncelle
  Future<bool> updateUserProfile({
    required String displayName,
    required Map<String, dynamic> preferences,
  }) async {
    // Oturum kontrolü
    if (_auth.currentUser == null) return false;
    
    try {
      // Firestore'a kaydet
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update({
        'displayName': displayName,
        'preferences': preferences,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print('Kullanıcı profili güncellenirken hata oluştu: $e');
      return false;
    }
  }
} 