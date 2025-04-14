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
    // Resimdeki mor renk
    const Color primaryPurple = Color(0xFF8B3FFD);
    const Color darkPurple = Color(0xFF7E33E6);
    const Color lightPurple = Color(0xFF9D59FF);

    final ColorScheme colorScheme = ColorScheme(
      primary: primaryPurple,
      onPrimary: Colors.white,
      secondary: darkPurple,
      onSecondary: Colors.white,
      tertiary: lightPurple,
      onTertiary: Colors.white,
      background: Colors.white,
      onBackground: Colors.black87,
      surface: Colors.white,
      onSurface: Colors.black87,
      error: Colors.redAccent,
      onError: Colors.white,
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
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
        fillColor: Colors.grey.shade100,
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
        backgroundColor: colorScheme.primary,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
      ),
      
      // FloatingActionButton stilleri
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
      ),
      
      // Scaffold arka plan rengi
      scaffoldBackgroundColor: Colors.white,
      
      // BottomNavigationBar stilleri
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
