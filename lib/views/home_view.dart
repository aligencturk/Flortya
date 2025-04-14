import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/message_viewmodel.dart';
import '../app_router.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
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
    final theme = Theme.of(context);
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const NeverScrollableScrollPhysics(), // Manuel kaydırmayı engelle
        children: [
          // Mesaj Analizi Tab
          _buildMessageAnalysisTab(context),
          
          // İlişki Raporu Tab
          _buildRelationshipReportTab(context),
          
          // Tavsiye Kartı Tab
          _buildAdviceCardTab(context),
          
          // Profil Tab
          _buildProfileTab(context),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: Colors.grey.shade600,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_outlined),
              activeIcon: Icon(Icons.chat),
              label: 'Mesaj Analizi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'İlişki Raporu',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.card_giftcard_outlined),
              activeIcon: Icon(Icons.card_giftcard),
              label: 'Tavsiye Kartı',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Önce viewModel'i temizle
          messageViewModel.clearCurrentMessage();
          // Sonra analiz sayfasına git
          context.push(AppRouter.messageAnalysis);
        },
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms);
  }

  // Mesaj Analizi Tab
  Widget _buildMessageAnalysisTab(BuildContext context) {
    final theme = Theme.of(context);
    final messageViewModel = Provider.of<MessageViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    // build sırasında doğrudan state değişikliği yapmamak için postFrameCallback kullan
    WidgetsBinding.instance.addPostFrameCallback((_) { 
      // Callback içinde tekrar kontrol et
      if (context.mounted && // Widget ağaçta mı?
          authViewModel.user != null && 
          !messageViewModel.isLoading && 
          !messageViewModel.isFirstLoadCompleted) { 
        messageViewModel.loadMessages(authViewModel.user!.id); 
      } 
    });
    
    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Mesaj Analizi',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            
            // Ana içerik
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      const Text(
                        'Mesajlarınızı Analiz Edin',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Mesaj Analiz Kartı
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                                'Yeni Analiz Başlat',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                                  fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 12),
                              const Text(
                                'Mesajlarınızı yükleyin ve ilişkiniz hakkında detaylı analiz alın.',
                                style: TextStyle(
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  // Önce viewModel'i temizle
                                  messageViewModel.clearCurrentMessage();
                                  // Sonra analiz sayfasına git
                                  context.push(AppRouter.messageAnalysis);
                                },
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Mesaj Yükle'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ],
                              ),
                            ),
                          ),
                      
                      const SizedBox(height: 24),
                      const Text(
                        'Son Analizler',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Analizler listesi
                      if (messageViewModel.isLoading)
                        const Expanded(
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (messageViewModel.messages.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Henüz analiz bulunamadı',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'İlk analizinizi yapmak için "Mesaj Yükle" butonuna tıklayın',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: messageViewModel.messages.length,
                            itemBuilder: (context, index) {
                              final message = messageViewModel.messages[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                                    child: Icon(
                                      Icons.message,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  title: Text(
                                    message.content.length > 30 
                                        ? '${message.content.substring(0, 30)}...' 
                                        : message.content
                                  ),
                                  subtitle: Text(
                                    '${message.sentAt.day}.${message.sentAt.month}.${message.sentAt.year}'
                                  ),
                                  trailing: message.isAnalyzed
                                    ? Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 18)
                                    : const Icon(Icons.arrow_forward_ios, size: 16),
                                  onTap: () {
                                    // Mesaj detayına git
                                    messageViewModel.clearCurrentMessage();
                                    
                                    // Mesaj ID boş kontrolü
                                    if (message.id.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Geçersiz mesaj ID'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    
                                    // İlgili mesajın ID'sini saklayalım
                                    final String messageId = message.id;
                                    
                                    // İlgili mesajın detay sayfasına yönlendir
                                    context.push(AppRouter.messageAnalysis);
                                    
                                    // Mesaj detayını yükle - bu işlem sayfa açıldıktan sonra yapılır
                                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                                      try {
                                        // Mesajı yükle
                                        final loadedMessage = await messageViewModel.getMessage(messageId);
                                        
                                        // Mesaj yüklenemediyse hata ver
                                        if (loadedMessage == null) {
                                          throw Exception('Mesaj yüklenemedi');
                                        }
                                        
                                        // Eğer mesaj analiz edilmişse sonucu da yükle
                                        if (loadedMessage.isAnalyzed) {
                                          await messageViewModel.getAnalysisResult(messageId);
                                        }
                                      } catch (e) {
                                        print('HATA: Mesaj yüklenirken hata oluştu: $e');
                                      }
                                    });
                                  },
                                ),
                              ).animate().fadeIn(duration: 300.ms, delay: (50 * index).ms);
                            },
                          ),
                        ),
                  ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms);
  }

  // İlişki Raporu Tab
  Widget _buildRelationshipReportTab(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'İlişki Raporu',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            
            // Ana içerik
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                        'İlişkinizin Detaylı Analizi',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                          fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 16),
                      
                      // İlişki Puanı Kartı
                      Card(
                        elevation: 2,
                                shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text(
                                'İlişki Uyum Puanınız',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 150,
                                    height: 150,
                                    child: CircularProgressIndicator(
                                      value: 0.78,
                                      strokeWidth: 12,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                    ),
                                  ),
                                  Text(
                                    '78%',
                            style: TextStyle(
                                      fontSize: 36,
                              fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                              const SizedBox(height: 24),
                              const Text(
                                'İyi bir ilişkiniz var! Detaylı raporunuzu görmek için tıklayın.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  context.push(AppRouter.report);
                                },
                                child: const Text('Detaylı Raporu Gör'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
                      
                      const SizedBox(height: 24),
                      
                      // Kategoriler
                      const Text(
                        'Kategori Bazlı Analizler',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
                      
                      // Örnek Kategori Kartları
                      Expanded(
                        child: ListView(
                          children: [
                            _buildCategoryCard(
            context, 
                              title: 'İletişim Kalitesi',
                              value: 0.85,
                              color: Colors.blue,
                            ),
                            _buildCategoryCard(
            context, 
                              title: 'Duygusal Bağ',
                              value: 0.72,
                              color: Colors.purple,
                            ),
                            _buildCategoryCard(
            context, 
                              title: 'Çatışma Çözümü',
                              value: 0.65,
                              color: Colors.orange,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ),
          ),
        ],
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms);
  }
  
  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required double value,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${(value * 100).toInt()}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Tavsiye Kartı Tab
  Widget _buildAdviceCardTab(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Tavsiye Kartları',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.favorite_border, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            
            // Ana içerik
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kişiselleştirilmiş Tavsiyeler',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'İlişkinizi güçlendirmek için günlük tavsiyeler',
                        style: TextStyle(
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Tavsiye Kartları
                      Expanded(
                        child: PageView.builder(
                          itemCount: 5,
                          controller: PageController(viewportFraction: 0.9),
                          itemBuilder: (context, index) {
                            // Renk listesi
                            final List<Color> cardColors = [
                              const Color(0xFF9D59FF),
                              const Color(0xFF4F8CF6),
                              const Color(0xFFFF7F50),
                              const Color(0xFF8CCF4D),
                              const Color(0xFFE85D75),
                            ];
                            
                            // Başlık listesi
                            final List<String> titles = [
                              'Aktif Dinleme',
                              'Takdir Etme',
                              'Ortak Aktiviteler',
                              'Açık İletişim',
                              'Destek Olma'
                            ];
                            
                            // İçerik listesi
                            final List<String> contents = [
                              'Bugün partnerinizi daha aktif bir şekilde dinlemeyi deneyin. Göz teması kurun ve ne söylediklerini kendi cümlelerinizle tekrarlayın.',
                              'Partnerinize bugün en az üç kez takdir ettiğiniz bir özelliğini söyleyin ve bunu neden beğendiğinizi açıklayın.',
                              'Bu hafta sonu birlikte yapabileceğiniz yeni bir aktivite planlayın. İkinizin de daha önce denemediği bir şey seçin.',
                              'Sizi rahatsız eden bir konuyu "Ben" dili kullanarak açıkça ifade edin. Suçlamadan ve sakin bir şekilde hislerinizi paylaşın.',
                              'Partnerinizin zor bir durumla karşılaştığında sadece dinleyin ve çözüm önermeden önce "Nasıl yardımcı olabilirim?" diye sorun.'
                            ];
                          
                            return GestureDetector(
                              onTap: () {
                                context.push(AppRouter.advice);
                              },
                              child: Card(
                                elevation: 4,
                                color: cardColors[index],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                                      Icon(
                                        Icons.card_giftcard,
                                        color: Colors.white.withOpacity(0.9),
                                        size: 48,
                                      ),
                                      const SizedBox(height: 24),
                  Text(
                                        titles[index],
                    style: const TextStyle(
                                          color: Colors.white,
                      fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Expanded(
                                        child: Text(
                                          contents[index],
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () {},
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: cardColors[index],
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(30),
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                            ),
                                            child: const Text(
                                              'Detaylar',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
        ),
      ),
    );
                          },
                        ),
                      ),
                      
                      // Sayfa indikatörü
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (index) => Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: index == 0
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
            ),
          ),
        ],
      ),
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms);
  }

  // Profil Tab
  Widget _buildProfileTab(BuildContext context) {
    final theme = Theme.of(context);
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: SafeArea(
      child: Column(
        children: [
          // App Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                  Text(
                    'Profil',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          
            // Ana içerik
          Expanded(
            child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Profil Bilgileri
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.primary,
                              width: 3,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<User?>(
                          future: Future.value(FirebaseAuth.instance.currentUser),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            }
                            
                            final user = snapshot.data;
                            final displayName = user?.displayName ?? 'İsimsiz Kullanıcı';
                            final email = user?.email ?? '';
                            
                            return Column(
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        
                        // Üyelik Bilgileri
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
              children: [
                                ListTile(
                                  leading: Icon(
                                    Icons.workspace_premium,
                                    color: theme.colorScheme.primary,
                                  ),
                                  title: const Text('Premium Üyelik'),
                                  subtitle: const Text('Aktif - 12.05.2023 tarihinde yenileniyor'),
                                ),
                                const Divider(),
                                ListTile(
                                  leading: Icon(
                                    Icons.insights,
                    color: theme.colorScheme.primary,
                                  ),
                                  title: const Text('Yapılan Analizler'),
                                  subtitle: const Text('22 analiz'),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                  onTap: () {},
                ),
              ],
            ),
          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Hesap Ayarları
                        const Text(
                          'Hesap Ayarları',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                              ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: const Text('Hesap Bilgileri'),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () {},
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.notifications_outlined),
                                title: const Text('Bildirim Ayarları'),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () {},
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.security_outlined),
                                title: const Text('Gizlilik ve Güvenlik'),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () {},
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.support_outlined),
                                title: const Text('Yardım ve Destek'),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () {},
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: Icon(
                                  Icons.logout,
                                  color: Colors.red.shade400,
                                ),
                                title: Text(
                                  'Çıkış Yap',
                  style: TextStyle(
                                    color: Colors.red.shade400,
                  ),
                                ),
                                onTap: () async {
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
                                    if (context.mounted) {
                                      context.go('/onboarding');
                                    }
                                  }
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
            ),
        ],
      ),
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms);
  }
} 