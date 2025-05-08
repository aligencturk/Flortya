import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../app_router.dart';
import '../utils/loading_indicator.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final List<Map<String, dynamic>> _onboardingItems = [
    {
      'title': 'Gelişimi Takip Edin',
      'description': 'Detaylı raporlar ve grafiklerle ilişkinizin gelişimini izleyin',
      'image': 'assets/images/GELİŞİMİ TAKİP EDİN.png',
    },
    {
      'title': 'Kişisel Tavsiyeler Alın',
      'description': 'Size özel tavsiyelerle ilişkinizi güçlendirin',
      'image': 'assets/images/KİŞİSEL TAVSİYELER ALIN.png',
    },
    {
      'title': 'İlişkinizi Analiz Edin',
      'description': 'Mesajlarınızı analiz ederek ilişkinizin durumunu öğrenin',
      'image': 'assets/images/İLİŞKİNİZİ ANALİZ EDİN.png',
    },
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _hasCompletedOnboarding = false;
  bool _isInitialized = false;
  bool _isRedirecting = false; // Yeniden yönlendirme durumunu takip et
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;
      final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      
      // Kullanıcı zaten giriş yapmışsa veya onboarding'i tamamlamışsa ana sayfaya yönlendir
      if (isLoggedIn && hasCompletedOnboarding) {
        setState(() {
          _isRedirecting = true;
        });
        _navigateToHome();
        return;
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      // Hata durumunda onboarding'i göster
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _navigateToHome() {
    if (mounted) {
      // Geçiş yaparken BuildContext'in hazır olduğundan emin olalım
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            context.go(AppRouter.home);
          } catch (e) {
            debugPrint('Ana sayfaya yönlendirme hatası: $e');
            // Alternatif yönlendirme yöntemleri
            try {
              context.pushReplacement(AppRouter.home);
            } catch (e2) {
              debugPrint('İkinci yönlendirme hatası: $e2');
              
              // Son çare olarak Navigator kullan
              try {
                Navigator.of(context).pushReplacementNamed(AppRouter.home);
              } catch (e3) {
                debugPrint('Üçüncü yönlendirme hatası: $e3');
              }
            }
          }
        }
      });
    }
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;
    setState(() {
      _hasCompletedOnboarding = hasCompletedOnboarding;
    });
  }

  Future<void> _completeOnboarding() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasCompletedOnboarding', true);
      await prefs.setBool('isLoggedIn', true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ayarlar kaydedilirken bir hata oluştu: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Google ile giriş
  Future<void> _handleSignInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authViewModel = AuthViewModel(
        authService: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
      );
      final user = await authViewModel.signInWithGoogle();
      
      if (user) {
        await _completeOnboarding();
        _navigateToHome();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google ile giriş başarısız oldu.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google ile giriş yaparken hata: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Apple ile giriş
  Future<void> _handleSignInWithApple() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authViewModel = AuthViewModel(
        authService: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
      );
      final user = await authViewModel.signInWithApple();
      
      if (user) {
        await _completeOnboarding();
        _navigateToHome();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apple ile giriş başarısız oldu.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apple ile giriş yaparken hata: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Geçiş Yapmakta Sorun mu Yaşıyorsunuz?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Uygulamaya devam etmek için:'),
            SizedBox(height: 8),
            Text('1. Sağ alttaki "Başla" butonuna basın.'),
            Text('2. Ekranın altından yukarı kaydırın.'),
            Text('3. Uygulamayı kapatıp tekrar açmayı deneyin.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
          ElevatedButton(
            onPressed: () async {
              debugPrint('Devam Et butonuna tıklandı');
              try {
                // Önce dialogu kapat
                Navigator.of(context).pop();
                
                // Onboarding'i tamamla
                await _completeOnboarding();
                
                if (mounted) {
                  // SharedPreferences'ı tekrar kontrol et
                  final prefs = await SharedPreferences.getInstance();
                  final hasCompleted = prefs.getBool('hasCompletedOnboarding') ?? false;
                  debugPrint('Dialog: hasCompletedOnboarding değeri: $hasCompleted');
                  
                  // GoRouter ile yönlendir
                  debugPrint('Dialog: Login sayfasına yönlendiriliyor...');
                  context.go(AppRouter.login);
                }
              } catch (e) {
                debugPrint('Dialog yönlendirme hatası: $e');
                // Gecikmeli olarak tekrar dene
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    try {
                      context.go(AppRouter.login);
                    } catch (e2) {
                      debugPrint('Dialog ikinci yönlendirme hatası: $e2');
                    }
                  }
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9D3FFF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Yönlendirme işlemi sırasında beyaz yukleniyor göster
    if (_isRedirecting) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: YuklemeAnimasyonu(
            renk: Color(0xFF9D3FFF),
          ),
        ),
      );
    }
    
    // Sayfa hazır değilse koyu yukleniyor göster
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF121929),
        body: const Center(
          child: YuklemeAnimasyonu(
            renk: Color(0xFF9D3FFF),
          ),
        ),
      );
    }
    
    final screenHeight = MediaQuery.of(context).size.height;
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF121929), // Koyu lacivert arka plan
      body: SafeArea(
        child: Column(
          children: [
            // Slaytlar
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _onboardingItems.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final item = _onboardingItems[index];
                  return _buildOnboardingItem(context, item);
                },
              ),
            ),
            
            // Sayfa İndikatörü
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _onboardingItems.length,
                  (index) => _buildPageIndicator(index == _currentPage, index),
                ),
              ),
            ),
            
            // Giriş Butonları (Son sayfada görünecek)
            if (_currentPage == _onboardingItems.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hadi Başlayalım butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Text(
                          '❤️',
                          style: TextStyle(fontSize: 20),
                        ),
                        label: _isLoading 
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: YuklemeAnimasyonu(
                                boyut: 20.0,
                                renk: Colors.white,
                              ),
                            )
                          : const Text('Hadi Başlayalım'),
                        onPressed: _isLoading ? null : () async {
                          debugPrint('Hadi Başlayalım butonuna tıklandı');
                          try {
                            await _completeOnboarding();
                            if (mounted) {
                              debugPrint('Login sayfasına yönlendirme başlıyor...');
                              
                              // 1. Yöntem: GoRouter.go ile yönlendirme
                              try {
                                debugPrint('1. Yöntem deneniyor: context.go(AppRouter.login)');
                                context.go(AppRouter.login);
                                debugPrint('1. Yöntem başarılı olabilir');
                                return; // Başarılı olduysa diğer yöntemleri deneme
                              } catch (navigasyon1Hatasi) {
                                debugPrint('1. Yöntem hatası: $navigasyon1Hatasi');
                              }
                              
                              // 500ms bekle ve 2. yöntemi dene
                              await Future.delayed(const Duration(milliseconds: 500));
                              if (!mounted) return;
                              
                              // 2. Yöntem: context.pushReplacement ile yönlendirme
                              try {
                                debugPrint('2. Yöntem deneniyor: context.pushReplacement(AppRouter.login)');
                                context.pushReplacement(AppRouter.login);
                                debugPrint('2. Yöntem başarılı olabilir');
                                return; // Başarılı olduysa diğer yöntemleri deneme
                              } catch (navigasyon2Hatasi) {
                                debugPrint('2. Yöntem hatası: $navigasyon2Hatasi');
                              }
                              
                              // 500ms bekle ve 3. yöntemi dene
                              await Future.delayed(const Duration(milliseconds: 500));
                              if (!mounted) return;
                              
                              // 3. Yöntem: Navigator.pushNamedAndRemoveUntil ile yönlendirme
                              try {
                                debugPrint('3. Yöntem deneniyor: Navigator.pushNamedAndRemoveUntil');
                                // Navigator yöntemini devre dışı bırakıyoruz, çünkü GoRouter ile çakışabilir
                                // Navigator.of(context).pushNamedAndRemoveUntil(
                                //   AppRouter.login, 
                                //   (route) => false
                                // );
                                // GoRouter'a geri dönün
                                context.go(AppRouter.login);
                                debugPrint('3. Yöntem başarılı olabilir');
                                return; // Başarılı olduysa diğer yöntemleri deneme
                              } catch (navigasyon3Hatasi) {
                                debugPrint('3. Yöntem hatası: $navigasyon3Hatasi');
                              }
                            }
                          } catch (e) {
                            debugPrint('Onboarding tamamlama hatası: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Hata: ${e.toString()}')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9D3FFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Alt Butonlar (Atla, İleri) - Son sayfada Başla butonu gizlenecek
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: _currentPage == _onboardingItems.length - 1 
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.spaceBetween,
                children: [
                  // Atla butonu
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      splashColor: Colors.white.withOpacity(0.1),
                      onTap: () {
                        debugPrint('Atla butonuna tıklandı');
                        try {
                          _pageController.animateToPage(
                            _onboardingItems.length - 1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } catch (e) {
                          debugPrint('Atla butonunda hata: $e');
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: const Text(
                          'Atla',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // İleri butonu - Sadece son sayfada değilse göster
                  if (_currentPage != _onboardingItems.length - 1)
                    ElevatedButton(
                      onPressed: () {
                        // Sonraki sayfaya git
                        debugPrint('İleri butonuna tıklandı');
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9D3FFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'İleri',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Onboarding öğesi widget'ı
  Widget _buildOnboardingItem(BuildContext context, Map<String, dynamic> item) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Görsel
          SizedBox(
            height: screenHeight * 0.35,
            width: screenHeight * 0.35,
            child: Image.asset(
              item['image'],
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Görsel yüklenemezse
                return Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 64,
                    color: Colors.grey.shade600,
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Başlık
          Text(
            item['title'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Açıklama
          Text(
            item['description'],
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Sayfa indikatörü widget'ı
  Widget _buildPageIndicator(bool isActive, int index) {
    // Aktif sayfanın mor, diğerlerinin soluk mor olması
    final color = isActive 
        ? const Color(0xFF9D3FFF) 
        : Colors.grey.withOpacity(0.5);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
} 