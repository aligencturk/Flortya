import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'viewmodels/auth_viewmodel.dart';
import 'views/onboarding_view.dart';
import 'views/home_view.dart';
import 'views/message_analysis_view.dart';
import 'views/report_view.dart';
import 'views/advice_view.dart';
import 'views/profile_view.dart';

class AppRouter {
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String messageAnalysis = '/message-analysis';
  static const String report = '/report';
  static const String advice = '/advice';
  static const String profile = '/profile';

  static GoRouter createRouter(AuthViewModel authViewModel) {
    return GoRouter(
      initialLocation: onboarding,
      debugLogDiagnostics: true,
      refreshListenable: authViewModel,
      redirect: (context, state) async {
        final bool isLoggedIn = authViewModel.isLoggedIn;
        final bool isInitialized = authViewModel.isInitialized;
        final bool isOnboardingRoute = state.uri.path == onboarding;

        // Henüz initializing ise, bir redirect yapmadan bekle
        if (!isInitialized) {
          return null;
        }

        // Kullanıcı oturum açmış ve onboarding sayfasındaysa, ana sayfaya yönlendir
        if (isLoggedIn && isOnboardingRoute) {
          return home;
        }

        // Kullanıcı oturum açmamış ve onboarding sayfasında değilse, onboarding'e yönlendir
        if (!isLoggedIn && !isOnboardingRoute) {
          return onboarding;
        }

        // Diğer durumlar için redirect yok
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