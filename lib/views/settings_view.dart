import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/report_viewmodel.dart';
import '../viewmodels/past_analyses_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../utils/utils.dart';
import '../controllers/home_controller.dart';
import '../services/data_reset_service.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _bildirimlerAcik = true;
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
              title: 'Bildirimleri Aç',
              value: _bildirimlerAcik,
              onChanged: (value) {
                setState(() {
                  _bildirimlerAcik = value;
                });
              },
            ),
            
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
                // Profil düzenleme sayfasına gitme işlemi
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
                // Hesap silme işlemi için doğrulama
              },
              isDestructive: true,
            ),
            
            _buildSectionHeader('Uygulama Hakkında'),
            
            _buildMenuButton(
              title: 'Yardım ve Destek',
              icon: Icons.help_outline,
              onTap: () {
                // Yardım sayfasına gitme işlemi
              },
            ),
            
            _buildMenuButton(
              title: 'Gizlilik Politikası',
              icon: Icons.privacy_tip_outlined,
              onTap: () {
                // Gizlilik politikası sayfasına gitme işlemi
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
                title: 'İlişki Değerlendirme Verilerini Sıfırla',
                onTap: () {
                  _resetReportData();
                  Navigator.pop(context);
                },
              ),
              _buildResetOption(
                title: 'Tüm Analiz Verilerini Sıfırla (Mesaj, Metin, Görsel)',
                onTap: () {
                  _resetAnalysisData();
                  Navigator.pop(context);
                },
              ),
              _buildResetOption(
                title: 'Tüm Verileri Sıfırla',
                onTap: () {
                  _resetAllData();
                  Navigator.pop(context);
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
            child: const Text('İptal'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResetOption({
    required String title,
    required VoidCallback onTap,
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
        child: Text(
          title,
          style: TextStyle(
            color: isDestructive ? Colors.redAccent : Colors.white,
            fontWeight: isDestructive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  void _resetReportData() async {
    // Kullanıcı ID'sini al
    final userId = Provider.of<AuthViewModel>(context, listen: false).currentUser?.uid;
    if (userId == null) {
      if (!mounted) return;
      Utils.showErrorFeedback(context, 'Kullanıcı bilgisi bulunamadı');
      return;
    }
    
    Utils.showLoadingDialog(context, 'İlişki değerlendirme verileri siliniyor...');
    
    try {
      // Data reset servisini oluştur
      final DataResetService resetService = DataResetService();
      
      // İlişki değerlendirme verilerini sil
      final bool success = await resetService.resetRelationshipData(userId);
      
      // UI verilerini güncelle
      final homeController = Provider.of<HomeController>(context, listen: false);
      await homeController.resetRelationshipData();
      
      // Dialog'u kapat
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      
      // Başarı durumunu bildir
      if (success) {
        Utils.showToast(context, 'İlişki değerlendirme verileri başarıyla silindi');
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
    
    Utils.showLoadingDialog(context, 'Mesaj analiz verileri siliniyor...');
    
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
        Utils.showToast(context, 'Mesaj analiz verileri başarıyla silindi');
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
    
    Utils.showLoadingDialog(context, 'Tüm veriler siliniyor...');
    
    try {
      // Data reset servisini oluştur
      final DataResetService resetService = DataResetService();
      
      // Tüm verileri sil
      final bool success = await resetService.resetAllData(userId);
      
      // UI verilerini güncelle
      final homeController = Provider.of<HomeController>(context, listen: false);
      await homeController.resetAnalizVerileri();
      await homeController.resetRelationshipData();
      
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
} 