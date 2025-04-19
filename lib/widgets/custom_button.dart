import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum ButtonType { primary, secondary, outline, text }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final ButtonType type;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final double borderRadius;
  final EdgeInsets padding;
  final bool disabled;
  final Color? color;
  final bool isOutlined;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = ButtonType.primary,
    this.isLoading = false,
    this.isFullWidth = false,
    this.icon,
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.disabled = false,
    this.color,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Tema renklerini elde etme
    final Color primaryColor = theme.colorScheme.primary;
    final Color onPrimaryColor = theme.colorScheme.onPrimary;
    final Color surfaceColor = theme.colorScheme.surface;
    final Color onSurfaceColor = theme.colorScheme.onSurface;
    
    // Tip bazlı renkler
    Color backgroundColor;
    Color textColor;
    Color borderColor;
    
    if (isOutlined) {
      backgroundColor = Colors.transparent;
      textColor = color ?? primaryColor;
      borderColor = color ?? primaryColor;
    } else {
      switch (type) {
        case ButtonType.primary:
          backgroundColor = color ?? primaryColor;
          textColor = onPrimaryColor;
          borderColor = Colors.transparent;
          break;
        case ButtonType.secondary:
          backgroundColor = color ?? theme.colorScheme.secondary;
          textColor = theme.colorScheme.onSecondary;
          borderColor = Colors.transparent;
          break;
        case ButtonType.outline:
          backgroundColor = Colors.transparent;
          textColor = color ?? primaryColor;
          borderColor = color ?? primaryColor;
          break;
        case ButtonType.text:
          backgroundColor = Colors.transparent;
          textColor = color ?? primaryColor;
          borderColor = Colors.transparent;
          break;
      }
    }
    
    // Devre dışı bırakılmış stilini uygulama
    if (disabled) {
      backgroundColor = isOutlined || type == ButtonType.text || type == ButtonType.outline
          ? Colors.transparent
          : theme.disabledColor.withOpacity(0.2);
      textColor = theme.disabledColor;
      borderColor = isOutlined || type == ButtonType.outline
          ? theme.disabledColor
          : Colors.transparent;
    }

    // İçerik widget'ı
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    // Buton widget'ı
    final buttonWidget = Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: disabled || isLoading ? null : onPressed,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor,
              width: type == ButtonType.outline ? 1.5 : 0,
            ),
          ),
          width: isFullWidth ? double.infinity : null,
          child: Center(child: content),
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 200.ms)
    .scaleXY(begin: 0.9, end: 1.0, duration: 200.ms, curve: Curves.easeOut);

    return buttonWidget;
  }
} 