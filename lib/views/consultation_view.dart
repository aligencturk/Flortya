import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/advice_viewmodel.dart'; // Danışma işlemleri için viewmodel
import '../viewmodels/message_viewmodel.dart'; // Mesaj analizi için gerekli viewmodel
import '../utils/utils.dart';
import '../models/analysis_result_model.dart'; // AnalysisResult modeli
import '../models/analysis_type.dart'; // Analiz türleri
import '../utils/loading_indicator.dart';

class ConsultationView extends StatefulWidget {
  const ConsultationView({super.key});

  @override
  State<ConsultationView> createState() => _ConsultationViewState();
}

class _ConsultationViewState extends State<ConsultationView> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _questionHistory = [];
  
  bool _isLoading = false;
  String? _responseText;
  String? _errorMessage;

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Danışma sorusu gönderme
  Future<void> _sendQuestion() async {
    // Soru boş ise işlem yapma
    if (_questionController.text.trim().isEmpty) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _responseText = null;
    });
    
    final String query = _questionController.text.trim();
    
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    
    // Kullanıcı giriş yapmamış ise
    if (authViewModel.currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Bu özelliği kullanmak için giriş yapmanız gerekiyor.';
      });
      return;
    }
    
    try {
      // AI'dan danışma cevabı iste
      final response = await adviceViewModel.getAdvice(query);
      
      if (response.containsKey('error')) {
        setState(() {
          _isLoading = false;
          _errorMessage = response['error'].toString();
        });
        return;
      }
      
      // Başarılı yanıt 
      bool isSuccessful = false;
      
      if (response.containsKey('answer') && response['answer'] != null) {
        final responseText = response['answer'].toString();
        _saveAnswerToHistory(query, responseText);
        
        // Ana sayfayı güncellemek için sonucu analiz olarak kaydet
        try {
          // Analiz sonucu oluştur
          final AnalysisResult consultationAnalysis = AnalysisResult(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            messageId: DateTime.now().millisecondsSinceEpoch.toString(),
            emotion: 'Danışma',
            intent: 'İlişki Tavsiyesi',
            tone: 'Profesyonel',
            severity: 5,
            persons: authViewModel.currentUser?.displayName ?? '',
            aiResponse: {
              'mesaj': query,
              'mesajYorumu': responseText,
              'tavsiyeler': response['advice'] is List ? response['advice'] : [responseText],
            },
            createdAt: DateTime.now(),
          );
          
          // Analiz sonucunu kullanıcı profiline ekle ve ana sayfayı güncelle
          await messageViewModel.updateUserProfileWithAnalysis(
            authViewModel.currentUser!.uid, 
            consultationAnalysis, 
            AnalysisType.consultation
          );
        } catch (analysisError) {
          print('Danışma analiz sonucu kayıt hatası: $analysisError');
          // Sadece loglama yap, kullanıcıya gösterme
        }
        
        isSuccessful = true;
        _responseText = responseText;
      }
      
      setState(() {
        _isLoading = false;
        if (isSuccessful) {
          // UI güncelleme
        } else {
          _errorMessage = 'Cevap alınamadı, lütfen tekrar deneyin.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Danışma işlemi sırasında bir hata oluştu: $e';
      });
    }
    
    // İşlem sonrası, metin girişini temizle
    _questionController.clear();
    
    // Yanıtı görüntüle
    if (_responseText != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }
  
  // Cevabı geçmişe kaydet
  void _saveAnswerToHistory(String question, String answer) {
    setState(() {
      _questionHistory.add({
        'question': question,
        'answer': answer,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _questionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF352269),
      appBar: AppBar(
        title: const Text(
          'İlişki Danışmanı',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF352269),
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Danışma formu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3A2A70),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'İlişki Danışmanına Sorun',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'İlişkinizle ilgili sorularınızı yazın, size kişiselleştirilmiş tavsiyeler verelim.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _questionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Sorunuzu yazın...',
                    hintStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF9D3FFF)),
                    ),
                    suffixIcon: IconButton(
                      onPressed: _isLoading ? null : _sendQuestion,
                      icon: Icon(
                        Icons.send,
                        color: _isLoading ? Colors.grey : Colors.white,
                      ),
                    ),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D3FFF),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Gönder'),
                  ),
                ),
              ],
            ),
          ),
          
          // Hata mesajı
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          
          // Yanıt
          if (_responseText != null)
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A2A70),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.psychology,
                                color: Color(0xFF9D3FFF),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'İlişki Danışmanı',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _responseText!,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                  ],
                ),
              ),
            ),
          
          // Boş alan
          if (_responseText == null && _errorMessage == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.message_outlined,
                      size: 64,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'İlişkiniz hakkında bir soru sorun',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
} 