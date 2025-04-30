import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../views/home_view.dart';
import '../views/report_view.dart';
import '../views/message_coach_view.dart';
import '../viewmodels/auth_viewmodel.dart';

/// Tüm uygulamaya ortak tabbar sağlayan ana görünüm
class MainView extends StatefulWidget {
  final int initialTabIndex;
  
  const MainView({
    Key? key, 
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Tab değişimini işleme
  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      return; // Zaten o sekmedeyse bir şey yapma
    }
    
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
      backgroundColor: const Color(0xFF21124A), // Koyu mor arka plan
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const NeverScrollableScrollPhysics(), // Sayfa kaydırma devre dışı
        children: const [
          // Anasayfa - Analiz
          HomeView(),
          
          // Rapor - Mevcut rapor sayfasını kullanalım
          ReportView(),
          
          // Mesaj Koçu - Mevcut mesaj koçu sayfasını kullanalım
          MessageCoachView(),
          
          // Profil - Mevcut profil sayfasını kullanalım
          HomeView(initialTabIndex: 3), // Eğer ayrı profil sayfası yoksa HomeView'ın profil modunu kullanalım
        ],
      ),
      // Alt navigasyon çubuğu - tüm sayfalarda ortak
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: const Color(0xFF21124A),
        selectedItemColor: const Color(0xFF9D3FFF),
        unselectedItemColor: Colors.white60,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Analiz',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment_outlined),
            activeIcon: Icon(Icons.assessment),
            label: 'Rapor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.psychology_outlined),
            activeIcon: Icon(Icons.psychology),
            label: 'Mesaj Koçu',
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
} 