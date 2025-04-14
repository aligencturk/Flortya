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
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                radius: 20,
                child: Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'İlişki Analizi Sonucum',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Mesajlarınız analiz edildi',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Özet Kartı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Özet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Bilgi satırları
                _buildInfoRow(
                  context, 
                  'Duygu',
                  result.emotion,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  context, 
                  'Niyet',
                  result.intent, 
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  context, 
                  'Mesaj Tonu',
                  result.tone,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Ciddiyet:',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSeverityIndicator(context, result.severity),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Konuşmada Yer Alan Kişiler:',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.persons,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Mesaj Yorumu
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
    
    // Renk ve etiket hesaplama
    Color color;
    String label;
    
    if (severity <= 3) {
      color = Colors.green;
      label = 'Düşük';
    } else if (severity <= 6) {
      color = Colors.orange;
      label = 'Orta';
    } else {
      color = Colors.red;
      label = 'Yüksek';
    }
    
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$severity/10 - $label',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: severity / 10,
            backgroundColor: theme.colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
  
  // Bilgi satırı
  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
  
  // Öneri listesi
  List<Widget> _buildSuggestionsList(BuildContext context, AnalysisResult result) {
    final theme = Theme.of(context);
    
    // Öneri listesini al
    List<String> suggestions = [];
    
    if (result.aiResponse.containsKey('cevapOnerileri')) {
      final suggestionList = result.aiResponse['cevapOnerileri'];
      if (suggestionList is List) {
        suggestions = suggestionList.map((item) => item.toString()).toList();
      }
    } else if (result.aiResponse.containsKey('cevap_onerileri')) {
      final suggestionList = result.aiResponse['cevap_onerileri'];
      if (suggestionList is List) {
        suggestions = suggestionList.map((item) => item.toString()).toList();
      }
    }
    
    // Öneri kartlarını oluştur
    return suggestions.asMap().entries.map((entry) {
      int index = entry.key;
      String suggestion = entry.value;
      
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              radius: 16,
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
                suggestion,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
} 