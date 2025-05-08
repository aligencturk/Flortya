import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../models/message_analysis_result.dart';
import '../utils/utils.dart';

/// Mesaj analiz sonuçlarını gösteren kart bileşeni
class MessageAnalysisResultCard extends StatelessWidget {
  final MessageAnalysisResult sonuc;
  final VoidCallback? onYenidenAnalizTalepEdildi;
  
  const MessageAnalysisResultCard({
    super.key,
    required this.sonuc,
    this.onYenidenAnalizTalepEdildi,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mesaj Analizi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: onYenidenAnalizTalepEdildi,
                  tooltip: 'Yeniden Analiz Et',
                ),
              ],
            ),
            const Divider(),
            
            // Genel Sohbet Havası
            if (sonuc.sohbetGenelHavasi != null) ...[
              _buildInfoRow(
                baslik: 'Sohbet Genel Havası:',
                deger: sonuc.sohbetGenelHavasi!,
                renk: _getHavaRengi(sonuc.sohbetGenelHavasi!),
              ),
              const SizedBox(height: 12),
            ],
            
            // Son Mesaj Tonu
            if (sonuc.sonMesajTonu != null) ...[
              _buildInfoRow(
                baslik: 'Son Mesaj Tonu:',
                deger: sonuc.sonMesajTonu!,
                renk: _getTonRengi(sonuc.sonMesajTonu!),
              ),
              const SizedBox(height: 12),
            ],
            
            // Etki Değerleri
            _buildEtkiler(sonuc.etki),
            const SizedBox(height: 16),
            
            // Tavsiyeler
            if (sonuc.anlikTavsiye != null) ...[
              _buildTavsiye(
                baslik: 'Tavsiye:',
                icerik: sonuc.anlikTavsiye!,
              ),
              const SizedBox(height: 12),
            ],
            
            // Strateji
            if (sonuc.strateji != null) ...[
              _buildTavsiye(
                baslik: 'Strateji:',
                icerik: sonuc.strateji!,
              ),
              const SizedBox(height: 12),
            ],
            
            // Yeniden Yazım
            if (sonuc.yenidenYazim != null) ...[
              _buildKopyalanabilirIcerik(
                context: context,
                baslik: 'Önerilen Mesaj:',
                icerik: sonuc.yenidenYazim!,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // Bilgi satırı
  Widget _buildInfoRow({
    required String baslik,
    required String deger,
    required Color renk,
  }) {
    return Row(
      children: [
        Text(
          baslik,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: renk.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: renk.withOpacity(0.3)),
          ),
          child: Text(
            deger,
            style: TextStyle(
              color: renk,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
  
  // Tavsiye metni
  Widget _buildTavsiye({
    required String baslik,
    required String icerik,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          baslik,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(icerik),
      ],
    );
  }
  
  // Kopyalanabilir içerik
  Widget _buildKopyalanabilirIcerik({
    required BuildContext context,
    required String baslik,
    required String icerik,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              baslik,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: icerik)).then((_) {
                  Utils.showSuccessFeedback(
                    context, 
                    'Metin panoya kopyalandı'
                  );
                });
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.copy,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Kopyala',
                      style: TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Text(icerik),
        ),
      ],
    );
  }
  
  // Etki değerleri widget'ı
  Widget _buildEtkiler(Map<String, int> etkiler) {
    // Değerleri sırala
    final List<MapEntry<String, int>> siralanmisEtkiler = etkiler.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Etki Analizi:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...siralanmisEtkiler.map((entry) {
          final etiket = entry.key;
          final deger = entry.value;
          
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _capitalizeFirst(etiket),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    '%$deger',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getEtkiRengi(etiket),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearPercentIndicator(
                lineHeight: 8.0,
                percent: deger / 100,
                animation: true,
                animationDuration: 800,
                backgroundColor: Colors.grey.withOpacity(0.2),
                progressColor: _getEtkiRengi(etiket),
                barRadius: const Radius.circular(4),
              ),
              const SizedBox(height: 8),
            ],
          );
        }),
      ],
    );
  }
  
  // Sohbet havası rengi
  Color _getHavaRengi(String hava) {
    switch (hava.toLowerCase()) {
      case 'soğuk':
        return Colors.blue;
      case 'samimi':
        return Colors.green;
      case 'pasif-agresif':
        return Colors.orange;
      case 'ilgisiz':
        return Colors.grey;
      case 'ilgili':
        return Colors.teal;
      default:
        return Colors.purple;
    }
  }
  
  // Ton rengi
  Color _getTonRengi(String ton) {
    switch (ton.toLowerCase()) {
      case 'sert':
        return Colors.red;
      case 'soğuk':
        return Colors.blue;
      case 'sempatik':
        return Colors.green;
      case 'umursamaz':
        return Colors.grey;
      case 'ilgisiz':
        return Colors.blueGrey;
      case 'nötr':
        return Colors.amber;
      case 'samimi':
        return Colors.teal;
      case 'pasif-agresif':
        return Colors.deepOrange;
      default:
        return Colors.purple;
    }
  }
  
  // Etki rengi
  Color _getEtkiRengi(String etki) {
    switch (etki.toLowerCase()) {
      case 'sempatik':
      case 'olumlu':
      case 'positive':
        return Colors.green;
      case 'kararsız':
      case 'hesitant':
      case 'neutral':
      case 'nötr':
        return Colors.orange;
      case 'endişeli':
      case 'negative':
      case 'olumsuz':
        return Colors.red;
      default:
        return Colors.purple;
    }
  }
  
  // String'in ilk harfini büyük yap
  String _capitalizeFirst(String text) {
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }
} 