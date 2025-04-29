import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'dart:io';
import '../controllers/message_coach_controller.dart';
import '../models/message_coach_analysis.dart';
import '../utils/utils.dart';
import '../utils/loading_indicator.dart';
import 'dart:async';
import '../helpers/file_utils.dart';

class MessageCoachView extends StatefulWidget {
  const MessageCoachView({super.key});

  @override
  State<MessageCoachView> createState() => _MessageCoachViewState();
}

class _MessageCoachViewState extends State<MessageCoachView> {
  final TextEditingController _sohbetController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
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
    // Bir kez çağırma garantisi
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Controller'ı sıfırla
      final controller = Provider.of<MessageCoachController>(context, listen: false);
      controller.analizSonuclariniSifirla();
      
      // Klavye görünürlük kontrolcüsünü başlat
      _keyboardVisibilityController = KeyboardVisibilityController();
      _keyboardSubscription = _keyboardVisibilityController.onChange.listen((bool visible) {
        setState(() {
          _klavyeAcik = visible;
        });
      });
    });
  }

  @override
  void dispose() {
    _sohbetController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MessageCoachController>(context);
    final theme = Theme.of(context);
    
    // Ekranı ilk kez gösterdiğinde animasyon için işaret
    if (!_gosterildiMi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _gosterildiMi = true;
        });
      });
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          controller.baslik,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () => _bilgiDialogGoster(context),
          ),
        ],
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            // Scroll view içindeki ana içerik
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Açıklama kartı
                    _buildAciklamaKarti(controller, theme).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                    // Sohbet giriş alanı
                    _buildSohbetGirisAlani(),
                    
                    // Analiz yükleniyor göstergesi
                    if (controller.yukleniyor)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: YuklemeAnimasyonu(
                            tip: AnimasyonTipi.DAIRE,
                            mesaj: controller.yuklemeMetni,
                          ),
                        ),
                      ),
                    
                    // Hata mesajı
                    if (controller.hataMesaji != null && !controller.yukleniyor)
                      _buildHataMesaji(controller.hataMesaji!, theme),
                    
                    // Analiz sonuçları
                    if (controller.analizTamamlandi && controller.mevcutAnaliz != null)
                      _buildAnalizSonuclari(controller.mevcutAnaliz!),
                    
                    // Ekran yüksekliği ayarı (klavye açıkken alt alan)
                    SizedBox(height: _klavyeAcik ? 200 : 50),
                  ],
                ),
              ),
            ),
            
            // Alt buton alanı
            _buildAltButtonAlani(controller),
          ],
        ),
      ),
    );
  }

  // Alt buton alanı widget'ı
  Widget _buildAltButtonAlani(MessageCoachController controller) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Örnek sohbet butonu
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  final ornekSohbet = controller.ornekSohbetIcerigiOlustur();
                  setState(() {
                    _sohbetController.text = ornekSohbet;
                  });
                },
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('Örnek Sohbet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Analiz butonu
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  final sohbetIcerigi = _sohbetController.text.trim();
                  
                  if (!controller.sohbetGecerliMi(sohbetIcerigi)) {
                    Utils.showErrorFeedback(
                      context, 
                      'Lütfen geçerli bir sohbet geçmişi girin'
                    );
                    return;
                  }
                  
                  // Klavyeyi kapat ve ekranı yukarı kaydır
                  FocusScope.of(context).unfocus();
                  
                  // Sohbeti analiz et
                  controller.sohbetiAnalizeEt(sohbetIcerigi);
                  
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
                icon: const Icon(Icons.analytics_outlined, size: 18),
                label: const Text('Analiz Et'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sohbet giriş alanı widget'ı
  Widget _buildSohbetGirisAlani() {
    final theme = Theme.of(context);
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _textAreaActive
            ? theme.colorScheme.surface
            : theme.colorScheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _textAreaActive
              ? theme.colorScheme.primary.withOpacity(0.5)
              : theme.colorScheme.outline.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık ve temizle butonu
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sohbet Geçmişi',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.clear_all,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _sohbetController.clear();
                    });
                  },
                  tooltip: 'Temizle',
                ),
              ],
            ),
          ),
          
          // Metin alanı
          Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Focus(
              onFocusChange: (hasFocus) {
                setState(() {
                  _textAreaActive = hasFocus;
                });
              },
              child: TextField(
                controller: _sohbetController,
                maxLines: 8,
                minLines: 6,
                decoration: InputDecoration(
                  hintText: 'Sohbet geçmişini buraya yapıştırın...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  // Analiz sonuçları widget'ı
  Widget _buildAnalizSonuclari(MessageCoachAnalysis analiz) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Text(
            'Analiz Sonuçları',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
          const SizedBox(height: 16),
          
          // Genel Sohbet Analizi kartı
          _buildAnalizKarti(
            baslik: 'Genel Sohbet Analizi',
            icerik: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEtiketSatiri(
                  etiket: 'Sohbet Genel Havası:',
                  deger: analiz.sohbetGenelHavasi ?? 'Belirlenemedi',
                  renkKodu: _havaDurumRengiGetir(analiz.sohbetGenelHavasi),
                ),
                const SizedBox(height: 12),
                _buildBilgiSatiri(
                  baslik: 'Genel Yorum:',
                  icerik: analiz.genelYorum ?? analiz.analiz,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
          const SizedBox(height: 16),
          
          // Son Mesaj Analizi kartı
          _buildAnalizKarti(
            baslik: 'Son Mesaj Analizi',
            icerik: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEtiketSatiri(
                  etiket: 'Son Mesaj Tonu:',
                  deger: analiz.sonMesajTonu ?? 'Belirlenemedi',
                  renkKodu: _tonRengiGetir(analiz.sonMesajTonu),
                ),
                const SizedBox(height: 16),
                if (analiz.sonMesajEtkisi != null) ...[
                  _buildEtkiYuzdeleri(analiz.sonMesajEtkisi!),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
          const SizedBox(height: 16),
          
          // Direkt Yorum ve Geliştirme kartı
          _buildAnalizKarti(
            baslik: 'Direkt Yorum ve Geliştirme',
            icerik: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBilgiSatiri(
                  baslik: 'Direkt Yorum:',
                  icerik: analiz.direktYorum ?? analiz.anlikTavsiye ?? 'Yorum yok',
                ),
                if (analiz.cevapOnerisi != null) ...[
                  const SizedBox(height: 16),
                  _buildCevapOnerisi(analiz.cevapOnerisi!),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 700.ms),
        ],
      ),
    );
  }

  // Etki yüzdeleri widget'ı
  Widget _buildEtkiYuzdeleri(Map<String, int> etkiler) {
    // Yüzdeleri doğrula ve toplam 100'e tamamla
    final toplamEtki = etkiler.values.fold(0, (sum, value) => sum + value);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Son Mesaj Etkisi:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ...etkiler.entries.map((entry) {
          final etki = entry.key;
          final yuzde = toplamEtki > 0 ? entry.value : 33; // 0'a bölünmeyi engelle
          final normalized = toplamEtki > 0 ? (entry.value / toplamEtki) : (1 / etkiler.length);
          
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _capitalizeFirst(etki), // String extension yerine helper method
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                  Text(
                    '%$yuzde',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _etkiRengiGetir(etki),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearPercentIndicator(
                lineHeight: 8.0,
                percent: normalized,
                animation: true,
                animationDuration: 800,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                progressColor: _etkiRengiGetir(etki),
                barRadius: const Radius.circular(4),
              ),
              const SizedBox(height: 8),
            ],
          );
        }).toList(),
      ],
    );
  }
  
  // String'in ilk harfini büyük yapan yardımcı metot
  String _capitalizeFirst(String text) {
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  // Cevap önerisi widget'ı
  Widget _buildCevapOnerisi(String cevapOnerisi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Cevap Önerisi:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            InkWell(
              onTap: () => _metniKopyala(cevapOnerisi),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.copy,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Kopyala',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
          child: Text(
            cevapOnerisi,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  // Analiz kartı widget'ı
  Widget _buildAnalizKarti({
    required String baslik,
    required Widget icerik,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Divider(height: 24),
          icerik,
        ],
      ),
    );
  }

  // Etiket satırı widget'ı
  Widget _buildEtiketSatiri({
    required String etiket,
    required String deger,
    required Color renkKodu,
  }) {
    return Row(
      children: [
        Text(
          etiket,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: renkKodu.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: renkKodu.withOpacity(0.3)),
          ),
          child: Text(
            deger,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: renkKodu,
            ),
          ),
        ),
      ],
    );
  }

  // Bilgi satırı widget'ı
  Widget _buildBilgiSatiri({
    required String baslik,
    required String icerik,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          baslik,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          icerik,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  // Hava durumu renk kodları
  Color _havaDurumRengiGetir(String? hava) {
    if (hava == null) return Colors.grey;
    
    switch (hava.toLowerCase()) {
      case 'soğuk':
        return Colors.blue;
      case 'samimi':
        return Colors.green;
      case 'pasif-agresif':
        return Colors.orange;
      case 'ilgisiz':
        return Colors.grey;
      case 'ilgili':
        return Colors.teal;
      default:
        return Colors.purple;
    }
  }

  // Ton renk kodları
  Color _tonRengiGetir(String? ton) {
    if (ton == null) return Colors.grey;
    
    switch (ton.toLowerCase()) {
      case 'sert':
        return Colors.red;
      case 'soğuk':
        return Colors.blue;
      case 'sempatik':
        return Colors.green;
      case 'umursamaz':
        return Colors.grey;
      case 'ilgisiz':
        return Colors.blueGrey;
      case 'nötr':
        return Colors.amber;
      case 'samimi':
        return Colors.teal;
      case 'pasif-agresif':
        return Colors.deepOrange;
      default:
        return Colors.purple;
    }
  }

  // Etki renk kodları
  Color _etkiRengiGetir(String etki) {
    switch (etki.toLowerCase()) {
      case 'sempatik':
      case 'olumlu':
        return Colors.green;
      case 'kararsız':
      case 'nötr':
        return Colors.amber;
      case 'olumsuz':
        return Colors.red;
      default:
        return Colors.purple;
    }
  }

  // Bilgi diyaloğunu göster
  void _bilgiDialogGoster(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mesaj Koçu Hakkında',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(
                  'Mesaj Koçu, sohbet geçmişinizi analiz ederek sohbetin genel havasını ve mesajlarınızın etkisini değerlendirir.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nasıl Kullanılır?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Sohbet geçmişinizi yukarıdaki metin kutusuna yapıştırın.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '2. "Analiz Et" butonuna tıklayın.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '3. Sohbetin genel havasını, son mesajınızın etkisini ve geliştirme önerilerini görüntüleyin.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'İpuçları',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Sohbet metnini "Sen: " ve "Karşı taraf: " şeklinde düzenleyerek daha doğru sonuçlar alabilirsiniz.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Analiz için en az 2-3 mesaj değişimi içeren bir sohbet geçmişi kullanın.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• "Örnek Sohbet" butonu ile nasıl veri girmeniz gerektiğini görebilirsiniz.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Anladım',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Dosya seçme butonu widget'ı
  Widget _buildDosyaSecmeButonu() {
    final theme = Theme.of(context);
    final controller = Provider.of<MessageCoachController>(context);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: OutlinedButton.icon(
        onPressed: _yuklemeDurumu ? null : _dosyaSec,
        icon: Icon(Icons.upload_file, size: 20),
        label: Text(controller.dosyaSecmeButonMetni),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.5),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 400.ms);
  }

  // Dosya seçme işlemi
  Future<void> _dosyaSec() async {
    final controller = Provider.of<MessageCoachController>(context, listen: false);
    
    try {
      setState(() {
        _yuklemeDurumu = true;
        _hataMesaji = '';
      });
      
      // FileUtils yardımcı sınıfını kullan
      final XFile? dosya = await FileUtils.dosyaSec(
        dosyaTurleri: [
          XTypeGroup(
            label: 'Metin Dosyaları',
            extensions: ['txt', 'json'],
          ),
        ],
      );
      
      if (dosya == null) {
        setState(() {
          _yuklemeDurumu = false;
        });
        return; // Kullanıcı dosya seçimini iptal etti
      }
      
      // Dosya içeriğini oku
      final String icerik = await dosya.readAsString();
      
      // Sohbet alanına içeriği yerleştir
      setState(() {
        _sohbetController.text = icerik;
        _yuklemeDurumu = false;
      });
      
    } catch (e) {
      setState(() {
        _yuklemeDurumu = false;
        _hataMesaji = 'Dosya seçilirken bir hata oluştu: ${e.toString()}';
      });
    }
  }

  // Açıklama kartı widget'ı
  Widget _buildAciklamaKarti(MessageCoachController controller, ThemeData theme) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.aciklamaBaslik,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            controller.aciklamaMetni,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 8),
          _buildDosyaSecmeButonu(),
        ],
      ),
    );
  }

  // Hata mesajı widget'ı
  Widget _buildHataMesaji(String mesaj, ThemeData theme) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              mesaj,
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
} 