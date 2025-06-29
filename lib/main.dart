import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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
import 'services/remote_config_service.dart';
import 'services/platform_service.dart';
import 'services/version_update_service.dart';
import 'services/campaign_service.dart';
import 'controllers/remote_config_controller.dart';
import 'controllers/message_coach_controller.dart';
import 'services/permission_service.dart';
import 'services/share_service.dart';
import 'utils/utils.dart';
import 'app_router.dart';

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
    
    // Firebase App Check - Remote Config için gerekli
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
      logger.i('Firebase App Check aktifleştirildi');
    } catch (e) {
      logger.w('Firebase App Check aktifleştirilemedi: $e, devam ediliyor');
    }
    
    // Platform servisini başlat
    final platformService = PlatformService(logger: logger);
    try {
      await platformService.baslat();
      logger.i('Platform servisi başlatıldı');
    } catch (e) {
      logger.e('Platform servisi başlatılamadı: $e, uygulama devam edecek');
    }

    // Remote Config servisini başlat
    final remoteConfigService = RemoteConfigService(
      platformService: platformService,
    );
    try {
      await remoteConfigService.baslat();
      logger.i('Remote Config servisi başlatıldı');
    } catch (e) {
      // Remote Config hatası uygulama çalışmasını engellemeyecek
      logger.w('Remote Config servisi başlatılırken hata: $e, uygulama Remote Config olmadan çalışacak');
    }

    // Versiyon güncelleme servisini başlat
    final versionUpdateService = VersionUpdateService(
      remoteConfigService: remoteConfigService,
      platformService: platformService,
      logger: logger,
    );

    // Kampanya servisini başlat
    final campaignService = CampaignService(
      remoteConfigService: remoteConfigService,
      platformService: platformService,
      logger: logger,
    );

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
            // Remote Config Service ve Controller
            provider.Provider<RemoteConfigService>.value(
              value: remoteConfigService,
            ),
            provider.ChangeNotifierProvider<RemoteConfigController>(
              create: (context) => RemoteConfigController(
                remoteConfigService: remoteConfigService,
                logger: logger,
              ),
            ),
            // Version Update Service
            provider.Provider<VersionUpdateService>.value(
              value: versionUpdateService,
            ),
            // Campaign Service
            provider.Provider<CampaignService>.value(
              value: campaignService,
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _handleSharedData();
    _checkPendingIntent();
  }

  Future<void> _handleSharedData() async {
    // Uygulama açılırken paylaşılan verileri kontrol et
    final sharedData = await ShareService.getSharedData();
    if (sharedData != null && sharedData['type'] != 'none') {
      _processSharedData(sharedData);
    }

    // Yeni intent geldiğinde dinle (normal durumlar)
    ShareService.setNewIntentListener((data) {
      if (data['type'] != 'none') {
        _processSharedData(data);
      }
    });
    
    // Hot intent geldiğinde dinle (uygulama arka planda açıkken)
    ShareService.setHotIntentListener((data) async {
      debugPrint('🔥 MAIN: Hot intent callback triggered');
      debugPrint('🔥 MAIN: Hot intent data: $data');
      
      if (data['type'] != 'none') {
        debugPrint('🔥 MAIN: Processing hot intent data');
        await _processHotIntent(data);
      } else {
        debugPrint('🔥 MAIN: Hot intent data type is "none", ignoring');
      }
    });
  }
  
  Future<void> _checkPendingIntent() async {
    // Bekleyen intent varsa veriyi al ve sakla, navigation'ı route hazır olana kadar ertele
    final hasPending = await ShareService.hasPendingIntent();
    if (hasPending) {
      final pendingData = await ShareService.processPendingIntent();
      if (pendingData != null && pendingData['type'] != 'none') {
        await _storePendingData(pendingData);
      }
    }
  }

  void _processSharedData(Map<String, dynamic> data) {
    final String type = data['type'] ?? '';
    
    // ShareService ile paylaşılan içeriği işle
    final String? content = ShareService.processSharedContent(data);
    
    if (content != null && content.isNotEmpty) {
      // WhatsApp sohbet verisini mesaj analizi sayfasına yönlendir
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          // Router'da message-analysis rotasına yönlendir ve içeriği parametre olarak gönder
          context.go('/message-analysis', extra: {'sharedText': content});
        }
      });
    }
  }
  
  void _processSharedDataDirectly(Map<String, dynamic> data) {
    final String type = data['type'] ?? '';
    
    // ShareService ile paylaşılan içeriği işle
    final String? content = ShareService.processSharedContent(data);
    
    if (content != null && content.isNotEmpty) {
      // Direkt routing yap (pending intent için)
      if (mounted && context.mounted) {
        // Router'da message-analysis rotasına yönlendir ve içeriği parametre olarak gönder
        context.go('/message-analysis', extra: {'sharedText': content});
      }
    }
  }
  
  // Hot intent (uygulama açıkken gelen paylaşım) işleme
  Future<void> _processHotIntent(Map<String, dynamic> data) async {
    final String type = data['type'] ?? '';
    
    // ShareService ile paylaşılan içeriği işle
    final String? content = ShareService.processSharedContent(data);
    
    if (content != null && content.isNotEmpty) {
      debugPrint('🔥 HOT INTENT algılandı: $type - ${content.length} karakter');
      
      // Router hazır mı kontrol et
      await _navigateWithSafetyCheck(content);
    }
  }
  
  // Güvenli navigation için GlobalKey kullan (Hot intent için)
  Future<void> _navigateWithSafetyCheck(String content) async {
    // Ortak GlobalKey navigation sistemini kullan
    await _navigateWithGlobalKey(content, isFromPendingData: false);
  }
  
  // Direkt content ile pending data saklama
  Future<void> _storePendingDataDirect(String content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_shared_content', content);
      await prefs.setBool('has_pending_navigation', true);
      debugPrint('📦 Hot intent content pending olarak kaydedildi');
    } catch (e) {
      debugPrint('❌ Pending data saklama hatası: $e');
    }
  }
  
  // Güvenli pending navigation handling (Cold start için)
  Future<void> _handlePendingNavigationSafely() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPendingNav = prefs.getBool('has_pending_navigation') ?? false;
      final pendingContent = prefs.getString('pending_shared_content');
      
      if (hasPendingNav && pendingContent != null && pendingContent.isNotEmpty) {
        debugPrint('🔄 COLD START: Pending navigation bulundu, GlobalKey navigation başlatılıyor...');
        
        // Router'ın biraz hazır olması için kısa bekleme
        await Future.delayed(const Duration(milliseconds: 800));
        
        // GlobalKey navigation sistemini kullan (hot intent ile aynı)
        await _navigateWithGlobalKey(pendingContent, isFromPendingData: true);
        
        // Temizlik - navigation başarılı olsa da olmasa da pending data'yı temizle
        await prefs.remove('pending_shared_content');
        await prefs.setBool('has_pending_navigation', false);
        debugPrint('🧹 Pending data temizlendi');
      }
    } catch (e) {
      debugPrint('❌ Pending navigation handling hatası: $e');
      // Hata durumunda da pending data'yı temizle
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_shared_content');
        await prefs.setBool('has_pending_navigation', false);
      } catch (cleanupError) {
        debugPrint('❌ Pending data temizlik hatası: $cleanupError');
      }
    }
  }
  
  // GoRouter ile navigation (Hot intent ve Cold start için ortak)
  Future<void> _navigateWithGlobalKey(String content, {bool isFromPendingData = false}) async {
    final source = isFromPendingData ? 'COLD START' : 'HOT INTENT';
    debugPrint('🔧 $source: GoRouter navigation başlatılıyor');
    
    try {
      // AppRouter.router ile direkt navigation yapmayı dene
      final router = AppRouter.router;
      if (router != null) {
        debugPrint('✅ $source: GoRouter hazır, navigation yapılıyor');
        router.go('/message-analysis', extra: {'sharedText': content});
        debugPrint('🚀 $source: Navigation başarılı (GoRouter ile)');
        return;
      } else {
        debugPrint('❌ $source: GoRouter henüz hazır değil');
      }
    } catch (e) {
      debugPrint('❌ $source: GoRouter navigation hatası: $e');
    }
    
    // GoRouter başarısız olduysa, GlobalKey ile deneme
    debugPrint('🔄 $source: Fallback GlobalKey navigation...');
    
    try {
      final navigatorState = Utils.navigatorKey.currentState;
      final context = Utils.navigatorKey.currentContext;
      
      if (navigatorState != null && context != null) {
        debugPrint('✅ $source: GlobalKey hazır, navigation yapılıyor');
        context.go('/message-analysis', extra: {'sharedText': content});
        debugPrint('🚀 $source: Fallback navigation başarılı (GlobalKey ile)');
        return;
      } else {
        debugPrint('❌ $source: GlobalKey de hazır değil (state: ${navigatorState != null}, context: ${context != null})');
      }
    } catch (e) {
      debugPrint('❌ $source: GlobalKey navigation hatası: $e');
    }
    
    // Son çare: 2 saniye bekleyip tekrar deneme
    debugPrint('🔄 $source: Son çare navigation (2 saniye bekleme)...');
    await Future.delayed(const Duration(seconds: 2));
    
    try {
      final router = AppRouter.router;
      if (router != null) {
        router.go('/message-analysis', extra: {'sharedText': content});
        debugPrint('🚀 $source: Son çare navigation başarılı');
        return;
      }
    } catch (e) {
      debugPrint('❌ $source: Son çare navigation hatası: $e');
    }
    
    // Her deneme başarısız olduysa
    if (!isFromPendingData) {
      // Hot intent için pending data olarak sakla
      debugPrint('📦 $source: Navigation tamamen başarısız, pending data olarak saklanıyor');
      await _storePendingDataDirect(content);
    } else {
      // Cold start pending data işlemi başarısız oldu, sadece logla
      debugPrint('❌ $source: Pending data navigation tamamen başarısız');
    }
  }
  
    Future<void> _storePendingData(Map<String, dynamic> data) async {
    try {
      final String? content = ShareService.processSharedContent(data);
      
      if (content != null && content.isNotEmpty) {
        // Veriyi SharedPreferences'e geçici olarak kaydet
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_shared_content', content);
        await prefs.setBool('has_pending_navigation', true);
        debugPrint('Pending data kaydedildi, router hazır olduğunda navigation yapılacak');
      }
    } catch (e) {
      debugPrint('Pending data saklama hatası: $e');
    }
  }
 
      @override
   Widget build(BuildContext context) {
     final LoggerService logger = LoggerService();
     logger.d('MyApp inşa ediliyor');
     
     // Build tamamlandığında pending navigation kontrolü yap
     WidgetsBinding.instance.addPostFrameCallback((_) async {
       _handlePendingNavigationSafely();
     });
    
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