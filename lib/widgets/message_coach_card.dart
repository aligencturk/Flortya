import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_selector/file_selector.dart';
import '../models/message_coach_analysis.dart';
import '../viewmodels/advice_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/message_viewmodel.dart';
import '../utils/loading_indicator.dart';
import '../utils/feedback_utils.dart';

class MesajKocuCard extends StatefulWidget {
  const MesajKocuCard({Key? key}) : super(key: key);

  @override
  State<MesajKocuCard> createState() => _MesajKocuCardState();
}

class _MesajKocuCardState extends State<MesajKocuCard> {
  final TextEditingController _mesajController = TextEditingController();
  bool _isExpanded = false;
  File? _selectedImage; // Seçilen resim dosyası

  @override
  void dispose() {
    _mesajController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adviceViewModel = Provider.of<AdviceViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF352269),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            const Row(
              children: [
                Icon(Icons.psychology, color: Color(0xFF9D3FFF), size: 24),
                SizedBox(width: 8),
                Text(
                  'Mesaj Koçu',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Açıklama
            if (!adviceViewModel.hasAnalizi)
              const Text(
                'Mesajını analiz edelim! Yazdığın mesajın duygusal etkisini ölçüp, daha etkili iletişim kurman için tavsiyelerde bulunalım.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Kalan analiz hakkı
            if (!adviceViewModel.hasAnalizi)
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Kalan ücretsiz analiz: ${MesajKocuAnalizi.ucretlizAnalizSayisi - adviceViewModel.ucretlizAnalizSayisi}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 16),
            
            // Mesaj girişi (analiz sonucu yoksa göster)
            if (!adviceViewModel.hasAnalizi) ...[
              _buildMessageInputArea(context),
            ],
            
            // Yükleniyor göstergesi
            if (adviceViewModel.isAnalyzing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: YuklemeAnimasyonu(renk: Color(0xFF9D3FFF)),
                ),
              ),
            
            // Hata mesajı
            if (adviceViewModel.errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        adviceViewModel.errorMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Sade rehber metni (her zaman göster - sonuçlar yokken)
            if (!adviceViewModel.hasAnalizi) ... [
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Mesaj Koçu, yazdığın mesajların duygusal etkisini analiz eder, karşı tarafın olası yaklaşımını değerlendirir ve sana daha etkili iletişim önerileri sunar.',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.4,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fade(duration: 300.ms).slideY(begin: 0.2, end: 0, duration: 300.ms, curve: Curves.easeOutQuad);
  }

  Widget _buildMessageInputArea(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), 
      decoration: BoxDecoration(
        color: const Color(0xFF462B8C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.4)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _mesajController,
            maxLines: 4,
            minLines: 1,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Analiz etmek istediğiniz mesajı yazın',
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          
          // Seçilen görsel varsa önizleme göster
          if (_selectedImage != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImage = null;
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
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.image, color: Colors.white70),
                tooltip: 'Görsel ekle',
                onPressed: () => _pickImageForAnalysis(context),
              ),
              ElevatedButton(
                onPressed: () async {
                  final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
                  final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
                  
                  if (_selectedImage != null) {
                    // Görsel analizi başlat
                    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
                    await messageViewModel.analyzeImageMessage(_selectedImage!);
                    
                    // Analiz sonrası görsel temizlenir - mounted kontrolü eklendi
                    if (mounted) {
                      setState(() {
                        _selectedImage = null;
                      });
                    }
                    
                    if (mounted) {
                      FeedbackUtils.showSuccessFeedback(
                        context, 
                        'Görsel başarıyla analiz edildi'
                      );
                    }
                  } else if (_mesajController.text.trim().isNotEmpty) {
                    // Metin analizi başlat
                    await adviceViewModel.analyzeMesaj(
                      _mesajController.text,
                      authViewModel.user?.id ?? '',
                    );
                  } else {
                    // Hata mesajı göster
                    if (mounted) {
                      FeedbackUtils.showErrorFeedback(
                        context, 
                        'Lütfen analiz için metin girin veya görsel yükleyin'
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9D3FFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  'Analiz Et',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Görsel seçme ve analiz etme
  Future<void> _pickImageForAnalysis(BuildContext context) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    if (authViewModel.user == null) {
      FeedbackUtils.showErrorFeedback(
        context, 
        'Lütfen önce giriş yapın'
      );
      return;
    }
    
    try {
      // XTypeGroup ile resim dosya tipleri tanımlama
      final XTypeGroup imageTypeGroup = XTypeGroup(
        label: 'Görseller',
        extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
        mimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp'],
        uniformTypeIdentifiers: ['public.image'],
      );
      
      // file_selector ile dosya seçimi
      final XFile? pickedFile = await openFile(
        acceptedTypeGroups: [imageTypeGroup],
      );
      
      // Kullanıcı dosya seçmediyse
      if (pickedFile == null) {
        return;
      }
      
      // Dosya geçerlilik kontrolü
      final File file = File(pickedFile.path);
      final bool fileExists = await file.exists();
      
      if (!fileExists) {
        FeedbackUtils.showErrorFeedback(
          context, 
          'Seçilen görsel dosyasına erişilemiyor'
        );
        return;
      }
      
      final int fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        FeedbackUtils.showErrorFeedback(
          context, 
          'Dosya boyutu 10MB\'dan küçük olmalıdır'
        );
        return;
      }
      
      // Dosya uzantısını kontrol et
      final String extension = pickedFile.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
        FeedbackUtils.showErrorFeedback(
          context, 
          'Desteklenmeyen dosya formatı. Lütfen bir görsel seçin.'
        );
        return;
      }
      
      // Seçilen görseli state'e kaydet ve önizleme için göster - mounted kontrolü eklendi
      if (mounted) {
        setState(() {
          _selectedImage = file;
        });
      }
      
    } catch (e) {
      if (mounted) {
        FeedbackUtils.showErrorFeedback(
          context, 
          'Görsel seçme işlemi sırasında hata: $e'
        );
      }
    }
  }
} 