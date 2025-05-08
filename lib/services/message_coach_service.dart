import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/message_coach_analysis.dart';
import '../models/message_coach_visual_analysis.dart';
import '../models/past_message_coach_analysis.dart';
import 'logger_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'ocr_service.dart';

class MessageCoachService {
  final LoggerService _logger = LoggerService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _messageCoachCollection = 'message_coach_history';
  
  // Gemini API anahtarını ve ayarlarını .env dosyasından alma
  String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get _geminiModel => dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.0-flash';
  int get _geminiMaxTokens => int.tryParse(dotenv.env['GEMINI_MAX_TOKENS'] ?? '1024') ?? 1024;
  
  // API anahtarını kontrol et ve tam URL'i hazırla
  String _getApiUrl() {
    final apiKey = _geminiApiKey;
    if (apiKey.isEmpty) {
      _logger.e('Gemini API anahtarı bulunamadı. .env dosyasını kontrol edin.');
      throw Exception('API anahtarı eksik veya geçersiz. Lütfen .env dosyasını kontrol edin ve GEMINI_API_KEY değerini ayarlayın.');
    }
    
    final model = _geminiModel;
    if (model.isEmpty) {
      _logger.e('Gemini model adı bulunamadı. .env dosyasını kontrol edin.');
      throw Exception('Model adı eksik veya geçersiz. Lütfen .env dosyasını kontrol edin ve GEMINI_MODEL değerini ayarlayın.');
    }
    
    return 'https://generativelanguage.googleapis.com/v1/models/$model:generateContent?key=$apiKey';
  }

  // Sohbeti analiz etme
  Future<MessageCoachAnalysis?> sohbetiAnalizeEt(String sohbetIcerigi) async {
    try {
      _logger.i('Sohbet analizi başlatılıyor...');
      
      // Sohbet içeriğini kontrol etme
      if (sohbetIcerigi.trim().isEmpty) {
        _logger.w('Boş sohbet içeriği, analiz yapılamıyor');
        return null;
      }
      
      // API anahtarını kontrol et ve tam URL oluştur
      String apiUrl;
      try {
        apiUrl = _getApiUrl();
        _logger.i('API URL oluşturuldu ve geçerlilik kontrolü yapıldı');
      } catch (apiError) {
        _logger.e('API URL oluşturulurken hata: $apiError');
        return null;
      }
      
      // Sohbetin uzunluğunu kontrol et
      if (sohbetIcerigi.length > 12000) {
        _logger.w('Sohbet içeriği çok uzun (${sohbetIcerigi.length} karakter). Kısaltılıyor...');
        sohbetIcerigi = "${sohbetIcerigi.substring(0, 12000)}...";
      }
      
      // Analiz için prompt oluşturma
      final prompt = '''
      Kullanıcı mesaj koçu sayfasında bir sohbet geçmişini gönderdi.
      Bu sadece Mesaj Koçu analizine özeldir ve başka bir analizle (ilişki analizi gibi) bağlantılı değildir.

      Görevin:
      1. Sohbetin genel havasını analiz etmek: soğukluk, samimiyet, pasif-agresiflik, ilgisizlik gibi.
      2. Son mesaja ayrıca özel bir analiz yapmak.
      3. Küstah, dürüst ve doğrudan yorumlar vermek.
      4. Kullanıcının mesajı üzerinden net, yüzdesel bir etki tahmini yapmak: (% sempati, % kararsızlık, % olumsuzluk gibi).
      5. Gerekirse doğrudan kısa bir cevap önerisinde bulunmak.

      ÖNEMLİ:
      - Her durumda mutlaka analiz yap, içerik ne kadar az olursa olsun. "Analiz edilemedi" veya "yetersiz içerik" gibi ifadeler kullanma.
      - Mutlaka küstah ve doğrudan yorumlar yap, nazik olmaktan kaçın.
      - Son mesaj tonu için mutlaka bir değer belirle (Sert/Soğuk/Sempatik/Umursamaz/İlgisiz) ve asla "Analiz edilemedi" deme.

      Kurallar:
      - Sağdaki mesajlar kullanıcıya, soldaki mesajlar karşı tarafa aittir.
      - Sohbet akışı yukarıdan aşağı doğru ilerler.
      - Gereksiz uzun açıklamalara girmeden kısa, açık ve net yorumlar yap.
      - Lafı dolandırmadan yaz. Gerekirse eleştirilerini sert bir dille yap.

      Analiz için sohbet içeriği:
      ```
      $sohbetIcerigi
      ```

      Lütfen aşağıdaki JSON formatında yanıt ver:
      {
        "sohbetGenelHavasi": "(Soğuk/Samimi/Pasif-agresif/İlgisiz)",
        "genelYorum": "(1-2 cümlede kısa, sert ve doğrudan)",
        "sonMesajTonu": "(Sert/Soğuk/Sempatik/Umursamaz/İlgisiz)",
        "sonMesajEtkisi": {
          "sempatik": X,
          "kararsız": Y,
          "olumsuz": Z
        },
        "direktYorum": "(Kısa, net ve gerekiyorsa acımasız bir yorum)",
        "cevapOnerileri": "(İsteğe Bağlı) Doğrudan, kibarlaştırılmamış kısa bir cevap önerisi"
      }

      Önemli: Cevabını SADECE JSON formatında ver, başka açıklama yapma.
      Cevabında "Analiz edilemedi", "yetersiz içerik" veya benzeri ifadeler KULLANMA.
      İçerik ne kadar az olursa olsun mutlaka bir yorum yap ve değerleri doldur.
      ''';
      
      // Gemini API'ye istek gönderme
      final requestBody = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text': prompt
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': _geminiMaxTokens
        }
      });
      
      _logger.d('Sohbet analizi API isteği gönderiliyor');
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );
      
      _logger.d('API yanıtı - status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent == null) {
          _logger.e('AI yanıtı boş veya beklenen formatta değil', data);
          return null;
        }
        
        _logger.d('AI yanıt metni: $aiContent');
        
        // AI yanıtını JSON formatına çevirip analiz nesnesine dönüştürme
        try {
          // JSON içeriğini çıkar - bazen AI yanıtı JSON bloğu dışında açıklama da içerebilir
          final jsonRegExp = RegExp(r'{[\s\S]*}');
          final jsonMatch = jsonRegExp.firstMatch(aiContent);
          
          if (jsonMatch == null) {
            _logger.e('JSON formatı bulunamadı', aiContent);
            return null;
          }
          
          final jsonStr = jsonMatch.group(0);
          if (jsonStr == null) {
            _logger.e('JSON içeriği çıkarılamadı', aiContent);
            return null;
          }
          
          Map<String, dynamic> analysisData;
          try {
            analysisData = jsonDecode(jsonStr);
          } catch (jsonError) {
            _logger.e('JSON decode hatası: $jsonError', jsonStr);
            // JSON decode hatası durumunda, düzeltme denemesi yap
            final cleanedJsonStr = _jsonuDuzelt(jsonStr);
            try {
              analysisData = jsonDecode(cleanedJsonStr);
            } catch (e) {
              _logger.e('Temizlenmiş JSON dahi decode edilemedi: $e');
              return null;
            }
          }
          
          return MessageCoachAnalysis.from(analysisData);
        } catch (jsonError) {
          _logger.e('AI yanıtını JSON formatına çevirirken hata: $jsonError');
          _logger.e('Hatalı yanıt: $aiContent');
          return null;
        }
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.e('Sohbet analizi hatası', e);
      return null;
    }
  }
  
  // JSON içindeki sorunları düzelten yardımcı metod
  String _jsonuDuzelt(String jsonStr) {
    // İlk olarak gelen string'i logla
    _logger.d('Düzeltilecek JSON: $jsonStr');
    
    // Hatalı şekilde escape edilen tırnak işaretlerini düzelt
    String temiz = jsonStr.replaceAll('\\"', '"').replaceAll('\\\\', '\\');
    
    // Tırnak içindeki çift tırnakları işle (JSON içinde sorun yaratan durum)
    // JSON property değerlerinin içindeki çift tırnakları escape et
    temiz = _jsonIcindekiTirnaklariDuzelt(temiz);
    
    // Gereksiz satır sonlarını ve fazla boşlukları temizle
    temiz = temiz.replaceAll('\\n', ' ');
    temiz = temiz.replaceAll(RegExp(r'\s+'), ' ');
    
    // Düzeltilmiş JSON'ı logla
    _logger.d('Düzeltilmiş JSON: $temiz');
    
    return temiz;
  }
  
  // JSON içindeki tırnakları düzeltme yardımcı metodu
  String _jsonIcindekiTirnaklariDuzelt(String json) {
    // JSON property'lerin değerlerini bulmak için regex
    final propertyValueRegex = RegExp(r'"([^"\\]*(?:\\.[^"\\]*)*)"');
    
    // Regex ile eşleşen değerleri işle
    String sonuc = json;
    final matches = propertyValueRegex.allMatches(json).toList();
    
    // Sondan başlayarak değiştir (pozisyonları korumak için)
    for (int i = matches.length - 1; i >= 0; i--) {
      final match = matches[i];
      
      if (match.groupCount >= 1) {
        final value = match.group(1) ?? '';
        // Değerdeki çift tırnakları escape et
        final duzeltilmisValue = value.replaceAll('"', '\\"');
        
        // Sadece değer içinde çift tırnak varsa değiştir
        if (value != duzeltilmisValue) {
          final start = match.start;
          final end = match.end;
          
          // Değeri değiştir
          sonuc = sonuc.substring(0, start + 1) + 
                  duzeltilmisValue + 
                  sonuc.substring(end - 1);
        }
      }
    }
    
    // Kapanmamış tırnakları düzelt
    sonuc = _kapanmamisTirnaklariKontrolEt(sonuc);
    
    return sonuc;
  }
  
  // Kapanmamış JSON tırnaklarını kontrol et ve düzelt
  String _kapanmamisTirnaklariKontrolEt(String json) {
    try {
      // Basit bir kontrol - JSON parse edilebiliyor mu?
      jsonDecode(json);
      return json; // Sorun yoksa aynı döndür
    } catch (e) {
      // Hata varsa temel yapıyı analiz et ve düzelt
      final bracketCount = _karakterSayisiniSay(json, '{', '}');
      final quoteCount = json.split('"').length - 1;
      
      if (bracketCount != 0) {
        // Kapanmamış süslü parantez var
        if (bracketCount > 0) {
          // Fazla açık süslü parantez
          return json + '}' * bracketCount;
        } else {
          // Fazla kapalı süslü parantez
          return json.substring(0, json.length + bracketCount);
        }
      }
      
      if (quoteCount % 2 != 0) {
        // Tek sayıda tırnak işareti var (kapanmamış tırnak)
        return json + '"';
      }
      
      // Özel karakterlerin escape edilmesi
      String duzeltilmis = json;
      
      // Kontrol karakterleri ve özel karakterleri temizle
      duzeltilmis = duzeltilmis.replaceAll(RegExp(r'[\u0000-\u001F]'), '');
      
      return duzeltilmis;
    }
  }
  
  // Belirli karakterlerin sayısını sayarak açık-kapalı dengesi kontrol et
  int _karakterSayisiniSay(String metin, String acilanKarakter, String kapananKarakter) {
    int acikSayisi = 0;
    int kapaliSayisi = 0;
    
    for (int i = 0; i < metin.length; i++) {
      if (metin[i] == acilanKarakter) {
        acikSayisi++;
      } else if (metin[i] == kapananKarakter) {
        kapaliSayisi++;
      }
    }
    
    return acikSayisi - kapaliSayisi;
  }
  
  // Analiz ifadelerini düzelten yardımcı metod
  void _analizeIfadeleriDuzelt(Map<String, dynamic> data) {
    // "sohbetGenelHavasi" alanı kontrolü ve düzeltmesi
    if (!data.containsKey('sohbetGenelHavasi') || 
        data['sohbetGenelHavasi'] == null || 
        _yetersizIfadeIceriyor(data['sohbetGenelHavasi'].toString())) {
      data['sohbetGenelHavasi'] = 'Samimi';
    }
    
    // "genelYorum" alanı kontrolü ve düzeltmesi
    if (!data.containsKey('genelYorum') || 
        data['genelYorum'] == null ||
        _yetersizIfadeIceriyor(data['genelYorum'].toString())) {
      data['genelYorum'] = 'İletişim tarzının geliştirilmesi gerekiyor. Mesajların çok sıradan ve etkileyici değil.';
    }
    
    // "sonMesajTonu" alanı kontrolü ve düzeltmesi
    if (!data.containsKey('sonMesajTonu') || 
        data['sonMesajTonu'] == null || 
        _yetersizIfadeIceriyor(data['sonMesajTonu'].toString())) {
      data['sonMesajTonu'] = 'Sempatik';
    }
    
    // "direktYorum" alanı kontrolü ve düzeltmesi
    if (!data.containsKey('direktYorum') || 
        data['direktYorum'] == null || 
        _yetersizIfadeIceriyor(data['direktYorum'].toString())) {
      data['direktYorum'] = 'Mesajların zayıf ve ilgi çekici değil. Daha net ve etkileyici bir iletişim kurmalısın.';
    }
    
    // "cevapOnerileri" alanı kontrolü ve düzeltmesi
    if (!data.containsKey('cevapOnerileri') || 
        data['cevapOnerileri'] == null || 
        !_listeyeCevrilebilir(data['cevapOnerileri'])) {
      data['cevapOnerileri'] = [
        'Seninle açıkça konuşmak istiyorum. Ne düşündüğünü bilmek istiyorum.',
        'Konuşmamız benim için önemli, devam edelim.',
        'Anladım, şimdi ne yapabiliriz?'
      ];
    } else if (data['cevapOnerileri'] is String) {
      // String ise listeye çevir
      data['cevapOnerileri'] = [data['cevapOnerileri']];
    }
    
    // "sonMesajEtkisi" alanı kontrolü ve düzeltmesi
    if (!data.containsKey('sonMesajEtkisi') || 
        data['sonMesajEtkisi'] == null || 
        data['sonMesajEtkisi'] is! Map) {
      data['sonMesajEtkisi'] = {
        'sempatik': 50,
        'kararsız': 30,
        'olumsuz': 20
      };
    } else {
      // Var olan sonMesajEtkisi'ni doğrula
      final Map<String, dynamic> etkiMap = Map<String, dynamic>.from(data['sonMesajEtkisi']);
      final Map<String, int> normalizeEtki = {};
      
      // Değeri olmayan etkiler için varsayılan ekle
      if (!etkiMap.containsKey('sempatik')) {
        normalizeEtki['sempatik'] = 40;
      }
      if (!etkiMap.containsKey('kararsız')) {
        normalizeEtki['kararsız'] = 30;
      }
      if (!etkiMap.containsKey('olumsuz')) {
        normalizeEtki['olumsuz'] = 30;
      }
      
      // String değerli etkileri sayıya çevir
      etkiMap.forEach((key, value) {
        if (value is int) {
          normalizeEtki[key] = value;
        } else if (value is double) {
          normalizeEtki[key] = value.toInt();
        } else if (value is String) {
          // Sayısal değer içeren string'i int'e çevir
          final temiz = value.toString().replaceAll(RegExp(r'[^\d]'), '');
          normalizeEtki[key] = temiz.isNotEmpty ? int.tryParse(temiz) ?? 33 : 33;
        } else {
          normalizeEtki[key] = 33; // Varsayılan değer
        }
      });
      
      data['sonMesajEtkisi'] = normalizeEtki;
    }
  }
  
  // Bir ifadenin "yetersiz" veya "analiz edilemedi" gibi ifadeler içerip içermediğini kontrol eder
  bool _yetersizIfadeIceriyor(String ifade) {
    final String kucukIfade = ifade.toLowerCase();
    return kucukIfade.contains('analiz edilemedi') || 
           kucukIfade.contains('yetersiz içerik') || 
           kucukIfade.contains('belirlenemedi') ||
           kucukIfade.contains('henüz analiz') ||
           kucukIfade == 'null' ||
           ifade.isEmpty;
  }

  // Bir değerin listeye çevrilebilir olup olmadığını kontrol eder
  bool _listeyeCevrilebilir(dynamic deger) {
    return deger is List || 
           (deger is String && deger.isNotEmpty && !_yetersizIfadeIceriyor(deger));
  }

  /// Mesaj koçu için görüntüden alınan metni ve kullanıcı açıklamasını analiz eder
  Future<MessageCoachVisualAnalysis?> sohbetGoruntusunuAnalizeEt(File gorsel, String aciklama) async {
    try {
      _logger.i('Mesaj koçu görsel analizi başlatılıyor');
      
      // API URL'i hazırla
      final String apiUrl = _getApiUrl();
      
      // Kontrolsüz metin uzunluğu hatalarını önlemek için
      if (aciklama.length > 500) {
        aciklama = "${aciklama.substring(0, 500)}...";
        _logger.w('Açıklama çok uzun, kısaltıldı');
      }
      
      // 1. Görselden OCR ile metni çıkar
      _logger.i('Görselden OCR ile metin çıkarılıyor...');
      final OCRService ocrService = OCRService();
      final String? ocrMetni = await ocrService.extractTextFromImage(gorsel);
      
      if (ocrMetni == null || ocrMetni.isEmpty) {
        _logger.e('Görselden metin çıkarılamadı');
        return MessageCoachVisualAnalysis.hata('Görselden metin çıkarılamadı');
      }
      
      _logger.i('OCR ile metin çıkarma tamamlandı: ${ocrMetni.length} karakter');
      
      // Görsel bytes'larını base64'e çevir
      final gorselBytes = await gorsel.readAsBytes();
      final gorselBase64 = base64Encode(gorselBytes);
      
      // 2. OCR metni ve açıklama içeren prompt oluştur
      final prompt = '''
      Aşağıda bir sohbet ekran görüntüsünün OCR ile çıkarılmış metni yer almaktadır:
      
      """
      $ocrMetni
      """
      
      Yukarıdaki metinde "Kullanıcı:" ile başlayan mesajlar ekranın sağında, "Partner:" ile başlayan mesajlar ekranın solunda yer almaktadır. Bu, bir mesajlaşma uygulamasından alınan ekran görüntüsüdür.

      Bu sohbetin bağlamını ve tarafların tavırlarını analiz et. Ayrıca aşağıdaki kullanıcı açıklamasını değerlendir:

      "Açıklama: $aciklama"

      ÖNEMLİ: Yanıtın doğrudan kullanıcıya hitap eden bir şekilde olmalı. "Kullanıcı şunu yapmalı" veya "Karşı taraf böyle düşünüyor" gibi ÜÇÜNCÜ ŞAHIS ANLATIMI KULLANMA. 
      Bunun yerine "Mesajlarında şunu görebiliyorum", "Bu durumda şunları yazabilirsin", "Şu mesajı gönderirsen..." gibi DOĞRUDAN KULLANICIYA HİTAP ET.

      Yanıtın dobra, yer yer alaycı ama mantıklı olsun. Sadece görselden elde ettiğin sohbet bağlamına ve kullanıcının açıklamasına göre değerlendirme yap.
      
      Görevin:
      1. Sohbetin mevcut durumunu değerlendirmek.
      2. Kullanıcıya ne yazması gerektiğine dair alternatif mesajlar önermek.
      3. Olası yanıtları tahmin etmek.
      
      KURALLAR:
      - Doğrudan kullanıcıya seslenmelisin, asla üçüncü şahıs anlatımı kullanmamalısın.
      - Eğer görselde sohbet yerine başka bir içerik varsa veya OCR sağlıklı çalışmamışsa, kullanıcıyı yeniden yönlendir.
      - Sohbet eğer ciddi bir konu içeriyorsa (örn. duygusal bir kriz, tehdit, şiddet, intihar düşüncesi, vs.), kullanıcıyı Analiz bölümüne yönlendir.
      - Görsel ve açıklamaya dayanarak sohbetin durumunu mutlaka analiz et ve bir yanıt oluştur.
      - Yüzeysel olmaktan kaçın, ama ahlaki öğütler vermekten de kaçın.

      Lütfen aşağıdaki JSON formatında yanıt ver:
      {
        "isAnalysisRedirect": false, // Eğer kullanıcı Analiz bölümüne yönlendirilmeli ise true, değilse false
        "redirectMessage": null, // isAnalysisRedirect true ise, yönlendirme mesajı, değilse null
        "konumDegerlendirmesi": "Sohbetin şu anki durumunun analizi ve kullanıcıya ne yapması gerektiğini doğrudan hitap eden şekilde",
        "alternativeMessages": [
          "Öneri 1",
          "Öneri 2",
          "Öneri 3"
        ],
        "partnerResponses": [
          "Olumlu yanıt senaryosu",
          "Olumsuz yanıt senaryosu"
        ]
      }
      
      Önemli: Cevabını SADECE JSON formatında ver, başka açıklama yapma.
      ''';
      
      // Gemini API'ye istek gönderme
      final requestBody = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text': prompt
              },
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': gorselBase64
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': _geminiMaxTokens
        }
      });
      
      _logger.d('Sohbet görüntüsü analizi API isteği gönderiliyor');
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );
      
      _logger.d('API yanıtı - status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent == null) {
          _logger.e('AI yanıtı boş veya beklenen formatta değil', data);
          return MessageCoachVisualAnalysis.hata('AI yanıtı oluşturulamadı');
        }
        
        _logger.d('AI yanıt metni: $aiContent');
        
        // AI yanıtını JSON formatına çevirip analiz nesnesine dönüştürme
        try {
          // JSON içeriğini çıkar - bazen AI yanıtı JSON bloğu dışında açıklama da içerebilir
          final jsonRegExp = RegExp(r'{[\s\S]*}');
          final jsonMatch = jsonRegExp.firstMatch(aiContent);
          
          if (jsonMatch == null) {
            _logger.e('JSON formatı bulunamadı', aiContent);
            return MessageCoachVisualAnalysis.hata('Yanıt uygun formatta değil');
          }
          
          final jsonStr = jsonMatch.group(0);
          if (jsonStr == null) {
            _logger.e('JSON içeriği çıkarılamadı', aiContent);
            return MessageCoachVisualAnalysis.hata('Yanıt içeriği okunamadı');
          }
          
          Map<String, dynamic> analysisData;
          try {
            analysisData = jsonDecode(jsonStr);
          } catch (jsonError) {
            _logger.e('JSON decode hatası: $jsonError', jsonStr);
            // JSON decode hatası durumunda, düzeltme denemesi yap
            final cleanedJsonStr = _jsonuDuzelt(jsonStr);
            try {
              analysisData = jsonDecode(cleanedJsonStr);
            } catch (e) {
              _logger.e('Temizlenmiş JSON dahi decode edilemedi: $e');
              return MessageCoachVisualAnalysis.hata('Yanıt formatı işlenemedi');
            }
          }
          
          // Analiz nesnesini oluştur
          final isAnalysisRedirect = analysisData['isAnalysisRedirect'] == true;
          final redirectMessage = analysisData['redirectMessage'] as String?;
          final konumDegerlendirmesi = analysisData['konumDegerlendirmesi'] as String?;
          
          // Alternatif mesajlar
          List<String> alternativeMessages = [];
          if (analysisData['alternativeMessages'] != null) {
            if (analysisData['alternativeMessages'] is List) {
              alternativeMessages = (analysisData['alternativeMessages'] as List)
                  .map((item) => item.toString())
                  .toList();
            } else if (analysisData['alternativeMessages'] is String) {
              alternativeMessages = [analysisData['alternativeMessages'] as String];
            }
          }
          
          // Partner yanıtları
          List<String> partnerResponses = [];
          if (analysisData['partnerResponses'] != null) {
            if (analysisData['partnerResponses'] is List) {
              partnerResponses = (analysisData['partnerResponses'] as List)
                  .map((item) => item.toString())
                  .toList();
            } else if (analysisData['partnerResponses'] is String) {
              partnerResponses = [analysisData['partnerResponses'] as String];
            }
          }
          
          return MessageCoachVisualAnalysis(
            isAnalysisRedirect: isAnalysisRedirect,
            redirectMessage: redirectMessage,
            konumDegerlendirmesi: konumDegerlendirmesi,
            alternativeMessages: alternativeMessages,
            partnerResponses: partnerResponses,
          );
          
        } catch (jsonError) {
          _logger.e('AI yanıtını işlerken hata: $jsonError');
          _logger.e('Hatalı yanıt: $aiContent');
          return MessageCoachVisualAnalysis.hata('Yanıt işlenirken hata oluştu');
        }
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return MessageCoachVisualAnalysis.hata('API Hatası: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Sohbet görüntüsü analizi hatası', e);
      return MessageCoachVisualAnalysis.hata('İşlem hatası: $e');
    }
  }
  
  // Firebase Storage'a dosya yükleme
  Future<String> fileUploadToStorage({
    required File dosya,
    required String klasor,
    required String userId,
  }) async {
    try {
      _logger.i('$klasor klasörüne dosya yükleniyor: ${dosya.path}');
      
      final FirebaseStorage storage = FirebaseStorage.instance;
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'mesaj_kocu_${userId}_$timestamp';
      
      final storageRef = storage.ref().child('$klasor/$fileName');
      final uploadTask = storageRef.putFile(dosya);
      final snapshot = await uploadTask.whenComplete(() => null);
      
      final downloadUrl = await snapshot.ref.getDownloadURL();
      _logger.i('Dosya başarıyla yüklendi. URL: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      _logger.e('Dosya yükleme hatası', e);
      throw Exception('Dosya yüklenirken hata oluştu: $e');
    }
  }

  // Mesaj koçu analiz sonuçlarını kaydetme
  Future<String> saveMessageCoachAnalysis({
    required String userId,
    required String sohbetIcerigi,
    required MessageCoachAnalysis analysis,
    String? aciklama,
    String? imageUrl,
  }) async {
    try {
      _logger.i('Mesaj koçu analizi kaydediliyor...');
      
      final docRef = await _firestore.collection(_messageCoachCollection).add({
        'userId': userId,
        'createdAt': Timestamp.now(),
        'sohbetIcerigi': sohbetIcerigi,
        'aciklama': aciklama ?? '',
        'imageUrl': imageUrl,
        'isVisualAnalysis': imageUrl != null,
        'analysisData': analysis.toFirestore(),
      });
      
      _logger.i('Mesaj koçu analizi kaydedildi. ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      _logger.e('Mesaj koçu analizi kaydederken hata oluştu', e);
      return '';
    }
  }
  
  // Görsel analizi kaydetme
  Future<String> saveVisualMessageCoachAnalysis({
    required String userId,
    required String aciklama,
    required MessageCoachVisualAnalysis analysis,
    String? imageUrl,
  }) async {
    try {
      _logger.i('Görsel mesaj koçu analizi kaydediliyor...');
      
      final docRef = await _firestore.collection(_messageCoachCollection).add({
        'userId': userId,
        'createdAt': Timestamp.now(),
        'sohbetIcerigi': '', // Görsel analiz olduğundan boş
        'aciklama': aciklama,
        'isVisualAnalysis': true,
        'imageUrl': imageUrl,
        'analysisData': {
          'isAnalysisRedirect': analysis.isAnalysisRedirect,
          'redirectMessage': analysis.redirectMessage,
          'konumDegerlendirmesi': analysis.konumDegerlendirmesi,
          'alternativeMessages': analysis.alternativeMessages,
          'partnerResponses': analysis.partnerResponses,
        },
      });
      
      _logger.i('Görsel mesaj koçu analizi kaydedildi. ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      _logger.e('Görsel mesaj koçu analizi kaydederken hata oluştu', e);
      return '';
    }
  }
  
  // Kullanıcının mesaj koçu geçmişini getirme
  Future<List<PastMessageCoachAnalysis>> getUserMessageCoachHistory(String userId) async {
    try {
      _logger.i('Kullanıcının mesaj koçu geçmişi getiriliyor: $userId');
      
      final querySnapshot = await _firestore
          .collection(_messageCoachCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      final results = querySnapshot.docs.map((doc) => 
          PastMessageCoachAnalysis.fromFirestore(doc)).toList();
      
      _logger.i('${results.length} adet mesaj koçu analizi bulundu.');
      return results;
    } catch (e) {
      _logger.e('Mesaj koçu geçmişi getirilirken hata oluştu', e);
      return [];
    }
  }
  
  // Mesaj koçu geçmişini temizleme
  Future<void> clearMessageCoachHistory(String userId) async {
    try {
      _logger.i('Kullanıcının mesaj koçu geçmişi temizleniyor: $userId');
      
      final querySnapshot = await _firestore
          .collection(_messageCoachCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      _logger.i('Silinecek mesaj koçu analiz sayısı: ${querySnapshot.docs.length}');
      
      if (querySnapshot.docs.isEmpty) {
        _logger.i('Silinecek mesaj koçu analizi bulunamadı.');
        return;
      }
      
      // Batch kullanarak toplu silme
      final WriteBatch batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      _logger.i('${querySnapshot.docs.length} adet mesaj koçu analizi silindi.');
      
      // Silme işleminin tamamlanması için 2 saniye bekleme
      await Future.delayed(const Duration(seconds: 2));
      
      // Doğrulama kontrolü
      final verificationQuery = await _firestore
          .collection(_messageCoachCollection)
          .where('userId', isEqualTo: userId)
          .get();
          
      if (verificationQuery.docs.isNotEmpty) {
        _logger.w('Silme işlemi tamamlanmasına rağmen ${verificationQuery.docs.length} adet analiz hala mevcut. Tekrar silme deneniyor...');
        
        // İkinci kez silme girişimi
        final secondBatch = _firestore.batch();
        for (var doc in verificationQuery.docs) {
          secondBatch.delete(doc.reference);
        }
        
        await secondBatch.commit();
        _logger.i('İkinci silme işlemi tamamlandı.');
      } else {
        _logger.i('Silme işlemi doğrulandı, tüm veriler başarıyla silindi.');
      }
      
    } catch (e) {
      _logger.e('Mesaj koçu geçmişi temizlenirken hata oluştu', e);
    }
  }
} 