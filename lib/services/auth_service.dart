import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'logger_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '850956703555-aaikom41i48eoelhmfvcmspmdp940hc2.apps.googleusercontent.com', // Web client ID
  );
  final LoggerService _logger = LoggerService();

  // Mevcut kullanıcıyı almak
  User? get currentUser => _auth.currentUser;

  // Kullanıcı oturum durumu stream'i
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google ile giriş
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Google oturum açma akışını başlat
      _logger.i('Google oturum açma akışı başlatılıyor...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        _logger.w('Kullanıcı Google girişini iptal etti');
        return null;
      }
      
      _logger.i('Google kullanıcısı seçildi: ${googleUser.email}');
      
      // Google kimlik bilgilerini kullanarak Firebase için kimlik bilgisi edinin
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.idToken == null) {
        _logger.e('Google kimlik doğrulama belirteci alınamadı');
        throw FirebaseAuthException(
          code: 'google-auth-failed',
          message: 'Google kimlik doğrulama belirteci alınamadı'
        );
      }
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      _logger.i('Google ile giriş yapılıyor: ${googleUser.email}');

      // Firebase ile giriş yap
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Kullanıcı belgesini Firestore'a ekleyin veya güncelleyin
      await _updateUserData(userCredential.user!);
      
      _logger.i('Google ile giriş başarılı: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      _logger.e('Google ile giriş hatası: ${e.toString()}', e);
      return null;
    }
  }

  // Apple ile giriş
  Future<UserCredential?> signInWithApple() async {
    try {
      // Apple giriş akışı burada yapılacak
      // (Bu işlev şu anda uygulanmamıştır)
      _logger.w('Apple ile giriş henüz uygulanmadı');
      return null;
    } catch (e) {
      _logger.e('Apple ile giriş hatası', e);
      return null;
    }
  }

  // Çıkış yap
  Future<void> signOut() async {
    _logger.i('Kullanıcı çıkış yapıyor: ${currentUser?.uid}');
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
      _logger.d('Kullanıcı bilgileri alınıyor: ${currentUser!.uid}');
      
      // Firestore'dan güncel veriyi al
      DocumentSnapshot doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      
      if (doc.exists) {
        _logger.d('Kullanıcı verisi bulundu: ${doc.data()}');
        return UserModel.fromFirestore(doc);
      }
      
      _logger.w('Kullanıcı verisi bulunamadı: ${currentUser!.uid}');
      
      // Kullanıcı verisi bulunamadıysa, temel bilgilerle yeni bir kullanıcı oluştur
      final user = _auth.currentUser!;
      UserModel newUser = UserModel(
        id: user.uid,
        displayName: user.displayName ?? '',
        email: user.email ?? '',
        photoURL: user.photoURL ?? '',
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );
      
      // Yeni kullanıcıyı Firestore'a kaydet
      await _firestore.collection('users').doc(user.uid).set(newUser.toFirestore());
      
      return newUser;
    } catch (e) {
      _logger.e('Kullanıcı verilerini alma hatası', e);
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
      _logger.i('Premium durumu güncelleniyor. isPremium: $isPremium, expiryDate: $expiryDate');
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'isPremium': isPremium,
        'premiumExpiry': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      });
      _logger.i('Premium durumu başarıyla güncellendi');
    } catch (e) {
      _logger.e('Premium durumu güncelleme hatası', e);
    }
  }

  // Kullanıcı adını güncelle
  Future<bool> updateDisplayName(String displayName) async {
    if (currentUser == null) return false;
    
    try {
      _logger.i('Kullanıcı adı güncelleniyor: $displayName');
      
      // Önce Firebase Auth'ta kullanıcı adını güncelle
      await currentUser!.updateDisplayName(displayName);
      
      // Kullanıcı verisini yeniden yükle
      await currentUser!.reload();
      
      // Firestore'da da kullanıcı adını güncelle
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'displayName': displayName,
        'name': displayName,
        'updatedAt': Timestamp.now(),
      });
      
      _logger.i('Kullanıcı adı başarıyla güncellendi');
      return true;
    } catch (e) {
      _logger.e('Kullanıcı adı güncelleme hatası', e);
      return false;
    }
  }
} 