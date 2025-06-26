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

  // Abonelik planları - App Store/Play Store'dan dinamik olarak gelecek
  List<Map<String, dynamic>> _planlar = [];

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
            
            // Eğer satın alma başarılıysa sayfayı yenile
            if (purchase.status == PurchaseStatus.purchased && mounted) {
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

  // Dinamik planları yükle (App Store/Play Store'dan)
  void _loadDynamicPlans() {
    try {
      // Premium service'ten dinamik planları al
      final dynamicPlans = _premiumService.getDynamicPlanlar();
      
      debugPrint('🔄 ${dynamicPlans.length} dinamik plan yüklendi');
      
      if (mounted) {
        setState(() {
          _planlar = dynamicPlans;
        });
      }
      
      // Fiyat bilgilerini log'la
      for (final plan in dynamicPlans) {
        debugPrint('💰 Plan: ${plan['title']} - Fiyat: ${plan['price']}');
      }
      
    } catch (e) {
      debugPrint('❌ Dinamik plan yükleme hatası: $e');
      
      // Hata durumunda boş liste bırak (fiyatlar yüklenemedi mesajı gösterilecek)
      if (mounted) {
        setState(() {
          _planlar = [];
        });
      }
      
      debugPrint('⚠️ Fiyatlar yüklenemedi');
    }
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
    // Google Play Store'dan gelen ürünleri göster (fiyatlar Play Store'dan alınır)
    if (_premiumService.urunler.isEmpty) {
      // Eğer loading değilse ve ürünler hala boşsa, varsayılan planları göster
      if (!_isContentLoading) {
        return _buildFallbackPlans();
      }
      
      return Container(
        height: 200,
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
                'Google Play Store fiyatları yükleniyor...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _premiumService.urunler.length,
        itemBuilder: (context, index) {
          final product = _premiumService.urunler[index];
          final bool isSelected = index == _selectedPlanIndex;
          final bool isPopular = _premiumService.enPopulerPlanMi(product.id);
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPlanIndex = index;
              });
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF352269) : const Color(0xFF1A2436),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF9D3FFF) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _premiumService.planAdiCevir(product.id),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.price,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _premiumService.planAciklamasiAl(product.id),
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF9D3FFF) : Colors.white30,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                
                // "En Popüler" etiketi
                if (isPopular)
                  Positioned(
                    bottom: 5,
                    left: 0,
                    right: 16,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9D3FFF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'En Popüler',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
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
    // Play Store ürünleri yoksa fallback buton göster
    bool canPurchase = _premiumService.urunler.isNotEmpty || (!_isContentLoading && _premiumService.urunler.isEmpty);
    
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
          : _premiumService.urunler.isEmpty
              ? const Text(
                  'Planlar yükleniyor...',
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

  // Fallback planları göster (Play Store'dan yüklenemezse)
  Widget _buildFallbackPlans() {
    // Eğer planlar henüz yüklenmediyse veya yüklenemedi ise hata mesajı göster
    if (_planlar.isEmpty) {
      // Content loading durumunda loading göster, değilse hata mesajı göster
      if (_isContentLoading) {
        return SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D3FFF)),
                ),
                SizedBox(height: 12),
                Text(
                  Platform.isIOS ? 'App Store\'dan fiyatlar yükleniyor...' : 'Play Store\'dan fiyatlar yükleniyor...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Fiyatlar yüklenemedi mesajı göster
        return SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'Fiyatlar Yüklenemedi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  Platform.isIOS 
                    ? 'App Store bağlantısı kurulamadı.\nLütfen internet bağlantınızı kontrol edin.'
                    : 'Play Store bağlantısı kurulamadı.\nLütfen internet bağlantınızı kontrol edin.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Planları tekrar yüklemeyi dene
                    setState(() {
                      _isContentLoading = true;
                    });
                    _initializeInAppPurchase();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF9D3FFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
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
    
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _planlar.length,
        itemBuilder: (context, index) {
          final plan = _planlar[index];
          final bool isSelected = index == _selectedPlanIndex;
          final bool isPopular = plan['mostPopular'] as bool;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPlanIndex = index;
              });
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF352269) : const Color(0xFF1A2436),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF9D3FFF) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        plan['title'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        plan['price'] as String,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF9D3FFF) : Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'per ${plan["period"]}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      if (plan['discountInfo'] != null && (plan['discountInfo'] as String).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9D3FFF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            plan['discountInfo'] as String,
                            style: const TextStyle(
                              color: Color(0xFF9D3FFF),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isPopular)
                  Positioned(
                    top: -8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9D3FFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'En Popüler',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
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
    if (_planlar.isEmpty || _selectedPlanIndex >= _planlar.length) {
      final String storeName = Platform.isIOS ? 'App Store' : 'Google Play Store';
      _premiumService.toastMesajGoster(
        'Fiyatlar yüklenemedi. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.',
        false,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final selectedPlan = _planlar[_selectedPlanIndex];
      final ProductDetails? productDetails = selectedPlan['productDetails'] as ProductDetails?;
      
      if (productDetails != null) {
        // Dinamik plan - App Store/Play Store'dan alınan ürün
        debugPrint('💰 Dinamik plan satın alınıyor: ${productDetails.title} - ${productDetails.price}');
        await _premiumService.satinAlmaBaslat(productDetails);
      } else {
        // Statik plan - fallback durumu
        final String planTitle = selectedPlan['title'] as String;
        final ProductDetails? fallbackProduct = _premiumService.getProductDetails(planTitle);
        
        if (fallbackProduct != null) {
          debugPrint('⚠️ Statik plandan ProductDetails bulundu: ${fallbackProduct.title}');
          await _premiumService.satinAlmaBaslat(fallbackProduct);
        } else {
          throw Exception('Seçilen plan için ürün bilgisi bulunamadı: $planTitle');
        }
      }
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