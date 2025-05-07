import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/logger_service.dart';
import '../services/notification_service.dart';
import 'package:flutter/widgets.dart';

class AuthViewModel extends ChangeNotifier with WidgetsBindingObserver implements Listenable {
  final FirebaseAuth _authService;
  final FirebaseFirestore _firestore;
  final AuthService _authServiceImpl;
  final LoggerService _logger = LoggerService();
  final NotificationService _notificationService = NotificationService();
  
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;
  bool _isPremium = false;

  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;
  bool get isInitialized => _isInitialized;
  bool get isPremium => _isPremium;
  User? get currentUser => _authService.currentUser;

  AuthViewModel({
    required FirebaseAuth authService,
    required FirebaseFirestore firestore,
  }) : _authService = authService,
       _firestore = firestore,
       _authServiceImpl = AuthService() {
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  /// ViewModel başlatma işlemi
  Future<void> _initialize() async {
    try {
      // Başlangıçta kullanıcı bilgilerini al
      final user = _authService.currentUser;
      
      if (user != null) {
        // Firestore'dan kullanıcı profil bilgilerini al
        final userData = await _getUserData(user.uid);
        if (userData != null) {
          _user = userData;
          
          // Premium durumunu kontrol et
          _checkPremiumStatus();
        }
      }
      
      // Auth değişiklikleri için dinleyici ekle
      // NOT: Bu dinleyici dispose edilmelidir
      _setupAuthListener();
      
    } catch (e) {
      _logger.e('AuthViewModel başlatma hatası: $e');
    } finally {
      // Başlatma işlemi tamamlandı
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  // Auth dinleyicisini ayarla
  void _setupAuthListener() {
    // Auth durumu değişimlerini dinle
    _authService.authStateChanges().listen((User? firebaseUser) async {
      try {
        if (firebaseUser == null) {
          // Kullanıcı çıkış yaptı veya hesabı silindi
          _user = null;
          _isPremium = false;
        } else {
          // Kullanıcı giriş yaptı veya oturum açtı
          // Firebase'den kullanıcı verilerini yükle
          final userData = await _getUserData(firebaseUser.uid);
          _user = userData;
          
          // Premium durumunu kontrol et
          _checkPremiumStatus();
        }
      } catch (e) {
        _logger.e('Auth state change hatası: $e');
      } finally {
        // UI güncellemesi için bildirim yap
        notifyListeners();
      }
    });
  }
  
  /// Firebase'den kullanıcı verilerini alır
  Future<UserModel?> _getUserData(String uid) async {
    try {
      _logger.d('Kullanıcı verileri alınıyor: $uid');
      
      final doc = await _firestore.collection('users').doc(uid).get();
      
      if (doc.exists) {
        // Firestore'dan kullanıcı verilerini al
        final userData = UserModel.fromFirestore(doc);
        _logger.d('Kullanıcı verileri alındı: ${userData.displayName}');
        return userData;
      } else {
        _logger.w('Kullanıcı verileri bulunamadı: $uid');
        return null;
      }
    } catch (e) {
      _logger.e('Kullanıcı verileri alınırken hata: $e');
      return null;
    }
  }

  // Google ile giriş yapma
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();
    try {
      final userCredential = await _authServiceImpl.signInWithGoogle();
      if (userCredential != null) {
        final userData = await _authServiceImpl.getUserData();
        _user = userData;
        notifyListeners();
        
        // FCM token'ı güncelle
        if (_user != null) {
          try {
            await _notificationService.updateFcmTokenOnLogin(_user!.id);
          } catch (fcmError) {
            // FCM token güncellemesi başarısız olsa bile giriş işlemine devam et
            _logger.e('FCM token güncellenirken hata oluştu: $fcmError');
            // Hatayı kullanıcıya gösterme, sessizce devam et
          }
        }
        
        // Kullanıcı ilk defa giriş yapıyorsa profil kurulum ekranına yönlendir
        final isFirstTime = await isFirstLogin();
        if (isFirstTime) {
          return false; // Profil tamamlama gerekiyor
        }
        
        return true;
      }
      _setError('Google ile giriş yapılamadı');
      return false;
    } catch (e) {
      _logger.e('Google ile giriş hatası: $e');
      // Hata mesajına göre daha kullanıcı dostu hata mesajı ayarla
      if (e.toString().contains('invalid-credential')) {
        _setError('Bu hesap daha önce silinmiş olabilir. Lütfen yeni bir hesap oluşturun.');
      } else {
        _setError('Google ile giriş hatası: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Premium üyeliğe yükseltme
  Future<bool> upgradeToPremium() async {
    if (_authService.currentUser == null) return false;
    
    _setLoading(true);
    try {
      // Burada gerçek ödeme sistemi entegrasyonu yapılacak
      // Şimdilik sadece veritabanındaki premium durumunu güncelliyoruz
      
      // Premium bitiş tarihini 1 ay sonra olarak ayarla
      final expiryDate = DateTime.now().add(const Duration(days: 30));
      
      await _authServiceImpl.updatePremiumStatus(
        isPremium: true,
        expiryDate: expiryDate,
      );
      
      // Kullanıcı verilerini yenile
      await refreshUserData();
      
      return true;
    } catch (e) {
      _setError('Premium üyeliğe yükseltme hatası: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Apple ile giriş yapma
  Future<bool> signInWithApple() async {
    _setLoading(true);
    _clearError();
    try {
      final userCredential = await _authServiceImpl.signInWithApple();
      if (userCredential != null) {
        final userData = await _authServiceImpl.getUserData();
        _user = userData;
        notifyListeners();
        
        // FCM token'ı güncelle
        if (_user != null) {
          try {
            await _notificationService.updateFcmTokenOnLogin(_user!.id);
          } catch (fcmError) {
            // FCM token güncellemesi başarısız olsa bile giriş işlemine devam et
            _logger.e('FCM token güncellenirken hata oluştu: $fcmError');
            // Hatayı kullanıcıya gösterme, sessizce devam et
          }
        }
        
        // Kullanıcı ilk defa giriş yapıyorsa profil kurulum ekranına yönlendir
        final isFirstTime = await isFirstLogin();
        if (isFirstTime) {
          return false; // Profil tamamlama gerekiyor
        }
        
        return true;
      }
      _setError('Apple ile giriş yapılamadı');
      return false;
    } catch (e) {
      _logger.e('Apple ile giriş hatası: $e');
      // Hata mesajına göre daha kullanıcı dostu hata mesajı ayarla
      if (e.toString().contains('invalid-credential')) {
        _setError('Bu hesap daha önce silinmiş olabilir. Lütfen yeni bir hesap oluşturun.');
      } else {
        _setError('Apple ile giriş hatası: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Çıkış yapma
  Future<void> signOut() async {
    _setLoading(true);
    _clearError();
    try {
      // SharedPreferences'tan onboarding durumunu güncelle
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasCompletedOnboarding', true);
      await prefs.remove('user_token');
      
      // FCM token'ı kaldır
      if (_user != null) {
        try {
          await _notificationService.removeFcmTokenOnLogout(_user!.id);
        } catch (fcmError) {
          _logger.e('FCM token silinirken hata oluştu: $fcmError');
          // Hatayı kullanıcıya gösterme, sessizce devam et
        }
      }
      
      await _authServiceImpl.signOut();
      _user = null;
      _isPremium = false;
      notifyListeners();
    } catch (e) {
      _setError('Çıkış yapma hatası: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Kullanıcı bilgilerini yenileme
  Future<void> refreshUserData() async {
    if (_authService.currentUser == null) return;
    
    _setLoading(true);
    _clearError();
    
    try {
      // Önce Firebase Auth'taki kullanıcı bilgilerini yenileyelim
      await _authService.currentUser!.reload();
      
      // Ardından Firestore'daki kullanıcı bilgilerini alalım
      final userData = await _authServiceImpl.getUserData();
      _user = userData;
      
      debugPrint('Kullanıcı bilgileri yenilendi: ${_user?.displayName}, ${_user?.email}');
      
      notifyListeners();
    } catch (e) {
      _setError('Kullanıcı bilgileri yenileme hatası: $e');
      debugPrint('Kullanıcı bilgileri yenileme hatası: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Premium durum güncelleme
  Future<void> updatePremiumStatus({
    required bool isPremium,
    required DateTime? expiryDate,
  }) async {
    if (_authService.currentUser == null) return;
    
    _setLoading(true);
    try {
      await _authServiceImpl.updatePremiumStatus(
        isPremium: isPremium,
        expiryDate: expiryDate,
      );
      
      await refreshUserData();
    } catch (e) {
      _setError('Premium durumu güncelleme hatası: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Premium aboneliği iptal etme
  Future<bool> cancelPremium() async {
    _setLoading(true);
    _clearError();
    try {
      // Premium durumunu güncelle
      await updatePremiumStatus(
        isPremium: false,
        expiryDate: null,
      );
      return true;
    } catch (e) {
      _setError('Premium abonelik iptali hatası: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Yükleme durumunu güncelleme
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Hata mesajını temizleme
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Hata mesajını ayarlama
  void _setError(String error) {
    _errorMessage = error;
    debugPrint(error);
    notifyListeners();
  }
  
  // E-posta ve şifre ile kayıt olma
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    String? firstName,
    String? lastName,
    String? gender,
    DateTime? birthDate,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final userCredential = await _authServiceImpl.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
        firstName: firstName,
        lastName: lastName,
        gender: gender,
        birthDate: birthDate,
      );
      
      if (userCredential != null) {
        // Kayıt başarılı ancak kullanıcıyı giriş yapmış olarak işaretleme
        // Kullanıcı daha sonra e-posta ile giriş yapacak
        
        // Not: Otomatik giriş yapmıyoruz, bu nedenle kullanıcı bilgilerini almıyoruz
        // ve FCM token güncellemiyoruz.
        
        // Çıkış yap, böylece kullanıcı giriş ekranına yönlendirilecek
        await _authServiceImpl.signOut();
        _user = null;
        notifyListeners();
        
        return true;
      }
      
      _setError('E-posta ile kayıt başarısız oldu');
      return false;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'Bu e-posta adresi zaten kullanımda.';
          break;
        case 'invalid-email':
          errorMessage = 'Geçersiz e-posta adresi.';
          break;
        case 'weak-password':
          errorMessage = 'Şifre çok zayıf.';
          break;
        default:
          errorMessage = 'Kayıt sırasında bir hata oluştu: ${e.message}';
      }
      
      _setError(errorMessage);
      return false;
    } catch (e) {
      _setError('E-posta ile kayıt hatası: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // E-posta ve şifre ile giriş yapma
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final userCredential = await _authServiceImpl.signInWithEmail(
        email: email,
        password: password,
      );
      
      if (userCredential != null) {
        // Kullanıcı verilerini al
        final userData = await _authServiceImpl.getUserData();
        _user = userData;
        notifyListeners();
        
        // FCM token'ı güncelle
        if (_user != null) {
          try {
            await _notificationService.updateFcmTokenOnLogin(_user!.id);
          } catch (fcmError) {
            // FCM token güncellemesi başarısız olsa bile giriş işlemine devam et
            _logger.e('FCM token güncellenirken hata oluştu: $fcmError');
            // Hatayı kullanıcıya gösterme, sessizce devam et
          }
        }
        
        return true;
      }
      
      _setError('E-posta ile giriş başarısız oldu');
      return false;
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
        case 'invalid-credential':
          errorMessage = 'Bu hesap daha önce silinmiş olabilir. Lütfen yeni bir hesap oluşturun.';
          break;
        default:
          errorMessage = 'Giriş sırasında bir hata oluştu: ${e.message}';
      }
      
      _setError(errorMessage);
      return false;
    } catch (e) {
      _logger.e('E-posta ile giriş hatası: $e');
      // Hata mesajına göre daha kullanıcı dostu hata mesajı ayarla
      if (e.toString().contains('invalid-credential')) {
        _setError('Bu hesap daha önce silinmiş olabilir. Lütfen yeni bir hesap oluşturun.');
      } else {
        _setError('E-posta ile giriş hatası: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Kullanıcının ilk kez giriş yapıp yapmadığını kontrol et
  Future<bool> isFirstLogin() async {
    if (_user == null) return false;
    
    try {
      final doc = await _firestore.collection('users').doc(_user!.id).get();
      
      // Hesap var ama gerekli profil alanları eksikse ilk giriş kabul et
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        
        if (data == null) return true;
        
        final hasFirstName = data.containsKey('firstName') && data['firstName'] != null;
        final hasLastName = data.containsKey('lastName') && data['lastName'] != null;
        final hasGender = data.containsKey('gender') && data['gender'] != null;
        
        // Google/Apple giriş için doğum tarihi kontrolü
        final hasAppleOrGoogleLogin = _user!.authProvider == 'google.com' || _user!.authProvider == 'apple.com';
        final hasBirthDate = data.containsKey('birthDate') && data['birthDate'] != null;
        
        if (hasAppleOrGoogleLogin) {
          return !(hasFirstName && hasLastName && hasGender && hasBirthDate);
        } else {
          return !(hasFirstName && hasLastName && hasGender);
        }
      }
      
      return true;
    } catch (e) {
      _logger.e('İlk giriş kontrolü hatası: $e');
      return false;
    }
  }

  // Kullanıcı profil bilgilerini güncelle
  Future<bool> updateUserProfile({
    required String firstName, 
    required String lastName, 
    required String gender,
    DateTime? birthDate,
  }) async {
    if (_user == null) return false;
    
    _setLoading(true);
    _clearError();
    
    try {
      // Kullanıcı verilerini güncelle
      await _firestore.collection('users').doc(_user!.id).update({
        'firstName': firstName,
        'lastName': lastName,
        'gender': gender,
        'birthDate': birthDate,
        'displayName': '$firstName $lastName', // displayName'i güncelle
        'profileCompleted': true, // Profil tamamlandı olarak işaretle
      });
      
      // Kullanıcı bilgilerini yenile
      await refreshUserData();
      
      return true;
    } catch (e) {
      _setError('Profil güncelleme hatası: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Premium durumunu kontrol et
  void _checkPremiumStatus() {
    if (_user != null) {
      _isPremium = _user!.isPremium;
    } else {
      _isPremium = false;
    }
  }

  // Hesabı silme
  Future<bool> deleteUserAccount() async {
    _setLoading(true);
    _clearError();
    try {
      if (_authService.currentUser == null) {
        _setError('Oturum açmış kullanıcı bulunamadı');
        return false;
      }
      
      final String uid = _authService.currentUser!.uid;
      _logger.i('Kullanıcı hesabı siliniyor: $uid');
      
      // 1. Kullanıcıya ait tüm Firestore verilerini silme
      try {
        // Kullanıcıya ait ana dokümanı sil
        await _firestore.collection('users').doc(uid).delete();
        
        // Kullanıcıya ait diğer koleksiyonlardaki verileri de silebilirsiniz
        // Örnek: Kullanıcının mesajları, raporları vb.
        final analizlerSnapshot = await _firestore.collection('analizler')
            .where('kullaniciId', isEqualTo: uid).get();
        
        for (var doc in analizlerSnapshot.docs) {
          await _firestore.collection('analizler').doc(doc.id).delete();
        }
        
        // Diğer koleksiyonlar için benzer silme işlemleri yapılabilir
        
        _logger.i('Kullanıcı Firestore verileri başarıyla silindi');
      } catch (firestoreError) {
        _logger.e('Firestore verileri silinirken hata: $firestoreError');
        // Firestore hatası olsa bile Authentication hesabını silmeye devam edelim
      }
      
      // 2. Authentication hesabını silme
      try {
        await _authService.currentUser!.delete();
        _logger.i('Kullanıcı Authentication hesabı başarıyla silindi');
        
        // Kullanıcının cihaz belleğindeki bilgilerini temizle
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear(); // Tüm local verileri temizle
        
        // Kullanıcı modelini temizle
        _user = null;
        _isPremium = false;
        notifyListeners();
        
        return true;
      } catch (authError) {
        // Bu hata genellikle kullanıcının yakın zamanda giriş yapmamış olmasından kaynaklanır
        _logger.e('Authentication hesabı silinirken hata: $authError');
        
        if (authError is FirebaseAuthException) {
          if (authError.code == 'requires-recent-login') {
            _setError('Hesabı silmek için yeniden giriş yapmanız gerekiyor');
            // Burada kullanıcıyı yeniden giriş yapma sayfasına yönlendirebilirsiniz
            return false;
          }
        }
        
        _setError('Hesap silme işlemi başarısız: $authError');
        return false;
      }
    } catch (e) {
      _setError('Hesap silme hatası: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Test için Premium modunu değiştirme
  void togglePremiumMode(bool isPremiumActive) {
    _isPremium = isPremiumActive;
    notifyListeners();
    _logger.i('Premium modu manuel olarak değiştirildi: $_isPremium');
  }
} 