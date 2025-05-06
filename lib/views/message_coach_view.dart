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
        ref.read(mesajKocuGorselKontrolProvider.notifier).gorselDosyasiAyarla(gorselDosya);
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
    
    // Ekranı ilk kez gösterdiğinde animasyon için işaret
    if (!_gosterildiMi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _gosterildiMi = true;
        });
      });
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF260F68),
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Merhaba, ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.normal,
                fontSize: 18,
              ),
            ),
            Text(
              'Ali Talip Gençtürk',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF260F68),
        elevation: 0,
        actions: [
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
      body: isLoading
          ? Center(
              child: YuklemeAnimasyonu(
                tip: AnimasyonTipi.DALGALI,
                renk: Color(0xFF9D3FFF),
                analizTipi: AnalizTipi.MESAJ_KOCU,
              ),
            )
          : _buildBodyContent(context, gorselModu, gorselDurumu),
    );
  }

  // Bilgi kartı widget'ı
  Widget _buildInfoCard(bool gorselModu) {
    final theme = Theme.of(context);
    final controller = provider.Provider.of<MessageCoachController>(context);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF352269),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                color: Colors.white.withOpacity(0.9),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Mesaj Koçu',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Mesajını analiz edelim! Yazdığın mesajın duygusal etkisini ölçüp, daha etkili iletişim kurman için tavsiyelerde bulunalım.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 18,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Kalan ücretsiz analiz: 3',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Sohbet giriş alanı widget'ı
  Widget _buildSohbetGirisAlani() {
    final theme = Theme.of(context);
    final controller = provider.Provider.of<MessageCoachController>(context);
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF231955).withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _textEditingController,
            maxLines: 5,
            minLines: 3,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Analiz edilecek mesajı buraya yazın...',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.5),
              ),
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Icon(
                  Icons.image,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
            ),
            onTap: () {
              setState(() {
                _textAreaActive = true;
              });
            },
            onTapOutside: (_) {
              setState(() {
                _textAreaActive = false;
              });
            },
          ),
        ],
      ),
    );
  }
  
  // Açıklama giriş alanı widget'ı (görsel modu için)
  Widget _buildAciklamaGirisAlani() {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _textAreaActive 
              ? theme.colorScheme.primary.withOpacity(0.5)
              : theme.colorScheme.outline.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 12, right: 16),
            child: Row(
              children: [
                Icon(
                  Icons.help_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Açıklamanız',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: _aciklamaController,
            maxLines: 3,
            minLines: 2,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              hintText: 'Örnek: "Ne yazmalıyım?", "Ne cevap vermeliyim?"',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              border: InputBorder.none,
            ),
            style: theme.textTheme.bodyLarge,
            onTap: () {
              setState(() {
                _textAreaActive = true;
              });
            },
            onTapOutside: (_) {
              setState(() {
                _textAreaActive = false;
              });
            },
          ),
        ],
      ),
    );
  }
  
  // Görsel önizleme alanı
  Widget _buildGorselOnizlemeAlani() {
    final gorselDurumu = ref.watch(mesajKocuGorselKontrolProvider);
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.all(16),
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: gorselDurumu.secilenGorsel != null
              ? theme.colorScheme.primary.withOpacity(0.5)
              : theme.colorScheme.outline.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: _gorselSec,
        borderRadius: BorderRadius.circular(14),
        child: gorselDurumu.secilenGorsel != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      gorselDurumu.secilenGorsel!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.refresh,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        onPressed: () {
                          ref.read(mesajKocuGorselKontrolProvider.notifier).gorselDosyasiAyarla(null);
                        },
                        tooltip: 'Görseli Değiştir',
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sohbet ekran görüntüsü yükleyin',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sağ taraftaki mesajlar size, sol taraftaki mesajlar karşı tarafa ait olmalıdır',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Görsel Seçmek İçin Tıklayın',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // Alt buton alanı widget'ı
  Widget _buildAltButtonAlani(MessageCoachController controller, bool gorselModu) {
    final gorselDurumu = ref.watch(mesajKocuGorselKontrolProvider);
    final theme = Theme.of(context);
    
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: ElevatedButton(
          onPressed: gorselDurumu.secilenGorsel == null && gorselModu 
            ? null  // Görsel yoksa butonu devre dışı bırak
            : () {
              // Görsel modunda analiz
              if (gorselModu) {
                if (gorselDurumu.secilenGorsel != null) {
                  final aciklama = _aciklamaController.text.trim();
                  controller.gorselIleAnalizeEt(gorselDurumu.secilenGorsel!, aciklama);
                } else {
                  Utils.showErrorFeedback(
                    context, 
                    'Lütfen önce bir sohbet görüntüsü yükleyin'
                  );
                }
                return;
              }
              
              // Metin açıklaması modunda analiz
              final aciklama = _textEditingController.text.trim();
              
              if (aciklama.isEmpty) {
                Utils.showErrorFeedback(
                  context, 
                  'Lütfen bir açıklama yazın'
                );
                return;
              }
              
              // Klavyeyi kapat ve ekranı yukarı kaydır
              FocusScope.of(context).unfocus();
              
              // Metni analiz et
              controller.metinAciklamasiIleAnalizeEt(aciklama);
              
              // İşlem tamamlandığında ekranı aşağı kaydır
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    300,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                }
              });
            },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB56CF8),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFB56CF8).withOpacity(0.5),
            disabledForegroundColor: Colors.white.withOpacity(0.7),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Analiz Et',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Ana içerik widget'ı
  Widget _buildBodyContent(BuildContext context, bool gorselModu, MesajKocuGorselDurumu gorselDurumu) {
    final controller = provider.Provider.of<MessageCoachController>(context);
    final theme = Theme.of(context);
    final analysis = controller.analysis;
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Mesaj Koçu',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
          
          // Üst kısım (scroll edilebilir alan)
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bilgi kartı
                  _buildInfoCard(gorselModu),
                  
                  // Görsel veya metin giriş alanı
                  gorselModu
                  ? Column(
                      children: [
                        _buildGorselOnizlemeAlani(),
                        _buildAciklamaGirisAlani(),
                      ],
                    )
                  : _buildSohbetGirisAlani(),
                  
                  const SizedBox(height: 16),
                  
                  // Görsel analiz sonuçları veya metin analiz sonuçları
                  if (gorselModu) 
                    if (gorselDurumu.analiz != null) 
                      _buildGorselAnalizSonuclari(gorselDurumu.analiz!)
                    else if (gorselDurumu.hataVar) 
                      _buildHataMesaji(gorselDurumu.hataMesaji ?? 'Görsel analiz edilirken bir hata oluştu')
                  else
                    if (analysis != null) 
                      _buildAnalizSonuclari(analysis)
                    else if (controller.errorMessage.isNotEmpty) 
                      _buildHataMesaji(controller.errorMessage),
                  
                  // Alt boşluk
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
          
          // Alt buton alanı
          _buildAltButtonAlani(controller, gorselModu),
        ],
      ),
    );
  }

  // Hata mesajı widget'ı
  Widget _buildHataMesaji(String mesaj) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              color: theme.colorScheme.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hata',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mesaj,
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Metin analiz sonuçları widget'ı
  Widget _buildAnalizSonuclari(MessageCoachAnalysis analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Analiz Sonuçları'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Genel Değerlendirme',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(analysis.genelYorum ?? 'Değerlendirme yapılamadı'),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  // Görsel analiz sonuçları widget'ı
  Widget _buildGorselAnalizSonuclari(MessageCoachVisualAnalysis analiz) {
    final theme = Theme.of(context);
    
    // Analiz bölümüne yönlendirme varsa
    if (analiz.isAnalysisRedirect) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Analiz Bölümüne Yönlendirme',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              analiz.redirectMessage ?? 'Bu tür bir analiz için lütfen Analiz bölümünü kullanın.',
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/analysis');
                },
                icon: Icon(Icons.analytics_outlined),
                label: Text('Analiz Bölümüne Git'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error.withOpacity(0.8),
                  foregroundColor: theme.colorScheme.onError,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Normal analiz sonuçları
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Durum Değerlendirmesi'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.psychology_outlined,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Koçun Değerlendirmesi',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            analiz.konumDegerlendirmesi ?? 'Değerlendirme yapılamadı.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        _buildSectionTitle('Önerilen Mesajlar'),
        if (analiz.alternativeMessages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Mesaj önerisi bulunamadı.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ...analiz.alternativeMessages.asMap().entries.map((entry) {
            final index = entry.key;
            final mesaj = entry.value;
            final gradientColors = [
              if (index == 0) [theme.colorScheme.primary.withOpacity(0.8), theme.colorScheme.primary.withOpacity(0.6)],
              if (index == 1) [theme.colorScheme.secondary.withOpacity(0.8), theme.colorScheme.secondary.withOpacity(0.6)],
              if (index == 2) [theme.colorScheme.tertiary.withOpacity(0.8), theme.colorScheme.tertiary.withOpacity(0.6)],
            ].firstWhere((_) => true, orElse: () => [theme.colorScheme.primary.withOpacity(0.7), theme.colorScheme.primary.withOpacity(0.5)]);
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Öneri ${index + 1}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      mesaj,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _metniKopyala(mesaj),
                          icon: Icon(
                            Icons.copy_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Kopyala',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          
        _buildSectionTitle('Olası Yanıtlar'),
        if (analiz.partnerResponses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Olası yanıt bulunamadı.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Olumlu yanıt
                if (analiz.partnerResponses.length > 0)
                  Expanded(
                    child: Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.thumb_up_outlined,
                                    color: Colors.green,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Olumlu Yanıt',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              analiz.partnerResponses[0],
                              style: theme.textTheme.bodySmall,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                const SizedBox(width: 8),
                
                // Olumsuz yanıt
                if (analiz.partnerResponses.length > 1)
                  Expanded(
                    child: Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Colors.red.withOpacity(0.3),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.thumb_down_outlined,
                                    color: Colors.red,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Olumsuz Yanıt',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              analiz.partnerResponses[1],
                              style: theme.textTheme.bodySmall,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
        const SizedBox(height: 24),
      ],
    );
  }

  // Ara başlık widget'ı
  Widget _buildSectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
} 