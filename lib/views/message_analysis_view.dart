import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../utils/utils.dart';
import '../services/ai_service.dart';
import '../models/message.dart';
import '../app_router.dart';
import '../viewmodels/message_viewmodel.dart';
import '../views/conversation_summary_view.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/advice_viewmodel.dart';
import '../controllers/home_controller.dart';
import '../utils/loading_indicator.dart';
import '../models/message_coach_analysis.dart';
import '../models/analysis_result.dart' as analysis;
import 'package:cloud_firestore/cloud_firestore.dart';

// String için extension - capitalizeFirst metodu
extension StringExtension on String {
  String get capitalizeFirst => length > 0 
      ? '${this[0].toUpperCase()}${substring(1)}'
      : '';
}

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
  bool _isLoading = false;
  bool _forceEmptyState = false; // Veri sıfırlaması sonrası boş durum gösterimi için flag
  bool _showDetailedAnalysisResult = false; // Analiz detaylarını gösterme durumu
  bool _isImageAnalysis = false; // Görsel analizi mi yapılıyor?
  final TextEditingController _textEditingController = TextEditingController(); // Metin analizi için kontrolcü
  
  @override
  void initState() {
    super.initState();
    
    // Analiz sonucunu sıfırla - sayfa tekrar açıldığında görünmemesi için
    _showDetailedAnalysisResult = false;
    
    // Bir kez çağırma garantisi
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Mesajları yükle
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      
      if (authViewModel.user != null) {
        _checkAndLoadMessages(authViewModel.user!.id);
      } else {
        debugPrint('initState - Kullanıcı oturum açmamış, mesaj yükleme atlanıyor');
      }
    });
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  // SharedPreferences kullanarak mesaj yükleme durumunu kontrol et
  Future<void> _checkAndLoadMessages(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final messagesLoaded = prefs.getBool('messages_loaded_$userId') ?? false;
    
    if (!messagesLoaded) {
      debugPrint('İlk kez mesaj yükleniyor - User ID: $userId');
      await _loadMessages();
      
      // Yükleme durumunu kaydet
      await prefs.setBool('messages_loaded_$userId', true);
    } else {
      debugPrint('Mesajlar daha önce yüklenmiş, tekrar yükleme atlanıyor');
      
      // Analiz sonrası ana sayfa verilerini güncelle
      _updateHomeController();
    }
  }

  // Ana sayfa controller'ını güncelle
  void _updateHomeController() {
    try {
      final homeController = Provider.of<HomeController>(context, listen: false);
      final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
      
      // Eğer mesaj analizi varsa, ana sayfayı güncelle
      if (messageViewModel.messages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          homeController.anaSayfayiGuncelle();
          debugPrint('Ana sayfa verileri güncellendi');
        });
      }
    } catch (e) {
      debugPrint('Ana sayfa güncellenirken hata: $e');
    }
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
      Utils.showErrorFeedback(
        context, 
        'Mesajlarınızı yüklemek için lütfen giriş yapın'
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    try {
      debugPrint('Mesaj yükleme başlıyor...');
      await messageViewModel.loadMessages(authViewModel.user!.id);
      
      if (!mounted) return;
      
      debugPrint('Mesaj yükleme tamamlandı. Mesaj sayısı: ${messageViewModel.messages.length}');
      
      if (messageViewModel.errorMessage != null) {
        Utils.showErrorFeedback(
          context, 
          'Mesajlar yüklenirken hata: ${messageViewModel.errorMessage}'
        );
      }
      
      // Reset flag after loading messages
      setState(() {
        _forceEmptyState = false;
      });
      
      // Ana sayfa verilerini güncelle
      _updateHomeController();
      
    } catch (e) {
      if (!mounted) return;
      Utils.showErrorFeedback(
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

  // Tüm verileri sıfırla
  Future<void> _resetAllData() async {
    setState(() {
      _isLoading = true;
    });
    
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    if (authViewModel.user == null) {
      if (!mounted) return;
      Utils.showErrorFeedback(
        context, 
        'Verilerinizi sıfırlamak için lütfen giriş yapın'
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    try {
      // Tüm verileri sıfırla
      await messageViewModel.clearAllData(authViewModel.user!.id);
      
      // Yükleme durumunu sıfırla
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('messages_loaded_${authViewModel.user!.id}', false);
      
      // ViewState'i zorla boş durum göstermeye ayarla
      setState(() {
        _forceEmptyState = true;
        _isLoading = false;
      });
      
      if (!mounted) return;
      
      // Başarı mesajı göster
      Utils.showSuccessFeedback(
        context, 
        'Tüm analiz verileriniz başarıyla silindi'
      );
      
      // UI'daki değişikliklerin hemen yansıması için explicit notifyListeners() çağrısı
      messageViewModel.resetCurrentAnalysis();
      
      // Ana sayfa verilerini sıfırla
      final homeController = Provider.of<HomeController>(context, listen: false);
      homeController.resetAnalizVerileri();
      
    } catch (e) {
      if (!mounted) return;
      Utils.showErrorFeedback(
        context, 
        'Veriler sıfırlanırken hata: $e'
      );
      setState(() {
        _isLoading = false;
      });
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
                            'Danışma',
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
                        'İlişki analizi ve danışma işlevlerini ayrı ekranlarda bulabilirsiniz. Özel bir konuda danışmak için "Danış" butonunu kullanabilirsiniz.',
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
                  Consumer<AuthViewModel>(
                    builder: (context, authViewModel, _) {
                      return Text(
                        'Merhaba, ${authViewModel.user?.displayName ?? ""}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  // Butonları Wrap içine alarak taşmayı önlüyoruz
                  Wrap(
                    spacing: 4, // butonlar arası boşluk
                    children: [
                      // Reset veriler butonu - kaldırıldı
                      IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.white),
                        onPressed: () {
                          _showInfoDialog(context);
                        },
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
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
                    _buildUploadCards(),
                    
                    const SizedBox(height: 20),
                    
                    // Analiz sonuçları bölümü
                    Expanded(
                      child: _isLoading
                        ? Center(child: YuklemeAnimasyonu(
                            renk: Color(0xFF9D3FFF), 
                            analizTipi: _isImageAnalysis ? AnalizTipi.FOTOGRAF : AnalizTipi.TXT_DOSYASI
                          ))
                        : _forceEmptyState || messageViewModel.messages.isEmpty
                          ? _buildEmptyState()
                          : _buildCurrentAnalysisResult(messageViewModel),
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
  
  Widget _buildUploadCards() {
    final viewModel = Provider.of<MessageViewModel>(context, listen: false);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          const Text(
            'Mesaj Analizi İçin Kaynak Seçin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildUploadCard(
                  title: 'Görsel Yükle',
                  subtitle: 'Ekran görüntüsü yükle',
                  icon: Icons.image_outlined,
                  onTap: _gorselAnalizi,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildUploadCard(
                  title: 'Metin Yükle',
                  subtitle: '.txt dosyası yükle',
                  icon: Icons.description_outlined,
                  onTap: _dosyadanAnaliz,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Yükle kartı widget'ı
  Widget _buildUploadCard({
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required VoidCallback onTap
  }) {
    return SizedBox(
      height: 150, // Sabit yükseklik belirle
      child: Card(
        color: const Color(0xFF352269),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF9D3FFF), width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white.withOpacity(0.9),
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Görsel analizi
  Future<void> _gorselAnalizi() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;

    // Premium kontrolü
    if (!isPremium) {
      // Premium olmayan kullanıcılar için bilgilendirme
      Utils.showToast(
        context, 
        'Bu özelliği sınırsız kullanmak için Premium üyelik gerekiyor'
      );
    }

    await _pickImage();
  }
  
  // Görsel analizi için dosya seçme işlemi
  Future<void> _pickImage() async {
    bool isProcessing = false;
    
    try {
      final XTypeGroup typeGroup = XTypeGroup(
        label: 'Görseller',
        extensions: <String>['jpg', 'jpeg', 'png'],
      );
      
      setState(() {
        _isLoading = true;
        _isImageAnalysis = true;
      });
      
      // Dosya seçiciyi aç
      final XFile? pickedFile = await openFile(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      );
      
      if (pickedFile == null) {
        setState(() {
          _isLoading = false;
          _isImageAnalysis = false;
        });
        return;
      }
      
      // Analize başladığını bildir
      setState(() {
        isProcessing = true;
      });
      
      final viewModel = Provider.of<MessageViewModel>(context, listen: false);
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      
      if (authViewModel.user == null) {
        Utils.showErrorFeedback(
          context, 
          'Görsel analizi için lütfen giriş yapın'
        );
        setState(() {
          isProcessing = false;
          _isLoading = false;
          _isImageAnalysis = false;
        });
        return;
      }
      
      // Önceki analiz işlemlerini sıfırla
      viewModel.resetCurrentAnalysis();
      
      // XFile'ı File'a dönüştür
      final File imageFile = File(pickedFile.path);
      
      // Görsel OCR ve analiz işlemi başlatılıyor
      final bool result = await viewModel.analyzeImageMessage(imageFile);
      
      // Analiz tamamlandı - tüm State'leri temizle
      if (mounted) {
        setState(() {
          isProcessing = false;
          _isLoading = false;
          _showDetailedAnalysisResult = result; // Analiz başarılıysa detayları göster
        });
      }
      
      if (result) {
        Utils.showSuccessFeedback(
          context, 
          'Görsel başarıyla analiz edildi'
        );
        
        // Belirli bir süre sonra mesaj listesini yenile
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          // Ana sayfa verilerini güncelle
          final homeController = Provider.of<HomeController>(context, listen: false);
          homeController.anaSayfayiGuncelle();
        }
      } else {
        Utils.showErrorFeedback(
          context, 
          'Görsel analiz edilirken bir hata oluştu'
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isProcessing = false;
          _isLoading = false;
          _isImageAnalysis = false;
        });
        
        debugPrint('_pickImage genel hata: $e');
        Utils.showErrorFeedback(
          context, 
          'Görsel seçme işlemi sırasında hata: $e'
        );
      }
    }
  }
  
  // Dosyadan analiz
  Future<void> _dosyadanAnaliz() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;

    // Premium kontrolü
    if (!isPremium) {
      // Premium olmayan kullanıcılar için bilgilendirme
      Utils.showToast(
        context, 
        'Bu özelliği sınırsız kullanmak için Premium üyelik gerekiyor'
      );
    }

    await _pickTextFile();
  }
  
  // Metin dosyası seçme işlemi
  Future<void> _pickTextFile() async {
    try {
      final XTypeGroup typeGroup = XTypeGroup(
        label: 'Metin Dosyaları',
        extensions: <String>['txt'],
      );
      
      setState(() {
        _isLoading = true;
        _isImageAnalysis = false;
      });
      
      // Dosya seçiciyi aç
      final XFile? pickedFile = await openFile(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      );
      
      if (pickedFile == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final viewModel = Provider.of<MessageViewModel>(context, listen: false);
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      
      if (authViewModel.user == null) {
        Utils.showErrorFeedback(
          context, 
          'Dosya analizi için lütfen giriş yapın'
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Önceki analiz işlemlerini sıfırla
      viewModel.resetCurrentAnalysis();
      
      // Dosyanın içeriğini oku
      final File file = File(pickedFile.path);
      String fileContent = await file.readAsString();
      
      if (fileContent.isEmpty) {
        Utils.showErrorFeedback(
          context, 
          'Metin dosyası boş'
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Dosya ismini ve yolu ekleyerek içeriği zenginleştir
      fileContent = "---- .txt dosyası içeriği ----\nDosya: ${pickedFile.name}\n\n$fileContent\n---- Dosya içeriği sonu ----";
      
      // Dosya içeriğini analiz et
      final bool result = await viewModel.analyzeMessage(fileContent);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showDetailedAnalysisResult = result;
        });
      }
      
      if (result) {
        Utils.showSuccessFeedback(
          context, 
          'Dosya başarıyla analiz edildi'
        );
        
        // Belirli bir süre sonra mesaj listesini yenile
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          // Ana sayfa verilerini güncelle
          final homeController = Provider.of<HomeController>(context, listen: false);
          homeController.anaSayfayiGuncelle();
        }
      } else {
        Utils.showErrorFeedback(
          context, 
          'Dosya analiz edilirken bir hata oluştu'
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        debugPrint('_pickTextFile genel hata: $e');
        Utils.showErrorFeedback(
          context, 
          'Dosya seçme işlemi sırasında hata: $e'
        );
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
  
  // Sadece en son analiz sonucunu göster
  Widget _buildCurrentAnalysisResult(MessageViewModel viewModel) {
    // Son mesajı al (varsa)
    if (viewModel.messages.isEmpty || _forceEmptyState || !_showDetailedAnalysisResult) {
      return _buildEmptyState();
    }
    
    // En son analiz edilen mesajı bul
    final lastAnalyzedMessage = viewModel.messages
        .where((message) => message.isAnalyzed)
        .toList()
        ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
        
    if (lastAnalyzedMessage.isEmpty) {
      return _buildEmptyState();
    }
    
    // Son analiz sonucunu göster
    final latestMessage = lastAnalyzedMessage.first;
    
    // Analiz sonucu yoksa boş durum göster
    if (latestMessage.analysisResult == null) {
      return _buildEmptyState();
    }
    
    // Analiz sonucu verileri
    final analysisResult = latestMessage.analysisResult!;
    final duygu = analysisResult.emotion;
    final niyet = analysisResult.intent;
    final mesajYorumu = analysisResult.aiResponse['mesajYorumu'] ?? 'Yorum bulunamadı';
    
    // tavsiyeler güvenli bir şekilde al
    List<String> tavsiyeler = [];
    final dynamic rawTavsiyeler = analysisResult.aiResponse['tavsiyeler'];
    if (rawTavsiyeler is List) {
      tavsiyeler = List<String>.from(rawTavsiyeler.map((item) => item.toString()));
    } else if (rawTavsiyeler is String) {
      // String formatındaki tavsiyeleri işle
      try {
        // Virgülle ayrılmış bir liste olabilir
        final List<String> parcalanmisTavsiyeler = rawTavsiyeler.split(',');
        for (String tavsiye in parcalanmisTavsiyeler) {
          if (tavsiye.trim().isNotEmpty) {
            tavsiyeler.add(tavsiye.trim());
          }
        }
      } catch (e) {
        // String'i doğrudan bir tavsiye olarak ekle
        if (rawTavsiyeler.toString().trim().isNotEmpty) {
          tavsiyeler.add(rawTavsiyeler.toString());
        }
      }
    }
    
    // Geriye dönük uyumluluk - tavsiyeler boşsa eski cevapOnerileri alanını kontrol et
    if (tavsiyeler.isEmpty) {
      final dynamic rawOnerileri = analysisResult.aiResponse['cevapOnerileri'];
      if (rawOnerileri is List) {
        tavsiyeler = List<String>.from(rawOnerileri.map((item) => item.toString()));
      } else if (rawOnerileri is String) {
        // String formatındaki tavsiyeleri işle
        try {
          // Virgülle ayrılmış bir liste olabilir
          final List<String> parcalanmisTavsiyeler = rawOnerileri.split(',');
          for (String tavsiye in parcalanmisTavsiyeler) {
            if (tavsiye.trim().isNotEmpty) {
              tavsiyeler.add(tavsiye.trim());
            }
          }
        } catch (e) {
          // String'i doğrudan bir tavsiye olarak ekle
          if (rawOnerileri.toString().trim().isNotEmpty) {
            tavsiyeler.add(rawOnerileri.toString());
          }
        }
      }
    }
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
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
            
            // Analiz edilen mesaj içeriği
            // --> KALDIRILACAK KOD BAŞLANGICI
            // if (latestMessage.analysisSource != AnalysisSource.image)
            //   Card(
            //     margin: const EdgeInsets.only(bottom: 16),
            //     color: Colors.white.withOpacity(0.05),
            //     shape: RoundedRectangleBorder(
            //       borderRadius: BorderRadius.circular(12),
            //     ),
            //     child: Padding(
            //       padding: const EdgeInsets.all(16),
            //       child: Column(
            //         crossAxisAlignment: CrossAxisAlignment.start,
            //         children: [
            //           Row(
            //             children: [
            //               Icon(
            //                 Icons.chat_bubble_outline,
            //                 color: Colors.white.withOpacity(0.7),
            //                 size: 18,
            //               ),
            //               const SizedBox(width: 8),
            //               Text(
            //                 'Mesaj İçeriği',
            //                 style: TextStyle(
            //                   color: Colors.white.withOpacity(0.7),
            //                   fontWeight: FontWeight.bold,
            //                   fontSize: 14,
            //                 ),
            //               ),
            //             ],
            //           ),
            //           const SizedBox(height: 8),
            //           Text(
            //             latestMessage.content.length > 150
            //                 ? '${latestMessage.content.substring(0, 150)}...'
            //                 : latestMessage.content,
            //             style: TextStyle(
            //               color: Colors.white.withOpacity(0.9),
            //               fontSize: 14,
            //             ),
            //           ),
            //         ],
            //       ),
            //     ),
            //   ),
            // <-- KALDIRILACAK KOD SONU
            
            // .txt dosyası analizi için Konuşma Özeti butonu
            // Sadece metin analizi ise butonu göster
            if (latestMessage.analysisSource == AnalysisSource.text) 
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // UI'da yükleme durumunu göster
                      setState(() {
                        _isLoading = true;
                      });
                      
                      try {
                        // Mevcut analiz sonucunu kontrol et
                        if (latestMessage.analysisResult == null) {
                          throw Exception('Analiz sonucu bulunamadı');
                        }
                        
                        // AI servisini al
                        final aiService = AiService();
                        
                        // Mesaj içeriğini kullanarak Spotify Wrapped tarzı sohbet analizi yap
                        final summaryData = await aiService.analizSohbetVerisi(
                          latestMessage.content
                        );
                        
                        if (summaryData.isEmpty) {
                          throw Exception('Konuşma özeti alınamadı');
                        }
                        
                        // Yükleme durumunu kapat
                        setState(() {
                          _isLoading = false;
                        });
                        
                        // Konuşma özeti sayfasına git
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => KonusmaSummaryView(
                                summaryData: summaryData,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        // Hata durumunda yükleme göstergesini kapat
                        setState(() {
                          _isLoading = false;
                        });
                        
                        // Hata mesajı göster
                        if (mounted) {
                          Utils.showErrorFeedback(
                            context, 
                            'Spotify Wrapped analizi alınırken hata oluştu: $e'
                          );
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.auto_awesome,
                      size: 22,
                    ),
                    label: const Text(
                      "✨ Spotify Wrapped Analizi",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954), // Spotify yeşili
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
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
                            ...tavsiyeler.map((oneri) => _buildSuggestionItem(oneri))
                          ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Butonlar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Danışmak İstiyorum butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.push('/consultation');
                      },
                      icon: const Icon(Icons.chat_outlined, size: 16),
                      label: const Text('Danışmak İstiyorum'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9D3FFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Geçmiş Analizler butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.push(AppRouter.pastAnalyses);
                      },
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('Geçmiş Analizler'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.white30),
                        ),
                      ),
                    ),
                  ),
                ],
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
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
    );
  }
  
  // Mesaj detayı widget'ı (yeni analiz yapılmadığında kullanılacak)
  Widget _buildMessageCard(Message message, MessageViewModel viewModel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
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

  // Veri sıfırlama diyaloğunu göster
  void _showResetDialog(BuildContext context) {
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    if (authViewModel.user == null) {
      Utils.showErrorFeedback(
        context, 
        'Verilerinizi sıfırlamak için lütfen giriş yapın'
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF352269),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verileri Sıfırla',
                style: TextStyle(
                  color: Colors.white,
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
                _buildResetOption(
                  context,
                  title: 'Sadece Mesaj Analizlerini Sıfırla',
                  description: 'Sadece görsel ve metin analizi sonuçlarını siler. Mesajların kendisi ve diğer veriler korunur.',
                  icon: Icons.analytics_outlined,
                  iconColor: Colors.blue,
                  onTap: () async {
                    Navigator.pop(context);
                    await _resetMessageAnalysisData();
                  },
                ),
                const SizedBox(height: 16),
                _buildResetOption(
                  context,
                  title: 'Sadece İlişki Değerlendirmelerini Sıfırla',
                  description: 'Sadece ilişki değerlendirmelerini siler. Mesajlar, analizler ve diğer veriler korunur.',
                  icon: Icons.people_outline,
                  iconColor: Colors.green,
                  onTap: () async {
                    Navigator.pop(context);
                    await _resetRelationshipData();
                  },
                ),
                const SizedBox(height: 16),
                _buildResetOption(
                  context,
                  title: 'Sadece Danışma Verilerini Sıfırla',
                  description: 'Sadece danışma geçmişini siler. Mesajlar, analizler ve diğer veriler korunur.',
                  icon: Icons.question_answer_outlined,
                  iconColor: Colors.amber,
                  onTap: () async {
                    Navigator.pop(context);
                    await _resetConsultationData();
                  },
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withOpacity(0.2), thickness: 1),
                const SizedBox(height: 16),
                _buildResetOption(
                  context,
                  title: 'TÜM VERİLERİ SIFIRLA',
                  description: 'Tüm analizler, mesajlar, değerlendirmeler ve danışmalar silinir. Sadece kullanıcı bilgileriniz korunur.',
                  icon: Icons.delete_forever_outlined,
                  iconColor: Colors.red,
                  onTap: () async {
                    Navigator.pop(context);
                    await _resetAllData();
                  },
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
              child: const Text('Vazgeç'),
            ),
          ],
        );
      },
    );
  }

  // Sıfırlama seçeneği widget'ı
  Widget _buildResetOption(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Sadece mesaj analizlerini sıfırla
  Future<void> _resetMessageAnalysisData() async {
    setState(() {
      _isLoading = true;
    });
    
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    try {
      // Mesaj analizlerini sıfırla
      await messageViewModel.clearMessageAnalysisData(authViewModel.user!.id);
      
      // Yükleme durumunu sıfırla
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('messages_loaded_${authViewModel.user!.id}', false);
      
      // ViewState'i sıfırla
      setState(() {
        _forceEmptyState = true;
        _isLoading = false;
      });
      
      if (!mounted) return;
      
      // Başarı mesajı göster
      Utils.showSuccessFeedback(
        context, 
        'Mesaj analizi verileriniz başarıyla silindi'
      );
      
      // UI güncellemesi için
      messageViewModel.resetCurrentAnalysis();
      
      // Verileri yenile
      await _loadMessages();
      
      // Ana sayfa verilerini güncelle
      final homeController = Provider.of<HomeController>(context, listen: false);
      homeController.anaSayfayiGuncelle();
      
    } catch (e) {
      if (!mounted) return;
      Utils.showErrorFeedback(
        context, 
        'Veriler sıfırlanırken hata: $e'
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Sadece ilişki değerlendirmelerini sıfırla
  Future<void> _resetRelationshipData() async {
    setState(() {
      _isLoading = true;
    });
    
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    try {
      // İlişki değerlendirmelerini sıfırla
      await messageViewModel.clearRelationshipEvaluationData(authViewModel.user!.id);
      
      setState(() {
        _isLoading = false;
      });
      
      if (!mounted) return;
      
      // Başarı mesajı göster
      Utils.showSuccessFeedback(
        context, 
        'İlişki değerlendirme verileriniz başarıyla silindi'
      );
      
      // Ana sayfa verilerini güncelle
      final homeController = Provider.of<HomeController>(context, listen: false);
      homeController.anaSayfayiGuncelle();
      
    } catch (e) {
      if (!mounted) return;
      Utils.showErrorFeedback(
        context, 
        'Veriler sıfırlanırken hata: $e'
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Sadece danışma verilerini sıfırla
  Future<void> _resetConsultationData() async {
    setState(() {
      _isLoading = true;
    });
    
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    try {
      // Danışma verilerini sıfırla
      await messageViewModel.clearConsultationData(authViewModel.user!.id);
      
      setState(() {
        _isLoading = false;
      });
      
      if (!mounted) return;
      
      // Başarı mesajı göster
      Utils.showSuccessFeedback(
        context, 
        'Danışma verileriniz başarıyla silindi'
      );
      
      // Ana sayfa verilerini güncelle
      final homeController = Provider.of<HomeController>(context, listen: false);
      homeController.anaSayfayiGuncelle();
      
    } catch (e) {
      if (!mounted) return;
      Utils.showErrorFeedback(
        context, 
        'Veriler sıfırlanırken hata: $e'
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Mesaj Koçu analiz sonuçlarını görüntüle
  Widget _buildMesajKocuAnalizi(MessageCoachAnalysis analiz) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Mesaj Etki Yüzdeleri
          Text(
            '📊 Mesaj Etki Analizi',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _buildEtkiYuzdeleri(analiz.etki),
          const Divider(height: 24),
          
          // 2. Anlık Tavsiye
          Text(
            '💬 Anlık Tavsiye',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            analiz.anlikTavsiye ?? 'Tavsiye bulunamadı',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Divider(height: 24),
          
          // 3. Yeniden Yazım Önerisi
          Text(
            '✍️ Yeniden Yazım Önerisi',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            analiz.yenidenYazim ?? 'Öneri bulunamadı',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Divider(height: 24),
          
          // 4. Karşı Taraf Yorumu
          Text(
            '🔍 Karşı Taraf Yorumu',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            analiz.karsiTarafYorumu ?? 'Yorum bulunamadı',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Divider(height: 24),
          
          // 5. Strateji Önerisi
          Text(
            '🧭 Strateji Önerisi',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            analiz.strateji ?? 'Öneri bulunamadı',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
  
  Widget _buildEtkiYuzdeleri(Map<String, int> etki) {
    if (etki.isEmpty) {
      return const Text('Etki analizi bulunamadı');
    }
    
    // Etki değerlerini azalan sırada sırala
    final List<MapEntry<String, int>> siralanmisEtki = etki.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Column(
      children: siralanmisEtki.map((entry) {
        final String etiket = entry.key;
        final int deger = entry.value;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${etiket.capitalizeFirst}: %$deger',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '$deger%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: deger / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getEtkiRengi(etiket),
                ),
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  Color _getEtkiRengi(String etiket) {
    // Farklı etiketler için farklı renkler
    switch (etiket.toLowerCase()) {
      case 'sempatik':
        return Colors.green;
      case 'kararsız':
        return Colors.orange;
      case 'endişeli':
        return Colors.red;
      case 'olumlu':
        return Colors.blue;
      case 'flörtöz':
        return Colors.purple;
      case 'mesafeli':
        return Colors.grey;
      case 'nötr':
        return Colors.blueGrey;
      default:
        return Colors.teal;
    }
  }

  // Metin analizi
  Future<void> _analizeGonder() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;

    if (_textEditingController.text.trim().isEmpty) {
      Utils.showErrorFeedback(context, 'Lütfen analiz için bir mesaj girin');
      return;
    }

    // Premium kontrolü
    if (!isPremium) {
      // Premium olmayan kullanıcılar için bilgilendirme
      Utils.showToast(
        context, 
        'Bu özelliği sınırsız kullanmak için Premium üyelik gerekiyor'
      );
    }

    setState(() {
      _isLoading = true;
      _isImageAnalysis = false;
    });

    final String messageText = _textEditingController.text.trim();
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    
    try {
      final bool result = await messageViewModel.analyzeMessage(messageText);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _showDetailedAnalysisResult = result;
      });
      
      if (result) {
        Utils.showSuccessFeedback(
          context, 
          'Mesaj başarıyla analiz edildi'
        );
        
        // Belirli bir süre sonra mesaj listesini yenile
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          // Ana sayfa verilerini güncelle
          final homeController = Provider.of<HomeController>(context, listen: false);
          homeController.anaSayfayiGuncelle();
        }
      } else {
        Utils.showErrorFeedback(
          context, 
          'Mesaj analiz edilirken bir hata oluştu'
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      Utils.showErrorFeedback(
        context, 
        'Analiz işlemi sırasında hata: $e'
      );
    }
  }

  // Wrapped analiz özeti
  void _analizOzetiGoster(BuildContext context, String analiz) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;

    // Premium kontrolü
    if (!isPremium) {
      // Premium olmayan kullanıcılar için bilgilendirme
      Utils.showToast(
        context, 
        'Bu özelliğe sınırsız erişmek için Premium üyelik gerekiyor'
      );
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF352269),
          title: Row(
            children: [
              Icon(Icons.psychology, color: Colors.white.withOpacity(0.9)),
              const SizedBox(width: 8),
              Text(
                'Analiz Özeti',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              analiz,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat', style: TextStyle(color: Color(0xFF9D3FFF))),
            ),
          ],
        );
      },
    );
  }

  // Danışma/Koçluk bölümü
  void _showCoachingDialog(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;

    // Sadece Premium kullanıcılar erişebilir
    if (!isPremium) {
      Utils.showToast(
        context, 
        'Danışma/Koçluk özelliği sadece Premium üyelere özeldir'
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF352269),
          title: Row(
            children: [
              Icon(Icons.psychology, color: Colors.white.withOpacity(0.9)),
              const SizedBox(width: 8),
              Text(
                'Danışma / Koçluk',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bu özellik yakında aktif olacak. Psikolojik danışmanlık hizmetleri için hazırlıklarımız devam ediyor.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat', style: TextStyle(color: Color(0xFF9D3FFF))),
            ),
          ],
        );
      },
    );
  }
} 