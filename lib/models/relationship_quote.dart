class RelationshipQuote {
  final String title; // Tek kelimelik tema (Güven, Anlayış, vb.)
  final String content; // Alıntı metni
  final String source; // Kaynak (Koç adı ve varsa kitap/konuşma adı)
  final DateTime timestamp;

  RelationshipQuote({
    required this.title,
    required this.content,
    required this.source,
    required this.timestamp,
  });

  // Firestore'dan veri dönüştürme
  factory RelationshipQuote.fromFirestore(Map<String, dynamic> data) {
    return RelationshipQuote(
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      source: data['source'] ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  // Firestore'a kaydetmek için Map'e dönüştürme
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'source': source,
      'timestamp': timestamp,
    };
  }

  // Hata durumu için boş bir alıntı oluşturma
  static RelationshipQuote empty() {
    return RelationshipQuote(
      title: '',
      content: 'Bugünün tavsiyesi şu an getirilemiyor. Lütfen daha sonra tekrar deneyin.',
      source: '',
      timestamp: DateTime.now(),
    );
  }
} 