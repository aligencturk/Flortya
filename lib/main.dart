import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_router.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/message_viewmodel.dart';
import 'viewmodels/report_viewmodel.dart';
import 'viewmodels/advice_viewmodel.dart';
import 'viewmodels/profile_viewmodel.dart';
import 'services/logger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Logger servisini başlat
  final logger = LoggerService();
  logger.i('Uygulama başlatılıyor...');
  
  try {
    // Firebase'i başlat
    await Firebase.initializeApp();
    logger.i('Firebase başlatıldı');
    
    // .env dosyasını yükle
    await dotenv.load(fileName: ".env");
    logger.i('.env dosyası yüklendi');
    
    runApp(const MyApp());
  } catch (e) {
    logger.e('Uygulama başlatılırken hata oluştu', e);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = LoggerService();
    logger.d('MyApp inşa ediliyor');
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => MessageViewModel()),
        ChangeNotifierProvider(create: (_) => ReportViewModel()),
        ChangeNotifierProvider(create: (_) => AdviceViewModel()),
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
      ],
      child: Builder(
        builder: (context) {
          logger.d('Router ve tema yapılandırılıyor');
          return MaterialApp.router(
            title: 'Retto - İlişki Analiz Asistanı',
            debugShowCheckedModeBanner: false,
            theme: _buildAppTheme(),
            routerConfig: AppRouter.createRouter(context),
          );
        },
      ),
    );
  }

  // Uygulama temasını oluşturma
  ThemeData _buildAppTheme() {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6A3DE8), // Mor
      secondary: const Color(0xFFFF6B6B), // Kırmızı-Pembe
      tertiary: const Color(0xFF4ECDC4), // Turkuaz
      brightness: Brightness.light,
    );

    final ThemeData baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
    );

    return baseTheme.copyWith(
      // Yazı tipleri
      textTheme: GoogleFonts.poppinsTextTheme(baseTheme.textTheme),
      
      // Buton stilleri
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: colorScheme.onPrimary,
          backgroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      
      // Kart stilleri
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: colorScheme.surface,
      ),
      
      // Input stilleri
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      // AppBar stilleri
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: colorScheme.primary,
        ),
      ),
      
      // Scaffold arka plan rengi
      scaffoldBackgroundColor: colorScheme.background,
    );
  }
}
