import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService;
  
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;
  bool get isPremium => _user?.isPremium ?? false;
  bool get isInitialized => _isInitialized;
  User? get currentUser => _authService.currentUser;

  // Constructor
  AuthViewModel({required FirebaseAuth authService, required FirebaseFirestore firestore}) 
      : _authService = AuthService() {
    _initializeUser();
  }

  // İlk kullanıcı durumunu yükleme
  Future<void> _initializeUser() async {
    _setLoading(true);
    try {
      // Firebase Auth durumu değişikliklerini dinleme
      _authService.authStateChanges.listen((User? firebaseUser) async {
        if (firebaseUser != null) {
          // Kullanıcı oturum açtıysa
          final userData = await _authService.getUserData();
          _user = userData;
          debugPrint('Kullanıcı oturum açtı: ${_user?.displayName}');
        } else {
          // Kullanıcı oturum açmadıysa
          _user = null;
          debugPrint('Kullanıcı oturum açmadı');
        }
        _isInitialized = true;
        notifyListeners();
      });
    } catch (e) {
      _setError('Kullanıcı durumu başlatılamadı: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Google ile giriş yapma
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();
    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential != null) {
        final userData = await _authService.getUserData();
        _user = userData;
        notifyListeners();
        return true;
      }
      _setError('Google ile giriş yapılamadı');
      return false;
    } catch (e) {
      _setError('Google ile giriş hatası: $e');
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
      
      await _authService.updatePremiumStatus(
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
      final userCredential = await _authService.signInWithApple();
      if (userCredential != null) {
        final userData = await _authService.getUserData();
        _user = userData;
        notifyListeners();
        return true;
      }
      _setError('Apple ile giriş yapılamadı');
      return false;
    } catch (e) {
      _setError('Apple ile giriş hatası: $e');
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
      // SharedPreferences'tan onboarding durumunu sıfırla
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasCompletedOnboarding', false);
      await prefs.remove('user_token');
      
      // Firebase Auth ile çıkış yap
      await _authService.signOut();
      _user = null;
      notifyListeners();
      
      // Debug için kullanıcı durumunu kontrol et
      debugPrint('Çıkış yapıldı, kullanıcı durumu: ${_authService.currentUser}');
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
      final userData = await _authService.getUserData();
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
      await _authService.updatePremiumStatus(
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
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final userCredential = await _authService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      
      if (userCredential != null) {
        // Kullanıcı verilerini al
        final userData = await _authService.getUserData();
        _user = userData;
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
      final userCredential = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      
      if (userCredential != null) {
        // Kullanıcı verilerini al
        final userData = await _authService.getUserData();
        _user = userData;
        notifyListeners();
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
        default:
          errorMessage = 'Giriş sırasında bir hata oluştu: ${e.message}';
      }
      
      _setError(errorMessage);
      return false;
    } catch (e) {
      _setError('E-posta ile giriş hatası: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
} 