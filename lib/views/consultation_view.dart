import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/advice_viewmodel.dart'; // Danışma işlemleri için viewmodel
import '../utils/feedback_utils.dart';

class ConsultationView extends StatefulWidget {
  const ConsultationView({super.key});

  @override
  State<ConsultationView> createState() => _ConsultationViewState();
}

class _ConsultationViewState extends State<ConsultationView> {
  final TextEditingController _consultationController = TextEditingController();
  final FocusNode _consultationFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = false;
  bool _hasConsulted = false;
  String? _aiResponse;
  
  @override
  void dispose() {
    _consultationController.dispose();
    _consultationFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // Danışma işlemini gerçekleştir
  Future<void> _submitConsultation() async {
    final query = _consultationController.text.trim();
    if (query.isEmpty) {
      FeedbackUtils.showWarningFeedback(
        context, 
        'Lütfen danışmak istediğiniz konuyu girin'
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
    
    // Kullanıcı kontrolü
    if (authViewModel.user == null) {
      if (!mounted) return;
      FeedbackUtils.showErrorFeedback(
        context, 
        'Danışma hizmetini kullanmak için lütfen giriş yapın'
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    try {
      // AI'dan danışma cevabı iste
      final response = await adviceViewModel.getAdvice(
        query, 
        authViewModel.user!.id,
      );
      
      if (!mounted) return;
      
      if (adviceViewModel.errorMessage != null) {
        FeedbackUtils.showErrorFeedback(
          context, 
          'Danışma cevabı alınırken hata: ${adviceViewModel.errorMessage}'
        );
      } else if (response != null) {
        setState(() {
          _aiResponse = response;
          _hasConsulted = true;
        });
        
        // Scroll'u aşağı kaydır
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      FeedbackUtils.showErrorFeedback(
        context, 
        'Danışma cevabı alınırken beklenmeyen hata: $e'
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Danışma bilgisi diyaloğunu göster
  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF352269),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Danışma Hakkında',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: Colors.white.withOpacity(0.2), thickness: 1),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bilgi başlığı
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9D3FFF).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lightbulb_outline,
                        color: Colors.white.withOpacity(0.9),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Danışma Nasıl Çalışır?',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Danışma özelliği bilgisi
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D3FFF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.psychology_outlined,
                            color: Colors.white.withOpacity(0.9),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Danışma Hizmeti',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bu sayfada ilişkilerinizle ilgili konularda, metin girerek danışabilirsiniz. Yapay zeka algoritması sizin metin girişinize göre değerlendirme yapacak ve size önerilerde bulunacaktır.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Uyarı metni
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber.withOpacity(0.9),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Önemli Bilgi',
                            style: TextStyle(
                              color: Colors.amber.withOpacity(0.9),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bu danışma hizmeti, profesyonel psikolojik danışmanlık yerine geçmez. Ciddi duygusal veya ilişki sorunları için lütfen bir uzmana başvurun.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Öneri metni
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tips_and_updates_outlined,
                            color: Colors.green.withOpacity(0.9),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'İpucu',
                            style: TextStyle(
                              color: Colors.green.withOpacity(0.9),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Daha iyi sonuçlar için, durumunuzu mümkün olduğunca detaylı açıklayın. Örneğin: "Partnerim 3 gündür mesajlarıma geç yanıt veriyor, ne yapmalıyım?" gibi.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              child: const Text('Anladım'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4A2A80),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const Text(
                    'Danışma',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    onPressed: () {
                      _showInfoDialog(context);
                    },
                  ),
                ],
              ),
            ),
            
            // Ana içerik
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF352269),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Başlık
                    Text(
                      'Size Nasıl Yardımcı Olabilirim?',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Bilgi notu
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
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
                              "İlişki durumunuz, duygularınız veya mesajlarla ilgili konularda danışabilirsiniz.",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Danışma içeriği (scrollable ana bölüm)
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Danışma formu
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Danışmak İstediğiniz Konuyu Girin',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _consultationController,
                                    focusNode: _consultationFocusNode,
                                    style: const TextStyle(color: Colors.white),
                                    maxLines: 5,
                                    maxLength: 500,
                                    decoration: InputDecoration(
                                      hintText: 'Örn: Partnerim mesajlarımı okumuyor ama yanıt vermiyor, ne yapmalıyım?',
                                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                      fillColor: Colors.white.withOpacity(0.05),
                                      filled: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: const Color(0xFF9D3FFF).withOpacity(0.5)),
                                      ),
                                      counterStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _submitConsultation,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF9D3FFF),
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: const Color(0xFF9D3FFF).withOpacity(0.4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.psychology, size: 18),
                                                SizedBox(width: 8),
                                                Text('Danış'),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // AI Cevabı - Danışma sonucu
                            if (_hasConsulted && _aiResponse != null) ...[
                              Text(
                                'Değerlendirme',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9D3FFF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF9D3FFF).withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.psychology,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _aiResponse!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _consultationController.clear();
                                              _aiResponse = null;
                                              _hasConsulted = false;
                                            });
                                            _consultationFocusNode.requestFocus();
                                          },
                                          icon: const Icon(Icons.refresh, size: 16),
                                          label: const Text('Yeni Danışma'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),
                            ],
                            
                            if (!_hasConsulted) ...[
                              const SizedBox(height: 36),
                              _buildSuggestedQuestions(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Örnek sorular widget'ı
  Widget _buildSuggestedQuestions() {
    final List<Map<String, dynamic>> suggestions = [
      {
        'icon': Icons.question_answer_outlined,
        'title': 'Mesaj Cevapları',
        'questions': [
          'Partnerim mesajlarıma geç yanıt veriyor, ne yapmalıyım?',
          'Partnerim mesajlarımı görmezden geliyor, bu ne anlama gelir?',
        ],
      },
      {
        'icon': Icons.favorite_border,
        'title': 'İlişki Sorunları',
        'questions': [
          'Partnerimle iletişim sorunları yaşıyorum, nasıl düzeltebilirim?',
          'İlişkimizde güven sorunu var, ne yapabilirim?',
        ],
      },
      {
        'icon': Icons.mood_bad_outlined,
        'title': 'Duygusal Konular',
        'questions': [
          'Partnerim duygularını paylaşmıyor, nasıl açılmasını sağlayabilirim?',
          'Sürekli kıskançlık hissediyorum, bu duyguyla nasıl başa çıkabilirim?',
        ],
      },
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Danışabileceğiniz Örnek Konular',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        ...suggestions.map((category) => _buildSuggestionCategory(category)),
      ],
    ).animate().fadeIn(duration: 800.ms);
  }
  
  // Öneri kategorisi widget'ı
  Widget _buildSuggestionCategory(Map<String, dynamic> category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                category['icon'] as IconData,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                category['title'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List<String>.from(category['questions']).map(
            (question) => _buildQuestionChip(question),
          ),
        ],
      ),
    );
  }
  
  // Soru önerisi widget'ı
  Widget _buildQuestionChip(String question) {
    return GestureDetector(
      onTap: () {
        _consultationController.text = question;
        _consultationFocusNode.requestFocus();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.arrow_right_alt,
              color: Color(0xFF9D3FFF),
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                question,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 