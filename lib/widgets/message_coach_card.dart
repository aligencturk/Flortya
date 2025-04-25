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
            
            // Analiz sonuçları (analiz sonucu varsa göster)
            if (adviceViewModel.hasAnalizi) ...[
              _buildAnalizSonucu(adviceViewModel.mesajAnalizi!),
              
              const SizedBox(height: 16),
              
              // Yeni analiz butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _mesajController.clear();
                    final viewModel = Provider.of<AdviceViewModel>(context, listen: false);
                    setState(() {
                      _isExpanded = false;
                    });
                    // Analiz sonucunu temizle
                    viewModel.analyzeMesaj('', ''); // Boş analiz için
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Yeni Analiz',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fade(duration: 300.ms).slideY(begin: 0.2, end: 0, duration: 300.ms, curve: Curves.easeOutQuad);
  }

  Widget _buildAnalizSonucu(MesajKocuAnalizi analiz) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mesaj Etki Yüzdeleri
        _buildSectionTitle('Mesaj Etki Yüzdeleri', Icons.analytics_outlined),
        const SizedBox(height: 8),
        if (analiz.etki != null) 
          _buildEtkiCubuklar(analiz.etki!)
        else
          _buildSectionContent('Etki analizi bulunamadı'),
        
        const SizedBox(height: 16),
        
        // Anlık Tavsiye
        _buildSectionTitle('Anlık Tavsiye', Icons.lightbulb_outline),
        const SizedBox(height: 8),
        _buildSectionContent(analiz.oneriler.isNotEmpty ? analiz.oneriler.first : 'Tavsiye bulunamadı'),
        
        const SizedBox(height: 16),
        
        // Yeniden Yazım
        _buildSectionTitle('Yeniden Yazım Önerisi', Icons.edit_outlined),
        const SizedBox(height: 8),
        _buildSectionContent(analiz.yenidenYazim ?? 'Yeniden yazım önerisi bulunmuyor'),
        
        const SizedBox(height: 16),
        
        // Karşı Taraf Analizi
        _buildSectionTitle('Karşı Taraf Analizi', Icons.person_outline),
        const SizedBox(height: 8),
        _buildSectionContent(analiz.analiz),
        
        // İleriye Yönelik Strateji (varsa)
        if (analiz.strateji != null) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('İleriye Yönelik Strateji', Icons.route_outlined),
          const SizedBox(height: 8),
          _buildSectionContent(analiz.strateji!),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF9D3FFF), size: 18),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContent(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        content,
        style: const TextStyle(
          color: Colors.white,
          height: 1.4,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildEtkiCubuklar(Map<String, int> etki) {
    return Column(
      children: etki.entries.map((entry) {
        final duygu = entry.key;
        final yuzde = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    duygu.substring(0, 1).toUpperCase() + duygu.substring(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '%$yuzde',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: yuzde / 100,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(_getEtkiRenk(duygu)),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getEtkiRenk(String duygu) {
    switch (duygu.toLowerCase()) {
      case 'sempatik':
        return Colors.green;
      case 'flörtöz':
        return Colors.pink;
      case 'çekingen':
        return Colors.amber;
      case 'soğuk':
        return Colors.blue;
      case 'kararsız':
        return Colors.orange;
      case 'gergin':
        return Colors.red;
      case 'yoğun':
        return Colors.deepPurple;
      case 'baskıcı':
        return Colors.redAccent;
      default:
        return const Color(0xFF9D3FFF);
    }
  }

  Widget _buildMessageInputArea(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _mesajController,
                  maxLines: 4,
                  minLines: 1,
                  decoration: const InputDecoration(
                    hintText: 'Analiz etmek istediğiniz mesajı yazın',
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.image, color: Colors.blue),
                tooltip: 'Görsel ekle',
                onPressed: () => _pickImageForAnalysis(context),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
              child: ElevatedButton(
                onPressed: () async {
                  if (_mesajController.text.trim().isNotEmpty) {
                    final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
                    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
                    await adviceViewModel.analyzeMesaj(
                      _mesajController.text,
                      authViewModel.user?.id ?? '',
                    );
                  }
                },
                child: const Text('Analiz Et'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Görsel seçme ve analiz etme
  Future<void> _pickImageForAnalysis(BuildContext context) async {
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
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
      
      // Görsel analizi başlat
      await messageViewModel.analyzeImageMessage(file);
      
      // Başarılı mesajı göster
      FeedbackUtils.showSuccessFeedback(
        context, 
        'Görsel başarıyla analiz edildi'
      );
      
    } catch (e) {
      FeedbackUtils.showErrorFeedback(
        context, 
        'Görsel seçme işlemi sırasında hata: $e'
      );
    }
  }
} 