import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/advice_viewmodel.dart'; // Danışma işlemleri için viewmodel
import '../viewmodels/message_viewmodel.dart'; // Mesaj analizi için gerekli viewmodel
import '../utils/feedback_utils.dart';
import '../models/analysis_result_model.dart'; // AnalysisResult modeli
import '../models/analysis_type.dart'; // Analiz türleri
import '../utils/loading_indicator.dart';

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
  AnalysisResult? _analysisResult; // Analiz sonucunu tutacak değişken
  
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
      _hasConsulted = false;
      _aiResponse = null;
      _analysisResult = null;
    });
    
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    
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
        // AI yanıtını işle
        final analysisData = _processAIResponse(response, query);
        
        // Analiz sonucunu oluştur
        final analysisResult = AnalysisResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          messageId: 'consultation_${DateTime.now().millisecondsSinceEpoch}',
          emotion: '', // Danışma analizi için duygu boş bırakılıyor
          intent: analysisData['niyet'] ?? 'Danışma analizi',
          tone: 'Bilgilendirici',
          severity: 5,
          persons: '',
          aiResponse: {
            'niyet': analysisData['niyet'] ?? '',
            'tavsiyeler': analysisData['tavsiyeler'] ?? [],
            'messageComment': analysisData['özet'] ?? '',
            'messageType': 'consultation',
          },
          createdAt: DateTime.now(),
        );
        
        // Veritabanına konsültasyon sonucunu kaydet - isteğe bağlı
        await _saveConsultationResult(
          authViewModel.user!.id, 
          query, 
          analysisResult
        );
        
        setState(() {
          _aiResponse = response;
          _hasConsulted = true;
          _analysisResult = analysisResult;
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
  
  // AI yanıtını işleme
  Map<String, dynamic> _processAIResponse(String response, String originalQuery) {
    Map<String, dynamic> result = {
      'niyet': '',
      'tavsiyeler': <String>[],
      'özet': '',
    };
    
    try {
      // Basit metin işleme ile yanıtı analiz et
      // NOT: Bu kısım yapay zeka yanıtının formatına göre özelleştirilmelidir
      final paragraphs = response.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
      
      if (paragraphs.isEmpty) {
        result['özet'] = response;
        return result;
      }
      
      // İlk paragrafı niyet olarak al
      if (paragraphs.isNotEmpty) {
        result['niyet'] = paragraphs.first.trim();
      }
      
      // Diğer paragrafları tavsiyeler olarak al
      if (paragraphs.length > 1) {
        List<String> tavsiyeler = [];
        
        // Maddeler halinde yanıt verilmişse
        if (paragraphs.any((p) => p.contains('- '))) {
          for (var p in paragraphs.skip(1)) {
            final items = p.split('\n- ');
            for (var item in items) {
              final cleanItem = item.replaceAll('- ', '').trim();
              if (cleanItem.isNotEmpty) {
                tavsiyeler.add(cleanItem);
              }
            }
          }
        } else {
          // Maddeler yoksa, paragrafları kullan
          tavsiyeler = paragraphs.skip(1).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
        }
        
        // Tavsiye sayısını 5 ile sınırla
        result['tavsiyeler'] = tavsiyeler.take(5).toList();
      }
      
      // Özet
      result['özet'] = "${result['niyet']}\n\n${(result['tavsiyeler'] as List).join('\n')}";
      
      return result;
    } catch (e) {
      debugPrint('AI yanıtı işlenirken hata: $e');
      result['özet'] = response;
      return result;
    }
  }

  // Konsültasyon sonucunu veritabanına kaydetme
  Future<void> _saveConsultationResult(String userId, String question, AnalysisResult analysisResult) async {
    try {
      // Firestore referansı
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      // Kullanıcının consultation_results koleksiyonuna kaydet
      await firestore
          .collection('users')
          .doc(userId)
          .collection('consultation_results')
          .add({
            'question': question,
            'messageId': analysisResult.messageId,
            'intent': analysisResult.intent,
            'tone': analysisResult.tone,
            'severity': analysisResult.severity,
            'aiResponse': analysisResult.aiResponse,
            'createdAt': Timestamp.fromDate(analysisResult.createdAt),
          });
      
      // Kullanıcı profilini güncellemek için MessageViewModel'i kullan
      final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
      // updateUserProfileWithAnalysis metodunu çağır
      await messageViewModel.updateUserProfileWithAnalysis(userId, analysisResult, AnalysisType.consultation);
      
      debugPrint('Danışma sonucu veritabanına kaydedildi ve kullanıcı profili güncellendi');
    } catch (e) {
      debugPrint('Danışma sonucu kaydedilirken hata: $e');
      // Hatayı yut, kullanıcıya gösterme (opsiyonel)
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
                                      hintText: 'Örn: Partnerimle aramız biraz gergin. Nasıl yaklaşmalıyım?',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 12,
                                      ),
                                      fillColor: Colors.white.withOpacity(0.05),
                                      filled: true,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.1),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF9D3FFF),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _submitConsultation,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF9D3FFF),
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: const Color(0xFF9D3FFF).withOpacity(0.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? Center(
                                              child: YuklemeAnimasyonu(
                                                renk: Colors.pinkAccent,
                                              ),
                                            )
                                          : const Text('Danış'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Analiz sonucu
                            if (_hasConsulted && _analysisResult != null)
                              _buildAnalysisResult(),
                            
                            // AI yanıtı
                            if (_hasConsulted && _aiResponse != null && _analysisResult == null)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF9D3FFF).withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.psychology_outlined,
                                            color: Colors.white.withOpacity(0.9),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Danışma Yanıtı',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.9),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _aiResponse!,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
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
  
  // Analiz sonucu widget'ı
  Widget _buildAnalysisResult() {
    if (_analysisResult == null) return const SizedBox.shrink();
    
    // AnalysisResult model'inden veri çıkarma
    final niyetYorumu = _analysisResult!.intent;
    final List<String> tavsiyeler = _analysisResult!.aiResponse['tavsiyeler'] != null 
        ? List<String>.from(_analysisResult!.aiResponse['tavsiyeler'])
        : [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analiz Sonucu',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        
        // Niyet Yorumu
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              const Row(
                children: [
                  Icon(Icons.psychology, color: Colors.white70, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Niyet',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // İçerik
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  niyetYorumu,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Tavsiyeler
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.white70, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Tavsiyeler',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // İçerik
              Column(
                children: tavsiyeler.isEmpty
                    ? [
                        Text(
                          'Tavsiye bulunamadı',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      ]
                    : [
                        ...tavsiyeler.map((tavsiye) => _buildAdviceItem(tavsiye))
                      ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Yasal uyarı notu
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
                  "Not: Bu içerikler yol gösterici niteliktedir ve profesyonel danışmanlık hizmeti yerine geçmez.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }
  
  // Tavsiye öğesi widget'ı
  Widget _buildAdviceItem(String advice) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF9D3FFF).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF9D3FFF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              advice,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 