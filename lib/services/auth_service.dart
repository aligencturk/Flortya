import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'logger_service.dart';
import '../utils/utils.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final GoogleSignIn _googleSignIn;
  final LoggerService _logger = LoggerService();
  
  AuthService() {
    // Platforma özgü Google Sign In yapılandırması
    if (Platform.isIOS) {
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        // iOS için clientID belirtmeyin, otomatik olarak bulacaktır
      );
    } else {
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: '850956703555-aaikom41i48eoelhmfvcmspmdp940hc2.apps.googleusercontent.com', // Web client ID
      );
    }
  }

  // Mevcut kullanıcıyı almak
  User? get currentUser => _auth.currentUser;

  // Kullanıcı oturum durumu stream'i
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google ile giriş
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Google Sign-In işlemi
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      
      if (googleUser == null) {
        return null; // Kullanıcı işlemi iptal etti
      }
      
      // Google hesabından kimlik bilgileri al
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Firebase ile yetkilendirme
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Firebase ile giriş yap
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Yeni bir kullanıcıysa Firestore'a kaydet
      await _saveUserToFirestore(userCredential.user, authProvider: 'google.com');
      
      return userCredential;
    } catch (e) {
      _logger.e('Google giriş hatası: $e');
      return null;
    }
  }
  
  // Apple ile giriş
  Future<UserCredential?> signInWithApple() async {
    try {
      // Apple ile giriş fonksiyonu şimdilik uygulanmadı
      // Gerekirse daha sonra sign_in_with_apple paketi kurulup gerçekleştirilebilir
      _logger.w('Apple ile giriş henüz uygulanmadı');
      return null;
    } catch (e) {
      _logger.e('Apple giriş hatası: $e');
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
      DocumentSnapshot<Map<String, dynamic>> doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      
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

  // E-posta ve şifre ile kayıt olma işlemi
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    String? firstName,
    String? lastName,
    String? gender,
    DateTime? birthDate,
  }) async {
    try {
      // Firebase Auth ile kullanıcı oluştur
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Kullanıcı profilini güncelle
      await userCredential.user?.updateDisplayName(displayName);
      
      // Kullanıcı bilgilerini yenile
      await userCredential.user?.reload();
      
      // Kullanıcıyı Firestore'a kaydet
      await _saveUserToFirestore(
        userCredential.user, 
        authProvider: 'password',
        firstName: firstName,
        lastName: lastName,
        gender: gender,
        birthDate: birthDate,
      );
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      _logger.e('E-posta kayıt hatası: ${e.code}');
      rethrow;
    } catch (e) {
      _logger.e('E-posta kayıt hatası: $e');
      return null;
    }
  }
  
  // E-posta ve şifre ile giriş yapma
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('E-posta ile giriş yapılıyor: $email');
      
      // Firebase Auth ile giriş yap
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Kullanıcı verilerini güncelle
      await _updateUserData(userCredential.user!);
      
      _logger.i('E-posta ile giriş başarılı: ${userCredential.user?.uid}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Bu e-posta adresine sahip bir kullanıcı bulunamadı.';
          break;
        case 'wrong-password':
          errorMessage = 'Şifre yanlış.';
          break;
        case 'invalid-email':
          errorMessage = 'Geçersiz e-posta adresi.';
          break;
        case 'user-disabled':
          errorMessage = 'Bu kullanıcı hesabı devre dışı bırakıldı.';
          break;
        default:
          errorMessage = 'Giriş sırasında bir hata oluştu: ${e.message}';
      }
      
      _logger.e('E-posta giriş hatası: $errorMessage', e);
      rethrow;
    } catch (e) {
      _logger.e('E-posta giriş hatası: ${e.toString()}', e);
      rethrow;
    }
  }

  // Kullanıcıyı Firestore'a kaydet
  Future<void> _saveUserToFirestore(
    User? user, {
    required String? authProvider,
    String? firstName,
    String? lastName,
    String? gender,
    DateTime? birthDate,
  }) async {
    if (user == null) return;
    
    try {
      final usersRef = _firestore.collection('users');
      final userDoc = usersRef.doc(user.uid);
      
      // Kullanıcı zaten var mı kontrol et
      final docSnapshot = await userDoc.get();
      
      if (docSnapshot.exists) {
        // Kullanıcı zaten var, sadece login bilgilerini güncelle
        await userDoc.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'photoURL': user.photoURL,
          'displayName': user.displayName,
        });
      } else {
        // Yeni kullanıcı oluştur
        final userData = {
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'authProvider': authProvider,
          'isPremium': false,
          'premiumExpiry': null,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'profileCompleted': false,
        };
        
        // Eğer profil bilgileri verilmişse ekle
        if (firstName != null) userData['firstName'] = firstName;
        if (lastName != null) userData['lastName'] = lastName;
        if (gender != null) userData['gender'] = gender;
        if (birthDate != null) userData['birthDate'] = Timestamp.fromDate(birthDate);
        
        // E-posta ile kayıtta profil tamamlandı olarak işaretle
        if (authProvider == 'password' && firstName != null && lastName != null && gender != null) {
          userData['profileCompleted'] = true;
        }
        
        await userDoc.set(userData);
      }
    } catch (e) {
      _logger.e('Kullanıcı Firestore kayıt hatası: $e');
    }
  }
} 