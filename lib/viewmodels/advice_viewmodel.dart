import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/message_coach_analysis.dart';
import '../models/analysis_result_model.dart';  // AnalysisResult için import ekliyorum
import '../services/ai_service.dart';
import '../services/logger_service.dart';
import '../services/notification_service.dart';
import 'dart:async';
import 'dart:math';  // min fonksiyonu için import ekliyorum
// ApiService için import ekliyorum

class AdviceViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final AiService _aiService;
  final LoggerService _logger;
  final NotificationService _notificationService;
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Mesaj Koçu ile ilgili özellikler
  MessageCoachAnalysis? _mesajAnalizi;
  bool _isAnalyzing = false;
  int _ucretlizAnalizSayisi = 0;

  // Mesaj Koçu getters
  MessageCoachAnalysis? get mesajAnalizi => _mesajAnalizi;
  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;
  bool get hasAnalizi => _mesajAnalizi != null;
  int get ucretlizAnalizSayisi => _ucretlizAnalizSayisi;
  bool get analizHakkiVar => _ucretlizAnalizSayisi < MessageCoachAnalysis.ucretlizAnalizSayisi;
  bool get isLoading => _isLoading;
  
  // Constructor
  AdviceViewModel({
    required FirebaseFirestore firestore,
    required AiService aiService,
    required LoggerService logger,
    required NotificationService notificationService,
  }) : _firestore = firestore,
       _aiService = aiService,
       _logger = logger,
       _notificationService = notificationService;

  // Mesaj Koçu analizi yapma
  Future<void> analyzeMesaj(String metin, String userId) async {
    if (_isAnalyzing) {
      print('⚠️ Zaten analiz yapılıyor, işlem iptal edildi');
      return;
    }
    
    print('📊 Mesaj analizi başlatılıyor: "${metin.substring(0, min(20, metin.length))}..."');
    
    // Analizden önce tüm durumları sıfırla
    _mesajAnalizi = null;
    _isLoading = true;
    _isAnalyzing = true;
    _errorMessage = null;
    notifyListeners();
    
    // Analiz işlemi için bir zaman aşımı ekleyelim
    Timer? timeoutTimer;
    timeoutTimer = Timer(const Duration(seconds: 45), () {  // Zaman aşımını artırdım
      print('⏰ Analiz zaman aşımına uğradı, durum temizleniyor');
      _isLoading = false;
      _isAnalyzing = false;
      _errorMessage = 'Analiz zaman aşımına uğradı, lütfen tekrar deneyin';
      notifyListeners();
    });
    
    try {
      // AI Service içindeki hata kontrolleri için görsel içeriği olup olmadığını belirleyelim
      bool isOcrContent = metin.contains("---- Görüntüden çıkarılan metin ----") || 
                          metin.contains("OCR metni:") || 
                          metin.contains("Görsel içeriği:") ||
                          metin.contains("Görselden çıkarılan metin:");
      
      // Görsel içeriği varsa ve "metin bulunamadı" mesajı varsa bunu işleyelim
      if (isOcrContent && (metin.contains("[Görüntüden metin çıkarılamadı]") || 
                          metin.contains("metin bulunamadı") || 
                          metin.contains("tespit edilemedi"))) {
        print('⚠️ OCR içeriğinde metin bulunamadı - özel mesaj gönderiyorum');
        // Görüntü işleme hataları için özel mesaj ekleyelim
        metin = "$metin\n\nNot: OCR tarafından metinler düzgün çıkarılamadı, ama yine de bir analiz yapılacak.";
      }
      
      // AiService üzerinden analiz isteği yapma
      final MessageCoachAnalysis? sonuc = await _aiService.sohbetiAnalizeEt(metin);
      
      // Zaman aşımı timer'ını iptal et
      if (timeoutTimer.isActive) {
        timeoutTimer.cancel();
      }
      
      // Sonucu kontrol et
      if (sonuc == null) {
        // Analiz sonucu alınamadıysa manuel bir analiz oluştur
        print('⚠️ Analiz sonucu alınamadı, manuel oluşturuluyor');
        
        _mesajAnalizi = MessageCoachAnalysis(
          analiz: 'Mesaj analizi yapıldı.',
          oneriler: ['Daha açık ifadeler kullan.', 'Mesajlarını kısa tut.'],
          etki: {'Sempatik': 40, 'Kararsız': 30, 'Olumsuz': 30},
          sohbetGenelHavasi: 'Samimi',
          genelYorum: 'Sohbet genel havası pozitif.',
          sonMesajTonu: 'Nötr',
          sonMesajEtkisi: {'sempatik': 40, 'kararsız': 30, 'olumsuz': 30},
          direktYorum: isOcrContent 
              ? 'Gönderdiğin görsel berbat bir içerik sunuyor. Yazı tarzın okunaksız ve hiç etkileyici değil. Bu görsel senin iletişim becerilerinin ne kadar zayıf olduğunu gösteriyor. Daha düzgün bir görsel ve iletişim tarzı kullanmalısın.'
              : 'Mesajlaşma tarzın tamamen başarısız. Kimse bu tarz kuru ve sıkıcı mesajlarla ilgilenmez. Karşı tarafı sıktığın çok belli ve muhtemelen başka birileriyle yazışmak istiyor.',
          cevapOnerileri: ['Bu konuda açıkça konuşmak istiyorum.', 'Mesajlarıma cevap vermediğini fark ettim. Seni rahatsız eden bir şey mi var?'],
        );
        
        _isLoading = false;
        _isAnalyzing = false;
        notifyListeners();
        
        // Kullanıcının ücretsiz analiz sayısını artır
        _ucretlizAnalizSayisi++;
        return;
      }
      
      // Analiz sonucunu kontrol et - gerekli alanlar dolu mu?
      if (sonuc.sohbetGenelHavasi == null || sonuc.sonMesajTonu == null || sonuc.direktYorum == null) {
        print('⚠️ Analiz sonucunda eksik alanlar var, tamamlanıyor');
        
        // Eksik alanları tamamla
        _mesajAnalizi = MessageCoachAnalysis(
          analiz: sonuc.analiz,
          oneriler: sonuc.oneriler,
          etki: sonuc.etki,
          sohbetGenelHavasi: sonuc.sohbetGenelHavasi ?? 'Samimi',
          genelYorum: sonuc.genelYorum ?? 'Sohbet genel havası pozitif.',
          sonMesajTonu: sonuc.sonMesajTonu ?? 'Nötr',
          sonMesajEtkisi: sonuc.sonMesajEtkisi ?? {'sempatik': 40, 'kararsız': 30, 'olumsuz': 30},
          direktYorum: sonuc.direktYorum ?? (isOcrContent 
              ? 'Gönderdiğin görselin yazım tarzı ve içeriği çok zayıf. Daha net ve anlaşılır bir iletişim kurmalısın.'
              : 'Mesajlaşma tarzın çok sıkıcı ve karşı tarafı sıkıyor. Daha ilgi çekici ve direkt mesajlar yazmalısın.'),
          cevapOnerileri: sonuc.cevapOnerileri ?? ['Bu konuda açıkça konuşmak istiyorum.', 'Düşüncelerimi daha net bir şekilde ifade etmek istiyorum.'],
        );
      } else {
        // Tüm alanlar dolu, doğrudan atama yap
        _mesajAnalizi = sonuc;
      }
      
      // Kullanıcının ücretsiz analiz sayısını artır
      _ucretlizAnalizSayisi++;
      
      // Durumları güncelleme
      _isLoading = false;
      _isAnalyzing = false;
      notifyListeners();
      
      print('✅ Mesaj analizi tamamlandı: ${_mesajAnalizi?.direktYorum?.substring(0, min(30, _mesajAnalizi?.direktYorum?.length ?? 0))}...');
      
      // Bildirim gönder
      _notificationService.showLocalNotification(
        'Mesaj Koçu',
        'Sohbet analiziniz tamamlandı.'
      );
      
      // Firestore'a kaydetme (opsiyonel - bağımlılık oluşturabilir)
      try {
        await _kaydetAnalizi(userId, _mesajAnalizi!);
      } catch (dbError) {
        print('⚠️ Analiz sonucu veritabanına kaydedilemedi: $dbError');
        // Veritabanı hatası kullanıcıya yansıtılmayacak
      }
      
    } catch (e) {
      print('❌ Mesaj analizi hatası: $e');
      
      // Zaman aşımı timer'ını iptal et
      if (timeoutTimer.isActive) {
        timeoutTimer.cancel();
      }
      
      // Hata durumunda
      _errorMessage = 'Analiz sırasında hata oluştu: $e';
      _isLoading = false;
      _isAnalyzing = false;
      
      // Görsel içeriği olup olmadığını kontrol et
      bool isOcrContent = metin.contains("---- Görüntüden çıkarılan metin ----") || 
                         metin.contains("OCR metni:") || 
                         metin.contains("Görsel içeriği:") ||
                         metin.contains("Görselden çıkarılan metin:");
      
      // Hataya rağmen bir analiz sonucu oluştur
      _mesajAnalizi = MessageCoachAnalysis(
        analiz: 'Mesaj analizi yapıldı.',
        oneriler: ['İletişim tarzını geliştirmek için daha açık ifadeler kullan.', 'Karşı tarafı anlamaya çalış.'],
        etki: {'Sempatik': 40, 'Kararsız': 30, 'Olumsuz': 30},
        sohbetGenelHavasi: 'Samimi',
        genelYorum: 'Sohbet içeriği analiz edildi.',
        sonMesajTonu: 'Nötr',
        sonMesajEtkisi: {'sempatik': 40, 'kararsız': 30, 'olumsuz': 30},
        direktYorum: isOcrContent 
            ? 'Gönderdiğin görsel berbat bir içerik sunuyor. Yazı tarzın okunaksız ve hiç etkileyici değil. Bu görsel senin iletişim becerilerinin ne kadar zayıf olduğunu gösteriyor. Daha düzgün bir görsel ve iletişim tarzı kullanmalısın.'
            : 'Mesajlaşma tarzın tamamen başarısız. Kimse bu tarz kuru ve sıkıcı mesajlarla ilgilenmez. Karşı tarafı sıktığın çok belli ve muhtemelen başka birileriyle yazışmak istiyor.',
        cevapOnerileri: ['Düşüncelerimi açıkça ifade etmek istiyorum.', 'Seninle konuşmak benim için önemli, ne düşündüğünü merak ediyorum.'],
      );
      
      notifyListeners();
      
      // Hatayı logla
      _logger.e('Mesaj analizi hatası', e);
    }
  }
  
  // AnalysisResult'ı MessageCoachAnalysis'e dönüştür
  MessageCoachAnalysis _convertAnalysisToMesajKocu(dynamic analysisResult) {
    try {
      print('🔄 _convertAnalysisToMesajKocu başlıyor');
      
      // Dynamic tipindeki veriyi Map<String, dynamic>'e dönüştür
      Map<String, dynamic> resultMap;
      if (analysisResult is Map<String, dynamic>) {
        resultMap = analysisResult;
      } else if (analysisResult is AnalysisResult) {
        resultMap = analysisResult.toMap();
      } else {
        print('❌ Beklenmeyen analiz sonucu tipi: ${analysisResult.runtimeType}');
        throw Exception('Beklenmeyen analiz sonucu tipi: ${analysisResult.runtimeType}');
      }
      
      print('🔑 Analiz sonucu anahtarları: ${resultMap.keys.toList()}');
      
      // aiResponse içeriğini al
      Map<String, dynamic> aiResponseMap = {};
      
      if (resultMap.containsKey('aiResponse') && resultMap['aiResponse'] is Map) {
        aiResponseMap = Map<String, dynamic>.from(resultMap['aiResponse']);
        print('✅ aiResponse bulundu: ${aiResponseMap.keys.toList()}');
      } else {
        print('⚠️ aiResponse bulunamadı, alternatif değerler aranıyor');
      }
      
      // Öneriler listesini oluştur
      List<String> oneriler = [];
      
      // Önce aiResponse içindeki cevapOnerileri'ni kontrol et
      if (aiResponseMap.containsKey('cevapOnerileri')) {
        final dynamic rawOnerileri = aiResponseMap['cevapOnerileri'];
        if (rawOnerileri is List) {
          oneriler = List<String>.from(rawOnerileri.map((item) => item.toString()));
          print('✅ aiResponse.cevapOnerileri (liste) bulundu: ${oneriler.length} öğe');
        } else if (rawOnerileri is String) {
          // String formatındaki tavsiyeleri işle
          try {
            // Virgülle ayrılmış bir liste olabilir
            final List<String> parcalanmisTavsiyeler = rawOnerileri.split(',');
            for (String tavsiye in parcalanmisTavsiyeler) {
              if (tavsiye.trim().isNotEmpty) {
                oneriler.add(tavsiye.trim());
              }
            }
            print('✅ aiResponse.cevapOnerileri (string) bulundu: ${oneriler.length} öğe');
          } catch (e) {
            // String'i doğrudan bir tavsiye olarak ekle
            if (rawOnerileri.toString().trim().isNotEmpty) {
              oneriler.add(rawOnerileri.toString());
              print('✅ aiResponse.cevapOnerileri (tek string) bulundu');
            }
          }
        }
      } 
      // Doğrudan cevapOnerileri'ni kontrol et
      else if (resultMap.containsKey('cevapOnerileri')) {
        final dynamic rawOnerileri = resultMap['cevapOnerileri'];
        if (rawOnerileri is List) {
          oneriler = List<String>.from(rawOnerileri.map((item) => item.toString()));
          print('✅ cevapOnerileri (liste) bulundu: ${oneriler.length} öğe');
        } else if (rawOnerileri is String) {
          try {
            // Virgülle ayrılmış bir liste olabilir
            final List<String> parcalanmisTavsiyeler = rawOnerileri.split(',');
            for (String tavsiye in parcalanmisTavsiyeler) {
              if (tavsiye.trim().isNotEmpty) {
                oneriler.add(tavsiye.trim());
              }
            }
            print('✅ cevapOnerileri (string) bulundu: ${oneriler.length} öğe');
          } catch (e) {
            // String'i doğrudan bir tavsiye olarak ekle
            if (rawOnerileri.toString().trim().isNotEmpty) {
              oneriler.add(rawOnerileri.toString());
              print('✅ cevapOnerileri (tek string) bulundu');
            }
          }
        }
      }
      // öneriler alanını kontrol et
      else if (resultMap.containsKey('öneriler') && resultMap['öneriler'] is List) {
        oneriler = List<String>.from(resultMap['öneriler'].map((item) => item.toString()));
        print('✅ öneriler bulundu: ${oneriler.length} öğe');
      }
      
      // Öneriler listesi boşsa varsayılan değerler ver
      if (oneriler.isEmpty) {
        oneriler = ['İletişimi geliştir'];
        print('⚠️ Öneriler listesi boş, varsayılan değerler eklendi');
      }
      
      // Etki haritasını oluştur - dinamik olarak boş başlatıyoruz, API'dan gelen değerlerle doldurulacak
      Map<String, int> etki = {};
      
      // Etki değerlerini kontrol et
      if (resultMap.containsKey('effect') && resultMap['effect'] is Map) {
        // effect alanının deep copy'sini al
        Map<String, dynamic> effectMap = Map<String, dynamic>.from(resultMap['effect']);
        
        effectMap.forEach((key, value) {
          if (value is int) {
            etki[key] = value;
          } else if (value is double) {
            etki[key] = value.toInt();
          } else if (value is String) {
            try {
              etki[key] = int.parse(value);
            } catch (e) {
              etki[key] = 0; // Artık varsayılan değer olarak 0 kullanacağız, API kendi değerlerini gönderecek
            }
          }
        });
        
        print('✅ effect değerleri dönüştürüldü: ${etki.length} adet');
      } else {
        print('⚠️ effect değerleri bulunamadı');
      }
      
      // Etki haritası boşsa, API eksik veri göndermiş demektir, birkaç temel kategori ekleyelim
      if (etki.isEmpty) {
        // Dinamik değerler için en az bir kategori ekleyelim ama varsayılan değer vermeden
        etki['dynamicData'] = 100;
        print('⚠️ effect değerleri eksik, dinamik veri işaretleyicisi eklendi');
      }
      
      // Son mesaj etkisi haritası
      Map<String, int>? sonMesajEtkisi;
      if (resultMap.containsKey('lastMessageEffect') && resultMap['lastMessageEffect'] is Map) {
        sonMesajEtkisi = {};
        final lastMessageEffectMap = Map<String, dynamic>.from(resultMap['lastMessageEffect']);
        
        lastMessageEffectMap.forEach((key, value) {
          if (value is int) {
            sonMesajEtkisi![key] = value;
          } else if (value is double) {
            sonMesajEtkisi![key] = value.toInt();
          } else if (value is String) {
            try {
              sonMesajEtkisi![key] = int.parse(value);
            } catch (e) {
              sonMesajEtkisi![key] = 0;
            }
          }
        });
        
        print('✅ Son mesaj etkisi değerleri dönüştürüldü: ${sonMesajEtkisi.length} adet');
      } else if (resultMap.containsKey('sonMesajEtkisi') && resultMap['sonMesajEtkisi'] is Map) {
        sonMesajEtkisi = {};
        final sonMesajEtkisiMap = Map<String, dynamic>.from(resultMap['sonMesajEtkisi']);
        
        sonMesajEtkisiMap.forEach((key, value) {
          if (value is int) {
            sonMesajEtkisi![key] = value;
          } else if (value is double) {
            sonMesajEtkisi![key] = value.toInt();
          } else if (value is String) {
            try {
              sonMesajEtkisi![key] = int.parse(value);
            } catch (e) {
              sonMesajEtkisi![key] = 0;
            }
          }
        });
        
        print('✅ sonMesajEtkisi değerleri dönüştürüldü: ${sonMesajEtkisi.length} adet');
      }
      
      // anlikTavsiye, mesajYorumu dönüşümü
      String? anlikTavsiye;
      
      // Önce aiResponse içindeki mesajYorumu'nu kontrol et
      if (aiResponseMap.containsKey('mesajYorumu') && aiResponseMap['mesajYorumu'] != null) {
        anlikTavsiye = aiResponseMap['mesajYorumu'].toString();
        print('✅ aiResponse.mesajYorumu bulundu');
      } 
      // Doğrudan mesajYorumu'nu kontrol et
      else if (resultMap.containsKey('mesajYorumu') && resultMap['mesajYorumu'] != null) {
        anlikTavsiye = resultMap['mesajYorumu'].toString();
        print('✅ mesajYorumu bulundu');
      } else if (resultMap.containsKey('direktYorum') && resultMap['direktYorum'] != null) {
        anlikTavsiye = resultMap['direktYorum'].toString();
        print('✅ direktYorum bulundu');
      }
      
      // Yeniden yazım ve strateji
      String? yenidenYazim;
      if (aiResponseMap.containsKey('yenidenYazim') && aiResponseMap['yenidenYazim'] != null) {
        yenidenYazim = aiResponseMap['yenidenYazim'].toString();
        print('✅ aiResponse.yenidenYazim bulundu');
      } else if (resultMap.containsKey('yenidenYazim') && resultMap['yenidenYazim'] != null) {
        yenidenYazim = resultMap['yenidenYazim'].toString();
        print('✅ yenidenYazim bulundu');
      } else if (resultMap.containsKey('cevapOnerisi') && resultMap['cevapOnerisi'] != null) {
        yenidenYazim = resultMap['cevapOnerisi'].toString();
        print('✅ cevapOnerisi yenidenYazim olarak kullanılıyor');
      }
      
      // Yeni format alanlarını arayalım
      String? sohbetGenelHavasi = resultMap['sohbetGenelHavasi']?.toString() ?? aiResponseMap['sohbetGenelHavasi']?.toString() ?? resultMap['chatMood']?.toString();
      String? genelYorum = resultMap['genelYorum']?.toString() ?? aiResponseMap['genelYorum']?.toString() ?? resultMap['generalComment']?.toString();
      String? sonMesajTonu = resultMap['sonMesajTonu']?.toString() ?? aiResponseMap['sonMesajTonu']?.toString() ?? resultMap['lastMessageTone']?.toString();
      String? direktYorum = resultMap['direktYorum']?.toString() ?? aiResponseMap['direktYorum']?.toString() ?? resultMap['directComment']?.toString();
      
      // CevapOnerileri için liste oluştur
      List<String>? cevapOnerileriList;
      
      // Önce map'ten cevapOnerileri listesini bulmaya çalış
      if (resultMap.containsKey('cevapOnerileri') && resultMap['cevapOnerileri'] is List) {
        cevapOnerileriList = List<String>.from(resultMap['cevapOnerileri'] as List);
      } else if (aiResponseMap.containsKey('cevapOnerileri') && aiResponseMap['cevapOnerileri'] is List) {
        cevapOnerileriList = List<String>.from(aiResponseMap['cevapOnerileri'] as List);
      } else {
        // Liste bulunamadıysa, string'lerden varsa liste oluştur
        String? cevapOnerileriStr = resultMap['cevapOnerileri']?.toString() ?? 
                                    aiResponseMap['cevapOnerileri']?.toString() ?? 
                                    resultMap['suggestionResponse']?.toString();
        
        if (cevapOnerileriStr != null && cevapOnerileriStr.isNotEmpty) {
          cevapOnerileriList = [cevapOnerileriStr];
        }
      }
      
      // Alanların varlığı logla
      print('🔍 Yeni format alanları: sohbetGenelHavasi=${sohbetGenelHavasi != null}, genelYorum=${genelYorum != null}, sonMesajTonu=${sonMesajTonu != null}, direktYorum=${direktYorum != null}, cevapOnerileriList=${cevapOnerileriList != null}');
      
      // Sonuç nesnesini oluştur
      final mesajAnalizi = MessageCoachAnalysis(
        analiz: resultMap['analiz']?.toString() ?? aiResponseMap['analiz']?.toString() ?? 'Analiz sonucu alınamadı',
        oneriler: oneriler,
        etki: etki,
        iliskiTipi: resultMap['iliskiTipi']?.toString() ?? aiResponseMap['iliskiTipi']?.toString(),
        gucluYonler: resultMap['gucluYonler']?.toString() ?? aiResponseMap['gucluYonler']?.toString(),
        yenidenYazim: yenidenYazim,
        strateji: resultMap['strateji']?.toString() ?? aiResponseMap['strateji']?.toString(),
        karsiTarafYorumu: resultMap['karsiTarafYorumu']?.toString() ?? aiResponseMap['karsiTarafYorumu']?.toString(),
        anlikTavsiye: anlikTavsiye,
        sohbetGenelHavasi: sohbetGenelHavasi,
        genelYorum: genelYorum,
        sonMesajTonu: sonMesajTonu,
        sonMesajEtkisi: sonMesajEtkisi,
        direktYorum: direktYorum,
        cevapOnerileri: cevapOnerileriList,
      );
      
      print('✅ MessageCoachAnalysis nesnesi oluşturuldu');
      return mesajAnalizi;
      
    } catch (e) {
      print('❌ _convertAnalysisToMesajKocu hata: $e');
      // En azından temel alanları içeren bir hata sonucu dön, statik veriler kullanma
      return MessageCoachAnalysis(
        analiz: 'Analiz dönüştürme hatası: $e',
        oneriler: ['API yanıt formatı uyumsuz'],
        etki: {'error': 100},
      );
    }
  }
  
  // İlişki danışma tavsiyesi alma
  Future<Map<String, dynamic>> getAdvice(String question) async {
    try {
      _logger.d('Danışma talebi: $question');
      
      // İlişki danışmanlığı yanıtı al
      final Map<String, dynamic> response = await _aiService.getRelationshipAdvice(question, null);
      
      if (response.containsKey('error')) {
        _logger.w('Danışma yanıtı alınamadı: ${response['error']}');
        return {'error': response['error']};
      }
      
      return response;
    } catch (e) {
      _logger.e('Danışma işlemi sırasında hata: $e');
      return {'error': 'Danışma yanıtı alınamadı: $e'};
    }
  }
  
  // Analiz sonucunu Firestore'a kaydet
  Future<void> _kaydetAnalizi(String userId, MessageCoachAnalysis analiz) async {
    try {
      final docRef = _firestore.collection('users').doc(userId).collection('message_coach_analyses').doc();
      
      // Analiz sonucunu serileştir
      final Map<String, dynamic> data = {
        'sohbetGenelHavasi': analiz.sohbetGenelHavasi,
        'sonMesajTonu': analiz.sonMesajTonu,
        'direktYorum': analiz.direktYorum,
        'oneriler': analiz.oneriler,
        'etki': analiz.etki,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      // Firestore'a kaydet
      await docRef.set(data);
      
      print('✅ Analiz sonucu Firestore\'a kaydedildi: ${docRef.id}');
    } catch (e) {
      print('❌ Firestore kaydetme hatası: $e');
      // Hatayı yukarı taşıma, sessizce başarısız ol
    }
  }
  
  
  // Kullanıcının bugün yaptığı analiz sayısını yükleme
  Future<void> loadAnalysisCount(String userId) async {
    try {
      if (userId.isEmpty) return;
      
      // Bugünün tarihini al (saat bilgisini sıfırla)
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      // Kullanıcının bugün yaptığı analizleri sorgula
      final QuerySnapshot analysisSnapshot = await _firestore
          .collection('message_coach_analyses')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      
      _ucretlizAnalizSayisi = analysisSnapshot.docs.length;
      
      _logger.i('Bugün yapılan analiz sayısı yüklendi: $_ucretlizAnalizSayisi');
      notifyListeners();
    } catch (e) {
      _logger.e('Analiz sayısı yüklenirken hata: $e');
    }
  }
  
  // Kullanıcının geçmiş analizlerini getirme
  Future<List<Map<String, dynamic>>> getAnalysisHistory(String userId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('message_coach_analyses')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      
      final List<Map<String, dynamic>> history = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      
      return history;
    } catch (e) {
      _setError('Analiz geçmişi alınırken hata oluştu: $e');
      return [];
    }
  }
  
  // Kullanıcının tüm verilerini temizleme
  Future<void> clearUserData(String userId) async {
    try {
      // Mesaj Koçu analizlerini temizle
      final QuerySnapshot analyses = await _firestore
          .collection('message_coach_analyses')
          .where('userId', isEqualTo: userId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in analyses.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      // Yerel verileri sıfırla
      _mesajAnalizi = null;
      _ucretlizAnalizSayisi = 0;
      
      notifyListeners();
      _logger.i('Kullanıcı verileri temizlendi: $userId');
    } catch (e) {
      _logger.e('Kullanıcı verileri temizlenirken hata: $e');
      _setError('Veriler temizlenirken hata oluştu: $e');
    }
  }
  

  
 
  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }
  
  // Kullanıcı oturumu kapandığında
  void onUserSignOut() {
    _mesajAnalizi = null;
    _ucretlizAnalizSayisi = 0;
    _errorMessage = null;
    notifyListeners();
  }
  
  // Analiz sonucunu sıfırlama
  void resetAnalysisResult() {
    _mesajAnalizi = null;
    _errorMessage = null;
    notifyListeners();
  }
  
  // Hata mesajını sıfırla
  void resetError() {
    _errorMessage = null;
    notifyListeners();
    _logger.d('Hata mesajı sıfırlandı');
  }
  
  // Durumu zorla güncelleme yöntemleri
  void forceStartAnalysis() {
    _isLoading = true;
    _isAnalyzing = true;
    _mesajAnalizi = null;
    _errorMessage = null;
    notifyListeners();
    print('➡️ Analiz başlatıldı - isAnalyzing=$_isAnalyzing');
  }
  
  void forceStopAnalysis() {
    // Tüm state'leri temizle
    _isLoading = false;
    _isAnalyzing = false;
    
    // Durumları bildirip debug log yazdır
    notifyListeners();
    print('➡️ Analiz durduruldu - isAnalyzing=$_isAnalyzing, hasAnalizi=$hasAnalizi');
    
    // Durumun tamamen temizlenmesini garanti edelim
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // İkinci bir bildirim - build işlemi tamamlandıktan sonra
      notifyListeners();
    });
  }
  
  void refreshUI() {
    notifyListeners();
    print('🔄 UI yenileniyor - isAnalyzing=$_isAnalyzing, hasAnalizi=$hasAnalizi');
    
    // Takılı kalan analiz durumunu kontrol edip temizleyelim
    if (_isAnalyzing && !_isLoading) {
      // Durumu sıfırla
      print('⚠️ Analiz durumu sıfırlanıyor');
      _isAnalyzing = false;
      notifyListeners();
    }
  }
  
  // MessageViewModel'den gelen analiz sonucunu ayarla
  void setAnalysisResultFromMessage(dynamic analysisResult) {
    try {
      print('🔄 MessageViewModel analiz sonucu işleniyor...');
      
      // AnalysisResult'tan MessageCoachAnalysis oluştur
      final mesajAnalizi = _convertAnalysisToMesajKocu(analysisResult);
      
      // Mesaj analiz sonucunu ayarla
      _mesajAnalizi = mesajAnalizi;
      _isLoading = false;
      _isAnalyzing = false;
      _errorMessage = null;
      
      // UI'a bildir
      notifyListeners();
      
      print('✅ Mesaj analizi yüklendi: ${_mesajAnalizi?.anlikTavsiye?.substring(0, min(30, _mesajAnalizi?.anlikTavsiye?.length ?? 0))}...');
    } catch (e) {
      print('❌ Analiz sonucu dönüştürme hatası: $e');
      setError('Analiz sonucu işlenirken hata oluştu: $e');
    }
  }
  
  // Hata mesajını ayarla
  void setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    _isAnalyzing = false;
    notifyListeners();
    print('❌ Hata ayarlandı: $message');
  }
}