import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:in_app_purchase/in_app_purchase.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../services/premium_service.dart';
import '../services/remote_config_service.dart';
import '../utils/utils.dart';

/// Premium abonelik sayfası
class PremiumView extends StatefulWidget {
  const PremiumView({super.key});

  @override
  State<PremiumView> createState() => _PremiumViewState();
}

class _PremiumViewState extends State<PremiumView> {
  bool _isLoading = false;
  bool _isContentLoading = true;
  int _selectedPlanIndex = 1; // Varsayılan olarak aylık plan
  final PremiumService _premiumService = PremiumService();
  final RemoteConfigService _remoteConfigService = RemoteConfigService();
  late StreamSubscription<List<PurchaseDetails>> _satinAlmaSubscription;
  
  // Remote Config'ten gelecek dinamik içerik
  String _premiumTitle = 'Flörtya Premium';
  String _premiumDescription = 'İlişkilerinizi geliştirmek için tüm premium özelliklere erişin.';
  List<String> _premiumFeatures = [
    'Reklamsız kullanım',
    'Sınırsız analiz',
    'Wrapped özeti',
    'Görsel analiz',
    '.txt analizi',
    'İlişki danışmanlığı',
    'Alternatif öneriler',
    'Yanıt senaryoları',
  ];



  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  // Uygulama başlatma işlemlerini sıralı olarak yap
  Future<void> _initializeApp() async {
    try {
      // Önce premium içeriği yükle (Remote Config)
      await _loadPremiumContent();
      
      // Sonra In-App Purchase'ı başlat
      await _initializeInAppPurchase();
    } catch (e) {
      debugPrint('Uygulama başlatma hatası: $e');
      if (mounted) {
        setState(() {
          _isContentLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _satinAlmaSubscription.cancel();
    super.dispose();
  }

  /// Remote Config'ten premium içeriğini çeker
  Future<void> _loadPremiumContent() async {
    try {
      setState(() {
        _isContentLoading = true;
      });

      // Remote Config'ten verileri çek
      await _remoteConfigService.baslat();
      
      // Premium başlığını çek
      try {
        _premiumTitle = await _remoteConfigService.parametreAl('premium_title');
      } catch (e) {
        // Varsayılan değer kullanılacak
        debugPrint('Premium title yüklenemedi, varsayılan değer kullanılıyor: $e');
      }

      // Premium açıklamasını çek
      try {
        _premiumDescription = await _remoteConfigService.parametreAl('premium_description');
      } catch (e) {
        // Varsayılan değer kullanılacak
        debugPrint('Premium description yüklenemedi, varsayılan değer kullanılıyor: $e');
      }

      // Premium özelliklerini çek
      try {
        final featuresJson = await _remoteConfigService.parametreAl('premium_features');
        if (featuresJson.isNotEmpty) {
          final List<dynamic> featuresData = jsonDecode(featuresJson);
          _premiumFeatures = featuresData.cast<String>();
        }
      } catch (e) {
        // Varsayılan değerler kullanılacak
        debugPrint('Premium features yüklenemedi, varsayılan değerler kullanılıyor: $e');
      }

      // Premium planları artık Play Console'dan alınıyor, 
      // Remote Config'den çekmeye gerek yok

    } catch (e) {
      debugPrint('Premium içerik yükleme hatası: $e');
      // Varsayılan değerler kullanılacak
    } finally {
      if (mounted) {
        setState(() {
          _isContentLoading = false;
        });
      }
    }
  }

  // In-App Purchase sistemini başlat
  Future<void> _initializeInAppPurchase() async {
    try {
      final bool available = await _premiumService.inAppPurchaseBaslat();
      if (!available) {
        final String storeName = Platform.isIOS ? 'App Store' : 'Google Play Store';
        _premiumService.toastMesajGoster('$storeName mevcut değil', false);
        if (mounted) {
          setState(() {
            _isContentLoading = false;
          });
        }
        return;
      }

      // Ürünler yüklendikten sonra dinamik planları yükle ve UI'ı güncelle
      _loadDynamicPlans();
      
      if (mounted) {
        setState(() {
          _isContentLoading = false;
        });
      }

      // Satın alma durumlarını dinle
      _satinAlmaSubscription = _premiumService.satinAlinan.listen(
        (List<PurchaseDetails> purchaseDetailsList) async {
          for (final PurchaseDetails purchase in purchaseDetailsList) {
            await _premiumService.satinAlmaTamamla(purchase);
            
            if (mounted) {
              // Satın alma başarılı
              if (purchase.status == PurchaseStatus.purchased) {
                // AuthViewModel'i güncelle
                final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
                await authViewModel.refreshUserData();
                
                setState(() {
                  _isLoading = false;
                });
                
                // Premium aktif olduğunda başarı mesajı göster ve anasayfaya yönlendir
                await Future.delayed(const Duration(seconds: 1));
                if (mounted) {
                  _premiumService.toastMesajGoster('Premium başarıyla aktif edildi! Artık tüm özelliklere erişebilirsiniz.', true);
                  await Future.delayed(const Duration(seconds: 2));
                  if (mounted) {
                    context.go('/home');
                  }
                }
              }
              // Satın alma iptal edildi
              else if (purchase.status == PurchaseStatus.canceled) {
                debugPrint('🚫 Satın alma iptal edildi');
                setState(() {
                  _isLoading = false;
                });
                _premiumService.toastMesajGoster('Satın alma iptal edildi', false);
              }
              // Satın alma başarısız
              else if (purchase.status == PurchaseStatus.error) {
                debugPrint('❌ Satın alma başarısız: ${purchase.error}');
                setState(() {
                  _isLoading = false;
                });
                _premiumService.toastMesajGoster('Satın alma başarısız: ${purchase.error?.message ?? "Bilinmeyen hata"}', false);
              }
              // Satın alma pending durumunda (işlem devam ediyor)
              else if (purchase.status == PurchaseStatus.pending) {
                debugPrint('⏳ Satın alma işlemi devam ediyor...');
                // Pending durumunda loading'i açık bırak
              }
              // Diğer durumlar (restored vb.)
              else {
                debugPrint('ℹ️ Satın alma durumu: ${purchase.status}');
                setState(() {
                  _isLoading = false;
                });
              }
            }
          }
        },
        onError: (error) {
          debugPrint('Satın alma dinleme hatası: $error');
          _premiumService.toastMesajGoster('Satın alma hatası: $error', false);
          setState(() {
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      debugPrint('In-App Purchase başlatma hatası: $e');
      _premiumService.toastMesajGoster('Satın alma sistemi başlatılamadı', false);
      if (mounted) {
        setState(() {
          _isContentLoading = false;
        });
      }
    }
  }

  // Dinamik planları yükle (App Store/Play Store'dan) - Artık kullanılmıyor
  void _loadDynamicPlans() {
    // Bu fonksiyon artık gerekmiyor - sadece Play Store ürünlerini kullanıyoruz
    debugPrint('🔄 Dinamik planlar artık Play Store\'dan otomatik yükleniyor');
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = provider.Provider.of<AuthViewModel>(context);
    final isPremium = authViewModel.isPremium;

    return Scaffold(
      backgroundColor: const Color(0xFF121929),
      appBar: AppBar(
        title: const Text(
          'Premium Üyelik',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isPremium
          ? _buildPremiumActiveView()
          : _buildSubscriptionView(context),
    );
  }

  Widget _buildPremiumActiveView() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.verified,
            color: Color(0xFF9D3FFF),
            size: 80,
          ),
          const SizedBox(height: 24),
          const Text(
            'Premium Üyeliğiniz Aktif',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Tüm premium özelliklere sınırsız erişiminiz bulunmaktadır.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              context.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9D3FFF),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Anasayfaya Dön',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionView(BuildContext context) {
    return _isContentLoading
        ? _buildLoadingView()
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _premiumTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _premiumDescription,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Abonelik planları
                _buildSubscriptionPlans(),
                const SizedBox(height: 32),
                
                // Premium avantajları
                const Text(
                  'Premium Avantajları',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildPremiumAdvantages(),
                const SizedBox(height: 24),
                
                // Satın alma butonu
                _buildPurchaseButton(),
                const SizedBox(height: 16),
                
                // Geri yükleme butonu
                _buildRestoreButton(),
                const SizedBox(height: 32),
                
                // Gizlilik ve kullanım şartları
                _buildTermsAndPrivacyLinks(),
              ],
            ),
          );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF9D3FFF),
          ),
          SizedBox(height: 16),
          Text(
            'Premium özellikleri yükleniyor...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPlans() {
    // Sadece Google Play Store'dan dinamik veri kullan
    if (_premiumService.urunler.isEmpty) {
      if (_isContentLoading) {
        // Loading durumu
        return Container(
          height: 300,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2436),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF9D3FFF)),
                SizedBox(height: 16),
                Text(
                  'Google Play Store\'dan planlar yükleniyor...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        );
      } else {
        // Hata durumu - Play Store'dan veri gelmiyor
        return Container(
          height: 300,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2436),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Planlar Yüklenemedi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Google Play Store bağlantısı kurulamadı.\nLütfen internet bağlantınızı kontrol edin ve tekrar deneyin.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isContentLoading = true;
                    });
                    _initializeInAppPurchase();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9D3FFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Tekrar Dene',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Tek plan göster + kaydırma butonları
    return Column(
      children: [
        // Seçili planı göster
        GestureDetector(
          onPanEnd: (details) {
            // Sağa kaydırma (önceki plan) - minimum 50px hareket gerekli
            if (details.velocity.pixelsPerSecond.dx > 200 && _selectedPlanIndex > 0) {
              setState(() {
                _selectedPlanIndex--;
              });
            }
            // Sola kaydırma (sonraki plan) - minimum 50px hareket gerekli
            else if (details.velocity.pixelsPerSecond.dx < -200 && _selectedPlanIndex < _premiumService.urunler.length - 1) {
              setState(() {
                _selectedPlanIndex++;
              });
            }
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildSinglePlan(
              key: ValueKey(_selectedPlanIndex),
              product: _premiumService.urunler[_selectedPlanIndex],
              isPopular: _premiumService.enPopulerPlanMi(_premiumService.urunler[_selectedPlanIndex].id),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Plan navigasyon butonları
        _buildPlanNavigationButtons(_premiumService.urunler.length),
      ],
    );
  }

  Widget _buildSinglePlan({
    required Key key,
    required dynamic product,
    required bool isPopular,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF352269),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF9D3FFF),
          width: 2,
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: isPopular ? 36 : 20,
        bottom: 20,
      ),
      child: Stack(
        children: [
          // Ana içerik - tam ortalanmış
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _premiumService.planAdiCevir(product.id),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  product.price,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  _premiumService.planAciklamasiAl(product.id),
                  style: const TextStyle(
                    color: Color(0xFF9D3FFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // "En Popüler" etiketi - sol üst köşe
          if (isPopular)
            Positioned(
              top: 1,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9D3FFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'En Popüler',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanNavigationButtons(int totalPlans) {
    if (totalPlans <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Önceki plan butonu
        IconButton(
          onPressed: _selectedPlanIndex > 0
              ? () {
                  setState(() {
                    _selectedPlanIndex--;
                  });
                }
              : null,
          style: IconButton.styleFrom(
            backgroundColor: _selectedPlanIndex > 0 
                ? const Color(0xFF1A2436) 
                : Colors.grey.withOpacity(0.3),
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(
            Icons.chevron_left,
            color: _selectedPlanIndex > 0 ? Colors.white : Colors.grey,
            size: 24,
          ),
        ),

        // Plan göstergesi (dots)
        Row(
          children: List.generate(
            totalPlans,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: index == _selectedPlanIndex 
                    ? const Color(0xFF9D3FFF) 
                    : Colors.white30,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),

        // Sonraki plan butonu
        IconButton(
          onPressed: _selectedPlanIndex < totalPlans - 1
              ? () {
                  setState(() {
                    _selectedPlanIndex++;
                  });
                }
              : null,
          style: IconButton.styleFrom(
            backgroundColor: _selectedPlanIndex < totalPlans - 1 
                ? const Color(0xFF1A2436) 
                : Colors.grey.withOpacity(0.3),
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(
            Icons.chevron_right,
            color: _selectedPlanIndex < totalPlans - 1 ? Colors.white : Colors.grey,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumAdvantages() {
    return Column(
      children: _premiumFeatures.map((feature) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2436),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF9D3FFF),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '• $feature',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPurchaseButton() {
    // Sadece Play Store ürünleri kullan
    bool canPurchase = _premiumService.urunler.isNotEmpty;
    
    return ElevatedButton(
      onPressed: _isLoading || !canPurchase
          ? null
          : () => _satinAl(),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF9D3FFF),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        disabledBackgroundColor: Colors.grey,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
          : !canPurchase
              ? const Text(
                  'Google Play Store\'dan planlar yükleniyor...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Flexible(
                      child: Text(
                        'Şimdi Premium Ol',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _premiumService.urunler.isNotEmpty 
                            ? _premiumService.urunler[_selectedPlanIndex].price
                            : '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildRestoreButton() {
    return TextButton(
      onPressed: _isLoading ? null : () => _satinAlimGeriYukle(),
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(40),
      ),
      child: const Text(
        'Önceki Satın Alımımı Geri Yükle',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTermsAndPrivacyLinks() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          TextButton(
            onPressed: () {
              // Gizlilik politikası sayfasına yönlendir
            },
            child: const Text(
              'Gizlilik Politikası',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ),
          const Text(
            '•',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          TextButton(
            onPressed: () {
              // Kullanım şartları sayfasına yönlendir
            },
            child: const Text(
              'Kullanım Şartları',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _satinAl() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Sadece Google Play Store ürünlerini kullan
      if (_premiumService.urunler.isEmpty) {
        throw Exception('Google Play Store ürünleri yüklenmedi. Lütfen sayfayı yenileyin.');
      }
      
      if (_selectedPlanIndex >= _premiumService.urunler.length) {
        throw Exception('Geçersiz plan seçimi');
      }
      
      final selectedProduct = _premiumService.urunler[_selectedPlanIndex];
      debugPrint('💰 Google Play Store planı satın alınıyor: ${selectedProduct.title} - ${selectedProduct.price}');
      await _premiumService.satinAlmaBaslat(selectedProduct);
      
    } catch (e) {
      debugPrint('❌ Satın alma hatası: $e');
      _premiumService.toastMesajGoster('Satın alma başlatılamadı: $e', false);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _satinAlimGeriYukle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (Platform.isIOS) {
        // iOS için restore purchases
        debugPrint('🍎 iOS App Store satın alımları geri yükleniyor...');
        await InAppPurchase.instance.restorePurchases();
        _premiumService.toastMesajGoster('iOS satın alımları geri yüklendi', true);
      } else {
        // Android için restore purchases - yakında implement edilecek
        _premiumService.toastMesajGoster('Android geri yükleme özelliği yakında aktif olacak', false);
      }
    } catch (e) {
      debugPrint('Satın alım geri yükleme hatası: $e');
      final String platform = Platform.isIOS ? 'iOS' : 'Android';
      _premiumService.toastMesajGoster('$platform geri yükleme başarısız: $e', false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
} 