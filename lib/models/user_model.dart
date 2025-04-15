flutimport 'package:cloud_firestore/cloud_firestore.dart';

class AnalizSonucu {
  final int iliskiPuani;
  final Map<String, int> kategoriPuanlari;
  final DateTime tarih;
  final List<String> kisiselestirilmisTavsiyeler;

  AnalizSonucu({
    required this.iliskiPuani,
    required this.kategoriPuanlari,
    required this.tarih,
    required this.kisiselestirilmisTavsiyeler,
  });

  factory AnalizSonucu.fromMap(Map<String, dynamic> map) {
    return AnalizSonucu(
      iliskiPuani: map['iliskiPuani'] ?? 0,
      kategoriPuanlari: Map<String, int>.from(map['kategoriPuanlari'] ?? {}),
      tarih: (map['tarih'] as Timestamp).toDate(),
      kisiselestirilmisTavsiyeler: List<String>.from(map['kisiselestirilmisTavsiyeler'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'iliskiPuani': iliskiPuani,
      'kategoriPuanlari': kategoriPuanlari,
      'tarih': Timestamp.fromDate(tarih),
      'kisiselestirilmisTavsiyeler': kisiselestirilmisTavsiyeler,
    };
  }

  AnalizSonucu copyWith({
    int? iliskiPuani,
    Map<String, int>? kategoriPuanlari,
    DateTime? tarih,
    List<String>? kisiselestirilmisTavsiyeler,
  }) {
    return AnalizSonucu(
      iliskiPuani: iliskiPuani ?? this.iliskiPuani,
      kategoriPuanlari: kategoriPuanlari ?? this.kategoriPuanlari,
      tarih: tarih ?? this.tarih,
      kisiselestirilmisTavsiyeler: kisiselestirilmisTavsiyeler ?? this.kisiselestirilmisTavsiyeler,
    );
  }
}

class UserModel {
  final String id;
  final String displayName;
  final String email;
  final String photoURL;
  final bool isPremium;
  final DateTime? premiumExpiry;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final Map<String, dynamic> preferences;
  final AnalizSonucu? sonAnalizSonucu;
  final List<AnalizSonucu> analizGecmisi;

  UserModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoURL = '',
    this.isPremium = false,
    this.premiumExpiry,
    required this.createdAt,
    required this.lastLoginAt,
    this.preferences = const {},
    this.sonAnalizSonucu,
    this.analizGecmisi = const [],
  });

  // Firestore'dan veri okuma
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Analiz geçmişini dönüştürme
    List<AnalizSonucu> analizGecmisi = [];
    if (data['analizGecmisi'] != null) {
      analizGecmisi = (data['analizGecmisi'] as List)
          .map((analizMap) => AnalizSonucu.fromMap(analizMap))
          .toList();
    }
    
    // Son analiz sonucunu dönüştürme
    AnalizSonucu? sonAnalizSonucu;
    if (data['sonAnalizSonucu'] != null) {
      sonAnalizSonucu = AnalizSonucu.fromMap(data['sonAnalizSonucu']);
    }
    
    return UserModel(
      id: doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      photoURL: data['photoURL'] ?? '',
      isPremium: data['isPremium'] ?? false,
      premiumExpiry: data['premiumExpiry'] != null 
          ? (data['premiumExpiry'] as Timestamp).toDate() 
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp).toDate(),
      preferences: data['preferences'] ?? {},
      sonAnalizSonucu: sonAnalizSonucu,
      analizGecmisi: analizGecmisi,
    );
  }

  // Firestore'a veri yazma
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'isPremium': isPremium,
      'premiumExpiry': premiumExpiry != null ? Timestamp.fromDate(premiumExpiry!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'preferences': preferences,
      'sonAnalizSonucu': sonAnalizSonucu?.toMap(),
      'analizGecmisi': analizGecmisi.map((analiz) => analiz.toMap()).toList(),
    };
  }

  // Yeni bir analiz sonucu eklemek için method
  UserModel analizSonucuEkle(AnalizSonucu yeniAnalizSonucu) {
    // Yeni analiz geçmişi oluştur (mevcut + yeni)
    List<AnalizSonucu> yeniAnalizGecmisi = List.from(analizGecmisi);
    yeniAnalizGecmisi.add(yeniAnalizSonucu);
    
    // Güncellenmiş modeli döndür
    return copyWith(
      sonAnalizSonucu: yeniAnalizSonucu,
      analizGecmisi: yeniAnalizGecmisi,
    );
  }

  // UserModel'in kopyasını oluşturma
  UserModel copyWith({
    String? id,
    String? displayName,
    String? email,
    String? photoURL,
    bool? isPremium,
    DateTime? premiumExpiry,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    Map<String, dynamic>? preferences,
    AnalizSonucu? sonAnalizSonucu,
    List<AnalizSonucu>? analizGecmisi,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      isPremium: isPremium ?? this.isPremium,
      premiumExpiry: premiumExpiry ?? this.premiumExpiry,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      preferences: preferences ?? this.preferences,
      sonAnalizSonucu: sonAnalizSonucu ?? this.sonAnalizSonucu,
      analizGecmisi: analizGecmisi ?? this.analizGecmisi,
    );
  }
} 