import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:go_router/go_router.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../services/premium_service.dart';
import '../utils/utils.dart';

/// Premium abonelik sayfası
class PremiumView extends StatefulWidget {
  const PremiumView({super.key});

  @override
  State<PremiumView> createState() => _PremiumViewState();
}

class _PremiumViewState extends State<PremiumView> {
  bool _isLoading = false;
  int _selectedPlanIndex = 1; // Varsayılan olarak aylık plan
  final PremiumService _premiumService = PremiumService();

  // Abonelik planları
  final List<Map<String, dynamic>> _planlar = [
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

  // Premium avantajları
  final List<Map<String, dynamic>> _avantajlar = [
    {
      'icon': Icons.remove_circle,
      'title': 'Reklamları Kaldır',
      'description': 'Reklamsız, kesintisiz kullanım deneyimi',
    },
    {
      'icon': Icons.analytics,
      'title': 'Sınırsız Analiz',
      'description': 'Sınırsız mesaj ve ilişki analizi',
    },
    {
      'icon': Icons.history,
      'title': 'Geçmiş Raporlar',
      'description': 'Tüm geçmiş raporlara erişim',
    },
    {
      'icon': Icons.image,
      'title': 'Görsel Analiz',
      'description': 'Sınırsız sohbet görüntüsü analizi',
    },
    {
      'icon': Icons.text_snippet,
      'title': '.txt Analizi',
      'description': 'Metin dosyası analizi özelliği',
    },
    {
      'icon': Icons.support_agent,
      'title': 'İlişki Danışmanlığı',
      'description': 'Premium ilişki danışmanlığı desteği',
    },
    {
      'icon': Icons.lightbulb,
      'title': 'Alternatif Öneriler',
      'description': 'Sınırsız alternatif mesaj önerileri',
    },
    {
      'icon': Icons.psychology,
      'title': 'Yanıt Senaryoları',
      'description': 'Olumlu ve olumsuz yanıt tahminleri',
    },
  ];

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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lovizia Premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'İlişkilerinizi geliştirmek için tüm premium özelliklere erişin.',
            style: TextStyle(
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

  Widget _buildSubscriptionPlans() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _planlar.length,
        itemBuilder: (context, index) {
          final plan = _planlar[index];
          final bool isSelected = index == _selectedPlanIndex;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPlanIndex = index;
              });
            },
            child: Container(
              width: 150,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF352269) : const Color(0xFF1A2436),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFF9D3FFF) : Colors.transparent,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    plan['title'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan['price'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan['discountInfo'],
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF9D3FFF) : Colors.white30,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (plan['mostPopular'])
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumAdvantages() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _avantajlar.length,
      itemBuilder: (context, index) {
        final avantaj = _avantajlar[index];
        
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A2436),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    avantaj['icon'],
                    color: const Color(0xFF9D3FFF),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      avantaj['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  avantaj['description'],
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPurchaseButton() {
    return ElevatedButton(
      onPressed: _isLoading
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
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Şimdi Premium Ol',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _planlar[_selectedPlanIndex]['price'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
      // Bu kısımda gerçek satın alma işlemi yapılacak
      // Şimdilik sadece mock bir işlem
      await Future.delayed(const Duration(seconds: 2));
      
      // AuthViewModel'de premium durumunu güncelle
      final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
      final success = await authViewModel.upgradeToPremium();
      
      if (success) {
        if (mounted) {
          Utils.showSuccessDialog(
            context,
            'Premium Üyelik Aktifleştirildi',
            'Tüm premium özelliklere erişiminiz açıldı. Teşekkür ederiz!',
            onOkPressed: () {
              context.pop(); // Premium sayfasını kapat
            }
          );
        }
      } else {
        if (mounted) {
          Utils.showErrorDialog(
            context,
            'Hata',
            'Premium üyelik aktifleştirilemedi. Lütfen daha sonra tekrar deneyin.'
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Utils.showErrorDialog(
          context,
          'Hata',
          'Satın alma işlemi sırasında bir hata oluştu: $e'
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _satinAlimGeriYukle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Bu kısımda gerçek satın alım geri yükleme işlemi yapılacak
      // Şimdilik sadece mock bir işlem
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        Utils.showInfoDialog(
          context, 
          title: 'Bilgi',
          message: 'Önceki satın alım bulunamadı. Daha önce premium üyelik satın aldıysanız lütfen doğru hesap ile giriş yaptığınızdan emin olun.'
        );
      }
    } catch (e) {
      if (mounted) {
        Utils.showErrorDialog(
          context,
          'Hata',
          'Satın alım geri yükleme işlemi sırasında bir hata oluştu: $e'
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 