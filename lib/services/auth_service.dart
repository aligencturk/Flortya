import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Mevcut kullanıcıyı almak
  User? get currentUser => _auth.currentUser;

  // Kullanıcı oturum durumu stream'i
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google ile giriş
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Google oturum açma akışını başlat
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) return null;
      
      // Google kimlik bilgilerini kullanarak Firebase için kimlik bilgisi edinin
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase ile giriş yap
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Kullanıcı belgesini Firestore'a ekleyin veya güncelleyin
      await _updateUserData(userCredential.user!);
      
      return userCredential;
    } catch (e) {
      debugPrint('Google ile giriş hatası: $e');
      return null;
    }
  }

  // Apple ile giriş
  Future<UserCredential?> signInWithApple() async {
    try {
      // Apple giriş akışı burada yapılacak
      // (Bu işlev şu anda uygulanmamıştır)
      return null;
    } catch (e) {
      debugPrint('Apple ile giriş hatası: $e');
      return null;
    }
  }

  // Çıkış yap
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    return await _auth.signOut();
  }

  // Kullanıcı verilerini Firestore'da güncelle
  Future<void> _updateUserData(User user) async {
    DocumentReference userRef = _firestore.collection('users').doc(user.uid);
    
    // Kullanıcının zaten var olup olmadığını kontrol et
    DocumentSnapshot snapshot = await userRef.get();
    
    if (snapshot.exists) {
      // Kullanıcı zaten var, son giriş zamanını güncelle
      await userRef.update({
        'lastLoginAt': Timestamp.now(),
      });
    } else {
      // Yeni kullanıcı oluştur
      UserModel newUser = UserModel(
        id: user.uid,
        displayName: user.displayName ?? '',
        email: user.email ?? '',
        photoURL: user.photoURL ?? '',
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );
      
      await userRef.set(newUser.toFirestore());
    }
  }

  // Kullanıcı bilgilerini Firestore'dan alma
  Future<UserModel?> getUserData() async {
    if (currentUser == null) return null;
    
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Kullanıcı verilerini alma hatası: $e');
      return null;
    }
  }

  // Premium abonelik durumunu güncelle
  Future<void> updatePremiumStatus({
    required bool isPremium, 
    required DateTime? expiryDate
  }) async {
    if (currentUser == null) return;
    
    try {
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'isPremium': isPremium,
        'premiumExpiry': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      });
    } catch (e) {
      debugPrint('Premium durumu güncelleme hatası: $e');
    }
  }
} 