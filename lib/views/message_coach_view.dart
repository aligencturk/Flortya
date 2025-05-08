import 'dart:async';
import 'dart:io';
import 'dart:ui'; // ImageFilter için eklendi

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:provider/provider.dart' as provider;
import '../controllers/message_coach_controller.dart';
import '../controllers/message_coach_visual_controller.dart';
import '../models/message_coach_analysis.dart';
import '../models/message_coach_visual_analysis.dart';
import '../utils/utils.dart';
import '../utils/loading_indicator.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../services/premium_service.dart';

class MessageCoachView extends ConsumerStatefulWidget {
  const MessageCoachView({super.key});

  @override
  ConsumerState<MessageCoachView> createState() => _MessageCoachViewState();
}

class _MessageCoachViewState extends ConsumerState<MessageCoachView> {
  final TextEditingController _textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _aciklamaController = TextEditingController();
  final PremiumService _premiumService = PremiumService();
  
  bool _klavyeAcik = false;
  bool _gosterildiMi = false;
  bool _textAreaActive = false;
  bool _yuklemeDurumu = false;
  String _hataMesaji = '';
  late KeyboardVisibilityController _keyboardVisibilityController;
  late StreamSubscription<bool> _keyboardSubscription;

  @override
  void initState() {
    super.initState();
    
    // Pencere değişikliklerini dinlemek için ekrana odaklanılınca veriyi yeniden yüklemek için
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Controller'ı sıfırla
      final controller = provider.Provider.of<MessageCoachController>(context, listen: false);
      controller.analizSonuclariniSifirla();
      
      // Text editing controller'ları ayarla
      _textEditingController.addListener(() {
        setState(() {
          _textAreaActive = _textEditingController.text.isNotEmpty;
        });
      });
      
      // Kullanıcı ID'sini controller'lara ayarla
      final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
      
      if (authViewModel.currentUser != null) {
        controller.setCurrentUserId(authViewModel.currentUser!.uid, isPremium: authViewModel.isPremium);
        ref.read(mesajKocuGorselKontrolProvider.notifier).kullaniciIdAyarla(authViewModel.currentUser!.uid);
        
        // Görsel analiz durumunu da sıfırla
        ref.read(mesajKocuGorselKontrolProvider.notifier).durumSifirla();
      }
      
      // Diğer başlangıç işlemleri
      _aciklamaController.text = "Ne yazmalıyım?";
      
      // Klavye görünürlük kontrolcüsünü başlat
      _keyboardVisibilityController = KeyboardVisibilityController();
      _keyboardSubscription = _keyboardVisibilityController.onChange.listen((bool visible) {
        if (visible) {
          // Klavye görününce otomatik olarak metin alanına odaklan
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _scrollController.dispose();
    _keyboardSubscription.cancel();
    super.dispose();
  }

  // Kopyala butonunu işle
  void _metniKopyala(String metin) {
    Clipboard.setData(ClipboardData(text: metin)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analiz sonucu kopyalandı'),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }
  
  // Görsel seçme işlemi
  Future<void> _gorselSec() async {
    try {
      final XTypeGroup typeGroup = XTypeGroup(
        label: 'Resimler',
        extensions: ['jpg', 'jpeg', 'png'],
        mimeTypes: ['image/jpeg', 'image/png'],
        uniformTypeIdentifiers: ['public.image'],
      );
      
      final XFile? file = await openFile(
        acceptedTypeGroups: [typeGroup],
      );
      
      if (file != null) {
        final gorselDosya = File(file.path);
        // Hem controller'a hem de Riverpod provider'a görsel dosyasını ayarla
        ref.read(mesajKocuGorselKontrolProvider.notifier).gorselDosyasiAyarla(gorselDosya);
        
        // Controller'a da aynı görsel dosyasını ayarla
        final controller = provider.Provider.of<MessageCoachController>(context, listen: false);
        controller.gorselBelirle(gorselDosya);
      }
    } catch (e) {
      Utils.showErrorFeedback(context, 'Görsel seçilirken hata oluştu: $e');
    }
  }

  // Metni analiz et
  Future<void> _metniAnalizEt() async {
    final String text = _textEditingController.text.trim();
    
    // Metin boş mu kontrol et
    if (text.isEmpty) {
      Utils.showToast(context, 'Lütfen analiz etmek için bir metin girin');
      return;
    }
    
    // Controller referansını al - önce controller'ı alalım
    final controller = provider.Provider.of<MessageCoachController>(context, listen: false);
    
    // Premium kontrolü
    final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    // Önce yükleme durumunu false yap
    setState(() {
      _yuklemeDurumu = false;
    });
    
    if (!isPremium) {
      // İlk kullanım veya reklam izleme kontrolü - controller.metinAciklamasiIleAnalizeEt henüz ÇAĞRILMASIN
      bool isFirstTime = await controller.isPremiumOrFirstTimeUse();
      
      if (!isFirstTime) {
        // Reklam izleme durumunu kontrol et
        bool adViewed = await controller.isMessageCoachAdViewed();
        
        if (!adViewed) {
          // Reklam gösterme diyaloğunu göster
          bool shouldShowAd = await _showAdRequiredDialog(
            title: 'Mesaj Analizi',
            message: 'Mesaj koçu özelliğini kullanmak için kısa bir reklam izlemeniz gerekiyor.',
          );
          
          if (shouldShowAd) {
            // Reklam göster
            await _showAdSimulation();
            
            // Reklam izlendiğini işaretle
            await controller.markMessageCoachAdViewed();
            
            // Şimdi analizi başlat
            await _metniAnalizEtDevam(text);
          }
          return; // Reklam izlenmediyse işlemi sonlandır
        }
      }
    }
    
    // Premium kullanıcı veya ilk kullanım veya reklam izlenmişse direkt analiz et
    await _metniAnalizEtDevam(text);
  }
  
  // Metin analizi devam metodu - reklam kontrolü geçildikten sonra
  Future<void> _metniAnalizEtDevam(String text) async {
    // Yüklemeyi başlat
    setState(() {
      _yuklemeDurumu = true;
    });
    
    // Controller referansını al
    final controller = provider.Provider.of<MessageCoachController>(context, listen: false);
    
    try {
      // Analiz işlemini başlat
      bool sonuc = await controller.metinAciklamasiIleAnalizeEt(text);
      
      if (!sonuc) {
        // Analiz başarısız olduysa hata göster
        Utils.showErrorFeedback(context, 'Analiz yapılamadı, lütfen daha sonra tekrar deneyin');
      }
      
      // Yüklemeyi bitir
      setState(() {
        _yuklemeDurumu = false;
      });
      
    } catch (e) {
      // Hata durumu
      setState(() {
        _yuklemeDurumu = false;
      });
      
      Utils.showErrorFeedback(context, 'Analiz sırasında bir hata oluştu: $e');
    }
  }

  // Görsel analizi
  Future<void> _gorselAnalizi() async {
    // Görsel seçme işlemini başlat
    await _gorselSec();
    
    // Premium kontrolü olmadan direk görsel seçimini başlatıyoruz
    // Reklam gösterimi ve premium kontrolü gorselAnalizeEt metodu içerisinde yapılacak
  }

  // Hazır mesaj şablonunu kullan
  void _hazirSablonuKullan(String sablonMetni) {
    // Premium kontrolü
    final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    if (!isPremium) {
      Utils.showToast(
        context, 
        'Tüm hazır mesaj şablonlarına erişmek için Premium üyelik gerekiyor'
      );
    }
    
    // Şablonu metin alanına ekle
    _textEditingController.text = sablonMetni;
    
    // ... existing code ...
  }

  // İletişim tavsiyelerini göster
  void _iletisimTavsiyeleriniGoster() {
    // Premium kontrolü
    final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    if (!isPremium) {
      Utils.showToast(
        context, 
        'İletişim tavsiyelerine reklamsız erişmek için Premium üyelik gerekiyor'
      );
    }
    
    // Tavsiyeleri göster
    // ... existing code ...
  }

  // Olumsuz mesaj uyarısı ve alternatif önerisi
  void _olumsuzMesajUyarisiGoster(String metin) {
    // Premium kontrolü
    final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    if (!isPremium) {
      Utils.showToast(
        context, 
        'Bu özelliği sınırsız kullanmak için Premium üyelik gerekiyor'
      );
    }
    
    // Uyarı ve alternatif mesaj önerisi göster
    // ... existing code ...
  }

  // Görsel analiz sonucunu MessageCoachAnalysis nesnesine dönüştürme yardımcı metodu
  MessageCoachAnalysis _gorselAnalizdenAnalizeSonucuDonustur(MessageCoachVisualAnalysis gorselAnaliz) {
    return MessageCoachAnalysis(
      analiz: gorselAnaliz.konumDegerlendirmesi ?? "Görsel analiz",
      oneriler: gorselAnaliz.alternativeMessages,
      etki: {'Görsel': 100},
      sohbetGenelHavasi: "Görsel Analiz",
      sonMesajTonu: "Görsel Analiz",
      sonMesajEtkisi: {'Görsel': 100},
      direktYorum: gorselAnaliz.konumDegerlendirmesi,
      cevapOnerileri: gorselAnaliz.alternativeMessages,
      olumluCevapTahmini: gorselAnaliz.partnerResponses.isNotEmpty ? gorselAnaliz.partnerResponses[0] : null,
      olumsuzCevapTahmini: gorselAnaliz.partnerResponses.length > 1 ? gorselAnaliz.partnerResponses[1] : null,
    );
  }
  
  // Kullanıcının açıklamasına göre olası yanıt senaryolarını gösterip göstermeme kararını verir
  bool _yanitSenaryolariGosterilmeli(String aciklama) {
    // Küçük harfe çevir ve boşlukları temizle
    final String temizAciklama = aciklama.toLowerCase().trim();
    
    // Cevap/yanıt/tepki ile ilgili anahtar kelimeler
    final List<String> anahtarKelimeler = [
      'cevap', 'yanit', 'tepki', 'karşilik', 'dönüş', 
      'ne der', 'ne söyler', 'nasil cevap', 'nasil yanit', 
      'ne cevap', 'ne yanit', 'ne tepki', 'ne düşünür'
    ];
    
    // Anahtar kelimeleri kontrol et
    for (final String kelime in anahtarKelimeler) {
      if (temizAciklama.contains(kelime)) {
        return true;
      }
    }
    
    return false;
  }

  // Cevap önerileri yerine alternatif öneriler (şu an mockup)
  void _alternativeMessagesGoster(MessageCoachAnalysis analiz) async {
    // Alternatif önerileri gösterebilir miyiz?
    final controller = provider.Provider.of<MessageCoachController>(context, listen: false);
    final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    // Premium kontrolü
    bool canShow = await controller.canShowAlternativeSuggestions();
    
    if (!canShow && !isPremium) {
      // Reklam gösterme diyaloğunu göster
      bool shouldUnlock = await _showAdRequiredDialog(
        title: 'Alternatif Öneriler',
        message: 'Alternatif mesaj önerilerini görmek için kısa bir reklam izlemeniz gerekiyor.',
      );
      
      if (shouldUnlock) {
        // Reklam göster
        await _showAdSimulation();
        
        // Kilidi aç
        await controller.unlockAlternativeSuggestions();
        
        // Şimdi gösterebiliriz
        canShow = true;
      } else {
        // Kullanıcı reklam izlemek istemedi
        return;
      }
    }
    
    if (canShow) {
      // Alternatif mesajları göster
      final alternatifler = analiz.cevapOnerileri ?? [];
      
      if (alternatifler.isEmpty) {
        Utils.showToast(context, 'Alternatif mesaj önerisi bulunamadı');
        return;
      }
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF2D1957),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Alternatif Mesaj Önerileri',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: alternatifler.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: const Color(0xFF4A2A80),
                        child: ListTile(
                          title: Text(
                            alternatifler[index],
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy, color: Colors.white),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: alternatifler[index]));
                              Utils.showToast(context, 'Mesaj kopyalandı');
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }
  
  // Yanıt senaryoları gösterme - kullanıcı "ne cevap verir?" tarzı sorular sorduğunda
  void _yanitSenaryolariniGoster(MessageCoachAnalysis analiz, {required bool olumluCevap}) async {
    // Yanıt senaryolarını gösterebilir miyiz?
    final controller = provider.Provider.of<MessageCoachController>(context, listen: false);
    final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    bool canShow;
    if (olumluCevap) {
      canShow = await controller.canShowPositiveResponseScenario();
    } else {
      canShow = await controller.canShowNegativeResponseScenario();
    }
    
    if (!canShow && !isPremium) {
      // Reklam gösterme diyaloğunu göster
      bool shouldUnlock = await _showAdRequiredDialog(
        title: 'Yanıt Senaryosu',
        message: olumluCevap
            ? 'Olumlu yanıt senaryosunu görmek için kısa bir reklam izlemeniz gerekiyor.'
            : 'Olumsuz yanıt senaryosunu görmek için kısa bir reklam izlemeniz gerekiyor.',
      );
      
      if (shouldUnlock) {
        // Reklam göster
        await _showAdSimulation();
        
        // Kilidi aç
        await controller.unlockResponseScenarios();
        
        // Gösterilecek yanıtı işaretle
        if (olumluCevap) {
          controller.showPositiveResponseScenario();
        } else {
          controller.showNegativeResponseScenario();
        }
        
        // Şimdi gösterebiliriz
        canShow = true;
      } else {
        // Kullanıcı reklam izlemek istemedi
        return;
      }
    }
    
    if (canShow) {
      // Yanıt senaryosunu göster
      String? yanitSenaryosu;
      
      if (olumluCevap) {
        yanitSenaryosu = analiz.olumluCevapTahmini;
      } else {
        yanitSenaryosu = analiz.olumsuzCevapTahmini;
      }
      
      if (yanitSenaryosu == null || yanitSenaryosu.isEmpty) {
        Utils.showToast(context, 'Bu senaryo için yanıt tahmini bulunamadı');
        return;
      }
      
      // Artık bu noktada yanitSenaryosu String olarak kesin bir şekilde var
      final String sonYanitSenaryosu = yanitSenaryosu;
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF2D1957),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    olumluCevap ? 'Olumlu Yanıt Senaryosu' : 'Olumsuz Yanıt Senaryosu',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Card(
                  color: const Color(0xFF4A2A80),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          olumluCevap ? 'Karşı taraf şöyle cevap verebilir:' : 'Olumsuz durumda karşı taraf şöyle cevap verebilir:',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          sonYanitSenaryosu,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: sonYanitSenaryosu));
                    Utils.showToast(context, 'Yanıt senaryosu kopyalandı');
                  },
                  icon: const Icon(Icons.copy, color: Colors.white),
                  label: const Text('Kopyala', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A2A80),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }
  
  // Reklam gösterme simülasyonu
  Future<void> _showAdSimulation() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.of(context).pop();
        });
        
        return AlertDialog(
          backgroundColor: const Color(0xFF2D1957),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF9D3FFF),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reklam yükleniyor...',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                '(Bu bir simülasyondur)',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Reklam gerektiren işlem için diyalog göster
  Future<bool> _showAdRequiredDialog({required String title, required String message}) async {
    bool result = false;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D1957),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
            onPressed: () {
              Navigator.pop(context);
              result = false;
            },
              child: const Text(
              'İptal', 
              style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D3FFF),
              ),
            onPressed: () {
              Navigator.pop(context);
              result = true;
            },
              child: const Text(
                'Reklam İzle',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
      ),
    );
    
    return result;
  }

  // Mesaj analiz etme işlemini başlat
  Future<void> _mesajAnalizeEt() async {
    final controller = provider.Provider.of<MessageCoachController>(context, listen: false);
    
    if (controller.analizTamamlandi) {
      // Eğer analiz tamamlanmışsa, yeni analiz için formu sıfırla
      controller.analizSonuclariniSifirla();
      _textEditingController.clear();
      return;
    }
    
    final gorselDurumu = ref.read(mesajKocuGorselKontrolProvider);
    
    if (controller.gorselModu) {
      // Premium kontrolü
      final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
      final isPremium = authViewModel.isPremium;
        
      // Görsel durumunu güncelle (premium bilgisi ile)
      ref.read(mesajKocuGorselKontrolProvider.notifier).premiumDurumunuGuncelle(isPremium);
      
      // Görsel var mı kontrol et
      if (gorselDurumu.secilenGorsel == null) {
        Utils.showToast(context, 'Lütfen önce bir sohbet görüntüsü seçin');
        return;
      }
      
      // Görsel mod için reklam kontrolü
      bool canShowVisualMode = await ref.read(mesajKocuGorselKontrolProvider.notifier).gorselModIcinReklamIzlenmismi();
      
      if (!canShowVisualMode && !isPremium) {
        // Reklam gösterme diyaloğunu göster
        bool shouldShowAd = await _showAdRequiredDialog(
          title: 'Görsel Mod',
          message: 'Görsel modu kullanmak için kısa bir reklam izlemeniz gerekiyor. Bu özelliği sadece 1 kez ücretsiz kullanabilirsiniz, sonrasında Premium üyelik gerekecektir.',
        );
        
        if (shouldShowAd) {
          // Reklam göster
          await _showAdSimulation();
          
          // Görsel mod reklam izlendiğini işaretle
          await ref.read(mesajKocuGorselKontrolProvider.notifier).gorselModReklamIzlendi();
          
          // Şimdi analiz işlemini başlat
          await ref.read(mesajKocuGorselKontrolProvider.notifier).gorselAnalizeEt(_aciklamaController.text);
        }
      } else {
        // Reklam gerekmiyor, direkt analiz et
        await ref.read(mesajKocuGorselKontrolProvider.notifier).gorselAnalizeEt(_aciklamaController.text);
      }
    } else {
      // Metin modu için analiz
      await _metniAnalizEt();
    }
  }

  // Görsel mod için alternatif mesaj önerilerini göster
  Future<void> _gorselModAlternativeMessagesGoster(MessageCoachVisualAnalysis analiz) async {
    // Premium durumunu al
    final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    // Alternatif mesajları gösterilebilir mi kontrol et
    bool canShow = await ref.read(mesajKocuGorselKontrolProvider.notifier).alternativeMessagesKilidiAcikmi();
    
    if (!canShow && !isPremium) {
      // Reklam gösterme diyaloğunu göster
      bool shouldUnlock = await _showAdRequiredDialog(
        title: 'Alternatif Öneriler',
        message: 'Alternatif mesaj önerilerini görmek için kısa bir reklam izlemeniz gerekiyor. Her görüntüleme için reklam izlemeniz gerekecektir.',
      );
      
      if (shouldUnlock) {
        // Reklam göster
        await _showAdSimulation();
        
        // Kilidi aç
        await ref.read(mesajKocuGorselKontrolProvider.notifier).alternativeMessagesKilidiniAc();
        
        // Şimdi gösterebiliriz
        canShow = true;
      } else {
        // Kullanıcı reklam izlemek istemedi
        return;
      }
    }
    
    if (canShow) {
      // Alternatif mesajları göster
      final alternatifler = analiz.alternativeMessages;
      
      if (alternatifler.isEmpty) {
        Utils.showToast(context, 'Alternatif mesaj önerisi bulunamadı');
        return;
      }
      
      showModalBottomSheet(
      context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF2D1957),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Alternatif Mesaj Önerileri',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: alternatifler.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: const Color(0xFF4A2A80),
                        child: ListTile(
                          title: Text(
                            alternatifler[index],
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy, color: Colors.white),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: alternatifler[index]));
                              Utils.showToast(context, 'Mesaj kopyalandı');
                            },
                          ),
                        ),
                      );
                    },
                  ),
              ),
            ],
          ),
        );
      },
    );
    }
  }
  
  // Görsel mod için yanıt senaryolarını göster
  Future<void> _gorselModYanitSenaryolariniGoster(MessageCoachVisualAnalysis analiz, {required bool olumluCevap}) async {
    // Premium durumunu al
    final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    // Yanıt senaryosu gösterebilir miyiz?
    bool canShow;
    if (olumluCevap) {
      canShow = await ref.read(mesajKocuGorselKontrolProvider.notifier).olumluSenaryoKilidiAcikmi();
    } else {
      canShow = await ref.read(mesajKocuGorselKontrolProvider.notifier).olumsuzSenaryoKilidiAcikmi();
    }
    
    if (!canShow && !isPremium) {
      // Reklam gösterme diyaloğunu göster
      bool shouldUnlock = await _showAdRequiredDialog(
        title: 'Yanıt Senaryosu',
        message: olumluCevap
            ? 'Olumlu yanıt senaryosunu görmek için kısa bir reklam izlemeniz gerekiyor. Bu özelliği sadece 1 kez reklam izleyerek açabilirsiniz.'
            : 'Olumsuz yanıt senaryosunu görmek için kısa bir reklam izlemeniz gerekiyor. Bu özelliği sadece 1 kez reklam izleyerek açabilirsiniz.',
      );
      
      if (shouldUnlock) {
      // Reklam göster
      await _showAdSimulation();
      
        // Kilidi aç
        if (olumluCevap) {
          await ref.read(mesajKocuGorselKontrolProvider.notifier).olumluSenaryoKilidiniAc();
        } else {
          await ref.read(mesajKocuGorselKontrolProvider.notifier).olumsuzSenaryoKilidiniAc();
        }
        
        // Şimdi gösterebiliriz
        canShow = true;
      } else {
    // Kullanıcı reklam izlemek istemedi
        return;
      }
    }
    
    if (canShow) {
      // Yanıt senaryosunu göster
      String? yanitSenaryosu;
      List<String> senaryolar = analiz.partnerResponses;
      
      if (senaryolar.isEmpty) {
        Utils.showToast(context, 'Bu senaryo için yanıt tahmini bulunamadı');
        return;
      }
      
      if (olumluCevap && senaryolar.isNotEmpty) {
        yanitSenaryosu = senaryolar[0];
      } else if (!olumluCevap && senaryolar.length > 1) {
        yanitSenaryosu = senaryolar[1];
        } else {
        Utils.showToast(context, 'Bu senaryo için yanıt tahmini bulunamadı');
          return;
        }
        
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF2D1957),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    olumluCevap ? 'Olumlu Yanıt Senaryosu' : 'Olumsuz Yanıt Senaryosu',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Card(
                  color: const Color(0xFF4A2A80),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          olumluCevap ? 'Karşı taraf şöyle cevap verebilir:' : 'Olumsuz durumda karşı taraf şöyle cevap verebilir:',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          yanitSenaryosu ?? "",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: yanitSenaryosu!));
                    Utils.showToast(context, 'Yanıt senaryosu kopyalandı');
                  },
                  icon: const Icon(Icons.copy, color: Colors.white),
                  label: const Text('Kopyala', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A2A80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  // Metin analiz sonuçlarını gösteren widget
  Widget _analizSonuclariniGoster(MessageCoachAnalysis analiz) {
    // Analiz sonucu görsel modundan mı geldi?
    final controller = provider.Provider.of<MessageCoachController>(context, listen: false);
    final bool isVisualAnalysis = controller.gorselModu;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Görsel analizi ise görseli göster
          if (isVisualAnalysis && controller.gorselDosya != null)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF9D3FFF), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  controller.gorselDosya!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
          const SizedBox(height: 16),
          
          // Analiz başlığı
          const Text(
            "MESAJ KOÇU ANALİZİ",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Sohbet genel havası
          if (analiz.sohbetGenelHavasi != null)
            AnalizBaslikVeIcerik(
              baslik: "Sohbet Genel Havası",
              icerik: analiz.sohbetGenelHavasi!,
            ),
            
          const SizedBox(height: 16),
          
          // Direkt yorum
          if (analiz.direktYorum != null)
            AnalizBaslikVeIcerik(
              baslik: "Değerlendirme",
              icerik: analiz.direktYorum!,
            ),
            
          const SizedBox(height: 16),
          
          // Cevap önerileri
          if (analiz.cevapOnerileri != null && analiz.cevapOnerileri!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Cevap Önerileri",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FutureBuilder<bool>(
                  future: controller.canShowMessageCoachTexts(),
                  builder: (context, snapshot) {
                    final bool canShow = snapshot.data ?? false;
                    final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
                    final isPremium = authViewModel.isPremium;
                    
                    // Premium kullanıcılar için tüm önerileri göster
                    if (isPremium) {
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: analiz.cevapOnerileri!.length,
                        itemBuilder: (context, index) {
                          return CevapOnerisiItem(
                            oneri: analiz.cevapOnerileri![index],
                          );
                        },
                      );
                    } else {
                      // Premium olmayan kullanıcılar için sadece 1 öneri açık, diğerleri ayrı ayrı blurlu
                      return Column(
                        children: [
                          // İlk öneri her zaman görünür
                          if (analiz.cevapOnerileri!.isNotEmpty)
                            CevapOnerisiItem(
                              oneri: analiz.cevapOnerileri![0],
                            ),
                          
                          // Diğer öneriler blurlu ve kilitli - her biri için ayrı kontrol
                          ...analiz.cevapOnerileri!.asMap().entries.where((entry) => entry.key > 0).map((entry) {
                            final int index = entry.key;
                            final String oneri = entry.value;
                            return FutureBuilder<bool>(
                              future: controller.isMessageCoachTextItemUnlocked(index),
                              builder: (context, snapshot) {
                                final bool isUnlocked = snapshot.data ?? false;
                                
                                if (isUnlocked) {
                                  // Kilidi açılmış öneri
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: CevapOnerisiItem(
                                      oneri: oneri,
                                    ),
                                  );
                                } else {
                                  // Kilitli ve blurlu öneri
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: BlurredContentWithLock(
                                      title: "Öneri ${index + 1}",
                                      content: oneri,
                                      isLocked: true,
                                      backgroundColor: const Color(0xFF4A2A80),
                                      onTap: () async {
                                        // Reklam gösterme diyaloğunu göster
                                        bool shouldUnlock = await _showAdRequiredDialog(
                                          title: 'Öneri Kilidi',
                                          message: 'Bu öneriyi görmek için kısa bir reklam izlemeniz gerekiyor.',
                                        );
                                        
                                        if (shouldUnlock) {
                                          // Reklam göster
                                          await _showAdSimulation();
                                          
                                          // Sadece bu önerinin kilidini aç
                                          await controller.unlockMessageCoachTextItem(index);
                                          
                                          // UI'ı yeniden oluştur
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  );
                                }
                              },
                            );
                          }).toList(),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
            
          const SizedBox(height: 16),
          
          // Olası yanıt senaryoları - direkt içerikleri göster
          if ((analiz.olumluCevapTahmini != null && analiz.olumluCevapTahmini!.isNotEmpty) ||
              (analiz.olumsuzCevapTahmini != null && analiz.olumsuzCevapTahmini!.isNotEmpty))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Olası Yanıt Senaryoları",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Olumlu senaryo
                if (analiz.olumluCevapTahmini != null && analiz.olumluCevapTahmini!.isNotEmpty)
                  FutureBuilder<bool>(
                    future: controller.isPositiveResponseUnlocked(),
                    builder: (context, snapshot) {
                      final bool canShow = snapshot.data ?? false;
                      final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
                      final isPremium = authViewModel.isPremium;
                      final isLocked = !canShow && !isPremium;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(
                            minHeight: 100, // Minimum yükseklik ayarı
                          ),
                          child: BlurredContentWithLock(
                            title: "Olumlu Yanıt Senaryosu",
                            content: analiz.olumluCevapTahmini!,
                            isLocked: isLocked,
                            backgroundColor: Colors.green.shade800,
                            onTap: () async {
                              // Reklam göster ve senaryoyu aç
                              bool shouldUnlock = await _showAdRequiredDialog(
                                title: 'Olumlu Yanıt Senaryosu',
                                message: 'Olumlu yanıt senaryosunu görmek için kısa bir reklam izlemeniz gerekiyor.',
                              );
                              
                              if (shouldUnlock) {
                                // Reklam göster
                                await _showAdSimulation();
                                
                                // Sadece olumlu yanıt senaryosunun kilidini aç
                                await controller.unlockPositiveResponse();
                                
                                setState(() {}); // Arayüzü yenile
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  
                // Olumsuz senaryo
                if (analiz.olumsuzCevapTahmini != null && analiz.olumsuzCevapTahmini!.isNotEmpty)
                  FutureBuilder<bool>(
                    future: controller.isNegativeResponseUnlocked(),
                    builder: (context, snapshot) {
                      final bool canShow = snapshot.data ?? false;
                      final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
                      final isPremium = authViewModel.isPremium;
                      final isLocked = !canShow && !isPremium;
                      
                      return Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(
                          minHeight: 100, // Minimum yükseklik ayarı
                        ),
                        child: BlurredContentWithLock(
                          title: "Olumsuz Yanıt Senaryosu",
                          content: analiz.olumsuzCevapTahmini!,
                          isLocked: isLocked,
                          backgroundColor: Colors.red.shade800,
                          onTap: () async {
                            // Reklam göster ve senaryoyu aç
                            bool shouldUnlock = await _showAdRequiredDialog(
                              title: 'Olumsuz Yanıt Senaryosu',
                              message: 'Olumsuz yanıt senaryosunu görmek için kısa bir reklam izlemeniz gerekiyor.',
                            );
                            
                            if (shouldUnlock) {
                              // Reklam göster
                              await _showAdSimulation();
                              
                              // Sadece olumsuz yanıt senaryosunun kilidini aç
                              await controller.unlockNegativeResponse();
                              
                              setState(() {}); // Arayüzü yenile
                            }
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
  
  // Şimdi görsel analiz sonuçlarını gösteren metodu güncelleyelim
  Widget _gorselAnalizSonuclariniGoster(MessageCoachVisualAnalysis analiz) {
    final konumDegerlendirmesi = analiz.konumDegerlendirmesi ?? "Görsel analiz edilemedi";
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Görsel dosyasını göster
          if (ref.read(mesajKocuGorselKontrolProvider).secilenGorsel != null)
              Container(
              height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF9D3FFF), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  ref.read(mesajKocuGorselKontrolProvider).secilenGorsel!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
          const SizedBox(height: 16),
          
          // Analiz başlığı
          const Text(
            "GÖRSEL ANALİZ SONUCU",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Genel değerlendirme
          AnalizBaslikVeIcerik(
            baslik: "Değerlendirme",
            icerik: konumDegerlendirmesi,
          ),
          
          const SizedBox(height: 16),
          
          // Alternatif mesaj önerileri
          if (analiz.alternativeMessages.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Cevap Önerileri",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    TextButton.icon(
                          onPressed: () {
                        _gorselModAlternativeMessagesGoster(analiz);
                      },
                      icon: const Icon(Icons.more_horiz, color: Colors.white),
                      label: const Text("Tümünü Gör", style: TextStyle(color: Colors.white)),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF4A2A80),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: analiz.alternativeMessages.length > 2 ? 2 : analiz.alternativeMessages.length,
                  itemBuilder: (context, index) {
                    return CevapOnerisiItem(
                      oneri: analiz.alternativeMessages[index],
                    );
                  },
                ),
              ],
            ),
            
          const SizedBox(height: 16),
          
          // Olası yanıt senaryoları - direkt içerikleri göster
          if (analiz.partnerResponses.isNotEmpty) 
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Olası Yanıt Senaryoları",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Olumlu senaryo
                if (analiz.partnerResponses.isNotEmpty)
                  FutureBuilder<bool>(
                    future: ref.read(mesajKocuGorselKontrolProvider.notifier).olumluSenaryoKilidiAcikmi(),
                    builder: (context, snapshot) {
                      final bool canShow = snapshot.data ?? false;
                      final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
                      final isPremium = authViewModel.isPremium;
                      final isLocked = !canShow && !isPremium;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(
                            minHeight: 100, // Minimum yükseklik ayarı
                          ),
                          child: BlurredContentWithLock(
                            title: "Olumlu Yanıt Senaryosu",
                            content: analiz.partnerResponses[0],
                            isLocked: isLocked,
                            backgroundColor: Colors.green.shade800,
                            onTap: () async {
                              // Reklam göster ve senaryoyu aç
                              bool shouldUnlock = await _showAdRequiredDialog(
                                title: 'Olumlu Yanıt Senaryosu',
                                message: 'Olumlu yanıt senaryosunu görmek için kısa bir reklam izlemeniz gerekiyor.',
                              );
                              
                              if (shouldUnlock) {
                                // Reklam göster
                                await _showAdSimulation();
                                
                                // Sadece olumlu yanıt senaryosunun kilidini aç
                                await ref.read(mesajKocuGorselKontrolProvider.notifier).olumluSenaryoKilidiniAc();
                                
                                setState(() {}); // Arayüzü yenile
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  
                // Olumsuz senaryo
                if (analiz.partnerResponses.length > 1)
                  FutureBuilder<bool>(
                    future: ref.read(mesajKocuGorselKontrolProvider.notifier).olumsuzSenaryoKilidiAcikmi(),
                    builder: (context, snapshot) {
                      final bool canShow = snapshot.data ?? false;
                      final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
                      final isPremium = authViewModel.isPremium;
                      final isLocked = !canShow && !isPremium;
                      
                      return Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(
                          minHeight: 100, // Minimum yükseklik ayarı
                        ),
                        child: BlurredContentWithLock(
                          title: "Olumsuz Yanıt Senaryosu",
                          content: analiz.partnerResponses[1],
                          isLocked: isLocked,
                          backgroundColor: Colors.red.shade800,
                          onTap: () async {
                            // Reklam göster ve senaryoyu aç
                            bool shouldUnlock = await _showAdRequiredDialog(
                              title: 'Olumsuz Yanıt Senaryosu',
                              message: 'Olumsuz yanıt senaryosunu görmek için kısa bir reklam izlemeniz gerekiyor.',
                            );
                            
                            if (shouldUnlock) {
                              // Reklam göster
                              await _showAdSimulation();
                              
                              // Sadece olumsuz yanıt senaryosunun kilidini aç
                              await ref.read(mesajKocuGorselKontrolProvider.notifier).olumsuzSenaryoKilidiniAc();
                              
                              setState(() {}); // Arayüzü yenile
                            }
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // Görsel moduna geçiş işlemi
  Future<void> _gorselModunuDegistir() async {
    final controller = provider.Provider.of<MessageCoachController>(context, listen: false);
    final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
    final isPremium = authViewModel.isPremium;
    
    // Metin modundan görsel moduna geçiş
    if (!controller.gorselModu) {
      // Premium değilse ve daha önce reklam izlenmediyse reklam göster
      bool isFirstUseCompleted = await _premiumService.isVisualModeFirstUseCompleted();
      
      // İlk kullanım tamamlanmışsa ve premium değilse, görsel moda geçişi engelle
      if (isFirstUseCompleted && !isPremium) {
        Utils.showToast(
          context, 
          'Görsel modu sadece premium üyeler kullanabilir. İlk kullanım hakkınızı kullanmışsınız.'
        );
        return;
      }
      
      bool canShowVisualMode = await ref.read(mesajKocuGorselKontrolProvider.notifier).gorselModIcinReklamIzlenmismi();
      
      if (!canShowVisualMode && !isPremium) {
        // Reklam gösterme diyaloğunu göster
        bool shouldShowAd = await _showAdRequiredDialog(
          title: 'Görsel Mod',
          message: 'Görsel modu kullanmak için kısa bir reklam izlemeniz gerekiyor. Bu özelliği sadece 1 kez ücretsiz kullanabilirsiniz, sonrasında Premium üyelik gerekecektir.',
        );
        
        if (shouldShowAd) {
          // Reklam göster
          await _showAdSimulation();
          
          // Görsel mod reklam izlendiğini işaretle
          await ref.read(mesajKocuGorselKontrolProvider.notifier).gorselModReklamIzlendi();
          
          // Görsel moduna geç
          controller.gorselModunuDegistir();
        }
      } else {
        // Premium veya reklam zaten izlenmişse direkt geçiş yap
        controller.gorselModunuDegistir();
      }
    } else {
      // Görsel modundan metin moduna geçiş - her zaman izin verilir
      controller.gorselModunuDegistir();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = provider.Provider.of<MessageCoachController>(context);
    final gorselDurumu = ref.watch(mesajKocuGorselKontrolProvider);
    final theme = Theme.of(context);
    final bool gorselModu = controller.gorselModu;
    
    // Hem normal controller'ın hem de Riverpod provider'ın yükleme ve analiz durumlarını kontrol et
    final bool isLoading = controller.isLoading || gorselDurumu.yukleniyor;
    final bool analizTamamlandi = controller.analizTamamlandi || gorselDurumu.analiz != null;
    
    // Uygulama renkleri
    final Color primaryColor = const Color(0xFF9D3FFF); 
    final Color darkPurple = const Color(0xFF2D1957);
    final Color lightPurple = const Color(0xFF4A2A80);
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A2A80), Color(0xFF2D1957)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Text(
                      'Merhaba, ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                        fontSize: 18,
                      ),
                    ),
                    const Text(
                      'Ali Talip Gençtürk',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.help_outline,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        // Yardım menüsü
                      },
                    ),
                  ],
                ),
              ),
              
              // Mod Değiştirme Butonu - Yeni konumda
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _gorselModunuDegistir,
                    icon: Icon(
                      gorselModu ? Icons.text_fields : Icons.image_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    label: Text(
                      gorselModu ? "Metin Modu" : "Görsel Modu",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Durum Bilgisi - Debug yazıları kaldırıldı
              Container(
                width: double.infinity,
                color: gorselModu ? primaryColor.withOpacity(0.2) : primaryColor.withOpacity(0.2),
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    gorselModu ? "GÖRSEL MODU AKTİF" : "METİN MODU AKTİF",
                    style: const TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              
              // Ana İçerik
              Expanded(
                child: isLoading
                    ? Center(
                        child: YuklemeAnimasyonu(
                          tip: AnimasyonTipi.DALGALI,
                          renk: primaryColor,
                          analizTipi: AnalizTipi.MESAJ_KOCU,
                        ),
                      )
                    : (analizTamamlandi)
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: gorselModu && gorselDurumu.analiz != null
                            ? _gorselAnalizSonuclariniGoster(gorselDurumu.analiz!)
                            : _analizSonuclariniGoster(
                            controller.analysis != null 
                            ? controller.analysis! 
                                : MessageCoachAnalysis(analiz: "Analiz edilemedi", oneriler: [], etki: {}, sohbetGenelHavasi: "")
                          ),
                        )
                      : Padding(
                        padding: const EdgeInsets.all(16),
                        child: gorselModu 
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Görsel seçme butonu
                                  InkWell(
                                    onTap: _gorselSec,
                                    child: Container(
                                      height: 250,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: primaryColor.withOpacity(0.5), width: 1),
                                      ),
                                      child: gorselDurumu.secilenGorsel != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(11),
                                              child: Image.file(
                                                gorselDurumu.secilenGorsel!,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.add_photo_alternate,
                                                  size: 48,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(height: 8),
                                                const Text(
                                                  "Görsel Seçmek İçin Tıklayın",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "Açıklama:",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _aciklamaController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: "Ne yazmalıyım?",
                                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.05),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: primaryColor),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Mesajınız:",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _textEditingController,
                                    maxLines: 5,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: "Analiz edilecek mesajı buraya yazın...",
                                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.05),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: primaryColor),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
              ),
              
              // Alt Buton - Analiz tamamlandıysa yeni analiz yapabilmek için "Yeni Analiz" butonu göster
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _mesajAnalizeEt,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor, 
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    analizTamamlandi
                        ? "Yeni Analiz"
                        : (gorselModu ? "Görseli Analiz Et" : "Yanıtla"),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Yardımcı widget sınıfları
class AnalizBaslikVeIcerik extends StatelessWidget {
  final String baslik;
  final String icerik;

  const AnalizBaslikVeIcerik({
    Key? key,
    required this.baslik,
    required this.icerik,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          baslik,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            icerik,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class CevapOnerisiItem extends StatelessWidget {
  final String oneri;

  const CevapOnerisiItem({
    Key? key,
    required this.oneri,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              oneri,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: oneri));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Mesaj kopyalandı'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// BlurredContentWithLock widget'ını oluştur (eğer daha önce tanımlanmadıysa)
class BlurredContentWithLock extends StatelessWidget {
  final String title;
  final String content;
  final bool isLocked;
  final Color backgroundColor;
  final VoidCallback onTap;

  const BlurredContentWithLock({
    Key? key,
    required this.title,
    required this.content,
    required this.isLocked,
    required this.backgroundColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLocked ? onTap : null,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                Text(
                  content,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    // Kilitli ise bulanıklaştır
                    fontWeight: isLocked ? FontWeight.normal : FontWeight.normal,
                  ),
                ),
                // Minimum yükseklik için görünmez bir boşluk ekliyoruz
                SizedBox(height: 20),
              ],
            ),
            // Kilitli ise bulanıklaştırma efekti ve kilit simgesi ekle
            if (isLocked)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Görmek için dokun",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 