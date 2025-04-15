import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

/// Türkçe karakter girişi için yardımcı servis
class InputService {
  /// TextField için TextInputFormatter oluşturur
  static List<TextInputFormatter> getTurkishTextFormatters() {
    // Platform bazlı farklı formatters kullan
    List<TextInputFormatter> formatters = [];
    
    // Her platform için farklı yaklaşım
    if (Platform.isAndroid) {
      formatters.add(AndroidTurkishTextInputFormatter());
    } else if (Platform.isIOS) {
      formatters.add(IOSTurkishTextInputFormatter());
    } else {
      formatters.add(TurkishTextInputFormatter());
    }
    
    // Boş mesaj gönderimini engelle
    formatters.add(FilteringTextInputFormatter.deny(RegExp(r'^\s*$')));
    
    return formatters;
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
  
  /// Klavye girişini aktif etmek için method
  static void activateSystemKeyboard(BuildContext context) {
    // Aktif TextField'a odaklandığında sistem klavyesini etkinleştir
    TextInput.finishAutofillContext(shouldSave: true);
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }
}

/// Android için Türkçe karakter desteği sağlayan TextInputFormatter
class AndroidTurkishTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Android'de Türkçe karakter girişi için özel işlemler
    
    // Eğer yeni metin Türkçe karakter içeriyorsa doğrudan dön
    if (newValue.text.contains(RegExp(r'[ğüşiöçıĞÜŞİÖÇI]'))) {
      return newValue;
    }
    
    // Android'de klavye girişiyle ilgili olası sorunları çöz
    String correctedText = newValue.text;
    
    // Türkçe karakter giriş kalıplarını kontrol et
    correctedText = _applyTurkishCharacterCorrections(correctedText);
    
    // Düzeltilmiş bir metin varsa, imleç pozisyonunu ayarla
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
  
  // Türkçe karakterleri düzelten yardımcı metod
  String _applyTurkishCharacterCorrections(String text) {
    // Genel ASCII-Türkçe dönüşüm kontrolleri (Android klavye için)
    text = text.replaceAll('g~', 'ğ');
    text = text.replaceAll('G~', 'Ğ');
    text = text.replaceAll('u~', 'ü');
    text = text.replaceAll('U~', 'Ü');
    text = text.replaceAll('s~', 'ş');
    text = text.replaceAll('S~', 'Ş');
    text = text.replaceAll('o~', 'ö');
    text = text.replaceAll('O~', 'Ö'); 
    text = text.replaceAll('c~', 'ç');
    text = text.replaceAll('C~', 'Ç');
    text = text.replaceAll('i~', 'ı');
    text = text.replaceAll('I~', 'İ');
    
    // Alternatif dönüşümler (farklı Android klavyeler için)
    text = text.replaceAll('g^', 'ğ');
    text = text.replaceAll('G^', 'Ğ');
    text = text.replaceAll('u:', 'ü');
    text = text.replaceAll('U:', 'Ü');
    text = text.replaceAll('s,', 'ş');
    text = text.replaceAll('S,', 'Ş');
    text = text.replaceAll('o:', 'ö');
    text = text.replaceAll('O:', 'Ö'); 
    text = text.replaceAll('c,', 'ç');
    text = text.replaceAll('C,', 'Ç');
    text = text.replaceAll('i\'', 'ı');
    text = text.replaceAll('I\'', 'I');
    
    return text;
  }
}

/// iOS için Türkçe karakter desteği sağlayan TextInputFormatter
class IOSTurkishTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // iOS'da Türkçe karakter girişi genelde sorunsuz çalışır
    // Ancak yine de özel durumlar için kontrol ekleyelim
    
    // Eğer yeni metin Türkçe karakter içeriyorsa doğrudan dön
    if (newValue.text.contains(RegExp(r'[ğüşiöçıĞÜŞİÖÇI]'))) {
      return newValue;
    }
    
    // iOS klavye girişiyle ilgili olası sorunları çöz
    String correctedText = newValue.text;
    
    // iOS'a özgü dönüşümler
    correctedText = correctedText.replaceAll('g~', 'ğ');
    correctedText = correctedText.replaceAll('G~', 'Ğ');
    correctedText = correctedText.replaceAll('u~', 'ü');
    correctedText = correctedText.replaceAll('U~', 'Ü');
    correctedText = correctedText.replaceAll('s~', 'ş');
    correctedText = correctedText.replaceAll('S~', 'Ş');
    correctedText = correctedText.replaceAll('o~', 'ö');
    correctedText = correctedText.replaceAll('O~', 'Ö'); 
    correctedText = correctedText.replaceAll('c~', 'ç');
    correctedText = correctedText.replaceAll('C~', 'Ç');
    correctedText = correctedText.replaceAll('i~', 'ı');
    correctedText = correctedText.replaceAll('I~', 'İ');
    
    // Düzeltilmiş bir metin varsa, imleç pozisyonunu ayarla
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

/// Genel Türkçe karakter desteği sağlayan TextInputFormatter
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