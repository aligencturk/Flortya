import 'package:flutter/material.dart';

class AppColors {
  // Ana renkler
  static const Color primary = Color(0xFF5E35B1);
  static const Color secondary = Color(0xFF03DAC5);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFB00020);
  
  // Metin renkleri
  static const Color textPrimary = Color(0xFF121212);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFDDDDDD);
  
  // Mesaj baloncukları
  static const Color userMessageBubble = Color(0xFFD0BCFF);
  static const Color assistantMessageBubble = Color(0xFFE6E0E9);
  
  // Analiz sonuçları
  static const Color positiveEmotion = Color(0xFF66BB6A);
  static const Color negativeEmotion = Color(0xFFEF5350);
  static const Color neutralEmotion = Color(0xFF42A5F5);
  
  // Severity renkleri
  static const List<Color> severityColors = [
    Color(0xFF00C853),  // 1 - En düşük
    Color(0xFF69F0AE),
    Color(0xFF76FF03),
    Color(0xFFFFEB3B),
    Color(0xFFFFC107),
    Color(0xFFFF9800),
    Color(0xFFFF5722),
    Color(0xFFF44336),
    Color(0xFFE53935),
    Color(0xFFB71C1C),  // 10 - En yüksek
  ];
  
  // UI bileşenleri
  static const Color cardBackground = Colors.white;
  static const Color divider = Color(0xFFEEEEEE);
  static const Color shadow = Color(0x40000000);
  
  // Durum renkleri
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);
  
  // Helper method to get color for severity
  static Color getSeverityColor(int severity) {
    final index = (severity - 1).clamp(0, 9);
    return severityColors[index];
  }
} 