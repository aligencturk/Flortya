import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/message_viewmodel.dart';
import '../widgets/analysis_result_box.dart';
import '../widgets/custom_button.dart';

class MessageAnalysisView extends StatefulWidget {
  const MessageAnalysisView({Key? key}) : super(key: key);

  @override
  State<MessageAnalysisView> createState() => _MessageAnalysisViewState();
}

class _MessageAnalysisViewState extends State<MessageAnalysisView> {
  final TextEditingController _messageController = TextEditingController();
  bool _showDetailedAnalysis = false;

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

  // Mesajı gönderme ve analiz etme
  Future<void> _analyzeMessage() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    
    final message = _messageController.text.trim();
    
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir mesaj girin')),
      );
      return;
    }
    
    // Yeni mesaj oluştur
    await messageViewModel.createMessage(authViewModel.user!.id, message);
    
    // Mesajı analiz et
    if (messageViewModel.currentMessage != null) {
      await messageViewModel.analyzeMessage(messageViewModel.currentMessage!);
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageViewModel = Provider.of<MessageViewModel>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesaj Analizi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bilgi Metni
            Text(
              'Partnerinizden gelen mesajı aşağıya girin ve analiz edin.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Mesaj Girişi
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Mesajı buraya yazın...',
                prefixIcon: Icon(Icons.message),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Analiz Butonu
            CustomButton(
              text: 'Mesajı Analiz Et',
              onPressed: _analyzeMessage,
              icon: Icons.psychology,
              isLoading: messageViewModel.isLoading,
              isFullWidth: true,
            ),
            
            const SizedBox(height: 32),
            
            // Analiz Sonucu (varsa)
            if (messageViewModel.hasAnalysisResult) ...[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
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
                  ),
                ),
              ),
            ] else if (messageViewModel.errorMessage != null) ...[
              // Hata mesajı
              Container(
                padding: const EdgeInsets.all(16),
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
              ),
            ] else if (!messageViewModel.hasCurrentMessage && messageViewModel.messages.isNotEmpty) ...[
              // Geçmiş mesajlar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Geçmiş Analizler',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Expanded(
                      child: ListView.builder(
                        itemCount: messageViewModel.messages.length,
                        itemBuilder: (context, index) {
                          final message = messageViewModel.messages[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                message.content,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'Tarih: ${_formatDate(message.timestamp)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              trailing: message.isAnalyzed
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.circle_outlined, color: Colors.grey),
                              onTap: () async {
                                // Mesajı ve analiz sonucunu yükle
                                await messageViewModel.getMessage(message.id);
                                
                                if (message.isAnalyzed) {
                                  await messageViewModel.getAnalysisResult(message.id);
                                  
                                  setState(() {
                                    _showDetailedAnalysis = false;
                                  });
                                } else {
                                  // Henüz analiz edilmemiş mesajı analiz et
                                  await messageViewModel.analyzeMessage(message);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Boş durum
              Expanded(
                child: Center(
                  child: messageViewModel.isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Henüz hiç mesaj analizi yapmadınız.\nYukarıdan bir mesaj girerek başlayın.',
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Tarih formatlama yardımcı metodu
  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
} 