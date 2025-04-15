import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../widgets/custom_button.dart';
import '../app_router.dart';
import '../widgets/auth_buttons.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({Key? key}) : super(key: key);

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final List<Map<String, dynamic>> _onboardingItems = [
    {
      'title': 'Gelişimi Takip Edin',
      'description': 'Detaylı raporlar ve grafiklerle ilişkinizin gelişimini izleyin',
      'image': 'assets/images/onboarding1.jpg',
    },
    {
      'title': 'Kişisel Tavsiyeler Alın',
      'description': 'Size özel tavsiyelerle ilişkinizi güçlendirin',
      'image': 'assets/images/onboarding2.jpg',
    },
    {
      'title': 'İlişkinizi Analiz Edin',
      'description': 'Mesajlarınızı analiz ederek ilişkinizin durumunu öğrenin',
      'image': 'assets/images/onboarding3.jpg',
    },
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _hasCompletedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;
    setState(() {
      _hasCompletedOnboarding = hasCompletedOnboarding;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCompletedOnboarding', true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Google ile giriş
  Future<void> _signInWithGoogle(BuildContext context) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    await _completeOnboarding();
    await authViewModel.signInWithGoogle();
  }

  // Apple ile giriş
  Future<void> _signInWithApple(BuildContext context) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    await _completeOnboarding();
    await authViewModel.signInWithApple();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF121929), // Koyu lacivert arka plan
      body: SafeArea(
        child: Column(
          children: [
            // Slaytlar
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _onboardingItems.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final item = _onboardingItems[index];
                  return _buildOnboardingItem(context, item);
                },
              ),
            ),
            
            // Sayfa İndikatörü
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _onboardingItems.length,
                  (index) => _buildPageIndicator(index == _currentPage, index),
                ),
              ),
            ),
            
            // Alt Butonlar (Atla, İleri, Başla)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Atla butonu
                  TextButton(
                    onPressed: () {
                      _pageController.animateToPage(
                        _onboardingItems.length - 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Text(
                      'Atla',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  
                  // İleri veya Başla butonu
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _onboardingItems.length - 1) {
                        // Son sayfadaysa ana sayfaya git
                        _completeOnboarding();
                        context.go(AppRouter.home);
                      } else {
                        // Sonraki sayfaya git
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D3FFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _onboardingItems.length - 1 ? 'Başla' : 'İleri',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_currentPage != _onboardingItems.length - 1) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 16),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Onboarding öğesi widget'ı
  Widget _buildOnboardingItem(BuildContext context, Map<String, dynamic> item) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Görsel
          Container(
            height: screenHeight * 0.35,
            width: screenHeight * 0.35,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                item['image'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Görsel yüklenemezse
                  return Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 64,
                      color: Colors.grey.shade600,
                    ),
                  );
                },
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Başlık
          Text(
            item['title'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Açıklama
          Text(
            item['description'],
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Sayfa indikatörü widget'ı
  Widget _buildPageIndicator(bool isActive, int index) {
    // Aktif sayfanın mor, diğerlerinin soluk mor olması
    final color = isActive 
        ? const Color(0xFF9D3FFF) 
        : Colors.grey.withOpacity(0.5);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
} 