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
import '../models/analysis_result.dart';
import '../constants/colors.dart';
import '../constants/text_styles.dart';

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
  bool _isMultiLanguageMode = false;
  TextRecognitionScript _selectedScript = TextRecognitionScript.latin;

  final Map<TextRecognitionScript, String> _scriptNames = {
    TextRecognitionScript.latin: 'Latin (Türkçe, İngilizce vb.)',
    TextRecognitionScript.chinese: 'Çince',
    TextRecognitionScript.devanagari: 'Devanagari (Hintçe)',
    TextRecognitionScript.japanese: 'Japonca',
    TextRecognitionScript.korean: 'Korece',
  };

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
          String extractedText;
          
          if (_isMultiLanguageMode) {
            // Çoklu dil modunda tüm dilleri dene
            extractedText = await _ocrService.otomatikDilTanima(imageFile);
          } else {
            // Tek dil modunda seçilen dili kullan
            extractedText = await _ocrService.metniOku(imageFile, script: _selectedScript);
          }
          
          setState(() {
            _extractedText = extractedText;
            _isProcessingImage = false;
          });
          
          if (extractedText.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Görüntüden metin çıkarılamadı. Lütfen açıklama ekleyin veya farklı bir dil seçin.'),
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
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: messageContent,
        sentAt: DateTime.now(),
        sentByUser: true,
        isAnalyzed: false,
      );

      // Mesajı veritabanına kaydet
      await viewModel.addMessage(message);

      // Resim varsa yükle
      if (_selectedImage != null) {
        await viewModel.uploadMessageImage(message.id, _selectedImage!);
      }

      // Mesajı analiz et
      await viewModel.analyzeMessage(message);

      // Giriş alanlarını temizle
      setState(() {
        _messageController.clear();
        _selectedImage = null;
        _extractedText = null;
        _isProcessingImage = false;
      });

      // Otomatik kaydırma
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      setState(() {
        _isProcessingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesaj gönderme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
          
          // Dil seçimi menüsü (sadece görsel modunda)
          if (_isImageMode)
            PopupMenuButton<dynamic>(
              icon: const Icon(Icons.language),
              tooltip: 'OCR Dil Seçimi',
              itemBuilder: (context) => [
                // Çoklu dil seçeneği
                PopupMenuItem(
                  value: 'multilang',
                  child: StatefulBuilder(
                    builder: (context, setState) => CheckboxListTile(
                      title: const Text('Otomatik Dil Algılama'),
                      subtitle: const Text('Tüm diller denenir'),
                      value: _isMultiLanguageMode,
                      onChanged: (value) {
                        setState(() {
                          _isMultiLanguageMode = value!;
                        });
                        this.setState(() {});
                        Navigator.pop(context);
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  ),
                ),
                
                // Dil seçenekleri
                const PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Dil Seçimi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                
                // Desteklenen diller
                ..._scriptNames.entries.map((entry) => PopupMenuItem(
                  value: entry.key,
                  enabled: !_isMultiLanguageMode,
                  child: RadioListTile<TextRecognitionScript>(
                    title: Text(entry.value),
                    value: entry.key,
                    groupValue: _selectedScript,
                    onChanged: !_isMultiLanguageMode ? (value) {
                      setState(() {
                        _selectedScript = value!;
                      });
                      Navigator.pop(context);
                    } : null,
                    dense: true,
                  ),
                )),
              ],
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bilgi Metni
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _isImageMode 
                    ? 'Analiz etmek istediğiniz görseli seçin.'
                    : 'Partnerinizden gelen mesajı aşağıya girin ve analiz edin.',
                key: ValueKey<bool>(_isImageMode),
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Metin veya Görsel Girişi
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _isImageMode
                    ? _buildImageInputSection(theme)
                    : _buildTextInputSection(theme),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Analiz Butonu
            CustomButton(
              text: 'Mesajı Analiz Et',
              onPressed: _isProcessingImage ? null : _sendMessage,
              icon: Icons.psychology,
              isLoading: messageViewModel.isLoading || _isProcessingImage,
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInputSection(ThemeData theme) {
    return Column(
      key: const ValueKey<String>('textInput'),
      children: [
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
        
        const SizedBox(height: 32),
          
        // Analiz Sonuçları veya Geçmiş Analizler
        Expanded(
          child: _buildAnalysisResultsSection(),
        ),
      ],
    );
  }

  Widget _buildImageInputSection(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey<String>('imageInput'),
      child: Column(
        children: [
          // Dil Seçimi Bilgisi
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isMultiLanguageMode
                        ? 'Otomatik dil algılama aktif - Tüm diller denenecek'
                        : 'Seçili dil: ${_scriptNames[_selectedScript]}',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.language, size: 20),
                  onPressed: () {
                    // Burada dil seçim menüsünü açabilirsiniz veya AppBar'daki butonu kullanabilirsiniz
                  },
                  tooltip: 'Dil Seçimi',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          
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
                onTap: _pickImage,
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
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo),
                          label: const Text('Galeri'),
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
            Column(
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    GestureDetector(
                      onTap: _pickImage, // Görsel tıklanınca yenisini seçme imkanı
                      child: Hero(
                        tag: 'selectedImage',
                        child: Container(
                          height: 250,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.contain,
                              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: theme.colorScheme.primary.withOpacity(0.5),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: child,
                                ),
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      margin: const EdgeInsets.all(8),
                      child: IconButton(
                        icon: Icon(Icons.close, color: theme.colorScheme.error),
                        onPressed: () {
                          setState(() {
                            _selectedImage = null;
                            _messageController.clear();
                            _extractedText = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                
                if (_isProcessingImage) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.text_fields, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Görseldeki metin okunuyor...',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms).shimmer(duration: 1200.ms, curve: Curves.easeInOut),
                ],
                
                if (_extractedText != null && !_isProcessingImage) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.05),
                            theme.colorScheme.primary.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.text_fields, color: theme.colorScheme.primary, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Görselden Okunan Metin',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (_extractedText!.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_extractedText!.length} karakter',
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          
                          // Kullanılan dil bilgisi
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 4),
                            child: Row(
                              children: [
                                Icon(Icons.language, size: 16, color: theme.colorScheme.primary.withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Text(
                                  _isMultiLanguageMode
                                      ? 'Otomatik dil algılama kullanıldı'
                                      : 'Kullanılan dil: ${_scriptNames[_selectedScript]}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.primary.withOpacity(0.8),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const Divider(height: 24, thickness: 1),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: _extractedText!.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.text_snippet_outlined,
                                          size: 48,
                                          color: theme.colorScheme.error.withOpacity(0.7),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Metne rastlanmadı',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.error,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Column(
                                          children: [
                                            const Text(
                                              'Lütfen görsel için bir açıklama yazın',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(fontSize: 14),
                                            ),
                                            const SizedBox(height: 8),
                                            OutlinedButton.icon(
                                              onPressed: () {
                                                if (!_isMultiLanguageMode) {
                                                  setState(() {
                                                    _isMultiLanguageMode = true;
                                                  });
                                                  _pickImage();
                                                } else {
                                                  // Farklı bir dil seçmeyi öner
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text('Farklı Bir Dil Deneyin'),
                                                      content: const Text('Görseldeki metin farklı bir alfabede olabilir. Dil seçimi yaparak tekrar deneyebilirsiniz.'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          child: const Text('Tamam'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }
                                              },
                                              icon: Icon(
                                                _isMultiLanguageMode ? Icons.settings : Icons.auto_awesome,
                                                size: 16,
                                              ),
                                              label: Text(
                                                _isMultiLanguageMode ? 'Dil Seçimi Yap' : 'Otomatik Dil Algılamayı Dene',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Card(
                                  elevation: 0,
                                  color: theme.colorScheme.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Metin içeriği
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxHeight: 180),
                                        child: Scrollbar(
                                          thickness: 4,
                                          radius: const Radius.circular(8),
                                          child: SingleChildScrollView(
                                            padding: const EdgeInsets.all(16),
                                            child: SelectableText(
                                              _extractedText!,
                                              style: TextStyle(
                                                fontSize: 15,
                                                height: 1.6,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      // Kopyalama ve diğer işlem butonları
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              onPressed: () {
                                                Clipboard.setData(ClipboardData(text: _extractedText!));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Metin panoya kopyalandı'),
                                                    duration: Duration(seconds: 2),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(Icons.copy, size: 18),
                                              tooltip: 'Metni Kopyala',
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  _messageController.text = _extractedText!;
                                                });
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Metin açıklama alanına kopyalandı'),
                                                    duration: Duration(seconds: 2),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(Icons.description, size: 18),
                                              tooltip: 'Açıklama Alanına Kopyala',
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            if (!_isMultiLanguageMode) 
                                              IconButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _isMultiLanguageMode = true;
                                                  });
                                                  _pickImage();
                                                },
                                                icon: const Icon(Icons.auto_awesome, size: 18),
                                                tooltip: 'Otomatik Dil Algılamayı Dene',
                                                visualDensity: VisualDensity.compact,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
                ],
                
                const SizedBox(height: 20),
                // Görsel açıklama alanı
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Görsel hakkında açıklama yazın (görseldeki mesaj, konuşma vs.)',
                    helperText: 'Görsel içeriğini detaylandırarak daha iyi analiz edilmesini sağlayabilirsiniz',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildAnalysisResultsSection() {
    final messageViewModel = Provider.of<MessageViewModel>(context);

    if (messageViewModel.hasAnalysisResult) {
      return SingleChildScrollView(
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
      );
    } else if (messageViewModel.errorMessage != null) {
      // Hata mesajı
      return Container(
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
      );
    } else if (!messageViewModel.hasCurrentMessage && messageViewModel.messages.isNotEmpty) {
      // Geçmiş mesajlar
      return Column(
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
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      message.content,
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
                ).animate().fadeIn(duration: 300.ms, delay: (50 * index).ms).slideX(begin: 0.2, end: 0);
              },
            ),
          ),
        ],
      );
    } else {
      // Boş durum
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
              'Analiz için bir mesaj girin',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Girdiğiniz mesaj burada analiz edilecek',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  // Tarih formatını düzenleme
  String _formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }
} 