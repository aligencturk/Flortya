import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  // Firestore'dan veri okuma
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
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
    };
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
    );
  }
} 