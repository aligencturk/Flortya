import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/report_viewmodel.dart';
import '../widgets/custom_button.dart';
import '../services/input_service.dart';

class ReportView extends StatefulWidget {
  const ReportView({Key? key}) : super(key: key);

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  bool _showReportResult = false;
  bool _isCommenting = false;

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
    _commentController.dispose();
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

  // Yorum moduna geç
  void _toggleCommentMode() {
    setState(() {
      _isCommenting = !_isCommenting;
    });
  }

  // Yorum gönder
  void _sendComment() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
    final comment = _commentController.text.trim();
    
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen yorum yazın')),
      );
      return;
    }
    
    // Yorum gönderme işlemi
    if (authViewModel.user != null) {
      await reportViewModel.sendComment(authViewModel.user!.id, comment);
    }
    
    // Gönderildi bildirimi
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yorumunuz gönderildi')),
    );
    
    _commentController.clear();
    setState(() {
      _isCommenting = false;
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
    final totalQuestions = 6;
    
    // Debugging
    debugPrint('Toplam soru sayısı: $totalQuestions');
    debugPrint('Sorular: ${reportViewModel.questions}');
    
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
            inputFormatters: InputService.getTurkishTextFormatters(),
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
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
    
    return Stack(
      children: [
        // Rapor içeriği
        SingleChildScrollView(
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
              
              // İlişki Gelişim Grafiği
              _buildRelationshipGraph(context, reportViewModel),
              
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
              
              // Yorumlar başlığı
              if (reportViewModel.comments.isNotEmpty) ...[
                Text(
                  'Yorumlarınız',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Yorum listesi
                ..._buildCommentList(context, reportViewModel),
                
                const SizedBox(height: 32),
              ],
              
              // Yeni test butonu
              CustomButton(
                text: 'Yeni Test Başlat',
                onPressed: _startNewReport,
                type: ButtonType.outline,
                isFullWidth: true,
              ),
              
              // Yorum butonu
              const SizedBox(height: 16),
              
              CustomButton(
                text: 'Rapor Hakkında Yorum Ekle',
                onPressed: _toggleCommentMode,
                icon: Icons.comment,
                type: ButtonType.outline,
                isFullWidth: true,
              ),
              
              // Boşluk (alt kısımdaki mesaj gönderme alanı için)
              const SizedBox(height: 80),
            ],
          ),
        ),
        
        // Yorum gönderme alanı (rapor gösterimi sırasında alt kısımda sabit)
        if (_isCommenting)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      inputFormatters: InputService.getTurkishTextFormatters(),
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Raporunuz hakkında yorum yazın...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendComment,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // İlişki gelişimi grafiği
  Widget _buildRelationshipGraph(BuildContext context, ReportViewModel reportViewModel) {
    // İlişki tipini alıyoruz
    final relationshipType = reportViewModel.reportResult!['relationship_type'] ?? 'Belirsiz';
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'İlişki Gelişimi',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRelationshipTypeColor(relationshipType),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  relationshipType,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: reportViewModel.getRelationshipHistory(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'Henüz yeterli veri yok',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  );
                }
                
                final graphData = snapshot.data!;
                
                // Basit çizgi grafiği
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    graphData.length,
                    (index) {
                      final data = graphData[index];
                      final value = (data['value'] as int?) ?? 0;
                      final label = data['label'] as String? ?? '';
                      final heightPercentage = value / 100;
                      
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 30,
                            height: 100 * heightPercentage,
                            decoration: BoxDecoration(
                              color: _getGraphBarColor(value),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  // İlişki tipine göre renk belirleme
  Color _getRelationshipTypeColor(String relationshipType) {
    final Map<String, Color> typeColors = {
      'Güven Odaklı': Colors.blue.shade700,
      'Tutkulu': Colors.red.shade700,
      'Uyumlu': Colors.green.shade700,
      'Dengeli': Colors.purple.shade700,
      'Mesafeli': Colors.amber.shade700,
      'Kaçıngan': Colors.orange.shade700,
      'Endişeli': Colors.pink.shade700,
      'Çatışmalı': Colors.deepOrange.shade700,
      'Kararsız': Colors.teal.shade700,
      'Gelişmekte Olan': Colors.cyan.shade700,
      'Sağlıklı': Colors.green.shade700,
      'Zorlayıcı': Colors.deepOrange.shade700,
    };
    
    return typeColors[relationshipType] ?? Colors.indigo.shade700;
  }
  
  // Grafik çubuğu için renk belirleme
  Color _getGraphBarColor(int value) {
    if (value >= 80) return Colors.green.shade600;
    if (value >= 60) return Colors.blue.shade600;
    if (value >= 40) return Colors.amber.shade600;
    if (value >= 20) return Colors.orange.shade600;
    return Colors.red.shade600;
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

  // Yorum listesi oluşturma
  List<Widget> _buildCommentList(BuildContext context, ReportViewModel reportViewModel) {
    return reportViewModel.comments.map((comment) {
      final index = reportViewModel.comments.indexOf(comment);
      final dateTime = comment['timestamp'] as DateTime;
      final formattedDate = '${dateTime.day}.${dateTime.month}.${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kullanıcı yorumu
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Yorumunuz',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(comment['comment']),
                ],
              ),
            ),
            
            // AI yanıtı (varsa)
            if (comment['aiResponse'] != null && comment['aiResponse'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.psychology, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Terapistiniz',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(comment['aiResponse']),
                  ],
                ),
              ),
            ],
          ],
        )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 300 + (index * 100)), duration: 400.ms)
        .slideY(begin: 0.2, end: 0),
      );
    }).toList();
  }
} 