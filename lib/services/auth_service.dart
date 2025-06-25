import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../models/user_model.dart';
import 'logger_service.dart';
import 'encryption_service.dart';
import 'package:flutter/foundation.dart';

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
        // serverClientId'yi kaldırdık - genellikle gerekli değil
      );
    }
    
    _logger.i('🔧 AuthService başlatıldı');
    _logger.d('📱 Platform: ${Platform.operatingSystem}');
    _logger.d('🔍 Google Sign-In scopes: ${_googleSignIn.scopes}');
  }

  // Mevcut kullanıcıyı almak
  User? get currentUser => _auth.currentUser;

  // Kullanıcı oturum durumu stream'i
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google ile giriş
  Future<UserCredential?> signInWithGoogle() async {
    try {
      _logger.i('🔄 Google Sign-In başlatılıyor...');
      
      // Aynı instance'ı kullan - _googleSignIn
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        _logger.i('❌ Kullanıcı Google Sign-In işlemini iptal etti');
        return null; // Kullanıcı işlemi iptal etti
      }
      
      _logger.i('✅ Google hesabı seçildi: ${googleUser.email}');
      
      // Google hesabından kimlik bilgileri al
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      _logger.i('🔑 Google auth tokens alındı');
      _logger.d('AccessToken: ${googleAuth.accessToken != null ? "Var" : "Yok"}');
      _logger.d('IdToken: ${googleAuth.idToken != null ? "Var" : "Yok"}');
      
      // Firebase ile yetkilendirme
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      _logger.i('🔥 Firebase credential oluşturuldu, giriş yapılıyor...');
      
      // Firebase ile giriş yap
      final userCredential = await _auth.signInWithCredential(credential);
      
      _logger.i('🎉 Firebase giriş başarılı: ${userCredential.user?.email}');
      
      // Yeni bir kullanıcıysa Firestore'a kaydet
      await _saveUserToFirestore(userCredential.user, authProvider: 'google.com');
      
      return userCredential;
    } catch (e) {
      _logger.e('❌ Google giriş hatası: $e');
      
      // Spesifik hata mesajları
      if (e.toString().contains('network_error')) {
        _logger.e('🌐 Ağ bağlantısı sorunu');
      } else if (e.toString().contains('sign_in_failed')) {
        _logger.e('🔐 Google Sign-In başarısız');
      } else if (e.toString().contains('invalid-credential')) {
        _logger.e('🚫 Geçersiz kimlik bilgileri - SHA-1 yapılandırması kontrol edilmeli');
      }
      
      return null;
    }
  }
  
  // Apple ile giriş
  Future<UserCredential?> signInWithApple() async {
    try {
      _logger.i('🍎 Apple Sign-In başlatılıyor...');
      
      // Apple Sign-In'in desteklendiğini kontrol et
      if (!await SignInWithApple.isAvailable()) {
        _logger.w('❌ Apple Sign-In bu cihazda desteklenmiyor');
        return null;
      }
      
      _logger.i('✅ Apple Sign-In destekleniyor, kimlik bilgileri alınıyor...');
      
      // Nonce oluştur
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);
      
      _logger.d('🔐 Nonce oluşturuldu');
      
      // Apple Sign-In isteğini yap
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      
      _logger.i('🎯 Apple kimlik bilgileri alındı');
      _logger.d('Email: ${appleCredential.email ?? "Belirtilmedi"}');
      _logger.d('GivenName: ${appleCredential.givenName ?? "Belirtilmedi"}');
      _logger.d('FamilyName: ${appleCredential.familyName ?? "Belirtilmedi"}');
      
      // Firebase credential oluştur
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );
      
      _logger.i('🔥 Firebase credential oluşturuldu, giriş yapılıyor...');
      
      // Firebase ile giriş yap
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      
      _logger.i('🎉 Firebase Apple giriş başarılı: ${userCredential.user?.email}');
      
      // Eğer kullanıcının display name'i yoksa Apple'dan gelen bilgileri kullan
      if (userCredential.user != null && 
          (userCredential.user!.displayName?.isEmpty ?? true) &&
          appleCredential.givenName != null) {
        final displayName = '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim();
        if (displayName.isNotEmpty) {
          await userCredential.user!.updateDisplayName(displayName);
          _logger.i('👤 Display name güncellendi: $displayName');
        }
      }
      
      // Kullanıcıyı Firestore'a kaydet
      await _saveUserToFirestore(userCredential.user, authProvider: 'apple.com');
      
      _logger.i('🎊 Apple ile giriş tamamen başarılı: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      if (e.toString().contains('canceled')) {
        _logger.i('🚫 Apple ile giriş kullanıcı tarafından iptal edildi');
        return null;
      }
      
      _logger.e('❌ Apple giriş hatası: $e');
      
      // Spesifik hata mesajları
      if (e.toString().contains('invalid-credential')) {
        _logger.e('🚫 Geçersiz Apple kimlik bilgileri');
      } else if (e.toString().contains('network_error')) {
        _logger.e('🌐 Ağ bağlantısı sorunu - Apple Sign-In');
      }
      
      return null;
    }
  }
  
  // Güvenli nonce oluşturucu
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }
  
  // SHA256 hash fonksiyonu
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
 
  
  // Çıkış yap
  Future<void> signOut() async {
    _logger.i('Kullanıcı çıkış yapıyor: ${currentUser?.uid}');
    
    // Google Sign-In'den çıkış yap
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      _logger.e('Google Sign-In çıkış hatası: $e');
    }
    
    // Firebase Auth'tan çıkış yap
    return await _auth.signOut();
  }

  // Kullanıcı verilerini Firestore'da güncelle
  Future<void> _updateUserData(User user) async {
    try {
      debugPrint('Kullanıcı verileri güncelleniyor: ${user.uid}');
      
      if (user.uid.isEmpty) {
        debugPrint('HATA: Kullanıcı UID boş, güncelleme yapılamıyor');
        return;
      }
      
      // Şifreleme servisini kullanıcı ID'si ile başlat
      EncryptionService().initializeWithUserId(user.uid);
      _logger.i('Şifreleme servisi kullanıcı girişinde başlatıldı');
      
      DocumentReference userRef = _firestore.collection('users').doc(user.uid);
      
      try {
        // Kullanıcının zaten var olup olmadığını kontrol et
        debugPrint('Kullanıcı verileri Firestore\'dan kontrol ediliyor...');
        DocumentSnapshot snapshot = await userRef.get();
        
        if (snapshot.exists) {
          // Kullanıcı zaten var, son giriş zamanını güncelle
          debugPrint('Kullanıcı verisi mevcut, son giriş zamanı güncelleniyor');
          
          final updateData = {
            'lastLoginAt': Timestamp.now(),
          };
          
          // premiumExpiry alanı yoksa ekle
          final userData = snapshot.data() as Map<String, dynamic>?;
          if (userData != null && !userData.containsKey('premiumExpiry')) {
            updateData['premiumExpiry'] = null as dynamic;
            debugPrint('⚡ premiumExpiry alanı eksikti, null olarak eklendi');
          }
          
          await userRef.update(updateData);
        } else {
          // Yeni kullanıcı oluştur
          debugPrint('Kullanıcı verisi bulunamadı, yeni kullanıcı oluşturuluyor');
          Map<String, dynamic> userData = {
            'id': user.uid,
            'displayName': user.displayName ?? '',
            'email': user.email ?? '',
            'photoURL': user.photoURL ?? '',
            'createdAt': Timestamp.now(),
            'lastLoginAt': Timestamp.now(),
            'authProvider': 'password', // Varsayılan olarak e-posta/şifre
            'isPremium': false,
            'premiumExpiry': null, // ✅ Premium expiry alanını null olarak ekle
          };
          
          await userRef.set(userData);
          debugPrint('Yeni kullanıcı verisi oluşturuldu: ${user.uid}');
        }
      } catch (firestoreError) {
        debugPrint('Firestore işlemi sırasında hata: $firestoreError');
        // Hata durumunda bu fonksiyondan çıkarız ama kullanıcı girişi hala geçerli olabilir
      }
    } catch (e) {
      debugPrint('Kullanıcı verilerini güncellerken beklenmeyen hata: $e');
      // Bu hatayı dışarı yansıtmıyoruz - kullanıcı girişi yine de başarılı olabilir
    }
  }

  // Kullanıcı bilgilerini Firestore'dan alma
  Future<UserModel?> getUserData() async {
    try {
      if (currentUser == null) {
        debugPrint('UYARI: Oturum açmış kullanıcı bulunamadı');
        return null;
      }
      
      if (currentUser!.uid.isEmpty) {
        debugPrint('HATA: Kullanıcı UID değeri boş');
        return null;
      }
      
      debugPrint('Kullanıcı bilgileri alınıyor: ${currentUser!.uid}');
      
      try {
        // Firestore'dan güncel veriyi al
        DocumentSnapshot<Map<String, dynamic>> doc = await _firestore.collection('users').doc(currentUser!.uid).get();
        
        if (doc.exists) {
          debugPrint('Kullanıcı verisi bulundu');
          try {
            final userData = UserModel.fromFirestore(doc);
            return userData;
          } catch (parseError) {
            debugPrint('Kullanıcı verisi ayrıştırma hatası: $parseError');
            // Veri ayrıştırma başarısız olsa bile devam edelim ve temel bir kullanıcı oluşturalım
          }
        }
        
        debugPrint('Kullanıcı verisi bulunamadı: ${currentUser!.uid}, temel kullanıcı oluşturuluyor');
        
        // Kullanıcı verisi bulunamadıysa, temel bilgilerle yeni bir kullanıcı oluştur
        final user = _auth.currentUser!;
        
        final Map<String, dynamic> userData = {
          'id': user.uid,
          'displayName': user.displayName ?? '',
          'email': user.email ?? '',
          'photoURL': user.photoURL ?? '',
          'createdAt': Timestamp.now(),
          'lastLoginAt': Timestamp.now(),
          'authProvider': 'password', // Varsayılan olarak e-posta/şifre
          'isPremium': false,
          'premiumExpiry': null,
        };
        
        // Yeni kullanıcıyı Firestore'a kaydet
        try {
          await _firestore.collection('users').doc(user.uid).set(userData);
          debugPrint('Temel kullanıcı verisi Firestore\'a kaydedildi');
        } catch (saveError) {
          debugPrint('Kullanıcı verisi kaydedilemedi: $saveError');
          // Kaydetme hatası oluşsa bile basic kullanıcı nesnesini döndürelim
        }
        
        // Temel UserModel'i döndür
        return UserModel(
          id: user.uid,
          displayName: user.displayName ?? '',
          email: user.email ?? '',
          photoURL: user.photoURL ?? '',
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );
      } catch (firestoreError) {
        debugPrint('Firestore işlemi sırasında hata: $firestoreError');
        
        // Firestore hatası durumunda, temel bir kullanıcı nesnesi oluştur
        final user = _auth.currentUser!;
        return UserModel(
          id: user.uid,
          displayName: user.displayName ?? '',
          email: user.email ?? '',
          photoURL: user.photoURL ?? '',
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );
      }
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
  }) async {
    try {
      _logger.i('🚀 AuthService: E-posta ile kayıt işlemi başlatılıyor: $email');
      
      // Firebase Auth ile kullanıcı oluştur
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _logger.i('✅ AuthService: Firebase Auth kullanıcı oluşturma başarılı: ${userCredential.user?.uid}');
      
      // Kullanıcı profilini güncelle
      await userCredential.user?.updateDisplayName(displayName);
      
      // Kullanıcı bilgilerini yenile
      await userCredential.user?.reload();
      
      _logger.i('📝 AuthService: Kullanıcı profili güncellendi, Firestore\'a kaydediliyor...');
      
      // Kullanıcıyı Firestore'a kaydet
      await _saveUserToFirestore(
        userCredential.user, 
        authProvider: 'password',
        firstName: firstName,
        lastName: lastName,
      );
      
      _logger.i('🎉 AuthService: E-posta kayıt işlemi tamamen başarılı');
      return userCredential;
    } on FirebaseAuthException catch (e, stackTrace) {
      // Detaylı Firebase Auth hatası loglama
      _logger.logEmailRegistrationError(
        source: 'AuthService.signUpWithEmail',
        userEmail: email,
        displayName: displayName,
        firebaseError: e,
        stackTrace: stackTrace,
        firstName: firstName,
        lastName: lastName,
      );
      
      // Hata mesajını da ayrıca basit logla
      _logger.e('❌ AuthService: E-posta kayıt hatası: ${e.code} - ${e.message}');
      
      rethrow; // Hata ViewModele aktarılacak
    } catch (e, stackTrace) {
      _logger.e('💥 AuthService: E-posta kayıt hatası (Beklenmeyen): $e');
      _logger.e('📚 Stack trace: $stackTrace');
      return null;
    }
  }
  
  // E-posta ve şifre ile giriş yapma
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('🚀 AuthService: E-posta ile giriş yapılıyor: $email');
      
      // Firebase Auth ile giriş yap
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Kullanıcı verilerini güncelle
      await _updateUserData(userCredential.user!);
      
      _logger.i('✅ AuthService: E-posta ile giriş başarılı: ${userCredential.user?.uid}');
      return userCredential;
    } on FirebaseAuthException catch (e, stackTrace) {
      // Detaylı Firebase Auth hatası loglama
      _logger.logEmailSignInError(
        source: 'AuthService.signInWithEmail',
        userEmail: email,
        firebaseError: e,
        stackTrace: stackTrace,
      );
      
      // Hata kodu için kullanıcı dostu mesaj hazırla
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
        case 'internal-error':
          errorMessage = 'Firebase internal hatası oluştu. Lütfen tekrar deneyin.';
          break;
        default:
          errorMessage = 'Giriş sırasında bir hata oluştu: ${e.message}';
      }
      
      _logger.e('❌ AuthService: E-posta giriş hatası: $errorMessage');
      rethrow; // Hata ViewModele aktarılacak
    } catch (e, stackTrace) {
      _logger.e('💥 AuthService: E-posta giriş hatası (Beklenmeyen): $e');
      _logger.e('📚 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Kullanıcıyı Firestore'a kaydet
  Future<void> _saveUserToFirestore(
    User? user, {
    required String? authProvider,
    String? firstName,
    String? lastName,
  }) async {
    if (user == null) {
      _logger.e('_saveUserToFirestore: Kullanıcı null, kayıt işlemi atlanıyor');
      return;
    }
    
    try {
      _logger.i('📝 Kullanıcı Firestore\'a kaydediliyor: ${user.uid}');
      final usersRef = _firestore.collection('users');
      final userDoc = usersRef.doc(user.uid);
      
      // Kullanıcı zaten var mı kontrol et
      final docSnapshot = await userDoc.get();
      
      if (docSnapshot.exists) {
        _logger.i('✏️ Mevcut kullanıcı güncelleniyor: ${user.uid}');
        
        // Mevcut kullanıcı için sadece temel bilgileri güncelle
        final updateData = {
          'lastLoginAt': FieldValue.serverTimestamp(),
          'photoURL': user.photoURL,
          'displayName': user.displayName,
        };
        
        // Eğer premiumExpiry alanı yoksa ekle
        final userData = docSnapshot.data() as Map<String, dynamic>?;
        if (userData != null && !userData.containsKey('premiumExpiry')) {
          updateData['premiumExpiry'] = null;
          _logger.i('⚡ premiumExpiry alanı eksikti, null olarak eklendi');
        }
        
        await userDoc.update(updateData);
        _logger.i('✅ Mevcut kullanıcı başarıyla güncellendi');
      } else {
        _logger.i('🆕 Yeni kullanıcı oluşturuluyor: ${user.uid}');
        
        // Yeni kullanıcı oluştur - tüm gerekli alanları ekle
        final userData = {
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'authProvider': authProvider,
          'isPremium': false,
          'premiumExpiry': null, // ✅ Premium expiry alanını null olarak ekle
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'profileCompleted': false,
        };
        
        // Eğer profil bilgileri verilmişse ekle
        if (firstName != null) userData['firstName'] = firstName;
        if (lastName != null) userData['lastName'] = lastName;
        
        // E-posta ile kayıtta profil tamamlandı olarak işaretle
        if (authProvider == 'password' && firstName != null && lastName != null) {
          userData['profileCompleted'] = true;
          _logger.i('📋 E-posta kaydı profil bilgileri ile tamamlandı');
        }
        
        await userDoc.set(userData);
        _logger.i('🎉 Yeni kullanıcı başarıyla Firestore\'a kaydedildi');
        _logger.d('📊 Kaydedilen veri: $userData');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Kullanıcı Firestore kayıt hatası: $e');
      _logger.e('📚 Stack trace: $stackTrace');
      
      // Premium kontrol sistemi için kritik hata olduğunu belirt
      throw Exception('Firestore kullanıcı kaydı başarısız: $e');
    }
  }
} 