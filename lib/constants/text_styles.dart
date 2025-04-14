import 'package:flutter/material.dart';
import 'colors.dart';

class AppTextStyles {
  // Ana başlıklar
  static const TextStyle headline1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );
  
  static const TextStyle headline2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle headline3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  // Gövde metinleri
  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );
  
  // Buton metinleri
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  
  // Mesaj metinleri
  static const TextStyle userMessageText = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle assistantMessageText = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );
  
  // Analiz sonuçları
  static const TextStyle analysisTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );
  
  static const TextStyle analysisResult = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle suggestionText = TextStyle(
    fontSize: 15,
    fontStyle: FontStyle.italic,
    color: AppColors.textSecondary,
  );
  
  // Caption ve yardımcı metin
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
  
  static const TextStyle timestamp = TextStyle(
    fontSize: 11,
    color: AppColors.textSecondary,
    fontStyle: FontStyle.italic,
  );
  
  // Çekmeceli menü stilleri
  static const TextStyle drawerHeader = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  
  static const TextStyle drawerItem = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  // Form elemanları
  static const TextStyle textFieldLabel = TextStyle(
    fontSize: 14,
    color: AppColors.primary,
    fontWeight: FontWeight.w500,
  );
  
  static const TextStyle textFieldHint = TextStyle(
    fontSize: 16,
    color: AppColors.textSecondary,
    fontStyle: FontStyle.italic,
  );
} 