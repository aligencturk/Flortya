import 'package:cloud_firestore/cloud_firestore.dart';
import 'analysis_result_model.dart';

class Message {
  final String id;
  final String content;
  final DateTime sentAt;
  final bool sentByUser;
  final bool isAnalyzed;
  final String? imageUrl;
  final AnalysisResult? analysisResult;
  final String userId;
  final String? errorMessage;
  final bool isAnalyzing;

  Message({
    required this.id,
    required this.content,
    required this.sentAt,
    required this.sentByUser,
    this.isAnalyzed = false,
    this.imageUrl,
    this.analysisResult,
    required this.userId,
    this.errorMessage,
    this.isAnalyzing = false,
  });

  Message copyWith({
    String? id,
    String? content,
    DateTime? sentAt,
    bool? sentByUser,
    bool? isAnalyzed,
    String? imageUrl,
    AnalysisResult? analysisResult,
    String? userId,
    String? errorMessage,
    bool? isAnalyzing,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      sentAt: sentAt ?? this.sentAt,
      sentByUser: sentByUser ?? this.sentByUser,
      isAnalyzed: isAnalyzed ?? this.isAnalyzed,
      imageUrl: imageUrl ?? this.imageUrl,
      analysisResult: analysisResult ?? this.analysisResult,
      userId: userId ?? this.userId,
      errorMessage: errorMessage ?? this.errorMessage,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'sentAt': Timestamp.fromDate(sentAt),
      'sentByUser': sentByUser,
      'isAnalyzed': isAnalyzed,
      'imageUrl': imageUrl,
      'analysisResult': analysisResult?.toMap(),
      'userId': userId,
      'errorMessage': errorMessage,
      'isAnalyzing': isAnalyzing,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map, {String? docId}) {
    String messageId = '';
    
    if (docId != null && docId.isNotEmpty) {
      messageId = docId;
    } else if (map['id'] != null && map['id'].toString().isNotEmpty) {
      messageId = map['id'];
    }
    
    if (messageId.isEmpty) {
      print('UYARI: Message.fromMap - Boş ID oluşturuldu. DocID: $docId, Map ID: ${map['id']}');
    }

    return Message(
      id: messageId,
      content: map['content'] ?? '',
      sentAt: map['sentAt'] != null
          ? (map['sentAt'] is Timestamp
              ? (map['sentAt'] as Timestamp).toDate()
              : DateTime.parse(map['sentAt'].toString()))
          : DateTime.now(),
      sentByUser: map['sentByUser'] ?? true,
      isAnalyzed: map['isAnalyzed'] ?? false,
      imageUrl: map['imageUrl'],
      analysisResult: map['analysisResult'] != null
          ? AnalysisResult.fromMap(map['analysisResult'])
          : null,
      userId: map['userId'] ?? '',
      errorMessage: map['errorMessage'],
      isAnalyzing: map['isAnalyzing'] ?? false,
    );
  }

  @override
  String toString() {
    return 'Message(id: $id, content: $content, sentAt: $sentAt, sentByUser: $sentByUser, isAnalyzed: $isAnalyzed, imageUrl: $imageUrl, userId: $userId)';
  }
} 