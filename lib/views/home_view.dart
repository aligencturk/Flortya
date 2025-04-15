import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/message_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../app_router.dart';

// Grafik Çizici Sınıf
class ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const pointData = [
      {'x': 0, 'y': 70},
      {'x': 1, 'y': 75},
      {'x': 2, 'y': 78},
      {'x': 3, 'y': 82},
    ];
    
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
    for (var i = 0; i <= 3; i++) {
      final x = i * size.width / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    
    // Noktaları birleştiren çizgiyi çizme
    final path = Path();
    
    // İlk noktayı ayarla
    var startPoint = _getPointLocation(pointData[0]['x']!, pointData[0]['y']!, size);
    path.moveTo(startPoint.dx, startPoint.dy);
    
    // Diğer noktalara bağla
    for (var i = 1; i < pointData.length; i++) {
      final point = _getPointLocation(pointData[i]['x']!, pointData[i]['y']!, size);
      path.lineTo(point.dx, point.dy);
    }
    
    // Çizgiyi çiz
    canvas.drawPath(path, linePaint);
    
    // Noktaları çizme
    for (var data in pointData) {
      final point = _getPointLocation(data['x']!, data['y']!, size);
      
      // Dolgu
      canvas.drawCircle(point, pointRadius, pointFillPaint);
      // Kenar
      canvas.drawCircle(point, pointRadius, pointStrokePaint);
    }
  }
  
  // X, Y koordinatlarını ekrandaki konuma dönüştürme
  Offset _getPointLocation(int x, int y, Size size) {
    final xPos = (x * size.width / 3);
    final yPos = size.height - (y * size.height / 100);
    return Offset(xPos, yPos);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Tab değişimini işleme
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
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
        child: PageView(
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

  // Mesaj Analizi Tab
  Widget _buildMessageAnalysisTab(BuildContext context) {
    final theme = Theme.of(context);
    final messageViewModel = Provider.of<MessageViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    // Kullanıcı profilinden analiz sonucunu al
    final profileViewModel = Provider.of<ProfileViewModel>(context, listen: true);
    final analizSonucu = profileViewModel.user?.sonAnalizSonucu;
    
    // build sırasında doğrudan state değişikliği yapmamak için postFrameCallback kullan
    WidgetsBinding.instance.addPostFrameCallback((_) { 
      if (context.mounted && 
          authViewModel.user != null && 
          !messageViewModel.isLoading && 
          !messageViewModel.isFirstLoadCompleted) { 
        messageViewModel.loadMessages(authViewModel.user!.id); 
      } 
    });
    
    return SafeArea(
        child: Column(
          children: [
            // App Bar
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                const Text(
                  'logo',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 12),
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
                  // İlişki Uyum Puanı Kartı
                  Container(
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
                            ? 'Son analiz: ${_formatDate(analizSonucu.tarih)}' 
                            : 'Henüz analiz yapılmamış',
                                style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  messageViewModel.clearCurrentMessage();
                                  context.push(AppRouter.messageAnalysis);
                                },
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Yeni Analiz Başlat'),
                                style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9D3FFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ],
                              ),
                            ),
                  
                  // Kategori Analizleri Başlık
                  Row(
                    children: [
                      const Text(
                        'Kategori Analizleri',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      if (analizSonucu == null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Analiz Yapılmamış',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Kategori Kartları
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
                            
                            return Row(
                              children: [
                                _buildCategoryCard(
                                  context, 
                                  title: kategoriAdi,
                                  description: aciklama,
                                  value: puan / 100,
                                  color: renk,
                                  width: 220,
                                ),
                                const SizedBox(width: 12),
                              ],
                            );
                          }).toList(),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                color: Colors.white.withOpacity(0.5),
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Henüz analiz yapılmamış',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                  ),
                      
                      const SizedBox(height: 24),
                  
                  // Kişiselleştirilmiş Tavsiyeler Başlık
                  Row(
                    children: [
                      const Text(
                        'Kişiselleştirilmiş Tavsiyeler',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      if (analizSonucu == null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Analiz Yapılmamış',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Kişiselleştirilmiş Tavsiye Kartları
                  if (analizSonucu != null && analizSonucu.kisiselestirilmisTavsiyeler.isNotEmpty)
                    ...analizSonucu.kisiselestirilmisTavsiyeler.map((tavsiye) => 
                      Column(
                        children: [
                          _buildAdviceCard(context, tavsiye),
                          const SizedBox(height: 12),
                        ],
                      )
                    ).toList()
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
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF352269),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Bu analiz için kişiselleştirilmiş tavsiye bulunmuyor',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 100), // Boşluk ekleyerek alt navigationbar'ın üzerindeki içeriği görelim
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

  // Kategori kartı widget'ı
  Widget _buildCategoryCard(BuildContext context, {
    required String title,
    required String description,
    required double value,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(value * 100).toInt()}/100',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              children: [
                Container(
                  width: (width - 32) * value,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Description
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Tavsiye kartı widget'ı
  Widget _buildAdviceCard(BuildContext context, String adviceText) {
    final Color randomColor = _getRandomAdviceColor();
    final IconData randomIcon = _getRandomAdviceIcon();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: randomColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              randomIcon,
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
                  _getTitleFromAdvice(adviceText),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  adviceText,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tarih formatlama
  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonthName(date.month)} ${date.year}';
  }

  // Ay numarasından ay adını alma
  String _getMonthName(int month) {
    const monthNames = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return monthNames[month - 1];
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
  
  // Rastgele tavsiye rengi alma
  Color _getRandomAdviceColor() {
    final colors = [
      const Color(0xFF6C5DD3),
      const Color(0xFFFF4FD8),
      const Color(0xFF4F8CF6),
      const Color(0xFFF79E1B),
    ];
    return colors[Random().nextInt(colors.length)];
  }
  
  // Rastgele tavsiye ikonu alma
  IconData _getRandomAdviceIcon() {
    final icons = [
      Icons.lightbulb_outline,
      Icons.favorite,
      Icons.headset_mic,
      Icons.psychology,
      Icons.support,
      Icons.health_and_safety,
    ];
    return icons[Random().nextInt(icons.length)];
  }
  
  // Tavsiye metninden başlık oluşturma
  String _getTitleFromAdvice(String advice) {
    if (advice.length > 30) {
      final firstPart = advice.substring(0, 30).split(' ');
      return firstPart.take(firstPart.length - 1).join(' ');
    }
    return advice.split('.').first;
  }

  // İlişki Raporu Tab
  Widget _buildRelationshipReportTab(BuildContext context) {
    return SafeArea(
        child: Column(
          children: [
            // App Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                const Text(
                  'logo',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Merhaba, Zeynep',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    ),
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
                      'İlişki Gelişim\nRaporu',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // İlişki Gelişim Grafiği
                    Container(
                      height: 250,
                      width: double.infinity,
                      child: Column(
                        children: [
                          // Y ekseni değerleri ve grafik
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Y ekseni değerleri
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('100', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                    const Text('80', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                    const Text('60', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                    const Text('40', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                    const Text('20', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                    const Text('0', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                
                                // Grafik alanı
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      child: CustomPaint(
                                        size: const Size(double.infinity, double.infinity),
                                        painter: ChartPainter(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // X ekseni değerleri
                          Padding(
                            padding: const EdgeInsets.only(left: 24, top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Mart', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                const Text('Nisan', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                const Text('Mayıs', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                const Text('Haziran', style: TextStyle(color: Colors.white60, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // İlişki Değerlendirmesi Butonu - Buraya taşındı
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9D3FFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            _showRelationshipEvaluation(context);
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min, // Buton içeriği kadar yer kaplasın
                            children: [
                              const Icon(
                                Icons.favorite,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'İlişki Değerlendirmesi',
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
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Alt kategoriler değişim oranları
                    _buildCategoryChangeRow('İletişim Kalitesi', 12, true),
                    const SizedBox(height: 12),
                    _buildCategoryChangeRow('Duygusal Bağ', 8, true),
                    const SizedBox(height: 12),
                    _buildCategoryChangeRow('Çatışma Çözümü', 15, true),
                    
                    // Alt kategori yazılarından sonra biraz boşluk bırakalım
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
                const Text(
                  'logo',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Merhaba, Zeynep',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    ),
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
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Tavsiye kartı
                    Expanded(
                      child: Container(
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
                                const Text(
                                  'İlişkinizi Güçlendirin',
                                  style: TextStyle(
                                          color: Colors.white,
                      fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.circle,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ],
                            ),
                            
                                      const SizedBox(height: 16),
                            
                            // Tavsiye metni
                            const Text(
                              'Bugün partnerinizle birlikte yeni bir aktivite planlamayı deneyin. Örneğin, evde birlikte yemek yapabilir veya online bir dans dersi alabilirsiniz. Yeni deneyimler paylaşmak, ilişkinizi taze ve heyecanlı tutar.',
                                          style: TextStyle(
                                color: Colors.white,
                      fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                            
                            const Spacer(),
                            
                            // Premium buton
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
                      ),
                    ),
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
                const Text(
                  'logo',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Merhaba, Zeynep',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    ),
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
                            icon: Icons.person_outline,
                            title: 'Hesap Bilgileri',
                          ),
                          const Divider(height: 1, color: Colors.white24),
                          _buildProfileMenuItem(
                            icon: Icons.notifications_outlined,
                            title: 'Bildirim Ayarları',
                          ),
                          const Divider(height: 1, color: Colors.white24),
                          _buildProfileMenuItem(
                            icon: Icons.security_outlined,
                            title: 'Gizlilik ve Güvenlik',
                          ),
                          const Divider(height: 1, color: Colors.white24),
                          _buildProfileMenuItem(
                            icon: Icons.support_outlined,
                            title: 'Yardım ve Destek',
                          ),
                        ],
          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                    // Çıkış Butonu
                    TextButton.icon(
                      onPressed: () async {
                                  final shouldLogout = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF352269),
                            title: const Text(
                              'Çıkış Yap',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              'Çıkış yapmak istediğinizden emin misiniz?',
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
                                    await authViewModel.signOut();
                                    if (context.mounted) {
                                      context.go('/onboarding');
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
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.white70,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: Colors.white70,
        size: 16,
      ),
      onTap: () {},
    );
  }

  void _showSettingsDialog(BuildContext context) {
    bool bildirimlerAcik = true; // Varsayılan olarak açık
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF352269),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Container(
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
                    
                    // Bildirimler
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bildirimler',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        Switch(
                          value: bildirimlerAcik,
                          onChanged: (value) {
                            setState(() {
                              bildirimlerAcik = value;
                            });
                          },
                          activeColor: const Color(0xFF9D3FFF),
                          activeTrackColor: const Color(0xFF9D3FFF).withOpacity(0.5),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Dil
                    InkWell(
                      onTap: () {
                        // Dil değiştirme ekranına git
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Dil',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            Row(
                              children: [
                                const Text(
                                  'Türkçe',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 16,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Gizlilik
                    InkWell(
                      onTap: () {
                        // Gizlilik ayarları ekranına git
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Gizlilik',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            Row(
                              children: [
                                const Text(
                                  'Ayarlar',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 16,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Değişiklikleri Kaydet Butonu
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Değişiklikleri kaydet
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9D3FFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_outlined, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Değişiklikleri Kaydet',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showRelationshipEvaluation(BuildContext context) {
    // İlişki değerlendirmesi için ReportView'a yönlendir
    context.push('/report');
  }
} 

