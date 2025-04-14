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
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.pinkAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'İlişki Arkadaşın',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Senin için buradayım',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Ciddiyet Seviyesi İndikatörü
              _buildSeverityIndicator(context, result.severity),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Mesaj Analizi Bilgileri
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mesajda Hissettiklerim:',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Temel Analiz Bilgileri - daha samimi ifadelerle
                _buildAnalysisChip(context, 'Duygu', result.emotion),
                const SizedBox(height: 8),
                _buildAnalysisChip(context, 'Niyet', result.intent),
                const SizedBox(height: 8),
                _buildAnalysisChip(context, 'Ton', result.tone),
                const SizedBox(height: 8),
                if (result.persons.isNotEmpty)
                  _buildAnalysisChip(context, 'Kişiler', result.persons),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Mesaj Yorumu Bölümü
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Benim Düşüncem:',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result.aiResponse.containsKey('mesajYorumu') 
                      ? result.aiResponse['mesajYorumu']
                      : result.aiResponse['mesaj_yorumu'] ?? 'Mesaj yorumu bulunamadı',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Öneriler bölümü
          if (showDetailedInfo && result.aiResponse.containsKey('cevapOnerileri') ||
              showDetailedInfo && result.aiResponse.containsKey('cevap_onerileri')) ...[
            const SizedBox(height: 24),
            
            Text(
              'Sana Arkadaşça Önerilerim:',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 12),
            
            ..._buildSuggestionsList(context, result),
          ],
          
          // Detay gösterme/gizleme butonu
          const SizedBox(height: 16),
          Center(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      showDetailedInfo ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      showDetailedInfo ? 'Daha az göster' : 'Önerilerimi göster',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 4,
        child: content,
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0, duration: 300.ms);
  }
  
  // Ciddiyet seviyesi indikatörü
  Widget _buildSeverityIndicator(BuildContext context, int severity) {
    final theme = Theme.of(context);
    final colors = [
      Colors.green,      // 1-3: Düşük
      Colors.orange,     // 4-7: Orta
      Colors.red,        // 8-10: Yüksek
    ];
    
    final color = severity <= 3 
        ? colors[0] 
        : (severity <= 7 ? colors[1] : colors[2]);
    
    final label = severity <= 3 
        ? 'Hafif' 
        : (severity <= 7 ? 'Dikkat' : 'Önemli');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(severity <= 3 
              ? Icons.sentiment_satisfied 
              : (severity <= 7 ? Icons.sentiment_neutral : Icons.sentiment_dissatisfied),
            color: color,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  // Analiz bilgisi chips
  Widget _buildAnalysisChip(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value.isEmpty ? 'Belirsiz' : value,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
  
  // Eski analiz bilgisi satırı
  Widget _buildAnalysisRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.isEmpty ? 'Belirsiz' : value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
  
  // Öneri listesini oluşturma
  List<Widget> _buildSuggestionsList(BuildContext context, AnalysisResult result) {
    final theme = Theme.of(context);
    
    // Öneri listesini al
    final suggestions = result.aiResponse.containsKey('cevapOnerileri')
        ? result.aiResponse['cevapOnerileri'] as List<dynamic>
        : result.aiResponse['cevap_onerileri'] as List<dynamic>? ?? [];
    
    // Widget listesi oluştur
    return suggestions.asMap().entries.map((entry) {
      final index = entry.key;
      final suggestion = entry.value.toString();
      
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                suggestion,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms, delay: (100 * index).ms)
          .slideX(begin: 0.1, end: 0, duration: 300.ms, delay: (100 * index).ms);
    }).toList();
  }
} 