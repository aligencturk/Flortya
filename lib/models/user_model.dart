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
    try {
      // Kategori puanlarını güvenli şekilde çıkar
      Map<String, int> kategoriPuanlari = {};
      if (map['kategoriPuanlari'] != null) {
        try {
          final rawMap = map['kategoriPuanlari'];
          if (rawMap is Map) {
            rawMap.forEach((key, value) {
              if (key is String) {
                if (value is int) {
                  kategoriPuanlari[key] = value;
                } else if (value is num) {
                  kategoriPuanlari[key] = value.toInt();
                } else if (value is String && int.tryParse(value) != null) {
                  kategoriPuanlari[key] = int.parse(value);
                }
              }
            });
          }
        } catch (e) {
          print('Kategori puanları dönüştürme hatası: $e');
          // Hata durumunda boş map ile devam et
        }
      }
      
      // Tarihi güvenli şekilde çıkar
      DateTime tarih = DateTime.now();
      if (map['tarih'] != null) {
        try {
          if (map['tarih'] is Timestamp) {
            tarih = (map['tarih'] as Timestamp).toDate();
          } else if (map['tarih'] is String) {
            tarih = DateTime.parse(map['tarih']);
          } else if (map['tarih'] is int) {
            tarih = DateTime.fromMillisecondsSinceEpoch(map['tarih']);
          }
        } catch (e) {
          print('Tarih dönüştürme hatası: $e');
          // Hata durumunda şimdiki zaman ile devam et
        }
      }
      
      // Kişiselleştirilmiş tavsiyeleri güvenli şekilde çıkar
      List<String> tavsiyeler = [];
      if (map['kisiselestirilmisTavsiyeler'] != null) {
        try {
          if (map['kisiselestirilmisTavsiyeler'] is List) {
            tavsiyeler = (map['kisiselestirilmisTavsiyeler'] as List)
                .map((item) => item?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .toList();
          }
        } catch (e) {
          print('Tavsiyeler dönüştürme hatası: $e');
          // Hata durumunda boş liste ile devam et
        }
      }
      
      return AnalizSonucu(
        iliskiPuani: map['iliskiPuani'] is int ? map['iliskiPuani'] as int : 
                    (map['iliskiPuani'] is num ? (map['iliskiPuani'] as num).toInt() : 0),
        kategoriPuanlari: kategoriPuanlari,
        tarih: tarih,
        kisiselestirilmisTavsiyeler: tavsiyeler,
      );
    } catch (e) {
      print('AnalizSonucu oluşturma hatası: $e');
      // Hata durumunda temel bir analiz sonucu döndür
      return AnalizSonucu(
        iliskiPuani: 0,
        kategoriPuanlari: {},
        tarih: DateTime.now(),
        kisiselestirilmisTavsiyeler: [],
      );
    }
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
    try {
      Map<String, dynamic> data = doc.data() ?? {};
      
      // Analiz geçmişini dönüştürme
      List<AnalizSonucu> analizGecmisi = [];
      if (data['analizGecmisi'] != null) {
        try {
          analizGecmisi = (data['analizGecmisi'] as List)
              .map((analizMap) {
                if (analizMap is Map<String, dynamic>) {
                  try {
                    return AnalizSonucu.fromMap(analizMap);
                  } catch (e) {
                    print('Tek bir analiz sonucu dönüştürme hatası: $e');
                    return null;
                  }
                }
                return null;
              })
              .whereType<AnalizSonucu>() // null olmayan değerleri filtrele
              .toList();
        } catch (e) {
          print('Analiz geçmişi dönüştürme hatası: $e');
          // Hata durumunda boş liste ile devam et
        }
      }
      
      // Son analiz sonucunu dönüştürme
      AnalizSonucu? sonAnalizSonucu;
      if (data['sonAnalizSonucu'] != null) {
        try {
          if (data['sonAnalizSonucu'] is Map<String, dynamic>) {
            sonAnalizSonucu = AnalizSonucu.fromMap(data['sonAnalizSonucu'] as Map<String, dynamic>);
          }
        } catch (e) {
          print('Son analiz sonucu dönüştürme hatası: $e');
          // Hata durumunda null ile devam et
        }
      }
      
      // Diğer alan dönüşümleri için güvenli yöntemler
      DateTime? getDateTime(dynamic value) {
        if (value == null) return null;
        try {
          if (value is Timestamp) return value.toDate();
          if (value is String) return DateTime.parse(value);
          return null;
        } catch (e) {
          print('DateTime dönüştürme hatası: $e');
          return null;
        }
      }
      
      // Kullanıcı modeli oluşturma
      return UserModel(
        id: doc.id,
        email: data['email'] as String? ?? '',
        displayName: data['displayName'] as String?,
        photoURL: data['photoURL'] as String?,
        isPremium: data['isPremium'] as bool? ?? false,
        premiumExpiryDate: getDateTime(data['premiumExpiry']),
        authProvider: data['authProvider'] as String?,
        firstName: data['firstName'] as String?,
        lastName: data['lastName'] as String?,
        gender: data['gender'] as String?,
        birthDate: getDateTime(data['birthDate']),
        profileCompleted: data['profileCompleted'] as bool? ?? false,
        createdAt: getDateTime(data['createdAt']) ?? DateTime.now(),
        lastLoginAt: getDateTime(data['lastLoginAt']) ?? DateTime.now(),
        preferences: data['preferences'] as Map<String, dynamic>? ?? {},
        sonAnalizSonucu: sonAnalizSonucu,
        analizGecmisi: analizGecmisi,
      );
    } catch (e) {
      print('UserModel oluşturma hatası: $e');
      // Temel bir kullanıcı döndür
      return UserModel(
        id: doc.id,
        email: '',
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );
    }
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