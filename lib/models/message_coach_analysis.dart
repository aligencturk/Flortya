import 'dart:math';

class MessageCoachAnalysis {
  final String? iliskiTipi;
  final String analiz;
  final String? gucluYonler;
  final List<String> oneriler;
  final Map<String, int> etki;
  final String? yenidenYazim;
  final String? strateji;
  final String? karsiTarafYorumu;
  final String? anlikTavsiye;
  
  // Mesaj koçu analiz alanları
  final String? sohbetGenelHavasi;     // Soğuk/Samimi/Pasif-agresif/İlgisiz/İlgili
  final String? genelYorum;            // Genel bir yorum (1-2 cümle)
  final String? sonMesajTonu;          // Son mesajın tonu
  final Map<String, int>? sonMesajEtkisi; // Son mesaj için etki yüzdeleri
  final String? direktYorum;           // Açık ve küstah tavsiye
  final List<String>? cevapOnerileri;  // Cevap önerileri listesi
  
  // Mesaj koçu için tahmini cevaplar
  final String? olumluCevapTahmini;    // Olumlu yanıt senaryosu
  final String? olumsuzCevapTahmini;   // Olumsuz yanıt senaryosu
  
  // İlk 3 analizi tanımlamak için sabit
  static const int ucretlizAnalizSayisi = 3;

  MessageCoachAnalysis({
    this.iliskiTipi,
    required this.analiz,
    this.gucluYonler,
    required this.oneriler,
    required this.etki,
    this.yenidenYazim,
    this.strateji,
    this.karsiTarafYorumu,
    this.anlikTavsiye,
    this.sohbetGenelHavasi,
    this.genelYorum,
    this.sonMesajTonu,
    this.sonMesajEtkisi,
    this.direktYorum,
    this.cevapOnerileri,
    this.olumluCevapTahmini,
    this.olumsuzCevapTahmini,
  });

  factory MessageCoachAnalysis.from(Map<String, dynamic> json) {
    try {
      // İlişki tipi doğrulama
      String iliskiTipi = json['iliskiTipi'] ?? json['relationType'] ?? 'Arkadaşlık';
      
      // Analiz doğrulama
      String analiz = json['analiz'] ?? json['analysis'] ?? '';
      if (analiz.isEmpty) {
        analiz = 'Analiz için yeterli veri bulunmuyor';
      }
      
      // Güçlü yönler doğrulama
      String gucluYonler = json['gucluYonler'] ?? json['strengths'] ?? '';
      if (gucluYonler.isEmpty) {
        gucluYonler = 'Henüz belirlenmedi';
      }
      
      // Öneriler doğrulama
      List<String> onerileriList = [];
      var onerilerJson = json['oneriler'] ?? json['suggestions'] ?? json['cevapOnerileri'] ?? [];
      if (onerilerJson is List) {
        onerileriList = List<String>.from(onerilerJson.map((item) => item?.toString() ?? '').where((item) => item.isNotEmpty));
      }
      
      // Boş öneriler listesi kontrolü 
      if (onerileriList.isEmpty) {
        onerileriList = ['Daha açık ifadeler kullan.', 'Mesajlarını kısa tut.'];
      }
      
      // Etki doğrulama
      Map<String, int> etkiMap = {};
      var etkiJson = json['etki'] ?? json['effect'] ?? {};
      if (etkiJson is Map) {
        etkiJson.forEach((key, value) {
          if (value is int) {
            etkiMap[key] = value;
          } else if (value is double) {
            etkiMap[key] = value.toInt();
          } else if (value is String) {
            // Sayısal değer içeren string'i int'e çevir
            final numericString = value.replaceAll(RegExp(r'[^\d]'), '');
            etkiMap[key] = numericString.isNotEmpty ? int.tryParse(numericString) ?? 0 : 0;
          }
        });
      }
      
      // Boş etki kontrolü
      if (etkiMap.isEmpty) {
        etkiMap = {'Sempatik': 50, 'Kararsız': 30, 'Olumsuz': 20};
      }
      
      // Yeniden yazım doğrulama
      String? yenidenYazim = json['yenidenYazim'] ?? json['rewrite'];
      
      // Strateji doğrulama
      String strateji = json['strateji'] ?? json['strategy'] ?? '';
      if (strateji.isEmpty) {
        strateji = 'Henüz strateji belirlenmedi';
      }
      
      // Karşı taraf yorumu doğrulama
      String? karsiTarafYorumu = json['karsiTarafYorumu'] ?? json['otherSideComment'];
      
      // Anlık tavsiye doğrulama
      String? anlikTavsiye = json['anlikTavsiye'] ?? json['instantAdvice'];
      
      // Sohbet genel havası doğrulama
      String? sohbetGenelHavasi = json['sohbetGenelHavasi'];
      
      // Sadece API'den açık hata mesajı gelirse düzelt
      if (sohbetGenelHavasi == null || 
          sohbetGenelHavasi.isEmpty || 
          sohbetGenelHavasi.toLowerCase() == 'analiz edilemedi' || 
          sohbetGenelHavasi.toLowerCase() == 'null' ||
          sohbetGenelHavasi.toLowerCase().contains('yeterli içerik') ||
          sohbetGenelHavasi.toLowerCase().contains('için yeterli') ||
          sohbetGenelHavasi.toLowerCase().contains('için yet')) {
        sohbetGenelHavasi = 'Samimi';
      }
      
      // Genel yorum doğrulama
      String? genelYorum = json['genelYorum'];
      
      // Sadece API'den açık hata mesajı gelirse düzelt
      if (genelYorum == null || 
          genelYorum.isEmpty || 
          genelYorum.toLowerCase() == 'analiz sonucu alınamadı' || 
          genelYorum.toLowerCase().contains('alınamadı') ||
          genelYorum.toLowerCase() == 'null') {
        genelYorum = 'API yanıtı alınamadı.';
      }
      
      // Son mesaj tonu doğrulama
      String? sonMesajTonu = json['sonMesajTonu'];
      
      // Sadece API'den açık hata mesajı gelirse düzelt
      if (sonMesajTonu == null || 
          sonMesajTonu.isEmpty || 
          sonMesajTonu.toLowerCase() == 'belirlenemedi' || 
          sonMesajTonu.toLowerCase() == 'analiz edilemedi' ||
          sonMesajTonu.toLowerCase().contains('yeterli') ||
          sonMesajTonu == 'null') {
        sonMesajTonu = 'Nötr';
      }
      
      // Son mesaj etkisi doğrulama
      Map<String, int> sonMesajEtkisiMap = {};
      var sonMesajEtkisiJson = json['sonMesajEtkisi'] ?? {};
      if (sonMesajEtkisiJson is Map) {
        sonMesajEtkisiJson.forEach((key, value) {
          if (value is int) {
            sonMesajEtkisiMap[key] = value;
          } else if (value is double) {
            sonMesajEtkisiMap[key] = value.toInt();
          } else if (value is String) {
            // Sayısal değer içeren string'i int'e çevir
            final numericString = value.replaceAll(RegExp(r'[^\d]'), '');
            sonMesajEtkisiMap[key] = numericString.isNotEmpty ? int.tryParse(numericString) ?? 0 : 0;
          }
        });
      }
      
      // Boş son mesaj etkisi kontrolü veya toplamı 100'den fazla uzaksa düzeltme
      if (sonMesajEtkisiMap.isEmpty) {
        sonMesajEtkisiMap = {'sempatik': 33, 'kararsız': 34, 'olumsuz': 33};
      } else {
        // Toplam kontrolü ve ayarlaması - bu gerekli bir işlemdir
        int toplam = sonMesajEtkisiMap.values.fold(0, (sum, value) => sum + value);
        if (toplam < 80 || toplam > 120) {
          // Değerleri oranla ve 100'e yaklaştır
          double oran = 100 / toplam;
          Map<String, int> yeniMap = {};
          int yeniToplam = 0;
          
          // İlk önce oranla ve yuvarla
          sonMesajEtkisiMap.forEach((key, value) {
            int yeniDeger = (value * oran).round();
            yeniMap[key] = yeniDeger;
            yeniToplam += yeniDeger;
          });
          
          // Toplam hala 100 değilse, farkı en büyük değere ekle/çıkar
          if (yeniToplam != 100) {
            String enBuyukKey = yeniMap.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key;
            yeniMap[enBuyukKey] = yeniMap[enBuyukKey]! + (100 - yeniToplam);
          }
          
          sonMesajEtkisiMap = yeniMap;
        }
      }
      
      // Direkt yorum doğrulama
      String? direktYorum = json['direktYorum'] ?? anlikTavsiye;
      
      // Sadece API'den açık hata mesajı gelirse düzelt
      if (direktYorum == null || 
          direktYorum.isEmpty || 
          direktYorum == 'null') {
        direktYorum = 'API yanıtı alınamadı.';
      }
      
      // CevapOnerileri doğrulama
      List<String> cevapOnerileriList = [];
      var cevapOnerileriJson = json['cevapOnerileri'] ?? [];
      
      if (cevapOnerileriJson is List) {
        cevapOnerileriList = List<String>.from(cevapOnerileriJson.map((item) => item?.toString() ?? '').where((item) => item.isNotEmpty));
      } else if (cevapOnerileriJson is String && cevapOnerileriJson.isNotEmpty) {
        // Tek bir string varsa listeye ekle
        cevapOnerileriList = [cevapOnerileriJson];
      }
      
      // Sadece boş liste durumunda varsayılan değer
      if (cevapOnerileriList.isEmpty) {
        cevapOnerileriList = [
          'API yanıtı alınamadı.',
        ];
      }

      // Karşı taraf cevap tahminleri
      String? olumluCevapTahmini = json['olumluCevapTahmini'] ?? json['positiveResponse'];
      String? olumsuzCevapTahmini = json['olumsuzCevapTahmini'] ?? json['negativeResponse'];

      return MessageCoachAnalysis(
        iliskiTipi: iliskiTipi,
        analiz: analiz,
        gucluYonler: gucluYonler,
        oneriler: onerileriList,
        etki: etkiMap,
        yenidenYazim: yenidenYazim,
        strateji: strateji,
        karsiTarafYorumu: karsiTarafYorumu,
        anlikTavsiye: anlikTavsiye,
        sohbetGenelHavasi: sohbetGenelHavasi,
        genelYorum: genelYorum,
        sonMesajTonu: sonMesajTonu,
        sonMesajEtkisi: sonMesajEtkisiMap,
        direktYorum: direktYorum,
        cevapOnerileri: cevapOnerileriList,
        olumluCevapTahmini: olumluCevapTahmini,
        olumsuzCevapTahmini: olumsuzCevapTahmini,
      );
    } catch (e) {
      print('❌ MesajKocuAnalizi.from hatası: $e');
      // Gerçek hata durumunda hata mesajı içeren model döndür
      return MessageCoachAnalysis(
        iliskiTipi: 'Belirlenmedi',
        analiz: 'Analiz işlemi sırasında bir hata oluştu: $e',
        gucluYonler: '',
        oneriler: ['API hatası. Lütfen tekrar deneyin.'],
        etki: {'Hata': 100},
        yenidenYazim: null,
        strateji: '',
        karsiTarafYorumu: null,
        anlikTavsiye: null,
        sohbetGenelHavasi: 'Hata',
        genelYorum: 'Analiz işlemi sırasında bir hata oluştu: $e',
        sonMesajTonu: 'Hata',
        sonMesajEtkisi: {'hata': 100},
        direktYorum: 'API yanıtı alınamadı. Lütfen tekrar deneyin.',
        cevapOnerileri: [
          'API yanıtı alınamadı. Lütfen tekrar deneyin.',
        ],
        olumluCevapTahmini: null,
        olumsuzCevapTahmini: null
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'ilişki_tipi': iliskiTipi,
      'analiz': analiz,
      'güçlü_yönler': gucluYonler,
      'öneriler': oneriler,
      'effect': etki,
      'rewrite': yenidenYazim,
      'strateji': strateji,
      'karşı_taraf_yorumu': karsiTarafYorumu,
      'anlık_tavsiye': anlikTavsiye,
      'sohbet_genel_havasi': sohbetGenelHavasi,
      'genel_yorum': genelYorum,
      'son_mesaj_tonu': sonMesajTonu,
      'son_mesaj_etkisi': sonMesajEtkisi,
      'direkt_yorum': direktYorum,
      'cevap_önerileri': cevapOnerileri,
      'olumlu_cevap_tahmini': olumluCevapTahmini,
      'olumsuz_cevap_tahmini': olumsuzCevapTahmini,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'iliskiTipi': iliskiTipi,
      'analiz': analiz,
      'gucluYonler': gucluYonler,
      'oneriler': oneriler,
      'etki': etki,
      'yenidenYazim': yenidenYazim,
      'strateji': strateji,
      'karsiTarafYorumu': karsiTarafYorumu,
      'anlikTavsiye': anlikTavsiye,
      'sohbetGenelHavasi': sohbetGenelHavasi,
      'genelYorum': genelYorum,
      'sonMesajTonu': sonMesajTonu,
      'sonMesajEtkisi': sonMesajEtkisi,
      'direktYorum': direktYorum,
      'cevapOnerileri': cevapOnerileri,
      'olumluCevapTahmini': olumluCevapTahmini,
      'olumsuzCevapTahmini': olumsuzCevapTahmini,
    };
  }
  
  /// JSON verilerinden MesajKocuAnalizi nesnesi oluşturur
  factory MessageCoachAnalysis.fromJson(Map<String, dynamic> json) {
    return MessageCoachAnalysis.from(json);
  }
  
  /// Geçerli bir sohbet genel havası değeri döndürür
  String _getValidChatMood() {
    final List<String> gecerliDegerler = ['Soğuk', 'Samimi', 'Pasif-agresif', 'İlgisiz', 'İlgili', 'Normal'];
    
    if (sohbetGenelHavasi != null) {
      for (final deger in gecerliDegerler) {
        if (sohbetGenelHavasi!.contains(deger)) {
          return sohbetGenelHavasi!;
        }
      }
    }
    
    // Varsayılan statik değer yerine null döndür
    return 'Belirlenmedi';
  }
  
  /// Geçerli bir mesaj tonu değeri döndürür
  String _getValidMessageTone() {
    final List<String> gecerliDegerler = ['Sert', 'Soğuk', 'Sempatik', 'Umursamaz', 'İlgili', 'Samimi', 'Pasif-agresif', 'Nötr'];
    
    if (sonMesajTonu != null) {
      for (final deger in gecerliDegerler) {
        if (sonMesajTonu!.contains(deger)) {
          return sonMesajTonu!;
        }
      }
    }
    
    // Varsayılan statik değer yerine null döndür
    return 'Belirlenmedi';
  }
  
  /// Mesaj koçu analiz sonucunu, istenilen formatta ve özetlenmiş halde döndürür
  String getFormattedAnalysis() {
    // Veri yoksa durumu belirt
    if (analiz.isEmpty || analiz == 'Analiz için yeterli veri bulunmuyor') {
      return 'Henüz analiz edilecek yeterli veri bulunmuyor.';
    }
    
    // Yeni formatta çıktı oluştur
    return '''
Genel Sohbet Analizi:
Sohbet genel havası: ${_getValidChatMood()}
Genel yorum: ${genelYorum ?? analiz}

Son Mesaj Analizi:
Son mesaj tonu: ${_getValidMessageTone()}
Son mesaj etkisi: ${getFormattedLastMessageEffects()}

Direkt Yorum ve Geliştirme:
${direktYorum ?? analiz}

${cevapOnerileri != null ? 'Cevap Önerileri:\n${cevapOnerileri!.join('\n')}' : ''}

${olumluCevapTahmini != null ? 'Olumlu Cevap Tahmini:\n$olumluCevapTahmini' : ''}
${olumsuzCevapTahmini != null ? 'Olumsuz Cevap Tahmini:\n$olumsuzCevapTahmini' : ''}
''';
  }
  
  /// Etki değerlerini istenilen formatta (yüzdelik olarak) döndürür
  String getFormattedEffects() {
    // Eğer etki verisi yoksa boş bir liste döndür
    if (etki.isEmpty) {
      return 'Henüz analiz edilmedi';
    }
    
    // Toplam etki değerini hesapla
    final int total = etki.values.fold(0, (sum, value) => sum + value);
    
    // Her bir etki değerini yüzdeye çevir ve formatla
    final formattedEffects = <String>[];
    
    // Mevcut kategorileri kontrol et ve daha iyi Türkçe karşılıkları ekle
    final Map<String, String> categories = {
      'neutral': 'Nötr',
      'positive': 'Olumlu',
      'negative': 'Olumsuz',
      'friendly': 'Samimi',
      'cold': 'Soğuk',
      'warm': 'Sıcak',
      'hesitant': 'Kararsız',
      'confident': 'Özgüvenli',
      'aggressive': 'Agresif',
      'defensive': 'Savunmacı',
      'sympathetic': 'Sempatik',
      'nötr': 'Nötr',
      'olumlu': 'Olumlu',
      'olumsuz': 'Olumsuz',
      'samimi': 'Samimi',
      'soğuk': 'Soğuk',
      'sıcak': 'Sıcak',
      'kararsız': 'Kararsız',
      'özgüvenli': 'Özgüvenli',
      'agresif': 'Agresif',
      'savunmacı': 'Savunmacı',
      'sempatik': 'Sempatik',
    };
    
    // Etki değerlerini büyükten küçüğe sırala
    final sortedEffects = etki.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // İlk 3 etki değerini al
    final topEffects = sortedEffects.take(3).toList();
    
    // Yüzdeye çevir ve formatla
    for (var effect in topEffects) {
      final percent = (effect.value / (total > 0 ? total : 1) * 100).round();
      final name = categories[effect.key.toLowerCase()] ?? effect.key;
      formattedEffects.add('- %$percent $name');
    }
    
    return formattedEffects.join('\n');
  }
  
  /// Son mesaj etkisini formatlı olarak döndürür
  String getFormattedLastMessageEffects() {
    if (sonMesajEtkisi == null || sonMesajEtkisi!.isEmpty) {
      return 'Henüz analiz edilmedi';
    }
    
    // Etkileri sırala
    final sortedEffects = sonMesajEtkisi!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // İlk üç etki değerini kullan
    final List<String> formattedEffects = [];
    
    for (var i = 0; i < min(3, sortedEffects.length); i++) {
      final entry = sortedEffects[i];
      String key = entry.key;
      
      // İngilizce anahtarları Türkçeye çevir
      if (key.toLowerCase() == 'positive' || key.toLowerCase() == 'friendly') {
        key = 'Olumlu';
      } else if (key.toLowerCase() == 'neutral' || key.toLowerCase() == 'hesitant') {
        key = 'Nötr';
      } else if (key.toLowerCase() == 'negative' || key.toLowerCase() == 'cold' || key.toLowerCase() == 'aggressive') {
        key = 'Olumsuz';
      } else if (key.toLowerCase() == 'sympathetic') {
        key = 'Sempatik';
      }
      
      formattedEffects.add('%${entry.value} $key');
    }
    
    return formattedEffects.join(' / ');
  }
} 