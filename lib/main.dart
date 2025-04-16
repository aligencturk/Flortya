import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_router.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/message_viewmodel.dart';
import 'viewmodels/advice_viewmodel.dart';
import 'viewmodels/report_viewmodel.dart';
import 'viewmodels/profile_viewmodel.dart';
import 'services/logger_service.dart';
import 'widgets/turkish_keyboard_provider.dart';
import 'controllers/home_controller.dart';
import 'screens/message_analysis_screen.dart';
import 'services/shared_prefs.dart';
import 'services/ai_service.dart';
import 'services/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final LoggerService logger = LoggerService();
  
  try {
    logger.i('Uygulama başlatılıyor...');
    
    // Firebase başlatma
    await Firebase.initializeApp();
    logger.i('Firebase başlatıldı');
    
    // .env dosyasını yükle
    await dotenv.load(fileName: ".env");
    logger.i('.env dosyası yüklendi');
    
    // Firebase App Check
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
    logger.i('Firebase App Check aktifleştirildi');
    
    // Tarih formatları için Türkçe desteği
    await initializeDateFormatting('tr_TR');
    
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>(
            create: (_) => AuthViewModel(
              authService: FirebaseAuth.instance,
              firestore: FirebaseFirestore.instance,
            ),
          ),
          ChangeNotifierProvider<MessageViewModel>(
            create: (_) => MessageViewModel(),
          ),
          ChangeNotifierProvider<ProfileViewModel>(
            create: (_) => ProfileViewModel(),
          ),
          ChangeNotifierProvider<ReportViewModel>(
            create: (_) => ReportViewModel(),
          ),
          ChangeNotifierProvider<AdviceViewModel>(
            create: (_) => AdviceViewModel(),
          ),
          ChangeNotifierProvider<HomeController>(
            create: (_) => HomeController(
              userService: UserService(),
              aiService: AiService(),
            ),
          ),
        ],
        child: MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    logger.e('Uygulama başlatma hatası: $e', stackTrace);
    runApp(ErrorApp(error: e.toString()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final LoggerService logger = LoggerService();
    logger.d('MyApp inşa ediliyor');
    
    // AuthViewModel'i al
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    // Material App temasını yapılandır
    return TurkishKeyboardProvider(
      child: MaterialApp.router(
        title: 'FlörtAI',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6750A4),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Nunito',
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('tr', 'TR'),
        ],
        locale: const Locale('tr', 'TR'),
        routerConfig: AppRouter.createRouter(authViewModel),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({Key? key, required this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlörtAI - Hata',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Uygulama başlatılamadı',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    main();
                  },
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
