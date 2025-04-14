import 'package:cloud_firestore/cloud_firestore.dart';
import 'analysis_result.dart';

class Message {
  final String id;
  final String content;
  final DateTime sentAt;
  final bool sentByUser;
  final bool isAnalyzed;
  final String? imageUrl;
  final AnalysisResult? analysisResult;

  Message({
    required this.id,
    required this.content,
    required this.sentAt,
    required this.sentByUser,
    this.isAnalyzed = false,
    this.imageUrl,
    this.analysisResult,
  });

  Message copyWith({
    String? id,
    String? content,
    DateTime? sentAt,
    bool? sentByUser,
    bool? isAnalyzed,
    String? imageUrl,
    AnalysisResult? analysisResult,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      sentAt: sentAt ?? this.sentAt,
      sentByUser: sentByUser ?? this.sentByUser,
      isAnalyzed: isAnalyzed ?? this.isAnalyzed,
      imageUrl: imageUrl ?? this.imageUrl,
      analysisResult: analysisResult ?? this.analysisResult,
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
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] ?? '',
      content: map['content'] ?? '',
      sentAt: (map['sentAt'] as Timestamp).toDate(),
      sentByUser: map['sentByUser'] ?? false,
      isAnalyzed: map['isAnalyzed'] ?? false,
      imageUrl: map['imageUrl'],
      analysisResult: map['analysisResult'] != null 
          ? AnalysisResult.fromMap(map['analysisResult']) 
          : null,
    );
  }

  @override
  String toString() {
    return 'Message(id: $id, content: $content, sentAt: $sentAt, sentByUser: $sentByUser, isAnalyzed: $isAnalyzed, imageUrl: $imageUrl)';
  }
} 