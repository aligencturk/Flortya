enum TextRecognitionScript {
  latin,
  chinese,
  devanagari,
  japanese,
  korean;

  String get name {
    switch (this) {
      case TextRecognitionScript.latin:
        return 'Latin';
      case TextRecognitionScript.chinese:
        return 'Çince';
      case TextRecognitionScript.devanagari:
        return 'Devanagari';
      case TextRecognitionScript.japanese:
        return 'Japonca';
      case TextRecognitionScript.korean:
        return 'Korece';
    }
  }
} 