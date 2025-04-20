import 'package:flutter/material.dart';
import 'responsive_scaffold.dart';

/// Tüm uygulama sayfalarında taşma hatalarını önleyen sayfa yapısı
/// ThemeExtension ile birlikte kullanılarak uygulamanın her yerinde tutarlı
/// bir şekilde sayfa oluşturulmasını sağlar.
class PageStructure {
  /// Ana Scaffold oluştur (ResponsiveScaffold kullanarak)
  static Widget scaffold({
    Key? key,
    String? title,
    Widget? titleWidget,
    Widget? content,
    Widget? bottomBar,
    Widget? floatingButton,
    PreferredSizeWidget? tabBar,
    List<Widget>? actions,
    Color? backgroundColor,
    Color? appBarColor,
    Widget? drawer,
    bool resizeToAvoidBottomInset = true,
    ScrollController? scrollController,
    ScrollViewKeyboardDismissBehavior keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    bool extendBody = false,
    bool extendBodyBehindAppBar = false,
    EdgeInsetsGeometry? contentPadding,
    ScrollPhysics? scrollPhysics,
    bool automaticallyImplyLeading = true,
    Widget? leadingWidget,
    VoidCallback? onLeadingPressed,
    bool useScrollView = true,
    bool centerTitle = true,
  }) {
    return ResponsiveScaffold(
      key: key,
      title: title,
      titleWidget: titleWidget,
      content: content,
      bottomBar: bottomBar,
      floatingButton: floatingButton,
      tabBar: tabBar,
      actions: actions,
      backgroundColor: backgroundColor,
      appBarColor: appBarColor,
      drawer: drawer,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      scrollController: scrollController,
      keyboardDismissBehavior: keyboardDismissBehavior,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      contentPadding: contentPadding,
      scrollPhysics: scrollPhysics,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leadingWidget: leadingWidget,
      onLeadingPressed: onLeadingPressed,
      useScrollView: useScrollView,
      centerTitle: centerTitle,
    );
  }
  
  /// İçerik alanı oluştur (ResponsiveContentArea kullanarak)
  static Widget contentArea({
    Key? key,
    required Widget child,
    ScrollController? scrollController,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    ScrollViewKeyboardDismissBehavior keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    ScrollPhysics? physics,
    bool fillScreen = true,
    FocusNode? focusNode,
  }) {
    return ResponsiveContentArea(
      key: key,
      child: child,
      scrollController: scrollController,
      padding: padding,
      keyboardDismissBehavior: keyboardDismissBehavior,
      physics: physics,
      fillScreen: fillScreen,
      focusNode: focusNode,
    );
  }
  
  /// Form alanı oluştur (ResponsiveFormArea kullanarak)
  static Widget formArea({
    Key? key,
    required Widget child,
    GlobalKey<FormState>? formKey,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16.0),
    ScrollViewKeyboardDismissBehavior keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
  }) {
    return ResponsiveFormArea(
      key: key,
      child: child,
      formKey: formKey,
      padding: padding,
      keyboardDismissBehavior: keyboardDismissBehavior,
    );
  }
}

/// Sayfa yapısı ThemeExtension - uygulamanın herhangi bir yerinden tema üzerinden 
/// sayfa yapısına erişim sağlar
class PageStructureTheme extends ThemeExtension<PageStructureTheme> {
  /// Ana kenarlık
  final BorderRadius mainBorderRadius;
  
  /// Sayfa padding değeri
  final EdgeInsetsGeometry pagePadding;
  
  /// İçerik padding değeri
  final EdgeInsetsGeometry contentPadding;
  
  /// Form padding değeri
  final EdgeInsetsGeometry formPadding;
  
  /// Klavye davranışı
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  
  /// Boşluk boyutu
  final double spacingSize;

  PageStructureTheme({
    this.mainBorderRadius = const BorderRadius.all(Radius.circular(16.0)),
    this.pagePadding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    this.contentPadding = const EdgeInsets.all(16.0),
    this.formPadding = const EdgeInsets.all(16.0),
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    this.spacingSize = 16.0,
  });

  @override
  ThemeExtension<PageStructureTheme> copyWith({
    BorderRadius? mainBorderRadius,
    EdgeInsetsGeometry? pagePadding,
    EdgeInsetsGeometry? contentPadding,
    EdgeInsetsGeometry? formPadding,
    ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior,
    double? spacingSize,
  }) {
    return PageStructureTheme(
      mainBorderRadius: mainBorderRadius ?? this.mainBorderRadius,
      pagePadding: pagePadding ?? this.pagePadding,
      contentPadding: contentPadding ?? this.contentPadding,
      formPadding: formPadding ?? this.formPadding,
      keyboardDismissBehavior: keyboardDismissBehavior ?? this.keyboardDismissBehavior,
      spacingSize: spacingSize ?? this.spacingSize,
    );
  }

  @override
  ThemeExtension<PageStructureTheme> lerp(
    ThemeExtension<PageStructureTheme>? other, 
    double t,
  ) {
    if (other is! PageStructureTheme) {
      return this;
    }
    
    return PageStructureTheme(
      mainBorderRadius: BorderRadius.lerp(mainBorderRadius, other.mainBorderRadius, t)!,
      // padding için lerp metodunu doğrudan çağıramayız, EdgeInsets kullanılıyorsa
      // aşağıdaki gibi yapılabilir
      pagePadding: EdgeInsets.lerp(
        pagePadding as EdgeInsets, 
        other.pagePadding as EdgeInsets, 
        t,
      )!,
      contentPadding: EdgeInsets.lerp(
        contentPadding as EdgeInsets, 
        other.contentPadding as EdgeInsets, 
        t,
      )!,
      formPadding: EdgeInsets.lerp(
        formPadding as EdgeInsets, 
        other.formPadding as EdgeInsets, 
        t,
      )!,
      keyboardDismissBehavior: t < 0.5 ? keyboardDismissBehavior : other.keyboardDismissBehavior,
      spacingSize: lerpDouble(spacingSize, other.spacingSize, t)!,
    );
  }
  
  /// Tema üzerinden sayfa yapısı temasını alır
  static PageStructureTheme of(BuildContext context) {
    return Theme.of(context).extension<PageStructureTheme>() ?? 
           PageStructureTheme();
  }
}

/// ScrollPhysics extension - kaydırma duyarlılığını artırır
class ResponsiveScrollPhysics extends AlwaysScrollableScrollPhysics {
  const ResponsiveScrollPhysics({ScrollPhysics? parent}) 
      : super(parent: parent);

  @override
  ResponsiveScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ResponsiveScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 3.0;
  
  @override
  double get minFlingVelocity => 50.0;
  
  @override
  double get maxFlingVelocity => 8000.0;
}

/// Double değerler arasında interpolasyon yapar
double? lerpDouble(double? a, double? b, double t) {
  if (a == null && b == null) return null;
  if (a == null) return b! * t;
  if (b == null) return a * (1.0 - t);
  return a + (b - a) * t;
} 