import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// Uygulama genelinde kullanılacak standart yükleme animasyonu widget'ı.
/// İstenen animasyon tipine göre farklı animasyonlar kullanabilir.
class YuklemeAnimasyonu extends StatelessWidget {
  final double boyut;
  final Color renk;
  final AnimasyonTipi tip;
  final String? mesaj;
  final AnalizTipi analizTipi;

  /// Yükleme animasyonu widget'ı oluşturur.
  /// 
  /// [boyut] - Animasyonun boyutu, varsayılan olarak 45.0
  /// [renk] - Animasyonun rengi, varsayılan olarak tema birincil rengi
  /// [tip] - Animasyon tipi, varsayılan olarak KALP
  /// [mesaj] - Opsiyonel mesaj, animasyonun altında gösterilir
  /// [analizTipi] - Analiz tipine göre otomatik bilgilendirme metni gösterilir
  const YuklemeAnimasyonu({
    super.key,
    this.boyut = 45.0,
    Color? renk,
    this.tip = AnimasyonTipi.KALP,
    this.mesaj,
    this.analizTipi = AnalizTipi.GENEL,
  }) : renk = renk ?? Colors.pinkAccent;

  @override
  Widget build(BuildContext context) {
    // Eğer renk belirtilmemişse temadan al
    final renkDegeri = renk == Colors.pinkAccent ? 
        Theme.of(context).colorScheme.primary : renk;
        
    Widget animasyonWidget;
    
    // Animasyon tipine göre uygun widget'ı seç
    switch (tip) {
      case AnimasyonTipi.KALP:
        animasyonWidget = SpinKitPumpingHeart(
          color: renkDegeri,
          size: boyut,
        );
        break;
      case AnimasyonTipi.DAIRE:
        animasyonWidget = SizedBox(
          width: boyut,
          height: boyut,
          child: CircularProgressIndicator(
            strokeWidth: 3.0,
            valueColor: AlwaysStoppedAnimation<Color>(renkDegeri),
          ),
        );
        break;
      case AnimasyonTipi.DALGALI:
        animasyonWidget = SpinKitWave(
          color: renkDegeri,
          size: boyut,
        );
        break;
      case AnimasyonTipi.NOKTA:
        animasyonWidget = SpinKitThreeBounce(
          color: renkDegeri,
          size: boyut,
        );
        break;
    }
    
    // Bilgilendirme metni
    String? bilgiMetni = mesaj;
    
    // Eğer mesaj belirtilmemişse ve analiz tipi belirtilmişse, tipin bilgilendirme metnini kullan
    if (bilgiMetni == null && analizTipi != AnalizTipi.GENEL) {
      bilgiMetni = _getAnalizMesaji();
    }
    
    // Eğer mesaj varsa animasyon ve mesajı birlikte göster
    if (bilgiMetni != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            animasyonWidget,
            const SizedBox(height: 12),
            Text(
              bilgiMetni,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // Sadece animasyon göster
    return Center(child: animasyonWidget);
  }
  
  // Analiz tipine göre uygun bilgilendirme mesajını döndürür
  String _getAnalizMesaji() {
    switch (analizTipi) {
      case AnalizTipi.FOTOGRAF:
        return 'Görseller işleniyor, ilişki ipuçları analiz ediliyor...';
      case AnalizTipi.MESAJ_KOCU:
        return 'Mesajınız değerlendiriliyor, en etkili iletişim önerisi hazırlanıyor...';
      case AnalizTipi.TXT_DOSYASI:
        return 'Yazışmalarınız işleniyor, iletişim örüntüleriniz çözümleniyor...';
      case AnalizTipi.ILISKI_ANKETI:
        return 'Anket yanıtlarınız işleniyor, ilişki haritanız oluşturuluyor...';
      case AnalizTipi.DANISMA:
        return 'Danışma sorunuz analiz ediliyor, kişisel çözüm üretiliyor...';
      case AnalizTipi.GENEL:
      default:
        return 'İşleminiz yapılıyor, lütfen bekleyin...';
    }
  }
}

/// Animasyon tipleri
enum AnimasyonTipi {
  KALP,
  DAIRE,
  DALGALI,
  NOKTA,
}

/// Analiz tipleri
enum AnalizTipi {
  GENEL,
  FOTOGRAF,
  MESAJ_KOCU,
  TXT_DOSYASI,
  ILISKI_ANKETI,
  DANISMA,
}

/// Uygulamada herhangi bir yerde yükleme animasyonu göstermek için kullanılabilecek fonksiyon.
/// Bu, doğrudan widget ağacına yerleştirilebilir.
Widget yuklemeWidgeti({
  double boyut = 45.0,
  Color? renk,
  AnimasyonTipi tip = AnimasyonTipi.KALP,
  String? mesaj,
  AnalizTipi analizTipi = AnalizTipi.GENEL,
}) {
  return YuklemeAnimasyonu(
    boyut: boyut,
    renk: renk,
    tip: tip,
    mesaj: mesaj,
    analizTipi: analizTipi,
  );
} 