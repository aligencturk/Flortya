import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/message_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../viewmodels/advice_viewmodel.dart';
import '../viewmodels/report_viewmodel.dart';
import '../controllers/home_controller.dart';
import '../app_router.dart';
import '../utils/feedback_utils.dart';

// Grafik Çizici Sınıf
class ChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> dataPoints;
  
  ChartPainter({required this.dataPoints});
  
  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;
    
    // Nokta boyutu ve renkleri
    const pointRadius = 4.0;
    final pointFillColor = Colors.white;
    final pointStrokeColor = const Color(0xFF9D3FFF);
    
    // Çizgi stili
    final linePaint = Paint()
      ..color = const Color(0xFF9D3FFF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    // Nokta dolgu stili
    final pointFillPaint = Paint()
      ..color = pointFillColor
      ..style = PaintingStyle.fill;
    
    // Nokta kenar stili
    final pointStrokePaint = Paint()
      ..color = pointStrokeColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    // Arka plan çizgileri çizme
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;
    
    // Yatay ızgara çizgileri
    for (var i = 0; i <= 5; i++) {
      final y = size.height - (i * size.height / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    
    // Dikey ızgara çizgileri
    final totalPoints = dataPoints.length;
    for (var i = 0; i <= totalPoints - 1; i++) {
      final x = i * size.width / (totalPoints - 1);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    
    // Noktaları birleştiren çizgiyi çizme
    final path = Path();
    
    // İlk noktayı ayarla
    var startPoint = _getPointLocation(0, dataPoints[0]['y'], size, totalPoints);
    path.moveTo(startPoint.dx, startPoint.dy);
    
    // Diğer noktalara bağla
    for (var i = 1; i < dataPoints.length; i++) {
      final point = _getPointLocation(i, dataPoints[i]['y'], size, totalPoints);
      path.lineTo(point.dx, point.dy);
    }
    
    // Çizgiyi çiz
    canvas.drawPath(path, linePaint);
    
    // Noktaları çizme
    for (var i = 0; i < dataPoints.length; i++) {
      final point = _getPointLocation(i, dataPoints[i]['y'], size, totalPoints);
      
      // Dolgu
      canvas.drawCircle(point, pointRadius, pointFillPaint);
      // Kenar
      canvas.drawCircle(point, pointRadius, pointStrokePaint);
    }
  }
  
  // X, Y koordinatlarını ekrandaki konuma dönüştürme
  Offset _getPointLocation(int x, int y, Size size, int totalPoints) {
    final xPos = (x * size.width / (totalPoints - 1));
    final yPos = size.height - (y * size.height / 100);
    return Offset(xPos, yPos);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HomeView extends StatefulWidget {
  final int initialTabIndex;
  
  const HomeView({
    super.key, 
    this.initialTabIndex = 0,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 0;
  late final PageController _pageController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Widget referans anahtarları
  final GlobalKey _analyzeButtonKey = GlobalKey();
  final GlobalKey _relationshipScoreCardKey = GlobalKey();
  final GlobalKey _categoryAnalysisKey = GlobalKey();
  final GlobalKey _relationshipEvaluationKey = GlobalKey();
  
  // AdviceCard tanımını düzelt
  Map<String, dynamic>? _dailyAdvice;
  
  @override
  void initState() {
    super.initState();
    // Başlangıç sekmesini widget'tan al
    _selectedIndex = widget.initialTabIndex;
    _pageController = PageController(initialPage: _selectedIndex);
    
    // Ana sayfayı yüklendiğinde güncelle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeController = Provider.of<HomeController>(context, listen: false);
      homeController.anaSayfayiGuncelle();
      
      // ProfileViewModel'e context referansı ekle
      final profileViewModel = Provider.of<ProfileViewModel>(context, listen: false);
      profileViewModel.setContext(context);
      
      // ProfileViewModel'i MessageViewModel'e aktar
      final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
      messageViewModel.setProfileViewModel(profileViewModel);
      
      // Günlük tavsiyeyi yükle
      _loadDailyAdvice();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Tab değişimini işleme
  void _onItemTapped(int index) {
    debugPrint('Tab değişimi: $index');
    
    if (_selectedIndex == index) {
      return; // Zaten o sekmedeyse bir şey yapma
    }
    
    try {
      // Önce sayfalar arası geçiş animasyonu
      setState(() {
        _selectedIndex = index;
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
      
      // Gerekirse GoRouter ile yönlendirme
      /* Bu kodu etkinleştirirseniz, bottom bar tıklamaları ayrı bir sayfaya yönlendirir
      if (index == 0) {
        context.go('/message-analysis');
      } else if (index == 1) {
        context.go('/report');
      } else if (index == 2) {
        context.go('/advice');
      } else if (index == 3) {
        context.go('/profile');
      }
      */
    } catch (e) {
      debugPrint('Tab değişimi hatası: $e');
    }
  }

  // Sayfa değişimini işleme
  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Günlük tavsiyeyi yükle
  Future<void> _loadDailyAdvice() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
    
    if (authViewModel.user != null) {
      await adviceViewModel.getDailyAdviceCard(authViewModel.user!.id);
    }
  }
  
  // Tavsiyeyi yenile (premium kullanıcı için)
  Future<void> _refreshDailyAdvice() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
    
    if (authViewModel.user != null) {
      await adviceViewModel.getDailyAdvice(
        authViewModel.user!.id,
        isPremium: authViewModel.isPremium,
        force: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A2A80), Color(0xFF2D1957)],
          ),
        ),
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const NeverScrollableScrollPhysics(), // Manuel kaydırmayı engelle
              children: [
                // Mesaj Analizi Tab
                _buildMessageAnalysisTab(context),
                
                // İlişki Raporu Tab
                _buildRelationshipReportTab(context),
                
                // Tavsiye Kartı Tab
                _buildAdviceCardTab(context),
                
                // Profil Tab
                _buildProfileTab(context),
              ],
            ),
            
            // Sıfırlama butonu kaldırıldı - Artık ayarlar menüsünde yer alıyor
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2D1957),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white.withOpacity(0.5),
          backgroundColor: Colors.transparent,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Analiz',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Rapor',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_outline),
              activeIcon: Icon(Icons.favorite),
              label: 'Tavsiyeler',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0 ? FloatingActionButton(
        onPressed: () {
          // Önce viewModel'i temizle
          messageViewModel.clearCurrentMessage();
          // Sonra analiz sayfasına git
          context.push(AppRouter.messageAnalysis);
        },
        backgroundColor: const Color(0xFF9D3FFF),
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    )
    .animate()
    .fadeIn(duration: 300.ms);
  }

  // Sıfırlama onay diyalogu göster
  void _showResetConfirmationDialog(BuildContext context) {
    try {
      debugPrint('Veri sıfırlama onay diyaloğu gösteriliyor...');
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF352269),
          title: const Text(
            'Verileri Sıfırla',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Bu işlem geri alınamaz. Tüm analiz verilerin silinecek. Devam etmek istiyor musun?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint('Veri sıfırlama işlemi iptal edildi');
                Navigator.pop(context);
              },
              child: const Text(
                'Vazgeç',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.8),
              ),
              onPressed: () {
                debugPrint('Veri sıfırlama işlemi onaylandı, işlem başlatılıyor...');
                Navigator.pop(context);
                
                // Kısa bir gecikme ekleyerek UI işlemlerinin tamamlanmasını sağla
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (context.mounted) {
                    _resetUserData(context);
                  } else {
                    debugPrint('Context artık geçerli değil, veri sıfırlama işlemi iptal edildi');
                  }
                });
              },
              child: const Text(
                'Evet, Sıfırla',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Veri sıfırlama diyaloğu gösterilirken hata oluştu: $e');
      // Hata durumunda kullanıcıyı bilgilendir
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beklenmeyen bir hata oluştu: $e')),
      );
    }
  }
  
  // Kullanıcı verilerini sıfırla
  Future<void> _resetUserData(BuildContext context) async {
    try {
      debugPrint('Veri sıfırlama işlemi başlatılıyor...');
      
      // Context kontrolü
      if (!context.mounted) {
        debugPrint('Context geçerli değil, işlem iptal ediliyor');
        return;
      }
      
      // Tüm view modelleri ve controlleri al (null kontrolü ekleyerek)
      ProfileViewModel? profileViewModel;
      ReportViewModel? reportViewModel;
      MessageViewModel? messageViewModel;
      HomeController? homeController;
      
      try {
        profileViewModel = Provider.of<ProfileViewModel>(context, listen: false);
        debugPrint('ProfileViewModel başarıyla alındı');
      } catch (e) {
        debugPrint('ProfileViewModel alınırken hata: $e');
      }
      
      try {
        reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
        debugPrint('ReportViewModel başarıyla alındı');
      } catch (e) {
        debugPrint('ReportViewModel alınırken hata: $e');
      }
      
      try {
        messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
        debugPrint('MessageViewModel başarıyla alındı');
      } catch (e) {
        debugPrint('MessageViewModel alınırken hata: $e');
      }
      
      try {
        homeController = Provider.of<HomeController>(context, listen: false);
        debugPrint('HomeController başarıyla alındı');
      } catch (e) {
        debugPrint('HomeController alınırken hata: $e');
      }
      
      // Hiçbir provider alınamadıysa işlemi iptal et
      if (profileViewModel == null && reportViewModel == null && 
          messageViewModel == null && homeController == null) {
        debugPrint('Hiçbir viewModel alınamadı, işlem iptal ediliyor');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veriler temizlenirken bir hata oluştu: Provider erişimi başarısız')),
          );
        }
        return;
      }
      
      // Yükleme göster
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veriler temizleniyor...')),
        );
      }
      
      // Firestore'daki verileri temizle
      bool firestoreTemizlendi = false;
      if (profileViewModel != null) {
        try {
          firestoreTemizlendi = await profileViewModel.clearUserAnalysisData();
          debugPrint('Firestore veri temizleme sonucu: $firestoreTemizlendi');
        } catch (e) {
          debugPrint('Firestore veri temizleme hatası: $e');
        }
      }
      
      if (!firestoreTemizlendi && profileViewModel != null) {
        debugPrint('Firestore verileri temizlenemedi');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veritabanı verileri temizlenirken bir hata oluştu')),
          );
        }
        return;
      }
      
      // Yerel verileri temizle (her biri için ayrı try-catch bloğu)
      if (reportViewModel != null) {
        try {
          reportViewModel.resetReport();
          debugPrint('ReportViewModel sıfırlandı');
        } catch (e) {
          debugPrint('ReportViewModel sıfırlama hatası: $e');
        }
      }
      
      if (messageViewModel != null) {
        try {
          messageViewModel.clearCurrentMessage();
          debugPrint('MessageViewModel sıfırlandı');
        } catch (e) {
          debugPrint('MessageViewModel sıfırlama hatası: $e');
        }
      }
      
      if (homeController != null) {
        try {
          homeController.resetAnalizVerileri();
          debugPrint('HomeController sıfırlandı');
        } catch (e) {
          debugPrint('HomeController sıfırlama hatası: $e');
        }
      }
      
      // Başarı mesajı göster
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tüm veriler başarıyla temizlendi')),
        );
        debugPrint('Veri sıfırlama işlemi başarıyla tamamlandı');
      }
    } catch (e) {
      debugPrint('Veri sıfırlama işleminde beklenmeyen hata: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  // Mesaj Analizi Tab
  Widget _buildMessageAnalysisTab(BuildContext context) {
    // HomeController'ı dinle
    final homeController = Provider.of<HomeController>(context);
    final analizSonucu = homeController.sonAnalizSonucu;
    final kategoriDegisimleri = homeController.kategoriDegisimleri;
    final tavsiyeler = homeController.kisisellestirilmisTavsiyeler;
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    
    return SafeArea(
        child: Column(
          children: [
            // App Bar
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                FutureBuilder<User?>(
                  future: Future.value(FirebaseAuth.instance.currentUser),
                  builder: (context, snapshot) {
                    final displayName = snapshot.data?.displayName ?? 'Ziyaretçi';
                    return Text(
                      'Merhaba, $displayName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    );
                  },
                ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () {},
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                    onPressed: () {
                      _showSettingsDialog(context);
                    },
                  ),
                ],
              ),
            ),
            
            // Analiz Et Butonu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                key: _analyzeButtonKey, // Rehber için anahtar ekle
                onTap: () {
                  // Önce viewModel'i temizle
                  messageViewModel.clearCurrentMessage();
                  // Sonra analiz sayfasına git
                  context.push(AppRouter.messageAnalysis);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D3FFF),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Analiz Et',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Ana içerik
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  children: [
                    // İlişki Uyum Puanı Kartı
                    Container(
                      key: _relationshipScoreCardKey, // Rehber için anahtar ekle
                      margin: const EdgeInsets.only(top: 16, bottom: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF352269),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                            const Text(
                                'İlişki Uyum Puanı',
                              style: TextStyle(
                                  color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                  SizedBox(
                                    width: 120,
                                    height: 120,
                                    child: CircularProgressIndicator(
                                      value: analizSonucu != null ? analizSonucu.iliskiPuani / 100 : 0,
                                      strokeWidth: 12,
                                      backgroundColor: Colors.white.withOpacity(0.2),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        analizSonucu != null 
                                          ? _getScoreColor(analizSonucu.iliskiPuani)
                                          : Colors.grey
                                      ),
                                    ),
                                  ),
                                  Text(
                                    analizSonucu != null 
                                      ? '${analizSonucu.iliskiPuani}%' 
                                      : 'Analiz\nYapılmamış',
                                  style: TextStyle(
                                      fontSize: analizSonucu != null ? 32 : 18,
                                    fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              analizSonucu != null 
                                ? _getScoreText(analizSonucu.iliskiPuani)
                                : 'İlişkinizi analiz etmek için bir mesaj gönderin',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          
                          // Geçmiş analiz noktasına göre ilerleme
                          if (analizSonucu != null && homeController.analizGecmisi.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: Column(
                                children: [
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Önceki Analize Göre',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                                        ),
                                      ),
                                      _buildChangeIndicator(
                                        context,
                                        analizSonucu.iliskiPuani - 
                                          homeController.analizGecmisi[homeController.analizGecmisi.length - 2].iliskiPuani
                                      ),
                                    ],
                                ),
                                const SizedBox(height: 16),
                                  SizedBox(
                                    height: 60,
                                    width: double.infinity,
                                    child: CustomPaint(
                                      painter: ChartPainter(
                                        dataPoints: homeController.analizGecmisi
                                          .map((analiz) => {
                                            'x': homeController.analizGecmisi.indexOf(analiz), 
                                            'y': analiz.iliskiPuani
                                          })
                                          .toList()
                                      ),
                                    ),
                                  ),
                                ],
                                  ),
                                ),
                              ],
                                ),
                              ),
                    
                    // Kategori Analiz Kartları
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      key: _categoryAnalysisKey, // Rehber için anahtar ekle
                      child: const Text(
                          'Kategori Analizleri',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                    ),
                    
                    SizedBox(
                      height: 190,
                      child: analizSonucu != null 
                        ? ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            children: analizSonucu.kategoriPuanlari.entries.map((entry) {
                              final String kategoriAdi = _formatCategoryName(entry.key);
                              final int puan = entry.value;
                              final String aciklama = _getCategoryDescription(entry.key, puan);
                              final Color renk = _getCategoryColor(entry.key);
                              
                              // Değişim bilgisi
                              final dynamic degisim = kategoriDegisimleri[entry.key];
                              final int? degisimYuzde = degisim != null ? degisim['yuzde'] as int? : null;
                              
                              return Row(
                                children: [
                                  _buildCategoryCard(
                                    context, 
                                    title: kategoriAdi,
                                    description: aciklama,
                                    value: puan / 100,
                                    color: renk,
                                    width: 220,
                                    degisim: degisimYuzde,
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              );
                            }).toList(),
                          )
                        : Center(
                            child: Text(
                              'Önce bir analiz yapmanız gerekiyor',
                                  style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                    fontSize: 16,
                                  ),
                            ),
                          ),
                    ),
                        
                        const SizedBox(height: 24),
                    
                    // Kişiselleştirilmiş Tavsiyeler
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                          'Kişiselleştirilmiş Tavsiyeler',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                    ),
                    
                    // Tavsiye Kartları
                    if (analizSonucu != null && tavsiyeler.isNotEmpty)
                      ...tavsiyeler.map((tavsiye) => _buildAdviceCard(
                        context, 
                        title: _getTitleFromAdvice(tavsiye),
                        advice: tavsiye,
                        color: _getAdviceColor(tavsiye),
                        icon: _getAdviceIcon(tavsiye),
                      ))
                    else if (analizSonucu == null)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF352269),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: Colors.white.withOpacity(0.5),
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Henüz analiz yapılmamış',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Kişiselleştirilmiş tavsiyeler için analiz yapmanız gerekiyor',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // İlişki Değerlendirme Butonu ekle
                    Container(
                      key: _relationshipEvaluationKey, // Rehber için anahtar ekle
                      margin: const EdgeInsets.only(bottom: 20),
                      child: ElevatedButton.icon(
                        onPressed: () => _showRelationshipEvaluation(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9D3FFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.assessment_outlined),
                        label: const Text('İlişki Değerlendirmesi Başlat'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      )
    .animate()
    .fadeIn(duration: 300.ms);
  }

  // İlişki raporu özeti alma
  String _getRelationshipSummary(ReportViewModel reportViewModel) {
    if (reportViewModel.reportResult == null) {
      return "Henüz bir ilişki değerlendirmesi yapılmadı.";
    }
    
    final relationshipType = reportViewModel.reportResult!['relationship_type'] as String? ?? 'Belirsiz';
    
    // İlişki tipine göre özet metin döndür
    final Map<String, String> summaries = {
      'Güven Odaklı': 'İlişkinizde güven temeli güçlü ve sağlıklı. İletişiminiz açık, birbirinize karşı dürüst ve şeffafsınız.',
      'Tutkulu': 'İlişkinizde tutku ve yoğun duygular ön planda. Duygusal bağınız güçlü ancak dengeyi korumak için iletişime özen göstermelisiniz.',
      'Uyumlu': 'İlişkinizde uyum seviyesi oldukça yüksek. Birbirinizi tamamlıyor ve birlikte hareket edebiliyorsunuz.',
      'Dengeli': 'İlişkiniz dengeli bir şekilde ilerliyor. Karşılıklı anlayış, saygı ve iletişiminiz güçlü.',
      'Mesafeli': 'İlişkinizde duygusal bir mesafe söz konusu. Daha açık iletişim kurarak ve duygularınızı paylaşarak bu mesafeyi azaltabilirsiniz.',
      'Kaçıngan': 'İlişkinizde sorunlardan kaçınma eğilimi görülüyor. Zor konuları konuşmaktan çekinmeyin.',
      'Endişeli': 'İlişkinizde endişe ve kaygı unsurları öne çıkıyor. Güveni artırmak için açık iletişim kurun.',
      'Çatışmalı': 'İlişkinizde çatışmalar ön planda. Yapıcı tartışma becerileri geliştirerek ve birbirinizi daha iyi dinleyerek ilişkinizi güçlendirebilirsiniz.',
      'Kararsız': 'İlişkinizde kararsızlık hâkim durumda. Ortak hedefler belirleyerek ve gelecek planları yaparak ilişkinize yön verebilirsiniz.',
      'Gelişmekte Olan': 'İlişkiniz gelişim aşamasında ve potansiyel vadediyor. Sabır ve anlayış göstererek, iletişimi güçlendirmeye devam edin.',
      'Gelişmekte Olan, Güven Sorunları Olan': 'İlişkiniz gelişiyor ancak güven konusunda çalışmanız gereken alanlar var.',
      'Sağlıklı': 'İlişkiniz son derece sağlıklı bir yapıya sahip. Güçlü iletişim, karşılıklı saygı ve güven temelinde ilerliyor.',
      'Zorlayıcı': 'İlişkinizde zorlayıcı unsurlar ve sınır sorunları var. Kişisel sınırlarınızı netleştirerek bu zorlukları aşabilirsiniz.',
      'Sağlıklı ve Gelişmekte Olan': 'İlişkiniz sağlıklı bir temel üzerinde gelişmeye devam ediyor. İletişiminiz açık ve saygı çerçevesinde ilerliyor.',
      'Belirsiz': 'İlişkinizde bazı gelişim alanları tespit edildi. Önerileri uygulayarak iletişiminizi güçlendirebilirsiniz.',
    };
    
    return summaries[relationshipType] ?? 'İlişkiniz için yapılan değerlendirme sonucunda, kişiselleştirilmiş öneriler hazırlandı.';
  }

  // Kategori kartı widget'ı
  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required String description,
    required double value,
    required Color color,
    double width = 180,
    int? degisim,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF352269),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (degisim != null)
                _buildChangeIndicator(context, degisim),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
    );
  }

  // Değişim göstergesi widget'ı
  Widget _buildChangeIndicator(BuildContext context, int change) {
    final isPositive = change > 0;
    final color = isPositive ? Colors.green : (change < 0 ? Colors.red : Colors.grey);
    final icon = isPositive ? Icons.arrow_upward : (change < 0 ? Icons.arrow_downward : Icons.remove);
    
    return Row(
              children: [
        Icon(
          icon,
          color: color,
          size: 14,
        ),
        const SizedBox(width: 2),
          Text(
          '${change.abs()}%',
            style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
    );
  }

  // Tavsiye kartı widget'ı
  Widget _buildAdviceCard(
    BuildContext context, {
    required String title,
    required String advice,
    required Color color,
    required IconData icon,
  }) {
    return InkWell(
      onTap: () {
        // Tıklanınca tüm metni göster
        _showAdviceDetail(context, title, advice, color, icon);
      },
      child: Container(
      padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: color,
        borderRadius: BorderRadius.circular(12),
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
        children: [
          Container(
                  width: 40,
                  height: 40,
            decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
                    icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                        title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                        advice,
                  style: const TextStyle(
                    color: Colors.white70,
                          fontSize: 14,
                  ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
            ),
            // Daha fazla oku göstergesi
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Detaylı Görüntüle",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tavsiye detayı dialog
  void _showAdviceDetail(BuildContext context, String title, String advice, Color color, IconData icon) {
    // Tutarlılık için aynı renk ve ikonları kullan - değiştirme
    final tavsiyeRengi = color;
    final tavsiyeIkonu = icon;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: tavsiyeRengi,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık ve ikon
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        tavsiyeIkonu,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // İçerik (Scrollable)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      advice,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Kapat butonu
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Kapat',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // İlişki Raporu Tab
  Widget _buildRelationshipReportTab(BuildContext context) {
    // Ekrandaki hata: Consumer kullanarak ReportViewModel içindeki değişimleri dinlemeliyiz
    return Consumer<ReportViewModel>(
      builder: (context, reportViewModel, _) {
        // İlişki puanını al (varsa)
        int? relationshipScore;
        if (reportViewModel.reportResult != null && reportViewModel.reportResult!.containsKey('relationship_type')) {
          final relationshipType = reportViewModel.reportResult!['relationship_type'] as String;
          relationshipScore = _calculateRelationshipScore(relationshipType);
          debugPrint('İlişki tipi: $relationshipType, Puan: $relationshipScore');
        } else {
          debugPrint('Rapor henüz oluşturulmamış');
        }
        
        return SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    FutureBuilder<User?>(
                      future: Future.value(FirebaseAuth.instance.currentUser),
                      builder: (context, snapshot) {
                        final displayName = snapshot.data?.displayName ?? 'Ziyaretçi';
                        return Text(
                          'Merhaba, $displayName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.white),
                      onPressed: () {
                        _showSettingsDialog(context);
                      },
                    ),
                  ],
                ),
              ),
              
              // Ana içerik
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF352269),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Başlık
                        const Text(
                          'İlişki Gelişim Raporu',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // İlişki Gelişim Görselleştirmesi - Emoji ve Dalga Animasyonu
                        SizedBox(
                          height: 250,
                          width: double.infinity,
                          child: Column(
                            children: [
                              // Emoji Göstergesi
                              const SizedBox(height: 16),
                              Text(
                                _getRelationshipEmoji(relationshipScore),
                                style: const TextStyle(fontSize: 80),
                              )
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .slide(begin: const Offset(0, -0.5), end: Offset.zero),
                              
                              const SizedBox(height: 20),
                              
                              // Dalga Animasyonu
                              SizedBox(
                                height: 80,
                                width: double.infinity,
                                child: relationshipScore != null
                                  ? _buildWaveAnimation(relationshipScore, const Color(0xFF9D3FFF))
                                  : Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF9D3FFF).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                              )
                              .animate()
                              .fadeIn(delay: 200.ms, duration: 600.ms),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // İlişki Değerlendirmesi Butonu
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), // Dikey padding artırıldı
                            decoration: BoxDecoration(
                              color: const Color(0xFF9D3FFF),
                              borderRadius: BorderRadius.circular(16), // Köşe yuvarlatma artırıldı
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF9D3FFF).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () {
                                _showRelationshipEvaluation(context);
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.favorite,
                                    color: Colors.white,
                                    size: 20, // İkon boyutu biraz artırıldı
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'İlişki Değerlendirmesi',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16, // Yazı boyutu artırıldı
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // İlişki değerlendirmesi özeti veya uyarı mesajı
                        Consumer<ReportViewModel>(
                          builder: (context, reportViewModel, _) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
                              ),
                              child: reportViewModel.hasReport
                                  ? Text(
                                      _getRelationshipSummary(reportViewModel),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    )
                                  : const Text(
                                      "Henüz bir ilişki değerlendirmesi yapılmadı.",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Alt kategoriler değişim oranları kaldırıldı
                        // _buildCategoryChangeRow('İletişim Kalitesi', 12, true),
                        // const SizedBox(height: 12),
                        // _buildCategoryChangeRow('Duygusal Bağ', 8, true),
                        // const SizedBox(height: 12),
                        // _buildCategoryChangeRow('Çatışma Çözümü', 15, true),
                        
                        // Kaldırılan yazılardan sonraki Spacer da kaldırıldı
                        const Spacer(flex: 1), // Bu satır kalabilir veya kaldırılabilir, tasarım tercihine bağlı
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms);
      },
    );
  }
  
  // İlişki tipini puana dönüştürme
  int _calculateRelationshipScore(String relationshipType) {
    final Map<String, int> typeScores = {
      'Güven Odaklı': 85,
      'Tutkulu': 75,
      'Uyumlu': 80,
      'Dengeli': 90,
      'Mesafeli': 60,
      'Kaçıngan': 50,
      'Endişeli': 55,
      'Çatışmalı': 40,
      'Kararsız': 60,
      'Gelişmekte Olan': 70,
      'Gelişmekte Olan, Güven Sorunları Olan': 65,
      'Sağlıklı': 95,
      'Zorlayıcı': 45,
      'Belirsiz': 65,
    };
    
    return typeScores[relationshipType] ?? 65;
  }
  
  // Kategori değişim satırını oluşturan yardımcı fonksiyon
  Widget _buildCategoryChangeRow(String title, int percentage, bool isIncrease) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
            color: Colors.white,
                fontSize: 16,
              ),
            ),
        Row(
              children: [
            Icon(
              isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
              color: isIncrease ? Colors.green : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 4),
                Text(
              '$percentage%',
              style: const TextStyle(
                color: Colors.white,
                    fontWeight: FontWeight.bold,
                fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
    );
  }
  
  // Tavsiye Kartı Tab
  Widget _buildAdviceCardTab(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // App Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                FutureBuilder<User?>(
                  future: Future.value(FirebaseAuth.instance.currentUser),
                  builder: (context, snapshot) {
                    final displayName = snapshot.data?.displayName ?? 'Ziyaretçi';
                    return Text(
                      'Merhaba, $displayName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    );
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  onPressed: () {
                    _showSettingsDialog(context);
                  },
                ),
              ],
            ),
          ),
          
          // Ana içerik
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                children: [
                  // Başlık, kalan sayısı ve yenile butonu
                  Row(
                    children: [
                      // Başlık
                      const Text(
                        'Günlük AI\nTavsiyesi',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const Spacer(),
                      
                      // Kalan tavsiye sayısı
                      const Text(
                        'Kalan:\n1/1',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(width: 16),
                      
                      // Yenile butonu
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            // Premium kontrolü
                            final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
                            if (!authViewModel.isPremium) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Bu özellik sadece premium kullanıcılar için kullanılabilir.'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              return;
                            }
                            _refreshDailyAdvice();
                          },
                          child: Row(
                            children: [
                              const Icon(
                                Icons.refresh,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Yenile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Tavsiye kartı
                  Container(
                    height: 500, // Bir yükseklik belirle, yoksa Expanded içindeki hata devam edebilir
                    child: Consumer<AdviceViewModel>(
                      builder: (context, adviceViewModel, child) {
                        if (adviceViewModel.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                        }
                        
                        if (adviceViewModel.errorMessage != null) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.white70,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Tavsiye yüklenirken bir sorun oluştu',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                TextButton(
                                  onPressed: _loadDailyAdvice,
                                  child: const Text(
                                    'Tekrar Dene',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        final advice = adviceViewModel.adviceCard;
                        
                        if (advice == null) {
                          return const Center(
                            child: Text(
                              'Henüz tavsiye bulunmuyor',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }
                        
                        final title = advice['title'] ?? 'İlişki Tavsiyesi';
                        final content = advice['content'] ?? 'Tavsiye içeriği bulunamadı.';
                        final category = advice['category'] ?? 'genel';
                        
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5DD3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Başlık ve simge
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.lightbulb_outline,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Tavsiye metni - Daha fazla alan kullanacak şekilde düzenlendi
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Text(
                                    content,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Premium buton - En alta sabitlendi
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF352269),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    // Sol kısım - Premium'a Geç
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF9D3FFF),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Icon(
                                                Icons.diamond,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Premium\'a Geç',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Sınırsız AI tavsiyesi al',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const Spacer(),
                                    
                                    // Sağ kısım - Yükselt butonu
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF9D3FFF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.diamond,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Yükselt',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms);
  }

  // Profil Tab
  Widget _buildProfileTab(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    return SafeArea(
      child: Column(
        children: [
          // App Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                FutureBuilder<User?>(
                  future: Future.value(FirebaseAuth.instance.currentUser),
                  builder: (context, snapshot) {
                    final displayName = snapshot.data?.displayName ?? 'Ziyaretçi';
                    return Text(
                      'Merhaba, $displayName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    );
                  },
                ),
                  const Spacer(),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () {},
                ),
                IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  onPressed: () {
                    _showSettingsDialog(context);
                  },
                ),
              ],
            ),
          ),
          
            // Ana içerik
          Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Profil Bilgileri
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                          color: Colors.white,
                              width: 3,
                            ),
                          ),
                      child: const CircleAvatar(
                            radius: 50,
                        backgroundColor: Color(0xFF352269),
                            child: Icon(
                              Icons.person,
                              size: 50,
                          color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<User?>(
                          future: Future.value(FirebaseAuth.instance.currentUser),
                          builder: (context, snapshot) {
                        final displayName = snapshot.data?.displayName ?? 'Zeynep';
                        final email = snapshot.data?.email ?? 'zeynep@example.com';
                            
                            return Column(
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                
                                // Premium durumu ve butonu
                                Consumer<AuthViewModel>(
                                  builder: (context, authViewModel, _) {
                                    final isPremium = authViewModel.isPremium;
                                    
                                    return Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isPremium 
                                                  ? const Color(0xFFFFD700).withOpacity(0.2)
                                                  : Colors.grey.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isPremium ? Icons.workspace_premium : Icons.workspace_premium_outlined,
                                                    color: isPremium ? const Color(0xFFFFD700) : Colors.grey,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isPremium ? 'Premium Üye' : 'Standart Üye',
                                                    style: TextStyle(
                                                      color: isPremium ? const Color(0xFFFFD700) : Colors.grey,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            
                                            if (!isPremium) ...[
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  // Premium yükseltme işlemi
                                                  final success = await authViewModel.upgradeToPremium();
                                                  
                                                  if (success && context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Premium üyeliğe yükseltildiniz!'),
                                                        backgroundColor: Color(0xFF4A2A80),
                                                      ),
                                                    );
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF9D3FFF),
                                                  foregroundColor: Colors.white,
                                                  minimumSize: const Size(0, 32),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                                ),
                                                child: const Text('Premium Ol'),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                    );
                                  },
                                ),
                                
                                Text(
                                  email,
                                  style: const TextStyle(
                                color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    const SizedBox(height: 32),
                    
                    // Profil Ayarları
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF352269),
                            borderRadius: BorderRadius.circular(16),
                          ),
                            child: Column(
              children: [
                          _buildProfileMenuItem(
                            icon: Icons.person,
                            title: 'Hesap Bilgileri',
                          ),
                          _buildProfileMenuItem(
                            icon: Icons.notifications,
                            title: 'Bildirim Ayarları',
                          ),
                          _buildProfileMenuItem(
                            icon: Icons.security,
                            title: 'Gizlilik ve Güvenlik',
                          ),
                          _buildProfileMenuItem(
                            icon: Icons.question_answer,
                            title: 'Yardım ve Destek',
                          ),
                          
                          // Yeni eklenen menü öğeleri
                          const Divider(color: Colors.white24, height: 32),
                          
                          _buildProfileMenuItem(
                            icon: Icons.analytics,
                            title: 'Geçmiş Analizler',
                          ),
                          _buildProfileMenuItem(
                            icon: Icons.assessment,
                            title: 'İlişki Raporları',
                          ),
                          
                          const Divider(color: Colors.white24, height: 32),
                          
                          // Çıkış butonu
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () async {
                              final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
                              
                              // Çıkış onayı sor
                              final shouldLogout = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF352269),
                                  title: const Text(
                                    'Çıkış Yapmak İstiyor musunuz?',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: const Text(
                                    'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text(
                                        'İptal',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text(
                                        'Çıkış Yap',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (shouldLogout == true) {
                                debugPrint('Çıkış yapılıyor...');
                                try {
                                  // Önce SharedPreferences'tan bilgileri temizle
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setBool('hasCompletedOnboarding', false);
                                  await prefs.remove('user_token');
                                  await prefs.remove('user_login_state');
                                  
                                  // Firebase Auth ile çıkış yap
                                  await authViewModel.signOut();
                                  
                                  if (context.mounted) {
                                    // Force kullanarak doğrudan onboarding sayfasına git
                                    context.go('/onboarding');
                                  }
                                } catch (e) {
                                  debugPrint('Çıkış yapma hatası: $e');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Çıkış yapma hatası: $e')),
                                    );
                                  }
                                }
                              }
                            },
                            icon: const Icon(
                              Icons.logout,
                              color: Colors.white70,
                            ),
                            label: const Text(
                              'Çıkış Yap',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                    // Çıkış Butonu kaldırıldı
                  ],
                  ),
                ),
              ),
            ),
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms);
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
  }) {
    return InkWell(
      onTap: () {
        debugPrint('Profil menü öğesine tıklandı: $title');
        // Menü öğesine göre dialog veya sayfa aç
        if (title == 'Hesap Bilgileri') {
          _showAccountSettingsDialog(context);
        } else if (title == 'Bildirim Ayarları') {
          _showNotificationSettingsDialog(context);
        } else if (title == 'Gizlilik ve Güvenlik') {
          _showPrivacySettingsDialog(context);
        } else if (title == 'Yardım ve Destek') {
          _showHelpSupportDialog(context);
        } else if (title == 'Geçmiş Analizler') {
          context.go('/past-analyses');
        } else if (title == 'İlişki Raporları') {
          context.go('/past-reports');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 16),
            Text(
              title, 
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  // Hesap Bilgileri Dialog
  void _showAccountSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF352269),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık ve Kapat Butonu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Hesap Bilgileri',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // İçerik - Örnek olarak bazı hesap ayarları
                const Text(
                  'Profil Bilgileri',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                
                const SizedBox(height: 10),
                
                FutureBuilder<User?>(
                  future: Future.value(FirebaseAuth.instance.currentUser),
                  builder: (context, snapshot) {
                    final displayName = snapshot.data?.displayName ?? 'İsimsiz Kullanıcı';
                    final email = snapshot.data?.email ?? '-';
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'İsim:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              'E-posta:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              email,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Kapat Butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D3FFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Kapat'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Bildirim Ayarları Dialog
  void _showNotificationSettingsDialog(BuildContext context) {
    bool pushBildirimAcik = true;
    bool emailBildirimAcik = true;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: const Color(0xFF352269),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık ve Kapat Butonu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bildirim Ayarları',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Push Bildirimleri
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Push Bildirimleri',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        Switch(
                          value: pushBildirimAcik,
                          onChanged: (value) {
                            setState(() {
                              pushBildirimAcik = value;
                            });
                          },
                          activeColor: const Color(0xFF9D3FFF),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // E-posta Bildirimleri
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'E-posta Bildirimleri',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        Switch(
                          value: emailBildirimAcik,
                          onChanged: (value) {
                            setState(() {
                              emailBildirimAcik = value;
                            });
                          },
                          activeColor: const Color(0xFF9D3FFF),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Kaydet Butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Bildirim ayarlarını kaydet
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bildirim ayarları kaydedildi')),
                          );
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9D3FFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Kaydet'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  // Gizlilik ve Güvenlik Dialog
  void _showPrivacySettingsDialog(BuildContext context) {
    bool hesapGizlilik = true;
    bool konum = false;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: const Color(0xFF352269),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık ve Kapat Butonu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Gizlilik ve Güvenlik',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Hesap Gizliliği
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Hesap Gizliliği',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        Switch(
                          value: hesapGizlilik,
                          onChanged: (value) {
                            setState(() {
                              hesapGizlilik = value;
                            });
                          },
                          activeColor: const Color(0xFF9D3FFF),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Konum Erişimi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Konum Erişimi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        Switch(
                          value: konum,
                          onChanged: (value) {
                            setState(() {
                              konum = value;
                            });
                          },
                          activeColor: const Color(0xFF9D3FFF),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Şifre Değiştir Butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Şifre değiştirme özelliği yakında eklenecek')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.white30),
                          ),
                        ),
                        child: const Text('Şifre Değiştir'),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Verileri Sıfırla Butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Önce mevcut diyaloğu kapat
                          _showResetConfirmationDialog(context); // Onay diyaloğunu göster
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Verileri Sıfırla'),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Kaydet Butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Gizlilik ayarlarını kaydet
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gizlilik ayarları kaydedildi')),
                          );
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9D3FFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Kaydet'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  // Yardım ve Destek Dialog
  void _showHelpSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF352269),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık ve Kapat Butonu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Yardım ve Destek',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Yardım Seçenekleri
                _buildHelpOption(
                  icon: Icons.help_outline,
                  title: 'Sık Sorulan Sorular',
                  onTap: () {
                    Navigator.of(context).pop();
                    _showFAQDialog(context);
                  },
                ),
                
                const SizedBox(height: 12),
                
                _buildHelpOption(
                  icon: Icons.email_outlined,
                  title: 'E-posta ile İletişim',
                  onTap: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('E-posta desteği: destek@flortai.com')),
                    );
                  },
                ),
                
                const SizedBox(height: 12),
                
                _buildHelpOption(
                  icon: Icons.feedback_outlined,
                  title: 'Geribildirim Gönder',
                  onTap: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Geribildirim özelliği yakında eklenecek')),
                    );
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Kapat Butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D3FFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Kapat'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Yardım Seçeneği Widget
  Widget _buildHelpOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Genel Ayarlar Dialog
  void _showSettingsDialog(BuildContext context) {
    bool bildirimlerAcik = true; // Varsayılan olarak açık
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: const Color(0xFF352269),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık ve Kapat Butonu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ayarlar',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Hesap Ayarları
                    _buildSettingsOption(
                      icon: Icons.person_outline,
                      title: 'Hesap Bilgileri',
                      onTap: () {
                        Navigator.of(context).pop();
                        _showAccountSettingsDialog(context);
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Bildirim Ayarları
                    _buildSettingsOption(
                      icon: Icons.notifications_outlined,
                      title: 'Bildirim Ayarları',
                      onTap: () {
                        Navigator.of(context).pop();
                        _showNotificationSettingsDialog(context);
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Gizlilik ve Güvenlik
                    _buildSettingsOption(
                      icon: Icons.security_outlined,
                      title: 'Gizlilik ve Güvenlik',
                      onTap: () {
                        Navigator.of(context).pop();
                        _showPrivacySettingsDialog(context);
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Yardım ve Destek
                    _buildSettingsOption(
                      icon: Icons.help_outline,
                      title: 'Yardım ve Destek',
                      onTap: () {
                        Navigator.of(context).pop();
                        _showHelpSupportDialog(context);
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Kapat Butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9D3FFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Kapat'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  // Ayarlar Seçeneği Widget
  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showRelationshipEvaluation(BuildContext context) {
    // İlişki değerlendirmesi için ReportView'a yönlendir
    context.push('/report');
  }

  // Kategori adını formatlama
  String _formatCategoryName(String category) {
    switch (category.toLowerCase()) {
      case 'iletisim':
        return 'İletişim';
      case 'guven':
        return 'Güven';
      case 'uyum':
        return 'Uyum';
      case 'saygi':
      case 'saygı':
        return 'Saygı';
      case 'destek':
        return 'Destek';
      default:
        return category;
    }
  }
  
  // Kategori açıklaması alma
  String _getCategoryDescription(String category, int score) {
    if (score >= 80) {
      switch (category.toLowerCase()) {
        case 'iletisim':
          return 'Mesajlaşma sıklığınız ve kalitesi oldukça iyi durumda.';
        case 'guven':
          return 'Partnerinizin size olan güveni çok yüksek seviyede.';
        case 'uyum':
          return 'İlişkinizde uyum seviyesi oldukça yüksek.';
        case 'saygi':
        case 'saygı':
          return 'Birbirinize karşı saygınız takdire değer seviyede.';
        case 'destek':
          return 'Partnerinize destek olma konusunda çok başarılısınız.';
        default:
          return 'Bu alanda oldukça başarılısınız.';
      }
    } else if (score >= 60) {
      switch (category.toLowerCase()) {
        case 'iletisim':
          return 'İletişiminiz iyi, ancak daha da geliştirilebilir.';
        case 'guven':
          return 'Güven seviyeniz iyi durumda, küçük gelişmeler yapabilirsiniz.';
        case 'uyum':
          return 'Uyumunuz iyi seviyede ama geliştirme alanları var.';
        case 'saygi':
        case 'saygı':
          return 'Karşılıklı saygı seviyeniz iyi, küçük iyileştirmeler yapabilirsiniz.';
        case 'destek':
          return 'Destek konusunda iyi durumdasınız, biraz daha geliştirebilirsiniz.';
        default:
          return 'Bu alanda iyi durumdasınız, ancak gelişme fırsatları var.';
      }
    } else if (score >= 40) {
      switch (category.toLowerCase()) {
        case 'iletisim':
          return 'İletişim alanında gelişime açık yönleriniz var.';
        case 'guven':
          return 'Güven konusunda gelişim göstermeniz gerekiyor.';
        case 'uyum':
          return 'Uyum seviyenizi artırmak için çalışmalar yapmanız faydalı olabilir.';
        case 'saygi':
        case 'saygı':
          return 'Saygı konusunda dikkate değer iyileştirmelere ihtiyacınız var.';
        case 'destek':
          return 'Destek alanında gelişim göstermeniz ilişkinize olumlu katkı sağlayacaktır.';
        default:
          return 'Bu alanda gelişime açık yönleriniz var.';
      }
    } else {
      switch (category.toLowerCase()) {
        case 'iletisim':
          return 'İletişim konusunda ciddi gelişime ihtiyacınız var.';
        case 'guven':
          return 'Güven seviyenizi artırmak için acilen çalışmalar yapmanız gerekiyor.';
        case 'uyum':
          return 'Uyum konusunda önemli sorunlar yaşıyorsunuz, profesyonel destek faydalı olabilir.';
        case 'saygi':
        case 'saygı':
          return 'Saygı alanında ciddi gelişime ihtiyacınız var.';
        case 'destek':
          return 'Destek konusunda önemli eksiklikler görülüyor, bu alan üzerinde çalışın.';
        default:
          return 'Bu alanda ciddi gelişime ihtiyacınız var.';
      }
    }
  }
  
  // Kategori rengi alma
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'iletisim':
        return const Color(0xFF6C5DD3);
      case 'guven':
        return const Color(0xFF4F8CF6);
      case 'uyum':
        return const Color(0xFFFF4FD8);
      case 'saygi':
      case 'saygı':
        return const Color(0xFFF79E1B);
      case 'destek':
        return const Color(0xFF8CCF4D);
      default:
        return const Color(0xFF9D3FFF);
    }
  }
  
  // Puan rengi alma
  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF8CCF4D); // Yeşil
    if (score >= 60) return const Color(0xFF4F8CF6); // Mavi
    if (score >= 40) return const Color(0xFFF79E1B); // Turuncu
    if (score >= 20) return const Color(0xFFFF7D05); // Koyu turuncu
    return const Color(0xFFFF3030); // Kırmızı
  }
  
  // Puan metni alma
  String _getScoreText(int score) {
    if (score >= 80) return 'Harika';
    if (score >= 60) return 'İyi';
    if (score >= 40) return 'Orta';
    if (score >= 20) return 'Zayıf';
    return 'Kritik';
  }
  
  // Tavsiye metninden sabit renk oluşturma - Koyu tonlar ve kategori bazlı renkler
  Color _getAdviceColor(String advice) {
    // Tavsiye metninden sabit bir hash değeri oluştur
    int hash = 0;
    for (var i = 0; i < advice.length; i++) {
      hash = advice.codeUnitAt(i) + ((hash << 5) - hash);
    }
    
    // Kategori bazlı koyu renkler - tavsiye türüne göre
    final categoryColors = {
      'iletişim': const Color(0xFF22577A),    // koyu mavi - iletişim
      'güven': const Color(0xFF5E548E),      // koyu mor - güven
      'sevgi': const Color(0xFF7D0633),      // koyu kırmızı - sevgi
      'aktivite': const Color(0xFF264653),   // koyu çam yeşili - aktiviteler
      'saygı': const Color(0xFF1B3A4B),      // koyu petrol mavisi - saygı
      'anlayış': const Color(0xFF3A506B),    // koyu mavi-gri - anlayış
      'denge': const Color(0xFF352F44),      // koyu mor-gri - denge
      'birlikte': const Color(0xFF2D4263),   // koyu indigo - birliktelik
      'paylaşım': const Color(0xFF2F4858),   // koyu lacivert - paylaşım
      'zaman': const Color(0xFF2D241A),      // koyu kahve - zaman
    };
    
    // Anahtar kelimeler ve kategori eşleştirmeleri
    final keywordCategoryMap = {
      'dinle': 'iletişim',
      'konuş': 'iletişim',
      'iletişim': 'iletişim',
      
      'güven': 'güven',
      'inan': 'güven',
      'dürüst': 'güven',
      
      'sevgi': 'sevgi',
      'aşk': 'sevgi',
      'sev': 'sevgi',
      
      'aktivite': 'aktivite',
      'etkinlik': 'aktivite',
      'yap': 'aktivite',
      
      'saygı': 'saygı',
      'değer': 'saygı',
      'kıymet': 'saygı',
      
      'anla': 'anlayış',
      'anlayış': 'anlayış',
      'empati': 'anlayış',
      
      'denge': 'denge',
      'ölçü': 'denge',
      'uyum': 'denge',
      
      'birlikte': 'birlikte',
      'beraber': 'birlikte',
      'biz': 'birlikte',
      
      'paylaş': 'paylaşım',
      'ortak': 'paylaşım',
      'paylaşım': 'paylaşım',
      
      'zaman': 'zaman',
      'vakit': 'zaman',
      'süre': 'zaman',
    };
    
    // Metni küçük harflere çevir
    final lowerAdvice = advice.toLowerCase();
    
    // Anahtar kelime ile kategori bul, varsa ilgili rengi döndür
    for (final entry in keywordCategoryMap.entries) {
      if (lowerAdvice.contains(entry.key)) {
        final category = entry.value;
        if (categoryColors.containsKey(category)) {
          return categoryColors[category]!;
        }
      }
    }
    
    // Hiç eşleşme yoksa, varsayılan koyu renk listesinden hash'e göre seç
    final defaultColors = [
      const Color(0xFF22577A),    // koyu mavi
      const Color(0xFF5E548E),    // koyu mor
      const Color(0xFF7D0633),    // koyu kırmızı
      const Color(0xFF264653),    // koyu çam yeşili
      const Color(0xFF1B3A4B),    // koyu petrol mavisi
    ];
    
    return defaultColors[hash.abs() % defaultColors.length];
  }
  
  // Tavsiye metninden sabit ikon oluşturma
  IconData _getAdviceIcon(String advice) {
    // Tavsiye metninden sabit bir hash değeri oluştur
    int hash = 0;
    for (var i = 0; i < advice.length; i++) {
      hash = advice.codeUnitAt(i) + ((hash << 5) - hash);
    }
    
    // Tavsiye kartları için anlamlı ikonlar
    final adviceIcons = [
      Icons.favorite, // sevgi
      Icons.people,   // ilişkiler
      Icons.schedule, // zaman
      Icons.psychology, // anlayış
      Icons.nightlight_round, // dinlenme
      Icons.emoji_emotions, // duygular
      Icons.celebration, // kutlama
      Icons.spa,      // rahatlama
      Icons.forum,    // konuşma
      Icons.directions_run, // aktivite
    ];
    
    // Anahtar kelimeler ve sabit ikonları eşleştiren harita
    final keywordIconMap = {
      'dinle': Icons.hearing,
      'iletişim': Icons.forum,
      'konuş': Icons.forum,
      'dürüst': Icons.verified,
      'açık': Icons.lock_open,
      'şeffaf': Icons.visibility,
      'güven': Icons.security,
      'inan': Icons.favorite,
      'zaman': Icons.schedule,
      'vakit': Icons.access_time,
      'aktivite': Icons.directions_run,
      'etkinlik': Icons.event,
      'sev': Icons.favorite,
      'aşk': Icons.favorite,
      'duygu': Icons.emoji_emotions,
      'anla': Icons.psychology,
      'anlayış': Icons.psychology,
      'empati': Icons.people,
      'paylaş': Icons.share,
      'ortak': Icons.group,
      'birlikte': Icons.group,
      'saygı': Icons.thumb_up,
      'değer': Icons.star,
      'denge': Icons.balance,
      'ölçü': Icons.straighten,
      'uyum': Icons.compare,
    };
    
    // Önce içeriği küçük harfe çevir
    final lowerAdvice = advice.toLowerCase();
    
    // Her anahtar kelimeyi kontrol et ve varsa sabit ikon döndür
    for (final entry in keywordIconMap.entries) {
      if (lowerAdvice.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Eşleşme yoksa, hash'e göre sabit bir ikon seç
    return adviceIcons[hash.abs() % adviceIcons.length];
  }
  
  // Tavsiye metninden sabit başlık oluşturma
  String _getTitleFromAdvice(String advice) {
    // Tavsiye metninden sabit bir hash değeri oluştur
    int hash = 0;
    for (var i = 0; i < advice.length; i++) {
      hash = advice.codeUnitAt(i) + ((hash << 5) - hash);
    }
    
    // Tavsiye kartları için sabit başlıklar
    final adviceTitles = [
      "İyi Dinle!",
      "Birlikte Büyü",
      "Bunu Dene",
      "Kendini Geliştir",
      "Şimdi Harekete Geç",
      "Bunu Bilmelisin",
      "Bu Senin İçin",
      "Bunu Hatırla",
      "İlişkini Güçlendir",
      "Mutluluğun Anahtarı",
    ];
    
    // Anahtar kelimeler ve sabit başlıkları eşleştiren harita
    final keywordTitleMap = {
      'dinle': "İletişimin Sırrı",
      'konuş': "Etkili İletişim",
      'iletişim': "İletişim Zamanı",
      'dürüst': "Dürüstlüğün Gücü",
      'açık': "Açıklık ve Şeffaflık",
      'paylaş': "Paylaşmanın Değeri",
      'güven': "Güven Gelişimi",
      'birlikte': "Birlikte Daha Güçlü",
      'ortak': "Ortaklık Zamanı",
      'sevgi': "Sevgi İlişkisi",
      'aşk': "Aşkın Dili",
      'sev': "Sevgiyi Göster",
      'anlayış': "Anlayış Geliştirme",
      'saygı': "Saygı ve Değer",
      'değer': "Değer Vermenin Önemi",
      'empati': "Empati Kurma",
      'denge': "Denge ve Uyum",
      'huzur': "İçsel Huzur",
      'plan': "Geleceği Planla",
      'zaman': "Zaman Yönetimi",
      'aktivite': "Aktif Yaşam",
    };
    
    // Önce içeriği küçük harfe çevir
    final lowerAdvice = advice.toLowerCase();
    
    // Her anahtar kelimeyi kontrol et ve varsa sabit başlık döndür
    for (final entry in keywordTitleMap.entries) {
      if (lowerAdvice.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Eşleşme yoksa, hash'e göre sabit bir başlık seç
    return adviceTitles[hash.abs() % adviceTitles.length];
  }

  // İlişki uyum emojisi belirleme
  String _getRelationshipEmoji(int? score) {
    if (score == null) return '🤔'; // Henüz analiz yapılmadıysa
    
    if (score >= 90) return '😊'; // 90-100 puan - mutlu emoji
    if (score >= 60) return '🙂'; // 60-89 puan - nötr emoji
    if (score >= 40) return '😟'; // 40-59 puan - endişeli emoji
    return '😢'; // 0-39 puan - üzgün emoji
  }
  
  // Dalga animasyonu oluşturma
  Widget _buildWaveAnimation(int score, Color baseColor) {
    // Dalga hareketinin ve yüksekliğinin puana göre ayarlanması
    final double waveFrequency = _getWaveFrequency(score);
    final double waveHeight = _getWaveHeight(score);
    
    // Skora göre renk değiştirme
    final Color waveColor = _getWaveColor(score);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AnimatedWave(
        color: waveColor,
        frequency: waveFrequency,
        amplitude: waveHeight,
      ),
    );
  }
  
  // Dalga rengini puana göre ayarlama
  Color _getWaveColor(int score) {
    if (score >= 90) return const Color(0xFF9D3FFF); // Mor - En iyi puan
    if (score >= 60) return const Color(0xFF7B68EE); // Lavanta
    if (score >= 40) return const Color(0xFFFF6B6B); // Turuncu-Kırmızı
    return const Color(0xFFFF4500);  // Kırmızı - En düşük puan
  }
  
  // Dalga frekansını puana göre ayarlama (düşük puan = daha hızlı ve düzensiz dalga)
  double _getWaveFrequency(int score) {
    if (score >= 90) return 0.03; // 90-100 puan - Çok sakin, yavaş dalga
    if (score >= 60) return 0.06; // 60-89 puan - Orta hızda dalga
    if (score >= 40) return 0.10; // 40-59 puan - Hızlı dalga
    return 0.15; // 0-39 puan - Çok hızlı ve düzensiz dalga
  }
  
  // Dalga yüksekliğini puana göre ayarlama (düşük puan = daha yüksek dalga)
  double _getWaveHeight(int score) {
    if (score >= 90) return 4;  // 90-100 puan - Çok düşük, yumuşak dalga
    if (score >= 60) return 8;  // 60-89 puan - Orta yükseklikte dalga
    if (score >= 40) return 12; // 40-59 puan - Yüksek dalga
    return 18; // 0-39 puan - Çok yüksek, sert ve düzensiz dalga
  }

  // SSS Diyaloğu
  void _showFAQDialog(BuildContext context) {
    // SSS içeriği
    final List<Map<String, String>> faqItems = [
      {
        'soru': 'Bu uygulama ne işe yarar?',
        'cevap': 'Uygulama, ilişkiniz hakkında geri bildirim almanızı ve kendinizi geliştirme alanlarınızı keşfetmenizi sağlar.'
      },
      {
        'soru': 'İlişki analizi nasıl çalışıyor?',
        'cevap': 'Analizleriniz, verdiğiniz yanıtlara göre değerlendirilir ve çeşitli ilişki boyutlarında (destek, güven, iletişim, saygı, uyum) bir uyum puanı oluşturulur.'
      },
      {
        'soru': 'Analizlerimi kimse görebilir mi?',
        'cevap': 'Hayır, analiz sonuçlarınız gizlidir ve sadece size özeldir.'
      },
      {
        'soru': 'Sonuçlar ne kadar güvenilir?',
        'cevap': 'Sunulan içerikler, verdiğiniz cevaplara göre oluşturulan genel önerilerdir. Son karar ve değerlendirme her zaman size aittir.'
      },
      {
        'soru': 'Uygulama partnerimle olan mesajlarımı analiz edebilir mi?',
        'cevap': 'Eğer bir ekran görüntüsü ya da metin sağlarsanız, bu içerik üzerinden yorum yapılabilir.'
      },
      {
        'soru': 'Aynı soruları tekrar cevaplayabilir miyim?',
        'cevap': 'Evet, dilediğiniz zaman yeni bir analiz yaparak gelişimi takip edebilirsiniz.'
      },
      {
        'soru': 'Analiz geçmişimi silebilir miyim?',
        'cevap': 'Evet. Ayarlar menüsünden analiz geçmişinizi silebilirsiniz.'
      },
      {
        'soru': 'Bu uygulama bir ilişki terapisti yerine geçer mi?',
        'cevap': 'Hayır. Uygulama destekleyici bilgiler sunar ama profesyonel danışmanlık hizmeti yerine geçmez.'
      },
    ];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Color(0xFF352269),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Üst kısım - başlık ve kapat butonu
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sık Sorulan Sorular',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Yasal uyarı notu
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Text(
                      "ℹ️",
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Not: Uygulamada sunulan içerikler yol gösterici niteliktedir, bağlayıcı değildir.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // SSS içeriği
              Expanded(
                child: ListView.builder(
                  itemCount: faqItems.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemBuilder: (context, index) {
                    return _buildFAQItem(faqItems[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // SSS Öğesi
  Widget _buildFAQItem(Map<String, String> item) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isExpanded = false;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(
                item['soru']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  isExpanded = expanded;
                });
              },
              collapsedIconColor: Colors.white70,
              iconColor: const Color(0xFF9D3FFF),
              collapsedBackgroundColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item['cevap']!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Kullanıcı verilerini temizle
  Future<void> _clearUserData(BuildContext context) async {
    try {
      // Tüm view modelleri ve controlleri al
      final profileViewModel = Provider.of<ProfileViewModel>(context, listen: false);
      final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
      final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
      final homeController = Provider.of<HomeController>(context, listen: false);
      
      // İşlem onayını al
      final shouldContinue = await FeedbackUtils.showConfirmationDialog(
        context,
        title: 'Veriler Silinecek',
        message: 'Tüm analiz verileriniz silinecek. Bu işlem geri alınamaz. Devam etmek istiyor musunuz?',
      );
      
      if (!shouldContinue) return;
      
      // Toast bildirim göster
      FeedbackUtils.showToast(context, 'Veriler temizleniyor...');
      
      // Firestore'daki verileri temizle
      final result = await profileViewModel.clearUserAnalysisData();
      
      if (!result) {
        FeedbackUtils.showErrorFeedback(context, 'Veriler temizlenirken bir hata oluştu');
        return;
      }
      
      // Yerel verileri temizle
      reportViewModel.resetReport();
      messageViewModel.clearCurrentMessage();
      homeController.resetAnalizVerileri();
      
      // Başarı mesajı göster
      FeedbackUtils.showSuccessFeedback(context, 'Tüm veriler başarıyla temizlendi');
    } catch (e) {
      FeedbackUtils.showErrorFeedback(context, 'Hata: $e');
    }
  }

  // Bildirim ayarlarını kaydet
  Future<void> _saveNotificationSettings() async {
    try {
      // Ayarlar kaydedildiğinde geri bildirim göster
      Navigator.of(context).pop(); // Ayarlar dialogunu kapat
      FeedbackUtils.showToast(context, 'Bildirim ayarları kaydedildi');
    } catch (e) {
      FeedbackUtils.showErrorFeedback(context, 'Ayarlar kaydedilirken hata oluştu');
    }
  }

  // Şifre değiştirme (henüz uygulanmamış)
  void _changePassword() {
    FeedbackUtils.showInfoDialog(
      context,
      title: 'Yakında',
      message: 'Şifre değiştirme özelliği yakında eklenecek.',
    );
  }
} 

// Sınıf sonu

// Animasyonlu dalga widget'ı
class AnimatedWave extends StatefulWidget {
  final Color color;
  final double frequency;
  final double amplitude;

  const AnimatedWave({
    super.key, 
    required this.color,
    required this.frequency,
    required this.amplitude,
  });

  @override
  State<AnimatedWave> createState() => _AnimatedWaveState();
}

class _AnimatedWaveState extends State<AnimatedWave> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Animasyon kontrolcüsü oluşturma
    _controller = AnimationController(
      vsync: this,
      // İlişki puanına göre farklı hızda hareket eden animasyon
      duration: Duration(milliseconds: (3000 / widget.frequency).round()),
    );

    // Sürekli tekrarlayan animasyon
    _animation = Tween<double>(begin: 0, end: 2 * pi).animate(_controller);
    
    // Animasyonu başlat
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: WavePainter(
            color: widget.color,
            frequency: widget.frequency,
            amplitude: widget.amplitude,
            phase: _animation.value,
          ),
          size: Size.infinite,
          child: Container(),
        );
      },
    );
  }
}

// Dalga animasyonu çizici sınıfı
class WavePainter extends CustomPainter {
  final Color color;
  final double frequency;
  final double amplitude;
  final double phase;

  WavePainter({
    required this.color,
    required this.frequency,
    required this.amplitude,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final path = Path();
    final width = size.width;
    final height = size.height;
    
    // Yol başlangıcı
    path.moveTo(0, height / 2);
    
    // Dalgalı çizgiyi oluşturma
    for (double i = 0; i <= width; i++) {
      // Sinüs dalgasını kullanarak dalgayı çiz
      // Farklı frekans ve genlik değerleri farklı dalga desenleri oluşturur
      // phase değeri, dalgayı hareket ettirmek için kullanılır
      final y = height / 2 + 
              amplitude * sin((i * frequency) + phase * 10) +
              (amplitude / 2) * sin((i * frequency * 2) + phase * 15);
      
      path.lineTo(i, y);
    }
    
    // Yolun altını kapat
    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();
    
    // Dalgalı alanı doldur
    canvas.drawPath(path, paint);
    
    // Dalga çizgisini de çiz (daha kalın ve belirgin)
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    final linePath = Path();
    linePath.moveTo(0, height / 2);
    
    for (double i = 0; i <= width; i++) {
      final y = height / 2 + 
              amplitude * sin((i * frequency) + phase * 10) +
              (amplitude / 2) * sin((i * frequency * 2) + phase * 15);
      
      linePath.lineTo(i, y);
    }
    
    canvas.drawPath(linePath, strokePaint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => 
      oldDelegate.phase != phase ||
      oldDelegate.frequency != frequency ||
      oldDelegate.amplitude != amplitude ||
      oldDelegate.color != color;
}

