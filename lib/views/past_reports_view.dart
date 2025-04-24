import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/past_reports_viewmodel.dart';
import '../models/past_report_model.dart';
import 'report_detail_view.dart';
import '../utils/loading_indicator.dart';

class PastReportsView extends StatefulWidget {
  const PastReportsView({super.key});

  @override
  State<PastReportsView> createState() => _PastReportsViewState();
}

class _PastReportsViewState extends State<PastReportsView> {
  late PastReportsViewModel _viewModel;
  
  @override
  void initState() {
    super.initState();
    
    // ViewModel'i başlat ve verileri yükle
    _viewModel = Provider.of<PastReportsViewModel>(context, listen: false);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (authViewModel.user != null) {
        await _viewModel.loadUserReports(authViewModel.user!.id);
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
                      onPressed: () => context.go('/profile'),
                    ),
                    const Text(
                      'İlişki Raporları',
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
                child: Consumer<PastReportsViewModel>(
                  builder: (context, viewModel, _) {
                    if (viewModel.isLoading) {
                      return const Center(
                        child: YuklemeAnimasyonu(renk: Colors.white),
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
                                  await viewModel.loadUserReports(authViewModel.user!.id);
                                }
                              },
                              child: const Text('Tekrar Dene'),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    if (!viewModel.hasReports) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.assessment_outlined,
                              size: 64,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Henüz ilişki raporu bulunmuyor',
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
                                'İlişki raporu oluşturmak için ilişki raporu ekranına geri dönün.',
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              onPressed: () => context.go('/report'),
                              icon: const Icon(Icons.edit_document),
                              label: const Text('Rapor Oluştur'),
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
                        itemCount: viewModel.reports.length,
                        itemBuilder: (context, index) {
                          final report = viewModel.reports[index];
                          return _buildReportItem(report);
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
  
  Widget _buildReportItem(PastReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF352269),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Rapor detayına git
          context.push('/report-detail/${report.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarih ve ilişki türü etiketi
              Row(
                children: [
                  Text(
                    report.formattedDate,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9D3FFF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      report.relationshipType,
                      style: const TextStyle(
                        color: Color(0xFF9D3FFF),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Rapor içeriği (kısaltılmış)
              Text(
                report.shortContent,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 12),
              
              // Cevapların gösterimi (ilk 2 soru-cevap)
              if (report.questions.isNotEmpty && report.answers.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // İlk soru-cevap
                    _buildQuestionAnswer(
                      report.questions.isNotEmpty ? report.questions[0] : 'Soru 1',
                      report.answers.isNotEmpty ? report.answers[0] : '',
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // İkinci soru-cevap
                    if (report.questions.length > 1 && report.answers.length > 1)
                      _buildQuestionAnswer(
                        report.questions[1],
                        report.answers[1],
                      ),
                  ],
                ),
              
              const SizedBox(height: 12),
              
              // Detay butonu
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      // Rapor detayına git
                      context.push('/report-detail/${report.id}');
                    },
                    icon: const Icon(
                      Icons.visibility,
                      size: 16,
                      color: Colors.white70,
                    ),
                    label: const Text(
                      'Detaylara Bak',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildQuestionAnswer(String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          answer.length > 100 ? '${answer.substring(0, 97)}...' : answer,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
} 