import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

/// Türkçe klavye desteği sağlayan provider widget
class TurkishKeyboardProvider extends StatelessWidget {
  final Widget child;

  const TurkishKeyboardProvider({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return KeyboardVisibilityProvider(
      child: TurkishKeyboardHandler(
        child: child,
      ),
    );
  }
}

/// Türkçe klavye eylemlerini yöneten widget
class TurkishKeyboardHandler extends StatefulWidget {
  final Widget child;

  const TurkishKeyboardHandler({
    super.key,
    required this.child,
  });

  @override
  State<TurkishKeyboardHandler> createState() => _TurkishKeyboardHandlerState();
}

class _TurkishKeyboardHandlerState extends State<TurkishKeyboardHandler> {
  late KeyboardVisibilityController _keyboardVisibilityController;

  @override
  void initState() {
    super.initState();
    _keyboardVisibilityController = KeyboardVisibilityController();
    
    // Klavye gösterildiğinde Türkçe karakter desteğini etkinleştir
    _keyboardVisibilityController.onChange.listen((bool visible) {
      if (visible) {
        // Fazla müdahale etme, varsayılan davranışa güven
        // Sistem klavyesinin doğal davranışını koru
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        // Kullanıcı kaydırma yaparken klavyeyi kapat
        if (notification is ScrollUpdateNotification && 
            _keyboardVisibilityController.isVisible) {
          FocusScope.of(context).unfocus();
        }
        return false;
      },
      child: GestureDetector(
        // Başka bir alana dokunulduğunda klavyeyi kapat
        onTap: () => FocusScope.of(context).unfocus(),
        child: widget.child,
      ),
    );
  }
  
 
} 