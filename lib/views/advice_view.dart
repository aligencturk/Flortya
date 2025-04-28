import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/advice_viewmodel.dart';
import '../services/logger_service.dart';
import '../utils/loading_indicator.dart';
import '../widgets/message_coach_card.dart';
import '../utils/feedback_utils.dart';
import '../models/message_coach_analysis.dart';
import 'dart:async';

class AdviceView extends StatefulWidget {
  const AdviceView({Key? key}) : super(key: key);

  @override
  State<AdviceView> createState() => _AdviceViewState();
}

class _AdviceViewState extends State<AdviceView> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _isLoading = false;
  bool _imageMode = false;
  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  final _logger = LoggerService();
  Timer? _analysisTimer;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // Mesaj alanındaki odak değişikliğini dinle
    _messageFocusNode.addListener(_onFocusChange);
    
    // Metin değişikliğini dinle
    _messageController.addListener(_onTextChange);
    
    // Sayfa her açıldığında verileri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
      
      setState(() {
        _isLoading = true;
      });
      
      try {
        // Kullanıcı giriş yapmışsa analiz sayısını yükle
        if (authViewModel.currentUser != null) {
          await adviceViewModel.loadAnalysisCount(authViewModel.currentUser!.uid);
        }
        
        setState(() {
          _isLoading = false;
        });
      } catch (e) {
        _logger.e('Veri yükleme hatası: $e');
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.removeListener(_onFocusChange);
    _messageFocusNode.dispose();
    _analysisTimer?.cancel();
    _textRecognizer.close();
    super.dispose();
  }

  // Metin değiştiğinde çağrılır
  void _onTextChange() {
    // Önceki zamanlayıcıyı iptal et
    _analysisTimer?.cancel();
    
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      // Kullanıcı yazımı bitirdiğinde otomatik analiz için 2 saniye bekle
      _analysisTimer = Timer(const Duration(seconds: 2), () {
        _analyzeMessage();
      });
    }
  }
  
  // Odak değiştiğinde çağrılır
  void _onFocusChange() {
    // Odak mesaj alanından çıktıysa ve içerik varsa analiz yap
    if (!_messageFocusNode.hasFocus && _messageController.text.trim().isNotEmpty) {
      _analysisTimer?.cancel(); // Eğer zamanlayıcı çalışıyorsa iptal et
      _analyzeMessage();
    }
  }

  // Görsel seçme (çoklu)
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          for (var image in images) {
            _selectedImages.add(File(image.path));
          }
          _imageMode = true;
        });
      }
    } catch (e) {
      FeedbackUtils.showErrorFeedback(
        context, 
        'Görseller seçilirken bir hata oluştu: $e'
      );
    }
  }

  // Kamera ile fotoğraf çekme
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _selectedImages.add(File(photo.path));
          _imageMode = true;
        });
      }
    } catch (e) {
      FeedbackUtils.showErrorFeedback(
        context, 
        'Fotoğraf çekilirken bir hata oluştu: $e'
      );
    }
  }

  // Analiz yapma
  Future<void> _analyzeMessage() async {
    // Kullanıcı kimliğini al
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final userId = authViewModel.currentUser?.uid;
    
    if (userId == null) {
      FeedbackUtils.showErrorFeedback(
        context, 
        'Lütfen önce giriş yapın'
      );
      return;
    }
    
    // Mesaj içeriğini kontrol et
    if (_imageMode) {
      if (_selectedImages.isEmpty) {
        FeedbackUtils.showErrorFeedback(
          context, 
          'Lütfen en az bir görsel seçin'
        );
        return;
      }
      
      // Görsel modunda OCR işlemi yapılacak
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      try {
        // OCR işlemi
        String extractedText = '';
        for (final imageFile in _selectedImages) {
          final inputImage = InputImage.fromFilePath(imageFile.path);
          final recognizedText = await _textRecognizer.processImage(inputImage);
          extractedText += recognizedText.text + '\n';
        }
        
        extractedText = extractedText.trim();
        _logger.i('OCR Sonucu: ${extractedText.isNotEmpty ? extractedText.substring(0, min(50, extractedText.length)) + "..." : "[BOŞ]"}');

        if (extractedText.isEmpty) {
          FeedbackUtils.showErrorFeedback(
            context, 
            'Görselden metin okunamadı veya metin bulunamadı. Lütfen daha net bir görsel deneyin.'
          );
          Future.microtask(() {
            setState(() {
              _isLoading = false;
            });
          });
          return;
        }
        
        // AdviceViewModel'e mesajı gönder
        final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
        await adviceViewModel.analyzeMesaj(extractedText, userId);
        
        Future.microtask(() {
          setState(() {
            _isLoading = false;
            _selectedImages.clear();
            _imageMode = false;
          });
        });
      } catch (e) {
        _logger.e('Görsel analiz (OCR) hatası: $e');
        Future.microtask(() {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Görsel işlenirken bir hata oluştu: $e';
          });
          FeedbackUtils.showErrorFeedback(
            context, 
            'Görsel işlenirken bir hata oluştu: $e'
          );
        });
      }
    } else {
      // Metin modu
      final messageText = _messageController.text.trim();
      if (messageText.isEmpty) {
        FeedbackUtils.showErrorFeedback(
          context, 
          'Lütfen bir mesaj girin'
        );
        return;
      }
      
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      try {
        final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
        await adviceViewModel.analyzeMesaj(messageText, userId);
        
        Future.microtask(() {
          setState(() {
            _isLoading = false;
          });
          
          if (mounted) {
            _messageController.clear();
          }
        });
      } catch (e) {
        _logger.e('Metin analizi hatası: $e');
        Future.microtask(() {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Mesaj analiz edilirken bir hata oluştu: $e';
          });
          FeedbackUtils.showErrorFeedback(
            context, 
            'Mesaj analiz edilirken bir hata oluştu: $e'
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF9D3FFF),
        title: const Text(
          'Mesaj Koçu',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          // Mod değiştirme butonu
          IconButton(
            icon: Icon(_imageMode ? Icons.text_fields : Icons.image),
            onPressed: () {
              setState(() {
                _imageMode = !_imageMode;
                // Mod değiştiğinde içerikleri temizle
                if (_imageMode) {
                  _messageController.clear();
                } else {
                  _selectedImages.clear();
                }
              });
            },
            tooltip: _imageMode ? 'Metin Moduna Geç' : 'Görsel Moduna Geç',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF121212),
      body: Consumer<AdviceViewModel>(
        builder: (context, viewModel, child) {
          // DEBUG: Analiz durumunu kontrol edelim
          print('🔍 AdviceView build - isLoading=$_isLoading, viewModel.isAnalyzing=${viewModel.isAnalyzing}, hasAnalizi=${viewModel.hasAnalizi}, mesajAnalizi=${viewModel.mesajAnalizi != null}, error=${viewModel.errorMessage}');
          
          // Yükleniyor göstergesi (View'ın kendi isLoading'i VEYA ViewModel'in isAnalyzing durumu)
          if (_isLoading || viewModel.isAnalyzing) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const YuklemeAnimasyonu(renk: Color(0xFF9D3FFF)),
                  const SizedBox(height: 16),
                  Text(
                    'Mesajınız analiz ediliyor...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }
          
          // Ana sayfa
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sol üst köşede kullanıcı selamlama bölümü
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Consumer<AuthViewModel>(
                    builder: (context, authViewModel, _) {
                      final displayName = authViewModel.currentUser?.displayName ?? 'Ziyaretçi';
                      return Text(
                        'Merhaba, $displayName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      );
                    },
                  ),
                ),
                
                // Mesaj girişi veya görsel yükleme - Ana fonksiyonu direkt olarak en üste taşıyorum
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D3FFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analiz yapmak için mesajını yaz veya görsel yükle',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Açıklama
                      Text(
                        'Mesaj Koçu kartı aracılığıyla analiz yapabilirsiniz.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Kalan ücretsiz analiz sayısı
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: Colors.white.withOpacity(0.7),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kalan ücretsiz analiz: ${MesajKocuAnalizi.ucretlizAnalizSayisi - viewModel.ucretlizAnalizSayisi}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Mesaj Koçu kartı (en sonda gösterelim)
                const MesajKocuCard(),
                
                const SizedBox(height: 24),
                
                // Hata Mesajı Bölümü (ViewModel'den gelen veya View'ın kendi hatası)
                if (viewModel.errorMessage != null || _errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 8),
                              const Text(
                                'Hata',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            viewModel.errorMessage ?? _errorMessage ?? 'Bilinmeyen bir hata oluştu.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                viewModel.resetError();
                                setState(() {
                                  _errorMessage = null;
                                });
                              },
                              child: const Text('Tamam'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Analiz sonuçları 
                if (viewModel.hasAnalizi && viewModel.mesajAnalizi != null)
                  _buildAnalysisResults(viewModel.mesajAnalizi!),
              ],
            ),
          );
        },
      ),
    );
  }
  
  // Analiz sonuçları bölümü
  Widget _buildAnalysisResults(MesajKocuAnalizi analiz) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mesaj Analiz Sonuçları',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          
          // 1. Mesaj Etki Yüzdeleri
          _buildAnalysisSection(
            '📊 Mesaj Etki Yüzdeleri',
            child: _buildEtkiYuzdeleri(analiz.etki),
          ),
          
          // 2. Anlık Tavsiye
          _buildAnalysisSection(
            '💬 Anlık Tavsiye',
            content: analiz.anlikTavsiye ?? 'Tavsiye bulunamadı',
          ),
          
          // 3. Yeniden Yazım Önerisi
          _buildAnalysisSection(
            '✍️ Rewrite Önerisi',
            content: analiz.yenidenYazim ?? 'Öneri bulunamadı',
          ),
          
          // 4. Karşı Taraf Yorumu
          _buildAnalysisSection(
            '🔍 Karşı Taraf Yorumu',
            content: analiz.karsiTarafYorumu ?? 'Yorum bulunamadı',
          ),
          
          // 5. Strateji Önerisi
          _buildAnalysisSection(
            '🧭 Strateji Önerisi',
            content: analiz.strateji ?? 'Strateji bulunamadı',
            showDivider: false,
          ),
          
          const SizedBox(height: 16),
          
          // Yeni Analiz Yap butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Analiz sonucunu sıfırla
                Provider.of<AdviceViewModel>(context, listen: false).resetAnalysisResult();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Yeni Analiz Yap'),
            ),
          ),
        ],
      ),
    );
  }
  
  // Analiz bölümü yapısı
  Widget _buildAnalysisSection(String title, {String? content, Widget? child, bool showDivider = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        if (content != null)
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        if (child != null) child,
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white.withOpacity(0.1)),
          ),
      ],
    );
  }
  
  // Etki yüzdelerini gösteren widget
  Widget _buildEtkiYuzdeleri(Map<String, int> etki) {
    if (etki.isEmpty) {
      return Text(
        'Etki analizi bulunamadı',
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 14,
        ),
      );
    }
    
    // Etki değerlerini azalan sırada sırala
    final List<MapEntry<String, int>> siralanmisEtki = etki.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Column(
      children: siralanmisEtki.map((entry) {
        final String etiket = entry.key;
        final int deger = entry.value;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${etiket.capitalizeFirst}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '%$deger',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: deger / 100,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(_getEtkiRengi(etiket)),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  Color _getEtkiRengi(String etiket) {
    // Farklı etiketler için farklı renkler
    switch (etiket.toLowerCase()) {
      case 'sempatik':
        return Colors.green;
      case 'kararsız':
        return Colors.orange;
      case 'endişeli':
        return Colors.red;
      case 'olumlu':
        return Colors.blue;
      case 'flörtöz':
        return Colors.purple;
      case 'mesafeli':
        return Colors.grey;
      case 'nötr':
        return Colors.blueGrey;
      default:
        return const Color(0xFF9D3FFF); // Uygulama ana rengi
    }
  }
}

// String için extension - capitalizeFirst metodu
extension StringExtension on String {
  String get capitalizeFirst => length > 0 
      ? '${this[0].toUpperCase()}${substring(1)}'
      : '';
}