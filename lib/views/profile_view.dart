import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../widgets/custom_button.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isEditingProfile = false;

  @override
  void initState() {
    super.initState();
    
    // Sayfa yüklendiğinde kullanıcı bilgilerini yeniden yükle
    _forceRefreshUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Tarih formatı
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  // Kullanıcı adını doğrudan değiştirme dialog'u (ViewModel kullanmadan)
  Future<void> _showDirectNameChangeDialog(BuildContext context) async {
    try {
      debugPrint('İsim değiştirme dialog\'u açılıyor...');
      final nameController = TextEditingController();
      final formKey = GlobalKey<FormState>();
      
      // Mevcut ismi al
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.displayName != null) {
        nameController.text = currentUser!.displayName!;
      }
      
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('İsim Değiştir'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Yeni İsim',
                hintText: 'Yeni isminizi girin',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'İsim boş olamaz';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      );
      
      if (result == true && nameController.text.isNotEmpty) {
        bool success = false;
        try {
          // Yükleniyor gösterelim
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İsminiz güncelleniyor...')),
          );
          
          final authUser = FirebaseAuth.instance.currentUser;
          if (authUser != null) {
            // Firebase Auth'da ismi güncelle
            await authUser.updateDisplayName(nameController.text);
            
            // Kullanıcıyı yenile
            await authUser.reload();
            
            // Firestore'da da güncelle
            await FirebaseFirestore.instance.collection('users').doc(authUser.uid).update({
              'displayName': nameController.text,
              'name': nameController.text,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            
            success = true;
            
            // UI'ı yenile
            setState(() {});
          }
        } catch (e) {
          debugPrint('İsim güncelleme hatası: $e');
          success = false;
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success 
                ? 'İsminiz başarıyla güncellendi' 
                : 'İsim güncellenirken hata oluştu, lütfen tekrar deneyin'
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('İsim değiştirme dialog hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bir hata oluştu: $e')),
      );
    }
  }

  // Kullanıcı verilerini zorla yenileme
  Future<void> _forceRefreshUserData() async {
    try {
      // Firebase Auth kullanıcısını yenile
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.currentUser!.reload();
        
        // Debug için kullanıcı bilgilerini yazdır
        final currentUser = FirebaseAuth.instance.currentUser;
        debugPrint('FORCE REFRESH - Kullanıcı bilgileri: ${currentUser?.displayName}, ${currentUser?.email}');
      }
      
      // UI'ı yenile
      setState(() {});
    } catch (e) {
      debugPrint('Firebase Auth yenileme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
      // Hata olsa bile UI yenilensin
      setState(() {});
    }
  }

  // Profil düzenleme modunu açma/kapama
  void _toggleEditMode() {
    setState(() {
      _isEditingProfile = !_isEditingProfile;
      
      if (!_isEditingProfile) {
        // Düzenleme modundan çıkarken orijinal değerleri geri yükle
        final profileViewModel = Provider.of<ProfileViewModel>(context, listen: false);
        if (profileViewModel.userProfile != null) {
          _nameController.text = profileViewModel.userProfile!['name'] ?? '';
        }
      }
    });
  }

  // Profil güncelleme
  Future<void> updateUserProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final profileViewModel = Provider.of<ProfileViewModel>(context, listen: false);
    
    if (authViewModel.user != null) {
      // ProfileViewModel üzerinden kullanıcı profilini güncelle
      final success = await profileViewModel.updateUserProfile(
        authViewModel.user!.id,
        _nameController.text.trim(),
        '', // bio parametresi için boş değer
        '', // relationshipStatus için boş değer
      );
      
      // Ayrıca AuthViewModel üzerinden kullanıcı adını da güncelle
      // Bu Firebase Auth üzerinden displayName'i de güncellemeyi sağlar
      await profileViewModel.updateDisplayName(_nameController.text.trim());
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil başarıyla güncellendi')),
        );
        
        // Kullanıcı bilgilerini yenile
        await authViewModel.refreshUserData();
        
        setState(() {
          _isEditingProfile = false;
        });
      }
    }
  }

  // Çıkış yapma
  Future<void> _logout() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    // Onay iletişim kutusu göster
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
    
    if (shouldLogout == true) {
      await authViewModel.signOut();
      if (mounted) {
        context.go('/onboarding');
      }
    }
  }

  // Premium abonelik satın alma
  Future<void> _upgradeToPremium() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    // Burada normalde ödeme işlemi başlatılır
    // Şimdilik sadece premium durumunu simüle edelim
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Abonelik'),
        content: const Text(
          'Premium abonelik satın almak istediğinizden emin misiniz?\n\n'
          'Aylık Ücret: ₺49.99',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Satın Al'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      // Normalde gerçek ödeme işlemi yapılır
      final success = await authViewModel.upgradeToPremium();
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium abonelik başarıyla aktifleştirildi')),
        );
      }
    }
  }
  
  // Premium aboneliği iptal etme
  Future<void> _cancelPremium() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Abonelik İptali'),
        content: const Text(
          'Premium aboneliğinizi iptal etmek istediğinizden emin misiniz?\n\n'
          'İptal ettiğinizde premium özellikler kullanıma kapanacaktır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      final success = await authViewModel.cancelPremium();
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium abonelik başarıyla iptal edildi')),
        );
      }
    }
  }
  
  // Profil kartı
  Widget _buildProfileCard(
    BuildContext context,
    AuthViewModel authViewModel,
    ProfileViewModel profileViewModel,
  ) {
    // Doğrudan Firebase'den kullanıcı bilgilerini al, cache kullanılmasını engelle
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        
        final authUser = userSnapshot.data;
        
        if (authUser == null) {
          return Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Giriş Yapılmadı',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  const Text('Lütfen giriş yapın'),
                ],
              ),
            ),
          );
        }
        
        // Firebase User'ı kullanarak profil kartını oluştur
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(authUser.uid).get(),
          builder: (context, snapshot) {
            // Debug bilgileri
            debugPrint('Auth User: ${authUser.displayName}, ${authUser.email}');
            
            var userName = authUser.displayName ?? 'İsimsiz Kullanıcı';
            var userEmail = authUser.email ?? '';
            
            // Firestore'dan veri varsa güncelle
            if (snapshot.connectionState == ConnectionState.done && 
                snapshot.hasData && 
                snapshot.data != null && 
                snapshot.data!.exists) {
              
              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              
              if (userData != null) {
                debugPrint('Firestore User Data: $userData');
                
                // Firestore'dan isim bilgisini al
                if (userData['displayName'] != null && userData['displayName'].toString().isNotEmpty) {
                  userName = userData['displayName'];
                } else if (userData['name'] != null && userData['name'].toString().isNotEmpty) {
                  userName = userData['name'];
                }
              }
            }
            
            // Kullanıcı avatarı
            Widget avatarWidget = CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              child: Icon(
                Icons.person,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            );
            
            // Auth kullanıcısında fotoğraf varsa göster
            if (authUser.photoURL != null && authUser.photoURL!.isNotEmpty) {
              avatarWidget = CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(authUser.photoURL!),
              );
            }
            
            return Card(
              margin: const EdgeInsets.all(16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    avatarWidget,
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            userName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _showDirectNameChangeDialog(context),
                          tooltip: 'İsmi Değiştir',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userEmail,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: -0.1, end: 0, duration: 400.ms);
          },
        );
      },
    );
  }
  
  // Premium üyelik kartı
  Widget _buildPremiumCard(BuildContext context, AuthViewModel authViewModel) {
    // Doğrudan Firebase'den veri alma
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        
        // Premium durumu ve bitiş tarihi
        bool isPremium = false;
        DateTime? premiumExpiry;
        
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          
          if (userData != null) {
            isPremium = userData['isPremium'] ?? false;
            
            if (userData['premiumExpiry'] != null) {
              premiumExpiry = (userData['premiumExpiry'] as Timestamp?)?.toDate();
            }
          }
        }
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      color: Colors.amber.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Premium Üyelik',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isPremium && premiumExpiry != null)
                            Text(
                              'Aktif - ${_formatDate(premiumExpiry)} tarihinde yenileniyor',
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                          else
                            Text(
                              'Standart Üyelik',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isPremium) 
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextButton.icon(
                      onPressed: _cancelPremium,
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Aboneliği İptal Et'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Yapılan analizler kartı
  Widget _buildAnalysisCard(BuildContext context, ProfileViewModel profileViewModel) {
    // Doğrudan Firebase'den veri alma
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        
        // Analiz sayısı
        int analysisCount = 0;
        
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          
          if (userData != null) {
            analysisCount = userData['messagesAnalyzed'] ?? 0;
          }
        }
    
        return Card(
          margin: const EdgeInsets.all(16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          child: InkWell(
            onTap: () => _navigateToAnalysisHistory(),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.insights,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yapılan Analizler',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$analysisCount analiz',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Yapılan analizler sayfasına git
  void _navigateToAnalysisHistory() {
    // Şimdilik sadece bilgi verelim
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yapılan Analizler sayfası yapım aşamasında')),
    );
  }

  // Hesap ayarları kartları
  Widget _buildSettingsCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      child: GestureDetector( // InkWell yerine GestureDetector kullanılıyor
        onTap: () {
          debugPrint('[$title] kartına tıklandı');
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideX(begin: 0.1, end: 0);
  }
  
  // Navigasyon metodları
  void _navigateToAccountSettings(BuildContext context) {
    debugPrint('_navigateToAccountSettings metodu çağrıldı');
    _showAccountSettingsDialog(context);
  }

  void _navigateToNotificationSettings(BuildContext context) {
    debugPrint('_navigateToNotificationSettings metodu çağrıldı');
    _showNotificationSettingsDialog(context);
  }

  void _navigateToPrivacySettings(BuildContext context) {
    debugPrint('_navigateToPrivacySettings metodu çağrıldı');
    _showPrivacySettingsDialog(context);
  }

  void _navigateToHelpAndSupport(BuildContext context) {
    debugPrint('_navigateToHelpAndSupport metodu çağrıldı');
    _showHelpAndSupportDialog(context);
  }
  
  // Profil bilgileri dialog
  void _showAccountSettingsDialog(BuildContext context) {
    try {
      debugPrint('_showAccountSettingsDialog başladı');
      // Gerçek kullanıcı bilgilerini al
      final firebaseUser = FirebaseAuth.instance.currentUser;
      debugPrint('Firebase kullanıcısı: ${firebaseUser?.uid}');
      final adSoyadController = TextEditingController(text: firebaseUser?.displayName ?? "");
      final emailController = TextEditingController(text: firebaseUser?.email ?? "");
      final telefonController = TextEditingController();

      // Dialog'u göster, Firestore verisinin yüklenmesini bekleme
      debugPrint('Dialog gösteriliyor...');
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) { // Context parametresini yeniden adlandırdık
          debugPrint('Dialog builder çağrıldı');
          return AlertDialog(
            title: const Text('Profil Bilgileri'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: adSoyadController,
                    decoration: const InputDecoration(
                      labelText: 'Ad Soyad',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: false, // E-posta değiştirilemez
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: telefonController,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (firebaseUser != null && adSoyadController.text.trim().isNotEmpty) {
                    try {
                      // Firebase Auth displayName güncelleme
                      firebaseUser.updateDisplayName(adSoyadController.text.trim());
                      
                      // Firestore güncelleme
                      FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).update({
                        'displayName': adSoyadController.text.trim(),
                        'name': adSoyadController.text.trim(),
                        'phone': telefonController.text.trim(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Profil bilgileri güncellendi')),
                      );
                    } catch (e) {
                      debugPrint('Profil güncelleme hatası: $e');
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text('Hata: $e')),
                      );
                    }
                  }
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      );
      
      // Firestore'dan telefon numarasını asenkron olarak al ve varsa controller'a yükle
      if (firebaseUser != null) {
        FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).get().then((doc) {
          if (doc.exists && doc.data() != null) {
            final userData = doc.data()!;
            if (userData['phone'] != null && userData['phone'].toString().isNotEmpty) {
              telefonController.text = userData['phone'];
            }
          }
        }).catchError((e) {
          debugPrint('Kullanıcı verisi getirme hatası: $e');
        });
      }
    } catch (e) {
      debugPrint('Dialog gösterme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bir hata oluştu: $e')),
      );
    }
  }

  // Bildirim ayarları dialog
  void _showNotificationSettingsDialog(BuildContext context) {
    try {
      debugPrint('_showNotificationSettingsDialog başladı');
      // Bildirim ayarları başlangıç değerleri
      bool tumBildirimler = true;
      bool epostaBildirimleri = true;
      bool uygulamaBildirimleri = true;
      bool pazarlamaBildirimleri = false;
      
      // Dialog'u hemen göster
      debugPrint('Bildirim dialog gösteriliyor...');
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          debugPrint('Bildirim dialog builder çağrıldı');
          return StatefulBuilder(
            builder: (BuildContext statefulContext, StateSetter setState) {
              return AlertDialog(
                title: const Text('Bildirim Ayarları'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        title: const Text('Tüm Bildirimler'),
                        subtitle: const Text('Tüm bildirimleri aç/kapat'),
                        value: tumBildirimler,
                        onChanged: (value) {
                          setState(() {
                            tumBildirimler = value;
                            if (!value) {
                              epostaBildirimleri = false;
                              uygulamaBildirimleri = false;
                              pazarlamaBildirimleri = false;
                            }
                          });
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('E-posta Bildirimleri'),
                        subtitle: const Text('Önemli güncellemeler için e-posta alın'),
                        value: epostaBildirimleri,
                        onChanged: tumBildirimler
                            ? (value) {
                                setState(() {
                                  epostaBildirimleri = value;
                                });
                              }
                            : null,
                      ),
                      SwitchListTile(
                        title: const Text('Uygulama Bildirimleri'),
                        subtitle: const Text('Uygulama içi bildirimler alın'),
                        value: uygulamaBildirimleri,
                        onChanged: tumBildirimler
                            ? (value) {
                                setState(() {
                                  uygulamaBildirimleri = value;
                                });
                              }
                            : null,
                      ),
                      SwitchListTile(
                        title: const Text('Pazarlama Bildirimleri'),
                        subtitle: const Text('Kampanya ve özel fırsatlar hakkında bilgi alın'),
                        value: pazarlamaBildirimleri,
                        onChanged: tumBildirimler
                            ? (value) {
                                setState(() {
                                  pazarlamaBildirimleri = value;
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('İptal'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      try {
                        // Bildirim ayarlarını kaydetme işlemi
                        final firebaseUser = FirebaseAuth.instance.currentUser;
                        if (firebaseUser != null) {
                          FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid)
                            .collection('settings').doc('notifications').set({
                              'allEnabled': tumBildirimler,
                              'emailEnabled': epostaBildirimleri,
                              'appEnabled': uygulamaBildirimleri,
                              'marketingEnabled': pazarlamaBildirimleri,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                        }
                        
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('Bildirim ayarları güncellendi')),
                        );
                        Navigator.of(dialogContext).pop();
                      } catch (e) {
                        debugPrint('Bildirim ayarları güncelleme hatası: $e');
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('Hata: $e')),
                        );
                      }
                    },
                    child: const Text('Kaydet'),
                  ),
                ],
              );
            },
          );
        },
      );

      // Mevcut ayarları Firebase'den asenkron olarak al
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid)
          .collection('settings').doc('notifications').get().then((doc) {
            if (doc.exists && doc.data() != null) {
              // Belgenin verilerini al
              // Not: Dialog kapatıldıysa bu veri işe yaramaz ama
              // kod akışını etkilemez
            }
          }).catchError((e) {
            debugPrint('Bildirim ayarları getirme hatası: $e');
          });
      }
    } catch (e) {
      debugPrint('Bildirim dialog hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bir hata oluştu: $e')),
      );
    }
  }

  // Gizlilik ve güvenlik dialog
  void _showPrivacySettingsDialog(BuildContext context) {
    try {
      debugPrint('_showPrivacySettingsDialog başladı');
      // Basit sabit değerlerle dialog'u hemen göster
      bool konumPaylasimi = true;
      bool profilGorunurlugu = true;
      bool ikiAdimliDogrulama = false;
      bool cevrimiciDurum = true;

      debugPrint('Gizlilik dialog gösteriliyor...');
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          debugPrint('Gizlilik dialog builder çağrıldı');
          return StatefulBuilder(
            builder: (BuildContext statefulContext, StateSetter setState) {
              return AlertDialog(
                title: const Text('Gizlilik Ayarları'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        title: const Text('Konum Paylaşımı'),
                        subtitle: const Text('Konum bilgileriniz diğer kullanıcılarla paylaşılsın'),
                        value: konumPaylasimi,
                        onChanged: (value) {
                          setState(() {
                            konumPaylasimi = value;
                          });
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Profil Görünürlüğü'),
                        subtitle: const Text('Profiliniz diğer kullanıcılar tarafından görüntülenebilir'),
                        value: profilGorunurlugu,
                        onChanged: (value) {
                          setState(() {
                            profilGorunurlugu = value;
                          });
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('İki Adımlı Doğrulama'),
                        subtitle: const Text('Hesabınızı daha güvenli hale getirin'),
                        value: ikiAdimliDogrulama,
                        onChanged: (value) {
                          setState(() {
                            ikiAdimliDogrulama = value;
                          });
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Çevrimiçi Durum'),
                        subtitle: const Text('Çevrimiçi durumunuz diğer kullanıcılara gösterilsin'),
                        value: cevrimiciDurum,
                        onChanged: (value) {
                          setState(() {
                            cevrimiciDurum = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('İptal'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Burada kaydetme işlemi olabilir
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Gizlilik ayarları güncellendi')),
                      );
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Kaydet'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      debugPrint('Gizlilik dialog hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bir hata oluştu: $e')),
      );
    }
  }

  // Yardım ve destek dialog
  void _showHelpAndSupportDialog(BuildContext context) {
    try {
      debugPrint('_showHelpAndSupportDialog başladı');
      debugPrint('Yardım dialog gösteriliyor...');
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          debugPrint('Yardım dialog builder çağrıldı');
          return AlertDialog(
            title: const Text('Yardım ve Destek'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Sıkça Sorulan Sorular'),
                    subtitle: const Text('Yaygın sorular ve cevapları'),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('SSS sayfasına yönlendiriliyorsunuz')),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.support_agent),
                    title: const Text('Canlı Destek'),
                    subtitle: const Text('Destek ekibimizle görüşün'),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Canlı destek başlatılıyor...')),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('E-posta Desteği'),
                    subtitle: const Text('Sorularınızı e-posta ile gönderin'),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('E-posta desteği yakında aktif olacak')),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Kapat'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('Yardım dialog hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bir hata oluştu: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Test debug kodu - KALDIR
    // print("ProfileView build metodu çalıştı");
    // final mediaQuery = MediaQuery.of(context);
    // print("Ekran boyutları: ${mediaQuery.size.width}x${mediaQuery.size.height}");

    // Doğrudan Firebase'den kullanıcı bilgilerini al
    final firebaseUser = FirebaseAuth.instance.currentUser;
    
    // Debug için kullanıcı bilgilerini göster
    debugPrint('[BUILD] Firebase User: ${firebaseUser?.displayName}, ${firebaseUser?.email}');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          // Test butonu - KALDIR
          // IconButton(
          //   icon: const Icon(Icons.checklist),
          //   onPressed: () {
          //     print("Test butonu tıklandı");
          //     try {
          //       showDialog(
          //         context: context,
          //         barrierDismissible: true,
          //         builder: (_) => SimpleDialog(
          //           title: const Text('Basit Dialog Testi'),
          //           children: [
          //             Padding(
          //               padding: const EdgeInsets.symmetric(horizontal: 24.0),
          //               child: Text('Dialog açılması testi: ${DateTime.now()}'),
          //             ),
          //             TextButton(
          //               onPressed: () => Navigator.of(context).pop(),
          //               child: const Text('Kapat'),
          //             ),
          //           ],
          //         ),
          //       );
          //     } catch (e) {
          //       print("Dialog açma hatası: $e");
          //     }
          //   },
          //   tooltip: 'Dialog Test',
          // ),
          // Yenileme butonu
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _forceRefreshUserData,
            tooltip: 'Yenile',
          ),
          // Çıkış butonu
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: SafeArea(
        child: firebaseUser == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Oturum açık değil'),
                    ElevatedButton(
                      onPressed: () {
                        // Giriş sayfasına yönlendir
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lütfen giriş yapın')),
                        );
                      },
                      child: const Text('Giriş Yap'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _forceRefreshUserData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Profil kartı - artık ViewModel'ler yerine direkt Firebase kullanıyor
                      _buildProfileCard(context, Provider.of<AuthViewModel>(context), Provider.of<ProfileViewModel>(context)),
                      
                      const SizedBox(height: 16),
                      
                      // Premium üyelik kartı
                      _buildPremiumCard(context, Provider.of<AuthViewModel>(context)),
                      
                      // Analizler kartı
                      _buildAnalysisCard(context, Provider.of<ProfileViewModel>(context)),
                      
                      const SizedBox(height: 16),
                      
                      // Hesap ayarları kartları
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hesap Ayarları',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Basit buton yaklaşımını kaldır, önceki yapıyı kullan
                            _buildSettingsCard(
                              context,
                              icon: Icons.person,
                              title: 'Profil Bilgilerini Düzenle',
                              onTap: () {
                                _navigateToAccountSettings(context);
                              },
                            ),
                            _buildSettingsCard(
                              context,
                              icon: Icons.notifications,
                              title: 'Bildirim Ayarları',
                              onTap: () {
                                _navigateToNotificationSettings(context);
                              },
                            ),
                            _buildSettingsCard(
                              context,
                              icon: Icons.security,
                              title: 'Gizlilik ve Güvenlik',
                              onTap: () {
                                _navigateToPrivacySettings(context);
                              },
                            ),
                            _buildSettingsCard(
                              context,
                              icon: Icons.help,
                              title: 'Yardım ve Destek',
                              onTap: () {
                                _navigateToHelpAndSupport(context);
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3, // Profil sekmesi seçili
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Mesaj Analizi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'İlişki Raporu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb),
            label: 'Tavsiye Kartı',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
        onTap: (index) {
          if (index != 3) { // Profil dışındaki bir sekmeye tıklandığında
            // Burada ilgili sayfaya yönlendirme yapılacak
            // Örneğin: context.go('/messages') gibi
            // Şimdilik sadece bir mesaj gösterelim
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${index == 0 ? "Mesaj Analizi" : index == 1 ? "İlişki Raporu" : "Tavsiye Kartı"} sayfasına yönlendiriliyorsunuz...')),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 