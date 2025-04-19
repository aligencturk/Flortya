import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../app_router.dart';

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

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
    
    // 5 saniye sonra hala onboarding ekranındaysa yardım kılavuzu göster
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _currentPage == _onboardingItems.length - 1) {
        _showHelpDialog();
      }
    });
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
      
      // Mevcut durumu kontrol et
      final bool mevcutDurum = prefs.getBool('hasCompletedOnboarding') ?? false;
      debugPrint('Mevcut onboarding durumu: $mevcutDurum');
      
      // Maksimum deneme sayısı
      const int maksimumDenemeSayisi = 5;
      bool basarili = false;
      
      for (int deneme = 1; deneme <= maksimumDenemeSayisi; deneme++) {
        debugPrint('Onboarding tamamlama deneme $deneme/$maksimumDenemeSayisi');
        
        try {
          final bool sonuc = await prefs.setBool('hasCompletedOnboarding', true);
          debugPrint('Deneme $deneme sonucu: $sonuc');
          
          // Başarılı kaydedildiyse döngüden çık
          if (sonuc) {
            basarili = true;
            debugPrint('Onboarding başarıyla tamamlandı (deneme $deneme)');
            break;
          }
          
          // Başarısız olduysa kısa bir süre bekle ve tekrar dene
          if (deneme < maksimumDenemeSayisi) {
            await Future.delayed(Duration(milliseconds: 300 * deneme)); // Her denemede bekleme süresini artır
          }
        } catch (denemehata) {
          debugPrint('Deneme $deneme hatası: $denemehata');
          if (deneme < maksimumDenemeSayisi) {
            await Future.delayed(Duration(milliseconds: 300 * deneme));
          }
        }
      }
      
      // Son durumu kontrol et
      final bool sonDurum = prefs.getBool('hasCompletedOnboarding') ?? false;
      debugPrint('Kayıt sonrası onboarding durumu: $sonDurum');
      
      if (!basarili) {
        debugPrint('UYARI: $maksimumDenemeSayisi deneme sonunda onboarding kaydedilemedi!');
      }
    } catch (e) {
      debugPrint('Onboarding tamamlama hatası: ${e.runtimeType} - $e');
      rethrow; // Hatayı yukarıya ilet
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Google ile giriş
  Future<void> _signInWithGoogle(BuildContext context) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    await _completeOnboarding();
    await authViewModel.signInWithGoogle();
  }

  // Apple ile giriş
  Future<void> _signInWithApple(BuildContext context) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    await _completeOnboarding();
    await authViewModel.signInWithApple();
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
            
            // Alt Butonlar (Atla, İleri, Başla)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  
                  // İleri veya Başla butonu
                  ElevatedButton(
                    onPressed: () async {
                      if (_currentPage == _onboardingItems.length - 1) {
                        // Son sayfadaysa ana sayfaya git
                        debugPrint('Başla butonuna tıklandı');
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
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                AppRouter.login, 
                                (route) => false
                              );
                              debugPrint('3. Yöntem başarılı olabilir');
                              return; // Başarılı olduysa diğer yöntemleri deneme
                            } catch (navigasyon3Hatasi) {
                              debugPrint('3. Yöntem hatası: $navigasyon3Hatasi');
                            }
                            
                            // 500ms bekle ve 4. yöntemi dene
                            await Future.delayed(const Duration(milliseconds: 1000));
                            if (!mounted) return;
                            
                            // 4. Yöntem: Gecikmeli Navigator.pushReplacementNamed ile yönlendirme
                            debugPrint('4. Yöntem deneniyor: Gecikmeli Navigator.pushReplacementNamed');
                            Future.delayed(const Duration(seconds: 1), () {
                              if (mounted) {
                                try {
                                  Navigator.of(context).pushReplacementNamed(AppRouter.login);
                                  debugPrint('4. Yöntem başarılı olabilir');
                                } catch (navigasyon4Hatasi) {
                                  debugPrint('4. Yöntem hatası: $navigasyon4Hatasi');
                                  
                                  // Tüm yöntemler başarısız olduysa kullanıcıya bilgi ver
                                  showDialog(
                                    context: context, 
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Yönlendirme Hatası'),
                                      content: const Text('Ana sayfaya yönlendirme yapılamadı. Lütfen uygulamayı yeniden başlatın.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(),
                                          child: const Text('Tamam'),
                                        )
                                      ],
                                    )
                                  );
                                }
                              }
                            });
                          }
                        } catch (e) {
                          debugPrint('Onboarding tamamlama hatası: $e');
                          // Hata durumunu kullanıcıya bildir
                          if (mounted) {
                            showDialog(
                              context: context, 
                              builder: (ctx) => AlertDialog(
                                title: const Text('Onboarding Hatası'),
                                content: const Text('Onboarding işlemi tamamlanamadı. Lütfen tekrar deneyin.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('Tamam'),
                                  )
                                ],
                              )
                            );
                          }
                        }
                      } else {
                        // Sonraki sayfaya git
                        debugPrint('İleri butonuna tıklandı');
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D3FFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _onboardingItems.length - 1 ? 'Başla' : 'İleri',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_currentPage != _onboardingItems.length - 1) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 16),
                        ],
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