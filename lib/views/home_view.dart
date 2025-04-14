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
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const NeverScrollableScrollPhysics(), // Manuel kaydırmayı engelle
        children: [
          // Sohbet Tab
          _buildChatTab(context),
          
          // Kişiler Tab
          _buildContactsTab(context),
          
          // Ayarlar Tab
          _buildSettingsTab(context),
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
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey.shade600,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_outlined),
              activeIcon: Icon(Icons.chat),
              label: 'Sohbet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.contacts_outlined),
              activeIcon: Icon(Icons.contacts),
              label: 'Kişiler',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Ayarlar',
            ),
          ],
        ),
      ),
    );
  }

  // Sohbet Tab
  Widget _buildChatTab(BuildContext context) {
    final theme = Theme.of(context);
    
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
                    'PWA CHATAPP',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
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
                child: Column(
                  children: [
                    // Uygulama Başlığı ve Arama
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PROGRASIVE WEB APP',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Arama Kutusu
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search',
                                prefixIcon: const Icon(Icons.search),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                suffixIcon: Container(
                                  margin: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Sohbet Listesi
                    Expanded(
                      child: ListView.builder(
                        itemCount: _dummyChats.length,
                        itemBuilder: (context, index) {
                          final chat = _dummyChats[index];
                          return ChatListItem(
                            name: chat.name,
                            message: chat.lastMessage,
                            avatarUrl: chat.avatarUrl,
                            onTap: () => _openChat(context, chat.name),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms);
  }

  // Kişiler Tab
  Widget _buildContactsTab(BuildContext context) {
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
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => _onItemTapped(0),
                  ),
                  Text(
                    'Add Contacts',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
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
                child: Column(
                  children: [
                    // Yeni Kişi Ekle
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ADD NEW CONTECT',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Telefon Numarası Girişi
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.phone, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      hintText: '+90 123-45-6789',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Ekle Butonu
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text('Add Contacts'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Ayırıcı Çizgi
                    const Divider(height: 30),
                    
                    // Kişiler
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text(
                            'EXISTING CONTACT IN PHONE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Kişiler Listesi
                    Expanded(
                      child: ListView.builder(
                        itemCount: _dummyContacts.length,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (context, index) {
                          final contact = _dummyContacts[index];
                          return ContactListItem(
                            name: contact.name,
                            phoneNumber: contact.phoneNumber,
                            avatarUrl: contact.avatarUrl,
                          );
                        },
                      ),
                    ),
                  ],
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

  // Ayarlar Tab
  Widget _buildSettingsTab(BuildContext context) {
    final theme = Theme.of(context);
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          
          // Profil Bilgileri
          CircleAvatar(
            radius: 50,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
            child: Icon(
              Icons.person,
              size: 60,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              authViewModel.currentUser?.displayName ?? 'Kullanıcı',
              style: theme.textTheme.titleLarge,
            ),
          ),
          Center(
            child: Text(
              authViewModel.currentUser?.email ?? 'user@example.com',
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 32),
          
          // Ayarlar Listesi
          _buildSettingItem(
            context, 
            'Tema Ayarları', 
            Icons.palette_outlined,
            () {},
          ),
          _buildSettingItem(
            context, 
            'Bildirim Ayarları', 
            Icons.notifications_outlined,
            () {},
          ),
          _buildSettingItem(
            context, 
            'Gizlilik ve Güvenlik', 
            Icons.security_outlined,
            () {},
          ),
          _buildSettingItem(
            context, 
            'Yardım ve Destek', 
            Icons.help_outline,
            () {},
          ),
          _buildSettingItem(
            context, 
            'Hakkında', 
            Icons.info_outline,
            () {},
          ),
          const SizedBox(height: 16),
          
          // Çıkış Yap Butonu
          ElevatedButton.icon(
            onPressed: () async {
              await authViewModel.signOut();
              if (context.mounted) {
                context.go(AppRouter.onboarding);
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Çıkış Yap'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms);
  }
  
  // Ayarlar İçin Item Widget
  Widget _buildSettingItem(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
  
  // Sohbet Açma
  void _openChat(BuildContext context, String userName) {
    // Sohbet Ekranına Git
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ChatDetailView(),
    );
  }
  
  // Örnek veriler
  final List<ChatModel> _dummyChats = [
    ChatModel(
      name: 'Metal Exchange',
      lastMessage: 'I\'m designing a new website, please check it out',
      avatarUrl: 'https://randomuser.me/api/portraits/men/1.jpg',
    ),
    ChatModel(
      name: 'Michael tony',
      lastMessage: 'Thank you for the update. We will check back later',
      avatarUrl: 'https://randomuser.me/api/portraits/men/2.jpg',
    ),
    ChatModel(
      name: 'Joseph ray',
      lastMessage: 'I\'m designing a new interface for the mobile app',
      avatarUrl: 'https://randomuser.me/api/portraits/men/3.jpg',
    ),
    ChatModel(
      name: 'Thomas adison',
      lastMessage: 'I\'m reviewing your design, it looks great',
      avatarUrl: 'https://randomuser.me/api/portraits/men/4.jpg',
    ),
    ChatModel(
      name: 'Jira',
      lastMessage: 'I\'m working on the project management tool',
      avatarUrl: 'https://randomuser.me/api/portraits/women/5.jpg',
    ),
  ];
  
  final List<ContactModel> _dummyContacts = [
    ContactModel(
      name: 'Metal Exchange',
      phoneNumber: '+90 123-456-7890',
      avatarUrl: 'https://randomuser.me/api/portraits/men/1.jpg',
    ),
    ContactModel(
      name: 'Michael tony',
      phoneNumber: '+90 123-456-7891',
      avatarUrl: 'https://randomuser.me/api/portraits/men/2.jpg',
    ),
    ContactModel(
      name: 'Joseph ray',
      phoneNumber: '+90 123-456-7892',
      avatarUrl: 'https://randomuser.me/api/portraits/men/3.jpg',
    ),
    ContactModel(
      name: 'Thomas adison',
      phoneNumber: '+90 123-456-7893',
      avatarUrl: 'https://randomuser.me/api/portraits/men/4.jpg',
    ),
  ];
}

// Sohbet Listesi İtem Widget
class ChatListItem extends StatelessWidget {
  final String name;
  final String message;
  final String avatarUrl;
  final VoidCallback onTap;
  
  const ChatListItem({
    super.key,
    required this.name,
    required this.message,
    required this.avatarUrl,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(avatarUrl),
            ),
            const SizedBox(width: 12),
            
            // İsim ve Mesaj
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // İşlem Butonları
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

// Kişi Listesi İtem Widget
class ContactListItem extends StatelessWidget {
  final String name;
  final String phoneNumber;
  final String avatarUrl;
  
  const ContactListItem({
    super.key,
    required this.name,
    required this.phoneNumber,
    required this.avatarUrl,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(avatarUrl),
          ),
          const SizedBox(width: 12),
          
          // İsim ve Telefon
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  phoneNumber,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Ekle Butonu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '+ Add',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Sohbet Model
class ChatModel {
  final String name;
  final String lastMessage;
  final String avatarUrl;
  
  ChatModel({
    required this.name,
    required this.lastMessage,
    required this.avatarUrl,
  });
}

// Kişi Model
class ContactModel {
  final String name;
  final String phoneNumber;
  final String avatarUrl;
  
  ContactModel({
    required this.name,
    required this.phoneNumber,
    required this.avatarUrl,
  });
}

// Sohbet Detay Görünümü
class ChatDetailView extends StatelessWidget {
  const ChatDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // App Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const CircleAvatar(
                  backgroundImage: NetworkImage('https://randomuser.me/api/portraits/men/1.jpg'),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Metal Exchange',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          
          // Mesaj Listesi
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                padding: const EdgeInsets.only(top: 16),
                children: const [
                  // Örnek mesajlar
                  MessageBubble(
                    message: 'Merhaba, nasılsın?',
                    isMe: false,
                    time: '12:30',
                  ),
                  MessageBubble(
                    message: 'İyiyim, teşekkürler. Sen nasılsın?',
                    isMe: true,
                    time: '12:32',
                  ),
                  MessageBubble(
                    message: 'Ben de iyiyim. Bugün hava çok güzel, değil mi?',
                    isMe: false,
                    time: '12:33',
                  ),
                  MessageBubble(
                    message: 'Evet, gerçekten öyle. Belki dışarı çıkabiliriz.',
                    isMe: true,
                    time: '12:35',
                  ),
                  MessageBubble(
                    message: 'Harika fikir! Ne zaman müsaitsin?',
                    isMe: false,
                    time: '12:36',
                  ),
                  MessageBubble(
                    message: 'Öğleden sonra müsaitim. Sana uyar mı?',
                    isMe: true,
                    time: '12:38',
                  ),
                  MessageBubble(
                    message: 'Ok',
                    isMe: false,
                    time: '12:39',
                  ),
                ],
              ),
            ),
          ),
          
          // Mesaj Giriş Alanı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: 'Type your message here...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Mesaj Balonu Widget
class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String time;
  
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.time,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) 
            const CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage('https://randomuser.me/api/portraits/men/1.jpg'),
            ),
          const SizedBox(width: 8),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.6,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMe ? theme.colorScheme.primary : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isMe) 
            const CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage('https://randomuser.me/api/portraits/men/3.jpg'),
            ),
        ],
      ),
    );
  }
} 