import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/report_viewmodel.dart';
import '../widgets/custom_button.dart';

class ReportView extends StatefulWidget {
  const ReportView({Key? key}) : super(key: key);

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  final TextEditingController _answerController = TextEditingController();
  bool _showReportResult = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserReports();
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  // Kullanıcının raporlarını yükleme
  Future<void> _loadUserReports() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
    
    if (authViewModel.user != null) {
      await reportViewModel.loadUserReports(authViewModel.user!.id);
    }
  }

  // Cevabı kaydet ve bir sonraki soruya geç
  void _saveAnswerAndContinue() {
    final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
    
    final answer = _answerController.text.trim();
    
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen soruyu yanıtlayın')),
      );
      return;
    }
    
    // Cevabı kaydet
    reportViewModel.saveAnswer(answer);
    
    // Sonraki soruya geç veya son soruysa rapor oluştur
    if (reportViewModel.isLastQuestion) {
      _generateReport();
    } else {
      reportViewModel.nextQuestion();
      _answerController.clear();
    }
  }

  // Önceki soruya dön
  void _goToPreviousQuestion() {
    final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
    
    reportViewModel.previousQuestion();
    _answerController.text = reportViewModel.answers[reportViewModel.currentQuestionIndex];
  }

  // Rapor oluştur
  Future<void> _generateReport() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
    
    if (authViewModel.user != null) {
      await reportViewModel.generateReport(authViewModel.user!.id);
      
      if (reportViewModel.hasReport) {
        setState(() {
          _showReportResult = true;
        });
      }
    }
  }

  // Yeni bir teste başla
  void _startNewReport() {
    final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
    
    reportViewModel.resetReport();
    _answerController.clear();
    
    setState(() {
      _showReportResult = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportViewModel = Provider.of<ReportViewModel>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('İlişki Raporu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: reportViewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _showReportResult || reportViewModel.hasReport
              ? _buildReportResult(context, reportViewModel)
              : _buildQuestionForm(context, reportViewModel),
    );
  }

  // Soru formu widget'ı
  Widget _buildQuestionForm(BuildContext context, ReportViewModel reportViewModel) {
    final currentQuestionNumber = reportViewModel.currentQuestionIndex + 1;
    final totalQuestions = reportViewModel.questions.length;
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // İlerleme göstergesi
          LinearProgressIndicator(
            value: currentQuestionNumber / totalQuestions,
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
            minHeight: 8,
          ),
          
          const SizedBox(height: 8),
          
          // Soru sayısı metni
          Text(
            'Soru $currentQuestionNumber / $totalQuestions',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.end,
          ),
          
          const SizedBox(height: 32),
          
          // Soru metni
          Text(
            reportViewModel.currentQuestion,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          )
          .animate()
          .fadeIn(duration: 400.ms)
          .slide(begin: const Offset(0.2, 0), end: Offset.zero),
          
          const SizedBox(height: 24),
          
          // Cevap alanı
          TextField(
            controller: _answerController,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Cevabınızı buraya yazın...',
            ),
          ),
          
          const Spacer(),
          
          // Butonlar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Önceki düğmesi
              if (reportViewModel.currentQuestionIndex > 0)
                CustomButton(
                  text: 'Önceki',
                  onPressed: _goToPreviousQuestion,
                  type: ButtonType.outline,
                  icon: Icons.arrow_back,
                ) 
              else
                const SizedBox(width: 100),
              
              // İleri / Bitir düğmesi
              CustomButton(
                text: reportViewModel.isLastQuestion ? 'Raporu Oluştur' : 'Devam Et',
                onPressed: _saveAnswerAndContinue,
                icon: reportViewModel.isLastQuestion ? Icons.done : Icons.arrow_forward,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Rapor sonucu widget'ı
  Widget _buildReportResult(BuildContext context, ReportViewModel reportViewModel) {
    final report = reportViewModel.reportResult!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık
          Text(
            'İlişki Tipiniz: ${report['relationship_type']}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          )
          .animate()
          .fadeIn(duration: 600.ms),
          
          const SizedBox(height: 32),
          
          // Rapor
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Text(
              report['report'],
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
          .animate()
          .fadeIn(delay: 300.ms, duration: 600.ms),
          
          const SizedBox(height: 32),
          
          // Öneriler
          Text(
            'Öneriler',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Öneri listesi
          ..._buildSuggestionList(context, report),
          
          const SizedBox(height: 32),
          
          // Yeni test butonu
          CustomButton(
            text: 'Yeni Test Başlat',
            onPressed: _startNewReport,
            type: ButtonType.outline,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  // Öneri listesi oluşturma
  List<Widget> _buildSuggestionList(BuildContext context, Map<String, dynamic> report) {
    final List<dynamic> suggestions = report['suggestions'] as List<dynamic>;
    
    return suggestions.map((suggestion) {
      final index = suggestions.indexOf(suggestion);
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                suggestion.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      )
      .animate()
      .fadeIn(delay: Duration(milliseconds: 400 + (index * 100)), duration: 400.ms)
      .slideX(begin: 0.2, end: 0);
    }).toList();
  }
} 