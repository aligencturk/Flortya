import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui'; // ImageFilter için gerekli import
import 'dart:convert'; // jsonEncode için gerekli
import 'package:flutter/foundation.dart'; // compute fonksiyonu için gerekli
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/message_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../viewmodels/advice_viewmodel.dart';
import '../viewmodels/report_viewmodel.dart';
import '../controllers/home_controller.dart';
import '../app_router.dart';
import '../views/message_coach_view.dart';
import '../services/relationship_access_service.dart';
import '../views/report_view.dart';
import '../services/ad_service.dart';
import '../views/conversation_summary_view.dart';
import '../services/ai_service.dart';
import '../services/event_bus_service.dart';
import 'dart:async';

// String için extension - capitalizeFirst metodu
extension StringExtension on String {
  String get capitalizeFirst => length > 0 
      ? '${this[0].toUpperCase()}${substring(1)}'
      : '';
}

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
  List<String> _unlockedAdvices = []; // Kilidini açtığımız tavsiyeler
  // Wrapped analizlerini tutmak için liste
  List<Map<String, dynamic>> _wrappedAnalyses = [];
  
  // Widget referans anahtarları
  final GlobalKey _analyzeButtonKey = GlobalKey(debugLabel: 'AnalyzeButtonKey');
  final GlobalKey _relationshipScoreCardKey = GlobalKey(debugLabel: 'RelationshipScoreCardKey');
  final GlobalKey _categoryAnalysisKey = GlobalKey(debugLabel: 'CategoryAnalysisKey');
  final GlobalKey _relationshipEvaluationKey = GlobalKey(debugLabel: 'RelationshipEvaluationKey');
  final GlobalKey _analyzeCardKey = GlobalKey(debugLabel: 'AnalyzeCardKey');
  final GlobalKey _startEvaluationButtonKey = GlobalKey(debugLabel: 'StartEvaluationButtonKey');
  
  bool _hesapBilgileriAcik = false;
  bool _isProfileDataLoaded = false; // Profil verilerinin yüklenip yüklenmediğini takip eden bayrak
  final RelationshipAccessService _relationshipAccessService = RelationshipAccessService();
  
  // Late olarak tanımlanan değişkeni nullable olarak değiştiriyorum
  StreamSubscription? _eventBusSubscription;
  
  @override
  void initState() {
    super.initState();
    // Başlangıç sekmesini widget'tan al
    _selectedIndex = widget.initialTabIndex;
    _pageController = PageController(initialPage: _selectedIndex);
    
    // Event bus'ı dinle - wrapped hikayeleri sıfırlama için
    try {
      final EventBusService eventBus = EventBusService();
      _eventBusSubscription = eventBus.eventStream.listen((event) {
        if (event == AppEvents.resetWrappedStories) {
          resetWrappedData();
        } else if (event == AppEvents.refreshHomeData) {
          // Microtask döngüsünü ve UI hatalarını önlemek için gecikme ekle
          // ve sadece widget bağlıysa işlem yap
          if (mounted) {
            Future.delayed(Duration(milliseconds: 800), () {
              if (mounted) {
                debugPrint('refreshHomeData olayı alındı - Wrapped analizlerini yeniliyorum');
                _loadWrappedAnalyses();
                
                // UI güncellemesi için setState çağır
                setState(() {});
              }
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Event bus dinleyicisi oluşturulamadı: $e');
    }
    
    // Ağır yükleme işlemlerini geciktir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ana UI gösterildiğinde hafif işlemleri yap
      _loadInitialUIData();
      
      // Ağır işlemleri arka planda ve kademeli olarak gerçekleştir
      _loadHeavyDataInBackground();
    });
  }
  
  // Önce hızlıca UI için kritik verileri yükle
  void _loadInitialUIData() {
    // Açılmış tavsiyeleri yükle (hafif işlem)
    _loadUnlockedAdvices();
    
    // Wrapped analizlerini yükle (hafif işlem)
    _loadWrappedAnalyses();
  }
  
  // Ağır işlemleri arka planda ve kademeli olarak yükle
  Future<void> _loadHeavyDataInBackground() async {
    try {
      // Her bir ağır işlemi ayrı mikro görevlere böl
      await Future.microtask(() async {
        await _initializePageData();
      });
      
      // Diğer gecikmeli yüklenen veriler için bekleme süresi ekle
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadSecondaryData();
        }
      });
    } catch (e) {
      debugPrint('Arka plan veri yükleme hatası: $e');
    }
  }
  
  // İkincil verileri yükle (kritik olmayan veriler)
  Future<void> _loadSecondaryData() async {
    try {
      // Burada analiz geçmişi, kategori değişimleri gibi ekstra veriler yüklenebilir
      final homeController = Provider.of<HomeController>(context, listen: false);
      await Future.microtask(() async {
        try {
          homeController.anaSayfayiGuncelle();
        } catch (e) {
          debugPrint('HomeController.anaSayfayiGuncelle hatası: $e');
        }
      });
    } catch (e) {
      debugPrint('İkincil veri yükleme hatası: $e');
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Premium durum değişikliğinde tavsiyeleri tekrar yükle
    try {
      final authViewModel = Provider.of<AuthViewModel>(context);
      // Premium durumu değiştiğinde tavsiyeleri yeniden yükle
      _loadUnlockedAdvices();
        } catch (e) {
      debugPrint('didChangeDependencies hata: $e');
    }
  }
  
  // Açılmış tavsiyeleri yükle
  Future<void> _loadUnlockedAdvices() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Önce premium durumunu kontrol et
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    if (isPremium) {
      // Premium kullanıcı için tüm tavsiyeler açık
      debugPrint('Premium kullanıcı: Tüm tavsiyeler açık');
      setState(() {
        // Premium kullanıcılar için özel bir değer kullanarak hepsinin açık olduğunu belirtelim
        _unlockedAdvices = ["premium_all_unlocked"];
      });
    } else {
      // Premium olmayan kullanıcılar için kaydedilmiş açık tavsiyeleri yükle
      setState(() {
        _unlockedAdvices = prefs.getStringList('unlockedAdvices') ?? [];
      });
    }
  }
  
  // Wrapped analizlerini yüklemek için yeni metod
  Future<void> _loadWrappedAnalyses() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? wrappedAnalysesJson = prefs.getString('wrappedAnalysesList');
      
      // Önce önbellekte cachedWrappedData varsa, analiz oluşturup listeye ekleyelim
      final String? cachedWrappedData = prefs.getString('wrappedCacheData');
      
      // Wrapped analiz listemiz
      List<Map<String, dynamic>> wrappedList = [];
      
      // Kaydedilmiş wrapped analizleri yükle
      if (wrappedAnalysesJson != null && wrappedAnalysesJson.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(wrappedAnalysesJson);
        wrappedList = List<Map<String, dynamic>>.from(
          decodedList.map((item) => Map<String, dynamic>.from(item))
        );
        debugPrint('Kaydedilmiş ${wrappedList.length} wrapped analizi yüklendi');
      } else {
        debugPrint('Kaydedilmiş wrapped analizi bulunamadı');
      }
      
      // Eğer önbellekte cachedWrappedData varsa ve listeye henüz eklenmemişse
      // otomatik olarak wrapped analizi oluşturup ekleyelim
      if (cachedWrappedData != null && cachedWrappedData.isNotEmpty) {
        // Önbellekte wrapped analizi var mı kontrol et
        bool hasWrappedCacheInList = wrappedList.any((item) => item['dataRef'] == 'wrappedCacheData');
        
        if (!hasWrappedCacheInList) {
          try {
            // Otomatik olarak wrapped analizi ekleyelim
            final String newId = DateTime.now().millisecondsSinceEpoch.toString();
            final newAnalysis = {
              'id': newId,
              'title': 'Wrapped',
              'date': DateTime.now().toIso8601String(),
              'dataRef': 'wrappedCacheData',
            };
            
            wrappedList.add(newAnalysis);
            
            // SharedPreferences'a kaydet
            await prefs.setString('wrappedAnalysesList', jsonEncode(wrappedList));
            debugPrint('Wrapped analizi otomatik olarak oluşturuldu ve listeye eklendi');
          } catch (e) {
            debugPrint('Otomatik wrapped analizi oluştururken hata: $e');
          }
        }
      }
      
      // State'i güncelle
      setState(() {
        _wrappedAnalyses = wrappedList;
      });
    } catch (e) {
      debugPrint('Wrapped analizleri yüklenirken hata: $e');
    }
  }
  
  // Yeni bir wrapped analizi kaydetmek için metod
  Future<void> _saveWrappedAnalysis(Map<String, dynamic> analysis) async {
    try {
      // Aynı ID'ye sahip analiz var mı kontrol et
      final existingIndex = _wrappedAnalyses.indexWhere(
        (item) => item['id'] == analysis['id']
      );
      
      if (existingIndex >= 0) {
        // Varsa güncelle
        setState(() {
          _wrappedAnalyses[existingIndex] = analysis;
        });
      } else {
        // Yoksa ekle
        setState(() {
          _wrappedAnalyses.add(analysis);
        });
      }
      
      // SharedPreferences'a kaydet
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('wrappedAnalysesList', jsonEncode(_wrappedAnalyses));
      
      debugPrint('Wrapped analizi kaydedildi, toplam: ${_wrappedAnalyses.length}');
      
      // Ana sayfaya geri dön ve tüm wrapped'ları göstermek için setState çağır
      if (mounted) {
        setState(() {
          // UI'ı yenile
        });
      }
    } catch (e) {
      debugPrint('Wrapped analizi kaydedilirken hata: $e');
    }
  }
  
  // Sayfa verilerini güvenli bir şekilde yükle
  Future<void> _initializePageData() async {
    if (!mounted) return;
    
    try {
      // Premium mesaj kontrolü yap
      final showPremiumMessage = GoRouter.of(context).routeInformationProvider.value
          .uri.queryParameters['showPremiumMessage'] == 'true';
      
      if (showPremiumMessage && _selectedIndex == 3) { // Profil sayfasındaysa mesajı göster
        await Future.microtask(() {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bu özellik sadece Premium üyelere özeldir'),
                duration: Duration(seconds: 3),
                backgroundColor: Colors.deepPurple,
              ),
            );
          }
        });
      }
      
      // ProfileViewModel ve MessageViewModel işlemlerini asenkron olarak ve ayrı ayrı gerçekleştir
      await Future.microtask(() async {
        try {
          if (!mounted) return;
          final profileViewModel = Provider.of<ProfileViewModel>(context, listen: false);
          profileViewModel.setContext(context);
        } catch (e) {
          debugPrint('ProfileViewModel hatası: $e');
        }
      });
      
      await Future.microtask(() async {
        try {
          if (!mounted) return;
          final profileViewModel = Provider.of<ProfileViewModel>(context, listen: false);
          final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
          messageViewModel.setProfileViewModel(profileViewModel);
        } catch (e) {
          debugPrint('MessageViewModel hatası: $e');
        }
      });
      
      // Analiz sayılarını yükle - arka planda
      await Future.microtask(() async {
        try {
          if (!mounted) return;
          final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
          final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
          
          if (authViewModel.user != null) {
            try {
              // Bu işlemi arka planda yap
              await compute<String, void>(
                _loadAnalysisCountIsolate, 
                authViewModel.user!.id
              ).catchError((e) {
                // Compute başarısız olursa normal metodu kullan
                adviceViewModel.loadAnalysisCount(authViewModel.user!.id);
              });
            } catch (e) {
              debugPrint('Analiz sayısı yüklenirken hata: $e');
            }
          }
        } catch (e) {
          debugPrint('AuthViewModel veya AdviceViewModel hatası: $e');
        }
      });
    } catch (e) {
      // Hata durumunda sessizce devam et, UI'nin çökmemesi için
      debugPrint('Ana sayfa verilerini yüklerken hata: $e');
    }
  }
  
  // Analiz sayısını yüklemek için isolate fonksiyonu
  static Future<void> _loadAnalysisCountIsolate(String userId) async {
    // Bu kısımda isolate içinde çalışacağı için direkt AdviceViewModel'e erişemeyiz
    // Bu nedenle burada sadece userId gösteriyoruz, gerçek implementasyonda
    // bu kısım uygulamanın mimarisine göre değişecektir
    debugPrint('Analiz sayısı yükleniyor (isolate): $userId');
    // Gerçek durumda burada veritabanı işlemleri yapılır
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _eventBusSubscription?.cancel();
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
              label: 'Mesaj Koçu',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms);
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
                      context.push('/settings');
                    },
                  ),
                ],
              ),
            ),
            
            // Analiz Et Butonu ve Wrapped Hikaye Kutusu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // "Hikayen" butonu yerine "Yeni Analiz Başlat" butonu (sol tarafa hizalı)
                      InkWell(
                        key: _analyzeButtonKey, // Rehber için anahtar ekle
                        onTap: () {
                          // Analiz sayfasına yönlendir
                          messageViewModel.clearCurrentMessage();
                          context.push(AppRouter.messageAnalysis);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Yuvarlak logo ikonu
                            Stack(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.auto_awesome,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                                // Sağ alt köşede "+" ikonu
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF4A2A80),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.add,
                                        color: Color(0xFF4A2A80),
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // "Yeni Analiz Başlat" yazısı
                            const Text(
                              'Yeni Analiz Başlat',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 12), // Buton ile wrapped daireleri arasında boşluk
                      
                      // Ana sayfada ilişki özeti dairesi - sadece wrapped analizi varsa göster
                      Expanded(
                        child: Visibility(
                          visible: _wrappedAnalyses.isNotEmpty,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'İlişki Özetiniz',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Hikaye tarzı daire ile wrapped özetini göster
                              Row(
                                children: [
                                  if (_wrappedAnalyses.isNotEmpty)
                                    _buildWrappedCircle(context, _wrappedAnalyses.first),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tavsiyeler.length,
                        itemBuilder: (context, index) {
                          // Premium durumunu kontrol et
                          final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
                          final isPremium = authViewModel.isPremium;
                          
                          // Premium kullanıcılar için tüm içerikler açık, 
                          // Premium olmayan kullanıcılar için ilk tavsiye ücretsiz, diğerleri kilitli (eğer açılmadıysa)
                          final bool isLocked = !isPremium && index > 0 && 
                            !_unlockedAdvices.contains(index.toString()) && 
                            !_unlockedAdvices.contains("premium_all_unlocked");
                          
                          return _buildAdviceCard(
                            context, 
                            title: _getTitleFromAdvice(tavsiyeler[index]),
                            advice: tavsiyeler[index],
                            color: _getAdviceColor(tavsiyeler[index]),
                            icon: _getAdviceIcon(tavsiyeler[index]),
                            isLocked: isLocked,
                            index: index,
                          );
                        },
                      )
                    else if (analizSonucu != null && tavsiyeler.isEmpty)
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
                              Icons.info_outline,
                              color: Colors.amber.withOpacity(0.7),
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tavsiyeler oluşturulamadı. Lütfen yeni bir analiz yapın.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Görsel yükleme, metin analizi veya danışma bölümünden analiz yaparak kişiselleştirilmiş tavsiyeler alabilirsiniz.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
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
                              'Kişiselleştirilmiş tavsiyeler için analiz yapmanız gerekiyor',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Mesaj Analizi, Görsel Yükleme veya Danışma bölümünden bir analiz yaparak tavsiyeler alabilirsiniz',
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
                      key: _startEvaluationButtonKey, // Rehber için anahtar ekle
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
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              width: double.infinity,
              color: Colors.white.withOpacity(0.2),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: Container(
                  color: color,
                ),
              ),
            ),
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
    required bool isLocked,
    required int index,
  }) {
    // Premium durumunu kontrol et
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    // Premium kullanıcıları için tüm tavsiyeleri kilitsiz göster
    final bool actuallyLocked = isPremium ? false : isLocked;
    
    return InkWell(
      key: ValueKey('advice_card_$index'),
      onTap: () {
        // Kilit durumuna göre işlem yap
        if (actuallyLocked) {
          _showAdvertisementDialog(context, title, advice, color, icon, index);
        } else {
          // Kilitli değilse detayları göster
          _showAdviceDetail(context, title, advice, color, icon);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Ana içerik - Kilitli ise bulanık göster
            Opacity(
              opacity: actuallyLocked ? 0.7 : 1.0, // Kilitliyse hafif saydam
              child: ImageFiltered(
                imageFilter: actuallyLocked 
                  ? ImageFilter.blur(sigmaX: 3, sigmaY: 3) // Kilitliyse bulanık
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0), // Kilitli değilse normal
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
            ),
            
            // Kilit ikonu ve etiket (sadece kilitliyse göster)
            if (actuallyLocked)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        "Reklam İzleyerek Aç",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
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
  
  // Reklam izleme diyaloğunu göster
  void _showAdvertisementDialog(BuildContext context, String title, String advice, Color color, IconData icon, int index) {
    showDialog(
      context: context,
      barrierDismissible: false, // Dışarı tıklayarak kapatılamaz
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF352269),
          title: const Text(
            "Premium İçerik",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_outline,
                color: Colors.amber,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                "Bu kişiselleştirilmiş tavsiyeyi açmak için kısa bir reklam izlemeniz gerekiyor.",
                style: TextStyle(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Diyaloğu kapat
              },
              child: const Text(
                "İptal",
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Diyaloğu kapat
                _simulateAdvertisement(context, title, advice, color, icon, index);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D3FFF),
              ),
              child: const Text(
                "Reklam İzle",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // Reklam izleme simülasyonu
  void _simulateAdvertisement(BuildContext context, String title, String advice, Color color, IconData icon, int index) {
    // Yükleniyor diyaloğu
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext loadingContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF352269),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D3FFF)),
              ),
              const SizedBox(height: 16),
              const Text(
                "Reklam yükleniyor...",
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
    
    // AdService kullanarak reklam göster
    AdService.loadRewardedAd(() {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Yükleme diyaloğunu kapat
      
      // Tavsiyeyi kaydet
      _unlockAdvice(index);
      
      // Başarı mesajı
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tavsiye başarıyla açıldı! Artık bu tavsiyeyi istediğiniz zaman görüntüleyebilirsiniz."),
          backgroundColor: Color(0xFF4A2A80),
          duration: Duration(seconds: 3),
        ),
      );
      
      // Tavsiye detayını göster
      if (context.mounted) {
        _showAdviceDetail(context, title, advice, color, icon);
      }
    });
  }
  
  // Tavsiyeyi kilitsiz hale getir (SharedPreferences ile)
  Future<void> _unlockAdvice(int index) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Premium kontrolü yap
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    if (isPremium) {
      // Premium kullanıcı zaten tüm içeriklere erişebilir, bir şey yapmaya gerek yok
      setState(() {
        if (!_unlockedAdvices.contains("premium_all_unlocked")) {
          _unlockedAdvices.add("premium_all_unlocked");
        }
      });
      return;
    }
    
    // Premium olmayan kullanıcılar için açılmış tavsiyelerin listesini al
    final List<String> unlockedAdvices = prefs.getStringList('unlockedAdvices') ?? [];
    
    // Bu tavsiye daha önce açılmamışsa ekle
    if (!unlockedAdvices.contains(index.toString())) {
      unlockedAdvices.add(index.toString());
      await prefs.setStringList('unlockedAdvices', unlockedAdvices);
    }
    
    // UI'ı güncelle
    setState(() {
      _unlockedAdvices = unlockedAdvices;
    });
  }

  // Tavsiye detayı dialog
  void _showAdviceDetail(BuildContext context, String title, String advice, Color color, IconData icon) {
    // Tutarlılık için aynı renk ve ikonları kullan - değiştirme
    final tavsiyeRengi = color;
    final tavsiyeIkonu = icon;
    
    showDialog(
      context: context,
      builder: (BuildContext detailContext) {
        return Dialog(
          key: ValueKey('advice_detail_dialog_${title.hashCode}'),
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
                      onTap: () => Navigator.of(detailContext).pop(),
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
                    maxHeight: MediaQuery.of(detailContext).size.height * 0.5,
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
                        context.push('/settings');
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
                              Consumer<ReportViewModel>(
                                builder: (context, reportViewModel, _) {
                                  int? score;
                                  if (reportViewModel.reportResult != null && 
                                      reportViewModel.reportResult!.containsKey('relationship_type')) {
                                    final relationshipType = reportViewModel.reportResult!['relationship_type'] as String;
                                    score = _calculateRelationshipScore(relationshipType);
                                  }
                                  return Text(
                                    _getRelationshipEmoji(score),
                                    style: const TextStyle(fontSize: 80),
                                  )
                                  .animate()
                                  .fadeIn(duration: 600.ms)
                                  .slide(begin: const Offset(0, -0.5), end: Offset.zero);
                                }
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Dalga Animasyonu
                              Consumer<ReportViewModel>(
                                builder: (context, reportViewModel, _) {
                                  int? score;
                                  if (reportViewModel.reportResult != null && 
                                      reportViewModel.reportResult!.containsKey('relationship_type')) {
                                    final relationshipType = reportViewModel.reportResult!['relationship_type'] as String;
                                    score = _calculateRelationshipScore(relationshipType);
                                  }
                                  return _buildWaveAnimation(score, const Color(0xFF9D3FFF));
                                }
                              ),
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
                        
                        // Raporu Gör butonu
                        Consumer<ReportViewModel>(
                          builder: (context, reportViewModel, _) {
                            return Visibility(
                              visible: reportViewModel.hasReport,
                              child: Center(
                                child: Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      // Rapor sayfasına yönlendir
                                      context.push('/report');
                                    },
                                    icon: const Icon(Icons.visibility),
                                    label: const Text(
                                      'Raporu Görüntüle',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF9D3FFF),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        
                        // Spacer
                        const Spacer(flex: 1),
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

  // Tavsiye Kartı Tab
  Widget _buildAdviceCardTab(BuildContext context) {
    return const MessageCoachView();
  }
  
  // Profil Tab
  Widget _buildProfileTab(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    // Profil sayfası açıldığında kullanıcı bilgilerini sadece bir kez güncelle
    // Bu değişkeni sınıf değişkeni olarak tanımlamamız gerekli
    if (!_isProfileDataLoaded) {
      // Bu işlemi sadece bir kez yapmak için bayrak kullanıyoruz
      _isProfileDataLoaded = true;
      // Bir kez çağrıldıktan sonra, artık her rebuild'de çağrılmayacak
      Future.microtask(() => authViewModel.refreshUserData());
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
                    context.push('/settings');
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
                                                  // Premium sayfasına yönlendir
                                                  context.push(AppRouter.premium);
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
                          
                          // Hesap Bilgileri Açılır Panel
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: _hesapBilgileriAcik ? null : 0,
                            margin: EdgeInsets.only(
                              top: _hesapBilgileriAcik ? 8 : 0,
                              bottom: _hesapBilgileriAcik ? 8 : 0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _hesapBilgileriAcik
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Consumer<AuthViewModel>(
                                        builder: (context, authViewModel, _) {
                                          final user = FirebaseAuth.instance.currentUser;
                                          final displayName = user?.displayName ?? 'İsimsiz Kullanıcı';
                                          final email = user?.email ?? '-';
                                          
                                          // AuthViewModel'den daha fazla bilgi al
                                          final gender = authViewModel.user?.gender ?? 'Belirtilmemiş';
                                          final birthDate = authViewModel.user?.birthDate;
                                          final formattedBirthDate = birthDate != null
                                              ? '${birthDate.day.toString().padLeft(2, '0')}.${birthDate.month.toString().padLeft(2, '0')}.${birthDate.year}'
                                              : 'Belirtilmemiş';
                                          
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildUserInfoRow(
                                                label: 'Ad Soyad:',
                                                value: displayName,
                                              ),
                                              const SizedBox(height: 8),
                                              _buildUserInfoRow(
                                                label: 'E-posta:',
                                                value: email,
                                              ),
                                              const SizedBox(height: 8),
                                              _buildUserInfoRow(
                                                label: 'Cinsiyet:',
                                                value: gender,
                                              ),
                                              const SizedBox(height: 8),
                                              _buildUserInfoRow(
                                                label: 'Doğum Tarihi:',
                                                value: formattedBirthDate,
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  )
                                : null,
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
                          _buildProfileMenuItem(
                            icon: Icons.chat_bubble_outline,
                            title: 'Danışma Geçmişi',
                          ),
                          _buildProfileMenuItem(
                            icon: Icons.psychology,
                            title: 'Mesaj Koçu Geçmişi',
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
                                  await prefs.setBool('hasCompletedOnboarding', true);
                                  await prefs.remove('user_token');
                                  await prefs.remove('user_login_state');
                                  
                                  // Firebase Auth ile çıkış yap
                                  await authViewModel.signOut();
                                  
                                  if (context.mounted) {
                                    // Onboarding yerine login sayfasına yönlendir
                                    context.go('/login');
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
    final bool isHesapBilgileri = title == 'Hesap Bilgileri';
    final bool isExpanded = isHesapBilgileri && _hesapBilgileriAcik;
    
    return InkWell(
      onTap: () {
        debugPrint('Profil menü öğesine tıklandı: $title');
        // Menü öğesine göre dialog veya sayfa aç
        if (title == 'Hesap Bilgileri') {
          // Dialog yerine aşağıya açılır panel için durumu güncelle
          setState(() {
            _hesapBilgileriAcik = !_hesapBilgileriAcik;
          });
        } else if (title == 'Yardım ve Destek') {
          _showHelpSupportDialog(context);
        } else if (title == 'Geçmiş Analizler' || 
                 title == 'İlişki Raporları' || 
                 title == 'Danışma Geçmişi' || 
                 title == 'Mesaj Koçu Geçmişi') {
          
          // Premium kontrolü yap
          final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
          final isPremium = authViewModel.isPremium;
          
          if (isPremium) {
            // Premium kullanıcı ise ilgili sayfaya yönlendir
            if (title == 'Geçmiş Analizler') {
              context.go('/past-analyses');
            } else if (title == 'İlişki Raporları') {
              context.go('/past-reports');
            } else if (title == 'Danışma Geçmişi') {
              context.go('/past-consultations');
            } else if (title == 'Mesaj Koçu Geçmişi') {
              context.go('/past-message-coach');
            }
          } else {
            // Premium değilse uyarı göster
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Bu özellik sadece Premium üyelere özeldir'),
                duration: const Duration(seconds: 3),
                backgroundColor: const Color(0xFF4A2A80),
                action: SnackBarAction(
                  label: 'Premium\'a Geç',
                  textColor: Colors.white,
                  onPressed: () {
                    // Premium sayfasına yönlendir
                    context.push(AppRouter.premium);
                  },
                ),
              ),
            );
          }
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
            AnimatedRotation(
              turns: isExpanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isHesapBilgileri ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
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
                      const SnackBar(content: Text('E-posta desteği: destek@flortya.com')),
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


  void _showRelationshipEvaluation(BuildContext context) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    // Erişim kontrolü
    final hasAccess = await _relationshipAccessService.canUseRelationshipTest(isPremium);
    
    if (!hasAccess) {
      // Erişim yoksa premium uyarısı göster
      if (!context.mounted) return;
      _showPremiumRequiredDialog();
      return;
    }
    
    // Erişim varsa kullanım sayısını artır (premium değilse)
    if (!isPremium) {
      await _relationshipAccessService.incrementRelationshipTestCount();
    }
    
    // İlişki değerlendirmesi sayfasına yönlendir
    if (context.mounted) {
      context.push('/report');
    }
  }
  
  // Premium gerekli uyarı diyaloğu
  void _showPremiumRequiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Premium Gerekli'),
          content: const Text(
            'İlişki değerlendirme hakkınız doldu. Premium üyelik satın alarak sınırsız kullanabilir veya reklam izleyerek 3 hak daha kazanabilirsiniz.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showAdForRelationshipTest();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Reklam İzle'),
            ),
          ],
        );
      },
    );
  }
  
  // İlişki testi için reklam izleme
  Future<void> _showAdForRelationshipTest() async {
    // Reklam yükleniyor diyaloğu
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext loadingContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF352269),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D3FFF)),
              ),
              const SizedBox(height: 16),
              const Text(
                "Reklam yükleniyor...",
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
    
    // AdService kullanarak reklam göster
    AdService.loadRewardedAd(() async {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Yükleme diyaloğunu kapat
      
      // Reklam izlendi olarak işaretle
      await _relationshipAccessService.setRelationshipTestAdViewed(true);
      
      // Başarı mesajı göster
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tebrikler! 3 ilişki değerlendirmesi hakkı kazandınız."),
          backgroundColor: Color(0xFF4A2A80),
        ),
      );
      
      // Sayfaya yönlendirirken skipAccessCheck=true parametresi ekleyerek
      // erişim kontrolünü atlayacağımızı belirtiyoruz
      if (!context.mounted) return;
      
      // Go router ile doğrudan yönlendirme yerine, Navigator ile ReportView'a
      // skipAccessCheck=true parametresiyle yönlendiriyoruz
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ReportView(skipAccessCheck: true)
        )
      );
    });
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
  Widget _buildWaveAnimation(int? score, Color color) {
    // Puan null ise varsayılan değer kullan
    final dalgaYuksekligi = score != null ? score / 5 : 5.0;
    
    return AnimasyonluDalga(
      dalgaYuksekligi: dalgaYuksekligi,
      renk: color,
    );
  }



  // SSS butonu için işlev
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

  

  // Kullanıcı bilgi satırı oluşturma
  Widget _buildUserInfoRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // Wrapped dairesi oluşturmak için yardımcı metod
  Widget _buildWrappedCircle(BuildContext context, Map<String, dynamic> analysis) {
    // "Yeni" mantığı kaldırıldı, artık tüm wrapped analizleri doğrudan gösterilecek
    final String title = analysis['title'] as String? ?? 'Wrapped';
    final String dateStr = analysis['date'] as String? ?? DateTime.now().toIso8601String();
    
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () async {
          // Wrapped analizini göster
          try {
            // Yükleniyor göstergesi
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Wrapped analizi yükleniyor...'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
            
            // İşlemleri arka planda gerçekleştir
            await Future.microtask(() async {
              // Mevcut analizi göster
              final String? dataRef = analysis['dataRef'] as String?;
              if (dataRef != null) {
                // Referans edilen veriyi yükle
                final SharedPreferences prefs = await SharedPreferences.getInstance();
                final String? cachedData = prefs.getString(dataRef);
                
                if (cachedData != null && cachedData.isNotEmpty) {
                  try {
                    final List<dynamic> decodedData = jsonDecode(cachedData);
                    final List<Map<String, String>> summaryData = List<Map<String, String>>.from(
                      decodedData.map((item) => Map<String, String>.from(item))
                    );
                    
                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => KonusmaSummaryView(
                            summaryData: summaryData,
                          ),
                        ),
                      );
                    }
                    return;
                  } catch (e) {
                    debugPrint('Mevcut analiz yüklenirken hata: $e');
                  }
                }
              }
              
              // Eğer referans yoksa veya referans yüklenemezse, varsayılan olarak son wrapped veriyi göster
              final SharedPreferences prefs = await SharedPreferences.getInstance();
              final String? cachedWrappedData = prefs.getString('wrappedCacheData');
              
              if (cachedWrappedData != null && cachedWrappedData.isNotEmpty) {
                try {
                  final List<dynamic> decodedData = jsonDecode(cachedWrappedData);
                  final List<Map<String, String>> summaryData = List<Map<String, String>>.from(
                    decodedData.map((item) => Map<String, String>.from(item))
                  );
                  
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => KonusmaSummaryView(
                          summaryData: summaryData,
                        ),
                      ),
                    );
                  }
                  return;
                } catch (e) {
                  debugPrint('Varsayılan wrapped veri yüklenirken hata: $e');
                }
              }
              
              // Hiçbir veri bulunamazsa hata mesajı göster
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Analiz verisi bulunamadı'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            });
          } catch (e) {
            // Hata durumunda
            debugPrint('Wrapped analizi genel hatası: $e');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Hata oluştu: ${e.toString().substring(0, min(50, e.toString().length))}...'),
                  duration: const Duration(seconds: 3),
                  backgroundColor: Colors.red.shade700,
                ),
              );
            }
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Yuvarlak daire
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "İlişki",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "Özetiniz",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${DateTime.parse(dateStr).day}/${DateTime.parse(dateStr).month}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Isolate içinde çalışacak analiz fonksiyonu
  static Future<List<Map<String, String>>> _analizSohbetVerisiIsolate(String messageContent) async {
    final aiService = AiService();
    return await aiService.analizSohbetVerisi(messageContent);
  }

  // Hata mesajı gösterme yardımcı metodu
  void _showErrorMessage(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // Wrapped hikayeleri sıfırlama
  void resetWrappedData() {
    setState(() {
      _wrappedAnalyses = [];
    });
    debugPrint('Wrapped hikayeleri UI üzerinde sıfırlandı');
  }
} 

// Sınıf sonu

// Animasyonlu dalga widget'ı
class AnimasyonluDalga extends StatefulWidget {
  final double dalgaYuksekligi;
  final Color renk;
  
  const AnimasyonluDalga({
    super.key,
    required this.dalgaYuksekligi,
    required this.renk,
  });
  
  @override
  State<AnimasyonluDalga> createState() => _AnimasyonluDalgaState();
}

class _AnimasyonluDalgaState extends State<AnimasyonluDalga> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          height: 80,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: CustomPaint(
            painter: SimpleDalgaPainter(
              dalgaYuksekligi: widget.dalgaYuksekligi,
              dalgaSayisi: 5,
              renk: widget.renk,
              animasyonDegeri: _animationController.value * 4.0,
            ),
          ),
        );
      },
    );
  }
}

// Basit dalga çizici
class SimpleDalgaPainter extends CustomPainter {
  final double dalgaYuksekligi;
  final int dalgaSayisi;
  final Color renk;
  final double animasyonDegeri; // Animasyon için değer eklendi

  SimpleDalgaPainter({
    required this.dalgaYuksekligi,
    required this.dalgaSayisi,
    required this.renk,
    required this.animasyonDegeri, // Animasyon değeri zorunlu parametre
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = renk.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    final path = Path();
    final width = size.width;
    final height = size.height;
    
    // Yatay çizgi (orta)
    final baseY = height * 0.5;
    path.moveTo(0, baseY);
    
    // Dalga deseni oluştur
    double waveWidth = width / dalgaSayisi;
    
    for (double i = 0; i <= dalgaSayisi; i += 0.5) {
      double x1 = i * waveWidth;
      // Animasyon değeri ile dalga hareketliliği sağlanıyor
      double y1 = baseY + sin((i + animasyonDegeri) * pi) * dalgaYuksekligi;
      
      path.lineTo(x1, y1);
    }
    
    canvas.drawPath(path, paint);
    
    // Dalga altını dolgu ile boyama
    final fillPath = Path();
    fillPath.moveTo(0, baseY);
    
    for (double i = 0; i <= dalgaSayisi; i += 0.5) {
      double x1 = i * waveWidth;
      double y1 = baseY + sin((i + animasyonDegeri) * pi) * dalgaYuksekligi;
      fillPath.lineTo(x1, y1);
    }
    
    // Ekranın alt kısmını kapatma
    fillPath.lineTo(width, height);
    fillPath.lineTo(0, height);
    fillPath.close();
    
    // Dolgu rengi
    final fillPaint = Paint()
      ..color = renk.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant SimpleDalgaPainter oldDelegate) => 
    oldDelegate.animasyonDegeri != animasyonDegeri || 
    oldDelegate.dalgaYuksekligi != dalgaYuksekligi;
}

