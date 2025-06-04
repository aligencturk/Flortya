import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'app_router.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/message_viewmodel.dart';
import 'viewmodels/advice_viewmodel.dart';
import 'viewmodels/report_viewmodel.dart';
import 'viewmodels/profile_viewmodel.dart';
import 'services/logger_service.dart';
import 'widgets/turkish_keyboard_provider.dart';
import 'widgets/page_structure.dart';
import 'controllers/home_controller.dart';
import 'services/ai_service.dart';
import 'services/user_service.dart';
import 'viewmodels/past_analyses_viewmodel.dart';
import 'viewmodels/past_reports_viewmodel.dart';
import 'services/notification_service.dart';
import 'controllers/message_coach_controller.dart';

// Global bayraklar servislerin durumunu takip etmek için
bool _isFirebaseInitialized = false;
bool _isMobileAdsInitialized = false;
bool _isDotEnvLoaded = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final LoggerService logger = LoggerService();
  
  try {
    logger.i('Uygulama başlatılıyor...');
    
    // Firebase'i sadece daha önce başlatılmamışsa başlat
    if (!_isFirebaseInitialized) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _isFirebaseInitialized = true;
        logger.i('Firebase başlatıldı');
      } catch (e) {
        if (e.toString().contains('duplicate-app')) {
          // Firebase zaten başlatılmış, sadece bayrak güncelle
          _isFirebaseInitialized = true;
          logger.i('Firebase zaten başlatılmış (duplicate-app yakalandı)');
        } else {
          rethrow;
        }
      }
    } else {
      logger.i('Firebase zaten başlatılmış');
    }
    
    // .env dosyasını sadece daha önce yüklenmemişse yükle  
    if (!_isDotEnvLoaded) {
      await dotenv.load(fileName: ".env");
      _isDotEnvLoaded = true;
      logger.i('.env dosyası yüklendi');
    } else {
      logger.i('.env dosyası zaten yüklü');
    }
    
    // MobileAds'i sadece daha önce başlatılmamışsa başlat
    if (!_isMobileAdsInitialized) {
      // Test cihazı ID'si tanımla
      final List<String> testDeviceIds = ['YOUR_TEST_DEVICE_ID'];
      
      await MobileAds.instance.initialize();
      MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: testDeviceIds),
      );
      _isMobileAdsInitialized = true;
      logger.i('Mobile Ads başlatıldı');
    } else {
      logger.i('Mobile Ads zaten başlatılmış');
    }
    
    // Firebase App Check - Geçici olarak deaktif, internal-error hatasını test etmek için
    /*
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
    logger.i('Firebase App Check aktifleştirildi');
    */
    logger.i('Firebase App Check geçici olarak deaktif');
    
    // Bildirim servisini başlat
    final notificationService = NotificationService();
    
    // Bildirim servisi başlatma işlemini try-catch içine alıyoruz
    try {
      await notificationService.initialize();
      logger.i('Bildirim servisi başlatıldı');
      
      // Firebase Cloud Messaging topic aboneliği
      // Bu kısmı da try-catch içine alıyoruz
      try {
        await notificationService.subscribeToTopic('general');
        logger.i('Genel bildirim kanalına abone olundu');
      } catch (e) {
        // Abone olma hatası uygulama çalışmasını engellemeyecek
        logger.w('Bildirim kanalına abone olunurken hata: $e, uygulama çalışmaya devam edecek');
      }
    } catch (e) {
      // Bildirim servisi hatası uygulama çalışmasını engellemeyecek
      logger.w('Bildirim servisi başlatılırken hata: $e, uygulama bildirimler olmadan çalışacak');
    }
    
    // Tarih formatları için Türkçe desteği
    await initializeDateFormatting('tr_TR');
    
    // Servis örnekleri
    final firestore = FirebaseFirestore.instance;
    final aiService = AiService();
    final loggerService = LoggerService();
    final userService = UserService();
    
    // Kullanıcı giriş durumunu SharedPreferences'e kaydet
    await _updateLoginStatusInPrefs();
    
    // AuthViewModel önceden oluşturuluyor, böylece diğer view modeller buna bağımlı olabilir
    final authViewModel = AuthViewModel(
      authService: FirebaseAuth.instance,
      firestore: firestore,
    );
    
    // ReportViewModel önceden oluşturuluyor
    final reportViewModel = ReportViewModel();
    
    runApp(
      ProviderScope(
        child: provider.MultiProvider(
          providers: [
            provider.ChangeNotifierProvider<AuthViewModel>.value(
              value: authViewModel,
            ),
            provider.ChangeNotifierProvider<MessageViewModel>(
              create: (_) => MessageViewModel(),
            ),
            provider.ChangeNotifierProvider<ProfileViewModel>(
              create: (_) => ProfileViewModel(),
            ),
            provider.ChangeNotifierProvider<ReportViewModel>.value(
              value: reportViewModel,
            ),
            provider.ChangeNotifierProvider<AdviceViewModel>(
              create: (_) => AdviceViewModel(
                firestore: firestore,
                aiService: aiService,
                logger: loggerService,
                notificationService: notificationService,
              ),
            ),
            provider.ChangeNotifierProvider<HomeController>(
              create: (_) => HomeController(
                userService: userService,
                aiService: aiService,
              ),
            ),
            provider.ChangeNotifierProvider<PastAnalysesViewModel>(
              create: (_) => PastAnalysesViewModel(),
            ),
            provider.ChangeNotifierProvider<PastReportsViewModel>(
              create: (_) => PastReportsViewModel(reportViewModel),
            ),
            provider.ChangeNotifierProvider<MessageCoachController>(
              create: (_) => MessageCoachController(),
            ),
          ],
          child: MyApp(),
        ),
      ),
    );
    
  } catch (e, stackTrace) {
    logger.e('Uygulama başlatma hatası: $e', stackTrace);
    runApp(ErrorApp(error: e.toString()));
  }
}

/// Firebase Authentication durumunu SharedPreferences'e kaydeder
Future<void> _updateLoginStatusInPrefs() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      // Kullanıcı giriş yapmış
      await prefs.setBool('isLoggedIn', true);
    } else {
      // Kullanıcı çıkış yapmış veya giriş yapmamış
      await prefs.setBool('isLoggedIn', false);
    }
    
    debugPrint('Kullanıcı giriş durumu güncellendi: ${user != null}');
  } catch (e) {
    debugPrint('Giriş durumu kaydetme hatası: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final LoggerService logger = LoggerService();
    logger.d('MyApp inşa ediliyor');
    
    // AuthViewModel'i al
    final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
    
    // Material App temasını yapılandır
    return TurkishKeyboardProvider(
      child: MaterialApp.router(
        title: 'Flörtya',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6750A4),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Nunito',
          // Tema uzantısı olarak PageStructureTheme ekleniyor
          extensions: [
            PageStructureTheme(
              mainBorderRadius: const BorderRadius.all(Radius.circular(16.0)),
              pagePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              contentPadding: const EdgeInsets.all(16.0),
              formPadding: const EdgeInsets.all(16.0),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              spacingSize: 16.0,
            ),
          ],
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
  
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flörtya - Hata',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Global bayrakları sıfırla ve tekrar dene
                        _isFirebaseInitialized = false;
                        _isMobileAdsInitialized = false;
                        _isDotEnvLoaded = false;
                        main();
                      },
                      child: const Text('Tekrar Dene'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Uygulamayı tamamen kapatmak için SystemNavigator kullan
                        SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Uygulamayı Kapat'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}