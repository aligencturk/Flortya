import 'dart:io';
import 'dart:async';
import 'dart:convert'; // JSON işlemleri için ekle
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/utils.dart';
import '../services/ai_service.dart';
import '../models/message.dart';
import '../app_router.dart';
import '../viewmodels/message_viewmodel.dart';
import '../views/conversation_summary_view.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../controllers/home_controller.dart';
import '../utils/loading_indicator.dart';
import '../services/premium_service.dart';
import '../services/ad_service.dart';

import '../services/event_bus_service.dart';


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
                            'Danış',
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
    
    return PopScope(
      canPop: !_isLoading,
      onPopInvoked: (bool didPop) async {
        // Eğer yükleme durumundaysa ve henüz çıkış yapılmamışsa onay iste
        if (_isLoading && !didPop) {
          final bool shouldPop = await _showExitConfirmationDialog(context);
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF4A2A80),
        resizeToAvoidBottomInset: false, // Klavye overflow'unu engeller
        body: SafeArea(
          child: Column(
            children: [
              // App Bar - Sabit
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () async {
                        if (_isLoading) {
                          final bool shouldPop = await _showExitConfirmationDialog(context);
                          if (shouldPop && mounted) {
                            Navigator.of(context).pop();
                          }
                        } else {
                          context.pop();
                        }
                      },
                    ),
                    Expanded(
                      child: Consumer<AuthViewModel>(
                        builder: (context, authViewModel, _) {
                          return Text(
                            'Merhaba, ${authViewModel.user?.displayName ?? ""}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    // Butonları Wrap içine alarak taşmayı önlüyoruz
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
              ),
              
              // Ana içerik
              Expanded(
                child: Container(
                  width: double.infinity,
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
                          FutureBuilder(
                            future: _checkFeatureAccess(),
                            builder: (context, AsyncSnapshot<Map<PremiumFeature, bool>> snapshot) {
                              final featureAccess = snapshot.data ?? {
                                PremiumFeature.CONSULTATION: false,
                              };
                              final bool canUseConsultation = featureAccess[PremiumFeature.CONSULTATION] ?? false;
                              
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      // Premium kontrolü - eğer premium değilse bilgilendirme göster
                                      if (canUseConsultation) {
                                        // Danışma sayfasına yönlendir
                                        context.push('/consultation');
                                      } else {
                                        // Premium bilgilendirme diyaloğu göster
                                        showPremiumInfoDialog(context, PremiumFeature.CONSULTATION);
                                      }
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
                                  
                                  // Premium değilse kilit simgesi göster
                                  if (!canUseConsultation)
                                    Positioned(
                                      top: -5,
                                      right: -5,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.lock,
                                          color: Color(0xFF9D3FFF),
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
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
                      
                      // Upload section - Yükleme bölümü
                      _buildUploadSection(),
                      
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
      ), // Scaffold kapanışı
    ); // PopScope kapanışı
  }
  
  // Çıkış onay diyaloğu
  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Dışarıya dokunarak kapatılamaz
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF352269),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Çıkmak istediğinize emin misiniz?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Şu anda analiz devam ediyor. Çıkarsanız analiz iptal olacak ve işlem yarıda kalacak.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Çıkma
              },
              child: Text(
                'Devam Et',
                style: TextStyle(
                  color: const Color(0xFF9D3FFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
                          ElevatedButton(
              onPressed: () async {
                // Tüm analizleri iptal et
                try {
                  // AiService'den analizi iptal et
                  final aiService = AiService();
                  aiService.cancelAnalysis();
                  debugPrint('AiService analizi iptal edildi');
                  
                  // MessageViewModel'deki analizi iptal et
                  final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
                  messageViewModel.cancelAnalysis();
                  debugPrint('MessageViewModel analizi iptal edildi');
                  
                  // Loading durumunu sıfırla
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                  
                  debugPrint('Tüm analizler iptal edildi');
                } catch (e) {
                  debugPrint('Analiz iptal edilirken hata: $e');
                }
                Navigator.of(context).pop(true); // Çık
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Çık',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false; // Null durumunda false döndür
  }
  
  // Upload section - Yükleme bölümü
  Widget _buildUploadSection() {
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
          FutureBuilder(
            future: _checkFeatureAccess(),
            builder: (context, AsyncSnapshot<Map<PremiumFeature, bool>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final featureAccess = snapshot.data ?? {
                PremiumFeature.VISUAL_OCR: true,
                PremiumFeature.TXT_ANALYSIS: true,
                PremiumFeature.CONSULTATION: false,
              };
              
              return Row(
                children: [
                  Expanded(
                    child: _buildUploadCard(
                      title: 'Görsel Yükle',
                      subtitle: 'Ekran görüntüsü yükle',
                      icon: Icons.image_outlined,
                      onTap: featureAccess[PremiumFeature.VISUAL_OCR]! 
                         ? _gorselAnalizi 
                         : () => showPremiumInfoDialog(context, PremiumFeature.VISUAL_OCR),
                      isLocked: !featureAccess[PremiumFeature.VISUAL_OCR]!,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildUploadCard(
                      title: 'Metin Yükle',
                      subtitle: '.txt dosyası yükle',
                      icon: Icons.description_outlined,
                      onTap: featureAccess[PremiumFeature.TXT_ANALYSIS]!
                         ? _dosyadanAnaliz
                         : () => showPremiumInfoDialog(context, PremiumFeature.TXT_ANALYSIS),
                      isLocked: !featureAccess[PremiumFeature.TXT_ANALYSIS]!,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  
  // Yükle kartı widget'ı - orijinal tasarım
  Widget _buildUploadCard({
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required VoidCallback onTap,
    bool isLocked = false,
    bool fullWidth = false,
  }) {
    return SizedBox(
      height: 150, // Sabit yükseklik belirle
      width: fullWidth ? double.infinity : null,
      child: Card(
        color: const Color(0xFF352269),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF9D3FFF), width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Padding(
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
              if (isLocked)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lock,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Premium özelliklere erişim durumunu kontrol et
  Future<Map<PremiumFeature, bool>> _checkFeatureAccess() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final bool isPremium = authViewModel.isPremium;
    final premiumService = PremiumService();
    
    // Premium ise tüm özelliklere erişim var
    if (isPremium) {
      return {
        PremiumFeature.VISUAL_OCR: true,
        PremiumFeature.TXT_ANALYSIS: true,
        PremiumFeature.WRAPPED_ANALYSIS: true,
        PremiumFeature.CONSULTATION: true,
      };
    }
    
    // Premium değilse, erişim durumlarını kontrol et
    final canUseVisualOcr = await premiumService.canUseFeature(
      PremiumFeature.VISUAL_OCR, 
      isPremium
    );
    
    final canUseTxtAnalysis = await premiumService.canUseFeature(
      PremiumFeature.TXT_ANALYSIS, 
      isPremium
    );
    
    final canUseWrappedAnalysis = await premiumService.canUseFeature(
      PremiumFeature.WRAPPED_ANALYSIS, 
      isPremium
    );
    
    return {
      PremiumFeature.VISUAL_OCR: canUseVisualOcr,
      PremiumFeature.TXT_ANALYSIS: canUseTxtAnalysis,
      PremiumFeature.WRAPPED_ANALYSIS: canUseWrappedAnalysis,
      PremiumFeature.CONSULTATION: false, // Danışma her zaman premium
    };
  }

  // Görsel analizi - reklam kontrolü ile
  Future<void> _gorselAnalizi() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    final premiumService = PremiumService();
    
    // Premium değilse, kullanım sayısını kontrol et ve artır
    if (!isPremium) {
      final int count = await premiumService.getDailyVisualOcrCount();
      debugPrint('Görsel OCR günlük kullanım: $count / 5');
      
      // İlk kullanım kontrolü
      bool isFirstTime = await premiumService.isFirstTimeVisualOcr();
      
      if (isFirstTime) {
        // İlk kullanım - bilgilendirme mesajı (reklamsız)
        await premiumService.markFirstTimeVisualOcrUsed();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İlk görsel analiziniz reklamsız. Sonraki kullanımlar reklam izlemenizi gerektirecek.'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // İlk kullanım değilse, reklam göster
        await _showAdSimulation();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bugün ${count + 1}. görsel analizinizi yaptınız. Günlük 5 hakkınız var.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Kullanım sayısını artır
      await premiumService.incrementDailyVisualOcrCount();
    }
    
    // Görsel seçme işlemini başlat
    await _gorselSec();
  }
  
  // Reklam simülasyonu gösterme fonksiyonu
  Future<void> _showAdSimulation() async {
    if (!mounted) return;
     
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF352269),
          title: Row(
            children: [
              Icon(Icons.live_tv, color: Colors.white),
              SizedBox(width: 10),
              Text('Reklam', style: TextStyle(color: Colors.white)),
            ],
          ),
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // Premium sayfasına yönlendir
                      Navigator.pop(context); // Dialog'u kapat
                      context.push(AppRouter.premium);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D3FFF),
                    ),
                    child: const Text(
                      "Premium'a Geç",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Reklamları görmek istemiyorsanız Premium'a geçebilirsiniz.",
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
    
    // AdService kullanarak reklam göster
    AdService.loadRewardedAd(() {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }
  
  // TXT dosyası analizi - reklam kontrolü ile
  Future<void> _dosyadanAnaliz() async {
    try {
      // Kullanıcı giriş kontrolü
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (authViewModel.user == null) {
        Utils.showErrorFeedback(context, 'Dosya analizi için lütfen giriş yapın');
        return;
      }
      
      // Premium durumu kontrolü
      final bool isPremium = authViewModel.isPremium;
      final premiumService = PremiumService();
      
      // Premium değilse limit kontrolü
      if (!isPremium) {
        final int count = await premiumService.getTxtAnalysisUsedCount();
        debugPrint('TXT analizi toplam kullanım: $count / 3');
        
        // Limit dolmuşsa uyarı göster ve çık
        if (count >= 3) {
          showPremiumInfoDialog(context, PremiumFeature.TXT_ANALYSIS);
          return;
        }
      }
      
      // Dosya seçim işlemini başlat
      bool? success = await _pickTextFile();
      
      // Dosya başarıyla seçilip analiz edildiyse sayaç artırılır
      if (success == true && !isPremium) {
        try {
          await premiumService.incrementTxtAnalysisUsedCount();
          final int newCount = await premiumService.getTxtAnalysisUsedCount();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$newCount. TXT dosyası analizinizi yaptınız. Toplamda 3 hakkınız var.'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          debugPrint('Kullanım sayacı güncellenirken hata: $e');
        }
      }
    } catch (e) {
      debugPrint('_dosyadanAnaliz hata: $e');
      if (mounted) {
        Utils.showErrorFeedback(context, 'Dosya analizi başlatılırken hata oluştu: $e');
      }
    }
  }
  
  // WhatsApp mesajlarından katılımcıları çıkaran fonksiyon - SADECE SOL TARAFTAKİ İSİMLER
  List<String> _extractParticipantsFromText(String content) {
    Set<String> participants = {};
    Map<String, int> participantFrequency = {}; // Mesaj sayısını takip et
    
    final lines = content.split('\n');
    debugPrint('=== KATILIMCI ÇIKARMA BAŞLIYOR ===');
    debugPrint('Toplam ${lines.length} satır analiz ediliyor...');
    
    int validMessageLines = 0;
    int invalidLines = 0;
    int rejectedDueToFormat = 0;
    int rejectedDueToValidation = 0;
    
    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // WhatsApp mesaj formatlarını kontrol et
      String? participantName = _extractParticipantFromLine(line);
      
      if (participantName == null) {
        rejectedDueToFormat++;
        continue;
      }
      
      if (participantName.isNotEmpty) {
        if (_isValidParticipantName(participantName)) {
          participants.add(participantName);
          participantFrequency[participantName] = (participantFrequency[participantName] ?? 0) + 1;
          validMessageLines++;
          // Debug log kaldırıldı - çok fazla spam yapıyor
        } else {
          rejectedDueToValidation++;
                      // Debug log kaldırıldı - çok fazla spam yapıyor
        }
      }
    }
    
    debugPrint('=== KATILIMCI ÇIKARMA SONUÇLARI ===');
    debugPrint('- Geçerli mesaj satırı: $validMessageLines');
    debugPrint('- Format hatası sebebiyle reddedilen: $rejectedDueToFormat');
    debugPrint('- Validasyon hatası sebebiyle reddedilen: $rejectedDueToValidation');
    debugPrint('- Bulunan benzersiz katılımcı: ${participants.length}');
    
    // Katılımcı sıklıklarını logla
    var sortedParticipants = participantFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    debugPrint('🏆 En aktif katılımcılar:');
    for (var entry in sortedParticipants.take(10)) {
      debugPrint('  - ${entry.key}: ${entry.value} mesaj');
    }
    
    // Eğer çok fazla katılımcı varsa (büyük ihtimalle hatalı parsing), filtrele
    if (participants.length > 10) {
      debugPrint('⚠️ Çok fazla katılımcı bulundu (${participants.length}), filtreleme uygulanıyor...');
      return _filterRelevantParticipants(sortedParticipants);
    }
    
    debugPrint('✅ FINAL KATILIMCI LİSTESİ: ${participants.toList()}');
    return participants.toList()..sort();
  }
  
  // Tek bir satırdan katılımcı adını çıkar - SADECE GERÇEKTen WhatsApp formatlarından
  String? _extractParticipantFromLine(String line) {
    // SADECE doğrulanmış WhatsApp export formatları kabul edilir
    
    // Format 1: [25/12/2023, 14:30:45] Ahmet: Mesaj (Ana WhatsApp export formatı)
    RegExp format1 = RegExp(r'^\[(\d{1,2}[\.\/]\d{1,2}[\.\/]\d{2,4}),\s*(\d{1,2}:\d{2}(?::\d{2})?)\]\s*([^:]+):\s*(.+)$');
    Match? match1 = format1.firstMatch(line);
    if (match1 != null) {
      String name = match1.group(3)?.trim() ?? '';
      if (_hasValidWhatsAppNameStructure(name)) {
        return _cleanParticipantName(name);
      }
    }
    
    // Format 2: 25/12/2023, 14:30 - Ahmet: Mesaj (İkinci yaygın format)
    RegExp format2 = RegExp(r'^(\d{1,2}[\.\/]\d{1,2}[\.\/]\d{2,4}),?\s*(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–]\s*([^:]+):\s*(.+)$');
    Match? match2 = format2.firstMatch(line);
    if (match2 != null) {
      String name = match2.group(3)?.trim() ?? '';
      if (_hasValidWhatsAppNameStructure(name)) {
        return _cleanParticipantName(name);
      }
    }
    
    // Diğer formatları KABUL ETMİYORUZ - çok riskli
    return null;
  }
  
  // WhatsApp isim yapısının geçerli olup olmadığını kontrol et
  bool _hasValidWhatsAppNameStructure(String name) {
    if (name.isEmpty || name.length < 2 || name.length > 30) return false;
    
    // Tarih/saat kalıntısı varsa reddet
    if (RegExp(r'\d{1,2}[\.\/]\d{1,2}[\.\/]\d{2,4}').hasMatch(name)) return false;
    if (RegExp(r'\d{1,2}:\d{2}').hasMatch(name)) return false;
    
    // Çok fazla sayı içeriyorsa reddet (%30'dan fazla)
    int digitCount = RegExp(r'\d').allMatches(name).length;
    if (digitCount > name.length * 0.3) return false;
    
    // Özel karakterlerin çok olduğu durumları reddet
    int specialCharCount = RegExp(r'[^\w\sğüşöçıİĞÜŞÖÇ]').allMatches(name).length;
    if (specialCharCount > 2) return false;
    
    // Sadece büyük harflerden oluşan kelimeler (TITLE, GENRE gibi) muhtemelen geçersiz
    if (name.length > 4 && name == name.toUpperCase() && !RegExp(r'\d').hasMatch(name)) {
      return false;
    }
    
    // İngilizce teknik terimler (WhatsApp'ta isim olarak kullanılmaz)
    final List<String> technicalTerms = [
      'genre', 'plot', 'title', 'year', 'movie', 'film', 'episode',
      'season', 'series', 'video', 'audio', 'image', 'document',
      'file', 'link', 'url', 'http', 'https', 'www', 'com', 'org',
      'admin', 'system', 'notification', 'message', 'chat', 'group'
    ];
    
    String lowerName = name.toLowerCase();
    for (String term in technicalTerms) {
      if (lowerName == term || lowerName.startsWith(term + ' ') || lowerName.endsWith(' ' + term)) {
        return false;
      }
    }
    
    // Çok uzun kelimeler (tek kelime 15+ karakter) muhtemelen geçersiz
    List<String> words = name.split(' ');
    for (String word in words) {
      if (word.length > 15) return false;
    }
    
    return true;
  }
  
  // Katılımcı adını temizle
  String _cleanParticipantName(String name) {
    // Tarih ve saat bilgilerini temizle
    name = name.replaceAll(RegExp(r'\d{1,2}[\.\/]\d{1,2}[\.\/]\d{2,4}'), '');
    name = name.replaceAll(RegExp(r'\d{1,2}:\d{2}(?::\d{2})?'), '');
    
    // Özel karakterleri temizle
    name = name.replaceAll(RegExp(r'[,\-–\[\]()]+'), '');
    
    // Çoklu boşlukları tek boşluk yap
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    
    return name.trim();
  }
  
  // Geçerli katılımcı adı kontrolü - ÇOK SIKTI kurallar (sadece gerçek WhatsApp isimleri)
  bool _isValidParticipantName(String name) {
    if (name.isEmpty || name.length < 2 || name.length > 25) return false;
    
    // Sadece sayılardan oluşan isimler ASLA
    if (RegExp(r'^\d+$').hasMatch(name)) return false;
    
    // Çok fazla sayı içeren isimler (%20'den fazla)
    int digitCount = RegExp(r'\d').allMatches(name).length;
    if (digitCount > name.length * 0.2) return false;
    
    // KESIN YASAK kelimeler - tek kelime olarak da geçmez
    final List<String> strictlyBannedWords = [
      'genre', 'plot', 'title', 'year', 'movie', 'film', 'episode', 'season',
      'series', 'video', 'audio', 'image', 'document', 'location', 'contact',
      'whatsapp', 'message', 'system', 'admin', 'notification', 'grup', 'group',
      'call', 'missed', 'left', 'joined', 'changed', 'removed', 'added',
      'created', 'deleted', 'silindi', 'eklendi', 'çıktı', 'katıldı',
      'http', 'https', 'www', 'com', 'org', 'net', 'download', 'upload',
      'link', 'url', 'file', 'dosya', 'resim', 'ses', 'music', 'song'
    ];
    
    String lowerName = name.toLowerCase();
    
    // Kesin yasak kelimelerden herhangi birini içeriyorsa reddet
    for (String banned in strictlyBannedWords) {
      if (lowerName == banned || lowerName.contains(banned)) return false;
    }
    
    // Büyük harfle başlayıp tamamı büyük harf olan kelimeler (teknik terimler)
    if (name.length > 3 && name == name.toUpperCase()) return false;
    
    // URL benzeri yapılar
    if (name.contains('://') || name.contains('.com') || name.contains('.org') || 
        name.contains('.net') || name.contains('www.')) return false;
    
    // Dosya yolu benzeri
    if (name.contains('/') || name.contains('\\') || name.contains('.txt') || 
        name.contains('.jpg') || name.contains('.png')) return false;
    
    // Çok fazla özel karakter (sadece 1 özel karaktere izin ver)
    int specialCharCount = RegExp(r'[^a-zA-ZğüşöçıİĞÜŞÖÇ0-9\s]').allMatches(name).length;
    if (specialCharCount > 1) return false;
    
    // Telefon numarası benzeri
    if (RegExp(r'^\+?\d[\d\s\-()]{7,}$').hasMatch(name)) return false;
    
    // E-mail benzeri
    if (name.contains('@')) return false;
    
    // Sadece boşluk ve özel karakterlerden oluşan
    if (RegExp(r'^[\s\W]+$').hasMatch(name)) return false;
    
    // En az bir harf içermeli (sadece sayı ve özel karakter olamaz)
    if (!RegExp(r'[a-zA-ZğüşöçıİĞÜŞÖÇ]').hasMatch(name)) return false;
    
    // Çok fazla kelime (5+ kelime muhtemelen isim değil)
    if (name.split(' ').length > 4) return false;
    
    return true;
  }
  
  // En ilgili katılımcıları filtrele
  List<String> _filterRelevantParticipants(List<MapEntry<String, int>> sortedParticipants) {
    // En az 3 mesaj göndermiş ve en fazla 10 kişi
    List<String> filtered = sortedParticipants
        .where((entry) => entry.value >= 3) // En az 3 mesaj
        .take(10) // En fazla 10 kişi
        .map((entry) => entry.key)
        .toList();
    
    debugPrint('Filtreleme sonrası ${filtered.length} katılımcı kaldı:');
    for (int i = 0; i < filtered.length; i++) {
      var participant = sortedParticipants[i];
      debugPrint('${i + 1}. ${participant.key}: ${participant.value} mesaj');
    }
    
    return filtered;
  }

  // Silinen mesajları ve medya içeriklerini temizleyen fonksiyon
  String _temizleSilinenVeMedyaMesajlari(String metin) {
    List<String> lines = metin.split('\n');
    List<String> temizLines = [];
    
    for (String line in lines) {
      String trimmedLine = line.trim();
      
      // Boş satırları koru
      if (trimmedLine.isEmpty) {
        temizLines.add(line);
        continue;
      }
      
      // Silinen mesaj kalıpları (Türkçe ve İngilizce)
      final List<String> silinenMesajKaliplari = [
        'Bu mesaj silindi',
        'This message was deleted',
        'Mesaj silindi',
        'Message deleted',
        'Bu mesaj geri alındı',
        'This message was recalled',
        'Silinen mesaj',
        'Deleted message',
        '🚫 Bu mesaj silindi',
        '❌ Bu mesaj silindi',
      ];
      
      // Medya içerik kalıpları
      final List<String> medyaKaliplari = [
        '(medya içeriği)',
        '(media content)',
        '(görsel)',
        '(image)',
        '(video)',
        '(ses)',
        '(audio)',
        '(dosya)',
        '(file)',
        '(document)',
        '(belge)',
        '(fotoğraf)',
        '(photo)',
        '(resim)',
        '(sticker)',
        '(çıkartma)',
        '(gif)',
        '(konum)',
        '(location)',
        '(kişi)',
        '(contact)',
        '(arama)',
        '(call)',
        '(sesli arama)',
        '(voice call)',
        '(görüntülü arama)',
        '(video call)',
        '(canlı konum)',
        '(live location)',
        '(anket)',
        '(poll)',
      ];
      
      // Sistem mesajları (grup bildirimleri vs.)
      final List<String> sistemMesajlari = [
        'gruba eklendi',
        'gruptan çıktı',
        'gruptan çıkarıldı',
        'grup adını değiştirdi',
        'grup açıklamasını değiştirdi',
        'grup resmini değiştirdi',
        'güvenlik kodunuz değişti',
        'şifreleme anahtarları değişti',
        'added to the group',
        'left the group',
        'removed from the group',
        'changed the group name',
        'changed the group description',
        'changed the group photo',
        'security code changed',
        'encryption keys changed',
        'mesajlar uçtan uca şifrelendi',
        'messages are end-to-end encrypted',
      ];
      
      // Satırın mesaj kısmını çıkar (tarih ve isim kısmından sonra)
      String mesajKismi = '';
      
      // WhatsApp formatlarından mesaj kısmını çıkar
      // Format 1: [25/12/2023, 14:30:45] Ahmet: Mesaj
      RegExp format1 = RegExp(r'^\[([^\]]+)\]\s*([^:]+):\s*(.+)$');
      Match? match1 = format1.firstMatch(trimmedLine);
      if (match1 != null) {
        mesajKismi = match1.group(3)?.trim() ?? '';
      } else {
        // Format 2: 25/12/2023, 14:30 - Ahmet: Mesaj
        RegExp format2 = RegExp(r'^(\d{1,2}[\.\/]\d{1,2}[\.\/]\d{2,4})[,\s]+(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–]\s*([^:]+):\s*(.+)$');
        Match? match2 = format2.firstMatch(trimmedLine);
        if (match2 != null) {
          mesajKismi = match2.group(4)?.trim() ?? '';
        } else {
          // Format 3: Basit format - Ahmet: Mesaj
          RegExp format3 = RegExp(r'^([^:]+):\s*(.+)$');
          Match? match3 = format3.firstMatch(trimmedLine);
          if (match3 != null) {
            mesajKismi = match3.group(2)?.trim() ?? '';
          } else {
            // Mesaj formatı tanınmadı, satırı olduğu gibi kontrol et
            mesajKismi = trimmedLine;
          }
        }
      }
      
      // Silinen mesaj kontrolü
      bool silinenMesaj = false;
      for (String kalip in silinenMesajKaliplari) {
        if (mesajKismi.toLowerCase().contains(kalip.toLowerCase())) {
          silinenMesaj = true;
          break;
        }
      }
      
      // Medya içerik kontrolü
      bool medyaIcerik = false;
      for (String kalip in medyaKaliplari) {
        if (mesajKismi.toLowerCase().contains(kalip.toLowerCase())) {
          medyaIcerik = true;
          break;
        }
      }
      
      // Sistem mesajı kontrolü
      bool sistemMesaji = false;
      for (String kalip in sistemMesajlari) {
        if (mesajKismi.toLowerCase().contains(kalip.toLowerCase()) || 
            trimmedLine.toLowerCase().contains(kalip.toLowerCase())) {
          sistemMesaji = true;
          break;
        }
      }
      
      // Sadece gerçek mesajları koru
      if (!silinenMesaj && !medyaIcerik && !sistemMesaji && mesajKismi.isNotEmpty) {
        temizLines.add(line);
      }
    }
    
    return temizLines.join('\n');
  }

  // Hassas bilgileri sansürleyen fonksiyon
  String _sansurleHassasBilgiler(String metin) {
    // TC Kimlik Numarası (11 haneli sayı)
    metin = metin.replaceAll(RegExp(r'\b\d{11}\b'), '***********');
    
    // Kredi Kartı Numarası (16 haneli, boşluk/tire ile ayrılmış olabilir)
    metin = metin.replaceAll(RegExp(r'\b\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4}\b'), '**** **** **** ****');
    
    // Telefon Numarası (Türkiye formatları)
    metin = metin.replaceAll(RegExp(r'\b(\+90|0)[\s\-]?\d{3}[\s\-]?\d{3}[\s\-]?\d{2}[\s\-]?\d{2}\b'), '0*** *** ** **');
    
    // IBAN (TR ile başlayan 26 karakter)
    metin = metin.replaceAll(RegExp(r'\bTR\d{24}\b'), 'TR** **** **** **** **** **');
    
    // E-posta adresleri (kısmi sansür)
    metin = metin.replaceAllMapped(RegExp(r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b'), 
        (match) {
          String email = match.group(0)!;
          int atIndex = email.indexOf('@');
          if (atIndex > 2) {
            String username = email.substring(0, atIndex);
            String domain = email.substring(atIndex);
            String maskedUsername = username.substring(0, 2) + '*' * (username.length - 2);
            return maskedUsername + domain;
          }
          return '***@***';
        });
    
    // Şifre benzeri ifadeler (şifre, password, pin kelimelerinden sonra gelen değerler)
    metin = metin.replaceAllMapped(RegExp(r'(şifre|password|pin|parola|sifre)[\s:=]+[^\s]+', caseSensitive: false), 
        (match) => match.group(0)!.split(RegExp(r'[\s:=]+'))[0] + ': ****');
    
    // Adres bilgileri (mahalle, sokak, cadde içeren uzun metinler)
    metin = metin.replaceAll(RegExp(r'\b[^.!?]*?(mahalle|sokak|cadde|bulvar|apt|daire|no)[^.!?]*[.!?]?', caseSensitive: false), 
        '[Adres bilgisi sansürlendi]');
    
    // Doğum tarihi (DD/MM/YYYY, DD.MM.YYYY formatları)
    metin = metin.replaceAll(RegExp(r'\b\d{1,2}[./]\d{1,2}[./](19|20)\d{2}\b'), '**/**/****');
    
    // Plaka numaraları (Türkiye formatı)
    metin = metin.replaceAll(RegExp(r'\b\d{2}[\s]?[A-Z]{1,3}[\s]?\d{2,4}\b'), '** *** ****');
    
    // Banka hesap numaraları (uzun sayı dizileri)
    metin = metin.replaceAllMapped(RegExp(r'\b\d{8,20}\b'), (match) {
      String number = match.group(0)!;
      if (number.length >= 8) {
        return '*' * number.length;
      }
      return number;
    });
    
    return metin;
  }

  // Kişi seçim dialog'unu göster
  Future<String?> _showParticipantSelectionDialog(List<String> participants, String fileName, String fileSize, int messageCount) async {
    if (participants.isEmpty) {
      return 'Tüm Katılımcılar'; // Varsayılan seçenek
    }
    
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        String? selectedParticipant = participants.isNotEmpty ? participants.first : null;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF352269),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.group,
                    color: const Color(0xFF9D3FFF),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Kişi Seçimi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dosya bilgileri özeti
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Dosya:', fileName),
                          _buildInfoRow('Boyut:', fileSize),
                          _buildInfoRow('Mesaj Sayısı:', messageCount.toString()),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Text(
                      'Dosyada ${participants.length} kişi bulundu. Analiz etmek istediğiniz kişiyi seçin:',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Tüm katılımcılar seçeneği
                    RadioListTile<String>(
                      value: 'Tüm Katılımcılar',
                      groupValue: selectedParticipant,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedParticipant = value;
                        });
                      },
                      title: Text(
                        'Tüm Katılımcılar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Tüm sohbeti analiz et',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      activeColor: const Color(0xFF9D3FFF),
                    ),
                    
                    const Divider(color: Colors.white24),
                    
                    // Katılımcılar listesi
                    ...participants.map((participant) {
                      return RadioListTile<String>(
                        value: participant,
                        groupValue: selectedParticipant,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedParticipant = value;
                          });
                        },
                        title: Text(
                          participant,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Bu kişinin mesajlarını analiz et',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        activeColor: const Color(0xFF9D3FFF),
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(null);
                  },
                  child: Text(
                    'İptal',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedParticipant != null ? () {
                    Navigator.of(context).pop(selectedParticipant);
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9D3FFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Analizi Başlat',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Seçilen katılımcıya göre mesajları filtrele ve diğer katılımcıyı tespit et
  Map<String, String> _filterMessagesByParticipantWithOther(String content, String selectedParticipant, List<String> allParticipants) {
    if (selectedParticipant == 'Tüm Katılımcılar') {
      return {
        'filteredContent': content,
        'otherParticipant': '',
      };
    }
    
    final lines = content.split('\n');
    final filteredLines = <String>[];
    
    // Diğer katılımcıyı bul (seçilen hariç)
    String otherParticipant = '';
    for (String participant in allParticipants) {
      if (participant != selectedParticipant) {
        otherParticipant = participant;
        break; // İlk bulunan diğer katılımcıyı al
      }
    }
    
    for (final line in lines) {
      if (line.trim().isEmpty) {
        filteredLines.add(line);
        continue;
      }
      
      // Bu satır seçilen katılımcıya ait mi kontrol et
      final patterns = [
        RegExp(r'\[.*?\]\s*' + RegExp.escape(selectedParticipant) + r':'),
        RegExp(r'\d{1,2}[\.\/]\d{1,2}[\.\/]\d{2,4}[,\s]+\d{1,2}:\d{2}\s*-\s*' + RegExp.escape(selectedParticipant) + r':'),
        RegExp('^' + RegExp.escape(selectedParticipant) + r'\s*\([^)]*\):'),
        RegExp('^' + RegExp.escape(selectedParticipant) + r':'),
      ];
      
      bool isParticipantMessage = false;
      for (final pattern in patterns) {
        if (pattern.hasMatch(line)) {
          isParticipantMessage = true;
          break;
        }
      }
      
      if (isParticipantMessage) {
        filteredLines.add(line);
      }
    }
    
    return {
      'filteredContent': filteredLines.join('\n'),
      'otherParticipant': otherParticipant,
    };
  }

  // Geriye uyumluluk için eski metod
  String _filterMessagesByParticipant(String content, String selectedParticipant) {
    if (selectedParticipant == 'Tüm Katılımcılar') {
      return content;
    }
    
    final lines = content.split('\n');
    final filteredLines = <String>[];
    
    for (final line in lines) {
      if (line.trim().isEmpty) {
        filteredLines.add(line);
        continue;
      }
      
      // Bu satır seçilen katılımcıya ait mi kontrol et
      final patterns = [
        RegExp(r'\[.*?\]\s*' + RegExp.escape(selectedParticipant) + r':'),
        RegExp(r'\d{1,2}[\.\/]\d{1,2}[\.\/]\d{2,4}[,\s]+\d{1,2}:\d{2}\s*-\s*' + RegExp.escape(selectedParticipant) + r':'),
        RegExp('^' + RegExp.escape(selectedParticipant) + r'\s*\([^)]*\):'),
        RegExp('^' + RegExp.escape(selectedParticipant) + r':'),
      ];
      
      bool isParticipantMessage = false;
      for (final pattern in patterns) {
        if (pattern.hasMatch(line)) {
          isParticipantMessage = true;
          break;
        }
      }
      
      if (isParticipantMessage) {
        filteredLines.add(line);
      }
    }
    
    return filteredLines.join('\n');
  }

  // Metin dosyası seçme işlemi
  Future<bool?> _pickTextFile() async {
    try {
      setState(() {
        _isLoading = true;
        _isImageAnalysis = false;
      });
      
      // Dosya seçiciyi aç - iOS ve macOS için uniformTypeIdentifiers ekle
      final XTypeGroup typeGroup = XTypeGroup(
        label: 'Metin Dosyaları',
        extensions: <String>['txt'],
        uniformTypeIdentifiers: <String>['public.plain-text'],
        mimeTypes: <String>['text/plain'],
      );
      
      final XFile? pickedFile = await openFile(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      );
      
      // Kullanıcı dosya seçimini iptal etti
      if (pickedFile == null) {
        setState(() {
          _isLoading = false;
        });
        return false;
      }

      // Dosya içeriğini oku
      final File file = File(pickedFile.path);
      String fileContent = await file.readAsString();
      
      // Dosya bilgilerini hesapla
      final fileSizeBytes = await file.length();
      final double fileSizeMB = fileSizeBytes / (1024 * 1024);
      final String fileSizeText = fileSizeMB >= 1 
          ? '${fileSizeMB.toStringAsFixed(2)} MB'
          : '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
      
      // Mesaj sayısını kabaca hesapla (satır başına yaklaşık 1 mesaj)
      final lines = fileContent.split('\n');
      final estimatedMessageCount = lines.where((line) => line.trim().isNotEmpty).length;
      
      // Dosyadan katılımcıları çıkar
      final participants = _extractParticipantsFromText(fileContent);
      
      // Kişi seçim dialog'unu göster
      final String? selectedParticipant = await _showParticipantSelectionDialog(
        participants, 
        pickedFile.name, 
        fileSizeText, 
        estimatedMessageCount
      );
      
      // Kullanıcı iptal ettiyse
      if (selectedParticipant == null) {
        setState(() {
          _isLoading = false;
        });
        return false;
      }
      
             if (fileContent.isEmpty) {
         if (mounted) {
           setState(() {
             _isLoading = false;
           });
           Utils.showErrorFeedback(context, 'Metin dosyası boş');
         }
         return false;
       }
       
       // Seçilen katılımcıya göre mesajları filtrele ve diğer katılımcıyı tespit et
       final filterResult = _filterMessagesByParticipantWithOther(fileContent, selectedParticipant, participants);
       String filteredContent = filterResult['filteredContent']!;
       String otherParticipant = filterResult['otherParticipant']!;
       
       // Silinen mesajları ve medya içeriklerini temizle
       filteredContent = _temizleSilinenVeMedyaMesajlari(filteredContent);
       
       // Hassas bilgileri sansürle (güvenlik için)
       filteredContent = _sansurleHassasBilgiler(filteredContent);
       
       // ViewModeli al
       final viewModel = Provider.of<MessageViewModel>(context, listen: false);
       
       // Önceki analiz işlemlerini sıfırla
       viewModel.resetCurrentAnalysis();
       
       // Mesaj içeriğini AI için hazırla - seçilen kişiye göre
       String aiPromptContent;
       if (selectedParticipant == 'Tüm Katılımcılar') {
         aiPromptContent = "---- WhatsApp Sohbet Analizi ----\n"
             "Bu bir WhatsApp sohbet dışa aktarımıdır. Tüm katılımcıların mesajları dahil edilmiştir.\n"
             "Lütfen bu sohbeti genel olarak analiz edin.\n\n"
             "$filteredContent\n"
             "---- Sohbet Sonu ----";
       } else {
         // Diğer katılımcı bilgisi varsa onu da belirt
         String conversationContext = otherParticipant.isNotEmpty 
             ? "$selectedParticipant'in $otherParticipant ile olan sohbeti"
             : "$selectedParticipant'in sohbeti";
             
         aiPromptContent = "---- WhatsApp Sohbet Analizi ----\n"
             "Bu bir WhatsApp sohbet dışa aktarımıdır. Sadece '$selectedParticipant' kişisinin mesajları dahil edilmiştir.\n"
             "Bu $conversationContext analiz ediliyor.\n"
             "Lütfen bu analizi '$selectedParticipant' kişisinin bakış açısından yapın.\n"
             "Analiz sonuçlarında '$selectedParticipant' kişisinin mesajlaşma tarzı, duygu durumu ve iletişim yaklaşımına odaklanın.\n";
             
         if (otherParticipant.isNotEmpty) {
           aiPromptContent += "Karşısındaki kişi: $otherParticipant\n";
         }
         
         aiPromptContent += "\n$filteredContent\n---- Sohbet Sonu ----";
       }
       
       filteredContent = aiPromptContent;
      
      // Normal mesaj analizi + otomatik wrapped analizi
      // NOT: analizSohbetVerisi metodu artık hem normal analiz hem de wrapped analizi yapıyor
      final AiService aiService = AiService();
      
             try {
         // Normal mesaj analizi - filtrelenmiş içerikle
         final bool normalAnalysisResult = await viewModel.analyzeMessage(filteredContent);
         
         if (!normalAnalysisResult) {
           if (mounted) {
             setState(() {
               _isLoading = false;
             });
             Utils.showErrorFeedback(context, 'Normal analiz yapılırken hata oluştu');
           }
           return false;
         }
         
         // Wrapped analizi için içeriği hazırla - TÜM MESAJLARI KULLAN
         // Sadece bakış açısı seçilen kişiye göre olacak, mesajlar filtrelenmeyecek
         String wrappedContent = await file.readAsString();
         
         // Wrapped analizi için silinen mesajları ve medya içeriklerini temizle
         wrappedContent = _temizleSilinenVeMedyaMesajlari(wrappedContent);
         
         // Wrapped analizi için de hassas bilgileri sansürle
         wrappedContent = _sansurleHassasBilgiler(wrappedContent);
         
         // Wrapped analizi yap ve otomatik olarak kaydet
         debugPrint('Wrapped analizi otomatik başlatılıyor...');
         debugPrint('- Seçilen katılımcı: $selectedParticipant');
         debugPrint('- Karşısındaki kişi: $otherParticipant');
         
         final List<Map<String, String>> wrappedData = await aiService.wrappedAnaliziYap(
           wrappedContent,
           secilenKisi: selectedParticipant,
           karsiKisi: otherParticipant, // Karşısındaki kişiyi de gönder
         );
        
        if (wrappedData.isNotEmpty) {
          // Wrapped verileri önbelleğe kaydet
                     await _cacheSummaryData(wrappedContent, wrappedData);
          debugPrint('Wrapped analizi tamamlandı ve önbelleğe kaydedildi: ${wrappedData.length} kart');
        }
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _showDetailedAnalysisResult = normalAnalysisResult;
          });
          
                     final String successMessage = selectedParticipant == 'Tüm Katılımcılar' 
               ? 'Tüm katılımcıların mesajları başarıyla analiz edildi!'
               : '"$selectedParticipant" kişisinin mesajları başarıyla analiz edildi!';
           Utils.showSuccessFeedback(context, successMessage);
          
          // Ana sayfayı güncelleme işlemini biraz geciktir
          Future.delayed(const Duration(milliseconds: 500)).then((_) {
            if (mounted) {
              try {
                final homeController = Provider.of<HomeController>(context, listen: false);
                homeController.anaSayfayiGuncelle();
              } catch (e) {
                debugPrint('Ana sayfa güncellenirken hata: $e');
              }
            }
          });
          
          return true; // Başarılı analiz
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          debugPrint('Analiz hatası: $e');
          Utils.showErrorFeedback(context, 'Analiz sırasında hata oluştu: $e');
        }
        return false;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        debugPrint('_pickTextFile hata: $e');
        Utils.showErrorFeedback(context, 'Dosya işleme sırasında hata: $e');
      }
      return false;
    }
    
    return null; // Widget mount edilmediğinde
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
            
            // .txt dosyası analizi için Wrapped Görüntüleme butonu
            // Sadece metin analizi ise butonu göster
            if (latestMessage.analysisSource == AnalysisSource.text) 
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Önbellekten wrapped verilerini kontrol et ve göster
                      try {
                        final SharedPreferences prefs = await SharedPreferences.getInstance();
                        final String? cachedDataJson = prefs.getString('wrappedCacheData');
                        
                        if (cachedDataJson != null && cachedDataJson.isNotEmpty) {
                          // Önbellekteki verileri parse et
                          final List<dynamic> decodedData = jsonDecode(cachedDataJson);
                          final List<Map<String, String>> summaryData = List<Map<String, String>>.from(
                            decodedData.map((item) => Map<String, String>.from(item))
                          );
                          
                          if (summaryData.isNotEmpty) {
                            // Wrapped seçenek dialogunu göster
                            _showWrappedOptionsDialog(summaryData);
                          } else {
                            Utils.showErrorFeedback(context, 'Wrapped verisi bulunamadı');
                          }
                        } else {
                          Utils.showErrorFeedback(context, 'Wrapped analizi bulunamadı. Lütfen txt dosyasını tekrar analiz edin.');
                        }
                      } catch (e) {
                        Utils.showErrorFeedback(context, 'Wrapped verisi yüklenirken hata oluştu: $e');
                      }
                    },
                    icon: const Icon(
                      Icons.auto_awesome,
                      size: 22,
                    ),
                    label: const Text(
                      "✨ Wrapped Analizini Göster",
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


  // Görsel seçme işlemi
  Future<void> _gorselSec() async {
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
        
        debugPrint('_gorselSec genel hata: $e');
        Utils.showErrorFeedback(
          context, 
          'Görsel seçme işlemi sırasında hata: $e'
        );
      }
    }
  }

  // Sonuçları önbelleğe kaydetme
  Future<void> _cacheSummaryData(String content, List<Map<String, String>> summaryData) async {
    try {
      if (summaryData.isEmpty || content.isEmpty) {
        debugPrint('Kaydedilecek analiz sonucu veya içerik yok');
        return;
      }
      
      // Veri sayısı kontrolü
      if (summaryData.length != 10) {
        debugPrint('UYARI: Önbelleğe kaydedilecek veri tam 10 wrapped kartı içermiyor (${summaryData.length} kart). Veri tamamlanacak veya kırpılacak.');
        
        // Eğer 10'dan az kart varsa, eksik kartları tamamla
        if (summaryData.length < 10) {
          final List<Map<String, String>> varsayilanKartlar = [
            {'title': 'İlk Mesaj - Son Mesaj', 'comment': 'İlk mesaj ve son mesaj bilgisi.'},
            {'title': 'Mesaj Sayıları', 'comment': 'Toplam mesaj sayısı ve dağılımları.'},
            {'title': 'En Yoğun Ay/Gün', 'comment': 'En çok mesajlaşılan ay ve gün bilgisi.'},
            {'title': 'En Çok Kullanılan Kelimeler', 'comment': 'Sohbette en sık geçen kelimeler.'},
            {'title': 'Pozitif/Negatif Ton', 'comment': 'Sohbetin duygusal tonu.'},
            {'title': 'Mesaj Patlaması', 'comment': 'En yoğun mesajlaşma dönemi.'},
            {'title': 'Sessizlik Süresi', 'comment': 'En uzun cevapsız kalınan süre.'},
            {'title': 'İletişim Tipi', 'comment': 'Mesajlaşma tarzınız.'},
            {'title': 'Mesaj Tipleri', 'comment': 'Mesajların içerik türleri.'},
            {'title': 'Kişisel Performans', 'comment': 'Mesajlaşma performansınız.'}
          ];
          
          for (int i = summaryData.length; i < 10; i++) {
            summaryData.add(varsayilanKartlar[i % varsayilanKartlar.length]);
          }
        } 
        // Eğer 10'dan fazla kart varsa, ilk 10 kartı al
        else if (summaryData.length > 10) {
          summaryData = summaryData.sublist(0, 10);
        }
      }
      
      debugPrint('Wrapped analiz sonuçları önbelleğe kaydediliyor (${summaryData.length} kart)');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Sonuçları JSON'a dönüştür
      final String encodedData = jsonEncode(summaryData);
      
      // Sonuçları ve ilgili içeriği kaydet
      await prefs.setString('wrappedCacheData', encodedData);
      await prefs.setString('wrappedCacheContent', content);
      
      // Ana sayfada göstermek için yeni bir wrapped analizi oluştur ve kaydet
      final String newId = DateTime.now().millisecondsSinceEpoch.toString();
      final Map<String, dynamic> newAnalysis = {
        'id': newId,
        'title': 'Wrapped',
        'date': DateTime.now().toIso8601String(),
        'dataRef': 'wrappedCacheData',
      };
      
      // Mevcut wrapped listesini al
      String? wrappedListJson = prefs.getString('wrappedAnalysesList');
      List<Map<String, dynamic>> wrappedList = [];
      
      if (wrappedListJson != null && wrappedListJson.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(wrappedListJson);
        wrappedList = List<Map<String, dynamic>>.from(
          decodedList.map((item) => Map<String, dynamic>.from(item))
        );
      }
      
      // Veriyi wrapped listesine ekle (eğer aynı dataRef'e sahip bir item yoksa)
      bool hasWrappedCacheInList = wrappedList.any((item) => item['dataRef'] == 'wrappedCacheData');
      
      if (!hasWrappedCacheInList) {
        wrappedList.add(newAnalysis);
        await prefs.setString('wrappedAnalysesList', jsonEncode(wrappedList));
        debugPrint('Yeni wrapped analizi otomatik olarak oluşturuldu ve ana sayfa listesine eklendi');
      } else {
        // Var olan wrapped analizini güncelle (tarihi yenile)
        final int existingIndex = wrappedList.indexWhere((item) => item['dataRef'] == 'wrappedCacheData');
        if (existingIndex >= 0) {
          wrappedList[existingIndex]['date'] = DateTime.now().toIso8601String();
          await prefs.setString('wrappedAnalysesList', jsonEncode(wrappedList));
          debugPrint('Mevcut wrapped analizi güncellendi');
        }
      }
      
      debugPrint('${summaryData.length} analiz sonucu önbelleğe kaydedildi');
      
      // Ana sayfaya bildirim gönder - wrapped listesini güncellemesi için
      try {
        // Microtask döngüsünü önlemek için gecikme ekle
        // Bu EventBus bildirimi, kullanıcı geri döndüğünde ana sayfada wrapped dairesinin görünmesini sağlar
        Future.delayed(Duration(milliseconds: 500), () {
          final EventBusService eventBus = EventBusService();
          eventBus.emit(AppEvents.refreshHomeData);
          debugPrint('refreshHomeData olayı gönderildi - Ana sayfa wrapped analizi güncellenecek');
        });
      } catch (e) {
        debugPrint('EventBus gönderme hatası: $e');
      }
    } catch (e) {
      debugPrint('Önbelleğe kaydetme hatası: $e');
    }
  }
  
  // Önbellekteki veriyi kontrol etme ve yükleme
  Future<bool> _checkAndLoadCachedSummary(String content) async {
    try {
      debugPrint('Önbellekte wrapped analiz sonucu kontrolü yapılıyor');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Önbellekten veri kontrolü
      final String? cachedDataJson = prefs.getString('wrappedCacheData');
      final String? cachedContent = prefs.getString('wrappedCacheContent');
      
      if (cachedDataJson != null && cachedDataJson.isNotEmpty) {
        // Kayıtlı içerik ve mevcut içerik kontrolü
        if (cachedContent != null && content.isNotEmpty && cachedContent == content) {
          // Önbellekteki verilerin formatını kontrol et
          try {
            final List<dynamic> decodedData = jsonDecode(cachedDataJson);
            final List<Map<String, String>> wrappedData = List<Map<String, String>>.from(
              decodedData.map((item) => Map<String, String>.from(item))
            );
            
            // Tam olarak 10 kart olduğundan emin ol
            if (wrappedData.length != 10) {
              debugPrint('Önbellekteki veri 10 wrapped kartı içermiyor (${wrappedData.length} kart bulundu). Önbellek geçersiz sayılacak.');
              return false;
            }
            
            // Kartların gerekli alanları içerdiğinden emin ol
            for (var kart in wrappedData) {
              if (!kart.containsKey('title') || !kart.containsKey('comment')) {
                debugPrint('Önbellekteki wrapped kartlarında eksik alanlar var. Önbellek geçersiz sayılacak.');
                return false;
              }
            }
            
            debugPrint('Mevcut içerik önbellekteki ile aynı, önbellekte geçerli 10 wrapped kartı var');
            return true;
          } catch (e) {
            debugPrint('Önbellek verisi ayrıştırma hatası: $e');
            return false;
          }
        }
      }
      
      debugPrint('Önbellekte eşleşen analiz sonucu bulunamadı');
      return false;
    } catch (e) {
      debugPrint('Önbellek kontrolü sırasında hata: $e');
      return false;
    }
  }

  // Premium özelliği için bilgilendirme dialog'unu göster
  void showPremiumInfoDialog(BuildContext context, PremiumFeature feature) {
    String featureName = '';
    String description = '';
    
    switch (feature) {
      case PremiumFeature.VISUAL_OCR:
        featureName = 'Görsel Analizi';
        description = 'Sınırsız görsel analizi yapabilmek için Premium üyeliğe geçin. Premium üyeler reklam izlemeden sınırsız görsel analizi yapabilir.';
        break;
      case PremiumFeature.TXT_ANALYSIS:
        featureName = 'Metin Dosyası Analizi';
        description = 'Sınırsız metin dosyası analizi için Premium üyeliğe geçin. Premium üyeler limitsiz .txt dosyası analizi yapabilir.';
        break;
      case PremiumFeature.WRAPPED_ANALYSIS:
        featureName = 'Wrapped Analiz';
        description = 'Sınırsız detaylı Spotify Wrapped tarzı analiz yapmak için Premium üyeliğe geçin.';
        break;
      case PremiumFeature.CONSULTATION:
        featureName = 'Danışma Hizmeti';
        description = 'Danışma hizmetimizden yararlanmak için Premium üyeliğe geçin. Premium üyeler ilişki uzmanlarımızdan kişisel danışmanlık alabilir.';
        break;
      case PremiumFeature.MESSAGE_COACH:
        featureName = 'Mesaj Koçu';
        description = 'Mesaj koçu özelliğinden sınırsız yararlanmak için Premium üyeliğe geçin.';
        break;
      default:
        featureName = 'Premium Özelliği';
        description = 'Bu özellikten yararlanmak için Premium üyeliğe geçin.';
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF9D3FFF), width: 1),
          ),
          title: Text(
            featureName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Premium avantajları:",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              _buildPremiumFeatureItem('Sınırsız görsel analizi'),
              _buildPremiumFeatureItem('Reklamsız kullanım'),
              _buildPremiumFeatureItem('Mesaj ve ilişki koçluğu'),
              _buildPremiumFeatureItem('Uzman danışmanlık desteği'),
              _buildPremiumFeatureItem('Detaylı ilişki raporları'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D3FFF),
              ),
              onPressed: () {
                Navigator.pop(context);
                // Premium sayfasına yönlendir
                context.push(AppRouter.premium);
              },
              child: const Text(
                "Premium'a Geç",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // Premium özellik maddesi
  Widget _buildPremiumFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF9D3FFF), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // Wrapped butonu tıklama işleminde açılan dialog
  void _showWrappedOptionsDialog(List<Map<String, String>> summaryData) {
    // Veri kontrolü - tam 10 kart olduğundan emin ol
    if (summaryData.length != 10) {
      debugPrint('UYARI: Wrapped kartları sayısı 10 olmalı, gelen veri sayısı: ${summaryData.length}');
      
      // Kart sayısı 10 değilse düzelt
      if (summaryData.length < 10) {
        // Eksik kartları tamamla
        final String ilkMesajTarihi = summaryData.isNotEmpty && 
                                     summaryData[0]['title']?.contains('İlk Mesaj') == true && 
                                     summaryData[0]['comment'] != null ? 
                                     _extractDateFromComment(summaryData[0]['comment']!) : '';
        
        // Temel kartı oluştur
        final Map<String, String> ilkMesajKarti = _createFirstMessageCard(ilkMesajTarihi);
        
        // İlk mesaj kartı yoksa ekle
        if (!summaryData.any((kart) => kart['title']?.contains('İlk Mesaj') == true)) {
          summaryData.insert(0, ilkMesajKarti);
        }
        
        // Eğer hala 10 kart yoksa, genel istatistik kartları ekle
        final List<Map<String, String>> genelKartBasliklari = [
          {'title': 'Mesaj Sayıları', 'comment': 'Toplam mesaj sayısı ve dağılımları.'},
          {'title': 'En Yoğun Ay/Gün', 'comment': 'En çok mesajlaşılan ay ve gün bilgisi.'},
          {'title': 'En Çok Kullanılan Kelimeler', 'comment': 'Sohbette en sık geçen kelimeler.'},
          {'title': 'Pozitif/Negatif Ton', 'comment': 'Sohbetin duygusal tonu.'},
          {'title': 'Mesaj Patlaması', 'comment': 'En yoğun mesajlaşma dönemi.'},
          {'title': 'Sessizlik Süresi', 'comment': 'En uzun cevapsız kalınan süre.'},
          {'title': 'İletişim Tipi', 'comment': 'Mesajlaşma tarzınız.'},
          {'title': 'Mesaj Tipleri', 'comment': 'Mesajların içerik türleri.'},
          {'title': 'Kişisel Performans', 'comment': 'Mesajlaşma performansınız.'}
        ];
        
        // Eksik kartları ekle
        for (final kartBaslik in genelKartBasliklari) {
          if (!summaryData.any((kart) => kart['title'] == kartBaslik['title']) && summaryData.length < 10) {
            summaryData.add(kartBaslik);
          }
        }
      } else if (summaryData.length > 10) {
        // Fazla kartları kırp
        summaryData = summaryData.sublist(0, 10);
      }
    }
    
    // İlk mesaj tarihinin doğru olduğundan emin ol
    if (summaryData.isNotEmpty && summaryData[0]['title']?.contains('İlk Mesaj') == true) {
      final comment = summaryData[0]['comment'] ?? '';
      
      // Tarih formatını kontrol et
      final RegExp datePattern = RegExp(r'(\d{1,2})[\.\/](\d{1,2})[\.\/](\d{4})');
      final match = datePattern.firstMatch(comment);
      
      if (match != null) {
        final extractedDate = match.group(0);
        debugPrint('Wrapped Kart #1 - Tespit edilen ilk mesaj tarihi: $extractedDate');
      } else {
        debugPrint('UYARI: İlk mesaj tarihini içeren kart bulunamadı: $comment');
      }
    }
    
    // Hata ayıklama için veriyi logla
    for (int i = 0; i < summaryData.length; i++) {
      debugPrint('Wrapped Kart #${i+1}:');
      debugPrint('  Başlık: ${summaryData[i]['title']}');
      debugPrint('  Yorum: ${summaryData[i]['comment']}');
    }

    // Ana sayfaya wrapped analizinin hazır olduğunu bildirmek için EventBus kullanmaya gerek yok
    // Wrapped verileri _cacheSummaryData tarafından kaydedildi ve EventBus oradan gönderiliyor

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF352269),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wrapped Analizi',
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Wrapped analizini nasıl görmek istersiniz?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              // Direkt göster butonu
              _buildWrappedOptionButton(
                title: 'Direkt Göster',
                icon: Icons.show_chart,
                color: const Color(0xFF1DB954),
                onTap: () {
                  Navigator.pop(context); // Dialog'u kapat
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => KonusmaSummaryView(
                        summaryData: summaryData,
                      ),
                    ),
                  );
                },
              ),

            ],
          ),
        );
      },
    );
  }
  
  // Tarihten düzgün bir ilk mesaj bilgisi oluşturma
  Map<String, String> _createFirstMessageCard(String ilkMesajTarihi) {
    final String tarihIfadesi;
    
    if (ilkMesajTarihi.isNotEmpty) {
      tarihIfadesi = ilkMesajTarihi;
    } else {
      // Şimdiki tarihten 3 ay önce gibi bir tahmin yap
      final threeMontshAgo = DateTime.now().subtract(const Duration(days: 90));
      tarihIfadesi = '${threeMontshAgo.day}.${threeMontshAgo.month}.${threeMontshAgo.year}';
    }
    
    return {
      'title': 'İlk Mesaj - Son Mesaj',
      'comment': 'İlk mesajınız $tarihIfadesi tarihinde atılmış görünüyor. Analiz için daha fazla mesaj verisi gerekli.'
    };
  }
  
  // Yorumdan tarih çıkarma yardımcı metodu
  String _extractDateFromComment(String comment) {
    final RegExp datePattern = RegExp(r'(\d{1,2})[\.\/](\d{1,2})[\.\/](\d{4})');
    final match = datePattern.firstMatch(comment);
    
    if (match != null) {
      return match.group(0) ?? '';
    }
    return '';
  }

  // Wrapped seçenek butonu
  Widget _buildWrappedOptionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }


  
  // Bilgi satırı oluşturma yardımcı metodu
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 