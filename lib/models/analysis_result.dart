class AnalysisResult {
  final String duygu;
  final String niyet;
  final String ton;
  final int ciddiyet;
  final String mesajYorumu;
  final List<String> cevapOnerileri;

  AnalysisResult({
    required this.duygu,
    required this.niyet,
    required this.ton,
    required this.ciddiyet,
    required this.mesajYorumu,
    required this.cevapOnerileri,
  });

  Map<String, dynamic> toMap() {
    return {
      'duygu': duygu,
      'niyet': niyet,
      'ton': ton,
      'ciddiyet': ciddiyet,
      'mesajYorumu': mesajYorumu,
      'cevapOnerileri': cevapOnerileri,
    };
  }

  factory AnalysisResult.fromMap(Map<String, dynamic> map) {
    return AnalysisResult(
      duygu: map['duygu'] ?? '',
      niyet: map['niyet'] ?? '',
      ton: map['ton'] ?? '',
      ciddiyet: map['ciddiyet'] ?? 5,
      mesajYorumu: map['mesaj_yorumu'] ?? map['mesajYorumu'] ?? '',
      cevapOnerileri: List<String>.from(map['cevapOnerileri'] ?? []),
    );
  }

  @override
  String toString() {
    return 'AnalysisResult(duygu: $duygu, niyet: $niyet, ton: $ton, ciddiyet: $ciddiyet)';
  }
} 