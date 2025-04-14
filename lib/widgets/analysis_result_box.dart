import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/analysis_result_model.dart';

class AnalysisResultBox extends StatelessWidget {
  final AnalysisResult result;
  final bool showDetailedInfo;
  final VoidCallback? onTap;

  const AnalysisResultBox({
    Key? key,
    required this.result,
    this.showDetailedInfo = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // İçerik Widget'ı
    Widget content = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık Satırı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mesaj Analizi',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Ciddiyet Seviyesi İndikatörü
              _buildSeverityIndicator(context, result.severity),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Temel Analiz Bilgileri
          _buildAnalysisRow(context, 'Duygu:', result.emotion),
          const SizedBox(height: 8),
          _buildAnalysisRow(context, 'Niyet:', result.intent),
          const SizedBox(height: 8),
          _buildAnalysisRow(context, 'Ton:', result.tone),
          
          const SizedBox(height: 16),
          
          // Mesaj Yorumu (her zaman gösterilir)
          if (result.aiResponse.containsKey('mesaj_yorumu') && 
              result.aiResponse['mesaj_yorumu'] != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Mesaj Yorumu',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(result.aiResponse['mesaj_yorumu']),
                ],
              ),
            ),
          ],
          
          // Cevap Önerileri (her zaman gösterilir)
          if (result.aiResponse.containsKey('cevap_onerileri') && 
              result.aiResponse['cevap_onerileri'] != null) ...[
            const SizedBox(height: 16),
            
            Text(
              'Cevap Önerileri:',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            
            ...List.generate(
              (result.aiResponse['cevap_onerileri'] as List).length,
              (index) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        result.aiResponse['cevap_onerileri'][index],
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        // Kopyalama işlevi buraya eklenebilir
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cevap kopyalandı'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      tooltip: 'Kopyala',
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          // Detaylı Bilgiler (şartlı gösterim)
          if (showDetailedInfo) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // AI'ın Ham Cevabı
            Text(
              'Ham AI Analizi:',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                result.aiResponse.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
          
          // "Daha Fazla Göster" Butonu (eğer detaylar gösterilmiyorsa)
          if (!showDetailedInfo && onTap != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.code),
                label: const Text('Teknik Detayları Göster'),
              ),
            ),
          ],
        ],
      ),
    );

    // Ana widget
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: content,
      ),
    )
    .animate()
    .fadeIn(duration: 400.ms)
    .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad);
  }

  // Ciddiyet seviyesi indikatörü
  Widget _buildSeverityIndicator(BuildContext context, int severity) {
    // Ciddiyet seviyesine göre renk belirleme
    Color getColorForSeverity(int value) {
      if (value <= 3) return Colors.green;
      if (value <= 6) return Colors.orange;
      return Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: getColorForSeverity(severity).withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: getColorForSeverity(severity)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            severity <= 3 
                ? Icons.sentiment_satisfied_alt 
                : (severity <= 6 ? Icons.sentiment_neutral : Icons.sentiment_very_dissatisfied),
            size: 16,
            color: getColorForSeverity(severity),
          ),
          const SizedBox(width: 4),
          Text(
            'Ciddiyet $severity/10',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: getColorForSeverity(severity),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Analiz satırı bileşeni
  Widget _buildAnalysisRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Belirtilmemiş' : value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
} 