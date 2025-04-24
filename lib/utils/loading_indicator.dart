import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// Uygulama genelinde kullanılacak standart yükleme animasyonu widget'ı.
/// SpinkitPumpingHeart animasyonu kullanır ve atan kalp efektine sahiptir.
class YuklemeAnimasyonu extends StatelessWidget {
  final double boyut;
  final Color renk;

  /// Yükleme animasyonu widget'ı oluşturur.
  /// 
  /// [boyut] - Animasyonun boyutu, varsayılan olarak 45.0
  /// [renk] - Animasyonun rengi, varsayılan olarak Colors.pinkAccent
  const YuklemeAnimasyonu({
    Key? key,
    this.boyut = 45.0,
    this.renk = Colors.pinkAccent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SpinKitPumpingHeart(
        color: renk,
        size: boyut,
      ),
    );
  }
}

/// Uygulamada herhangi bir yerde yükleme animasyonu göstermek için kullanılabilecek fonksiyon.
/// Bu, doğrudan widget ağacına yerleştirilebilir.
Widget yuklemeWidgeti({
  double boyut = 45.0,
  Color renk = Colors.pinkAccent,
}) {
  return YuklemeAnimasyonu(
    boyut: boyut,
    renk: renk,
  );
} 