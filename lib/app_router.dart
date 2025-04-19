import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'viewmodels/auth_viewmodel.dart';
import 'views/onboarding_view.dart';
import 'views/home_view.dart';
import 'views/message_analysis_view.dart';
import 'views/report_view.dart';
import 'views/advice_view.dart';
import 'views/profile_view.dart';
import 'views/past_analyses_view.dart';
import 'views/past_reports_view.dart';
import 'views/analysis_detail_view.dart';
import 'views/report_detail_view.dart';

// Placeholder Widgets for new routes
class AccountSettingsView extends StatelessWidget {
  const AccountSettingsView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Hesap Ayarları')));
  }
}

class NotificationSettingsView extends StatelessWidget {
  const NotificationSettingsView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Bildirim Ayarları')));
  }
}

class PrivacySettingsView extends StatelessWidget {
  const PrivacySettingsView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Gizlilik ve Güvenlik')));
  }
}

class HelpSupportView extends StatelessWidget {
  const HelpSupportView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Yardım ve Destek')));
  }
}

class LoginView extends StatelessWidget {
  const LoginView({super.key});
  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF121929), // Onboarding ile aynı arka plan rengi
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Giriş Yap',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // Logo veya uygulama adı
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 64,
                      color: const Color(0xFF9D3FFF),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'FlörtAI',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'İlişkinize yapay zeka desteği',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Giriş seçenekleri
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Aşağıdaki seçeneklerden biriyle devam edin:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Google ile giriş butonu
                  ElevatedButton(
                    onPressed: authViewModel.isLoading
                      ? null
                      : () async {
                          final success = await authViewModel.signInWithGoogle();
                          if (success && context.mounted) {
                            context.go(AppRouter.home);
                          }
                        },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: authViewModel.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/google_logo.png',
                              height: 24,
                              width: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Google ile Giriş Yap',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Apple ile giriş butonu
                  ElevatedButton(
                    onPressed: authViewModel.isLoading
                      ? null
                      : () async {
                          final success = await authViewModel.signInWithApple();
                          if (success && context.mounted) {
                            context.go(AppRouter.home);
                          }
                        },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: authViewModel.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.apple, size: 24),
                            const SizedBox(width: 12),
                            const Text(
                              'Apple ile Giriş Yap',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Gizlilik politikası ve kullanım şartları
                  Text(
                    'Giriş yaparak, Kullanım Koşullarını ve Gizlilik Politikasını kabul etmiş olursunuz.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppRouter {
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String home = '/home';
  static const String messageAnalysis = '/message-analysis';
  static const String report = '/report';
  static const String advice = '/advice';
  static const String profile = '/profile';
  // Yeni route sabitleri
  static const String accountSettings = '/account-settings';
  static const String notificationSettings = '/notification-settings';
  static const String privacySettings = '/privacy-settings';
  static const String helpSupport = '/help-support';
  // Geçmiş analizler ve raporlar için route sabitleri
  static const String pastAnalyses = '/past-analyses';
  static const String pastReports = '/past-reports';
  static const String analysisDetail = '/analysis-detail';
  static const String reportDetail = '/report-detail';

  static GoRouter createRouter(AuthViewModel authViewModel) {
    return GoRouter(
      initialLocation: onboarding,
      debugLogDiagnostics: true,
      refreshListenable: authViewModel,
      redirect: (context, state) async {
        final bool isLoggedIn = authViewModel.isLoggedIn;
        final bool isInitialized = authViewModel.isInitialized;
        final bool isOnboardingRoute = state.uri.path == onboarding;
        final bool isLoginRoute = state.uri.path == login;
        
        // SharedPreferences'tan onboarding durumunu al
        final prefs = await SharedPreferences.getInstance();
        final bool hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;
        
        debugPrint('------------------------------');
        debugPrint('Yönlendirme kontrolü:');
        debugPrint('isLoggedIn=$isLoggedIn');
        debugPrint('isInitialized=$isInitialized');
        debugPrint('hasCompletedOnboarding=$hasCompletedOnboarding');
        debugPrint('isOnboardingRoute=$isOnboardingRoute');
        debugPrint('isLoginRoute=$isLoginRoute');
        debugPrint('path=${state.uri.path}');
        debugPrint('------------------------------');

        // Henüz initializing ise, bir redirect yapmadan bekle
        if (!isInitialized) {
          debugPrint('Henüz initialize edilmemiş, yönlendirme yok');
          return null;
        }

        // 1. Kullanıcı giriş yapmamışsa ve onboarding'i tamamlamamışsa:
        // - Onboarding sayfasına yönlendir
        if (!isLoggedIn && !hasCompletedOnboarding && !isOnboardingRoute) {
          debugPrint('Kullanıcı giriş yapmamış, onboarding tamamlanmamış');
          debugPrint('=> Onboarding sayfasına yönlendiriliyor');
          return onboarding;
        }
        
        // 2. Kullanıcı giriş yapmamışsa ancak onboarding'i tamamlamışsa:
        // - Login sayfasına yönlendir (onboarding sayfasında veya login sayfasında değilse)
        if (!isLoggedIn && hasCompletedOnboarding && !isLoginRoute && !isOnboardingRoute) {
          debugPrint('Kullanıcı giriş yapmamış, onboarding tamamlanmış ve login sayfasında değil');
          debugPrint('=> Login sayfasına yönlendiriliyor');
          return login;
        }
        
        // 3. Kullanıcı giriş yapmışsa:
        // - Ana sayfaya yönlendir (home'da değilse)
        if (isLoggedIn && (isOnboardingRoute || isLoginRoute)) {
          debugPrint('Kullanıcı giriş yapmış ve onboarding/login sayfasında');
          debugPrint('=> Ana sayfaya yönlendiriliyor');
          return home;
        }
        
        // 4. Kullanıcı onboarding'i tamamlamışsa ve onboarding sayfasındaysa:
        // - Login sayfasına yönlendir
        if (hasCompletedOnboarding && isOnboardingRoute) {
          debugPrint('Onboarding tamamlanmış ve onboarding sayfasında');
          debugPrint('=> Login sayfasına yönlendiriliyor');
          return login;
        }
        
        // Diğer durumlar için redirect yok
        debugPrint('Herhangi bir yönlendirme koşulu sağlanmadı. Mevcut sayfada kalınıyor.');
        return null;
      },
      routes: [
        GoRoute(
          path: onboarding,
          name: 'onboarding',
          builder: (context, state) => const OnboardingView(),
        ),
        // Ana tabbar sayfası
        GoRoute(
          path: home,
          name: 'home',
          builder: (context, state) => const HomeView(),
        ),
        // Mesaj Analizi sayfası - Detay sayfası
        GoRoute(
          path: messageAnalysis,
          name: 'messageAnalysis',
          builder: (context, state) => const MessageAnalysisView(),
        ),
        // İlişki Raporu sayfası - Detay sayfası
        GoRoute(
          path: report,
          name: 'report',
          builder: (context, state) => const ReportView(),
        ),
        // Tavsiye Kartı sayfası - Detay sayfası
        GoRoute(
          path: advice,
          name: 'advice',
          builder: (context, state) => const AdviceView(),
        ),
        // Profil sayfası - Detay sayfası  
        GoRoute(
          path: profile,
          name: 'profile',
          builder: (context, state) => const ProfileView(),
        ),
        // Yeni route tanımlamaları
        GoRoute(
          path: accountSettings,
          name: 'accountSettings',
          builder: (context, state) => const AccountSettingsView(),
        ),
        GoRoute(
          path: notificationSettings,
          name: 'notificationSettings',
          builder: (context, state) => const NotificationSettingsView(),
        ),
        GoRoute(
          path: privacySettings,
          name: 'privacySettings',
          builder: (context, state) => const PrivacySettingsView(),
        ),
        GoRoute(
          path: helpSupport,
          name: 'helpSupport',
          builder: (context, state) => const HelpSupportView(),
        ),
        GoRoute(
          path: login,
          name: 'login',
          builder: (context, state) => const LoginView(),
        ),
        
        // Geçmiş analizler ve raporlar için route'lar
        GoRoute(
          path: pastAnalyses,
          name: 'pastAnalyses',
          builder: (context, state) => const PastAnalysesView(),
        ),
        GoRoute(
          path: pastReports,
          name: 'pastReports',
          builder: (context, state) => const PastReportsView(),
        ),
        GoRoute(
          path: '$analysisDetail/:id',
          name: 'analysisDetail',
          builder: (context, state) {
            final analysisId = state.pathParameters['id'] ?? '';
            return AnalysisDetailView(analysisId: analysisId);
          },
        ),
        GoRoute(
          path: '$reportDetail/:id',
          name: 'reportDetail',
          builder: (context, state) {
            final reportId = state.pathParameters['id'] ?? '';
            return ReportDetailView(reportId: reportId);
          },
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Sayfa Bulunamadı',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('Aradığınız sayfa (${state.uri.path}) mevcut değil.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(home), 
                child: const Text('Ana Sayfaya Dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 