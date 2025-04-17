import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Ana sayfadaki özellikleri adım adım tanıtan rehber overlay widget'ı
class FeatureGuideOverlay extends StatefulWidget {
  /// Rehber adımları listesi
  final List<GuideStep> steps;
  
  /// Rehber tamamlandığında çağrılacak fonksiyon
  final VoidCallback onCompleted;
  
  /// Kapat butonuna tıklandığında çağrılacak fonksiyon
  final VoidCallback onClose;
  
  const FeatureGuideOverlay({
    Key? key,
    required this.steps,
    required this.onCompleted,
    required this.onClose,
  }) : super(key: key);

  @override
  State<FeatureGuideOverlay> createState() => _FeatureGuideOverlayState();
}

class _FeatureGuideOverlayState extends State<FeatureGuideOverlay> with SingleTickerProviderStateMixin {
  int _currentStepIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _nextStep() {
    if (_currentStepIndex < widget.steps.length - 1) {
      _animationController.reset();
      setState(() {
        _currentStepIndex++;
      });
      _animationController.forward();
    } else {
      // Tüm adımlar tamamlandı
      widget.onCompleted();
    }
  }
  
  void _closeGuide() {
    widget.onClose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Mevcut adımın vurgulanacak widget'ını al
    final GuideStep currentStep = widget.steps[_currentStepIndex];
    final Rect highlightedArea = currentStep.targetArea;
    
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Gri-siyah yarı saydam arka plan
          GestureDetector(
            onTap: () {}, // Boş işleyici ile dokunmaları engelle
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.7),
            ),
          ),
          
          // Vurgulanan alanı gösteren delik
          CustomPaint(
            painter: HighlightAreaPainter(
              highlightedArea: highlightedArea,
              animationValue: _fadeAnimation.value,
              shape: currentStep.highlightShape,
              borderWidth: currentStep.borderWidth,
              padding: currentStep.padding,
            ),
            child: Container(
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          
          // Açıklama balonu
          Positioned(
            left: _calculateTooltipPosition(context, highlightedArea).dx,
            top: _calculateTooltipPosition(context, highlightedArea).dy,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: 250,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF352269),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF9D3FFF),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentStep.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentStep.description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // İlerleme göstergesi
                        Text(
                          '${_currentStepIndex + 1}/${widget.steps.length}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        
                        // Butonlar
                        Row(
                          children: [
                            // Kapat butonu
                            TextButton(
                              onPressed: _closeGuide,
                              child: Text(
                                'Kapat',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            
                            // İleri butonu
                            ElevatedButton(
                              onPressed: _nextStep,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9D3FFF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(
                                _currentStepIndex < widget.steps.length - 1
                                    ? 'İleri'
                                    : 'Tamamla',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Açıklama balonunun konumunu hesaplama
  Offset _calculateTooltipPosition(BuildContext context, Rect targetArea) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final GuideStep currentStep = widget.steps[_currentStepIndex];
    final tooltipWidth = 250.0;
    final tooltipHeight = 160.0;
    
    // Eğer pozisyon kullanıcı tarafından belirtilmişse onu kullan
    if (currentStep.tooltipPosition != null) {
      switch (currentStep.tooltipPosition) {
        case TooltipPosition.top:
          return Offset(
            targetArea.center.dx - tooltipWidth / 2,
            math.max(20, targetArea.top - tooltipHeight - 20)
          );
        case TooltipPosition.bottom:
          return Offset(
            targetArea.center.dx - tooltipWidth / 2,
            math.min(screenHeight - tooltipHeight - 20, targetArea.bottom + 20)
          );
        case TooltipPosition.left:
          return Offset(
            math.max(20, targetArea.left - tooltipWidth - 20),
            targetArea.center.dy - tooltipHeight / 2
          );
        case TooltipPosition.right:
          return Offset(
            math.min(screenWidth - tooltipWidth - 20, targetArea.right + 20),
            targetArea.center.dy - tooltipHeight / 2
          );
        default:
          // Otomatik hesaplama için aşağıdaki kodu çalıştır
          break;
      }
    }
    
    // Varsayılan konum (otomatik hesaplama)
    double left = targetArea.right + 20;
    double top = targetArea.center.dy - tooltipHeight / 2;
    
    // Sağda yeterli alan yoksa, solda göster
    if (left + tooltipWidth > screenWidth - 20) {
      left = targetArea.left - tooltipWidth - 20;
    }
    
    // Solda yeterli alan yoksa, üstte veya altta göster
    if (left < 20) {
      left = math.max(20, math.min(screenWidth - tooltipWidth - 20, targetArea.center.dx - tooltipWidth / 2));
      
      // Üstte veya altta gösterme
      if (targetArea.center.dy > screenHeight / 2) {
        // Hedef aşağıdaysa, üstte göster
        top = targetArea.top - tooltipHeight - 20;
      } else {
        // Hedef yukarıdaysa, altta göster
        top = targetArea.bottom + 20;
      }
    }
    
    // Ekran sınırlarını kontrol et
    if (top < 20) {
      top = 20;
    } else if (top + tooltipHeight > screenHeight - 20) {
      top = screenHeight - tooltipHeight - 20;
    }
    
    return Offset(left, top);
  }
}

/// Rehber adımı bilgilerini tutan sınıf
class GuideStep {
  /// Adım başlığı
  final String title;
  
  /// Adım açıklaması
  final String description;
  
  /// Vurgulanacak hedef widget'ın ekrandaki alanı
  final Rect targetArea;
  
  /// Tooltip'in konumu - varsayılan olarak otomatik hesaplanır
  final TooltipPosition? tooltipPosition;
  
  /// Vurgulama efekti şekli - varsayılan olarak yuvarlak köşeli dikdörtgen
  final HighlightShape highlightShape;
  
  /// Vurgulama çerçevesi genişliği
  final double borderWidth;
  
  /// Vurgulama alanı ek padding miktarı
  final double padding;
  
  GuideStep({
    required this.title,
    required this.description,
    required this.targetArea,
    this.tooltipPosition,
    this.highlightShape = HighlightShape.roundedRect,
    this.borderWidth = 2.0,
    this.padding = 5.0,
  });
}

/// Tooltip pozisyonu için enum
enum TooltipPosition {
  auto,
  top,
  bottom,
  left,
  right
}

/// Vurgulama şekli için enum
enum HighlightShape {
  roundedRect,
  circle,
  oval
}

/// Vurgulanan alanı çizen özel boyacı
class HighlightAreaPainter extends CustomPainter {
  final Rect highlightedArea;
  final double animationValue;
  final HighlightShape shape;
  final double borderWidth;
  final double padding;
  
  HighlightAreaPainter({
    required this.highlightedArea,
    required this.animationValue,
    this.shape = HighlightShape.roundedRect,
    this.borderWidth = 2.0,
    this.padding = 5.0,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Animasyonlu vurgulanan alan - padding'i kullan
    final Rect animatedArea = Rect.lerp(
      highlightedArea.inflate(-20),
      highlightedArea.inflate(padding),
      animationValue,
    )!;
    
    // Arka plan maskesini oluştur
    final Path mask = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
       
    // Seçilen şekle göre highlight oluştur
    if (shape == HighlightShape.circle) {
      final double radius = math.max(animatedArea.width, animatedArea.height) / 2;
      final Offset center = animatedArea.center;
      mask.addOval(Rect.fromCircle(center: center, radius: radius));
    } else if (shape == HighlightShape.oval) {
      mask.addOval(animatedArea);
    } else {
      // RoundedRect (varsayılan)
      mask.addRRect(RRect.fromRectAndRadius(
        animatedArea,
        const Radius.circular(12),
      ));
    }
    
    mask.fillType = PathFillType.evenOdd;
    
    // Gri-siyah yarı saydam arka plan çiz
    canvas.drawPath(
      mask,
      Paint()..color = Colors.black.withOpacity(0.7),
    );
    
    // Nabız efekti için genişleme-daralma animasyonu
    final double pulseValue = (math.sin(animationValue * math.pi * 8) * 0.1) + 0.9;
    final Rect pulseArea = animatedArea.inflate(pulseValue * 2);
    
    // Vurgulanan alanın kenarlığını çiz
    if (shape == HighlightShape.circle) {
      final double radius = math.max(pulseArea.width, pulseArea.height) / 2;
      final Offset center = pulseArea.center;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF9D3FFF)
          ..strokeWidth = borderWidth,
      );
    } else if (shape == HighlightShape.oval) {
      canvas.drawOval(
        pulseArea,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF9D3FFF)
          ..strokeWidth = borderWidth,
      );
    } else {
      // RoundedRect (varsayılan)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          pulseArea,
          const Radius.circular(12),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF9D3FFF)
          ..strokeWidth = borderWidth,
      );
    }
    
    // Parıltı efekti ekle - animasyonu yumuşat
    final Gradient gradient = SweepGradient(
      center: Alignment.topLeft,
      startAngle: 0,
      endAngle: math.pi * 2 * animationValue,
      colors: [
        const Color(0xFF9D3FFF).withOpacity(0.7),
        const Color(0xFF9D3FFF).withOpacity(0.5),
        const Color(0xFF9D3FFF).withOpacity(0.3),
        const Color(0xFF9D3FFF).withOpacity(0.1),
        Colors.transparent,
      ],
    );
    
    if (shape == HighlightShape.circle) {
      final double radius = math.max(pulseArea.width, pulseArea.height) / 2;
      final Offset center = pulseArea.center;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..shader = gradient.createShader(pulseArea),
      );
    } else if (shape == HighlightShape.oval) {
      canvas.drawOval(
        pulseArea,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..shader = gradient.createShader(pulseArea),
      );
    } else {
      // RoundedRect (varsayılan)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          pulseArea,
          const Radius.circular(12),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..shader = gradient.createShader(pulseArea),
      );
    }
  }
  
  @override
  bool shouldRepaint(HighlightAreaPainter oldDelegate) {
    return oldDelegate.highlightedArea != highlightedArea ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.shape != shape ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.padding != padding;
  }
} 