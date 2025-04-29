import 'package:intl/intl.dart';

/// Tarih ve zaman işlemleri için yardımcı fonksiyonlar sınıfı
class TarihZamanYardimcisi {
  /// Verilen DateTime'ı "dd.MM.yyyy" formatında döndürür
  static String tarihiFormatla(DateTime tarih) {
    return DateFormat('dd.MM.yyyy').format(tarih);
  }
  
  /// Verilen DateTime'ı "dd.MM.yyyy HH:mm" formatında döndürür
  static String tarihVeSaatiFormatla(DateTime tarih) {
    return DateFormat('dd.MM.yyyy HH:mm').format(tarih);
  }
  
  /// Verilen DateTime'ı "dd MMMM yyyy" formatında döndürür (Türkçe ay adı ile)
  static String tarihiUzunFormatla(DateTime tarih) {
    return DateFormat('dd MMMM yyyy', 'tr_TR').format(tarih);
  }
  
  /// İki tarih arasındaki farkı gün olarak döndürür
  static int gunFarkiniHesapla(DateTime ilkTarih, DateTime sonTarih) {
    return sonTarih.difference(ilkTarih).inDays;
  }
  
  /// Verilen DateTime'dan n gün öncesini döndürür
  static DateTime gunOncesiniAl(DateTime tarih, int gunSayisi) {
    return tarih.subtract(Duration(days: gunSayisi));
  }
  
  /// Verilen DateTime'dan n gün sonrasını döndürür
  static DateTime gunSonrasiniAl(DateTime tarih, int gunSayisi) {
    return tarih.add(Duration(days: gunSayisi));
  }
  
  /// Verilen DateTime'ı ay ve gün olarak döndürür ("01 Ocak")
  static String ayVeGunFormatla(DateTime tarih) {
    return DateFormat('dd MMMM', 'tr_TR').format(tarih);
  }
  
  /// Verilen DateTime'ı sadece saat olarak döndürür ("14:30")
  static String saatiFormatla(DateTime tarih) {
    return DateFormat('HH:mm').format(tarih);
  }
  
  /// Verilen zaman farkını insanlar için okunabilir formata çevirir
  /// Örn: "1 saat önce", "3 gün önce", "az önce" gibi
  static String zamaniInsanIcinFormatla(DateTime tarih) {
    final simdi = DateTime.now();
    final fark = simdi.difference(tarih);
    
    if (fark.inSeconds < 60) {
      return 'az önce';
    } else if (fark.inMinutes < 60) {
      return '${fark.inMinutes} dakika önce';
    } else if (fark.inHours < 24) {
      return '${fark.inHours} saat önce';
    } else if (fark.inDays < 7) {
      return '${fark.inDays} gün önce';
    } else if (fark.inDays < 30) {
      return '${(fark.inDays / 7).floor()} hafta önce';
    } else if (fark.inDays < 365) {
      return '${(fark.inDays / 30).floor()} ay önce';
    } else {
      return '${(fark.inDays / 365).floor()} yıl önce';
    }
  }
  
  /// Timestamp'ı DateTime'a çevirir
  static DateTime timestampTariheCevir(int timestamp) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
  
  /// İki tarih aynı gün mü kontrol eder
  static bool ayniGunMu(DateTime tarih1, DateTime tarih2) {
    return tarih1.year == tarih2.year && 
           tarih1.month == tarih2.month && 
           tarih1.day == tarih2.day;
  }
  
  /// Verilen ayın son gününü döndürür
  static DateTime ayinSonGunu(int yil, int ay) {
    return DateTime(yil, ay + 1, 0);
  }
  
  /// Tarihin hafta içi mi yoksa hafta sonu mu olduğunu kontrol eder
  static bool haftaIciMi(DateTime tarih) {
    return tarih.weekday <= 5; // 1-5 arası (Pazartesi-Cuma) hafta içi
  }
  
  /// Bir sonraki çalışma gününü hesaplar (Cumartesi ve Pazar hariç)
  static DateTime sonrakiCalismaGunu(DateTime tarih) {
    DateTime sonrakiGun = tarih.add(const Duration(days: 1));
    
    // Eğer sonraki gün cumartesi veya pazar ise, pazartesiye atla
    if (sonrakiGun.weekday == 6) { // Cumartesi
      sonrakiGun = sonrakiGun.add(const Duration(days: 2));
    } else if (sonrakiGun.weekday == 7) { // Pazar
      sonrakiGun = sonrakiGun.add(const Duration(days: 1));
    }
    
    return sonrakiGun;
  }
} 