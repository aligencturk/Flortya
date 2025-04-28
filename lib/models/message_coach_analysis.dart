import 'package:flutter/foundation.dart';
import 'dart:math';

class MesajKocuAnalizi {
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

  MesajKocuAnalizi({
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

  factory MesajKocuAnalizi.fromJson(Map<String, dynamic> json) {
    // Debug log için konsola yazdır
    print('MesajKocuAnalizi.fromJson çağrıldı: ${json.keys.toList()}');
    
    // Öneriler listesini dönüştür
    final List<dynamic> onerileriJson = json['öneriler'] ?? [];
    final List<String> onerileriList = onerileriJson
        .map((item) => item.toString())
        .toList();
    
    // Öneriler listesi boşsa varsayılan değerler ver
    if (onerileriList.isEmpty) {
      onerileriList.addAll(['İletişim tekniklerini geliştir', 'Karşı tarafı dinlemeye özen göster']);
    }

    // Etki alanını Map<String, int> olarak dönüştür
    Map<String, int> etkiMap = {};
    if (json.containsKey('effect') && json['effect'] is Map) {
      final etkiJson = json['effect'] as Map<String, dynamic>;
      
      etkiJson.forEach((key, value) {
        if (value is int) {
          etkiMap[key] = value;
        } else if (value is double) {
          etkiMap[key] = value.toInt();
        } else if (value is String) {
          try {
            etkiMap[key] = int.parse(value);
          } catch (e) {
            etkiMap[key] = 0;
          }
        } else {
          etkiMap[key] = 0;
        }
      });
    }
    
    // Etki haritası boşsa varsayılan değer ekle
    if (etkiMap.isEmpty) {
      etkiMap = {'nötr': 100};
    }
    
    // Son mesaj etkisi alanını dönüştür
    Map<String, int>? sonMesajEtkisiMap;
    if (json.containsKey('sonMesajEtkisi') && json['sonMesajEtkisi'] is Map) {
      sonMesajEtkisiMap = {};
      final sonMesajEtkisiJson = json['sonMesajEtkisi'] as Map<String, dynamic>;
      
      sonMesajEtkisiJson.forEach((key, value) {
        if (value is int) {
          sonMesajEtkisiMap![key] = value;
        } else if (value is double) {
          sonMesajEtkisiMap![key] = value.toInt();
        } else if (value is String) {
          try {
            sonMesajEtkisiMap![key] = int.parse(value);
          } catch (e) {
            sonMesajEtkisiMap![key] = 0;
          }
        } else {
          sonMesajEtkisiMap![key] = 0;
        }
      });
    }

    // Zorunlu alanların varlığını kontrol et ve eşleştir
    // 1. Anlık tavsiye - mesajYorumu veya instantAdvice alanlarında olabilir
    String? mesajYorumu = json['mesajYorumu'];
    String? anlikTavsiye = json['anlikTavsiye'] ?? json['instantAdvice'] ?? mesajYorumu;
    
    // 2. Analiz sonucu - analiz, mesajYorumu, veya karsiTarafYorumu alanlarından biri olabilir
    String analiz = json['analiz'] ?? mesajYorumu ?? json['karsiTarafYorumu'] ?? 'Analiz sonucu bulunamadı';
    
    // 3. Diğer alanlar için eşleştirmeler
    String? yenidenYazim = json['yenidenYazim'] ?? json['rewrite'];
    String? strateji = json['strateji'] ?? json['strategy'];
    String? karsiTarafYorumu = json['karsiTarafYorumu'] ?? json['counterpartOpinion'];
    String? gucluYonler = json['gucluYonler'] ?? json['strongPoints'];
    String? iliskiTipi = json['iliskiTipi'] ?? json['relationshipType'];

    // 4. Yeni alanlar için eşleştirmeler
    String? sohbetGenelHavasi = json['sohbetGenelHavasi'] ?? json['chatMood'];
    String? genelYorum = json['genelYorum'] ?? json['generalComment'];
    String? sonMesajTonu = json['sonMesajTonu'] ?? json['lastMessageTone'];
    String? direktYorum = json['direktYorum'] ?? json['directComment'];
    String? cevapOnerisi = json['cevapOnerisi'] ?? json['suggestionResponse'];

    // Log ile alanların nasıl doldurulduğunu kontrol et
    print('📊 MesajKocuAnalizi - Etki: ${etkiMap.keys.join(', ')}');
    print('📝 MesajKocuAnalizi - Anlık Tavsiye: ${anlikTavsiye?.substring(0, min(30, anlikTavsiye?.length ?? 0))}...');
    print('📝 MesajKocuAnalizi - Yeniden Yazım: ${yenidenYazim != null ? "Var" : "Yok"}');
    print('👀 MesajKocuAnalizi - Karşı Taraf Yorumu: ${karsiTarafYorumu != null ? "Var" : "Yok"}');

    return MesajKocuAnalizi(
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
    
    // Varsayılan değer yok - dinamik içerik isteniyor
    return sohbetGenelHavasi ?? 'Analiz bekleniyor';
  }
  
  /// Geçerli bir mesaj tonu değeri döndürür
  String _getValidMessageTone() {
    final List<String> gecerliDegerler = ['Sert', 'Soğuk', 'Sempatik', 'Umursamaz', 'İlgili', 'Samimi', 'Pasif-agresif', 'Nötr', 'Normal'];
    
    if (sonMesajTonu != null) {
      for (final deger in gecerliDegerler) {
        if (sonMesajTonu!.contains(deger)) {
          return sonMesajTonu!;
        }
      }
    }
    
    // Varsayılan değer yok - dinamik içerik isteniyor
    return sonMesajTonu ?? 'Analiz bekleniyor';
  }
  
  /// Mesaj koçu analiz sonucunu, istenilen formatta ve özetlenmiş halde döndürür
  String getFormattedAnalysis() {
    // Yeni formatta çıktı oluştur
    return '''
1. Genel Sohbet Analizi:
Sohbet genel havası: ${_getValidChatMood()}
Genel yorum: ${genelYorum ?? analiz}

2. Son Mesaj Analizi:
Son mesaj tonu: ${_getValidMessageTone()}
Son mesaj etkisi: ${getFormattedLastMessageEffects()}

3. Direkt Yorum ve Geliştirme:
${direktYorum ?? analiz}

${cevapOnerisi != null ? '4. Cevap Önerisi:\n$cevapOnerisi' : ''}
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
      return 'Analiz bekleniyor';
    }
    
    // Etki değerlerini büyükten küçüğe sırala
    final sortedEffects = sonMesajEtkisi!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Standart kategoriler için değerleri al (yoksa 0)
    int sempatik = 0;
    int kararsiz = 0;
    int olumsuz = 0;
    
    for (var entry in sortedEffects) {
      final key = entry.key.toLowerCase();
      if (key == 'sempatik' || key == 'sympathetic' || key == 'positive' || key == 'olumlu') {
        sempatik = entry.value;
      } else if (key == 'kararsız' || key == 'hesitant' || key == 'neutral' || key == 'nötr') {
        kararsiz = entry.value;
      } else if (key == 'olumsuz' || key == 'negative' || key == 'soğuk' || key == 'cold') {
        olumsuz = entry.value;
      }
    }
    
    return '%$sempatik sempatik / %$kararsiz kararsız / %$olumsuz olumsuz';
  }
} 