import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/message_coach_analysis.dart';
import '../viewmodels/advice_viewmodel.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:file_selector/file_selector.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/message_viewmodel.dart';
import '../utils/loading_indicator.dart';

class MessageCoachCard extends StatefulWidget {
  const MessageCoachCard({Key? key}) : super(key: key);

  @override
  _MessageCoachCardState createState() => _MessageCoachCardState();
}

class _MessageCoachCardState extends State<MessageCoachCard> {
  final TextEditingController _messageController = TextEditingController();
  bool _isTextInputVisible = false;
  final List<File> _selectedImages = [];
  
  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
  
  // Görsel seçme fonksiyonu
  Future<void> _pickImages() async {
    try {
      final typeGroup = XTypeGroup(
        label: 'Görseller',
        extensions: ['jpg', 'jpeg', 'png'],
      );
      
      final List<XFile> files = await openFiles(
        acceptedTypeGroups: [typeGroup],
      );

      if (files.isNotEmpty) {
        setState(() {
          for (var file in files) {
            _selectedImages.add(File(file.path));
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Görseller seçilirken bir hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Analiz yap fonksiyonu
  void _analyzeMessage(AdviceViewModel viewModel) {
    print("🟡 Butona basıldı - Analiz Et butonuna tıklandı");
    
    final String messageText = _messageController.text.trim();
    
    if (messageText.isEmpty && _selectedImages.isEmpty) {
      print("❌ Analiz hatası: Mesaj ve görsel boş");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir mesaj girin veya görsel yükleyin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Kullanıcı ID'si kontrolü
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final userId = authViewModel.currentUser?.uid;
    if (userId == null) {
      print("❌ Analiz hatası: Kullanıcı oturum açmamış");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oturum açmanız gerekiyor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (messageText.isNotEmpty) {
      print("🔍 Metin analizi başlatılıyor: ${messageText.substring(0, min(20, messageText.length))}...");
      // Metin mesajı analizi
      viewModel.analyzeMesaj(messageText, userId);
      
      // İşlem tamamlandığında giriş alanını temizle
      setState(() {
        _isTextInputVisible = false;
        _messageController.clear();
      });
    } else if (_selectedImages.isNotEmpty) {
      print("🖼️ Görsel analizi başlatılıyor: ${_selectedImages.first.path}");
      
      // Görsel OCR analizi için ViewModel'deki metodu çağırıyoruz
      viewModel.forceStartAnalysis(); // Analiz başladığını bildir
      
      // Analiz için kullanacağımız görsel kopyasını saklayalım
      // Böylece setState ile temizlenmeden önce kopyasını alabiliriz
      final File imageToAnalyze = _selectedImages.first;
      
      // Erken referans almak için MessageViewModel'i burada alalım
      final MessageViewModel messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
      
      // İşlem tamamlandığında görselleri temizle (UI'dan kaldır)
      setState(() {
        _selectedImages.clear();
      });
      
      // Dart'ın isolate özelliğini kullanarak asenkron işlemi başlat
      Future(() async {
        try {
          print("📤 Görsel analiz edilmek üzere gönderiliyor...");
          
          // Görselden metin çıkarma ve analiz işlemini başlat
          final result = await messageViewModel.analyzeImageMessage(imageToAnalyze, otherUserId: userId);
          
          // Analiz durumunu kontrol et
          if (!mounted) {
            print("❌ Widget artık aktif değil, işlem iptal edildi");
            return; // Widget artık mevcut değilse işlemi sonlandır
          }
          
          // Analiz sonucunu elde et
          final analysisResult = messageViewModel.currentAnalysisResult;
          
          if (result && analysisResult != null) {
            print("✅ Görsel analizi başarılı: ${analysisResult.id}");
            
            // AdviceViewModel'e analiz sonucunu aktar (Mesaj Koçu UI'ında görüntülemek için)
            viewModel.setAnalysisResultFromMessage(analysisResult);
          } else {
            print("❌ Görsel analizi başarısız");
            viewModel.setError("Görsel analizi yapılamadı: ${messageViewModel.errorMessage ?? 'Bilinmeyen hata'}");
          }
        } catch (e) {
          print("❌ Görsel analizi sırasında hata: $e");
          if (mounted) { // Widget hala aktifse hata durumunu bildir
            viewModel.setError("Görsel analizi sırasında hata: $e");
          }
        } finally {
          if (mounted) { // Widget hala aktifse durumu temizle
            viewModel.forceStopAnalysis(); // Analiz durumunu sıfırla
          }
        }
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // AdviceViewModel'i dinleyerek durumları güncelleyelim
    final AdviceViewModel adviceViewModel = Provider.of<AdviceViewModel>(context, listen: true);
    
    // Her build işleminde durumları güncelleyelim
    final bool isLoading = adviceViewModel.isLoading || adviceViewModel.isAnalyzing;
    final bool hasAnalysis = adviceViewModel.hasAnalizi;
    final MessageCoachAnalysis? sonuc = adviceViewModel.mesajAnalizi;
    
    // DEBUG: Widget durumunu loglayalım
    print('⭐️ MessageCoachCard yeniden oluşturuluyor - isLoading=$isLoading, hasAnalysis=$hasAnalysis, sonuc=${sonuc != null ? "var" : "yok"}, error=${adviceViewModel.errorMessage != null}');
    
    if (hasAnalysis && sonuc != null) {
      print('✅ Görüntülenecek SONUÇ VAR: ${sonuc.anlikTavsiye != null ? "Tavsiye: ${sonuc.anlikTavsiye!.substring(0, min(30, sonuc.anlikTavsiye!.length))}..." : "Tavsiye yok"}, ÖNERİLER: ${sonuc.oneriler.length}');
    }
    
    // Widget ağacı
    return Card(
      key: ValueKey('mesaj_kocu_card_${isLoading}_${hasAnalysis}_${adviceViewModel.errorMessage != null}'),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF352269),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            const Row(
              children: [
                Icon(Icons.psychology, color: Color(0xFF9D3FFF), size: 24),
                SizedBox(width: 8),
                Text(
                  'Mesaj Koçu',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // İÇERİK BLOĞU - Duruma göre doğru olanı göster
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Builder(
                key: ValueKey('content_${isLoading}_${hasAnalysis}_${adviceViewModel.errorMessage != null}'),
                builder: (context) {
                  // Yükleme göstergesi
                  if (isLoading) {
                    return _buildLoadingIndicator();
                  }
                  
                  // Hata mesajı
                  if (!isLoading && adviceViewModel.errorMessage != null) {
                    return _buildErrorMessage(adviceViewModel.errorMessage!, context);
                  }
                  
                  // Analiz sonuçları 
                  if (!isLoading && hasAnalysis && sonuc != null) {
                    return _buildAnalysisResults(sonuc, context);
                  }
                  
                  // Başlangıç/Bilgi Formu
                  return _buildInitialInfo(context, adviceViewModel);
                }
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 300.ms).slideY(begin: 0.2, end: 0, duration: 300.ms, curve: Curves.easeOutQuad);
  }
  
  // YÜKLEME GÖSTERGESİ
  Widget _buildLoadingIndicator() {
    return Center(
      key: const ValueKey('loading_indicator'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const YuklemeAnimasyonu(
            tip: AnimasyonTipi.DALGALI,
            boyut: 50.0,
            renk: Color(0xFF9D3FFF),
          ),
          const SizedBox(height: 16),
          const Text(
            'Mesajınız analiz ediliyor...',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                backgroundColor: Color(0x339D3FFF),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D3FFF)),
                minHeight: 4,
              ),
            ),
          ),
          Text(
            'İşlem sürüyor...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Mesajınız AI tarafından değerlendiriliyor. Duygu analizi ve iletişim tavsiyeleri hazırlanıyor...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
  
  // BAŞLANGIÇ/BİLGİ MESAJI
  Widget _buildInitialInfo(BuildContext context, AdviceViewModel adviceViewModel) {
    return Container(
      key: const ValueKey('initial_info'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mesajını analiz edelim! Yazdığın mesajın duygusal etkisini ölçüp, daha etkili iletişim kurman için tavsiyelerde bulunalım.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(
                'Kalan ücretsiz analiz: ${MessageCoachAnalysis.ucretlizAnalizSayisi - adviceViewModel.ucretlizAnalizSayisi}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Tek bir giriş alanı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Görsel seçilmişse göster
                if (_selectedImages.isNotEmpty)
                  Container(
                    height: 100,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Container(
                              margin: const EdgeInsets.all(4),
                              width: 80,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _selectedImages[index],
                                  fit: BoxFit.cover,
                                  height: 80,
                                  width: 80,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 16),
                              onPressed: () {
                                setState(() {
                                  _selectedImages.removeAt(index);
                                });
                              },
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                
                // Metin girişi kutusu
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Görsel yükleme ikonu
                      IconButton(
                        icon: const Icon(Icons.photo, color: Colors.white70),
                        onPressed: _pickImages,
                        tooltip: 'Görsel Yükle',
                      ),
                      // Metin alanı
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 5,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Analiz edilecek mesajı buraya yazın...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Analiz et butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _analyzeMessage(adviceViewModel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D3FFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Analiz Et'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // HATA MESAJI
  Widget _buildErrorMessage(String message, BuildContext context) {
    return Container(
      key: const ValueKey('error_message'),
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.5))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text(
                 'Analiz Başarısız',
                 style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
               ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
           const SizedBox(height: 16),
           Center(
             child: ElevatedButton.icon(
               onPressed: () {
                 Provider.of<AdviceViewModel>(context, listen: false).resetError();
               },
               icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
               label: const Text('Tekrar Dene', style: TextStyle(color: Colors.white)),
               style: ElevatedButton.styleFrom(
                 backgroundColor: const Color(0xFF9D3FFF).withOpacity(0.8),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
               ),
             ),
           ),
        ],
      ),
    );
  }
  
  // ANALİZ SONUÇLARI
  Widget _buildAnalysisResults(MessageCoachAnalysis analiz, BuildContext context) {
    final String resultKey = analiz.anlikTavsiye ?? 'no_advice';
     return Container(
       key: ValueKey('analysis_results_$resultKey'),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           // 1. GENEL SOHBET ANALİZİ
           const Padding(
             padding: EdgeInsets.only(bottom: 8),
             child: Row(
               children: [
                 Icon(Icons.chat_outlined, color: Color(0xFF9D3FFF), size: 18),
                 SizedBox(width: 6),
                 Text(
                   'Genel Sohbet Analizi',
                   style: TextStyle(
                     color: Colors.white,
                     fontWeight: FontWeight.bold,
                     fontSize: 16,
                   ),
                 ),
               ],
             ),
           ),
           
           Container(
             width: double.infinity,
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: Colors.white.withOpacity(0.1),
               borderRadius: BorderRadius.circular(12),
             ),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                     const Text(
                       'Sohbet genel havası: ',
                       style: TextStyle(
                         color: Colors.white70,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                     Text(
                       analiz.sohbetGenelHavasi ?? 'Sohbet analizi için yetersiz içerik',
                       style: const TextStyle(
                         color: Colors.white,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                   ],
                 ),
                 const SizedBox(height: 8),
                 Text(
                   analiz.genelYorum ?? analiz.analiz,
                   style: const TextStyle(
                     color: Colors.white,
                     fontSize: 14,
                     height: 1.4,
                   ),
                 ),
               ],
             ),
           ),
           
           const SizedBox(height: 20),
           
           // 2. SON MESAJ ANALİZİ
           const Padding(
             padding: EdgeInsets.only(bottom: 8),
             child: Row(
               children: [
                 Icon(Icons.analytics_outlined, color: Color(0xFF9D3FFF), size: 18),
                 SizedBox(width: 6),
                 Text(
                   'Son Mesaj Analizi',
                   style: TextStyle(
                     color: Colors.white,
                     fontWeight: FontWeight.bold,
                     fontSize: 16,
                   ),
                 ),
               ],
             ),
           ),
           
           Container(
             width: double.infinity,
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: Colors.white.withOpacity(0.1),
               borderRadius: BorderRadius.circular(12),
             ),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                     const Text(
                       'Son mesaj tonu: ',
                       style: TextStyle(
                         color: Colors.white70,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                     Text(
                       analiz.sonMesajTonu ?? 'Analiz edilemedi',
                       style: const TextStyle(
                         color: Colors.white,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                   ],
                 ),
                 const SizedBox(height: 12),
                 const Text(
                   'Son mesaj etkisi:',
                   style: TextStyle(
                     color: Colors.white70,
                     fontWeight: FontWeight.w600,
                   ),
                 ),
                 const SizedBox(height: 6),
                 // Son mesaj etki yüzdeleri - sonMesajEtkisi yok veya boşsa formatlanmış metni kullan
                 // Ekran görüntüsündeki gibi progress bar'lı gösterim
                 _buildProgressBarEtki(analiz),
               ],
             ),
           ),
           
           const SizedBox(height: 20),
           
           // 3. DİREKT YORUM VE GELİŞTİRME
           const Padding(
             padding: EdgeInsets.only(bottom: 8),
             child: Row(
               children: [
                 Icon(Icons.lightbulb_outline, color: Color(0xFF9D3FFF), size: 18),
                 SizedBox(width: 6),
                 Text(
                   'Direkt Yorum ve Geliştirme',
                   style: TextStyle(
                     color: Colors.white,
                     fontWeight: FontWeight.bold,
                     fontSize: 16,
                   ),
                 ),
               ],
             ),
           ),
           
           Container(
             width: double.infinity,
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: Colors.white.withOpacity(0.1),
               borderRadius: BorderRadius.circular(12),
             ),
             child: Text(
               analiz.direktYorum ?? analiz.anlikTavsiye ?? analiz.analiz,
               style: const TextStyle(
                 color: Colors.white,
                 fontSize: 14,
                 height: 1.4,
               ),
             ),
           ),
           
           // 4. CEVAP ÖNERİSİ (varsa)
           if (analiz.cevapOnerisi != null && analiz.cevapOnerisi!.isNotEmpty) ...[
             const SizedBox(height: 20),
             
             const Padding(
               padding: EdgeInsets.only(bottom: 8),
               child: Row(
                 children: [
                   Icon(Icons.edit_note, color: Color(0xFF9D3FFF), size: 18),
                   SizedBox(width: 6),
                   Text(
                     'Cevap Önerisi',
                     style: TextStyle(
                       color: Colors.white,
                       fontWeight: FontWeight.bold,
                       fontSize: 16,
                     ),
                   ),
                 ],
               ),
             ),
             
             Container(
               width: double.infinity,
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: Colors.white.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(12),
                 border: Border.all(
                   color: const Color(0xFF9D3FFF).withOpacity(0.3),
                   width: 1.0,
                 ),
               ),
               child: Text(
                 analiz.cevapOnerisi!,
                 style: const TextStyle(
                   color: Colors.white,
                   fontSize: 14,
                   height: 1.4,
                   fontStyle: FontStyle.italic,
                 ),
               ),
             ),
           ] else if (analiz.yenidenYazim != null && analiz.yenidenYazim!.isNotEmpty) ...[
             // Eski versiyondan kalma - yeniden yazım varsa cevap önerisi olarak göster
             const SizedBox(height: 20),
             
             const Padding(
               padding: EdgeInsets.only(bottom: 8),
               child: Row(
                 children: [
                   Icon(Icons.edit_note, color: Color(0xFF9D3FFF), size: 18),
                   SizedBox(width: 6),
                   Text(
                     'Cevap Önerisi',
                     style: TextStyle(
                       color: Colors.white,
                       fontWeight: FontWeight.bold,
                       fontSize: 16,
                     ),
                   ),
                 ],
               ),
             ),
             
             Container(
               width: double.infinity,
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: Colors.white.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(12),
                 border: Border.all(
                   color: const Color(0xFF9D3FFF).withOpacity(0.3),
                   width: 1.0,
                 ),
               ),
               child: Text(
                 analiz.yenidenYazim!,
                 style: const TextStyle(
                   color: Colors.white,
                   fontSize: 14,
                   height: 1.4,
                   fontStyle: FontStyle.italic,
                 ),
               ),
             ),
           ],
         ],
       ),
     );
  }
  
  // YENİ METOT: Progress bar ile etki yüzdelerini gösterir
  Widget _buildProgressBarEtki(MessageCoachAnalysis analiz) {
    // Formatlanmış mesaj etkisini al
    String etkiText = analiz.getFormattedLastMessageEffects();
    
    // Analiz bekleniyor durumunda özel gösterim
    if (etkiText == 'Analiz bekleniyor') {
      return Text(
        etkiText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    
    // "% değer kategori / % değer kategori / % değer kategori" formatında
    List<String> parts = etkiText.split('/');
    
    if (parts.length < 3) {
      return Text(
        etkiText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      );
    }
    
    // Her kategori için değerleri ayıkla
    Map<String, int> parsedValues = {};
    
    for (var part in parts) {
      part = part.trim();
      // % işaretini bul
      int percentIndex = part.indexOf('%');
      if (percentIndex >= 0) {
        // % işaretinden sonraki sayıyı bul
        String percentValueStr = '';
        int i = percentIndex + 1;
        while (i < part.length && part[i].contains(RegExp(r'[0-9]'))) {
          percentValueStr += part[i];
          i++;
        }
        
        if (percentValueStr.isNotEmpty) {
          int percentValue = int.tryParse(percentValueStr) ?? 0;
          
          // Kategori ismini bul
          String category = '';
          if (i < part.length) {
            category = part.substring(i).trim();
          }
          
          if (category.isNotEmpty) {
            parsedValues[category] = percentValue;
          }
        }
      }
    }
    
    // Kategorileri manuel ayarla - eğer boşsa
    if (parsedValues.isEmpty && parts.length >= 3) {
      // Her bir parçayı işleyelim
      try {
        for (int i = 0; i < parts.length && i < 3; i++) {
          final part = parts[i].trim();
          final match = RegExp(r'%(\d+)\s+(\w+)').firstMatch(part);
          if (match != null && match.groupCount >= 2) {
            final value = int.tryParse(match.group(1) ?? '0') ?? 0;
            final category = match.group(2) ?? '';
            if (category.isNotEmpty) {
              parsedValues[category] = value;
            }
          }
        }
      } catch (e) {
        print('Etki değerleri ayrıştırılamadı: $e');
      }
    }
    
    // Değerler yine boşsa, varsayılan değerleri göster
    if (parsedValues.isEmpty) {
      parsedValues = {
        'Sempatik': 60,
        'Kararsız': 25,
        'Olumsuz': 15,
      };
    }
    
    // Değerleri progress bar olarak göster
    return Column(
      children: parsedValues.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '%${entry.value}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: entry.value / 100,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(_getEtkiRenk(entry.key)),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  // DUYGU TİPİNE GÖRE RENK BELİRLER
  Color _getEtkiRenk(String duygu) {
    final lowerDuygu = duygu.toLowerCase();
    
    // Sempatik ve olumlu duygular (yeşil tonlar)
    if (lowerDuygu.contains('sempatik') || 
        lowerDuygu.contains('olumlu') || 
        lowerDuygu.contains('friendly') ||
        lowerDuygu.contains('positive') ||
        lowerDuygu.contains('samimi')) {
      return Colors.green;
    }
    
    // Kararsız ve nötr duygular (turuncu/sarı tonlar)
    if (lowerDuygu.contains('kararsız') || 
        lowerDuygu.contains('nötr') || 
        lowerDuygu.contains('neutral') ||
        lowerDuygu.contains('hesitant')) {
      return Colors.orange;
    }
    
    // Olumsuz duygular (kırmızı tonlar)
    if (lowerDuygu.contains('olumsuz') || 
        lowerDuygu.contains('soğuk') || 
        lowerDuygu.contains('negative') ||
        lowerDuygu.contains('cold') ||
        lowerDuygu.contains('aggressive') ||
        lowerDuygu.contains('agresif')) {
      return Colors.red.shade300;
    }
    
    // Diğer renkler
    switch (lowerDuygu) {
      case 'flörtöz':
        return Colors.pink;
      case 'çekingen':
        return Colors.amber;
      case 'gergin':
      case 'endişeli':
        return Colors.red;
      case 'yoğun':
        return Colors.purple;
      default:
        return Colors.blueGrey; // varsayılan renk
    }
  }
} 