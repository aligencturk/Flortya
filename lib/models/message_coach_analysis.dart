import 'package:flutter/foundation.dart';

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
  });

  factory MesajKocuAnalizi.fromJson(Map<String, dynamic> json) {
    // Oneriler listesini dönüştür
    final List<dynamic> onerileriJson = json['öneriler'] ?? [];
    final List<String> onerileriList = onerileriJson
        .map((item) => item.toString())
        .toList();

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

    return MesajKocuAnalizi(
      iliskiTipi: json['ilişki_tipi'] as String?,
      analiz: json['analiz'] as String? ?? 'Analiz bulunamadı',
      gucluYonler: json['güçlü_yönler'] as String?,
      oneriler: onerileriList,
      etki: etkiMap,
      yenidenYazim: json['rewrite'] as String?,
      strateji: json['strategy'] as String?,
      karsiTarafYorumu: json['karsiTarafYorumu'] as String?,
      anlikTavsiye: json['anlikTavsiye'] as String?,
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
    };
  }

  Map<String, dynamic> toFirestore() {
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
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
} 