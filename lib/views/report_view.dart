import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/report_viewmodel.dart';
import '../widgets/custom_button.dart';
import '../services/input_service.dart';
import '../utils/utils.dart';
import '../utils/loading_indicator.dart';

class ReportView extends StatefulWidget {
  const ReportView({super.key});

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
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
  void _startNewReport(BuildContext context) {
    final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
    
    reportViewModel.resetReport();
    
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
      Utils.showToast(context, 'Lütfen yorum yazın');
      return;
    }
    
    // Yorum gönderme işlemi
    if (authViewModel.user != null) {
      await reportViewModel.sendComment(authViewModel.user!.id, comment);
    }
    
    // Gönderildi bildirimi
    Utils.showSuccessFeedback(context, 'Yorumunuz gönderildi');
    
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
          ? const YuklemeAnimasyonu()
          : _showReportResult || reportViewModel.hasReport
              ? _buildReportResult(context, reportViewModel)
              : _buildQuestionForm(context, reportViewModel),
    );
  }

  // Soru formu widget'ı
  Widget _buildQuestionForm(BuildContext context, ReportViewModel reportViewModel) {
    final currentQuestionNumber = reportViewModel.currentQuestionIndex + 1;
    final totalQuestions = reportViewModel.questions.length;
    
    // Debugging
    debugPrint('Toplam soru sayısı: $totalQuestions');
    debugPrint('Sorular: ${reportViewModel.questions}');
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Soruların yenilenmesine kalan süre göstergesi
          if (reportViewModel.nextUpdateTime != null)
            _buildCountdownTimer(context, reportViewModel),
          
          const SizedBox(height: 24),
          
          // İlerleme göstergesi
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 8,
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: currentQuestionNumber / totalQuestions,
                child: Container(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
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
          
          // Cevap butonları - Evet/Hayır/Bilmiyorum
          _buildAnswerButtons(context, reportViewModel),
          
          const Spacer(),
          
          // Butonlar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Önceki düğmesi
              if (reportViewModel.currentQuestionIndex > 0)
                CustomButton(
                  text: 'Önceki',
                  onPressed: () {
                    // Önceki soruya geç
                    reportViewModel.previousQuestion();
                  },
                  type: ButtonType.outline,
                  icon: Icons.arrow_back,
                ) 
              else
                const SizedBox(width: 100),
              
              // İleri / Bitir düğmesi
              CustomButton(
                text: reportViewModel.isLastQuestion ? 'Raporu Oluştur' : 'Devam Et',
                onPressed: () {
                  // Mevcut sorunun cevabını kontrol et
                  if (reportViewModel.answers[reportViewModel.currentQuestionIndex].isEmpty) {
                    Utils.showToast(context, 'Lütfen soruyu yanıtlayın');
                    return;
                  }
                  
                  // Son soruysa raporu oluştur, değilse sonraki soruya geç
                  if (reportViewModel.isLastQuestion) {
                    _generateReport();
                  } else {
                    reportViewModel.nextQuestion();
                  }
                },
                icon: reportViewModel.isLastQuestion ? Icons.done : Icons.arrow_forward,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Geri sayım sayacı widget'ı
  Widget _buildCountdownTimer(BuildContext context, ReportViewModel reportViewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Soruların Yenilenmesine Kalan Süre:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCountdownItem(context, reportViewModel.remainingDays, 'Gün'),
              _buildCountdownItem(context, reportViewModel.remainingHours, 'Saat'),
              _buildCountdownItem(context, reportViewModel.remainingMinutes, 'Dakika'),
              _buildCountdownItem(context, reportViewModel.remainingSeconds, 'Saniye'),
            ],
          ),
        ],
      ),
    );
  }
  
  // Geri sayım için tekil öğe
  Widget _buildCountdownItem(BuildContext context, int value, String label) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              value.toString().padLeft(2, '0'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  // Evet/Hayır/Bilmiyorum butonları
  Widget _buildAnswerButtons(BuildContext context, ReportViewModel reportViewModel) {
    final currentAnswer = reportViewModel.answers[reportViewModel.currentQuestionIndex];
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAnswerButton(
                context: context,
                text: 'Evet',
                isSelected: currentAnswer == 'Evet',
                color: Colors.green,
                onTap: () => reportViewModel.saveAnswer('Evet'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildAnswerButton(
                context: context,
                text: 'Hayır',
                isSelected: currentAnswer == 'Hayır',
                color: Colors.red,
                onTap: () => reportViewModel.saveAnswer('Hayır'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildAnswerButton(
          context: context,
          text: 'Bilmiyorum',
          isSelected: currentAnswer == 'Bilmiyorum',
          color: Colors.orange,
          onTap: () => reportViewModel.saveAnswer('Bilmiyorum'),
        ),
      ],
    );
  }
  
  // Tekil cevap butonu
  Widget _buildAnswerButton({
    required BuildContext context,
    required String text,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withOpacity(0.2) 
              : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? color 
                : Theme.of(context).colorScheme.outline.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected 
                ? color 
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  // Rapor sonuçlarını gösteren widget
  Widget _buildReportResult(BuildContext context, ReportViewModel reportViewModel) {
    final report = reportViewModel.reportResult!;
    
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 10,
            bottom: 120, // Butonlar için daha fazla boşluk
          ),
          children: [
            // İlişki değerlendirme grafiği (Başlığı kaldırıldı)
            const SizedBox(height: 20),
            
            _buildRelationshipGraph(context, reportViewModel),
            
            const SizedBox(height: 24),
            
            // Öneriler başlığı
            Text(
              'İlişkinizi Geliştirecek Öneriler',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Öneriler listesi
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildSuggestionList(context, report),
            ),
          ],
        ),
        
        // Alt butonlar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                // Testi yeniden başlat butonu
                Expanded(
                  child: CustomButton(
                    text: 'Testi Yeniden Başlat',
                    onPressed: () {
                      try {
                        // ViewModel'i al ve resetle
                        final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
                        reportViewModel.resetReport();
                        
                        // UI güncellemesini güvenli şekilde planlama
                        Future.microtask(() {
                          if (mounted) {
                            setState(() {
                              _showReportResult = false;
                            });
                          }
                        });
                      } catch (e) {
                        // Herhangi bir hata durumunda kullanıcıyı bilgilendir
                        Utils.showErrorFeedback(context, 'Test başlatılırken bir hata oluştu: $e');
                      }
                    },
                    type: ButtonType.outline,
                    icon: Icons.refresh,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Testi puanla butonu
                Expanded(
                  child: CustomButton(
                    text: 'Testi Puanla',
                    onPressed: () {
                      // Puanlama modalini göster
                      _showRatingDialog(context);
                    },
                    icon: Icons.star,
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
    final report = reportViewModel.reportResult!;
    final relationshipType = report['relationship_type'] ?? 'Belirsiz';
    final color = _getRelationshipTypeColor(relationshipType);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık
          Text(
            'İlişki Değerlendirmesi',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // İlişki tipi göstergesi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  relationshipType,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // İlişki açıklaması - Yapay zeka tarafından üretilen metin
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              report['ai_analysis'] as String? ?? _getFallbackRelationshipDescription(relationshipType),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Yasal uyarı metni
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Text(
                  "ℹ️",
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Not: Uygulamada sunulan içerikler yol gösterici niteliktedir, bağlayıcı değildir.",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 600.ms);
  }
  
  // Yedek ilişki tipi açıklaması (Yapay zeka açıklaması yoksa kullanılır)
  String _getFallbackRelationshipDescription(String relationshipType) {
    // Bu fonksiyon sadece yapay zeka metni olmadığında yedek olarak kullanılır
    final Map<String, String> descriptions = {
      'Güven Odaklı': 'İlişkinizde güven temeli güçlü ve sağlıklı. İletişiminiz açık, birbirinize karşı dürüst ve şeffafsınız. Bu temeli koruyarak ilişkinizi daha da derinleştirebilirsiniz.',
      'Tutkulu': 'İlişkinizde tutku ve yoğun duygular ön planda. Duygusal bağınız güçlü ancak dengeyi korumak için iletişime özen göstermelisiniz. Ortak hedefler belirleyerek tutkuyu sürdürülebilir kılabilirsiniz.',
      'Uyumlu': 'İlişkinizde uyum seviyesi oldukça yüksek. Birbirinizi tamamlıyor ve birlikte hareket edebiliyorsunuz. Bu güçlü yanınızı kullanarak ilişkinizi daha da zenginleştirebilirsiniz.',
      'Dengeli': 'İlişkiniz dengeli bir şekilde ilerliyor. Karşılıklı anlayış, saygı ve iletişiminiz güçlü. Bu sağlıklı temeli koruyarak birlikte büyümeye devam edebilirsiniz.',
      'Mesafeli': 'İlişkinizde duygusal bir mesafe söz konusu. Daha açık iletişim kurarak ve duygularınızı paylaşarak bu mesafeyi azaltabilir, daha derin bir bağ kurabilirsiniz.',
      'Kaçıngan': 'İlişkinizde sorunlardan kaçınma eğilimi görülüyor. Zor konuları konuşmaktan çekinmeyin, yüzleşme cesareti göstererek ilişkinizi güçlendirebilirsiniz.',
      'Endişeli': 'İlişkinizde endişe ve kaygı unsurları öne çıkıyor. Güveni artırmak için açık iletişim kurun, beklentilerinizi net bir şekilde ifade edin ve birbirinize destek olun.',
      'Çatışmalı': 'İlişkinizde çatışmalar ön planda. Yapıcı tartışma becerileri geliştirerek ve birbirinizi daha iyi dinleyerek bu çatışmaları ilişkinizi güçlendiren fırsatlara dönüştürebilirsiniz.',
      'Kararsız': 'İlişkinizde kararsızlık hâkim durumda. Ortak hedefler belirleyerek ve gelecek planları yaparak bu belirsizliği giderebilir, ilişkinize yön verebilirsiniz.',
      'Gelişmekte Olan': 'İlişkiniz gelişim aşamasında ve potansiyel vadediyor. Sabır ve anlayış göstererek, iletişimi güçlendirerek bu gelişim sürecini olumlu yönde ilerletebilirsiniz.',
      'Gelişmekte Olan, Güven Sorunları Olan': 'İlişkiniz gelişiyor ancak güven konusunda çalışmanız gereken alanlar var. Açık iletişim kurarak ve sözünüzü tutarak güven temelini yeniden inşa edebilirsiniz.',
      'Sağlıklı': 'İlişkiniz son derece sağlıklı bir yapıya sahip. Güçlü iletişim, karşılıklı saygı ve güven temelinde ilerliyor. Bu değerli temeli koruyarak ilişkinizi daha da derinleştirebilirsiniz.',
      'Zorlayıcı': 'İlişkinizde zorlayıcı unsurlar ve sınır sorunları var. Kişisel sınırlarınızı netleştirerek ve birbirinize saygı göstererek bu zorlukları aşabilirsiniz.',
      'Sağlıklı ve Gelişmekte Olan': 'İlişkiniz sağlıklı bir temel üzerinde gelişmeye devam ediyor. İletişiminiz açık ve saygı çerçevesinde ilerliyor. Bu olumlu temeli koruyarak ilişkinizi daha da güçlendirebilirsiniz.',
      'Belirsiz': 'İlişkinizde bazı gelişim alanları tespit edildi. Aşağıdaki kişiselleştirilmiş önerileri uygulayarak iletişiminizi güçlendirebilir ve ilişkinizi daha sağlıklı bir noktaya taşıyabilirsiniz.',
    };
    
    return descriptions[relationshipType] ?? 'İlişkiniz için yapılan değerlendirme sonucunda, kişiselleştirilmiş öneriler hazırlandı. Bu önerileri uyguladığınızda iletişiminiz güçlenecek ve daha sağlıklı bir ilişki kurabileceksiniz.';
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
  
  // Puan rengi belirleme
  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green.shade600;
    if (score >= 60) return Colors.blue.shade600;
    if (score >= 40) return Colors.amber.shade600;
    if (score >= 20) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  // Öneri listesi oluşturma
  List<Widget> _buildSuggestionList(BuildContext context, Map<String, dynamic> report) {
    final List<dynamic> suggestions = report['suggestions'] as List<dynamic>;
    
    if (suggestions.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Henüz öneri bulunmuyor',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ];
    }
    
    return suggestions.map((suggestion) {
      final index = suggestions.indexOf(suggestion);
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
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
        .slideX(begin: 0.2, end: 0),
      );
    }).toList();
  }

  // Puanlama diyalogu
  void _showRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Testi Puanla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bu test size ne kadar yardımcı oldu?'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                5,
                (index) => IconButton(
                  icon: Icon(
                    Icons.star,
                    size: 36,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    // Puanı kaydet ve diyalogu kapat
                    Navigator.of(context).pop();
                    Utils.showToast(context, 'Değerlendirmeniz için teşekkürler!');
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
        ],
      ),
    );
  }
} 