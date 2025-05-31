import 'package:cloud_firestore/cloud_firestore.dart';

/// İlişki analiz sonucunu temsil eden veri modeli
class AnalysisResult {
  final String id;
  final String messageId;
  final String emotion;
  final String intent;
  final String tone;
  final int severity;
  final String persons;
  final Map<String, dynamic> aiResponse;
  final DateTime createdAt;

  AnalysisResult({
    required this.id,
    required this.messageId,
    required this.emotion,
    required this.intent,
    required this.tone,
    required this.severity,
    required this.persons,
    required this.aiResponse,
    required this.createdAt,
  });

  factory AnalysisResult.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AnalysisResult(
      id: doc.id,
      messageId: data['messageId'] ?? '',
      emotion: data['emotion'] ?? '',
      intent: data['intent'] ?? '',
      tone: data['tone'] ?? '',
      severity: data['severity'] ?? 0,
      persons: data['persons'] ?? '',
      aiResponse: data['aiResponse'] ?? {},
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Map veri türünden doğrudan oluşturma
  factory AnalysisResult.fromMap(Map<String, dynamic> map) {
    try {
      print('🧩 AnalysisResult.fromMap çağrıldı: ${map.keys.toList()}');
      
      // Zorunlu alanları kontrol et, eksikse varsayılan değer kullan
      String id = map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      String messageId = map['messageId']?.toString() ?? id;
      String emotion = map['emotion']?.toString() ?? 'Belirtilmemiş';
      String intent = map['intent']?.toString() ?? 'Belirtilmemiş';
      String tone = map['tone']?.toString() ?? 'Nötr';
      int severity = 0;
      
      // severity dönüşümünü güvenli bir şekilde yap
      if (map['severity'] is int) {
        severity = map['severity'];
      } else if (map['severity'] is String) {
        try {
          severity = int.parse(map['severity'].toString());
        } catch (e) {
          severity = 5;
        }
      } else {
        severity = 5;
      }
      
      String persons = map['persons']?.toString() ?? 'Belirtilmemiş';
      
      // aiResponse dönüşümü
      Map<String, dynamic> aiResponse = {};
      if (map['aiResponse'] is Map) {
        aiResponse = Map<String, dynamic>.from(map['aiResponse']);
      } else {
        // aiResponse yoksa, mesajYorumu ve cevapOnerileri varsa onları kullan
        if (map.containsKey('mesajYorumu')) {
          aiResponse['mesajYorumu'] = map['mesajYorumu'];
        }
        if (map.containsKey('cevapOnerileri')) {
          aiResponse['cevapOnerileri'] = map['cevapOnerileri'];
        }
      }
      
      // aiResponse hala boşsa varsayılan değerler koy
      if (aiResponse.isEmpty) {
        aiResponse = {
          'mesajYorumu': 'Analiz sonucu bulunamadı',
          'cevapOnerileri': ['İletişim tekniklerini geliştir']
        };
      }
      
      // createdAt dönüşümü
      DateTime createdAt;
      try {
        if (map['createdAt'] is String) {
          createdAt = DateTime.parse(map['createdAt']);
        } else {
          createdAt = DateTime.now();
        }
      } catch (e) {
        createdAt = DateTime.now();
      }
      
      print('✅ AnalysisResult oluşturuldu: id=$id, emotion=$emotion');
      
      return AnalysisResult(
        id: id,
        messageId: messageId,
        emotion: emotion,
        intent: intent,
        tone: tone,
        severity: severity,
        persons: persons,
        aiResponse: aiResponse,
        createdAt: createdAt,
      );
    } catch (e, stackTrace) {
      print('❌ AnalysisResult.fromMap hatası: $e');
      print('❌ Stack trace: $stackTrace');
      print('❌ Map içeriği: $map');
      
      // Hata durumunda, varsayılan bir AnalysisResult nesnesi oluştur
      return AnalysisResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        emotion: 'Hata',
        intent: 'Hata',
        tone: 'Hata',
        severity: 5,
        persons: 'Hata',
        aiResponse: {
          'mesajYorumu': 'Analiz sonucu işlenirken bir hata oluştu: $e',
          'cevapOnerileri': ['Tekrar analiz yapmayı deneyin']
        },
        createdAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toMap() {
    // Temel map oluştur ve null değerleri kontrol et
    final Map<String, dynamic> resultMap = {};
    
    // Temel alanları kontrol edip ekle
    if (id.isNotEmpty) resultMap['id'] = id;
    if (messageId.isNotEmpty) resultMap['messageId'] = messageId;
    if (emotion.isNotEmpty) resultMap['emotion'] = emotion;
    if (intent.isNotEmpty) resultMap['intent'] = intent;
    if (tone.isNotEmpty) resultMap['tone'] = tone;
    
    // severity değerini ekle (int olduğu için boşluk kontrolü gerekmez)
    resultMap['severity'] = severity;
    
    if (persons.isNotEmpty) resultMap['persons'] = persons;
    
    // aiResponse map'ini güvenli bir şekilde ekle
    if (aiResponse.isNotEmpty) {
      // Sorunlu olabilecek alt-alanlarda içerikleri kontrol et
      final Map<String, dynamic> safeAiResponse = {};
      
      aiResponse.forEach((key, value) {
        // String ve List tipi kontrolleri
        if (value != null) {
          if (value is List) {
            final List<dynamic> safeList = [];
            for (final item in value) {
              if (item != null) safeList.add(item);
            }
            if (safeList.isNotEmpty) safeAiResponse[key] = safeList;
          } else {
            safeAiResponse[key] = value;
          }
        }
      });
      
      if (safeAiResponse.isNotEmpty) {
        resultMap['aiResponse'] = safeAiResponse;
      }
    }
    
    // Tarih ekle
    resultMap['createdAt'] = Timestamp.fromDate(createdAt);
    
    return resultMap;
  }

  @override
  String toString() {
    return 'AnalysisResult{id: $id, messageId: $messageId, emotion: $emotion, intent: $intent, tone: $tone, persons: $persons}';
  }
}

/// İlişki tavsiyesi sohbeti için mesaj modeli
class ChatMessage {
  final String id;
  final String userId;
  final String content;
  final String role; // 'user' veya 'model'
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.content,
    required this.role,
    required this.timestamp,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      userId: data['userId'] ?? '',
      content: data['content'] ?? '',
      role: data['role'] ?? 'user',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'content': content,
      'role': role,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  Map<String, String> toApiFormat() {
    return {
      'role': role,
      'text': content,
    };
  }

  @override
  String toString() {
    return 'ChatMessage{id: $id, role: $role, content: $content}';
  }
}

/// İlişki tavsiyesi sohbeti modeli
class AdviceChat {
  final String id;
  final String userId;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String title;

  AdviceChat({
    required this.id,
    required this.userId,
    required this.messages,
    required this.createdAt,
    this.updatedAt,
    required this.title,
  });
  
  factory AdviceChat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdviceChat(
      id: doc.id,
      userId: data['userId'] ?? '',
      messages: (data['messages'] as List<dynamic>?)
          ?.map((messageData) => ChatMessage(
                id: messageData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                userId: messageData['userId'] ?? '',
                content: messageData['content'] ?? '',
                role: messageData['role'] ?? 'user',
                timestamp: (messageData['timestamp'] as Timestamp).toDate(),
              ))
          .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      title: data['title'] ?? 'İlişki Tavsiyesi Sohbeti',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'messages': messages.map((message) => message.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'title': title,
    };
  }

  @override
  String toString() {
    return 'AdviceChat{id: $id, title: $title, messageCount: ${messages.length}}';
  }
} 