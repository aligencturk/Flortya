import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
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

class KonusmaSummaryView extends StatefulWidget {
  final List<Map<String, String>> summaryData;

  const KonusmaSummaryView({
    Key? key,
    required this.summaryData,
  }) : super(key: key);

  @override
  State<KonusmaSummaryView> createState() => _KonusmaSummaryViewState();
}

class _KonusmaSummaryViewState extends State<KonusmaSummaryView> {
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
    // Her kart için farklı gradient arka plan
    List<List<Color>> gradients = [
      [const Color(0xFF6A11CB), const Color(0xFF2575FC)], // Mor-Mavi
      [const Color(0xFFFF416C), const Color(0xFFFF4B2B)], // Kırmızı
      [const Color(0xFF00C9FF), const Color(0xFF92FE9D)], // Mavi-Yeşil
      [const Color(0xFFFF9A9E), const Color(0xFFFAD0C4)], // Pembe
      [const Color(0xFFA18CD1), const Color(0xFFFBC2EB)], // Mor-Pembe
      [const Color(0xFF1A2980), const Color(0xFF26D0CE)], // Koyu Mavi-Turkuaz
    ];

    final colorIndex = index % gradients.length;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradients[colorIndex],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Stack(
            children: [
              // Sayfa göstergesi
              Positioned(
                top: 16,
                right: 0,
                child: Text(
                  '${index + 1}/${widget.summaryData.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              // Ana içerik
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pırıltılı başlık efekti
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Colors.white, Colors.white.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Yorum metni
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20, 
                        vertical: 16
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        comment,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.5,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Kaydırma göstergesi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Devam etmek için kaydırın',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
                'Konuşma Özeti Tamamlandı!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Konuşmanızdaki önemli analizleri gördünüz. İlişkinizi geliştirmek için bu içgörüleri kullanabilirsiniz.',
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
                  'PDF Olarak Paylaş',
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
                  'Analize Geri Dön',
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

  // Wrapped özelliğinin açık olup olmadığını kontrol et
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
  
  // Wrapped analizini göster - KonusmaSummaryView için
  void _showWrappedSummaryView() {
    if (widget.summaryData.isEmpty) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => KonusmaSummaryView(
          summaryData: widget.summaryData,
        ),
      ),
    );
  }
}

/// Dosya seçme ve sohbet analizi için giriş ekranı
class SohbetAnaliziView extends StatefulWidget {
  const SohbetAnaliziView({Key? key}) : super(key: key);

  @override
  State<SohbetAnaliziView> createState() => _SohbetAnaliziViewState();
}

class _SohbetAnaliziViewState extends State<SohbetAnaliziView> {
  final AiService _aiService = AiService();
  final LoggerService _logger = LoggerService();
  
  File? _selectedFile;
  String _fileContent = '';
  bool _isAnalyzing = false;
  String _errorMessage = '';
  List<Map<String, String>> _summaryData = [];
  bool _isTxtFile = false; // .txt dosyası olup olmadığını takip etmek için
  
  // Cache için değişkenler
  static const String WRAPPED_CACHE_KEY = 'wrappedCacheData';
  static const String WRAPPED_CACHE_CONTENT_KEY = 'wrappedCacheContent';
  
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
        setState(() {
          _fileContent = content;
          _errorMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Dosya okunurken bir hata oluştu: $e';
      });
      _logger.e('Dosya okuma hatası', e);
    }
  }
  
  Future<void> _analyzeChatContent() async {
    if (_fileContent.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen önce bir dosya seçin';
      });
      return;
    }
    
    setState(() {
      _isAnalyzing = true;
      _errorMessage = '';
    });
    
    try {
      final result = await _aiService.analizSohbetVerisi(_fileContent);
      setState(() {
        _summaryData = result;
        _isAnalyzing = false;
      });
      
      if (_summaryData.isNotEmpty) {
        _showSummaryViewWithPremiumCheck();
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
  
  // Wrapped tarzı analiz sonuçlarını gösterme - Premium kontrolü ile
  Future<void> _showSummaryViewWithPremiumCheck() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final bool isPremium = authViewModel.isPremium;
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
      _showSummaryView();
    }
  }
  
  // Önbellekteki sonuçları yükleme
  Future<void> _loadCachedSummaryData() async {
    try {
      _logger.i('Önbellekten wrapped analiz sonuçları yükleniyor');
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
            _summaryData = List<Map<String, String>>.from(
              decodedData.map((item) => Map<String, String>.from(item))
            );
            
            _logger.i('Önbellekten ${_summaryData.length} analiz sonucu yüklendi');
          } catch (e) {
            _logger.e('Önbellek verisi ayrıştırma hatası', e);
            _summaryData = [];
          }
        } else {
          _logger.i('Dosya içeriği değişmiş veya kayıtlı değil, analiz yeniden yapılacak');
          _summaryData = [];
        }
      } else {
        _logger.i('Önbellekte veri bulunamadı');
        _summaryData = [];
      }
    } catch (e) {
      _logger.e('Önbellek okuma hatası', e);
      _summaryData = [];
    }
  }
  
  // Sonuçları önbelleğe kaydetme
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
      
      // Sonuçları ve ilgili dosya içeriğini kaydet
      await prefs.setString(WRAPPED_CACHE_KEY, encodedData);
      await prefs.setString(WRAPPED_CACHE_CONTENT_KEY, _fileContent);
      
      _logger.i('${_summaryData.length} analiz sonucu önbelleğe kaydedildi');
    } catch (e) {
      _logger.e('Önbelleğe kaydetme hatası', e);
    }
  }
  
  void _showSummaryView() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => KonusmaSummaryView(
          summaryData: _summaryData,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konuşma Analizi'),
        backgroundColor: const Color(0xFF6A11CB),
        foregroundColor: Colors.white,
      ),
      body: Container(
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
                  
                  // Analiz Başlat Butonu
                  ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _analyzeChatContent,
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                          onTap: () => _showSummaryViewWithPremiumCheck(),
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
                                  'Spotify Wrapped tarzı analiz sonuçlarını görmek için tıklayın!',
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
      ),
    );
  }

  // Premium bilgilendirme diyaloğunu göster
  void _showWrappedPremiumDialog(BuildContext context) {
    showPremiumInfoDialog(context, PremiumFeature.WRAPPED_ANALYSIS);
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
} 