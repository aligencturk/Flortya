import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

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
  File? _selectedImage;
  bool _isImageMode = false;

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

  // Resim seçme
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    
    if (pickedImage != null) {
      setState(() {
        _selectedImage = File(pickedImage.path);
        _isImageMode = true;
      });
    }
  }

  // Mesajı gönderme ve analiz etme
  Future<void> _analyzeMessage() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    
    // Metin mesajı kontrolü
    if (!_isImageMode) {
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
    // Görüntü mesajı kontrolü
    else if (_selectedImage != null) {
      // Not: Görüntü analizi için ek fonksiyonellik gerekecek
      // Şimdilik mesaj gibi işleme alıyoruz
      final message = "Görsel mesaj: ${_selectedImage!.path.split('/').last}";
      
      // Yeni mesaj oluştur
      await messageViewModel.createMessage(authViewModel.user!.id, message);
      
      // Mesajı analiz et
      if (messageViewModel.currentMessage != null) {
        await messageViewModel.analyzeMessage(messageViewModel.currentMessage!);
        setState(() {
          _selectedImage = null;
          _isImageMode = false;
        });
      }
    }
  }

  // Mod değiştirme
  void _toggleMode() {
    setState(() {
      _isImageMode = !_isImageMode;
      // Eğer resim modu kapatılıyorsa, seçili resmi temizle
      if (!_isImageMode) {
        _selectedImage = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messageViewModel = Provider.of<MessageViewModel>(context);
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bilgi Metni
            Text(
              _isImageMode 
                  ? 'Analiz etmek istediğiniz görseli seçin.'
                  : 'Partnerinizden gelen mesajı aşağıya girin ve analiz edin.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Metin veya Görsel Girişi
            if (_isImageMode) ...[
              // Görsel Seçimi
              if (_selectedImage == null) ...[
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                  ),
                  child: InkWell(
                    onTap: () => _pickImage(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        const Text('Görsel Seçmek İçin Tıklayın'),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo),
                              label: const Text('Galeri'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Kamera'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Seçilen görseli göster
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.8),
                        child: Icon(Icons.close, color: theme.colorScheme.error),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ] else ...[
              // Mesaj Girişi
              TextField(
                controller: _messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Mesajı buraya yazın...',
                  prefixIcon: Icon(Icons.message),
                ),
              ),
            ],
            
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
            ],
          ],
        ),
      ),
    );
  }

  // Tarih formatını düzenleme
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
} 