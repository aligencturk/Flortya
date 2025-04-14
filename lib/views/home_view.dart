import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../app_router.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Tab değişimini işleme
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  // Sayfa değişimini işleme
  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const NeverScrollableScrollPhysics(), // Manuel kaydırmayı engelle
        children: [
          // Mesaj Analizi Tab
          _buildMessageAnalysisTab(context),
          
          // İlişki Raporu Tab
          _buildReportTab(context),
          
          // Tavsiyeler Tab
          _buildAdviceTab(context),
          
          // Profil Tab
          _buildProfileTab(context),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            activeIcon: Icon(Icons.message),
            label: 'Analiz',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment_outlined),
            activeIcon: Icon(Icons.assessment),
            label: 'Rapor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tips_and_updates_outlined),
            activeIcon: Icon(Icons.tips_and_updates),
            label: 'Tavsiyeler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  // Mesaj Analizi Tab İçeriği
  Widget _buildMessageAnalysisTab(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesaj Analizi'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Açıklama
              Text(
                'Mesajlarınızı burada analiz edebilirsiniz',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Aşk mesajlarınızı yapay zeka ile analiz ederek ilişki dinamiklerinizi anlayın.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Açıklama
              ElevatedButton.icon(
                onPressed: () => context.go(AppRouter.messageAnalysis),
                icon: const Icon(Icons.search),
                label: const Text('Mesaj Analizi Yap'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms);
  }

  // İlişki Raporu Tab İçeriği
  Widget _buildReportTab(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İlişki Raporu'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Açıklama
              Text(
                'İlişkinizi 5 soruda analiz edin',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '5 basit soruyu yanıtlayarak ilişki tipinizi öğrenin ve kişiselleştirilmiş öneriler alın.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Açıklama
              ElevatedButton.icon(
                onPressed: () => context.go(AppRouter.report),
                icon: const Icon(Icons.assignment),
                label: const Text('Testi Başlat'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms);
  }

  // Tavsiyeler Tab İçeriği
  Widget _buildAdviceTab(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Günlük Tavsiye'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Açıklama
              Text(
                'Günlük ilişki tavsiyesi alın',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Her gün ilişkinizi güçlendirmek için farklı tavsiyeler keşfedin.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Açıklama
              ElevatedButton.icon(
                onPressed: () => context.go(AppRouter.advice),
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('Günün Tavsiyesini Gör'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms);
  }

  // Profil Tab İçeriği
  Widget _buildProfileTab(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final user = authViewModel.user;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authViewModel.signOut();
              if (mounted) {
                context.go(AppRouter.onboarding);
              }
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profil Kartı
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Profil Resmi
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            backgroundImage: user.photoURL.isNotEmpty
                                ? NetworkImage(user.photoURL)
                                : null,
                            child: user.photoURL.isEmpty
                                ? Text(
                                    user.displayName.isNotEmpty
                                        ? user.displayName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  )
                                : null,
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Kullanıcı Bilgileri
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName.isNotEmpty
                                      ? user.displayName
                                      : 'İsimsiz Kullanıcı',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (user.email.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    user.email,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: user.isPremium
                                        ? Colors.amber.withOpacity(0.2)
                                        : Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: user.isPremium ? Colors.amber : Colors.grey,
                                    ),
                                  ),
                                  child: Text(
                                    user.isPremium ? 'Premium Üye' : 'Standart Üye',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: user.isPremium ? Colors.amber.shade800 : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Ayarlar Bölümü
                  Text(
                    'Ayarlar',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Ayarlar Listesi
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildSettingsItem(
                          context,
                          icon: Icons.person,
                          title: 'Profili Düzenle',
                          onTap: () => context.go(AppRouter.profile),
                        ),
                        const Divider(height: 1),
                        _buildSettingsItem(
                          context,
                          icon: Icons.workspace_premium,
                          title: user.isPremium ? 'Premium Yönetimi' : 'Premium\'a Yükselt',
                          onTap: () => context.go(AppRouter.profile),
                        ),
                        const Divider(height: 1),
                        _buildSettingsItem(
                          context,
                          icon: Icons.help_outline,
                          title: 'Yardım ve Destek',
                          onTap: () {},
                        ),
                        const Divider(height: 1),
                        _buildSettingsItem(
                          context,
                          icon: Icons.privacy_tip_outlined,
                          title: 'Gizlilik Politikası',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    )
    .animate()
    .fadeIn(duration: 300.ms);
  }

  // Ayarlar öğesi
  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
} 