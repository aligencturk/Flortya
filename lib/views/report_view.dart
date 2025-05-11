import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import 'dart:ui';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/report_viewmodel.dart';
import '../widgets/custom_button.dart';
import '../utils/utils.dart';
import '../utils/loading_indicator.dart';
import '../services/relationship_access_service.dart';
import '../services/ad_service.dart';

class ReportView extends StatefulWidget {
  final bool skipAccessCheck;
  
  const ReportView({
    super.key,
    this.skipAccessCheck = false,
  });

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  final TextEditingController _commentController = TextEditingController();
  final RelationshipAccessService _accessService = RelationshipAccessService();
  bool _showReportResult = false;
  bool _isCommenting = false;
  List<String> _unlockedSuggestions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserReports();
      _loadUnlockedSuggestions();
      // Eğer skipAccessCheck true ise, hak kontrolü yapma
      if (!widget.skipAccessCheck) {
        _checkInitialAccess();
      } else {
        debugPrint('Hak kontrolü atlanıyor çünkü skipAccessCheck=true');
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadUnlockedSuggestions() async {
    final suggestions = await _accessService.getUnlockedSuggestions();
    setState(() {
      _unlockedSuggestions = suggestions;
    });
  }

  Future<void> _loadUserReports() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
    
    if (authViewModel.user != null) {
      await reportViewModel.loadUserReports(authViewModel.user!.id);
    }
  }

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

  void _showPremiumRequiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('İlişki Değerlendirme Hakkı'),
          content: const Text(
            'İlişki değerlendirme hakkınız doldu. Premium üyelik satın alarak sınırsız kullanabilir veya reklam izleyerek 3 hak daha kazanabilirsiniz.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showAdSimulation(AdViewType.TEST_ACCESS);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Reklam İzle'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLockedWidget({
    required Widget child,
    required bool isLocked,
    required VoidCallback onUnlock,
  }) {
    return Stack(
      children: [
        if (isLocked)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: child,
          )
        else
          child,
          
        if (isLocked)
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 130,
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: onUnlock,
                      icon: const Icon(
                        Icons.play_arrow,
                        size: 18,
                      ),
                      label: const Text(
                        'Reklam İzle',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showAdSimulation(AdViewType type, {int? suggestionIndex}) async {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext loadingContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF352269),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D3FFF)),
              ),
              const SizedBox(height: 16),
              const Text(
                "Reklam yükleniyor...",
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
    
    // AdService kullanarak reklam göster
    AdService.loadRewardedAd(() async {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      
      // Tüm işlemleri try-catch içine alarak hataları yönetiyoruz
      try {
        switch (type) {
          case AdViewType.TEST_ACCESS:
            await _accessService.setRelationshipTestAdViewed(true);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Tebrikler! 3 ilişki değerlendirmesi hakkı kazandınız."),
                  backgroundColor: Color(0xFF4A2A80),
                ),
              );
              
              // Reklam izlendikten sonra rapor sayfasına yönlendir
              if (context.mounted) {
                // Sayfadan çıkış yapıp tekrar girerek state sorunlarını önle
                await Future.delayed(const Duration(milliseconds: 300));
                if (context.mounted) {
                  // Özel parametre ile hak kontrolünü atlayarak sayfaya yönlendir
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const ReportView(skipAccessCheck: true)
                    )
                  );
                }
              }
            }
            break;
            
          case AdViewType.REPORT_VIEW:
            await _accessService.incrementReportViewCount();
            if (context.mounted) {
              setState(() {
                _showReportResult = true;
              });
            }
            break;
            
          case AdViewType.REPORT_REGENERATE:
            await _accessService.incrementReportRegenerateCount();
            
            if (context.mounted) {
              // Raporu sıfırla ve UI'ı güncelle
              final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
              reportViewModel.resetReport();
              
              setState(() {
                _showReportResult = false;
              });
              
              // Başarı mesajı göster
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Test yeniden başlatıldı"),
                  backgroundColor: Color(0xFF4A2A80),
                ),
              );
            }
            break;
            
          case AdViewType.SUGGESTION_UNLOCK:
            if (suggestionIndex != null) {
              await _accessService.unlockSuggestion(suggestionIndex);
              if (mounted) {
                await _loadUnlockedSuggestions();
              }
            }
            break;
        }
      } catch (e) {
        debugPrint('Reklam işlemleri sırasında hata: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("İşlem sırasında bir hata oluştu: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  void _startNewReport(BuildContext context) async {
    final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    final canRegenerate = await _accessService.canRegenerateReport(isPremium);
    
    if (!canRegenerate) {
      if (!context.mounted) return;
      _showReportRegenerateDialog();
      return;
    }
    
    reportViewModel.resetReport();
    
    setState(() {
      _showReportResult = false;
    });
  }

  void _showReportRegenerateDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Premium Gerekli'),
          content: const Text(
            'Raporu yeniden oluşturma hakkınız doldu. Premium üyelik satın alarak sınırsız kullanabilir veya reklam izleyerek yeniden oluşturabilirsiniz.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showAdSimulation(AdViewType.REPORT_REGENERATE);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Reklam İzle'),
            ),
          ],
        );
      },
    );
  }

  void _toggleCommentMode() {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    if (!isPremium) {
      Utils.showToast(
        context,
        'Yorum ve danışma özelliği sadece Premium üyelere özeldir'
      );
      return;
    }
    
    setState(() {
      _isCommenting = !_isCommenting;
    });
  }

  void _sendComment() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
    final comment = _commentController.text.trim();
    
    if (comment.isEmpty) {
      Utils.showToast(context, 'Lütfen yorum yazın');
      return;
    }
    
    if (authViewModel.user != null) {
      await reportViewModel.sendComment(authViewModel.user!.id, comment);
    }
    
    Utils.showSuccessFeedback(context, 'Yorumunuz gönderildi');
    
    _commentController.clear();
    setState(() {
      _isCommenting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportViewModel = Provider.of<ReportViewModel>(context);
    
    // Özel hata yakalama mekanizması ekle
    Widget contentWidget;
    try {
      contentWidget = reportViewModel.isLoading
          ? const YuklemeAnimasyonu(
              analizTipi: AnalizTipi.ILISKI_ANKETI,
            )
          : _showReportResult || reportViewModel.hasReport
              ? _buildReportResult(context, reportViewModel)
              : _buildQuestionForm(context, reportViewModel);
    } catch (e) {
      // Hata durumunda kontrollü fallback widget göster
      debugPrint('ReportView içerik oluşturulurken hata: $e');
      contentWidget = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text('Bir sorun oluştu.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Güvenli bir şekilde resetleme işlemi yapmak için
                try {
                  if (mounted) {
                    Future.microtask(() {
                      if (mounted) {
                        reportViewModel.resetReport();
                        setState(() {
                          _showReportResult = false;
                        });
                      }
                    });
                  }
                } catch (resetError) {
                  debugPrint('Sıfırlama sırasında hata: $resetError');
                }
              },
              child: const Text('Yeniden Başlat'),
            ),
          ],
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('İlişki Raporu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: contentWidget,
    );
  }

  Widget _buildQuestionForm(BuildContext context, ReportViewModel reportViewModel) {
    if (reportViewModel.questions.isEmpty) {
      return const Center(
        child: Text('Sorular yükleniyor, lütfen bekleyin...'),
      );
    }
    
    if (reportViewModel.currentQuestionIndex < 0 || 
        reportViewModel.currentQuestionIndex >= reportViewModel.questions.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Soru verilerinde bir sorun oluştu.'),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Testi Yeniden Başlat',
              onPressed: () {
                reportViewModel.resetReport();
              },
              icon: Icons.refresh,
            ),
          ],
        ),
      );
    }
    
    final currentQuestionNumber = reportViewModel.currentQuestionIndex + 1;
    final totalQuestions = reportViewModel.questions.length;
    
    // Cevaplar ve sorular dizisi uzunluğu kontrolünü daha güvenli hale getiriyoruz
    if (reportViewModel.answers.length != reportViewModel.questions.length) {
      debugPrint('Uyarı: Cevaplar ve sorular dizilerinin uzunluğu uyuşmuyor');
      try {
        // Cevapları asenkron olarak sıfırlıyoruz, böylece build işlemi tamamlanabilir
        Future.microtask(() {
          if (mounted) {
        reportViewModel.resetAnswers();
          }
        });
        // Bu sırada yalnızca mevcut durumu göster, sıfırlama işlemi tamamlandıktan sonra UI güncellenecek
      } catch (e) {
        debugPrint('Rapor sayfasında cevapları sıfırlarken hata oluştu: $e');
        // Kritik hata durumunda tüm raporu sıfırla
        Future.microtask(() {
          if (mounted) {
        reportViewModel.resetReport();
          }
        });
      }
    }
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reportViewModel.nextUpdateTime != null)
            _buildCountdownTimer(context, reportViewModel),
          
          const SizedBox(height: 24),
          
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
          
          Text(
            'Soru $currentQuestionNumber / $totalQuestions',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.end,
          ),
          
          const SizedBox(height: 32),
          
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
          
          _buildAnswerButtons(context, reportViewModel),
          
          const Spacer(),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (reportViewModel.currentQuestionIndex > 0)
                CustomButton(
                  text: 'Önceki',
                  onPressed: () {
                    reportViewModel.previousQuestion();
                  },
                  type: ButtonType.outline,
                  icon: Icons.arrow_back,
                ) 
              else
                const SizedBox(width: 100),
              
              CustomButton(
                text: reportViewModel.isLastQuestion ? 'Raporu Oluştur' : 'Devam Et',
                onPressed: () async {
                  final currentIndex = reportViewModel.currentQuestionIndex;
                  if (currentIndex < 0 || currentIndex >= reportViewModel.answers.length || reportViewModel.answers[currentIndex].isEmpty) {
                    Utils.showToast(context, 'Lütfen soruyu yanıtlayın');
                    return;
                  }
                  
                  if (reportViewModel.isLastQuestion) {
                    // Son soruya geldiğinde rapor oluşturmadan önce erişim hakkı kontrolü yap
                    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
                    final isPremium = authViewModel.isPremium;
                    
                    // Eğer sayfaya skipAccessCheck=true parametresiyle gelinmişse, erişim kontrolü zaten atlanmıştır
                    // Bu durumda doğrudan raporu oluştur
                    if (widget.skipAccessCheck) {
                      // Erişim kontrolü atlandığı için doğrudan raporu oluştur
                      _generateReport();
                      return;
                    }
                    
                    final hasAccess = await _accessService.canUseRelationshipTest(isPremium);
                    
                    if (!hasAccess) {
                      if (!context.mounted) return;
                      _showPremiumRequiredDialog();
                      return;
                    }
                    
                    // Kullanım hakkını artır (premium olmayan kullanıcılar için)
                    if (!isPremium) {
                      await _accessService.incrementRelationshipTestCount();
                    }
                    
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
  
  Widget _buildAnswerButtons(BuildContext context, ReportViewModel reportViewModel) {
    if (reportViewModel.currentQuestionIndex >= reportViewModel.answers.length ||
        reportViewModel.currentQuestionIndex < 0) {
      return const SizedBox.shrink();
    }
    
    final currentAnswer = reportViewModel.answers[reportViewModel.currentQuestionIndex];
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                child: _buildAnswerButton(
                  context: context,
                  text: 'Kesinlikle evet',
                  isSelected: currentAnswer == 'Kesinlikle evet',
                  color: Colors.green,
                  onTap: () => reportViewModel.saveAnswer('Kesinlikle evet'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                child: _buildAnswerButton(
                  context: context,
                  text: 'Kararsızım',
                  isSelected: currentAnswer == 'Kararsızım',
                  color: Colors.orange,
                  onTap: () => reportViewModel.saveAnswer('Kararsızım'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _buildAnswerButton(
            context: context,
            text: 'Pek sanmam',
            isSelected: currentAnswer == 'Pek sanmam',
            color: Colors.red,
            onTap: () => reportViewModel.saveAnswer('Pek sanmam'),
          ),
        ),
      ],
    );
  }
  
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

  Widget _buildReportResult(BuildContext context, ReportViewModel reportViewModel) {
    final report = reportViewModel.reportResult!;
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 10,
            bottom: 120,
          ),
          children: [
            const SizedBox(height: 20),
            
            _buildRelationshipGraph(context, reportViewModel),
            
            const SizedBox(height: 24),
            
            Text(
              'İlişkinizi Geliştirecek Öneriler',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildSuggestionList(context, report),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
        
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
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    child: CustomButton(
                      text: 'Testi Yeniden Başlat',
                      onPressed: () async {
                        final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
                        final isPremium = authViewModel.isPremium;
                        
                        // Premium değilse reklam göster
                        if (!isPremium) {
                          // Önce testi tekrar başlatma diyaloğunu göster
                          final shouldRestart = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Testi Yeniden Başlat'),
                              content: const Text('Testi yeniden başlatmak için kısa bir reklam izlemeniz gerekiyor. Devam etmek istiyor musunuz?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Vazgeç'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                  ),
                                  child: const Text('Reklam İzle'),
                                ),
                              ],
                            ),
                          );
                          
                          if (shouldRestart == true && context.mounted) {
                            // Reklam göster
                            await _showAdSimulation(AdViewType.REPORT_REGENERATE);
                            
                            // Reklam sonrası testi yeniden başlat
                            if (context.mounted) {
                          final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
                          reportViewModel.resetReport();
                          
                              setState(() {
                                _showReportResult = false;
                              });
                            }
                          }
                        } else {
                          // Premium kullanıcı için doğrudan başlat
                          try {
                            final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
                            reportViewModel.resetReport();
                            
                            setState(() {
                              _showReportResult = false;
                          });
                        } catch (e) {
                          Utils.showErrorFeedback(context, 'Test başlatılırken bir hata oluştu: $e');
                          }
                        }
                      },
                      type: ButtonType.outline,
                      icon: Icons.refresh,
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    child: CustomButton(
                      text: 'Puanla',
                      onPressed: () {
                        _showRatingDialog(context);
                      },
                      icon: Icons.star,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRelationshipGraph(BuildContext context, ReportViewModel reportViewModel) {
    final report = reportViewModel.reportResult!;
    final relationshipType = report['relationship_type'] ?? 'Belirsiz';
    final color = _getRelationshipTypeColor(relationshipType);
    final score = _calculateRelationshipScore(relationshipType);
    
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
          Text(
            'İlişki Değerlendirmesi',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
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
          
          Text(
            _getRelationshipEmoji(score),
            style: const TextStyle(fontSize: 60),
          )
          .animate()
          .fadeIn(duration: 600.ms)
          .slide(begin: const Offset(0, -0.5), end: Offset.zero),
          
          const SizedBox(height: 12),
          
          SizedBox(
            height: 60,
            width: double.infinity,
            child: AnimasyonluDalga(
              dalgaYuksekligi: score / 5,
              renk: color,
            ),
          )
          .animate()
          .fadeIn(delay: 200.ms, duration: 600.ms),
          
          const SizedBox(height: 12),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              report['ai_analysis'] as String? ?? _getFallbackRelationshipDescription(relationshipType),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          
          const SizedBox(height: 16),
          
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
  
  String _getRelationshipEmoji(int score) {
    if (score >= 90) return '😊';
    if (score >= 60) return '🙂';
    if (score >= 40) return '😟';
    return '😢';
  }
  
  int _calculateRelationshipScore(String relationshipType) {
    final Map<String, int> typeScores = {
      'Güven Odaklı': 85,
      'Tutkulu': 75,
      'Uyumlu': 80,
      'Dengeli': 90,
      'Mesafeli': 60,
      'Kaçıngan': 50,
      'Endişeli': 55,
      'Çatışmalı': 40,
      'Kararsız': 60,
      'Gelişmekte Olan': 70,
      'Sağlıklı': 95,
      'Zorlayıcı': 45,
      'Sağlıklı ve Gelişmekte Olan': 85,
    };
    
    return typeScores[relationshipType] ?? 65;
  }

  String _getFallbackRelationshipDescription(String relationshipType) {
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
  
  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green.shade600;
    if (score >= 60) return Colors.blue.shade600;
    if (score >= 40) return Colors.amber.shade600;
    if (score >= 20) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  List<Widget> _buildSuggestionList(BuildContext context, Map<String, dynamic> report) {
    final List<dynamic> suggestions = report['suggestions'] as List<dynamic>;
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
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
    
    return List.generate(suggestions.length, (index) {
      final suggestion = suggestions[index];
      
      return FutureBuilder<bool>(
        future: _accessService.isSuggestionUnlocked(index, isPremium),
        builder: (context, snapshot) {
          bool isUnlocked = isPremium ||
                         index == 0 ||
                         snapshot.data == true;
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
            child: _buildLockedWidget(
              isLocked: !isUnlocked,
              onUnlock: () {
                _showAdSimulation(AdViewType.SUGGESTION_UNLOCK, suggestionIndex: index);
              },
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
          ),
        )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 400 + (index * 100)), duration: 400.ms)
        .slideX(begin: 0.2, end: 0),
      );
        },
      );
    });
  }

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

  void _showPastReportsScreen() {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    if (!isPremium) {
      Utils.showToast(
        context,
        'Geçmiş raporlara erişim sadece Premium üyelere özeldir'
      );
      return;
    }
    
    context.push('/past-reports');
  }

  // İlk erişim kontrolü
  Future<void> _checkInitialAccess() async {
    if (!mounted) return;
    
    try {
      final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
      
      // Eğer sonuç sayfası gösteriliyorsa veya rapor zaten varsa, kontrol etmeye gerek yok
      if (_showReportResult || reportViewModel.hasReport) {
        return;
      }
      
      // Ankete başlamadan önce hak kontrolü yap
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final isPremium = authViewModel.isPremium;
      
      // Eğer sayfaya reklam izledikten sonra yönlendirme yapıldıysa (skipAccessCheck=true), 
      // erişim kontrolü atlanmalıdır
      if (widget.skipAccessCheck) {
        debugPrint('skipAccessCheck=true olduğu için erişim kontrolü atlanıyor');
        return;
      }
      
      debugPrint('İlişki değerlendirme hakkı kontrolü yapılıyor...');
      final hasAccess = await _accessService.canUseRelationshipTest(isPremium);
      
      // Asenkron işlem sonrası widget hala monte edilmiş mi kontrol et
      if (!mounted) return;
      
      if (!hasAccess) {
        debugPrint('İlişki değerlendirme hakkı yok, premium uyarısı gösteriliyor...');
        // Hak yoksa giriş engellenir ve Premium uyarısı gösterilir
        _showPremiumRequiredDialog();
      } else {
        debugPrint('İlişki değerlendirme hakkı mevcut, ankete devam ediliyor...');
      }
    } catch (e) {
      debugPrint('Erişim hakkı kontrolü sırasında hata: $e');
      // Hata durumunda sessizce devam et, kullanıcı deneyimi bozulmasın
    }
  }
}

class AnimasyonluDalga extends StatefulWidget {
  final double dalgaYuksekligi;
  final Color renk;
  
  const AnimasyonluDalga({
    super.key,
    required this.dalgaYuksekligi,
    required this.renk,
  });
  
  @override
  State<AnimasyonluDalga> createState() => _AnimasyonluDalgaState();
}

class _AnimasyonluDalgaState extends State<AnimasyonluDalga> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          height: 60,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: CustomPaint(
            painter: SimpleDalgaPainter(
              dalgaYuksekligi: widget.dalgaYuksekligi,
              dalgaSayisi: 5,
              renk: widget.renk,
              animasyonDegeri: _animationController.value * 4.0,
            ),
          ),
        );
      },
    );
  }
}

class SimpleDalgaPainter extends CustomPainter {
  final double dalgaYuksekligi;
  final int dalgaSayisi;
  final Color renk;
  final double animasyonDegeri;

  SimpleDalgaPainter({
    required this.dalgaYuksekligi,
    required this.dalgaSayisi,
    required this.renk,
    required this.animasyonDegeri,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = renk.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    final path = Path();
    final width = size.width;
    final height = size.height;
    
    final baseY = height * 0.5;
    path.moveTo(0, baseY);
    
    double waveWidth = width / dalgaSayisi;
    
    for (double i = 0; i <= dalgaSayisi; i += 0.5) {
      double x1 = i * waveWidth;
      double y1 = baseY + sin((i + animasyonDegeri) * pi) * dalgaYuksekligi;
      
      path.lineTo(x1, y1);
    }
    
    canvas.drawPath(path, paint);
    
    final fillPath = Path();
    fillPath.moveTo(0, baseY);
    
    for (double i = 0; i <= dalgaSayisi; i += 0.5) {
      double x1 = i * waveWidth;
      double y1 = baseY + sin((i + animasyonDegeri) * pi) * dalgaYuksekligi;
      fillPath.lineTo(x1, y1);
    }
    
    fillPath.lineTo(width, height);
    fillPath.lineTo(0, height);
    fillPath.close();
    
    final fillPaint = Paint()
      ..color = renk.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant SimpleDalgaPainter oldDelegate) => 
    oldDelegate.animasyonDegeri != animasyonDegeri || 
    oldDelegate.dalgaYuksekligi != dalgaYuksekligi;
}

enum AdViewType {
  TEST_ACCESS,
  REPORT_VIEW,
  REPORT_REGENERATE,
  SUGGESTION_UNLOCK,
} 