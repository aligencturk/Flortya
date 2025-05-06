import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:provider/provider.dart' as provider;
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../controllers/message_coach_controller.dart';
import '../controllers/message_coach_visual_controller.dart';
import '../models/message_coach_analysis.dart';
import '../models/message_coach_visual_analysis.dart';
import '../utils/utils.dart';
import '../utils/loading_indicator.dart';
import '../helpers/file_utils.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/message_coach_card.dart';

class MessageCoachView extends ConsumerStatefulWidget {
  const MessageCoachView({super.key});

  @override
  ConsumerState<MessageCoachView> createState() => _MessageCoachViewState();
}

class _MessageCoachViewState extends ConsumerState<MessageCoachView> {
  final TextEditingController _textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _aciklamaController = TextEditingController();
  
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
        controller.setCurrentUserId(authViewModel.currentUser!.uid);
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
      Utils.showSuccessFeedback(
        context, 
        'Metin panoya kopyalandı'
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

  @override
  Widget build(BuildContext context) {
    final controller = provider.Provider.of<MessageCoachController>(context);
    final gorselDurumu = ref.watch(mesajKocuGorselKontrolProvider);
    final theme = Theme.of(context);
    final bool gorselModu = controller.gorselModu;
    final bool isLoading = controller.isLoading || gorselDurumu.yukleniyor;
    
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
                    onPressed: () {
                      // Görsel modunu değiştir
                      controller.gorselModunuDegistir();
                    },
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
                                      child: controller.gorselDosya != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(11),
                                              child: Image.file(
                                                controller.gorselDosya!,
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
              
              // Alt Buton
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () {
                    if (gorselModu) {
                      if (controller.gorselDosya != null) {
                        controller.gorselIleAnalizeEt(
                          controller.gorselDosya!,
                          _aciklamaController.text,
                        );
                      } else {
                        Utils.showErrorFeedback(context, "Lütfen önce bir görsel seçin");
                      }
                    } else {
                      controller.metinAciklamasiIleAnalizeEt(_textEditingController.text);
                    }
                  },
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
                    gorselModu ? "Görseli Analiz Et" : "Yanıtla",
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