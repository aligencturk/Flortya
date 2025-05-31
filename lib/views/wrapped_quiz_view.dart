import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../views/conversation_summary_view.dart';

class WrappedQuizView extends StatefulWidget {
  final List<Map<String, String>> summaryData;

  const WrappedQuizView({
    super.key,
    required this.summaryData,
  });

  @override
  State<WrappedQuizView> createState() => _WrappedQuizViewState();
}

class _WrappedQuizViewState extends State<WrappedQuizView> {
  int _currentQuestionIndex = 0;
  int _correctAnswers = 0;
  List<Map<String, dynamic>> _quizQuestions = [];
  bool _showingResult = false;
  bool _answeredCorrectly = false;
  
  @override
  void initState() {
    super.initState();
    _prepareQuizQuestions();
    
    // Tam ekran modu
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    // Tam ekran modunu kapat
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
  
  void _prepareQuizQuestions() {
    debugPrint('📝 Wrapped Quiz soruları hazırlanıyor...');
    debugPrint('📝 Toplam kart sayısı: ${widget.summaryData.length}');
    
    // Her kart için bir hata ayıklama log'u
    for (int i = 0; i < widget.summaryData.length; i++) {
      final card = widget.summaryData[i];
      debugPrint('Kart #${i+1}:');
      debugPrint('  Başlık: ${card['title']}');
      debugPrint('  Yorum: ${card['comment']}');
    }
    
    // Soruların oluşturulması - her bir wrapped card için bir soru
    _quizQuestions = [
      {
        'question': '🗓️ İlk mesaj ne zaman atıldı?',
        'wrappedIndex': 0, // İlk Mesaj – Son Mesaj kartı
        'options': _generateDateOptions(0),
        'correctOptionIndex': 0,
      },
      {
        'question': '📊 Kim daha çok mesaj atmış?',
        'wrappedIndex': 1, // Mesaj Sayıları kartı
        'options': _generateSenderOptions(1),
        'correctOptionIndex': 0,
      },
      {
        'question': '📅 En çok hangi ay mesajlaşılmış?',
        'wrappedIndex': 2, // En Yoğun Ay/Gün kartı
        'options': _generateMonthOptions(2),
        'correctOptionIndex': 0,
      },
      {
        'question': '🔤 En çok kullanılan kelime hangisi?',
        'wrappedIndex': 3, // En Çok Kullanılan Kelimeler kartı
        'options': _generateWordOptions(3),
        'correctOptionIndex': 0,
      },
      {
        'question': '😊 Sohbetin genel tonu nasıl?',
        'wrappedIndex': 4, // Pozitif/Negatif Ton kartı
        'options': _generateMoodOptions(4),
        'correctOptionIndex': 0,
      },
      {
        'question': '🚀 En çok mesaj hangi gün atılmış?',
        'wrappedIndex': 5, // Mesaj Patlaması kartı
        'options': _generateSpikeOptions(5),
        'correctOptionIndex': 0,
      },
      {
        'question': '🔕 En uzun sessizlik ne kadar sürmüş?',
        'wrappedIndex': 6, // Sessizlik Süresi kartı
        'options': _generateSilenceOptions(6),
        'correctOptionIndex': 0,
      },
      {
        'question': '💬 Mesajlaşma tarzınız nasıl tanımlanabilir?',
        'wrappedIndex': 7, // İletişim Tipi kartı
        'options': _generateCommunicationTypeOptions(7),
        'correctOptionIndex': 0,
      },
      {
        'question': '📝 Mesajlarda en çok hangi tip içerik var?',
        'wrappedIndex': 8, // Mesaj Tipleri kartı
        'options': _generateMessageTypeOptions(8),
        'correctOptionIndex': 0,
      },
      {
        'question': '🎯 Quiz sonuna geldin! Nasıl gittiğini görelim...',
        'wrappedIndex': 9, // Kişisel Performans kartı
        'options': _generatePerformanceOptions(),
        'correctOptionIndex': 0,
      },
    ];
    
    // Hata ayıklama - tüm soruları ve seçenekleri logla
    for (var i = 0; i < _quizQuestions.length; i++) {
      final q = _quizQuestions[i];
      debugPrint('--------------------------------');
      debugPrint('Soru ${i+1}: ${q['question']}');
      
      // İlgili wrapped kartını log'la
      final wrappedIndex = q['wrappedIndex'] as int;
      if (wrappedIndex < widget.summaryData.length) {
        debugPrint('Bağlantılı Kart (index: $wrappedIndex):');
        debugPrint('  Başlık: ${widget.summaryData[wrappedIndex]['title']}');
        debugPrint('  Yorum: ${widget.summaryData[wrappedIndex]['comment']}');
      } else {
        debugPrint('⚠️ Bağlantılı kart yok! (index: $wrappedIndex), kart sayısı: ${widget.summaryData.length}');
      }
      
      // Seçenekleri log'la
      final options = q['options'] as List<String>;
      final correctIndex = q['correctOptionIndex'] as int;
      
      for (var j = 0; j < options.length; j++) {
        if (j == correctIndex) {
          debugPrint('✅ Doğru Yanıt: ${options[j]}');
        } else {
          debugPrint('❌ Yanlış Yanıt: ${options[j]}');
        }
      }
    }
    
    // Her soru için seçenekleri karıştır
    for (var question in _quizQuestions) {
      final options = question['options'] as List<String>;
      final correctOption = options[0]; // İlk seçenek her zaman doğru cevap
      
      // Seçenekleri karıştır
      options.shuffle();
      
      // Doğru cevabın yeni indeksini bul
      question['correctOptionIndex'] = options.indexOf(correctOption);
    }
  }
  
  // Veriden bilgi çıkarma yardımcı fonksiyonu
  String _extractInfoFromComment(int index, String pattern) {
    try {
      if (index >= widget.summaryData.length) {
        debugPrint('Geçersiz veri indeksi: $index, veri uzunluğu: ${widget.summaryData.length}');
        return '';
      }
      
      final comment = widget.summaryData[index]['comment'] ?? '';
      final title = widget.summaryData[index]['title'] ?? '';
      
      debugPrint('🔍 Veri çıkarma - Kart #${index+1}:');
      debugPrint('  Başlık: $title');
      debugPrint('  Yorum: $comment');
      debugPrint('  Aranan desen: $pattern');
      
      // Önce yorum içinde düzenli ifade ile arama yap
      final regExp = RegExp(pattern, caseSensitive: false);
      final match = regExp.firstMatch(comment);
      
      if (match != null && match.groupCount >= 1) {
        final extractedInfo = match.group(1) ?? '';
        debugPrint('✅ Yorumda düzenli ifade eşleşmesi: "$extractedInfo"');
        if (extractedInfo.isNotEmpty) {
          return extractedInfo.trim();
        }
      }
      
      // Yorumda tırnak içindeki metinleri ara
      final quotePattern = RegExp(r'["\'']([^\'"]+)[\'"]', caseSensitive: false);
      final quoteMatches = quotePattern.allMatches(comment);
      
      if (quoteMatches.isNotEmpty) {
        for (final qMatch in quoteMatches) {
          if (qMatch.groupCount >= 1) {
            final quoted = qMatch.group(1) ?? '';
            debugPrint('✅ Yorumda tırnak içi metin: "$quoted"');
            if (quoted.isNotEmpty) {
              return quoted.trim();
            }
          }
        }
      }
      
      // Başlıkta düzenli ifade ile arama yap
      final titleMatch = regExp.firstMatch(title);
      if (titleMatch != null && titleMatch.groupCount >= 1) {
        final extractedInfo = titleMatch.group(1) ?? '';
        debugPrint('✅ Başlıkta düzenli ifade eşleşmesi: "$extractedInfo"');
        if (extractedInfo.isNotEmpty) {
          return extractedInfo.trim();
        }
      }
      
      // Başlıkta iki nokta varsa, sonrasını al
      if (title.contains(':')) {
        final parts = title.split(':');
        if (parts.length > 1 && parts[1].trim().isNotEmpty) {
          debugPrint('✅ Başlık ayırma ile bilgi bulundu: "${parts[1].trim()}"');
          return parts[1].trim();
        }
      }
      
      // Başlıkta tire işareti varsa, ayır ve uygun parçayı al
      if (title.contains('-') || title.contains('–')) {
        final parts = title.split(RegExp(r'[-–]'));
        if (parts.length > 1 && parts[1].trim().isNotEmpty) {
          debugPrint('✅ Başlık tire ile bilgi bulundu: "${parts[1].trim()}"');
          return parts[1].trim();
        }
      }
      
      // Yorumda özel anahtar kelimeleri ara
      final keywordPatterns = {
        'tarih': RegExp(r'(\d{1,2}[\.\/]\d{1,2}[\.\/]\d{2,4})', caseSensitive: false),
        'ay': RegExp(r'([OoŞşMmNnHhTtAaEeKk][a-zğüşıöç]+)', caseSensitive: false),
        'yüzde': RegExp(r'(\d+)\s*%', caseSensitive: false),
        'gün': RegExp(r'(\d+)\s+g[üu]n', caseSensitive: false),
        'kelime': RegExp(r'\b(\w+)\b', caseSensitive: false)
      };
      
      for (final entry in keywordPatterns.entries) {
        final matches = entry.value.allMatches(comment);
        if (matches.isNotEmpty) {
          for (final m in matches) {
            if (m.groupCount >= 1) {
              final extracted = m.group(1) ?? '';
              debugPrint('✅ Yorumda "${entry.key}" deseni ile eşleşme: "$extracted"');
              if (extracted.isNotEmpty) {
                return extracted.trim();
              }
            }
          }
        }
      }
      
      // Yorumun ilk cümlesini al
      final firstSentence = comment.split('.').first;
      if (firstSentence.length > 10) {
        debugPrint('⚠️ İlk cümleyi kullanıyorum: "$firstSentence"');
        return firstSentence.trim();
      }
      
      // Hiçbir şey bulunamadı
      debugPrint('❌ Veri çıkarılamadı. Desen kullanılarak ilgili bilgi bulunamadı.');
      return '';
    } catch (e) {
      debugPrint('❌ Veri çıkarma hatası: $e');
      return '';
    }
  }
  
  // İlk mesaj tarih seçenekleri
  List<String> _generateDateOptions(int index) {
    try {
      // İlk mesaj tarihi veriden çıkar
      final comment = widget.summaryData[index]['comment'] ?? '';
      final title = widget.summaryData[index]['title'] ?? '';
      
      debugPrint('📆 Tarih analizi - Kart #${index+1}:');
      debugPrint('  Başlık: $title');
      debugPrint('  Yorum: $comment');
      
      String correctDate = '';
      
      // 1. "İlk mesaj" ifadesinden sonraki tarih formatını kontrol et
      int firstMessageIdx = comment.toLowerCase().indexOf("ilk mesaj");
      if (firstMessageIdx != -1) {
        // Tarih desenleri
        List<RegExp> datePatterns = [
          RegExp(r'(\d{1,2}[\.\/]\d{1,2}[\.\/]\d{4})'), // gg.aa.yyyy veya gg/aa/yyyy
          RegExp(r'(\d{1,2}[\.\/]\d{1,2}[\.\/]\d{2})'),  // gg.aa.yy veya gg/aa/yy
          RegExp(r'(\d{1,2}\s+[a-zşçöğüıİ]+\s+\d{4})'),  // gg ay yyyy (5 Ekim 2022)
        ];
        
        // İlk mesajdan sonraki metni al
        String afterFirstMessage = comment.substring(firstMessageIdx);
        
        // Tarih desenlerini kontrol et
        for (var pattern in datePatterns) {
          final match = pattern.firstMatch(afterFirstMessage);
          if (match != null) {
            correctDate = match.group(1) ?? '';
            debugPrint('✅ "İlk mesaj" ifadesinden sonra tarih bulundu: "$correctDate"');
            break;
          }
        }
      }
      
      // 2. Yorumda herhangi bir tarih ara
      if (correctDate.isEmpty) {
        List<RegExp> datePatterns = [
          RegExp(r'(\d{1,2}[\.\/]\d{1,2}[\.\/]\d{4})'), // gg.aa.yyyy veya gg/aa/yyyy
          RegExp(r'(\d{1,2}[\.\/]\d{1,2}[\.\/]\d{2})'),  // gg.aa.yy veya gg/aa/yy
          RegExp(r'(\d{1,2}\s+[a-zşçöğüıİ]+\s+\d{4})'),  // gg ay yyyy (5 Ekim 2022)
        ];
        
        for (var pattern in datePatterns) {
          final match = pattern.firstMatch(comment);
          if (match != null) {
            correctDate = match.group(1) ?? '';
            debugPrint('✅ Yorumda tarih bulundu: "$correctDate"');
            break;
          }
        }
      }
      
      // 3. Başlıkta tarih ara
      if (correctDate.isEmpty) {
        List<RegExp> datePatterns = [
          RegExp(r'(\d{1,2}[\.\/]\d{1,2}[\.\/]\d{4})'), // gg.aa.yyyy veya gg/aa/yyyy
          RegExp(r'(\d{1,2}[\.\/]\d{1,2}[\.\/]\d{2})'),  // gg.aa.yy veya gg/aa/yy
          RegExp(r'(\d{1,2}\s+[a-zşçöğüıİ]+\s+\d{4})'),  // gg ay yyyy (5 Ekim 2022)
        ];
        
        for (var pattern in datePatterns) {
          final match = pattern.firstMatch(title);
          if (match != null) {
            correctDate = match.group(1) ?? '';
            debugPrint('✅ Başlıkta tarih bulundu: "$correctDate"');
            break;
          }
        }
      }
      
      // 4. Başlık "İlk Mesaj" içeriyorsa, yorum içinde bir tarih değeri ara
      if (correctDate.isEmpty && title.contains("İlk Mesaj")) {
        // Aylara göre ara
        final months = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", 
                       "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
        
        for (var month in months) {
          int monthIdx = comment.indexOf(month);
          if (monthIdx != -1) {
            // Ay etrafındaki 20 karakteri al
            int startIdx = max(0, monthIdx - 10);
            int endIdx = min(comment.length, monthIdx + month.length + 10);
            String context = comment.substring(startIdx, endIdx);
            
            // Bu bağlamda bir sayı bul (gün olabilir)
            RegExp dayPattern = RegExp(r'(\d{1,2})');
            final dayMatch = dayPattern.firstMatch(context);
            
            // Ve bir yıl bul
            RegExp yearPattern = RegExp(r'(\d{4})');
            final yearMatch = yearPattern.firstMatch(context);
            
            if (dayMatch != null && yearMatch != null) {
              String day = dayMatch.group(1) ?? '';
              String year = yearMatch.group(1) ?? '';
              correctDate = "$day $month $year";
              debugPrint('✅ Ay değerinden tarih oluşturuldu: "$correctDate"');
              break;
            }
          }
        }
      }
      
      // Hala bulunamadıysa varsayılan değer kullan
      if (correctDate.isEmpty) {
        correctDate = "5 Ekim 2022";
        debugPrint('⚠️ Tarih bulunamadı, varsayılan değer kullanılıyor: "$correctDate"');
      }
      
      // Doğru tarihi standartlaştır (nokta yerine boşluk vs.)
      correctDate = correctDate.replaceAll('.', ' ').replaceAll('/', ' ').trim();
      
      // Yanlış tarih oluştur - gerçekçi bir alternatif (ama doğru değil)
      final random = Random();
      final months = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", 
                     "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
      
      // Doğru tarihin yapısını analiz et
      int correctYear = DateTime.now().year;
      String correctMonth = "Ocak";
      int correctDay = 1;
      
      // Doğru tarih içinde ay adı varsa, onu bul
      for (var month in months) {
        if (correctDate.contains(month)) {
          correctMonth = month;
          break;
        }
      }
      
      // Gün ve yıl bilgisini bulmaya çalış
      final dayYearPattern = RegExp(r'(\d{1,2}).*?(\d{4})');
      final dayYearMatch = dayYearPattern.firstMatch(correctDate);
      
      if (dayYearMatch != null) {
        correctDay = int.tryParse(dayYearMatch.group(1) ?? '1') ?? 1;
        correctYear = int.tryParse(dayYearMatch.group(2) ?? correctYear.toString()) ?? correctYear;
      }
      
      // Farklı bir tarih seç
      String wrongMonth;
      do {
        wrongMonth = months[random.nextInt(months.length)];
      } while (wrongMonth == correctMonth);
      
      int wrongDay = random.nextInt(28) + 1;
      
      // Yılı 1-2 yıl farklı seç (ama gelecekte olmasın)
      int wrongYear;
      do {
        wrongYear = correctYear + (random.nextBool() ? 1 : -1);
      } while (wrongYear > DateTime.now().year);
      
      final wrongDate = "$wrongDay $wrongMonth $wrongYear";
      
      debugPrint('📊 Tarih seçenekleri: Doğru="$correctDate", Yanlış="$wrongDate"');
      
      return [correctDate, wrongDate];
    } catch (e) {
      debugPrint('❌ Tarih seçenekleri üretme hatası: $e');
      return ["5 Ekim 2022", "15 Mayıs 2023"]; // Varsayılan değerler
    }
  }
  
  // Mesaj gönderen seçenekleri
  List<String> _generateSenderOptions(int index) {
    try {
      // Veriden mesaj gönderen bilgisini çıkar
      final comment = widget.summaryData[index]['comment'] ?? '';
      
      // İlk olarak yüzde bilgisi ile eşleşme ara
      final percentPattern = RegExp(r'(Sen|[^\.]+)\s+[^\d]*(\d+)[^\d%]*%');
      final percentMatch = percentPattern.firstMatch(comment);
      
      String correctOption;
      
      if (percentMatch != null && percentMatch.groupCount >= 2) {
        final sender = percentMatch.group(1)?.trim() ?? 'Sen';
        final percent = percentMatch.group(2) ?? '60';
        correctOption = "$sender (%$percent)";
      } else {
        // Başka bir desene bakalım
        final pattern = RegExp(r'(sen|[^\.]+)\s+daha\s+çok\s+mesaj');
        final match = pattern.firstMatch(comment);
        
        if (match != null && match.groupCount >= 1) {
          final sender = match.group(1)?.trim() ?? 'Sen';
          correctOption = "$sender (%65)";
        } else {
          // Varsayılan değer
          correctOption = "Sen (%60)";
        }
      }
      
      // Alternatif seçenek oluştur
      String wrongOption;
      if (correctOption.toLowerCase().contains('sen')) {
        wrongOption = "Karşı taraf (%65)";
      } else {
        wrongOption = "Sen (%65)";
      }
      
      return [correctOption, wrongOption];
    } catch (e) {
      debugPrint('Gönderen seçenekleri üretme hatası: $e');
      return ["Sen (%60)", "Karşı taraf (%60)"]; // Varsayılan değerler
    }
  }
  
  // Ay seçenekleri
  List<String> _generateMonthOptions(int index) {
    try {
      // Veriden en yoğun ay bilgisini çıkar
      String correctMonth = _extractInfoFromComment(index, r'en\s+yo[ğg]un\s+ay(?:\w+)?\s+([^\.]+)');
      
      // Eğer veriden çıkarılamadıysa
      if (correctMonth.isEmpty) {
        correctMonth = _extractInfoFromComment(index, r'([oO]cak|[şŞ]ubat|[mM]art|[nN]isan|[mM]ay[ıi]s|[hH]aziran|[tT]emmuz|[aA][ğg]ustos|[eE]yl[üu]l|[eE]kim|[kK]as[ıi]m|[aA]ral[ıi]k)');
      }
      
      // Hala bulunamadıysa
      if (correctMonth.isEmpty) {
        final title = widget.summaryData[index]['title'] ?? '';
        final months = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", 
                       "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
        
        for (var month in months) {
          if (title.contains(month)) {
            correctMonth = month;
            break;
          }
        }
      }
      
      // Temizle
      correctMonth = correctMonth.replaceAll('ayında', '').trim();
      
      // Eğer hala bulunamadıysa varsayılan değer kullan
      if (correctMonth.isEmpty) {
        correctMonth = "Mart";
      }
      
      // Yanlış ay seçeneği oluştur
      final months = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", 
                     "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
      
      // Ay adını standartlaştır
      for (var month in months) {
        if (correctMonth.toLowerCase().contains(month.toLowerCase())) {
          correctMonth = month;
          break;
        }
      }
      
      // Farklı bir ay seç
      final random = Random();
      String wrongMonth;
      do {
        wrongMonth = months[random.nextInt(months.length)];
      } while (wrongMonth.toLowerCase() == correctMonth.toLowerCase());
      
      return [correctMonth, wrongMonth];
    } catch (e) {
      debugPrint('Ay seçenekleri üretme hatası: $e');
      return ["Mart", "Ekim"]; // Varsayılan değerler
    }
  }
  
  // Kelime seçenekleri
  List<String> _generateWordOptions(int index) {
    try {
      // Veriden en çok kullanılan kelime bilgisini çıkar
      String correctWord = '';
      final comment = widget.summaryData[index]['comment'] ?? '';
      
      debugPrint('📋 Kelime analizi - Kart #${index+1}:');
      debugPrint('  Yorum: $comment');
      
      // 1. Tırnak içindeki kelimeleri bul
      List<String> quotedWords = [];
      
      // Çift tırnak içindeki kelimeleri bul
      int startIdx = comment.indexOf('"');
      while (startIdx != -1) {
        int endIdx = comment.indexOf('"', startIdx + 1);
        if (endIdx != -1) {
          String quoted = comment.substring(startIdx + 1, endIdx).trim();
          if (quoted.isNotEmpty && !quoted.contains(' ')) {
            quotedWords.add(quoted);
          }
          startIdx = comment.indexOf('"', endIdx + 1);
        } else {
          break;
        }
      }
      
      // Tek tırnak içindeki kelimeleri bul
      startIdx = comment.indexOf("'");
      while (startIdx != -1) {
        int endIdx = comment.indexOf("'", startIdx + 1);
        if (endIdx != -1) {
          String quoted = comment.substring(startIdx + 1, endIdx).trim();
          if (quoted.isNotEmpty && !quoted.contains(' ')) {
            quotedWords.add(quoted);
          }
          startIdx = comment.indexOf("'", endIdx + 1);
        } else {
          break;
        }
      }
      
      if (quotedWords.isNotEmpty) {
        correctWord = quotedWords.first;
        debugPrint('✅ Tırnak içinde kelimeler bulundu: $quotedWords');
      }
      
      // 2. "en çok kullanılan kelime" ifadesinden sonra tırnak içindeki kelimeyi bul
      if (correctWord.isEmpty) {
        final mostUsedIdx = comment.toLowerCase().indexOf("en çok kullanılan kelime");
        if (mostUsedIdx != -1) {
          // Bu ifadeden sonraki ilk tırnak işaretini bul
          final quoteAfterIdx = comment.indexOf('"', mostUsedIdx);
          if (quoteAfterIdx != -1) {
            final quoteEndIdx = comment.indexOf('"', quoteAfterIdx + 1);
            if (quoteEndIdx != -1) {
              correctWord = comment.substring(quoteAfterIdx + 1, quoteEndIdx).trim();
              debugPrint('✅ "En çok kullanılan kelime" ifadesi sonrasında: "$correctWord"');
            }
          }
        }
      }
      
      // 3. "kelimeler:" ifadesinden sonra gelen tırnak içindeki ilk kelimeyi bul
      if (correctWord.isEmpty) {
        final keywordsIdx = comment.toLowerCase().indexOf("kelimeler:");
        if (keywordsIdx != -1) {
          // Bu ifadeden sonraki ilk tırnak işaretini bul
          final quoteAfterIdx = comment.indexOf('"', keywordsIdx);
          if (quoteAfterIdx != -1) {
            final quoteEndIdx = comment.indexOf('"', quoteAfterIdx + 1);
            if (quoteEndIdx != -1) {
              final wordList = comment.substring(quoteAfterIdx + 1, quoteEndIdx).trim();
              final words = wordList.split(",");
              if (words.isNotEmpty) {
                correctWord = words.first.trim();
                debugPrint('✅ "Kelimeler:" ifadesi sonrasında: "$correctWord"');
              }
            }
          }
        }
      }
      
      // 4. Metin içindeki yaygın kelimelerden ilkini bul
      if (correctWord.isEmpty) {
        // Türkçe yaygın kelimeler listesi
        final commonWords = ["tamam", "evet", "hayır", "belki", "merhaba", 
                           "olur", "iyi", "güzel", "teşekkür", "rica", "selam",
                           "nasılsın", "naber", "görüşürüz", "peki", "anladım",
                           "şey", "aşkım", "canım", "tabii", "tabi", "kesinlikle",
                           "lütfen", "haydi", "hadi", "yani"];
        
        // Yorumdaki tüm kelimeleri al
        final allWords = comment.toLowerCase()
                          .replaceAll('.', ' ')
                          .replaceAll(',', ' ')
                          .replaceAll(':', ' ')
                          .replaceAll(';', ' ')
                          .replaceAll('!', ' ')
                          .replaceAll('?', ' ')
                          .replaceAll('"', ' ')
                          .replaceAll("'", ' ')
                          .split(' ');
        
        // Yaygın kelimeler içinde geçen ilk kelimeyi bul
        for (var word in allWords) {
          word = word.trim();
          if (word.isNotEmpty && commonWords.contains(word)) {
            correctWord = word;
            debugPrint('✅ Yorum içinde yaygın kelime: "$correctWord"');
            break;
          }
        }
      }
      
      // Hala bulunamadıysa varsayılan değer kullan
      if (correctWord.isEmpty) {
        correctWord = "tamam";
        debugPrint('⚠️ Kelime bulunamadı, varsayılan değer kullanılıyor: "$correctWord"');
      }
      
      // Doğru kelimeyi standartlaştır
      correctWord = correctWord.trim();
      
      // Yanlış kelime oluştur - gerçekçi alternatif kelimeler (ama doğru değil)
      final alternativeWords = ["tamam", "evet", "hayır", "belki", "merhaba", 
                              "olur", "iyi", "güzel", "teşekkür", "rica", "selam",
                              "nasılsın", "naber", "görüşürüz", "peki", "anladım",
                              "şey", "aşkım", "canım", "tabii", "tabi", "kesinlikle",
                              "lütfen", "haydi", "hadi", "yani"];
      
      // Doğru kelimeyi alternatif listeden çıkar
      alternativeWords.remove(correctWord.toLowerCase());
      
      // Farklı bir kelime seç
      final random = Random();
      final wrongWord = alternativeWords[random.nextInt(alternativeWords.length)];
      
      debugPrint('📊 Kelime seçenekleri: Doğru="$correctWord", Yanlış="$wrongWord"');
      
      return [correctWord, wrongWord];
    } catch (e) {
      debugPrint('❌ Kelime seçenekleri üretme hatası: $e');
      return ["tamam", "merhaba"]; // Varsayılan değerler
    }
  }
  
  // Quiz performans seçenekleri
  List<String> _generatePerformanceOptions() {
    if (_correctAnswers >= _quizQuestions.length * 0.7) {
      return ["🏆 Harika bir performans! 🎉", "😅 Biraz daha çalışman gerek."];
    } else {
      return ["😅 Biraz daha çalışman gerek.", "🏆 Harika bir performans! 🎉"];
    }
  }
  
  // Ruh hali seçenekleri
  List<String> _generateMoodOptions(int index) {
    try {
      // Veriden ruh hali bilgisini çıkar
      final comment = widget.summaryData[index]['comment'] ?? '';
      
      // Pozitif veya negatif desen ara
      final String correctOption;
      
      if (comment.toLowerCase().contains('pozitif') || 
          comment.toLowerCase().contains('olumlu') || 
          comment.toLowerCase().contains('iyi')) {
        correctOption = "😊 Genellikle pozitif";
      } else if (comment.toLowerCase().contains('negatif') || 
                comment.toLowerCase().contains('olumsuz') || 
                comment.toLowerCase().contains('kötü')) {
        correctOption = "😔 Genellikle negatif";
      } else {
        // Varsayılan değer
        correctOption = "😊 Genellikle pozitif";
      }
      
      // Alternatif seçenek
      final wrongOption = correctOption == "😊 Genellikle pozitif" 
          ? "😔 Genellikle negatif" 
          : "😊 Genellikle pozitif";
      
      return [correctOption, wrongOption];
    } catch (e) {
      debugPrint('Ruh hali seçenekleri üretme hatası: $e');
      return ["😊 Genellikle pozitif", "😔 Genellikle negatif"]; // Varsayılan değerler
    }
  }
  
  // Mesaj patlaması seçenekleri
  List<String> _generateSpikeOptions(int index) {
    try {
      // Veriden mesaj patlaması bilgisini çıkar
      String correctOption = _extractInfoFromComment(index, r'en\s+yo[ğg]un\s+g[üu]n(?:\w+)?\s+([^\.]+)');
      
      // Başka desenler dene
      if (correctOption.isEmpty) {
        correctOption = _extractInfoFromComment(index, r'(\d+\s+[^\.]+)\s+g[üu]n[üu]');
      }
      
      // Title'dan çıkarmayı dene
      if (correctOption.isEmpty) {
        final title = widget.summaryData[index]['title'] ?? '';
        final parts = title.split(':');
        if (parts.length > 1) {
          correctOption = parts[1].trim();
        }
      }
      
      // Hala bulunamadıysa
      if (correctOption.isEmpty) {
        final random = Random();
        final months = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", 
                       "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
        final month = months[random.nextInt(months.length)];
        final day = random.nextInt(28) + 1;
        correctOption = "$day $month";
      }
      
      // Alternatif tarih oluştur
      final random = Random();
      final months = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", 
                     "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
      
      // Doğru tarihin yapısını analiz et ve farklı bir gün ve ay seç
      String wrongMonth;
      int wrongDay;
      
      // Mevcut ayı tespit et
      String correctMonth = "";
      for (var month in months) {
        if (correctOption.contains(month)) {
          correctMonth = month;
          break;
        }
      }
      
      do {
        wrongMonth = months[random.nextInt(months.length)];
      } while (wrongMonth == correctMonth);
      
      // Gün seç
      wrongDay = random.nextInt(28) + 1;
      
      final wrongOption = "$wrongDay $wrongMonth";
      
      return [correctOption, wrongOption];
    } catch (e) {
      debugPrint('Mesaj patlaması seçenekleri üretme hatası: $e');
      return ["15 Mart", "4 Haziran"]; // Varsayılan değerler
    }
  }
  
  // Sessizlik seçenekleri
  List<String> _generateSilenceOptions(int index) {
    try {
      // Veriden sessizlik bilgisini çıkar
      String correctOption = _extractInfoFromComment(index, r'([^\.\d]*\d+[^\.\d]*g[üu]n)');
      
      // Sayı + gün desenini ara
      if (correctOption.isEmpty) {
        final pattern = RegExp(r'(\d+)[^\d]*g[üu]n');
        final comment = widget.summaryData[index]['comment'] ?? '';
        final match = pattern.firstMatch(comment);
        
        if (match != null && match.groupCount >= 1) {
          final days = match.group(1) ?? '3';
          correctOption = "$days gün";
        }
      }
      
      // Eğer hala bulunamadıysa
      if (correctOption.isEmpty) {
        final random = Random();
        final days = random.nextInt(7) + 2;
        correctOption = "$days gün";
      }
      
      // Sayıyı çıkar
      final numPattern = RegExp(r'(\d+)');
      final numMatch = numPattern.firstMatch(correctOption);
      int correctDays = 3;
      
      if (numMatch != null && numMatch.groupCount >= 1) {
        correctDays = int.parse(numMatch.group(1)!);
      }
      
      // Farklı bir gün sayısı seç
      final random = Random();
      int wrongDays;
      do {
        wrongDays = random.nextInt(7) + 2;
      } while (wrongDays == correctDays);
      
      final wrongOption = "$wrongDays gün";
      
      return [correctOption, wrongOption];
    } catch (e) {
      debugPrint('Sessizlik seçenekleri üretme hatası: $e');
      return ["3 gün", "7 gün"]; // Varsayılan değerler
    }
  }
  
  // İletişim tipi seçenekleri
  List<String> _generateCommunicationTypeOptions(int index) {
    try {
      // Veriden iletişim tipi bilgisini çıkar
      final comment = widget.summaryData[index]['comment'] ?? '';
      final Map<String, String> types = {
        "Flörtöz": "💘 Flörtöz", 
        "Arkadaşça": "🤝 Arkadaşça", 
        "Romantik": "❤️ Romantik", 
        "Resmi": "🧐 Resmi", 
        "Samimi": "🫂 Samimi"
      };
      
      // Metin içinde hangi iletişim tipi geçiyor
      String correctOption = "";
      
      for (var entry in types.entries) {
        if (comment.toLowerCase().contains(entry.key.toLowerCase())) {
          correctOption = entry.value;
          break;
        }
      }
      
      // Title'da kontrol et
      if (correctOption.isEmpty) {
        final title = widget.summaryData[index]['title'] ?? '';
        for (var entry in types.entries) {
          if (title.toLowerCase().contains(entry.key.toLowerCase())) {
            correctOption = entry.value;
            break;
          }
        }
      }
      
      // Eğer hala bulunamadıysa
      if (correctOption.isEmpty) {
        final random = Random();
        correctOption = types.values.elementAt(random.nextInt(types.length));
      }
      
      // Farklı bir iletişim tipi seç
      final random = Random();
      String wrongOption;
      do {
        wrongOption = types.values.elementAt(random.nextInt(types.length));
      } while (wrongOption == correctOption);
      
      return [correctOption, wrongOption];
    } catch (e) {
      debugPrint('İletişim tipi seçenekleri üretme hatası: $e');
      return ["🤝 Arkadaşça", "❤️ Romantik"]; // Varsayılan değerler
    }
  }
  
  // Mesaj türü seçenekleri
  List<String> _generateMessageTypeOptions(int index) {
    try {
      // Veriden mesaj türü bilgisini çıkar
      final comment = widget.summaryData[index]['comment'] ?? '';
      
      String correctOption;
      
      if (comment.toLowerCase().contains('soru') || 
          comment.toLowerCase().contains('sorgulama')) {
        correctOption = "❓ Genellikle soru-cevap";
      } else if (comment.toLowerCase().contains('duygu') || 
                comment.toLowerCase().contains('hisler')) {
        correctOption = "💖 Genellikle duygu ifadeleri";
      } else {
        // Varsayılan değer
        correctOption = "❓ Genellikle soru-cevap";
      }
      
      // Alternatif seçenek
      final wrongOption = correctOption == "❓ Genellikle soru-cevap" 
          ? "💖 Genellikle duygu ifadeleri" 
          : "❓ Genellikle soru-cevap";
      
      return [correctOption, wrongOption];
    } catch (e) {
      debugPrint('Mesaj türü seçenekleri üretme hatası: $e');
      return ["❓ Genellikle soru-cevap", "💖 Genellikle duygu ifadeleri"]; // Varsayılan değerler
    }
  }
  
  void _checkAnswer(int selectedOptionIndex) {
    final correctOptionIndex = _quizQuestions[_currentQuestionIndex]['correctOptionIndex'];
    final isCorrect = selectedOptionIndex == correctOptionIndex;
    
    setState(() {
      _showingResult = true;
      _answeredCorrectly = isCorrect;
      
      if (isCorrect) {
        _correctAnswers++;
      }
    });
    
    // 1.5 saniye sonra kartı göster
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _showingResult = false;
        
        // Son soru değilse sonraki soruya geç
        if (_currentQuestionIndex < _quizQuestions.length - 1) {
          _currentQuestionIndex++;
        } else {
          // Tüm sorular tamamlandı, KonusmaSummaryView'a git
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => KonusmaSummaryView(
                summaryData: widget.summaryData,
              ),
            ),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showingResult
          ? _buildResultScreen()
          : _buildQuestionScreen(),
    );
  }
  
  Widget _buildQuestionScreen() {
    final question = _quizQuestions[_currentQuestionIndex];
    
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9D3FFF), Color(0xFF6A11CB)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // İlerleme göstergesi
              LinearProgressIndicator(
                value: (_currentQuestionIndex + 1) / _quizQuestions.length,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                borderRadius: BorderRadius.circular(8),
              ),
              
              const SizedBox(height: 8),
              
              // Soru numarası
              Row(
                children: [
                  Text(
                    '🎮 Soru ${_currentQuestionIndex + 1}/${_quizQuestions.length}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '✅ $_correctAnswers doğru',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Soru metni
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  question['question'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 36),
              
              // Seçenekler
              ...List.generate(
                question['options'].length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _buildOptionButton(
                    option: question['options'][index],
                    index: index,
                    onTap: () => _checkAnswer(index),
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Alt bilgi
              Center(
                child: Text(
                  '✨ Her sorudan sonra ilgili Wrapped kartı gösterilecek ✨',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildOptionButton({
    required String option,
    required int index,
    required VoidCallback onTap,
  }) {
    final optionEmojis = ['🅰️', '🅱️'];
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                optionEmojis[index],
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildResultScreen() {
    final wrappedIndex = _quizQuestions[_currentQuestionIndex]['wrappedIndex'];
    final item = widget.summaryData[wrappedIndex];
    final question = _quizQuestions[_currentQuestionIndex]['question'];
    
    // Verinin içeriğini logla
    debugPrint('Sonuç gösteriliyor - index: $wrappedIndex');
    debugPrint('Title: ${item['title']}');
    debugPrint('Comment: ${item['comment']}');
    
    // Gradyan renkleri
    final List<List<Color>> gradients = [
      [const Color(0xFF6A11CB), const Color(0xFF2575FC)], // Mor-Mavi
      [const Color(0xFFFF416C), const Color(0xFFFF4B2B)], // Kırmızı
      [const Color(0xFF00C9FF), const Color(0xFF92FE9D)], // Mavi-Yeşil
      [const Color(0xFFFF9A9E), const Color(0xFFFAD0C4)], // Pembe
      [const Color(0xFFA18CD1), const Color(0xFFFBC2EB)], // Mor-Pembe
      [const Color(0xFF1A2980), const Color(0xFF26D0CE)], // Koyu Mavi-Turkuaz
    ];
    
    final colorIndex = wrappedIndex % gradients.length;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradients[colorIndex],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Doğru/Yanlış göstergesi
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _answeredCorrectly 
                      ? Colors.green.withOpacity(0.2) 
                      : Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _answeredCorrectly ? Icons.check : Icons.close,
                  color: _answeredCorrectly ? Colors.green : Colors.red,
                  size: 40,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Başlık
              Text(
                _answeredCorrectly
                    ? '🎉 Doğru hatırladın, bravo! 👏'
                    : '🤔 Bunu unutmuşsun ama biz hatırlıyoruz! 📝',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Sorulan soru
              Text(
                '$question',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Wrapped kartı
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _decorateTitle(item['title'] ?? 'Wrapped Kartı'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // İçerik kontrolü ekle - çok uzun metinleri kırp
                    Text(
                      item['comment'] ?? 'Bu konu hakkında veri bulunamadı.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Devam et metni
              Text(
                '⏭️ Sonraki soruya geçiliyor...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Başlığı emojilerle süsleme metodu
  String _decorateTitle(String title) {
    // Belirli anahtar kelimelere göre başlığa emoji ekler
    Map<String, String> emojis = {
      'İlk Mesaj': '🔮 İlk Mesaj',
      'Mesaj Sayıları': '📊 Mesaj Sayıları',
      'En Yoğun': '📅 En Yoğun',
      'Kelimeler': '🔤 Kelimeler',
      'Ton': '😊 Ton',
      'Patlaması': '🚀 Patlaması',
      'Sessizlik': '🔕 Sessizlik',
      'İletişim': '💬 İletişim',
      'Mesaj Tipleri': '📝 Mesaj Tipleri',
      'Performans': '🎯 Performans',
    };
    
    // Emojileri ekleme
    for (var key in emojis.keys) {
      if (title.contains(key)) {
        // Başlıkta zaten emoji varsa ekleme (emoji başına eklenirken çift emoji olmasını önler)
        if (!title.contains(emojis[key]!.split(' ')[0])) {
          return emojis[key]!;
        }
        break;
      }
    }
    
    return title;
  }
} 