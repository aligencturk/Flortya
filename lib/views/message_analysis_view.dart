import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:file_selector/file_selector.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/message_viewmodel.dart';
import '../utils/feedback_utils.dart';
import '../models/message.dart';

// Mesaj sınıfı için extension
extension MessageExtension on Message {
  String get formattedCreatedAt {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return formatter.format(sentAt);
  }
}

class MessageAnalysisView extends StatefulWidget {
  const MessageAnalysisView({super.key});

  @override
  State<MessageAnalysisView> createState() => _MessageAnalysisViewState();
}

class _MessageAnalysisViewState extends State<MessageAnalysisView> {
  static bool _messagesLoaded = false; // Sınıf seviyesinde tanımlandı
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    
    // Bir kez çağırma garantisi
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Eğer daha önce mesajlar yüklenmediyse yükle
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      
      if (!_messagesLoaded && authViewModel.user != null) {
        debugPrint('initState - İlk kez mesaj yükleniyor - User ID: ${authViewModel.user!.id}');
        _loadMessages();
        _messagesLoaded = true; // Statik flag'i güncelle
      } else {
        debugPrint('initState - Mesajlar daha önce yüklenmiş, tekrar yükleme atlanıyor');
      }
    });
  }

  // Mesajları yükle
  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });
    
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    // Kullanıcı kontrolü
    if (authViewModel.user == null) {
      if (!mounted) return;
      FeedbackUtils.showErrorFeedback(
        context, 
        'Mesajlarınızı yüklemek için lütfen giriş yapın'
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    try {
      debugPrint('Tek seferlik yükleme başlıyor...');
      await messageViewModel.loadMessages(authViewModel.user!.id);
      
      if (!mounted) return;
      
      debugPrint('Mesaj yükleme tamamlandı. Mesaj sayısı: ${messageViewModel.messages.length}');
      
      if (messageViewModel.errorMessage != null) {
        FeedbackUtils.showErrorFeedback(
          context, 
          'Mesajlar yüklenirken hata: ${messageViewModel.errorMessage}'
        );
      }
    } catch (e) {
      if (!mounted) return;
      FeedbackUtils.showErrorFeedback(
        context, 
        'Mesajlar yüklenirken beklenmeyen hata: $e'
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Bilgi diyaloğunu göster
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
                'Mesaj Analizi Hakkında',
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
                        'Mesaj Analizi Sonuçları',
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
                
                // Yeni danışma özelliği bilgisi
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
                            Icons.new_releases_outlined,
                            color: Colors.white.withOpacity(0.9),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Yeni Özellik',
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
                        'Artık ilişki analizi ve danışma işlevlerini ayrı ekranlarda bulabilirsiniz. Özel bir konuda danışmak için "Danış" butonunu kullanabilirsiniz.',
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
                        'Bu analiz sonuçları yol gösterici niteliktedir ve profesyonel psikolojik danışmanlık yerine geçmez. Ciddi ilişki sorunları için lütfen bir uzmana başvurun.',
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
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final messageViewModel = Provider.of<MessageViewModel>(context);
    
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
                    'Mesaj Analizi',
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
                    // Başlık ve Danışma Butonu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Analiz Et',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Danışma sayfasına yönlendir
                            context.push('/consultation');
                          },
                          icon: Icon(Icons.chat_outlined, size: 18),
                          label: Text('Danış'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9D3FFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
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
                              "Bir ekran görüntüsü yükleyerek veya .txt dosyası seçerek mesajlarınızı analiz edebilirsiniz.",
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
                    
                    // Yükleme kartları
                    Row(
                      children: [
                        // Görsel Yükleme Kartı
                        Expanded(
                          child: _buildUploadCard(
                            icon: Icons.image_outlined,
                            title: 'Görsel Yükle',
                            subtitle: 'Ekran görüntüsü veya mesaj fotoğrafı yükleyin',
                            onTap: () => _pickImage(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Metin Dosyası Yükleme Kartı
                        Expanded(
                          child: _buildUploadCard(
                            icon: Icons.text_snippet_outlined,
                            title: 'Metin Yükle',
                            subtitle: '.txt dosyası yükleyin',
                            onTap: () => _pickTextFile(context),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Başlık
                    Text(
                      'Son Analizleriniz',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Analiz sonuçları listesi
                    Expanded(
                      child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: Color(0xFF9D3FFF)))
                        : messageViewModel.messages.isEmpty
                          ? _buildEmptyState()
                          : _buildAnalysisList(messageViewModel),
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
  
  // Yükleme kartı oluşturucu
  Widget _buildUploadCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white.withOpacity(0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: const Color(0xFF9D3FFF),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Görsel seçme işlemi
  Future<void> _pickImage(BuildContext context) async {
    try {
      // XFile tipinde görsel seçme
      final XTypeGroup typeGroup = XTypeGroup(
        label: 'Görseller',
        extensions: ['jpg', 'jpeg', 'png'],
      );
      
      final XFile? image = await openFile(
        acceptedTypeGroups: [typeGroup],
      );
      
      if (image == null) {
        // Kullanıcı dosya seçmedi
        return;
      }
      
      // Dosyanın boyutunu kontrol etme
      final fileStat = await File(image.path).stat();
      final fileSize = fileStat.size / (1024 * 1024); // MB cinsinden
      
      if (fileSize > 5) {
        // Dosya çok büyük
        if (!mounted) return;
        FeedbackUtils.showWarningFeedback(
          context, 
          'Dosya boyutu çok büyük. Lütfen 5 MB\'den küçük bir görsel seçin.'
        );
        return;
      }
      
      // Mesaj model'ine görsel yükleme işlemi
      final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      
      if (authViewModel.user == null) {
        if (!mounted) return;
        FeedbackUtils.showErrorFeedback(
          context, 
          'Görsel yüklemek için lütfen giriş yapın'
        );
        return;
      }
      
      setState(() {
        _isLoading = true;
      });
      
      // Görsel işleme ve analiz için yeni bir mesaj oluştur
      final newMessage = await messageViewModel.addMessage(
        'Görsel analizi', 
        imageUrl: null, 
        imagePath: null,
        analyze: false, // İlk aşamada analiz etmiyoruz
      );
      
      if (newMessage != null) {
        // Görseli yükle
        await messageViewModel.uploadMessageImage(newMessage.id, File(image.path));
        
        // Görseli analiz et
        await messageViewModel.analyzeMessage(newMessage.id);
        
        if (!mounted) return;
        FeedbackUtils.showSuccessFeedback(
          context, 
          'Görsel yüklendi ve analiz edildi'
        );
      } else {
        if (!mounted) return;
        FeedbackUtils.showErrorFeedback(
          context, 
          'Görsel yüklenirken bir hata oluştu'
        );
      }
    } catch (e) {
      if (!mounted) return;
      FeedbackUtils.showErrorFeedback(
        context, 
        'Görsel seçilirken bir hata oluştu: $e'
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Metin dosyası seçme işlemi
  Future<void> _pickTextFile(BuildContext context) async {
    try {
      // XFile tipinde metin dosyası seçme
      final XTypeGroup typeGroup = XTypeGroup(
        label: 'Metin Dosyaları',
        extensions: ['txt'],
      );
      
      final XFile? textFile = await openFile(
        acceptedTypeGroups: [typeGroup],
      );
      
      if (textFile == null) {
        // Kullanıcı dosya seçmedi
        return;
      }
      
      // Dosya içeriğini okuma
      final String content = await textFile.readAsString();
      
      if (content.isEmpty) {
        if (!mounted) return;
        FeedbackUtils.showWarningFeedback(
          context, 
          'Seçtiğiniz dosya boş. Lütfen içerik olan bir dosya seçin.'
        );
        return;
      }
      
      // Mesaj model'ine metin dosyası yükleme işlemi
      final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      
      if (authViewModel.user == null) {
        if (!mounted) return;
        FeedbackUtils.showErrorFeedback(
          context, 
          'Metin dosyası yüklemek için lütfen giriş yapın'
        );
        return;
      }
      
      setState(() {
        _isLoading = true;
      });
      
      // Mesaj ekleme
      await messageViewModel.addMessage(
        content, 
        imageUrl: null,
        imagePath: null,
        analyze: true,
      );
      
      if (!mounted) return;
      FeedbackUtils.showSuccessFeedback(
        context, 
        'Metin dosyası içeriği yüklendi ve analiz edilecek'
      );
      
    } catch (e) {
      if (!mounted) return;
      FeedbackUtils.showErrorFeedback(
        context, 
        'Metin dosyası okunurken bir hata oluştu: $e'
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Boş durum widget'ı
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 70,
            color: const Color(0xFF9D3FFF).withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz bir analiz yapılmadı',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'İlişkinizle ilgili danışmak için "Danış" butonunu kullanabilirsiniz',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Analiz sonuçları listesi
  Widget _buildAnalysisList(MessageViewModel viewModel) {
    return ListView.builder(
      itemCount: viewModel.messages.length,
      itemBuilder: (context, index) {
        final message = viewModel.messages[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              // Analiz detayına git
              _showAnalysisDetails(context, viewModel, message);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarih ve durum
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        message.formattedCreatedAt,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: message.analysisResult != null
                              ? const Color(0xFF9D3FFF).withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message.analysisResult != null ? 'Analiz Edildi' : 'Bekliyor',
                          style: TextStyle(
                            color: message.analysisResult != null
                                ? Colors.white
                                : Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Mesaj önizlemesi
                  Text(
                    message.content.length > 100
                        ? '${message.content.substring(0, 100)}...'
                        : message.content,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Analiz kategorileri
                  if (message.analysisResult != null) ...[
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildCategoryChip('Duygu', message.analysisResult!.emotion),
                        const SizedBox(width: 8),
                        _buildCategoryChip('Niyet', message.analysisResult!.intent),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
      },
    );
  }
  
  // Kategori chip'i
  Widget _buildCategoryChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value.length > 15 ? '${value.substring(0, 15)}...' : value,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Analiz detaylarını göster
  void _showAnalysisDetails(BuildContext context, MessageViewModel viewModel, dynamic message) {
    if (message.analysisResult == null) {
      FeedbackUtils.showWarningFeedback(
        context, 
        'Bu mesaj henüz analiz edilmemiş'
      );
      return;
    }
    
    final analysisResult = message.analysisResult;
    final duygu = analysisResult.emotion;
    final niyet = analysisResult.intent;
    final mesajYorumu = analysisResult.aiResponse['mesajYorumu'] ?? 'Yorum bulunamadı';
    final List<String> cevapOnerileri = List<String>.from(analysisResult.aiResponse['cevapOnerileri'] ?? []);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF352269),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık
                Row(
                  children: [
                    const Icon(Icons.analytics, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Analiz Sonucu',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Duygu Çözümlemesi
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
                          Icon(Icons.mood, color: Colors.white70, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Duygu Çözümlemesi',
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
                          duygu,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
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
                            'Niyet Yorumu',
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
                          mesajYorumu,
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
                
                // Cevap Önerileri
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
                            'Cevap Önerileri',
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
                        children: cevapOnerileri.isEmpty
                            ? [
                                Text(
                                  'Cevap önerisi bulunamadı',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              ]
                            : [
                                ...cevapOnerileri.map((oneri) => _buildSuggestionItem(oneri))
                              ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Danışma butonu
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Önce mevcut bottom sheet'i kapat
                      context.push('/consultation'); // Danışma sayfasına git
                    },
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Şimdi Danışmak İstiyorum'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D3FFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
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
                          "Not: Uygulamada sunulan içerikler yol gösterici niteliktedir, bağlayıcı değildir.",
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
            ),
          ),
        ),
      ),
    );
  }
  
  // Öneri öğesi widget'ı
  Widget _buildSuggestionItem(String oneri) {
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
              Icons.reply,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              oneri,
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