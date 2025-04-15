import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Türkçe karakter girişi için yardımcı servis
class InputService {
  /// TextField için TextInputFormatter oluşturur
  static List<TextInputFormatter> getTurkishTextFormatters() {
    // FilteringTextInputFormatter.deny kullanarak sınırlamaları engelliyoruz
    return [
      TurkishTextInputFormatter(),
      FilteringTextInputFormatter.deny(RegExp(r'^\s*$')), // Yalnızca boşluk engelleme
    ];
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
    // Türkçe karakterler: ğ, ü, ş, i, ö, ç, ı, Ğ, Ü, Ş, İ, Ö, Ç, I
    // Değişiklik yapılmadan önce karakter kontrolü yapalım 
    if (newValue.text.contains(RegExp(r'[ğüşiöçıĞÜŞİÖÇI]'))) {
      // Türkçe karakter içeriyorsa doğru şekilde geri döndürelim
      return newValue;
    }
    
    // Bazı durumlarda Flutter'ın IME klavye entegrasyonu 
    // Türkçe karakterleri ASCII eşdeğerlerine dönüştürebilir
    // Bu durumları kontrol edip düzeltelim
    String correctedText = newValue.text;
    
    // Genel ASCII-Türkçe dönüşüm kontrolleri
    correctedText = correctedText.replaceAll('g~', 'ğ');
    correctedText = correctedText.replaceAll('G~', 'Ğ');
    correctedText = correctedText.replaceAll('u:', 'ü');
    correctedText = correctedText.replaceAll('U:', 'Ü');
    correctedText = correctedText.replaceAll('s,', 'ş');
    correctedText = correctedText.replaceAll('S,', 'Ş');
    correctedText = correctedText.replaceAll('o:', 'ö');
    correctedText = correctedText.replaceAll('O:', 'Ö'); 
    correctedText = correctedText.replaceAll('c,', 'ç');
    correctedText = correctedText.replaceAll('C,', 'Ç');
    correctedText = correctedText.replaceAll('i\'', 'ı');
    correctedText = correctedText.replaceAll('I\'', 'I');
    
    // Düzeltilmiş bir metin varsa, imleç pozisyonunu da ayarlayalım
    if (correctedText != newValue.text) {
      return TextEditingValue(
        text: correctedText,
        selection: TextSelection.collapsed(
          offset: newValue.selection.baseOffset + 
            (correctedText.length - newValue.text.length),
        ),
      );
    }
    
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