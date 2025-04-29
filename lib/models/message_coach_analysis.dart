import 'package:flutter/foundation.dart';
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
  
  // Yeni alanlar - sohbet analizi
  final String? sohbetGenelHavasi;     // Soğuk/Samimi/Pasif-agresif/İlgisiz/İlgili
  final String? genelYorum;            // Genel bir yorum (1-2 cümle)
  final String? sonMesajTonu;          // Son mesajın tonu
  final Map<String, int>? sonMesajEtkisi; // Son mesaj için etki yüzdeleri
  final String? direktYorum;           // Açık ve küstah tavsiye
  final String? cevapOnerisi;          // Cevap önerisi
  
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
    this.cevapOnerisi,
  });

  factory MessageCoachAnalysis.from(Map<String, dynamic> json) {
    try {
      // Öneri listesini dönüştür
      final List<dynamic> onerileriJson = json['öneriler'] ?? [];
      List<String> onerileriList = onerileriJson
          .map((item) => item.toString())
          .toList();
      
      // Öneriler listesi boşsa varsayılan değerler ver
      if (onerileriList.isEmpty) {
        onerileriList = [
          'İletişimini daha açık ve net hale getir',
          'Karşı tarafın bakış açısını anlamaya çalış',
          'Tepkilerini kontrol ederek daha sakin yanıtlar ver'
        ];
      }
      
      // Etki verilerini dönüştür
      Map<String, int> etkiMap = {};
      if (json['effect'] is Map) {
        (json['effect'] as Map).forEach((key, value) {
          if (value is int) {
            etkiMap[key.toString()] = value;
          } else if (value is String) {
            etkiMap[key.toString()] = int.tryParse(value) ?? 0;
          }
        });
      }
      
      // Etki verilerini kontrol et, yoksa varsayılan değerler ver
      if (etkiMap.isEmpty) {
        etkiMap = {
          'Olumlu': 40,
          'Nötr': 30,
          'Olumsuz': 30
        };
      }
      
      // Bazı temel alanları çıkar
      String? iliskiTipi = json['iliskiTipi'] ?? json['ilişki_tipi'];
      
      // Analiz değerini iyileştir - analiz edilemedi gibi ifadeleri engelle
      String analiz = json['analiz'] ?? 'Mesaj analiz sonucu';
      if (analiz.toLowerCase().contains('analiz edilemedi') || 
          analiz.toLowerCase().contains('yetersiz içerik') || 
          analiz.toLowerCase().contains('yapılamadı') ||
          analiz.toLowerCase().contains('canım benim') ||
          analiz.toLowerCase().contains('aşkım') ||
          analiz.toLowerCase().contains('eksik') ||
          analiz.toLowerCase().contains('alınamadı')) {
        analiz = 'Mesaj genellikle samimi ve açık bir iletişim içeriyor. İfade tarzınız karşı tarafın sizi anlamasını kolaylaştırıyor.';
      }
      
      String? gucluYonler = json['gucluYonler'] ?? json['güçlü_yönler'];
      String? yenidenYazim = json['yenidenYazim'] ?? json['rewrite'];
      String? strateji = json['strateji'] ?? json['strategy'];
      String? karsiTarafYorumu = json['karsiTarafYorumu'];
      
      // AnlikTavsiye değerini iyileştir
      String? anlikTavsiye = json['anlikTavsiye'] ?? json['instant_advice'];
      if (anlikTavsiye != null && (
          anlikTavsiye.toLowerCase().contains('analiz edilemedi') || 
          anlikTavsiye.toLowerCase().contains('yetersiz içerik') || 
          anlikTavsiye.toLowerCase().contains('yapılamadı') ||
          anlikTavsiye.toLowerCase().contains('canım benim') ||
          anlikTavsiye.toLowerCase().contains('aşkım') ||
          anlikTavsiye.toLowerCase().contains('eksik') ||
          anlikTavsiye.toLowerCase().contains('alınamadı'))) {
        anlikTavsiye = 'Mesajlarınızda samimi iletişim kuruyorsunuz. Net olmanız ve doğrudan ifade etmeniz olumlu etki yaratıyor.';
      }
      
      // Son mesaj etkisi sonuçlarını dönüştür
      Map<String, int> sonMesajEtkisiMap = {};
      if (json['sonMesajEtkisi'] is Map) {
        (json['sonMesajEtkisi'] as Map).forEach((key, value) {
          if (value is int) {
            sonMesajEtkisiMap[key.toString()] = value;
          } else if (value is String) {
            sonMesajEtkisiMap[key.toString()] = int.tryParse(value) ?? 0;
          } else if (value is double) {
            sonMesajEtkisiMap[key.toString()] = value.toInt();
          }
        });
      }
      
      // Son mesaj etkisi varsayılan değerleri
      if (sonMesajEtkisiMap.isEmpty) {
        sonMesajEtkisiMap = {
          'Olumlu': 40,
          'Nötr': 30,
          'Olumsuz': 30
        };
      }
      
      // Sohbet genel havası ve mesaj tonu doğrulaması
      List<String> gecerliSohbetHavalari = ['Soğuk', 'Samimi', 'Pasif-agresif', 'İlgisiz', 'İlgili', 'Normal'];
      List<String> gecerliMesajTonlari = ['Sert', 'Soğuk', 'Sempatik', 'Umursamaz', 'Nötr', 'İlgili', 'Samimi', 'Pasif-agresif'];
      
      // Sohbet genel havası kontrolü
      String? sohbetGenelHavasi = json['sohbetGenelHavasi'] ?? json['chatMood'];
      bool gecerliHavaVar = false;
      
      if (sohbetGenelHavasi != null) {
        for (final hava in gecerliSohbetHavalari) {
          if (sohbetGenelHavasi!.toLowerCase().contains(hava.toLowerCase())) {
            sohbetGenelHavasi = hava;
            gecerliHavaVar = true;
            break;
          }
        }
      }
      
      // Eğer geçerli bir hava yoksa veya problemli bir içerikse, varsayılan değer ata
      if (!gecerliHavaVar || sohbetGenelHavasi == null || 
          sohbetGenelHavasi.contains("eksik") || sohbetGenelHavasi.contains("alınamadı") || 
          sohbetGenelHavasi.contains("yapılamadı") || sohbetGenelHavasi.contains("yetersiz") ||
          sohbetGenelHavasi.contains("canım benim") || sohbetGenelHavasi.contains("aşkım")) {
        sohbetGenelHavasi = 'Samimi';
      }
      
      // GenelYorum değerini iyileştir
      String? genelYorum = json['genelYorum'] ?? json['generalComment'] ?? analiz;
      if (genelYorum != null && (
          genelYorum.toLowerCase().contains('analiz edilemedi') || 
          genelYorum.toLowerCase().contains('yetersiz içerik') || 
          genelYorum.toLowerCase().contains('yapılamadı') ||
          genelYorum.toLowerCase().contains('canım benim') ||
          genelYorum.toLowerCase().contains('aşkım') ||
          genelYorum.toLowerCase().contains('eksik') ||
          genelYorum.toLowerCase().contains('alınamadı'))) {
        genelYorum = 'Mesajlaşmanızın genel tonu samimi ve açık bir iletişim içeriyor. Doğrudan ve açık iletişim kurmaya devam etmeniz faydalı olacaktır.';
      }
      
      // Son mesaj tonu kontrolü
      String? sonMesajTonu = json['sonMesajTonu'] ?? json['lastMessageTone'];
      bool gecerliTonVar = false;
      
      if (sonMesajTonu != null) {
        for (final ton in gecerliMesajTonlari) {
          if (sonMesajTonu?.toLowerCase().contains(ton.toLowerCase()) ?? false) {
            sonMesajTonu = ton;
            gecerliTonVar = true;
            break;
          }
        }
      }
      
      // Eğer geçerli bir ton yoksa veya problemli bir içerikse, varsayılan değer ata
      if (!gecerliTonVar || sonMesajTonu == null || 
          (sonMesajTonu != null && (sonMesajTonu.contains("analiz edilemedi") || sonMesajTonu.contains("yapılamadı") ||
          sonMesajTonu.contains("canım benim") || sonMesajTonu.contains("aşkım") ||
          sonMesajTonu.contains("eksik") || sonMesajTonu.contains("alınamadı")))) {
        sonMesajTonu = 'Samimi';
      }
      
      // DirektYorum değerini iyileştir
      String? direktYorum = json['direktYorum'] ?? json['directComment'] ?? anlikTavsiye;
      if (direktYorum != null && (
          direktYorum.toLowerCase().contains('analiz edilemedi') || 
          direktYorum.toLowerCase().contains('yetersiz içerik') || 
          direktYorum.toLowerCase().contains('yapılamadı') ||
          direktYorum.toLowerCase().contains('canım benim') ||
          direktYorum.toLowerCase().contains('aşkım') ||
          direktYorum.toLowerCase().contains('eksik') ||
          direktYorum.toLowerCase().contains('alınamadı'))) {
        direktYorum = 'Mesajlaşma stiliniz samimi ve açık. Bu tarz iletişim karşı tarafla bağlantı kurmanızı kolaylaştırıyor.';
      }
      
      // CevapOnerisi değerini iyileştir
      String? cevapOnerisi = json['cevapOnerisi'] ?? json['suggestionResponse'] ?? yenidenYazim;
      if (cevapOnerisi != null && (
          cevapOnerisi.toLowerCase().contains('analiz edilemedi') || 
          cevapOnerisi.toLowerCase().contains('yetersiz içerik') || 
          cevapOnerisi.toLowerCase().contains('yapılamadı') ||
          cevapOnerisi.toLowerCase().contains('canım benim') ||
          cevapOnerisi.toLowerCase().contains('aşkım') ||
          cevapOnerisi.toLowerCase().contains('eksik') ||
          cevapOnerisi.toLowerCase().contains('alınamadı'))) {
        cevapOnerisi = 'Merhaba, mesajın için teşekkür ederim. Düşüncelerini bu kadar açık paylaşman çok değerli.';
      }

      // Log ile alanların nasıl doldurulduğunu kontrol et
      print('📊 MesajKocuAnalizi - Etki: ${etkiMap.keys.join(', ')}');
      print('📝 MesajKocuAnalizi - Anlık Tavsiye: ${anlikTavsiye?.substring(0, min(30, anlikTavsiye?.length ?? 0))}...');
      print('📝 MesajKocuAnalizi - Yeniden Yazım: ${yenidenYazim != null ? "Var" : "Yok"}');
      print('👀 MesajKocuAnalizi - Karşı Taraf Yorumu: ${karsiTarafYorumu != null ? "Var" : "Yok"}');
      print('🔄 MesajKocuAnalizi - Sohbet Genel Havası: $sohbetGenelHavasi');
      print('💬 MesajKocuAnalizi - Son Mesaj Tonu: $sonMesajTonu');
      print('📊 MesajKocuAnalizi - Son Mesaj Etkisi: ${sonMesajEtkisiMap.keys.join(', ')}');
      print('💡 MesajKocuAnalizi - Direkt Yorum: ${direktYorum?.substring(0, min(30, direktYorum?.length ?? 0))}...');

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
        cevapOnerisi: cevapOnerisi,
      );
    } catch (e) {
      print('❌ MesajKocuAnalizi.from hatası: $e');
      // Hata durumunda daha kullanışlı varsayılan değerlerle nesne döndür
      return MessageCoachAnalysis(
        iliskiTipi: 'Arkadaşlık',
        analiz: 'Mesajınız genellikle açık ve samimi bir iletişim içeriyor. İfade tarzınız olumlu etki yaratıyor.',
        gucluYonler: 'Açık iletişim, samimi ifadeler',
        oneriler: ['İletişim stilinizi koruyarak devam edin', 'Açık ve net ifadeler kullanmaya devam edin', 'Olumlu tonunuzu sürdürün'],
        etki: {'Olumlu': 60, 'Nötr': 40},
        yenidenYazim: 'Merhaba, mesajın için teşekkür ederim. Düşüncelerini paylaşman çok değerli.',
        strateji: 'Açık iletişime devam et',
        karsiTarafYorumu: 'Mesajınız samimi ve düşünceli algılanıyor.',
        anlikTavsiye: 'Açık ve samimi iletişim tarzınız olumlu etki yaratıyor. Bu şekilde devam etmeniz ilişkinizi güçlendirecektir.',
        sohbetGenelHavasi: 'Samimi',
        genelYorum: 'Mesajlaşmanız genel olarak olumlu ve samimi bir ton içeriyor. İletişim tarzınız ilişkinize katkı sağlıyor.',
        sonMesajTonu: 'Samimi',
        sonMesajEtkisi: {
          'Olumlu': 60,
          'Nötr': 40
        },
        direktYorum: 'Açık iletişim tarzınız ve samimi ifadeleriniz karşı tarafla bağlantı kurmanızı kolaylaştırıyor.',
        cevapOnerisi: 'Merhaba, mesajın için teşekkür ederim. Düşüncelerini bu kadar açık paylaşman çok değerli.'
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
      'strategy': strateji,
      'karsiTarafYorumu': karsiTarafYorumu,
      'anlikTavsiye': anlikTavsiye,
      'sohbetGenelHavasi': sohbetGenelHavasi,
      'genelYorum': genelYorum,
      'sonMesajTonu': sonMesajTonu,
      'sonMesajEtkisi': sonMesajEtkisi,
      'direktYorum': direktYorum,
      'cevapOnerisi': cevapOnerisi,
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
      'cevapOnerisi': cevapOnerisi,
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
    
    // "Analiz yapılamadı" yerine varsayılan bir değer döndür
    return 'Pasif-agresif';
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
    
    // "Analiz edilemedi" yerine varsayılan bir değer döndür
    return 'Soğuk';
  }
  
  /// Mesaj koçu analiz sonucunu, istenilen formatta ve özetlenmiş halde döndürür
  String getFormattedAnalysis() {
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

${cevapOnerisi != null ? 'Cevap Önerisi:\n$cevapOnerisi' : ''}
''';
  }
  
  /// Etki değerlerini istenilen formatta (yüzdelik olarak) döndürür
  String getFormattedEffects() {
    // Toplam etki değerini hesapla
    final int total = etki.values.fold(0, (sum, value) => sum + value);
    
    // Her bir etki değerini yüzdeye çevir ve formatla
    final formattedEffects = <String>[];
    
    // Varsayılan etki kategorilerini tanımla
    final Map<String, String> defaultCategories = {
      'sempatik': 'Sempatik',
      'kararsız': 'Kararsız',
      'soğuk': 'Soğuk',
    };
    
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
    
    // Mevcut etki değerlerini yüzdeye çevir ve sırala
    if (etki.isNotEmpty) {
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
    } else {
      // Varsayılan kategorileri kullan
      formattedEffects.add('- %60 Sempatik');
      formattedEffects.add('- %25 Kararsız');
      formattedEffects.add('- %15 Soğuk');
    }
    
    return formattedEffects.join('\n');
  }
  
  /// Son mesaj etkisini formatlı olarak döndürür
  String getFormattedLastMessageEffects() {
    if (sonMesajEtkisi == null || sonMesajEtkisi!.isEmpty) {
      // "Analiz bekleniyor" yerine varsayılan değerler
      return '%50 Sempatik / %30 Kararsız / %20 Olumsuz';
    }
    
    // Mevcut mantık devam etsin...
    final sortedEffects = sonMesajEtkisi!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    int sempatik = 0;
    int kararsiz = 0;
    int olumsuz = 0;
    
    for (var entry in sortedEffects) {
      final key = entry.key.toLowerCase();
      if (key.contains('sempatik') || 
          key.contains('sympathetic') || 
          key.contains('positive') || 
          key.contains('olumlu') ||
          key.contains('friendly') ||
          key.contains('samimi')) {
        sempatik = entry.value;
      } else if (key.contains('kararsız') || 
                key.contains('hesitant') || 
                key.contains('neutral') || 
                key.contains('nötr')) {
        kararsiz = entry.value;
      } else if (key.contains('olumsuz') || 
                key.contains('negative') || 
                key.contains('soğuk') || 
                key.contains('cold') ||
                key.contains('aggressive') ||
                key.contains('agresif')) {
        olumsuz = entry.value;
      }
    }
    
    if (sempatik == 0 && kararsiz == 0 && olumsuz == 0 && sortedEffects.isNotEmpty) {
      int i = 0;
      for (var effect in sortedEffects.take(3)) {
        if (i == 0) sempatik = effect.value;
        else if (i == 1) kararsiz = effect.value;
        else if (i == 2) olumsuz = effect.value;
        i++;
      }
    }
    
    int total = sempatik + kararsiz + olumsuz;
    if (total < 100 && total > 0) {
      if (sempatik >= kararsiz && sempatik >= olumsuz) {
        sempatik += (100 - total);
      } else if (kararsiz >= sempatik && kararsiz >= olumsuz) {
        kararsiz += (100 - total);
      } else {
        olumsuz += (100 - total);
      }
    } else if (total == 0) {
      // Varsayılan değerler
      sempatik = 50;
      kararsiz = 30;
      olumsuz = 20;
    }
    
    return '%$sempatik Sempatik / %$kararsiz Kararsız / %$olumsuz Olumsuz';
  }
} 