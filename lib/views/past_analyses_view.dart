import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/past_analyses_viewmodel.dart';
import '../models/past_analysis_model.dart';
import 'analysis_detail_view.dart';

class PastAnalysesView extends StatefulWidget {
  const PastAnalysesView({super.key});

  @override
  State<PastAnalysesView> createState() => _PastAnalysesViewState();
}

class _PastAnalysesViewState extends State<PastAnalysesView> {
  late PastAnalysesViewModel _viewModel;
  
  @override
  void initState() {
    super.initState();
    
    // ViewModel'i başlat ve verileri yükle
    _viewModel = Provider.of<PastAnalysesViewModel>(context, listen: false);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (authViewModel.user != null) {
        await _viewModel.loadUserAnalyses(authViewModel.user!.id);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
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
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Geçmiş Analizler',
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
                child: Consumer<PastAnalysesViewModel>(
                  builder: (context, viewModel, _) {
                    if (viewModel.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }
                    
                    if (viewModel.errorMessage != null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.white70,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              viewModel.errorMessage!,
                              style: const TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () async {
                                final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
                                if (authViewModel.user != null) {
                                  await viewModel.loadUserAnalyses(authViewModel.user!.id);
                                }
                              },
                              child: const Text('Tekrar Dene'),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    if (!viewModel.hasAnalyses) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.analytics_outlined,
                              size: 64,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Henüz analiz bulunmuyor',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'Bir mesaj analiziyle başlamak için mesaj analizi ekranına geri dönün.',
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              onPressed: () => context.go('/message-analysis'),
                              icon: const Icon(Icons.message),
                              label: const Text('Mesaj Analizi Yap'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9D3FFF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.builder(
                        itemCount: viewModel.analyses.length,
                        itemBuilder: (context, index) {
                          final analysis = viewModel.analyses[index];
                          return _buildAnalysisItem(analysis);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
  
  Widget _buildAnalysisItem(PastAnalysis analysis) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF352269),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Analiz detayına git
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnalysisDetailView(analysisId: analysis.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarih ve duygu ikonu
              Row(
                children: [
                  Text(
                    analysis.formattedDate,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getEmotionColor(analysis.emotion).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getEmotionIcon(analysis.emotion),
                          color: _getEmotionColor(analysis.emotion),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          analysis.emotion,
                          style: TextStyle(
                            color: _getEmotionColor(analysis.emotion),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Mesaj içeriği (kısaltılmış)
              Text(
                analysis.shortContent,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 12),
              
              // Özet, niyet ve ton bilgileri
              Row(
                children: [
                  // Niyet
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Niyet:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          analysis.intent,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Ton
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ton:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          analysis.tone,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Şiddet
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Şiddet:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${analysis.severity}/10',
                        style: TextStyle(
                          color: _getSeverityColor(analysis.severity),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
} 