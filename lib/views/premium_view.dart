import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:async';
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

  // Abonelik planları - Remote Config'ten gelecek
  List<Map<String, dynamic>> _planlar = [
    {
      'title': 'Haftalık',
      'price': '₺49,99',
      'discountInfo': '',
      'period': 'hafta',
      'mostPopular': false,
    },
    {
      'title': 'Aylık',
      'price': '₺149,99',
      'discountInfo': '25% indirim',
      'period': 'ay',
      'mostPopular': true,
    },
    {
      'title': 'Yıllık',
      'price': '₺999,99',
      'discountInfo': '50% indirim',
      'period': 'yıl',
      'mostPopular': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeInAppPurchase();
    _loadPremiumContent();
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

      // Premium planlarını çek
      try {
        final plansJson = await _remoteConfigService.parametreAl('premium_plans');
        if (plansJson.isNotEmpty) {
          final List<dynamic> plansData = jsonDecode(plansJson);
          _planlar = plansData.cast<Map<String, dynamic>>();
          
          // En popüler planı bulup selected index olarak ayarla
          for (int i = 0; i < _planlar.length; i++) {
            if (_planlar[i]['mostPopular'] == true) {
              _selectedPlanIndex = i;
              break;
            }
          }
        }
      } catch (e) {
        // Varsayılan planlar kullanılacak
        debugPrint('Premium plans yüklenemedi, varsayılan planlar kullanılıyor: $e');
      }

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
        _premiumService.toastMesajGoster('Google Play Store mevcut değil', false);
        return;
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
    // Google Play Store'dan gelen ürünleri göster
    if (_premiumService.urunler.isEmpty) {
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
                'Abonelik planları yükleniyor...',
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
    return ElevatedButton(
      onPressed: _isLoading || _premiumService.urunler.isEmpty
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
    if (_premiumService.urunler.isEmpty) {
      _premiumService.toastMesajGoster('Ürün bilgileri yüklenemedi', false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final product = _premiumService.urunler[_selectedPlanIndex];
      await _premiumService.satinAlmaBaslat(product);
    } catch (e) {
      debugPrint('Satın alma hatası: $e');
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
      // TODO: Restore purchases implementation
      _premiumService.toastMesajGoster('Geri yükleme özelliği yakında aktif olacak', false);
    } catch (e) {
      debugPrint('Satın alım geri yükleme hatası: $e');
      _premiumService.toastMesajGoster('Geri yükleme başarısız: $e', false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
} 