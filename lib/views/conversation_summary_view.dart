import 'package:animated_background/animated_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math'; // Rastgele değerler için eklendi
import 'package:file_selector/file_selector.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Animasyonlar için eklendi
import 'package:google_fonts/google_fonts.dart';
import '../services/ai_service.dart';
import '../services/logger_service.dart';
import '../utils/loading_indicator.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../services/premium_service.dart';
import '../widgets/feature_card.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/wrapped_service.dart';

class KonusmaSummaryView extends StatefulWidget {
  final List<Map<String, String>> summaryData;

  const KonusmaSummaryView({
    super.key,
    required this.summaryData,
  });

  @override
  State<KonusmaSummaryView> createState() => _KonusmaSummaryViewState();
}

class _KonusmaSummaryViewState extends State<KonusmaSummaryView> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Tam ekran modu
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Tam ekran modunu kapat
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.transparent,
        body: PageView.builder(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          itemCount: widget.summaryData.length + 1, // Ekstra sayfa için +1
          onPageChanged: (int page) {
            setState(() {
              _currentPage = page;
            });
          },
          itemBuilder: (context, index) {
            // Son sayfada "Bitir" butonunu göster
            if (index == widget.summaryData.length) {
              return _buildFinalCard();
            }
            
            // Normal özet kartı
            final item = widget.summaryData[index];
            return _buildSummaryCard(
              title: item['title'] ?? '',
              comment: item['comment'] ?? '',
              index: index,
            );
          },
        ),
      );
  }

  Widget _buildSummaryCard({
    required String title,
    required String comment,
    required int index,
  }) {
    // Her kart için farklı resim arka planları (1.png - 10.png)
    final List<String> backgroundImages = [
      'assets/images/1.png',
      'assets/images/2.png',
      'assets/images/3.png',
      'assets/images/4.png',
      'assets/images/5.png',
      'assets/images/6.png',
      'assets/images/7.png',
      'assets/images/8.png',
      'assets/images/9.png',
      'assets/images/10.png',
    ];
    
    // Her kart için yazı renkleri (true = beyaz, false = siyah)
    final List<bool> useWhiteText = [
      true,  // 1. resim - beyaz yazı
      false, // 2. resim - siyah yazı
      false, // 3. resim - siyah yazı
      true,  // 4. resim - beyaz yazı
      true,  // 5. resim - beyaz yazı
      true,  // 6. resim - beyaz yazı (mevcut gibi)
      true,  // 7. resim - beyaz yazı (varsayılan)
      false, // 8. resim - siyah yazı
      true,  // 9. resim - beyaz yazı (doğru)
      true,  // 10. resim - beyaz yazı (doğru)
    ];

    final imageIndex = index % backgroundImages.length;
    final isWhiteText = useWhiteText[imageIndex];
    final textColor = isWhiteText ? Colors.white : Colors.black;
    final iconColor = isWhiteText ? Colors.white : Colors.black;
    final (decoratedTitle, iconData) = _decorateTitle(title);

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(backgroundImages[imageIndex]),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Üst Kısım: Sayfa göstergesi ve Kapat Butonu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Kapat butonu
                      IconButton(
                        icon: Icon(Icons.close, color: iconColor, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Kapat',
                      ),
                      
                      // Sayfa göstergesi
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${index + 1}/${widget.summaryData.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  
                  // Orta Kısım: İkon, Başlık ve Yorum
                  Icon(iconData, color: iconColor, size: 64)
                      .animate()
                      .fade(duration: 500.ms)
                      .scale(delay: 200.ms),
                  const SizedBox(height: 24),
                  Text(
                    decoratedTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.archivo(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      shadows: isWhiteText 
                        ? const [Shadow(color: Colors.black38, offset: Offset(2, 2), blurRadius: 4)]
                        : const [Shadow(color: Colors.white54, offset: Offset(1, 1), blurRadius: 2)],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    comment,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.archivo(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: textColor.withOpacity(0.95),
                      height: 1.5,
                      shadows: isWhiteText 
                        ? const [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)]
                        : const [Shadow(color: Colors.white38, offset: Offset(1, 1), blurRadius: 2)],
                    ),
                  ),
                  const Spacer(),
                  
                  // Alt Kısım: Kaydırma göstergesi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Devam etmek için kaydırın',
                        style: TextStyle(
                          color: textColor.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: textColor,
                        size: 16,
                      ),
                    ],
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .shimmer(delay: 1000.ms, duration: 1800.ms, color: textColor.withOpacity(0.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalCard() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF121212), Color(0xFF2D2D2D)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animasyonlu tamamlandı ikonu
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF9D3FFF).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Color(0xFF9D3FFF),
                  size: 60,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Tamamlandı metni
              const Text(
                '🎉 Konuşma Özeti Tamamlandı! 🎊',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                '💡 Konuşmanızdaki önemli analizleri gördünüz. İlişkinizi geliştirmek için bu içgörüleri kullanabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 30),
              
              // PDF Paylaş butonu
              ElevatedButton.icon(
                onPressed: () => _createAndSharePDF(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF9D3FFF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.share),
                label: const Text(
                  '📑 PDF Olarak Paylaş',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Bitir butonu
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9D3FFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  '🔍 Analize Geri Dön',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // PDF oluşturma ve paylaşma metodu
  Future<void> _createAndSharePDF() async {
    try {
      // PDF belgesi oluştur
      final pdf = pw.Document();
      
      // Varsayılan font yükle
      final font = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();
      
      // PDF sayfalarını oluştur
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Konuşma Analizi',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 24,
                      color: PdfColors.purple,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'Tarih: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                ],
              ),
            );
          },
        )
      );
      
      // İçerik sayfalarını oluştur
      for (int i = 0; i < widget.summaryData.length; i++) {
        final item = widget.summaryData[i];
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Padding(
                padding: const pw.EdgeInsets.all(24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.purple50,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColors.purple200),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            item['title'] ?? '',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 18,
                              color: PdfColors.purple900,
                            ),
                          ),
                          pw.SizedBox(height: 16),
                          pw.Text(
                            item['comment'] ?? '',
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 14,
                              color: PdfColors.black,
                              lineSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Text(
                      '${i + 1} / ${widget.summaryData.length}',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
      
      // Son sayfayı ekle
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'AYNA',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 24,
                      color: PdfColors.purple,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'İlişki Danışmanı Uygulaması',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 18,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Text(
                    'Bu analiz yapay zeka kullanılarak oluşturulmuştur.\nRapor tarihi: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
      
      // PDF'i geçici dosyaya kaydet
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/konusma_analizi.pdf');
      await file.writeAsBytes(await pdf.save());
      
      // PDF'i paylaş
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Konuşma analizi raporum',
        subject: 'Konuşma Wrapped Analizi',
      );
      
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF oluşturulurken bir hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  // Başlığı emojilerle süsleme ve ikon döndürme metodu
  (String, IconData) _decorateTitle(String title) {
    if (title.toLowerCase().contains('konuşma süresi') || title.toLowerCase().contains('süre')) {
      return ('⏰ $title', Icons.access_time_filled_outlined);
    } else if (title.toLowerCase().contains('başlatıyor') || title.toLowerCase().contains('kim')) {
      return ('👑 $title', Icons.person_pin_outlined);
    } else if (title.toLowerCase().contains('gergin') || title.toLowerCase().contains('tartışma')) {
      return ('⚡ $title', Icons.bolt_outlined);
    } else if (title.toLowerCase().contains('romantik') || title.toLowerCase().contains('ateşli')) {
      return ('🔥 $title', Icons.favorite_outlined);
    } else if (title.toLowerCase().contains('kelime') || title.toLowerCase().contains('şampiyon')) {
      return ('🏆 $title', Icons.emoji_events_outlined);
    } else if (title.toLowerCase().contains('emoji') || title.toLowerCase().contains('sticker')) {
      return ('😄 $title', Icons.emoji_emotions_outlined);
    } else if (title.toLowerCase().contains('karakter') || title.toLowerCase().contains('mesaj')) {
      return ('📝 $title', Icons.text_fields_outlined);
    } else if (title.toLowerCase().contains('ritim') || title.toLowerCase().contains('konuşma')) {
      return ('🎵 $title', Icons.graphic_eq_outlined);
    } else if (title.toLowerCase().contains('duygu') || title.toLowerCase().contains('ton')) {
      return ('💭 $title', Icons.psychology_outlined);
    } else if (title.toLowerCase().contains('dikkat') || title.toLowerCase().contains('sohbet')) {
      return ('🎯 $title', Icons.auto_awesome_outlined);
    } else {
      return ('✨ $title', Icons.auto_awesome);
    }
  }
}

class _DynamicAnimatedBackground extends StatelessWidget {
  const _DynamicAnimatedBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final random = Random();

    // Animate edilecek elementleri tanımla
    final List<IconData> elements = [
      Icons.favorite,
      Icons.favorite_border,
      Icons.all_inclusive, // Sonsuzluk
      Icons.key_outlined,
      Icons.diamond_outlined,
      Icons.lock_open_outlined,
    ];

    const elementCount = 25; // Toplam element sayısı

    return Stack(
      children: List.generate(elementCount, (index) {
        final iconData = elements[random.nextInt(elements.length)];
        final isHeart = iconData == Icons.favorite || iconData == Icons.favorite_border;

        // Element tipine göre animasyonu özelleştir
        final elementSize = isHeart
            ? random.nextDouble() * 20 + 10 // Kalpler daha küçük
            : random.nextDouble() * 30 + 20; // Diğer objeler daha büyük
        
        final duration = (random.nextDouble() * 8000 + 8000).ms; // Daha yavaş animasyonlar
        final delay = (random.nextDouble() * 10000).ms;

        final startX = random.nextDouble() * size.width;
        final startY = size.height + elementSize;
        
        // Daha dinamik hareket için bitiş pozisyonunu rastgele yap
        final endX = startX + (random.nextDouble() * 100 - 50); // Hafif yatay sürüklenme
        final endY = -elementSize;

        // Kalp olmayan objeler için rotasyon ekle
        final rotation = isHeart ? 0.0 : (random.nextDouble() * 0.5 - 0.25);

        return Positioned(
          left: startX,
          top: startY,
          child: Animate(
            effects: [
              FadeEffect(begin: 0.0, end: 0.6, duration: 1500.ms, delay: delay),
              MoveEffect(
                begin: const Offset(0, 0),
                end: Offset(endX - startX, endY - startY),
                duration: duration,
                delay: delay,
                curve: Curves.linear,
              ),
              if (!isHeart)
                RotateEffect(
                  begin: 0,
                  end: rotation,
                  duration: duration,
                  delay: delay,
                ),
              FadeEffect(begin: 0.6, end: 0.0, duration: 1500.ms, delay: duration + delay - 1500.ms),
            ],
            onComplete: (controller) => controller.loop(),
            child: Icon(
              iconData,
              color: Colors.white.withOpacity(isHeart ? 0.3 : 0.2), // Objeleri daha belirsiz yap
              size: elementSize,
            ),
          ),
        );
      }),
    );
  }
}

/// Dosya seçme ve sohbet analizi için giriş ekranı
class SohbetAnaliziView extends StatefulWidget {
  const SohbetAnaliziView({super.key});

  @override
  State<SohbetAnaliziView> createState() => _SohbetAnaliziViewState();
}

class _SohbetAnaliziViewState extends State<SohbetAnaliziView> {
  final AiService _aiService = AiService();
  final LoggerService _logger = LoggerService();
  final WrappedService _wrappedService = WrappedService();
  
  File? _selectedFile;
  String _fileContent = '';
  bool _isAnalyzing = false;
  bool _isAnalysisCancelled = false; // Analiz iptal kontrolü
  String _errorMessage = '';
  List<Map<String, String>> _summaryData = [];
  bool _isTxtFile = false; // .txt dosyası olup olmadığını takip etmek için
  
  // Katılımcı seçimi için yeni değişkenler
  List<String> _participants = [];
  String? _selectedParticipant;
  bool _isParticipantsExtracted = false;
  
  // Cache için değişkenler
  static const String WRAPPED_CACHE_KEY = 'wrappedCacheData';
  static const String WRAPPED_CACHE_CONTENT_KEY = 'wrappedCacheContent';
  static const String WRAPPED_IS_TXT_KEY = 'wrappedIsTxtFile'; // _isTxtFile değişkenini saklamak için yeni anahtar
  
  @override
  void initState() {
    super.initState();
    // Uygulama başladığında önbellekten verileri yükle
    _loadInitialData();
  }
  
  // Uygulama başladığında önbellekten verileri yükleme
  Future<void> _loadInitialData() async {
    try {
      _logger.i('Wrapped analiz sonuçları yükleniyor...');
      
      // Önce Firestore'dan yüklemeyi dene
      final wrappedData = await _wrappedService.getWrappedAnalysis();
      
      if (wrappedData != null) {
        _logger.i('Firestore\'dan wrapped analiz sonuçları yüklendi');
        
        setState(() {
          _summaryData = wrappedData['summaryData'] as List<Map<String, String>>;
          _fileContent = wrappedData['fileContent'] as String;
          _isTxtFile = wrappedData['isTxtFile'] as bool;
        });
        
        _logger.i('Firestore\'dan ${_summaryData.length} analiz sonucu yüklendi');
        return;
      }
      
      _logger.i('Firestore\'da veri bulunamadı, SharedPreferences kontrol ediliyor');
      
      // Firestore'da veri yoksa, eski SharedPreferences'dan yüklemeyi dene
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Önbellekte veri var mı kontrol et
      final String? cachedDataJson = prefs.getString(WRAPPED_CACHE_KEY);
      final String? cachedContent = prefs.getString(WRAPPED_CACHE_CONTENT_KEY);
      final bool isTxtFile = prefs.getBool(WRAPPED_IS_TXT_KEY) ?? false;
      
      if (cachedDataJson != null && cachedDataJson.isNotEmpty) {
        try {
          // Daha önce analiz edilmiş verileri yükle
          final List<dynamic> decodedData = jsonDecode(cachedDataJson);
          final loadedSummaryData = List<Map<String, String>>.from(
            decodedData.map((item) => Map<String, String>.from(item))
          );
          
          // Verileri yükle ve UI'ı güncelle
          setState(() {
            if (cachedContent != null) {
              _fileContent = cachedContent;
            }
            _summaryData = loadedSummaryData;
            _isTxtFile = isTxtFile; // .txt dosya bayrağını geri yükle
          });
          
          _logger.i('SharedPreferences\'dan ${_summaryData.length} analiz sonucu yüklendi');
          
          // SharedPreferences'dan yüklenen verileri Firestore'a aktarma
          if (_summaryData.isNotEmpty && _fileContent.isNotEmpty) {
            await _wrappedService.saveWrappedAnalysis(
              summaryData: _summaryData,
              fileContent: _fileContent,
              isTxtFile: _isTxtFile,
            );
            _logger.i('SharedPreferences\'dan yuklenen veriler Firestore\'a aktarildi');
          }
        } catch (e) {
          _logger.e('Önbellek verisi ayrıştırma hatası', e);
        }
      } else {
        _logger.i('Uygulama başlangıcında önbellekte veri bulunamadı');
      }
    } catch (e) {
      _logger.e('Başlangıç verisi yükleme hatası', e);
    }
  }
  
  Future<void> _selectFile() async {
    try {
      final XTypeGroup txtTypeGroup = XTypeGroup(
        label: 'Text',
        extensions: ['txt'],
      );
      
      final XFile? result = await openFile(
        acceptedTypeGroups: [txtTypeGroup],
      );
      
      if (result != null) {
        setState(() {
          _selectedFile = File(result.path);
          _fileContent = '';
          _errorMessage = '';
          _summaryData = [];
          _isTxtFile = true; // .txt dosyası seçildiğini işaretle
        });
        
        // Dosya içeriğini oku
        await _readFileContent();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Dosya seçilirken bir hata oluştu: $e';
      });
      _logger.e('Dosya seçme hatası', e);
    }
  }
  
  Future<void> _readFileContent() async {
    try {
      if (_selectedFile != null) {
        final content = await _selectedFile!.readAsString();
        
        // Dosya boyutunu kontrol et ve kullanıcıya bilgi ver
        final sizeInMB = (content.length / 1024 / 1024);
        final messageCount = content.split('\n').where((line) => 
          line.trim().isNotEmpty && 
          (RegExp(r'\d{1,2}[\.\/-]\d{1,2}[\.\/-](\d{2}|\d{4}).*\d{1,2}:\d{2}').hasMatch(line) ||
           line.contains(':'))
        ).length;
        
        // Katılımcıları çıkar
        final participants = _extractParticipantsFromText(content);
        
        // Onaylama dialogu göster
        if (context.mounted) {
          final bool? shouldProceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Dosya Yüklendi'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📄 Dosya: ${_selectedFile!.path.split('/').last}'),
                  const SizedBox(height: 8),
                  Text('📊 Boyut: ${sizeInMB.toStringAsFixed(2)} MB'),
                  const SizedBox(height: 8),
                  Text('💬 Tahmini mesaj sayısı: $messageCount'),
                  const SizedBox(height: 8),
                  Text('👥 Katılımcı sayısı: ${participants.length}'),
                  const SizedBox(height: 16),
                  const Text(
                    'Dosya başarıyla yüklendi. Katılımcı seçimi için "Devam Et" butonuna basabilirsiniz.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Başka Dosya Seç'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A11CB),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Devam Et'),
                ),
              ],
            ),
          );
          
          if (shouldProceed == false) {
            // Kullanıcı başka dosya seçmek istiyor
            setState(() {
              _selectedFile = null;
              _fileContent = '';
              _summaryData = [];
              _errorMessage = '';
              _isTxtFile = false;
              _participants = [];
              _selectedParticipant = null;
              _isParticipantsExtracted = false;
            });
            return;
          }
        }
        
        setState(() {
          _fileContent = content;
          _errorMessage = '';
          _participants = participants;
          _isParticipantsExtracted = true;
        });
        
        // Katılımcı seçim dialogunu göster
        if (participants.length > 1) {
          await _showParticipantSelectionDialog();
        } else if (participants.length == 1) {
          setState(() {
            _selectedParticipant = participants.first;
          });
        } else {
          setState(() {
            _selectedParticipant = 'Tüm Katılımcılar';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Dosya okunurken bir hata oluştu: $e';
      });
      _logger.e('Dosya okuma hatası', e);
    }
  }
  
  // WhatsApp mesajlarından katılımcıları çıkaran fonksiyon
  List<String> _extractParticipantsFromText(String content) {
    Set<String> participants = {};
    Map<String, int> participantFrequency = {}; // Mesaj sayısını takip et
    
    final lines = content.split('\n');
    _logger.i('Toplam ${lines.length} satır analiz ediliyor...');
    
    int validMessageLines = 0;
    int invalidLines = 0;
    
    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // WhatsApp mesaj formatlarını kontrol et
      String? participantName = _extractParticipantFromLine(line);
      
      if (participantName != null && participantName.isNotEmpty) {
        if (_isValidParticipantName(participantName)) {
          participants.add(participantName);
          participantFrequency[participantName] = (participantFrequency[participantName] ?? 0) + 1;
          validMessageLines++;
        } else {
          invalidLines++;
          if (invalidLines < 10) { // İlk 10 geçersiz satırı logla
            _logger.d('Geçersiz katılımcı adı: "$participantName" satır: "${line.length > 100 ? line.substring(0, 100) + "..." : line}"');
          }
        }
      }
    }
    
    _logger.i('Analiz sonuçları:');
    _logger.i('- Geçerli mesaj satırı: $validMessageLines');
    _logger.i('- Geçersiz satır: $invalidLines');
    _logger.i('- Bulunan benzersiz katılımcı: ${participants.length}');
    
    // Katılımcı sıklıklarını logla
    var sortedParticipants = participantFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    _logger.i('En aktif katılımcılar:');
    for (var entry in sortedParticipants.take(10)) {
      _logger.i('- ${entry.key}: ${entry.value} mesaj');
    }
    
    // Eğer çok fazla katılımcı varsa (büyük ihtimalle hatalı parsing), filtrele
    if (participants.length > 15) {
      _logger.w('Çok fazla katılımcı bulundu (${participants.length}), filtreleme yapılıyor...');
      return _filterRelevantParticipants(sortedParticipants);
    }
    
    return participants.toList()..sort();
  }
  
  // Tek bir satırdan katılımcı adını çıkar
  String? _extractParticipantFromLine(String line) {
    // WhatsApp mesaj formatları - sadece iki nokta öncesi önemli
    
    // Format 1: [25/12/2023, 14:30:45] Ahmet: Mesaj
    RegExp format1 = RegExp(r'^\[([^\]]+)\]\s*([^:]+):(.*)$');
    Match? match1 = format1.firstMatch(line);
    if (match1 != null) {
      String nameWithDate = match1.group(2)?.trim() ?? '';
      // Tarih/saat bilgilerini temizle
      String cleanName = _cleanParticipantName(nameWithDate);
      return cleanName;
    }
    
    // Format 2: 25/12/2023, 14:30 - Ahmet: Mesaj
    RegExp format2 = RegExp(r'^(\d{1,2}[\.\/]\d{1,2}[\.\/]\d{2,4})[,\s]+(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–]\s*([^:]+):(.*)$');
    Match? match2 = format2.firstMatch(line);
    if (match2 != null) {
      String name = match2.group(3)?.trim() ?? '';
      return _cleanParticipantName(name);
    }
    
    // Format 3: 25.12.2023 14:30 - Ahmet: Mesaj
    RegExp format3 = RegExp(r'^(\d{1,2}[\.\/]\d{1,2}[\.\/]\d{2,4})\s+(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–]\s*([^:]+):(.*)$');
    Match? match3 = format3.firstMatch(line);
    if (match3 != null) {
      String name = match3.group(3)?.trim() ?? '';
      return _cleanParticipantName(name);
    }
    
    // Format 4: Basit format - Ahmet: Mesaj (tarih olmadan, sadece isim kontrolü yaparak)
    if (!line.contains('[') && !RegExp(r'^\d{1,2}[\.\/]\d{1,2}').hasMatch(line)) {
      RegExp simpleFormat = RegExp(r'^([^:]+):(.+)$');
      Match? simpleMatch = simpleFormat.firstMatch(line);
      if (simpleMatch != null) {
        String name = simpleMatch.group(1)?.trim() ?? '';
        // Bu format için daha sıkı kontrol
        if (name.length > 1 && name.length < 30 && !name.contains('/') && !name.contains('\\')) {
          return _cleanParticipantName(name);
        }
      }
    }
    
    return null;
  }
  
  // Katılımcı adını temizle
  String _cleanParticipantName(String name) {
    // Tarih ve saat bilgilerini temizle
    name = name.replaceAll(RegExp(r'\d{1,2}[\.\/]\d{1,2}[\.\/]\d{2,4}'), '');
    name = name.replaceAll(RegExp(r'\d{1,2}:\d{2}(?::\d{2})?'), '');
    
    // Özel karakterleri temizle
    name = name.replaceAll(RegExp(r'[,\-–\[\]()]+'), '');
    
    // Çoklu boşlukları tek boşluk yap
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    
    return name.trim();
  }
  
  // Geçerli katılımcı adı kontrolü - daha sıkı kurallar
  bool _isValidParticipantName(String name) {
    if (name.isEmpty || name.length < 2 || name.length > 40) return false;
    
    // Sadece sayılardan oluşan isimler
    if (RegExp(r'^\d+$').hasMatch(name)) return false;
    
    // Çok fazla sayı içeren isimler (%50'den fazla)
    int digitCount = RegExp(r'\d').allMatches(name).length;
    if (digitCount > name.length * 0.5) return false;
    
    // Yasaklı kelimeler (case-insensitive)
    final List<String> bannedWords = [
      'whatsapp', 'message', 'system', 'admin', 'notification', 'grup', 'group',
      'genre', 'plot', 'title', 'year', 'movie', 'film', 'episode', 'season',
      'series', 'video', 'audio', 'image', 'document', 'location', 'contact',
      'call', 'missed', 'left', 'joined', 'changed', 'removed', 'added',
      'created', 'deleted', 'silindi', 'eklendi', 'çıktı', 'katıldı',
      'http', 'https', 'www', 'com', 'org', 'net', 'download', 'upload',
      'link', 'url', 'file', 'dosya', 'resim', 'ses', 'video'
    ];
    
    String lowerName = name.toLowerCase();
    for (String banned in bannedWords) {
      if (lowerName.contains(banned)) return false;
    }
    
    // URL benzeri yapılar
    if (name.contains('://') || name.contains('.com') || name.contains('.org') || name.contains('.net')) {
      return false;
    }
    
    // Dosya yolu benzeri
    if (name.contains('/') || name.contains('\\')) return false;
    
    // Çok fazla özel karakter (Latin harfler, Türkçe karakterler ve boşluk hariç)
    int specialCharCount = RegExp(r'[^a-zA-ZğüşöçıİĞÜŞÖÇ\s]').allMatches(name).length;
    if (specialCharCount > 3) return false;
    
    // Telefon numarası benzeri
    if (RegExp(r'^\+?\d[\d\s\-()]{7,}$').hasMatch(name)) return false;
    
    return true;
  }
  
  // En ilgili katılımcıları filtrele
  List<String> _filterRelevantParticipants(List<MapEntry<String, int>> sortedParticipants) {
    // En az 3 mesaj göndermiş ve en fazla 10 kişi
    List<String> filtered = sortedParticipants
        .where((entry) => entry.value >= 3) // En az 3 mesaj
        .take(10) // En fazla 10 kişi
        .map((entry) => entry.key)
        .toList();
    
    _logger.i('Filtreleme sonrası ${filtered.length} katılımcı kaldı:');
    for (int i = 0; i < filtered.length; i++) {
      var participant = sortedParticipants[i];
      _logger.i('${i + 1}. ${participant.key}: ${participant.value} mesaj');
    }
    
    return filtered;
  }

  // Silinen mesajları ve medya içeriklerini temizleyen fonksiyon
  String _temizleSilinenVeMedyaMesajlari(String metin) {
    List<String> lines = metin.split('\n');
    List<String> temizLines = [];
    
    for (String line in lines) {
      String trimmedLine = line.trim();
      
      // Boş satırları koru
      if (trimmedLine.isEmpty) {
        temizLines.add(line);
        continue;
      }
      
      // Silinen mesaj kalıpları (Türkçe ve İngilizce)
      final List<String> silinenMesajKaliplari = [
        'Bu mesaj silindi',
        'This message was deleted',
        'Mesaj silindi',
        'Message deleted',
        'Bu mesaj geri alındı',
        'This message was recalled',
        'Silinen mesaj',
        'Deleted message',
        '🚫 Bu mesaj silindi',
        '❌ Bu mesaj silindi',
      ];
      
      // Medya içerik kalıpları
      final List<String> medyaKaliplari = [
        '(medya içeriği)',
        '(media content)',
        '(görsel)',
        '(image)',
        '(video)',
        '(ses)',
        '(audio)',
        '(dosya)',
        '(file)',
        '(document)',
        '(belge)',
        '(fotoğraf)',
        '(photo)',
        '(resim)',
        '(sticker)',
        '(çıkartma)',
        '(gif)',
        '(konum)',
        '(location)',
        '(kişi)',
        '(contact)',
        '(arama)',
        '(call)',
        '(sesli arama)',
        '(voice call)',
        '(görüntülü arama)',
        '(video call)',
        '(canlı konum)',
        '(live location)',
        '(anket)',
        '(poll)',
      ];
      
      // Sistem mesajları (grup bildirimleri vs.)
      final List<String> sistemMesajlari = [
        'gruba eklendi',
        'gruptan çıktı',
        'gruptan çıkarıldı',
        'grup adını değiştirdi',
        'grup açıklamasını değiştirdi',
        'grup resmini değiştirdi',
        'güvenlik kodunuz değişti',
        'şifreleme anahtarları değişti',
        'added to the group',
        'left the group',
        'removed from the group',
        'changed the group name',
        'changed the group description',
        'changed the group photo',
        'security code changed',
        'encryption keys changed',
        'mesajlar uçtan uca şifrelendi',
        'messages are end-to-end encrypted',
      ];
      
      // Satırın mesaj kısmını çıkar (tarih ve isim kısmından sonra)
      String mesajKismi = '';
      
      // WhatsApp formatlarından mesaj kısmını çıkar
      // Format 1: [25/12/2023, 14:30:45] Ahmet: Mesaj
      RegExp format1 = RegExp(r'^\[([^\]]+)\]\s*([^:]+):\s*(.+)$');
      Match? match1 = format1.firstMatch(trimmedLine);
      if (match1 != null) {
        mesajKismi = match1.group(3)?.trim() ?? '';
      } else {
        // Format 2: 25/12/2023, 14:30 - Ahmet: Mesaj
        RegExp format2 = RegExp(r'^(\d{1,2}[\.\/]\d{1,2}[\.\/]\d{2,4})[,\s]+(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–]\s*([^:]+):\s*(.+)$');
        Match? match2 = format2.firstMatch(trimmedLine);
        if (match2 != null) {
          mesajKismi = match2.group(4)?.trim() ?? '';
        } else {
          // Format 3: Basit format - Ahmet: Mesaj
          RegExp format3 = RegExp(r'^([^:]+):\s*(.+)$');
          Match? match3 = format3.firstMatch(trimmedLine);
          if (match3 != null) {
            mesajKismi = match3.group(2)?.trim() ?? '';
          } else {
            // Mesaj formatı tanınmadı, satırı olduğu gibi kontrol et
            mesajKismi = trimmedLine;
          }
        }
      }
      
      // Silinen mesaj kontrolü
      bool silinenMesaj = false;
      for (String kalip in silinenMesajKaliplari) {
        if (mesajKismi.toLowerCase().contains(kalip.toLowerCase())) {
          silinenMesaj = true;
          break;
        }
      }
      
      // Medya içerik kontrolü
      bool medyaIcerik = false;
      for (String kalip in medyaKaliplari) {
        if (mesajKismi.toLowerCase().contains(kalip.toLowerCase())) {
          medyaIcerik = true;
          break;
        }
      }
      
      // Sistem mesajı kontrolü
      bool sistemMesaji = false;
      for (String kalip in sistemMesajlari) {
        if (mesajKismi.toLowerCase().contains(kalip.toLowerCase()) || 
            trimmedLine.toLowerCase().contains(kalip.toLowerCase())) {
          sistemMesaji = true;
          break;
        }
      }
      
      // Sadece gerçek mesajları koru
      if (!silinenMesaj && !medyaIcerik && !sistemMesaji && mesajKismi.isNotEmpty) {
        temizLines.add(line);
      }
    }
    
    return temizLines.join('\n');
  }

  // Hassas bilgileri sansürleyen fonksiyon
  String _sansurleHassasBilgiler(String metin) {
    // TC Kimlik Numarası (11 haneli sayı)
    metin = metin.replaceAll(RegExp(r'\b\d{11}\b'), '***********');
    
    // Kredi Kartı Numarası (16 haneli, boşluk/tire ile ayrılmış olabilir)
    metin = metin.replaceAll(RegExp(r'\b\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4}\b'), '**** **** **** ****');
    
    // Telefon Numarası (Türkiye formatları)
    metin = metin.replaceAll(RegExp(r'\b(\+90|0)[\s\-]?\d{3}[\s\-]?\d{3}[\s\-]?\d{2}[\s\-]?\d{2}\b'), '0*** *** ** **');
    
    // IBAN (TR ile başlayan 26 karakter)
    metin = metin.replaceAll(RegExp(r'\bTR\d{24}\b'), 'TR** **** **** **** **** **');
    
    // E-posta adresleri (kısmi sansür)
    metin = metin.replaceAllMapped(RegExp(r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b'), 
        (match) {
          String email = match.group(0)!;
          int atIndex = email.indexOf('@');
          if (atIndex > 2) {
            String username = email.substring(0, atIndex);
            String domain = email.substring(atIndex);
            String maskedUsername = username.substring(0, 2) + '*' * (username.length - 2);
            return maskedUsername + domain;
          }
          return '***@***';
        });
    
    // Şifre benzeri ifadeler (şifre, password, pin kelimelerinden sonra gelen değerler)
    metin = metin.replaceAllMapped(RegExp(r'(şifre|password|pin|parola|sifre)[\s:=]+[^\s]+', caseSensitive: false), 
        (match) => match.group(0)!.split(RegExp(r'[\s:=]+'))[0] + ': ****');
    
    // Adres bilgileri (mahalle, sokak, cadde içeren uzun metinler)
    metin = metin.replaceAll(RegExp(r'\b[^.!?]*?(mahalle|sokak|cadde|bulvar|apt|daire|no)[^.!?]*[.!?]?', caseSensitive: false), 
        '[Adres bilgisi sansürlendi]');
    
    // Doğum tarihi (DD/MM/YYYY, DD.MM.YYYY formatları)
    metin = metin.replaceAll(RegExp(r'\b\d{1,2}[./]\d{1,2}[./](19|20)\d{2}\b'), '**/**/****');
    
    // Plaka numaraları (Türkiye formatı)
    metin = metin.replaceAll(RegExp(r'\b\d{2}[\s]?[A-Z]{1,3}[\s]?\d{2,4}\b'), '** *** ****');
    
    // Banka hesap numaraları (uzun sayı dizileri)
    metin = metin.replaceAllMapped(RegExp(r'\b\d{8,20}\b'), (match) {
      String number = match.group(0)!;
      if (number.length >= 8) {
        return '*' * number.length;
      }
      return number;
    });
    
    return metin;
  }

  // Kişi seçim dialog'unu göster
  Future<void> _showParticipantSelectionDialog() async {
    if (_participants.isEmpty) {
      setState(() {
        _selectedParticipant = 'Tüm Katılımcılar';
      });
      return;
    }
    
    final String? result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        String? selectedInDialog = _participants.isNotEmpty ? _participants.first : null;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF352269),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.group,
                    color: Color(0xFF9D3FFF),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Katılımcı Seçimi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dosyada ${_participants.length} katılımcı bulundu:',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _participants.map((name) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9D3FFF).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Text(
                      'Wrapped analizinde hangi katılımcıya odaklanmak istiyorsunuz?',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Tüm katılımcılar seçeneği
                    RadioListTile<String>(
                      value: 'Tüm Katılımcılar',
                      groupValue: selectedInDialog,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedInDialog = value;
                        });
                      },
                      title: const Text(
                        'Tüm Katılımcılar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Genel sohbet analizi yap',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      activeColor: const Color(0xFF9D3FFF),
                    ),
                    
                    const Divider(color: Colors.white24),
                    
                    // Katılımcılar listesi
                    ..._participants.map((participant) {
                      return RadioListTile<String>(
                        value: participant,
                        groupValue: selectedInDialog,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedInDialog = value;
                          });
                        },
                        title: Text(
                          participant,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Bu kişiye odaklı analiz yap',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        activeColor: const Color(0xFF9D3FFF),
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(null);
                  },
                  child: Text(
                    'İptal',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedInDialog != null ? () {
                    Navigator.of(context).pop(selectedInDialog);
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9D3FFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Seç',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    
    if (result != null) {
      setState(() {
        _selectedParticipant = result;
      });
    } else {
      // Dialog iptal edildi, dosyayı sıfırla
      setState(() {
        _selectedFile = null;
        _fileContent = '';
        _summaryData = [];
        _errorMessage = '';
        _isTxtFile = false;
        _participants = [];
        _selectedParticipant = null;
        _isParticipantsExtracted = false;
      });
    }
  }
  
  Future<void> _analyzeChatContent() async {
    if (_fileContent.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen önce bir dosya seçin';
      });
      return;
    }
    
    if (!_isParticipantsExtracted || _selectedParticipant == null) {
      setState(() {
        _errorMessage = 'Lütfen önce katılımcı seçimi yapın';
      });
      return;
    }
    
    setState(() {
      _isAnalyzing = true;
      _isAnalysisCancelled = false; // İptal durumunu sıfırla
      _errorMessage = '';
    });
    
    try {
      // Silinen mesajları ve medya içeriklerini temizle
      String temizIcerik = _temizleSilinenVeMedyaMesajlari(_fileContent);
      
      // Hassas bilgileri sansürle
      String sansurluIcerik = _sansurleHassasBilgiler(temizIcerik);
      
      final result = await _aiService.wrappedAnaliziYap(sansurluIcerik, secilenKisi: _selectedParticipant);
      
      // Analiz iptal edilmişse işlemi durdu
      if (_isAnalysisCancelled) {
        _logger.i('Analiz kullanıcı tarafından iptal edildi');
        setState(() {
          _isAnalyzing = false;
          _errorMessage = 'Analiz iptal edildi';
        });
        return;
      }
      
      setState(() {
        _summaryData = result;
        _isAnalyzing = false;
      });
      
      if (_summaryData.isNotEmpty) {
        // NOT: Bu sadece wrapped kartlarını oluşturan analizdir
        // Normal txt mesaj analizi ayrı olarak yapılmalıdır
        _logger.i('Wrapped analizi tamamlandı');
        
        // Wrapped verilerini önbelleğe kaydet
        await _cacheSummaryData();
        
        // Wrapped görünümünü göster
        _showDirectWrappedView();
      } else {
        setState(() {
          _errorMessage = 'Analiz sırasında bir hata oluştu, sonuç alınamadı';
        });
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'Analiz sırasında bir hata oluştu: $e';
      });
      _logger.e('Sohbet analizi hatası', e);
    }
  }

  // Analizi iptal etme metodu
  void _cancelAnalysis() {
    setState(() {
      _isAnalysisCancelled = true;
      _isAnalyzing = false;
    });
    
    // AiService'e de iptal sinyali gönder
    _aiService.cancelAnalysis();
    _logger.i('Analiz iptal edildi');
  }
  
  // Wrapped analizi cache'den hızlı yükleme
  Future<void> _showWrappedAnalysisFromCache() async {
    _logger.i('Wrapped analizi cache\'den yükleniyor');
    
    try {
      if (_summaryData.isNotEmpty) {
        _logger.i('Memory\'de zaten ${_summaryData.length} wrapped sonucu var');
        _showDirectWrappedView();
        return;
      }
      
      // Cache'den yüklemeyi dene
      await _loadCachedSummaryData();
      
      if (_summaryData.isNotEmpty) {
        _logger.i('Cache\'den ${_summaryData.length} wrapped sonucu yüklendi');
        _showDirectWrappedView();
      } else {
        // Cache'de veri yoksa kullanıcıya bildir
        setState(() {
          _errorMessage = 'Wrapped analizi bulunamadı. Lütfen önce bir txt dosyası analiz edin.';
        });
        _logger.w('Cache\'de wrapped analizi bulunamadı');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Wrapped analizi yüklenirken hata oluştu: $e';
      });
      _logger.e('Cache\'den wrapped yükleme hatası', e);
    }
  }

  // Direkt wrapped görünümünü aç - premium kontrolü ile ama YENİ ANALİZ YAPMA
  Future<void> _showDirectWrappedView() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final bool isPremium = authViewModel.isPremium;
    final premiumService = PremiumService();
    
    // Premium değilse, kullanım kontrolü
    if (!isPremium) {
      final bool wrappedOpenedOnce = await premiumService.getWrappedOpenedOnce();
      
      if (!wrappedOpenedOnce) {
        // İlk kullanım - durumu güncelle
        await premiumService.setWrappedOpenedOnce();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu özelliği bir kez ücretsiz kullanabilirsiniz.'),
            duration: Duration(seconds: 2),
          ),
        );
        
        // Wrapped görünümünü aç
        _showSummaryViewDirect();
      } else {
        // Kullanım hakkı dolmuşsa premium dialog göster
        showPremiumInfoDialog(context, PremiumFeature.WRAPPED_ANALYSIS);
      }
    } else {
      // Premium kullanıcı için wrapped görünümünü aç
      _showSummaryViewDirect();
    }
  }

  // Wrapped tarzı analiz sonuçlarını gösterme - Premium kontrolü ile
  Future<void> _showSummaryViewWithPremiumCheck() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final user = authViewModel.user;
    final bool isPremium = user?.actualIsPremium ?? false;
    final premiumService = PremiumService();
    
    // Eğer sonuçlar boşsa, önbellekte veri var mı kontrol et
    if (_summaryData.isEmpty) {
      await _loadCachedSummaryData();
    }
    
    // Yine boşsa analiz yapılamamış demektir
    if (_summaryData.isEmpty) {
      setState(() {
        _errorMessage = 'Analiz sonuçları bulunamadı';
      });
      return;
    }
    
    // Premium değilse, kullanım kontrolü
    if (!isPremium) {
      final bool wrappedOpenedOnce = await premiumService.getWrappedOpenedOnce();
      
      if (!wrappedOpenedOnce) {
        // İlk kullanım - durumu güncelle
        await premiumService.setWrappedOpenedOnce();
        
        // Sonuçları önbelleğe kaydet
        await _cacheSummaryData();
        
        // Ayrıca Firestore'a da kaydet
        await _wrappedService.saveWrappedAnalysis(
          summaryData: _summaryData,
          fileContent: _fileContent,
          isTxtFile: _isTxtFile,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu özelliği bir kez ücretsiz kullanabilirsiniz.'),
            duration: Duration(seconds: 2),
          ),
        );
        
        // İlk kullanım için eski metodu çağır
        _showSummaryView();
      } else {
        // Kullanım hakkı dolmuşsa premium dialog göster
        showPremiumInfoDialog(context, PremiumFeature.WRAPPED_ANALYSIS);
      }
    } else {
      // Premium kullanıcı için normal gösterimi çağır
      // Her seferinde önbelleğe kaydet
      await _cacheSummaryData();
      
      // Ayrıca Firestore'a da kaydet
      await _wrappedService.saveWrappedAnalysis(
        summaryData: _summaryData,
        fileContent: _fileContent,
        isTxtFile: _isTxtFile,
      );
      
      _showSummaryView();
    }
  }
  
  // Önbellekteki sonuçları yükleme
  Future<void> _loadCachedSummaryData() async {
    try {
      _logger.i('Önbellekten wrapped analiz sonuçları yükleniyor');
      
      // Önce Firestore'dan yüklemeyi dene
      final wrappedData = await _wrappedService.getWrappedAnalysis();
      
      if (wrappedData != null) {
        setState(() {
          _summaryData = wrappedData['summaryData'] as List<Map<String, String>>;
          _fileContent = wrappedData['fileContent'] as String;
          _isTxtFile = wrappedData['isTxtFile'] as bool;
        });
        
        _logger.i('Firestore\'dan ${_summaryData.length} analiz sonucu yüklendi');
        return;
      }
      
      // Firestore'da veri yoksa, SharedPreferences'a bak
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Önbellekten veri kontrolü
      final String? cachedDataJson = prefs.getString(WRAPPED_CACHE_KEY);
      final String? cachedContent = prefs.getString(WRAPPED_CACHE_CONTENT_KEY);
      
      if (cachedDataJson != null && cachedDataJson.isNotEmpty) {
        // Kayıtlı içerik ve mevcut içerik kontrolü
        if (cachedContent != null && _fileContent.isNotEmpty && cachedContent == _fileContent) {
          _logger.i('Mevcut dosya içeriği önbellekteki ile aynı, önbellekten sonuçlar yükleniyor');
          
          try {
            final List<dynamic> decodedData = jsonDecode(cachedDataJson);
            final loadedSummaryData = List<Map<String, String>>.from(
              decodedData.map((item) => Map<String, String>.from(item))
            );
            
            setState(() {
              _summaryData = loadedSummaryData;
            });
            
            _logger.i('Önbellekten ${_summaryData.length} analiz sonucu yüklendi');
            
            // SharedPreferences'tan yüklenen verileri Firestore'a da kaydet
            await _wrappedService.saveWrappedAnalysis(
              summaryData: _summaryData,
              fileContent: _fileContent,
              isTxtFile: _isTxtFile,
            );
          } catch (e) {
            _logger.e('Önbellek verisi ayrıştırma hatası', e);
            setState(() {
              _summaryData = [];
            });
          }
        } else {
          _logger.i('Dosya içeriği değişmiş veya kayıtlı değil');
          setState(() {
            _summaryData = [];
          });
        }
      } else {
        _logger.i('Önbellekte veri bulunamadı');
        setState(() {
          _summaryData = [];
        });
      }
    } catch (e) {
      _logger.e('Önbellek okuma hatası', e);
      setState(() {
        _summaryData = [];
      });
    }
  }
  
  // Sonuçları önbelleğe kaydetme (eski yöntem - geriye uyumluluk için)
  Future<void> _cacheSummaryData() async {
    try {
      if (_summaryData.isEmpty || _fileContent.isEmpty) {
        _logger.w('Kaydedilecek analiz sonucu veya dosya içeriği yok');
        return;
      }
      
      _logger.i('Wrapped analiz sonuçları önbelleğe kaydediliyor');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Sonuçları JSON'a dönüştür
      final String encodedData = jsonEncode(_summaryData);
      
      // Sonuçları, ilgili dosya içeriğini ve .txt dosyası bayrağını kaydet
      await prefs.setString(WRAPPED_CACHE_KEY, encodedData);
      await prefs.setString(WRAPPED_CACHE_CONTENT_KEY, _fileContent);
      await prefs.setBool(WRAPPED_IS_TXT_KEY, _isTxtFile);
      
      _logger.i('${_summaryData.length} analiz sonucu önbelleğe kaydedildi');
    } catch (e) {
      _logger.e('Önbelleğe kaydetme hatası', e);
    }
  }
  
  void _showSummaryView() {
    if (_summaryData.isEmpty) {
      setState(() {
        _errorMessage = 'Gösterilecek analiz sonucu bulunamadı.';
      });
      return;
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => KonusmaSummaryView(
          summaryData: _summaryData,
        ),
      ),
    );
  }
  
  void _showSummaryViewDirect() {
    _showSummaryView();
  }
  
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isAnalyzing, // Analiz sırasında doğrudan çıkışı engelle
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        
        // Analiz devam ediyorsa kullanıcıya sor
        if (_isAnalyzing) {
          final bool? shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Analiz Devam Ediyor'),
              content: const Text(
                'Analiz işlemi devam ediyor. Eğer çıkarsanız analiz sonlandırılacaktır. '
                'Çıkmak istediğinizden emin misiniz?'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('İptal'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Çık'),
                ),
              ],
            ),
          );
          
          if (shouldPop == true) {
            // Analizi iptal et ve çık
            _cancelAnalysis();
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Konuşma Analizi'),
          backgroundColor: const Color(0xFF6A11CB),
          foregroundColor: Colors.white,
          actions: [
            // Tüm verileri sıfırla butonu
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Tüm Verileri Sıfırla',
              onPressed: () {
                // Silme işlemi öncesi onay al
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Tüm Verileri Sıfırla'),
                    content: const Text(
                      'Tüm analiz verileri silinecek ve wrapped görünümü kaldırılacak. Bu işlem geri alınamaz. Devam etmek istiyor musunuz?'
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('İptal'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _resetAllData();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Sıfırla'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: FutureBuilder(
          // Future değeri olarak verilerin yüklenmesini bekle
          future: _ensureDataLoaded(),
          builder: (context, snapshot) {
            // Veriler yüklenirken yükleme göstergesi göster
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  ),
                ),
                child: const Center(
                  child: YuklemeAnimasyonu(
                    renk: Colors.white,
                    boyut: 40.0,
                  ),
                ),
              );
            }
            
            // Veriler yüklendikten sonra ana içeriği göster
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Üst bilgi kartı
                      Card(
                        elevation: 8,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Wrapped Tarzı Konuşma Analizi',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6A11CB),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Bu analiz aracı, seçtiğiniz .txt dosyasındaki konuşma verisini analiz ederek '
                                'eğlenceli ve istatistiksel içgörüler sunar. Konuşmalarınızdaki ilginç '
                                'detayları keşfedin!',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Dosya seçim butonu
                              ElevatedButton.icon(
                                onPressed: _isAnalyzing ? null : _selectFile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6A11CB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.file_upload),
                                label: Text(
                                  _selectedFile != null 
                                      ? 'Dosyayı Değiştir' 
                                      : 'TXT Dosyası Seç',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              
                                            if (_selectedFile != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Seçilen Dosya: ${_selectedFile!.path.split('/').last}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (_isParticipantsExtracted && _selectedParticipant != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A11CB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF6A11CB).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person,
                          size: 16,
                          color: Color(0xFF6A11CB),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Seçilen: $_selectedParticipant',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6A11CB),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _showParticipantSelectionDialog(),
                          child: const Icon(
                            Icons.edit,
                            size: 14,
                            color: Color(0xFF6A11CB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ]
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Dosya içeriği önizleme ve Analiz Başlat butonu
                      if (_selectedFile != null && _fileContent.isNotEmpty && _summaryData.isEmpty) ...[
                        Card(
                          elevation: 4,
                          color: Colors.white.withOpacity(0.9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Dosya Önizleme',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6A11CB),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  height: 120,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Text(
                                      _fileContent.length > 1000 
                                          ? '${_fileContent.substring(0, 1000)}...' 
                                          : _fileContent,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                                                  // Analiz Başlat ve Başka Dosya Seç Butonları
                        Row(
                          children: [
                            // Analiz Başlat Butonu
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: (_isAnalyzing || !_isParticipantsExtracted || _selectedParticipant == null) ? null : _analyzeChatContent,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF9D3FFF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 8,
                                ),
                                icon: _isAnalyzing 
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: YuklemeAnimasyonu(
                                          renk: Colors.white,
                                          boyut: 20.0,
                                        ),
                                      )
                                    : const Icon(Icons.analytics),
                                label: Text(
                                  _isAnalyzing ? 'Analiz Ediliyor...' : 'Analizi Başlat',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            // Başka Dosya Seç Butonu
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isAnalyzing ? null : () {
                                  setState(() {
                                    _selectedFile = null;
                                    _fileContent = '';
                                    _summaryData = [];
                                    _errorMessage = '';
                                    _isTxtFile = false;
                                    _participants = [];
                                    _selectedParticipant = null;
                                    _isParticipantsExtracted = false;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 4,
                                ),
                                icon: const Icon(Icons.folder_open, size: 20),
                                label: const Text(
                                  'Başka Dosya',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      // Spotify Wrapped tarzı analiz sonuçları butonu - SADECE .txt analizi yapıldığında gösterilir
                      if (_summaryData.isNotEmpty && _isTxtFile) ...[
                        const SizedBox(height: 24),
                        
                        Card(
                          elevation: 8,
                          color: const Color(0xFF9D3FFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Stack(
                            children: [
                              InkWell(
                                onTap: () => _showWrappedAnalysisFromCache(),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.auto_awesome,
                                          color: Colors.white,
                                          size: 36,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Konuşma Wrapped',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Daha önce analiz edilmiş txt dosyanızın wrapped sonuçlarını görmek için tıklayın!',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'Göster',
                                          style: TextStyle(
                                            color: Color(0xFF9D3FFF),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Kilit ikonu için FutureBuilder kullan, ama pozisyonu değiştirme
                              FutureBuilder<bool>(
                                future: _checkWrappedAccess(),
                                builder: (context, snapshot) {
                                  final bool isLocked = snapshot.data == false;
                                  if (!isLocked) return const SizedBox.shrink();
                                  
                                  return Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.lock,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Hata Mesajı
                      if (_errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(
                                    color: Colors.red.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const Spacer(),
                      
                      // Alt Bilgi
                      Text(
                        'Bu analiz yapay zeka kullanılarak gerçekleştirilir ve sonuçlar tamamen eğlence amaçlıdır.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Verilerin yüklenmesini sağlayan metot
  Future<bool> _ensureDataLoaded() async {
    // Eğer veriler henüz yüklenmemişse yüklemeyi bekle
    if (_summaryData.isEmpty) {
      try {
        // Önce Firestore'dan kontrol et
        final wrappedData = await _wrappedService.getWrappedAnalysis();
        
        if (wrappedData != null) {
          setState(() {
            _summaryData = wrappedData['summaryData'] as List<Map<String, String>>;
            _fileContent = wrappedData['fileContent'] as String;
            _isTxtFile = wrappedData['isTxtFile'] as bool;
          });
          
          _logger.i('_ensureDataLoaded: Firestore\'dan ${_summaryData.length} analiz sonucu yüklendi');
          return true;
        }
        
        // SharedPreferences'tan kontrol et
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final String? cachedDataJson = prefs.getString(WRAPPED_CACHE_KEY);
        
        if (cachedDataJson != null && cachedDataJson.isNotEmpty) {
          try {
            final List<dynamic> decodedData = jsonDecode(cachedDataJson);
            final loadedSummaryData = List<Map<String, String>>.from(
              decodedData.map((item) => Map<String, String>.from(item))
            );
            
            final String? cachedContent = prefs.getString(WRAPPED_CACHE_CONTENT_KEY);
            final bool isTxtFile = prefs.getBool(WRAPPED_IS_TXT_KEY) ?? false;
            
            setState(() {
              _summaryData = loadedSummaryData;
              if (cachedContent != null) {
                _fileContent = cachedContent;
              }
              _isTxtFile = isTxtFile;
            });
            
            _logger.i('_ensureDataLoaded: SharedPreferences\'dan ${_summaryData.length} analiz sonucu yüklendi');
            
            // SharedPreferences'tan yüklenen verileri Firestore'a kaydet
            if (_summaryData.isNotEmpty && _fileContent.isNotEmpty) {
              await _wrappedService.saveWrappedAnalysis(
                summaryData: _summaryData,
                fileContent: _fileContent,
                isTxtFile: _isTxtFile,
              );
            }
            
            return true;
          } catch (e) {
            _logger.e('_ensureDataLoaded: Veri yükleme hatası', e);
          }
        }
      } catch (e) {
        _logger.e('_ensureDataLoaded: Hata', e);
      }
    }
    
    return true; // Her durumda yükleme tamamlandı kabul et
  }

  // Wrapped erişim durumunu kontrol et
  Future<bool> _checkWrappedAccess() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final bool isPremium = authViewModel.isPremium;
    final premiumService = PremiumService();
    
    if (isPremium) {
      return true; // Premium kullanıcılar her zaman erişebilir
    }
    
    // Premium değilse, bir kez açabilme kontrolü
    final bool wrappedOpenedOnce = await premiumService.getWrappedOpenedOnce();
    return !wrappedOpenedOnce; // Henüz açılmamışsa true, açılmışsa false döndür
  }

  // Tüm verileri sıfırla
  Future<void> _resetAllData() async {
    try {
      // Önbellekteki verileri temizle
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(WRAPPED_CACHE_KEY);
      await prefs.remove(WRAPPED_CACHE_CONTENT_KEY);
      await prefs.remove(WRAPPED_IS_TXT_KEY);
      
      // Firestore'daki wrapped analiz verilerini sil
      await _wrappedService.deleteWrappedAnalysis();
      
      // Değişkenleri sıfırla
      setState(() {
        _selectedFile = null;
        _fileContent = '';
        _summaryData = [];
        _isTxtFile = false;
        _errorMessage = '';
        _participants = [];
        _selectedParticipant = null;
        _isParticipantsExtracted = false;
      });
      
      _logger.i('Tüm veriler başarıyla sıfırlandı');
      
      // Kullanıcıya bilgi ver
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tüm veriler sıfırlandı'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _logger.e('Veri sıfırlama hatası', e);
      setState(() {
        _errorMessage = 'Veriler sıfırlanırken bir hata oluştu: $e';
      });
    }
  }
}