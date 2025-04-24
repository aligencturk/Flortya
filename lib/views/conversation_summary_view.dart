import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import '../services/ai_service.dart';
import '../services/logger_service.dart';
import '../utils/loading_indicator.dart';

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
              
              const SizedBox(height: 60),
              
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
        _showSummaryView();
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
                    child: InkWell(
                      onTap: _showSummaryView,
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
} 