import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart' as provider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/home_controller.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/report_viewmodel.dart';
import '../controllers/message_coach_controller.dart';
import '../services/data_reset_service.dart';
import '../services/event_bus_service.dart';
import '../services/remote_config_service.dart';
import '../utils/utils.dart';
import '../utils/loading_indicator.dart';
import 'dart:convert';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final RemoteConfigService _remoteConfigService = RemoteConfigService();
  
  // FAQ için state değişkenleri
  List<Map<String, String>> _faqList = [];
  bool _isFaqLoading = false;
  String _faqTitle = 'Sık Sorulan Sorular';
  
  @override
  void initState() {
    super.initState();
    _loadFaqContent();
  }
  
  // FAQ içeriğini Remote Config'den yükle
  Future<void> _loadFaqContent() async {
    setState(() {
      _isFaqLoading = true;
    });
    
    try {
      await _remoteConfigService.baslat();
      
      // FAQ başlığını al
      _faqTitle = await _remoteConfigService.parametreAl('faq_title');
      
      // FAQ listesini al
      final faqJsonString = await _remoteConfigService.parametreAl('faq_list');
      final List<dynamic> faqData = jsonDecode(faqJsonString);
      
      _faqList = faqData.map<Map<String, String>>((item) {
        return {
          'question': item['question']?.toString() ?? '',
          'answer': item['answer']?.toString() ?? '',
        };
      }).toList();
      
      // Eğer Remote Config'den veri gelmezse varsayılan değerleri kullan
      if (_faqList.isEmpty) {
        _setDefaultFaqContent();
      }
      
    } catch (e) {
      debugPrint('FAQ içeriği yüklenirken hata: $e');
      _setDefaultFaqContent();
    } finally {
      if (mounted) {
        setState(() {
          _isFaqLoading = false;
        });
      }
    }
  }
  
  // Varsayılan FAQ içeriğini ayarla
  void _setDefaultFaqContent() {
    _faqList = [
      {
        'question': 'Uygulama nasıl kullanılır?',
        'answer': 'Ana ekrandan mesajlarınızı analiz etmeye başlayabilirsiniz. Mesajlarınızı girin ve AI sistemimiz size kişiselleştirilmiş bir analiz sunacaktır.',
      },
      {
        'question': 'Verilerim güvende mi?',
        'answer': 'Evet, tüm verileriniz şifrelenerek saklanır ve hiçbir üçüncü parti ile paylaşılmaz. Gizliliğiniz bizim önceliğimizdir.',
      },
      {
        'question': 'Premium özellikler nelerdir?',
        'answer': 'Premium üyelik ile sınırsız analiz, ilişki raporları ve mesaj koçu hizmetlerine erişebilirsiniz. Ayrıca premium kullanıcılara özel tavsiyeler ve içgörüler sağlanır.',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF352269),
      appBar: AppBar(
        title: const Text(
          'Ayarlar',
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: Colors.white
          ),
        ),
        backgroundColor: const Color(0xFF352269),
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF352269),
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tercihlerinizi Özelleştirin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.Provider.of<AuthViewModel>(context, listen: false).currentUser?.displayName ?? "Kullanıcı",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _buildSectionHeader('Hesap Ayarları'),
            
            _buildMenuButton(
              title: 'Profil Bilgilerini Düzenle',
              icon: Icons.person_outline,
              onTap: () {
                _showEditProfileDialog(context);
              },
            ),
            
            _buildMenuButton(
              title: 'Şifre Değiştir',
              icon: Icons.lock_outline,
              onTap: () {
                // Şifre değiştirme sayfasına gitme işlemi
              },
            ),
            
            _buildSectionHeader('Veri Yönetimi'),
            
            _buildMenuButton(
              title: 'Tüm Verileri Sıfırla',
              icon: Icons.delete_forever,
              onTap: () {
                _showCompleteDataResetDialog();
              },
              isDestructive: true,
            ),
            
            _buildMenuButton(
              title: 'Hesabımı Sil',
              icon: Icons.no_accounts,
              onTap: () {
                _showDeleteAccountDialog();
              },
              isDestructive: true,
            ),
            
            _buildSectionHeader('Uygulama Hakkında'),
            
            _buildMenuButton(
              title: 'Yardım ve Destek',
              icon: Icons.help_outline,
              onTap: () {
                _showHelpSupportDialog(context);
              },
            ),
            
            _buildMenuButton(
              title: 'Gizlilik Politikası',
              icon: Icons.privacy_tip_outlined,
              onTap: () async {
                final uri = Uri.parse('https://www.rivorya.com/gizlilik-politikasi');
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) {
                      Utils.showToast(context, 'Gizlilik politikası sayfası açılamadı');
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    Utils.showToast(context, 'Gizlilik politikası sayfası açılırken hata oluştu');
                  }
                }
              },
            ),
            
            _buildMenuButton(
              title: 'Sürüm Bilgisi',
              icon: Icons.info_outline,
              onTap: () {
                Utils.showToast(context, 'Sürüm 1.0.0');
              },
            ),
            
            const SizedBox(height: 32.0),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
  
  Widget _buildSwitchItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2A70),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null 
          ? Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ) 
          : null,
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: const Color(0xFF9D3FFF),
          inactiveThumbColor: Colors.grey,
          inactiveTrackColor: Colors.grey.withOpacity(0.3),
        ),
      ),
    );
  }
  
  Widget _buildMenuButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2A70),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive 
              ? Colors.redAccent 
              : Colors.white,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? Colors.redAccent : Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.white70,
        ),
        onTap: onTap,
      ),
    );
  }
  
  // Tüm verileri sıfırlama onay dialog'u
  void _showCompleteDataResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3A2A70),
        title: const Text(
          'Tüm Veriler Silinsin Mi?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu işlem geri alınamaz ve aşağıdaki veriler kalıcı olarak silinecektir:',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              '• Tüm mesaj analizleri',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            Text(
              '• İlişki raporları',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            Text(
              '• Mesaj koçu geçmişi',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            Text(
              '• Danışma geçmişi',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            Text(
              '• Konuşma özetleri (Wrapped)',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Hesap bilgileriniz korunacaktır.',
              style: TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetAllData();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Evet, Tüm Verileri Sil'),
          ),
        ],
      ),
    );
  }
  

  

  
  void _resetAllData() async {
    // Kullanıcı ID'sini al
    final userId = provider.Provider.of<AuthViewModel>(context, listen: false).currentUser?.uid;
    if (userId == null) {
      if (!mounted) return;
      Utils.showErrorFeedback(context, 'Kullanıcı bilgisi bulunamadı');
      return;
    }
    
    Utils.showLoadingDialog(context, 'Tüm veriler siliniyor...', analizTipi: AnalizTipi.GENEL);
    
    try {
      // Data reset servisini oluştur
      final DataResetService resetService = DataResetService();
      
      // Tüm verileri sil
      final bool success = await resetService.resetAllData(userId);
      
      // UI verilerini güncelle
      final homeController = provider.Provider.of<HomeController>(context, listen: false);
      await homeController.resetAnalizVerileri();
      await homeController.resetRelationshipData();
      
      // Mesaj koçu verilerini sıfırla
      try {
        final messageCoachController = provider.Provider.of<MessageCoachController>(context, listen: false);
        messageCoachController.analizSonuclariniSifirla();
        messageCoachController.analizGecmisiniSifirla();
      } catch (e) {
        debugPrint('Mesaj koçu verileri sıfırlanırken hata: $e');
      }
      
      // Mesaj koçu görsel kontrolcüsünü sıfırla (Riverpod)
      try {
        // BuildContext'i bir ProviderScope içinde kullanmamız gerekiyor
        // Doğrudan provider notifier'a erişerek sıfırlama yapma:
        debugPrint('Mesaj koçu görsel kontrolcüsü sıfırlanıyor...');
        
        // Eğer bu context ProviderScope içinde değilse, bu işlemi atlayalım
        // Bu sadece uygulama çapında bir sıfırlama olduğu için, mesaj koçu sayfasına
        // tekrar gidildiğinde zaten kontrolcü sıfırlanacaktır
        debugPrint('Not: Mesaj koçu görsel kontrolcüsünün tam sıfırlanması, mesaj koçu sayfası tekrar açıldığında gerçekleşecek');
      } catch (e) {
        debugPrint('Mesaj koçu görsel kontrolcüsü sıfırlanırken hata: $e');
      }
      
      // ÖNEMLİ: ReportViewModel'daki rapor verilerini de tamamen temizle
      try {
        final reportViewModel = provider.Provider.of<ReportViewModel>(context, listen: false);
        await reportViewModel.clearAllReports(userId);
      } catch (e) {
        debugPrint('ReportViewModel temizleme hatası: $e');
      }
      
      // Ana sayfadaki wrapped hikayeleri temizle (UI güncellemesi için)
      try {
        // Event bus servisi ile wrapped hikayeleri sıfırlama olayını yayınla
        debugPrint('Ana sayfadaki wrapped hikayeleri UI üzerinde güncelleniyor...');
        
        // EventBusService aracılığıyla resetWrappedStories olayını yayınla
        // Bu olay HomeView'deki dinleyici tarafından yakalanacak ve UI güncellenecek
        final EventBusService eventBus = EventBusService();
        eventBus.emit(AppEvents.resetWrappedStories);
        
        if (mounted) {
          // Bilgilendirme mesajı göster
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tüm veriler silindi ve wrapped hikayeleri temizlendi.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        debugPrint('Wrapped hikayeleri sıfırlanırken hata: $e');
      }
      
      // Dialog'u kapat
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      
      // Başarı durumunu bildir
      if (success) {
        // Kullanıcıya verileri sıfırlama mesajı ve yönlendirme göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tüm veriler başarıyla silindi.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: Duration(seconds: 6),
            backgroundColor: Color(0xFF3A2A70),
          ),
        );
      } else {
        Utils.showErrorFeedback(context, 'Veri silme işleminde beklenmeyen bir hata oluştu');
      }
    } catch (e) {
      // Dialog'u kapat
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      
      Utils.showErrorFeedback(context, 'Veri silme işleminde hata: $e');
    }
  }
  
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3A2A70),
        title: const Text(
          'Hesabınız silinsin mi?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bu işlem geri alınamaz. Tüm kişisel bilgileriniz ve uygulamadaki verileriniz kalıcı olarak silinecektir.',
          style: TextStyle(color: Colors.white),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () async {
              // Dialog'u kapat
              Navigator.of(context).pop(); 
              
              // BuildContext'i değişkende tutarak capture edilmesi
              final BuildContext currentContext = context;
              
              // Yükleme diyaloğunu göster
              Utils.showLoadingDialog(currentContext, 'Hesabınız siliniyor...', analizTipi: AnalizTipi.GENEL);
              
              try {
                final authViewModel = provider.Provider.of<AuthViewModel>(currentContext, listen: false);
                final bool success = await authViewModel.deleteUserAccount();
                
                // Yükleme diyaloğunu kapat - güvenli şekilde
                if (!mounted) return;
                if (Navigator.canPop(currentContext)) {
                  Navigator.of(currentContext, rootNavigator: true).pop();
                }
                
                if (success) {
                  // Hesap başarıyla silindi, kullanıcıyı giriş ekranına yönlendir
                  if (!mounted) return;
                  Navigator.of(currentContext).pushNamedAndRemoveUntil('/login', (route) => false);
                } else {
                  // Hata mesajını kontrol et - requires-recent-login hatası mı?
                  if (authViewModel.errorMessage?.contains('yeniden giriş yapmanız gerekiyor') ?? false) {
                    // Yeniden kimlik doğrulama diyaloğunu göster
                    _showReauthenticationDialog(currentContext, authViewModel);
                  } else {
                    // Diğer hata mesajlarını göster
                  if (mounted) {
                    Utils.showErrorFeedback(
                      currentContext, 
                      authViewModel.errorMessage ?? 'Hesap silme işlemi başarısız oldu.'
                    );
                    }
                  }
                }
              } catch (e) {
                // Hata oluştu
                if (!mounted) return;
                
                // Yükleme diyaloğunu kapat - güvenli şekilde
                if (Navigator.canPop(currentContext)) {
                  Navigator.of(currentContext, rootNavigator: true).pop();
                }
                
                if (mounted) {
                  Utils.showErrorFeedback(currentContext, 'Hesap silme işleminde hata: $e');
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              backgroundColor: Colors.white10,
            ),
            child: const Text('Evet, hesabımı sil'),
          ),
        ],
      ),
    );
  }

  // Yeniden kimlik doğrulama diyaloğu
  void _showReauthenticationDialog(BuildContext context, AuthViewModel authViewModel) {
    // Kullanıcının giriş yöntemini belirle
    final currentUser = authViewModel.currentUser;
    if (currentUser == null || currentUser.providerData.isEmpty) {
      Utils.showErrorFeedback(context, 'Kullanıcı bilgileri alınamadı');
      return;
    }
    
    final providerId = currentUser.providerData[0].providerId;
    
    if (providerId == 'password') {
      // E-posta/şifre ile giriş yapmış kullanıcı için şifre doğrulama diyaloğu
      _showEmailPasswordReauthDialog(context, authViewModel, currentUser.email ?? '');
    } else if (providerId == 'google.com') {
      // Google ile giriş yapmış kullanıcı için bilgi diyaloğu
      _showProviderReauthDialog(context, authViewModel, 'Google');
    } else if (providerId == 'apple.com') {
      // Apple ile giriş yapmış kullanıcı için bilgi diyaloğu
      _showProviderReauthDialog(context, authViewModel, 'Apple');
    } else {
      Utils.showErrorFeedback(context, 'Desteklenmeyen giriş yöntemi: $providerId');
    }
  }
  
  // E-posta/şifre için yeniden kimlik doğrulama diyaloğu
  void _showEmailPasswordReauthDialog(BuildContext context, AuthViewModel authViewModel, String email) {
    final TextEditingController passwordController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3A2A70),
        title: const Text(
          'Güvenlik Doğrulaması',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hesabınızı silmek için lütfen şifrenizi girin.',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'E-posta: $email',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lütfen şifrenizi girin')),
                );
                return;
              }
              
              Navigator.of(context).pop();
              
              // Yükleme diyaloğunu göster
              Utils.showLoadingDialog(context, 'Kimlik doğrulanıyor...', analizTipi: AnalizTipi.GENEL);
              
              try {
                // Kimlik doğrulama işlemi
                final success = await authViewModel.reauthenticateUser(
                  email: email,
                  password: password,
                );
                
                // Yükleme diyaloğunu kapat
                if (!mounted) return;
                if (Navigator.canPop(context)) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
                
                if (success) {
                  // Doğrulama başarılı, hesap silme işlemini tekrar dene
                  _retryAccountDeletion(context, authViewModel);
                } else {
                  // Doğrulama başarısız
                  if (mounted) {
                    Utils.showErrorFeedback(
                      context, 
                      authViewModel.errorMessage ?? 'Kimlik doğrulama başarısız.'
                    );
                  }
                }
              } catch (e) {
                // Hata oluştu
                if (!mounted) return;
                if (Navigator.canPop(context)) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
                Utils.showErrorFeedback(context, 'Kimlik doğrulama hatası: $e');
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF9D3FFF),
            ),
            child: const Text('Doğrula'),
          ),
        ],
      ),
    );
  }
  
  // Google/Apple gibi sağlayıcılar için yeniden kimlik doğrulama diyaloğu
  void _showProviderReauthDialog(BuildContext context, AuthViewModel authViewModel, String provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3A2A70),
        title: const Text(
          'Güvenlik Doğrulaması',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hesabınızı silmek için $provider ile tekrar giriş yapmanız gerekiyor.',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              // Yükleme diyaloğunu göster
              Utils.showLoadingDialog(context, 'Kimlik doğrulanıyor...', analizTipi: AnalizTipi.GENEL);
              
              try {
                // Google/Apple ile otomatik kimlik doğrulama
                final success = await authViewModel.reauthenticateUser();
                
                // Yükleme diyaloğunu kapat
                if (!mounted) return;
                if (Navigator.canPop(context)) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
                
                if (success) {
                  // Doğrulama başarılı, hesap silme işlemini tekrar dene
                  _retryAccountDeletion(context, authViewModel);
                } else {
                  // Doğrulama başarısız
                  if (mounted) {
                    Utils.showErrorFeedback(
                      context, 
                      authViewModel.errorMessage ?? 'Kimlik doğrulama başarısız.'
                    );
                  }
                }
              } catch (e) {
                // Hata oluştu
                if (!mounted) return;
                if (Navigator.canPop(context)) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
                Utils.showErrorFeedback(context, 'Kimlik doğrulama hatası: $e');
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF9D3FFF),
            ),
            child: Text('$provider ile Giriş Yap'),
          ),
        ],
      ),
    );
  }
  
  // Hesap silme işlemini tekrar dene
  void _retryAccountDeletion(BuildContext context, AuthViewModel authViewModel) async {
    // Yükleme diyaloğunu göster
    Utils.showLoadingDialog(context, 'Hesabınız siliniyor...', analizTipi: AnalizTipi.GENEL);
    
    try {
      final bool success = await authViewModel.deleteUserAccount();
      
      // Yükleme diyaloğunu kapat
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (success) {
        // Hesap başarıyla silindi, kullanıcıyı giriş ekranına yönlendir
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      } else {
        // Hala başarısız
        if (mounted) {
          Utils.showErrorFeedback(
            context, 
            authViewModel.errorMessage ?? 'Hesap silme işlemi başarısız oldu.'
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      Utils.showErrorFeedback(context, 'Hesap silme işleminde hata: $e');
    }
  }

  // Yardım ve Destek Dialog
  void _showHelpSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF352269),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık ve Kapat Butonu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Yardım ve Destek',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Yardım Seçenekleri
                _buildHelpOption(
                  icon: Icons.help_outline,
                  title: 'Sık Sorulan Sorular',
                  onTap: () {
                    Navigator.of(context).pop();
                    _showFAQDialog(context);
                  },
                ),
                
                const SizedBox(height: 12),
                
                _buildHelpOption(
                  icon: Icons.email_outlined,
                  title: 'E-posta ile İletişim',
                  onTap: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('E-posta desteği: destek@flortya.com')),
                    );
                  },
                ),
                
                const SizedBox(height: 12),
                
                _buildHelpOption(
                  icon: Icons.feedback_outlined,
                  title: 'Geribildirim Gönder',
                  onTap: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Geribildirim özelliği yakında eklenecek')),
                    );
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Kapat Butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D3FFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Kapat'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Yardım Seçeneği Widget
  Widget _buildHelpOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
  
  // FAQ Dialog
  void _showFAQDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF352269),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık ve Kapat Butonu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _faqTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // FAQ İçeriği
                Expanded(
                  child: _isFaqLoading
                      ? const Center(
                          child: YuklemeAnimasyonu(
                            boyut: 40.0,
                            renk: Colors.white,
                          ),
                        )
                      : _faqList.isEmpty
                          ? const Center(
                              child: Text(
                                'Henüz soru bulunmuyor',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _faqList.length,
                              itemBuilder: (context, index) {
                                final faq = _faqList[index];
                                return _buildFaqItem(
                                  question: faq['question'] ?? '',
                                  answer: faq['answer'] ?? '',
                                  isLast: index == _faqList.length - 1,
                                );
                              },
                            ),
                ),
                
                const SizedBox(height: 20),
                
                // Kapat Butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D3FFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Kapat'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // FAQ öğesi widget'ı
  Widget _buildFaqItem({
    required String question,
    required String answer,
    bool isLast = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          answer,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        if (!isLast) ...[
          const SizedBox(height: 16),
          Divider(
            color: Colors.white.withOpacity(0.2),
            height: 1,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  // Profil düzenleme diyaloğu
  void _showEditProfileDialog(BuildContext context) {
    // Kontrolcüleri oluştur
    TextEditingController adSoyadController = TextEditingController();
    

    
    // Dialog kapandığında kontrolcüleri temizle
    void dispose() {
      adSoyadController.dispose();
    }
    
    // Mevcut kullanıcı bilgilerini al
    final user = FirebaseAuth.instance.currentUser;
    
    // Firestore'dan kullanıcı bilgilerini al
    Future<void> getUserData() async {
      if (user != null) {
        adSoyadController.text = user.displayName ?? '';
        
        try {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          
          if (userDoc.exists) {
            // Kullanıcı verileri alındı
          }
        } catch (e) {
          print('Kullanıcı verileri alınırken hata: $e');
        }
      }
    }
    
    // Kullanıcı verilerini yükle
    getUserData().then((_) {
      if (context.mounted) {
        setState(() {}); // Dialog içeriğini güncelle
      }
    });
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF3A2A70),
            title: const Text(
              'Profil Bilgilerini Düzenle',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: adSoyadController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Ad Soyad',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  ),

                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  dispose(); // Dialog kapanırken kontrolcüleri temizle
                },
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9D3FFF),
                ),
                onPressed: () async {
                  // Yükleniyor göstergesi
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bilgiler güncelleniyor...')),
                  );
                  
                  try {
                    // Kullanıcı adını güncelle
                    if (user != null && adSoyadController.text.isNotEmpty) {
                      await user.updateDisplayName(adSoyadController.text);
                      
                      // Firestore'da da güncelleme yapılabilir
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({
                        'displayName': adSoyadController.text,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    }
                    
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      dispose(); // Dialog kapanırken kontrolcüleri temizle
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profil bilgileri güncellendi')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      dispose(); // Dialog kapanırken kontrolcüleri temizle
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hata: $e')),
                      );
                    }
                  }
                },
                child: const Text(
                  'Kaydet',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        }
      ),
    );
  }
} 