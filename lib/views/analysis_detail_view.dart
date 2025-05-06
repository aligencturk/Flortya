import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../models/past_analysis_model.dart';
import '../viewmodels/past_analyses_viewmodel.dart';
import '../utils/loading_indicator.dart';

class AnalysisDetailView extends StatefulWidget {
  final String analysisId;
  
  const AnalysisDetailView({
    super.key,
    required this.analysisId,
  });

  @override
  State<AnalysisDetailView> createState() => _AnalysisDetailViewState();
}

class _AnalysisDetailViewState extends State<AnalysisDetailView> {
  late PastAnalysesViewModel _viewModel;
  PastAnalysis? _analysis;
  
  @override
  void initState() {
    super.initState();
    _viewModel = Provider.of<PastAnalysesViewModel>(context, listen: false);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnalysis();
    });
  }
  
  void _loadAnalysis() {
    try {
      _analysis = _viewModel.getAnalysisById(widget.analysisId);
      setState(() {});
    } catch (e) {
      // Analiz bulunamadı
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analiz bulunamadı: $e')),
      );
      context.go('/past-analyses');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_analysis == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Analiz Yükleniyor'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: YuklemeAnimasyonu(),
        ),
      );
    }
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A2A80), Color(0xFF2D1957)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => context.go('/past-analyses'),
                    ),
                    const Text(
                      'Analiz Detayı',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              
              // İçerik
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tarih ve duygu göstergesi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _analysis!.formattedDate,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getEmotionColor(_analysis!.emotion).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _getEmotionIcon(_analysis!.emotion),
                                  color: _getEmotionColor(_analysis!.emotion),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _analysis!.emotion,
                                  style: TextStyle(
                                    color: _getEmotionColor(_analysis!.emotion),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Orijinal Mesaj Kartı
                      _buildSectionCard(
                        title: 'Analiz Edilen Mesaj',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Mesajın içeriğini temizleyerek gösterme - "Görüntüden çıkarılan metin" gibi kısımları atlayarak
                            Text(
                              _cleanMessageContent(_analysis!.messageContent),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                height: 1.5,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Mesajın tipini belirten bilgi (görsel analizi, .txt dosyası analizi vs.)
                            _buildAnalysisTypeInfo(_analysis!.messageContent),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Görsel
                      if (_analysis!.imageUrl != null && _analysis!.imageUrl!.isNotEmpty)
                        _buildSectionCard(
                          title: 'Mesaj Görseli',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _analysis!.imageUrl!,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: YuklemeAnimasyonu(
                                      boyut: 18.0,
                                      renk: Colors.deepPurple,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 100,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Text('Görsel yüklenemedi'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Analiz Sonuçları Kartı
                      _buildSectionCard(
                        title: 'Analiz Sonuçları',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Duygu
                            _buildAnalysisItem(
                              title: 'Duygu',
                              value: _analysis!.emotion,
                              icon: _getEmotionIcon(_analysis!.emotion),
                              color: _getEmotionColor(_analysis!.emotion),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Niyet
                            _buildAnalysisItem(
                              title: 'Niyet',
                              value: _analysis!.intent,
                              icon: Icons.psychology,
                              color: Colors.blue,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Ton
                            _buildAnalysisItem(
                              title: 'Ton',
                              value: _analysis!.tone,
                              icon: Icons.record_voice_over,
                              color: Colors.amber,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Şiddet
                            _buildAnalysisItem(
                              title: 'Şiddet Seviyesi',
                              value: '${_analysis!.severity}/10',
                              icon: Icons.warning,
                              color: _getSeverityColor(_analysis!.severity),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // AI Yorumu Kartı
                      _buildSectionCard(
                        title: 'AI Yorumu',
                        child: Text(
                          _analysis!.summary,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
  
  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF352269),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
  
  Widget _buildAnalysisItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'mutlu':
      case 'neşeli':
      case 'sevgi dolu':
        return Colors.green;
      case 'üzgün':
      case 'endişeli':
      case 'kaygılı':
        return Colors.blue;
      case 'kızgın':
      case 'öfkeli':
      case 'sinirli':
        return Colors.red;
      case 'kıskanç':
        return Colors.amber;
      default:
        return Colors.purple;
    }
  }
  
  IconData _getEmotionIcon(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'mutlu':
      case 'neşeli':
      case 'sevgi dolu':
        return Icons.sentiment_very_satisfied;
      case 'üzgün':
      case 'endişeli':
      case 'kaygılı':
        return Icons.sentiment_dissatisfied;
      case 'kızgın':
      case 'öfkeli':
      case 'sinirli':
        return Icons.sentiment_very_dissatisfied;
      case 'kıskanç':
        return Icons.face;
      default:
        return Icons.sentiment_neutral;
    }
  }
  
  Color _getSeverityColor(int severity) {
    if (severity <= 3) return Colors.green;
    if (severity <= 6) return Colors.orange;
    return Colors.red;
  }

  String _cleanMessageContent(String content) {
    // Görüntüden çıkarılan metin veya .txt dosyası içeriğindeki gereksiz bilgileri temizle
    if (content.contains("---- Görüntüden çıkarılan metin ----") || 
        content.contains("---- Çıkarılan metin sonu ----")) {
      
      // Sadece analiz özeti göster
      return "Bu içerik görsel analizi sonucu elde edilmiştir.";
    } else if (content.contains(".txt") || content.contains("metin dosyası")) {
      // .txt dosyası analizi için açıklayıcı metin
      return "Bu içerik metin dosyası analizi sonucu elde edilmiştir.";
    } else if (content.length > 200) {
      // Çok uzun içerik - kısalt
      return "${content.substring(0, 150)}...";
    }
    
    // Normal mesajlar için
    return content;
  }

  Widget _buildAnalysisTypeInfo(String content) {
    String messageType;
    IconData typeIcon;
    Color typeColor;
    
    if (content.contains("---- Görüntüden çıkarılan metin ----")) {
      messageType = "Görsel Analizi";
      typeIcon = Icons.image;
      typeColor = Colors.blue;
    } else if (content.contains(".txt") || content.contains("metin dosyası")) {
      messageType = "Metin Dosyası Analizi";
      typeIcon = Icons.text_snippet;
      typeColor = Colors.orange;
    } else {
      messageType = "Mesaj Analizi";
      typeIcon = Icons.chat;
      typeColor = Colors.green;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            typeIcon,
            size: 14,
            color: typeColor,
          ),
          const SizedBox(width: 6),
          Text(
            messageType,
            style: TextStyle(
              color: typeColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 