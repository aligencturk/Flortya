import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// Uygulama genelinde kullanılacak standart yükleme animasyonu widget'ı.
/// İstenen animasyon tipine göre farklı animasyonlar kullanabilir.
class YuklemeAnimasyonu extends StatelessWidget {
  final double boyut;
  final Color renk;
  final AnimasyonTipi tip;
  final String? mesaj;

  /// Yükleme animasyonu widget'ı oluşturur.
  /// 
  /// [boyut] - Animasyonun boyutu, varsayılan olarak 45.0
  /// [renk] - Animasyonun rengi, varsayılan olarak tema birincil rengi
  /// [tip] - Animasyon tipi, varsayılan olarak KALP
  /// [mesaj] - Opsiyonel mesaj, animasyonun altında gösterilir
  const YuklemeAnimasyonu({
    Key? key,
    this.boyut = 45.0,
    Color? renk,
    this.tip = AnimasyonTipi.KALP,
    this.mesaj,
  }) : renk = renk ?? Colors.pinkAccent, super(key: key);

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
    
    // Eğer mesaj varsa animasyon ve mesajı birlikte göster
    if (mesaj != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          animasyonWidget,
          const SizedBox(height: 12),
          Text(
            mesaj!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    
    // Sadece animasyon göster
    return Center(child: animasyonWidget);
  }
}

/// Animasyon tipleri
enum AnimasyonTipi {
  KALP,
  DAIRE,
  DALGALI,
  NOKTA,
}

/// Uygulamada herhangi bir yerde yükleme animasyonu göstermek için kullanılabilecek fonksiyon.
/// Bu, doğrudan widget ağacına yerleştirilebilir.
Widget yuklemeWidgeti({
  double boyut = 45.0,
  Color? renk,
  AnimasyonTipi tip = AnimasyonTipi.KALP,
  String? mesaj,
}) {
  return YuklemeAnimasyonu(
    boyut: boyut,
    renk: renk,
    tip: tip,
    mesaj: mesaj,
  );
}

class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;
  
  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 24.0,
    this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Theme.of(context).colorScheme.primary;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 3.0,
            valueColor: AlwaysStoppedAnimation<Color>(themeColor),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(
            message!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
} 