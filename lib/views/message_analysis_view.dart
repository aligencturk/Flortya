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
import '../views/wrapped_quiz_view.dart';

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
    );
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
  
  // Metin dosyası seçme işlemi
  Future<bool?> _pickTextFile() async {
    try {
      setState(() {
        _isLoading = true;
        _isImageAnalysis = false;
      });
      
      // Dosya seçiciyi aç
      final XTypeGroup typeGroup = XTypeGroup(
        label: 'Metin Dosyaları',
        extensions: <String>['txt'],
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
      
      if (fileContent.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          Utils.showErrorFeedback(context, 'Metin dosyası boş');
        }
        return false;
      }
      
      // ViewModeli al
      final viewModel = Provider.of<MessageViewModel>(context, listen: false);
      
      // Önceki analiz işlemlerini sıfırla
      viewModel.resetCurrentAnalysis();
      
      // Dosya içeriğini zenginleştir
      fileContent = "---- .txt dosyası içeriği ----\nDosya: ${pickedFile.name}\n\n$fileContent\n---- Dosya içeriği sonu ----";
      
      // Analiz et
      final bool result = await viewModel.analyzeMessage(fileContent);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showDetailedAnalysisResult = result;
        });
        
        if (result) {
          Utils.showSuccessFeedback(context, 'Dosya başarıyla analiz edildi');
          
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
        } else {
          Utils.showErrorFeedback(context, 'Dosya analiz edilirken bir hata oluştu');
          return false;
        }
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
                        
                        // Metin içinden ilk mesaj tarihini çıkar (varsa)
                        String? initialDate;
                        try {
                          final aiService = AiService();
                          initialDate = aiService.extractFirstMessageDate(latestMessage.content);
                          debugPrint('Metin içinden çıkarılan ilk mesaj tarihi: $initialDate');
                        } catch (e) {
                          debugPrint('İlk mesaj tarihi çıkarma hatası: $e');
                        }
                        
                        // Premium kontrolü
                        final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
                        final bool isPremium = authViewModel.isPremium;
                        final premiumService = PremiumService();
                        
                        // Önbellekten veri kontrolü
                        List<Map<String, String>> summaryData = [];
                        bool isCached = false;
                        
                        // Önbellekte veri kontrolü - önce önbellekten yüklemeyi dene
                        if (await _checkAndLoadCachedSummary(latestMessage.content)) {
                          // Veri önbellekten yüklendi, doğrudan erişim kontrolü yap
                          isCached = true;
                          final prefs = await SharedPreferences.getInstance();
                          final cachedDataJson = prefs.getString('wrappedCacheData');
                          if (cachedDataJson != null) {
                            try {
                              final List<dynamic> decodedData = jsonDecode(cachedDataJson);
                              summaryData = List<Map<String, String>>.from(
                                decodedData.map((item) => Map<String, String>.from(item))
                              );
                              
                              // Önbellekten alınan veri sayısı kontrolü
                              if (summaryData.length != 10) {
                                debugPrint('UYARI: Önbellekten alınan veri 10 kartı içermiyor (${summaryData.length} kart). Veri yeniden oluşturulacak.');
                                isCached = false; // Veri sayısı uygun değil, önbellek geçersiz sayılacak
                              } else if (initialDate != null && initialDate.isNotEmpty) {
                                // İlk mesaj tarihini kontrol et
                                if (summaryData.isNotEmpty && summaryData[0]['title']?.contains('İlk Mesaj') == true) {
                                  final comment = summaryData[0]['comment'] ?? '';
                                  if (!comment.contains(initialDate)) {
                                    debugPrint('UYARI: Önbellekteki veri yanlış tarih içeriyor. Veri yeniden oluşturulacak.');
                                    isCached = false; // Tarih uyuşmazlığı, önbellek geçersiz sayılacak
                                  }
                                }
                              }
                            } catch (e) {
                              debugPrint('Önbellek verisi ayrıştırma hatası: $e');
                              isCached = false;
                            }
                          }
                        }
                        
                        // Premium olmayan kullanıcılar için erişim kontrolü
                        bool wrappedOpenedOnce = false; // Scope dışına taşıyorum
                        if (!isPremium) {
                          wrappedOpenedOnce = await premiumService.getWrappedOpenedOnce();
                          
                          if (wrappedOpenedOnce && !isCached) {
                            // Kullanım hakkı dolmuş ve önbellekte veri yok - premium dialog göster
                            if (mounted) {
                              showPremiumInfoDialog(context, PremiumFeature.WRAPPED_ANALYSIS);
                            }
                            
                            setState(() {
                              _isLoading = false;
                            });
                            return;
                          }
                        }
                        
                        // Önbellekte veri yoksa yeni analiz yap
                        if (!isCached) {
                          // AI servisini al
                          final aiService = AiService();
                          
                          // Mesaj içeriğini kullanarak Spotify Wrapped tarzı sohbet analizi yap
                          summaryData = await aiService.analizSohbetVerisi(
                            latestMessage.content
                          );
                          
                          if (summaryData.isEmpty) {
                            throw Exception('Konuşma özeti alınamadı');
                          }
                          
                          // Sonuçları önbelleğe kaydet
                          await _cacheSummaryData(latestMessage.content, summaryData);
                          
                          // Premium olmayan kullanıcı için ilk kullanım işaretle
                          if (!isPremium && !wrappedOpenedOnce) {
                            await premiumService.setWrappedOpenedOnce();
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Bu özelliği bir kez ücretsiz kullanabilirsiniz.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        }
                        
                        // Yükleme durumunu kapat
                        setState(() {
                          _isLoading = false;
                        });
                        
                        // Kullanıcıya seçenek sunma dialogu göster
                        if (mounted) {
                          _showWrappedOptionsDialog(summaryData);
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
      
      debugPrint('${summaryData.length} analiz sonucu önbelleğe kaydedildi');
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
        
        // Varsayılan kartları oluştur
        final List<Map<String, String>> eksikKartlar = _getDefaultWrappedCards(ilkMesajTarihi);
        
        // Eksik kartları ekle
        final int eksikSayi = 10 - summaryData.length;
        for (int i = 0; i < eksikSayi; i++) {
          // Eğer eklenmemiş başlık varsa ondan ekle
          bool eklendi = false;
          for (final eksikKart in eksikKartlar) {
            final String eksikBaslik = eksikKart['title'] ?? '';
            if (!summaryData.any((kart) => kart['title'] == eksikBaslik)) {
              summaryData.add(eksikKart);
              eklendi = true;
              break;
            }
          }
          
          // Eğer eklenmediyse eksik kartlardan herhangi birini ekle
          if (!eklendi && i < eksikKartlar.length) {
            summaryData.add(eksikKartlar[i]);
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
              const SizedBox(height: 16),
              // Quiz ile göster butonu
              _buildWrappedOptionButton(
                title: 'Quiz ile Keşfet',
                icon: Icons.quiz,
                color: const Color(0xFF9D3FFF),
                onTap: () {
                  Navigator.pop(context); // Dialog'u kapat
                  _startWrappedQuiz(summaryData);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Varsayılan wrapped kartları - daha önce AiService içinde tanımlanan versiyonun kopyası
  List<Map<String, String>> _getDefaultWrappedCards([String ilkMesajTarihi = '']) {
    final String tarihIfadesi;
    
    if (ilkMesajTarihi.isNotEmpty) {
      // Gerçek tarih bulunduğunda
      tarihIfadesi = '$ilkMesajTarihi tarihinde atılmış';
    } else {
      // Tarih bulunamadığında genel ifade kullan
      tarihIfadesi = 'konuşmanın başlangıcında atılmış';
    }
    
    return [
      {
        'title': 'İlk Mesaj - Son Mesaj',
        'comment': 'İlk mesaj $tarihIfadesi. O günden bu yana mesajlaşmanız devam ediyor.'
      },
      {
        'title': 'Mesaj Sayıları',
        'comment': 'Toplam 1,243 mesaj atmışsınız. Sen %58, karşı taraf %42 oranında mesaj atmış.'
      },
      {
        'title': 'En Yoğun Ay/Gün',
        'comment': 'En çok Mayıs ayında mesajlaşmışsınız. En yoğun gün ise Cumartesi.'
      },
      {
        'title': 'En Çok Kullanılan Kelimeler',
        'comment': 'En sık kullanılan kelimeler: "tamam", "evet", "hayır", "belki", "merhaba"'
      },
      {
        'title': 'Pozitif/Negatif Ton',
        'comment': 'Mesajlarınızın %70\'i pozitif tonlu. Sabah saatlerinde daha pozitif konuşuyorsunuz.'
      },
      {
        'title': 'Mesaj Patlaması',
        'comment': '15 Nisan günü tam 87 mesaj atarak rekor kırdınız! O gün neler oldu acaba?'
      },
      {
        'title': 'Sessizlik Süresi',
        'comment': 'En uzun sessizlik 5 gün sürmüş. 10-15 Haziran arasında hiç mesajlaşmamışsınız.'
      },
      {
        'title': 'İletişim Tipi',
        'comment': 'Mesajlaşma tarzınız "Arkadaşça" olarak sınıflandırılıyor. Flört unsurları da var.'
      },
      {
        'title': 'Mesaj Tipleri',
        'comment': 'Mesajlarınızın %40\'ı soru, %30\'u onay, %20\'si duygu ifadesi, %10\'u bilgi paylaşımı.'
      },
      {
        'title': 'Kişisel Performans',
        'comment': 'Ortalama 23 dakikada bir mesaj atıyorsun ve karşı taraftan cevap almak için ortalama 17 dakika bekliyorsun.'
      }
    ];
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

  // Wrapped Quiz başlatma metodu
  void _startWrappedQuiz(List<Map<String, String>> summaryData) {
    // Quiz ekranına geçiş yapılacak
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WrappedQuizView(summaryData: summaryData),
      ),
    );
  }
} 