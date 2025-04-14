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
          
          // Detaylı Bilgiler (şartlı gösterim)
          if (showDetailedInfo) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // AI Cevabı
            Text(
              'Detaylı Analiz:',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              result.aiResponse['analysis'] ?? 'Detaylı analiz mevcut değil.',
              style: theme.textTheme.bodyMedium,
            ),
            
            // Öneri varsa göster
            if (result.aiResponse.containsKey('suggestion') && 
                result.aiResponse['suggestion'] != null) ...[
              const SizedBox(height: 16),
              Text(
                'Öneri:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.aiResponse['suggestion'],
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
          
          // "Daha Fazla Göster" Butonu (eğer detaylar gösterilmiyorsa)
          if (!showDetailedInfo && onTap != null)
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_downward),
                label: const Text('Daha Fazla Göster'),
              ),
            ),
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
            'Seviye $severity',
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
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
} 