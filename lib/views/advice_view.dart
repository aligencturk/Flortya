import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/advice_viewmodel.dart';
import '../services/logger_service.dart';
import '../utils/loading_indicator.dart';
import '../widgets/message_coach_card.dart';
import '../utils/feedback_utils.dart';
import '../models/message_coach_analysis.dart';

class AdviceView extends StatefulWidget {
  const AdviceView({Key? key}) : super(key: key);

  @override
  State<AdviceView> createState() => _AdviceViewState();
}

class _AdviceViewState extends State<AdviceView> {
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;
  bool _imageMode = false;
  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  final _logger = LoggerService();

  @override
  void initState() {
    super.initState();
    
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
    super.dispose();
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
      });
      
      try {
        // TODO: Görsel OCR işlemi burada yapılacak
        // Şimdilik mockup bir mesaj oluşturalım
        final messageText = "Görüntüden metinler çıkarılacak...";
        
        // AdviceViewModel'e mesajı gönder
        final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
        await adviceViewModel.analyzeMesaj(messageText, userId);
        
        setState(() {
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        FeedbackUtils.showErrorFeedback(
          context, 
          'Görsel analiz edilirken bir hata oluştu: $e'
        );
      }
    } else {
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
      });
      
      try {
        // AdviceViewModel'e mesajı gönder
        final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
        await adviceViewModel.analyzeMesaj(messageText, userId);
        
        // İşlem başarılı olduysa mesaj kutusunu temizle
        _messageController.clear();
        
        setState(() {
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        FeedbackUtils.showErrorFeedback(
          context, 
          'Mesaj analiz edilirken bir hata oluştu: $e'
        );
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
          // Yükleniyor göstergesi
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
          
          // Ana sayfa - MesajKocuCard ve analiz sonuçları
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mesaj Koçu kartı
                const MesajKocuCard(),
                
                const SizedBox(height: 24),
                
                // Kalan ücretsiz analiz sayısı
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Kalan Ücretsiz Analiz:',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${MesajKocuAnalizi.ucretlizAnalizSayisi - viewModel.ucretlizAnalizSayisi}/${MesajKocuAnalizi.ucretlizAnalizSayisi}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: 1 - (viewModel.ucretlizAnalizSayisi / MesajKocuAnalizi.ucretlizAnalizSayisi),
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            viewModel.analizHakkiVar ? const Color(0xFF9D3FFF) : Colors.red,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Mesaj girişi veya görsel yükleme
                _imageMode ? _buildImageUploadSection() : _buildMessageInputSection(),
                
                const SizedBox(height: 24),
                
                // Analiz butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: viewModel.analizHakkiVar ? _analyzeMessage : null,
                    icon: const Icon(Icons.psychology_alt),
                    label: const Text(
                      'Analiz Et',
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
                      disabledBackgroundColor: Colors.grey[800],
                      disabledForegroundColor: Colors.grey[400],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Hata mesajı varsa göster
                if (viewModel.errorMessage != null)
                  Container(
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
                          viewModel.errorMessage!,
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
                            },
                            child: const Text('Tamam'),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Analiz sonuçları (hasAnalizi kontrolü ile)
                if (viewModel.hasAnalizi)
                  _buildAnalysisResults(viewModel.mesajAnalizi!),
              ],
            ),
          );
        },
      ),
    );
  }
  
  // Mesaj giriş alanı
  Widget _buildMessageInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mesajlaşma İçeriğini Yapıştır',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            style: TextStyle(color: Colors.white.withOpacity(0.9)),
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Analiz etmek istediğin mesajlaşmayı buraya yapıştır...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: const Color(0xFF9D3FFF), width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }
  
  // Görsel yükleme alanı
  Widget _buildImageUploadSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mesajlaşma Ekran Görüntüleri',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          
          // Seçilen görseller varsa göster
          if (_selectedImages.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImages[index],
                            fit: BoxFit.cover,
                            height: 100,
                            width: 100,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Görsel yükleme butonları
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galeriden Seç'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Fotoğraf Çek'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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