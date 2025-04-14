import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/message_viewmodel.dart';
import '../widgets/analysis_result_box.dart';
import '../widgets/custom_button.dart';
import '../services/ocr_service.dart';
import '../models/message.dart';
import '../widgets/chat_bubble.dart';
import '../models/analysis_result_model.dart';
import '../constants/colors.dart';
import '../constants/text_styles.dart';
import '../models/text_recognition_script.dart' as local;

class MessageAnalysisView extends StatefulWidget {
  const MessageAnalysisView({Key? key}) : super(key: key);

  @override
  State<MessageAnalysisView> createState() => _MessageAnalysisViewState();
}

class _MessageAnalysisViewState extends State<MessageAnalysisView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showDetailedAnalysis = false;
  File? _selectedImage;
  bool _isImageMode = false;
  bool _isProcessingImage = false;
  final OcrService _ocrService = OcrService();
  String? _extractedText;
  
  // Artık dil seçimi kaldırıldı - Sadece Latin/Türkçe destekleniyor
  local.TextRecognitionScript _selectedScript = local.TextRecognitionScript.latin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  // Kullanıcının mesajlarını yükleme
  Future<void> _loadMessages() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    
    if (authViewModel.user != null) {
      await messageViewModel.loadMessages(authViewModel.user!.id);
    }
  }

  // Resim seçme
  Future<void> _pickImage() async {
    setState(() {
      _isProcessingImage = true;
    });
    
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,  // Daha iyi OCR performansı için yüksek kalite
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        setState(() {
          _selectedImage = imageFile;
        });

        // OCR ile metin çıkarma
        try {
          String extractedText = await _ocrService.metniOku(imageFile);
          
          setState(() {
            _extractedText = extractedText;
            _isProcessingImage = false;
          });
          
          if (extractedText.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Görüntüden metin çıkarılamadı. Lütfen açıklama ekleyin.'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.text_fields, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Metin başarıyla çıkarıldı'),
                          Text(
                            '${extractedText.length} karakter bulundu',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          setState(() {
            _isProcessingImage = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Metin çıkarma hatası: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        setState(() {
          _isProcessingImage = false;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Görüntü seçme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Mesajı gönderme ve analiz etme
  void _sendMessage() {
    final viewModel = Provider.of<MessageViewModel>(context, listen: false);
    String messageText = _messageController.text.trim();
    
    if ((messageText.isEmpty && _selectedImage == null) || _isProcessingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text('Lütfen bir mesaj girin veya resim seçin')),
            ],
          ),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    // Önceki analiz sonuçlarını temizle
    viewModel.clearCurrentMessage();
    
    setState(() {
      _isProcessingImage = true;
    });

    String messageContent = '';
    
    if (_selectedImage != null) {
      messageContent = "Ekran görüntüsü: ";
      
      if (_extractedText != null && _extractedText!.isNotEmpty) {
        messageContent += "\nGörseldeki metin: $_extractedText";
      }
      
      if (messageText.isNotEmpty) {
        messageContent += "\nAçıklama: $messageText";
      } else if (_extractedText == null || _extractedText!.isEmpty) {
        // Hem metin çıkarılamamış hem de açıklama eklenmemişse uyarı ver
        setState(() {
          _isProcessingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Görselinizdeki metin okunamadı. Lütfen açıklama ekleyin.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } else {
      messageContent = messageText;
    }

    _analyzeMessage(messageContent);
  }

  // Mesaj analizi
  void _analyzeMessage(String messageContent) async {
    final viewModel = Provider.of<MessageViewModel>(context, listen: false);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    try {
      final userId = authViewModel.user?.id;
      
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesaj göndermek için giriş yapmalısınız'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Mesajı veritabanına kaydet
      await viewModel.addMessage(messageContent, userId);
      
      // Mevcut mesajı alalım
      final message = viewModel.currentMessage;
      if (message == null) {
        throw Exception('Mesaj eklenirken bir hata oluştu');
      }
      
      // ID boş mu kontrol et
      if (message.id.isEmpty) {
        throw Exception('Geçersiz mesaj ID');
      }

      // Resim varsa yükle
      if (_selectedImage != null) {
        await viewModel.uploadMessageImage(message.id, _selectedImage!);
      }

      // Mesajı analiz et
      await viewModel.analyzeMessage(message.id);

      // Mesaj listesini yenile
      if (authViewModel.user != null) {
        await viewModel.loadMessages(authViewModel.user!.id);
      }

      // Giriş alanlarını temizle
      setState(() {
        _messageController.clear();
        _selectedImage = null;
        _extractedText = null;
        _isProcessingImage = false;
        // Detaylı analiz bölümünü varsayılan olarak kapat
        _showDetailedAnalysis = false;
      });
      
      // Debug amaçlı kontroller
      debugPrint('ViewModel sonrası analiz sonucu: ${viewModel.hasAnalysisResult}');
      debugPrint('ViewModel sonrası mesaj: ${viewModel.hasCurrentMessage}');
      
      // Ekstra bir yeniden çizim çağrısı ekleyelim
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesaj analizi sırasında hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      setState(() {
        _isProcessingImage = false;
      });
    }
  }

  // Mod değiştirme
  void _toggleMode() {
    setState(() {
      _isImageMode = !_isImageMode;
      // Eğer resim modu kapatılıyorsa, seçili resmi temizle
      if (!_isImageMode) {
        _selectedImage = null;
        _extractedText = null;
      }
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final messageViewModel = Provider.of<MessageViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesaj Analizi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Metin/Görsel modu geçiş butonu
          IconButton(
            icon: Icon(_isImageMode ? Icons.text_fields : Icons.image),
            onPressed: _toggleMode,
            tooltip: _isImageMode ? 'Metin Moduna Geç' : 'Görsel Moduna Geç',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Partnerden gelen mesaj bilgisi
              Text(
                'Partnerinizden gelen mesajı aşağıya girin ve analiz edin.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Mesaj Girişi
              TextField(
                controller: _messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Mesajı buraya yazın...',
                  prefixIcon: const Icon(Icons.message),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Geçmiş Analizler Bölümü - aktif analiz yoksa göster
              if (!messageViewModel.hasCurrentMessage && !messageViewModel.isLoading) 
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Geçmiş Analizler',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Geçmiş analizler listesi
                    SizedBox(
                      height: 300, // Sabit yükseklik ile liste alanını sınırla
                      child: _buildHistoryList(),
                    ),
                  ],
                ),
              
              // Aktif analiz veya yükleniyor durumu
              if (messageViewModel.hasCurrentMessage || messageViewModel.isLoading)
                _buildAnalysisResult(),
              
              const SizedBox(height: 24),
              
              // Analiz Butonu - sadece analiz gösterilmiyorsa göster
              if (!messageViewModel.hasCurrentMessage)
                CustomButton(
                  text: 'Mesajı Analiz Et',
                  onPressed: _isProcessingImage ? () {} : _sendMessage,
                  icon: Icons.psychology,
                  isLoading: messageViewModel.isLoading || _isProcessingImage,
                  isFullWidth: true,
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: messageViewModel.hasCurrentMessage ? 
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: CustomButton(
            text: 'Geçmiş Analizlere Dön',
            onPressed: () {
              messageViewModel.clearCurrentMessage();
              setState(() {
                _showDetailedAnalysis = false;
              });
            },
            icon: Icons.history,
            isFullWidth: true,
          ),
        ) : null,
    );
  }

  // Analiz sonuçlarını gösteren widget
  Widget _buildAnalysisResult() {
    final messageViewModel = Provider.of<MessageViewModel>(context);
    
    if (messageViewModel.isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Mesaj analiz ediliyor...')
            ],
          ),
        ),
      );
    }
    
    if (messageViewModel.hasAnalysisResult && messageViewModel.currentAnalysisResult != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analiz Sonucu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Mesaj İçeriği
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mesaj:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(messageViewModel.currentMessage?.content ?? ''),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Analiz Sonucu Kutusu
          AnalysisResultBox(
            result: messageViewModel.currentAnalysisResult!,
            showDetailedInfo: _showDetailedAnalysis,
            onTap: () {
              setState(() {
                _showDetailedAnalysis = !_showDetailedAnalysis;
              });
            },
          ),
        ],
      ).animate().fadeIn(duration: 400.ms);
    } else if (messageViewModel.errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                messageViewModel.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox(); // Boş durum
  }
  
  // Geçmiş analizler listesi
  Widget _buildHistoryList() {
    final messageViewModel = Provider.of<MessageViewModel>(context);
    
    if (messageViewModel.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz analiz yapılmamış',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Analiz için bir mesaj girin veya görsel yükleyin',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: messageViewModel.messages.length,
      itemBuilder: (context, index) {
        final message = messageViewModel.messages[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              message.content.length > 30 
                  ? '${message.content.substring(0, 30)}...' 
                  : message.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(message.sentAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            trailing: message.isAnalyzed
              ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
              : Icon(Icons.circle_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
            onTap: () async {
              // Burada önce önceki analizi temizleyelim
              messageViewModel.clearCurrentMessage();
              
              // Boş ID kontrolü
              if (message.id.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Geçersiz mesaj ID'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              // Mesajı yükle
              await messageViewModel.getMessage(message.id);
              
              if (message.isAnalyzed) {
                await messageViewModel.getAnalysisResult(message.id);
                
                setState(() {
                  _showDetailedAnalysis = false;
                });
              } else {
                // Henüz analiz edilmemiş mesajı analiz et
                await messageViewModel.analyzeMessage(message.id);
              }
            },
          ),
        ).animate().fadeIn(duration: 300.ms, delay: (50 * index).ms).slideX(begin: 0.2, end: 0);
      },
    );
  }

  // Tarih formatını düzenleme
  String _formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }
} 