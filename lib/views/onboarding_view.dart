import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../widgets/custom_button.dart';
import '../app_router.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({Key? key}) : super(key: key);

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final List<Map<String, dynamic>> _onboardingItems = [
    {
      'title': 'İlişkinizi Analiz Edin',
      'description': 'Mesajlarınızı AI ile analiz edin, ilişki dinamiklerinizi anlayın.',
      'animation': 'assets/animations/message_analysis.json',
    },
    {
      'title': 'İlişki Tipinizi Öğrenin',
      'description': '5 soruluk testle ilişki tipinizi belirleyin ve öneriler alın.',
      'animation': 'assets/animations/relationship_test.json',
    },
    {
      'title': 'Günlük Tavsiyeler Alın',
      'description': 'Her gün ilişkinizi güçlendirmek için farklı tavsiyeler keşfedin.',
      'animation': 'assets/animations/daily_advice.json',
    },
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Üst Başlık
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Retto',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            
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
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _onboardingItems.length,
                  (index) => _buildPageIndicator(index == _currentPage),
                ),
              ),
            ),
            
            // Giriş Butonları
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  CustomButton(
                    text: 'Google ile Giriş Yap',
                    onPressed: () => _signInWithGoogle(context),
                    icon: Icons.login,
                    isFullWidth: true,
                    isLoading: authViewModel.isLoading,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  CustomButton(
                    text: 'Apple ile Giriş Yap',
                    onPressed: () => _signInWithApple(context),
                    icon: Icons.apple,
                    type: ButtonType.outline,
                    isFullWidth: true,
                    isLoading: authViewModel.isLoading,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animasyon (şimdilik basit Container)
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(
                Icons.favorite,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Başlık
          Text(
            item['title'],
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          )
          .animate()
          .fadeIn(duration: 600.ms)
          .slide(begin: const Offset(0, 0.2), end: Offset.zero),
          
          const SizedBox(height: 16),
          
          // Açıklama
          Text(
            item['description'],
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          )
          .animate()
          .fadeIn(delay: 200.ms, duration: 600.ms)
          .slide(begin: const Offset(0, 0.2), end: Offset.zero),
        ],
      ),
    );
  }

  // Sayfa indikatörü widget'ı
  Widget _buildPageIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // Google ile giriş
  Future<void> _signInWithGoogle(BuildContext context) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    final success = await authViewModel.signInWithGoogle();
    
    if (success && mounted) {
      context.go(AppRouter.home);
    }
  }

  // Apple ile giriş
  Future<void> _signInWithApple(BuildContext context) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    final success = await authViewModel.signInWithApple();
    
    if (success && mounted) {
      context.go(AppRouter.home);
    }
  }
} 