import 'package:cloud_firestore/cloud_firestore.dart';

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
      tarih: map['tarih'] is Timestamp 
          ? (map['tarih'] as Timestamp).toDate() 
          : (map['tarih'] != null ? DateTime.parse(map['tarih'].toString()) : DateTime.now()),
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
  final String email;
  final String? displayName;
  final String? photoURL;
  final bool isPremium;
  final DateTime? premiumExpiryDate;
  final String? authProvider;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final DateTime? birthDate;
  final bool profileCompleted;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final Map<String, dynamic> preferences;
  final AnalizSonucu? sonAnalizSonucu;
  final List<AnalizSonucu> analizGecmisi;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoURL,
    this.isPremium = false,
    this.premiumExpiryDate,
    this.authProvider,
    this.firstName,
    this.lastName,
    this.gender,
    this.birthDate,
    this.profileCompleted = false,
    required this.createdAt,
    required this.lastLoginAt,
    this.preferences = const {},
    this.sonAnalizSonucu,
    this.analizGecmisi = const [],
  });

  // Firestore'dan veri okuma
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data() ?? {};
    
    // Analiz geçmişini dönüştürme
    List<AnalizSonucu> analizGecmisi = [];
    if (data['analizGecmisi'] != null) {
      analizGecmisi = (data['analizGecmisi'] as List)
          .map((analizMap) => AnalizSonucu.fromMap(analizMap as Map<String, dynamic>))
          .toList();
    }
    
    // Son analiz sonucunu dönüştürme
    AnalizSonucu? sonAnalizSonucu;
    if (data['sonAnalizSonucu'] != null) {
      sonAnalizSonucu = AnalizSonucu.fromMap(data['sonAnalizSonucu'] as Map<String, dynamic>);
    }
    
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoURL: data['photoURL'],
      isPremium: data['isPremium'] ?? false,
      premiumExpiryDate: data['premiumExpiry'] != null 
          ? (data['premiumExpiry'] as Timestamp).toDate() 
          : null,
      authProvider: data['authProvider'],
      firstName: data['firstName'],
      lastName: data['lastName'],
      gender: data['gender'],
      birthDate: data['birthDate'] != null 
          ? (data['birthDate'] as Timestamp).toDate() 
          : null,
      profileCompleted: data['profileCompleted'] ?? false,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      lastLoginAt: data['lastLoginAt'] != null 
          ? (data['lastLoginAt'] as Timestamp).toDate() 
          : DateTime.now(),
      preferences: data['preferences'] ?? {},
      sonAnalizSonucu: sonAnalizSonucu,
      analizGecmisi: analizGecmisi,
    );
  }

  // Firestore'a veri yazma
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'isPremium': isPremium,
      'premiumExpiry': premiumExpiryDate != null ? Timestamp.fromDate(premiumExpiryDate!) : null,
      'authProvider': authProvider,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'profileCompleted': profileCompleted,
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
    String? email,
    String? displayName,
    String? photoURL,
    bool? isPremium,
    DateTime? premiumExpiryDate,
    String? authProvider,
    String? firstName,
    String? lastName,
    String? gender,
    DateTime? birthDate,
    bool? profileCompleted,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    Map<String, dynamic>? preferences,
    AnalizSonucu? sonAnalizSonucu,
    List<AnalizSonucu>? analizGecmisi,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      isPremium: isPremium ?? this.isPremium,
      premiumExpiryDate: premiumExpiryDate ?? this.premiumExpiryDate,
      authProvider: authProvider ?? this.authProvider,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      preferences: preferences ?? this.preferences,
      sonAnalizSonucu: sonAnalizSonucu ?? this.sonAnalizSonucu,
      analizGecmisi: analizGecmisi ?? this.analizGecmisi,
    );
  }
} 