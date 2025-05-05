import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/report_viewmodel.dart';
import '../viewmodels/past_analyses_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../utils/utils.dart';
import '../controllers/home_controller.dart';
import '../controllers/message_coach_controller.dart';
import '../services/data_reset_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/loading_indicator.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _otomatikGuncellemelerAcik = true;
  
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
                    Provider.of<AuthViewModel>(context, listen: false).currentUser?.displayName ?? "Kullanıcı",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _buildSectionHeader('Genel Ayarlar'),
            
            _buildSwitchItem(
              title: 'Otomatik Güncellemeler',
              value: _otomatikGuncellemelerAcik,
              onChanged: (value) {
                setState(() {
                  _otomatikGuncellemelerAcik = value;
                });
              },
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
              title: 'Verileri Sıfırla',
              icon: Icons.delete_outline,
              onTap: () {
                _showDataResetDialog();
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
              onTap: () {
                // Gizlilik politikası için yeni işlev eklenecek
                Utils.showToast(context, 'Gizlilik politikası yakında eklenecek');
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
  
  void _showDataResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3A2A70),
        title: const Text(
          'Verileri Sıfırla',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Hangi verileri sıfırlamak istiyorsunuz? Bu işlem geri alınamaz.',
          style: TextStyle(color: Colors.white),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          Column(
            children: [
              _buildResetOption(
                title: 'Analiz Verilerini Sıfırla',
                description: 'Görsel analiz, .txt analizleri ve danışma geçmişini siler',
                onTap: () {
                  Navigator.pop(context);
                  _resetAnalysisData();
                },
              ),
              _buildResetOption(
                title: 'Mesaj Koçu Verilerini Sıfırla',
                description: 'Koç geçmişini cihazdan ve Firestore\'dan siler',
                onTap: () {
                  Navigator.pop(context);
                  _resetMessageCoachData();
                },
              ),
              _buildResetOption(
                title: 'İlişki Raporlarını Sıfırla',
                description: 'İlişki raporu içeriklerini cihazdan ve veritabanından siler',
                onTap: () {
                  Navigator.pop(context);
                  _resetReportData();
                },
              ),
              _buildResetOption(
                title: 'Tüm Verileri Tamamen Sıfırla',
                description: 'Yukarıdaki 3 başlıktaki tüm verileri siler',
                onTap: () {
                  Navigator.pop(context);
                  _showResetAllConfirmDialog();
                },
                isDestructive: true,
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            child: const Text('Vazgeç'),
          ),
        ],
      ),
    );
  }
  
  void _showResetAllConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3A2A70),
        title: const Text(
          'Tüm veriler silinsin mi?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bu işlem geri alınamaz. Sadece analiz, mesaj koçu ve ilişki rapor verileri silinir. Hesap bilgileriniz korunur.',
          style: TextStyle(color: Colors.white),
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
              foregroundColor: Colors.white,
            ),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetAllData();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              backgroundColor: Colors.white10,
            ),
            child: const Text('Evet, sil'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResetOption({
    required String title,
    required VoidCallback onTap,
    String? description,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isDestructive ? Colors.redAccent : Colors.white,
                fontWeight: isDestructive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (description != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  void _resetMessageCoachData() async {
    // Kullanıcı ID'sini al
    final userId = Provider.of<AuthViewModel>(context, listen: false).currentUser?.uid;
    if (userId == null) {
      if (!mounted) return;
      Utils.showErrorFeedback(context, 'Kullanıcı bilgisi bulunamadı');
      return;
    }
    
    Utils.showLoadingDialog(context, 'Mesaj koçu verileri siliniyor...', analizTipi: AnalizTipi.MESAJ_KOCU);
    
    try {
      // Data reset servisini oluştur
      final DataResetService resetService = DataResetService();
      
      // Mesaj koçu verilerini sil
      final bool success = await resetService.resetMessageCoachData(userId);
      
      // UI verilerini güncelle
      try {
        final messageCoachController = Provider.of<MessageCoachController>(context, listen: false);
        messageCoachController.analizSonuclariniSifirla();
        messageCoachController.analizGecmisiniSifirla();
      } catch (e) {
        debugPrint('Mesaj koçu controller verilerini sıfırlarken hata: $e');
      }
      
      // Dialog'u kapat
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      
      // Başarı durumunu bildir
      if (success) {
        Utils.showToast(context, 'Mesaj koçu verileri başarıyla silindi');
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
  
  void _resetReportData() async {
    // Kullanıcı ID'sini al
    final userId = Provider.of<AuthViewModel>(context, listen: false).currentUser?.uid;
    if (userId == null) {
      if (!mounted) return;
      Utils.showErrorFeedback(context, 'Kullanıcı bilgisi bulunamadı');
      return;
    }
    
    Utils.showLoadingDialog(context, 'İlişki raporları siliniyor...', analizTipi: AnalizTipi.ILISKI_ANKETI);
    
    try {
      // Data reset servisini oluştur
      final DataResetService resetService = DataResetService();
      
      // İlişki değerlendirme verilerini sil
      final bool success = await resetService.resetRelationshipData(userId);
      
      // UI verilerini güncelle - HomeController
      final homeController = Provider.of<HomeController>(context, listen: false);
      await homeController.resetRelationshipData();
      
      // ÖNEMLİ: ReportViewModel'daki rapor verilerini de temizle
      try {
        final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
        await reportViewModel.clearAllReports(userId);
      } catch (e) {
        debugPrint('ReportViewModel temizleme hatası: $e');
      }
      
      // Dialog'u kapat
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      
      // Başarı durumunu bildir
      if (success) {
        Utils.showToast(context, 'İlişki raporları başarıyla silindi');
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
  
  void _resetAnalysisData() async {
    // Kullanıcı ID'sini al
    final userId = Provider.of<AuthViewModel>(context, listen: false).currentUser?.uid;
    if (userId == null) {
      if (!mounted) return;
      Utils.showErrorFeedback(context, 'Kullanıcı bilgisi bulunamadı');
      return;
    }
    
    Utils.showLoadingDialog(context, 'Analiz verileri siliniyor...', analizTipi: AnalizTipi.TXT_DOSYASI);
    
    try {
      // Data reset servisini oluştur
      final DataResetService resetService = DataResetService();
      
      // Mesaj analiz verilerini sil
      final bool success = await resetService.resetMessageAnalysisData(userId);
      
      // UI verilerini güncelle
      final homeController = Provider.of<HomeController>(context, listen: false);
      await homeController.resetAnalizVerileri();
      
      // Dialog'u kapat
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      
      // Başarı durumunu bildir
      if (success) {
        Utils.showToast(context, 'Analiz verileri başarıyla silindi');
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
  
  void _resetAllData() async {
    // Kullanıcı ID'sini al
    final userId = Provider.of<AuthViewModel>(context, listen: false).currentUser?.uid;
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
      final homeController = Provider.of<HomeController>(context, listen: false);
      await homeController.resetAnalizVerileri();
      await homeController.resetRelationshipData();
      
      // Mesaj koçu verilerini sıfırla
      try {
        final messageCoachController = Provider.of<MessageCoachController>(context, listen: false);
        messageCoachController.analizSonuclariniSifirla();
        messageCoachController.analizGecmisiniSifirla();
      } catch (e) {
        debugPrint('Mesaj koçu verileri sıfırlanırken hata: $e');
      }
      
      // ÖNEMLİ: ReportViewModel'daki rapor verilerini de tamamen temizle
      try {
        final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
        await reportViewModel.clearAllReports(userId);
      } catch (e) {
        debugPrint('ReportViewModel temizleme hatası: $e');
      }
      
      // Dialog'u kapat
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      
      // Başarı durumunu bildir
      if (success) {
        Utils.showToast(context, 'Tüm veriler başarıyla silindi');
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
                final authViewModel = Provider.of<AuthViewModel>(currentContext, listen: false);
                final bool success = await authViewModel.deleteUserAccount();
                
                // Hesap silme işlemi tamamlandı
                // mounted kontrolü - widget hala ağaçta mı?
                if (!mounted) return;
                
                // Yükleme diyaloğunu kapat - güvenli şekilde
                if (Navigator.canPop(currentContext)) {
                  Navigator.of(currentContext, rootNavigator: true).pop();
                }
                
                if (success) {
                  // Hesap başarıyla silindi, kullanıcıyı giriş ekranına yönlendir
                  if (!mounted) return;
                  
                  // Giriş sayfasına yönlendir
                  Navigator.of(currentContext).pushNamedAndRemoveUntil('/login', (route) => false);
                } else {
                  // Hata mesajını göster
                  if (mounted) {
                    Utils.showErrorFeedback(
                      currentContext, 
                      authViewModel.errorMessage ?? 'Hesap silme işlemi başarısız oldu.'
                    );
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
                      const SnackBar(content: Text('E-posta desteği: destek@flortai.com')),
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
                      'Sık Sorulan Sorular',
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
                
                // SSS İçeriği
                const Text(
                  'Uygulama nasıl kullanılır?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ana ekrandan mesajlarınızı analiz etmeye başlayabilirsiniz. Mesajlarınızı girin ve AI sistemimiz size kişiselleştirilmiş bir analiz sunacaktır.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                const Text(
                  'Verilerim güvende mi?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Evet, tüm verileriniz şifrelenerek saklanır ve hiçbir üçüncü parti ile paylaşılmaz. Gizliliğiniz bizim önceliğimizdir.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                const Text(
                  'Premium özellikler nelerdir?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Premium üyelik ile sınırsız analiz, ilişki raporları ve mesaj koçu hizmetlerine erişebilirsiniz. Ayrıca premium kullanıcılara özel tavsiyeler ve içgörüler sağlanır.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
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
                    child: const Text('Anladım'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Profil düzenleme diyaloğu
  void _showEditProfileDialog(BuildContext context) {
    // Kontrolcüleri oluştur
    TextEditingController adSoyadController = TextEditingController();
    TextEditingController telefonController = TextEditingController();
    
    // Doğum tarihi için değişken
    DateTime? selectedBirthDate;
    // Cinsiyet için değişken
    String selectedGender = 'Belirtilmemiş';
    
    // Dialog kapandığında kontrolcüleri temizle
    void dispose() {
      adSoyadController.dispose();
      telefonController.dispose();
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
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
            
            telefonController.text = userData['phoneNumber'] ?? '';
            
            // Cinsiyet bilgisini al
            if (userData['gender'] != null) {
              selectedGender = userData['gender'];
            }
            
            // Doğum tarihi bilgisini al
            if (userData['birthDate'] != null) {
              if (userData['birthDate'] is Timestamp) {
                selectedBirthDate = (userData['birthDate'] as Timestamp).toDate();
              }
            }
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: telefonController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Telefon Numarası (İsteğe Bağlı)',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  
                  // Cinsiyet seçimi
                  const Text(
                    'Cinsiyet',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedGender,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF3A2A70),
                      style: const TextStyle(color: Colors.white),
                      underline: Container(),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                      items: <String>['Belirtilmemiş', 'Kadın', 'Erkek', 'Diğer']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedGender = newValue;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Doğum tarihi seçimi
                  const Text(
                    'Doğum Tarihi',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedBirthDate ?? DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Color(0xFF9D3FFF),
                                onPrimary: Colors.white,
                                surface: Color(0xFF3A2A70),
                                onSurface: Colors.white,
                              ),
                              dialogBackgroundColor: const Color(0xFF352269),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null && picked != selectedBirthDate) {
                        setState(() {
                          selectedBirthDate = picked;
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedBirthDate != null
                                ? '${selectedBirthDate!.day.toString().padLeft(2, '0')}.${selectedBirthDate!.month.toString().padLeft(2, '0')}.${selectedBirthDate!.year}'
                                : 'Seçilmedi',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
                        ],
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
                        'phoneNumber': telefonController.text,
                        'gender': selectedGender,
                        'birthDate': selectedBirthDate != null ? Timestamp.fromDate(selectedBirthDate!) : null,
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