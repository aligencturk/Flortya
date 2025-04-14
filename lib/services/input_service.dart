import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Türkçe karakter girişi için yardımcı servis
class InputService {
  /// TextField için TextInputFormatter oluşturur
  static List<TextInputFormatter> getTurkishTextFormatters() {
    return [TurkishTextInputFormatter()];
  }
  
  /// TextField'a Türkçe karakter desteği ekleyen dekorasyon ve formatter
  static InputDecoration getTurkishInputDecoration({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? helperText,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      helperText: helperText,
      errorText: errorText,
      helperStyle: const TextStyle(fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// Türkçe karakter desteği sağlayan TextInputFormatter
class TurkishTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Türkçe karakter girişi için özel işlem gerekmiyor
    // Flutter'ın kendi sistemini kullanarak Türkçe karakterleri doğrudan destekler
    // Bu formatter gelecekte özel bir işlem gerekirse eklenebilir
    return newValue;
  }
}

/// Tüm metinlerde Türkçe karakter kontrolü
extension StringExtension on String {
  String get fixTurkishChars {
    return this
        .replaceAll('i', 'i')
        .replaceAll('ı', 'ı')
        .replaceAll('ğ', 'ğ')
        .replaceAll('ü', 'ü')
        .replaceAll('ş', 'ş')
        .replaceAll('ö', 'ö')
        .replaceAll('ç', 'ç')
        .replaceAll('İ', 'İ')
        .replaceAll('I', 'I')
        .replaceAll('Ğ', 'Ğ')
        .replaceAll('Ü', 'Ü')
        .replaceAll('Ş', 'Ş')
        .replaceAll('Ö', 'Ö')
        .replaceAll('Ç', 'Ç');
  }
} 