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
import '../app_router.dart';

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

  // İsim değiştirme dialog'u - basitleştirilmiş versiyon
  Future<void> _showDirectNameChangeDialog(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('İsim değiştirme özelliği yakında kullanıma açılacak')),
    );
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

  // Hesaptan çıkış yapma - basitleştirilmiş
  Future<void> _logout() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    // Basit bir onay mesajı göster
    bool shouldLogout = false;
    
    // Kullanıcıya çıkış yapmak istediğinden emin olup olmadığını sor
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
        action: SnackBarAction(
          label: 'Evet, Çıkış Yap',
          onPressed: () {
            shouldLogout = true;
            // Çıkış işlemini başlat
            _performLogout(authViewModel);
          },
        ),
      ),
    );
  }
  
  // Asıl çıkış işlemini gerçekleştirir
  Future<void> _performLogout(AuthViewModel authViewModel) async {
    try {
      await authViewModel.signOut();
      if (mounted) {
        context.go('/onboarding');
      }
    } catch (e) {
      debugPrint('Çıkış yapma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Çıkış yapma hatası: $e')),
        );
      }
    }
  }

  // Premium abonelik satın alma
  Future<void> _upgradeToPremium() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Premium abonelik satın alma özelliği yakında kullanıma açılacak')),
    );
  }
  
  // Premium aboneliği iptal etme
  Future<void> _cancelPremium() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Premium abonelik iptal etme özelliği yakında kullanıma açılacak')),
    );
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
            );
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            debugPrint('[$title] butonuna tıklandı');
            onTap(); // Orijinal onTap fonksiyonunu çağıralım
          },
          borderRadius: BorderRadius.circular(16),
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
      ),
    );
  }
  
  // Navigasyon metodları - tümü basitleştirildi
  void _navigateToAccountSettings(BuildContext context) {
    debugPrint('_navigateToAccountSettings metodu çağrıldı');
    context.go('/account-settings'); // GoRouter ile yönlendirme
  }

  void _navigateToNotificationSettings(BuildContext context) {
    debugPrint('_navigateToNotificationSettings metodu çağrıldı');
    context.go('/notification-settings'); // GoRouter ile yönlendirme
  }

  void _navigateToPrivacySettings(BuildContext context) {
    debugPrint('_navigateToPrivacySettings metodu çağrıldı');
    context.go('/privacy-settings'); // GoRouter ile yönlendirme
  }

  void _navigateToHelpAndSupport(BuildContext context) {
    debugPrint('_navigateToHelpAndSupport metodu çağrıldı');
    context.go('/help-support'); // GoRouter ile yönlendirme
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
                              // Directly call context.go here for testing
                              onTap: () {
                                debugPrint('Profil Bilgilerini Düzenle - Doğrudan context.go çağrılıyor');
                                try {
                                  context.go('/account-settings');
                                } catch (e) {
                                  debugPrint('context.go hatası: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Yönlendirme hatası: $e')),
                                  );
                                }
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
          if (index != 3) {
            debugPrint('Bottom navigation bar index: $index seçildi');
            try {
              if (index == 0) {
                context.go('/message-analysis');
              } else if (index == 1) {
                context.go('/report');
              } else if (index == 2) {
                context.go('/advice');
              }
            } catch (e) {
              debugPrint('Yönlendirme hatası: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Yönlendirme hatası: $e')),
              );
            }
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          debugPrint('FloatingActionButton tıklandı');
          // Basit bir bilgi mesajı göster
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil düzenleme özelliği yakında kullanıma açılacak')),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.person_outline),
      ),
    );
  }
}
