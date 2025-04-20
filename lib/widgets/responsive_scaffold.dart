import 'package:flutter/material.dart';

/// Uygulamadaki tüm sayfalar için "Bottom overflowed by XX pixels" hatalarını 
/// önleyen duyarlı bir scaffold bileşeni.
/// 
/// Bu widget, içeriğin ekranı taşırmamasını sağlar ve klavye açıldığında
/// otomatik olarak içeriği yukarı kaydırır.
class ResponsiveScaffold extends StatelessWidget {
  /// Sayfa başlığı
  final String? title;
  
  /// Başlık widget'ı (title parametresine alternatif)
  final Widget? titleWidget;
  
  /// Sayfa içeriği
  final Widget? content;
  
  /// Alt navigasyon çubuğu
  final Widget? bottomBar;
  
  /// Ekranın sağ alt köşesindeki yüzen buton
  final Widget? floatingButton;
  
  /// Appbar'ın altındaki tabBar
  final PreferredSizeWidget? tabBar;
  
  /// Appbar'daki işlemler
  final List<Widget>? actions;
  
  /// Scaffold arka plan rengi
  final Color? backgroundColor;
  
  /// Appbar arka plan rengi
  final Color? appBarColor;
  
  /// Scaffold'ın drawer'ı 
  final Widget? drawer;
  
  /// Klavye açıldığında ekranın yeniden boyutlandırılıp boyutlandırılmayacağı
  final bool resizeToAvoidBottomInset;
  
  /// Scaffold'ın key'i
  final Key? scaffoldKey;
  
  /// ScrollController
  final ScrollController? scrollController;
  
  /// Klavye davranışı
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  
  /// İçeriğin üst üste binme davranışı
  final bool extendBody;
  
  /// İçeriğin appBar'ın altına uzanması
  final bool extendBodyBehindAppBar;
  
  /// İçeriğin padding değerleri
  final EdgeInsetsGeometry? contentPadding;
  
  /// Fizik davranışı
  final ScrollPhysics? scrollPhysics;
  
  /// Appbar otomatik olarak geri butonu göstersin mi
  final bool automaticallyImplyLeading;
  
  /// Appbar geri butonu widget'ı
  final Widget? leadingWidget;
  
  /// Appbar'ın geri butonuna basıldığında çalışacak fonksiyon
  final VoidCallback? onLeadingPressed;
  
  /// Kaydırma görünümünün kullanılıp kullanılmayacağı
  final bool useScrollView;
  
  /// AppBar merkez başlık
  final bool centerTitle;

  const ResponsiveScaffold({
    super.key,
    this.title,
    this.titleWidget,
    this.content,
    this.bottomBar,
    this.floatingButton,
    this.tabBar,
    this.actions,
    this.backgroundColor,
    this.appBarColor,
    this.drawer,
    this.resizeToAvoidBottomInset = true,
    this.scaffoldKey,
    this.scrollController,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.contentPadding,
    this.scrollPhysics,
    this.automaticallyImplyLeading = true,
    this.leadingWidget,
    this.onLeadingPressed,
    this.useScrollView = true,
    this.centerTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    // Ekranın klavyeyle kaplanan kısmını al
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final screenSize = mediaQuery.size;
    
    // Özel geri butonu oluştur
    Widget? leadingButton;
    if (leadingWidget != null) {
      leadingButton = leadingWidget;
    } else if (onLeadingPressed != null) {
      leadingButton = IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onLeadingPressed,
      );
    }
    
    // AppBar oluştur (başlık veya başlık widget varsa)
    final appBar = (title != null || titleWidget != null || actions != null)
        ? AppBar(
            centerTitle: centerTitle,
            title: titleWidget ?? (title != null ? Text(title!) : null),
            actions: actions,
            backgroundColor: appBarColor,
            automaticallyImplyLeading: automaticallyImplyLeading,
            leading: leadingButton,
            bottom: tabBar,
          )
        : null;
    
    // İçerik için varsayılan padding değerleri
    final defaultPadding = contentPadding ?? EdgeInsets.zero;
    
    // İçeriği oluştur
    Widget? body = content;
    
    // İçerik null değilse ve kaydırma görünümü kullanılacaksa
    if (body != null && useScrollView) {
      body = SingleChildScrollView(
        controller: scrollController,
        physics: scrollPhysics ?? const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: keyboardDismissBehavior,
        padding: defaultPadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // Ekran yüksekliğinden AppBar ve BottomBar yüksekliği çıkarılıyor
            minHeight: screenSize.height - 
                       (appBar?.preferredSize.height ?? 0) - 
                       mediaQuery.padding.top - 
                       mediaQuery.padding.bottom - 
                       (bottomBar != null ? kBottomNavigationBarHeight : 0),
          ),
          child: body,
        ),
      );
    } else if (body != null) {
      // Kaydırma görünümü kullanılmayacaksa sadece padding uygula
      body = Padding(
        padding: defaultPadding,
        child: body,
      );
    }
    
    // SafeArea ile bileşenleri güvenli alanda tut
    body = SafeArea(
      bottom: true,
      top: !extendBodyBehindAppBar,
      child: body ?? const SizedBox.shrink(),
    );
    
    // Klavye açıldığında alt boşluk eklenmesi için padding ekle
    if (bottomInset > 0) {
      body = Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: body,
      );
    }
    
    // Son olarak oluşturulan içeriği Scaffold'a yerleştir
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingButton,
      drawer: drawer,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );
  }
}

/// Genişletilebilir, sayfa içeriğini taşma sorunlarına karşı koruyan ve 
/// otomatik olarak kaydırılabilir hale getiren bir içerik container'ı.
class ResponsiveContentArea extends StatelessWidget {
  /// İçerik widget'ı
  final Widget child;
  
  /// Scroll denetleyicisi
  final ScrollController? scrollController;
  
  /// İçerik padding'i
  final EdgeInsetsGeometry padding;
  
  /// Klavye davranışı
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  
  /// Fizik davranışı 
  final ScrollPhysics? physics;
  
  /// Minimum yükseklik kullanıp tüm ekranı kullanmaya zorla
  final bool fillScreen;
  
  /// Sayfaya otomatik focus
  final FocusNode? focusNode;

  const ResponsiveContentArea({
    super.key,
    required this.child,
    this.scrollController,
    this.padding = EdgeInsets.zero,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    this.physics,
    this.fillScreen = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    // Ekran boyutunu ve klavye yüksekliğini al
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    
    Widget content = child;

    // Tüm ekranı kapla seçeneği aktifse
    if (fillScreen) {
      content = LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: content,
            ),
          );
        },
      );
    }
    
    // Gerekirse odak düğümü ekle
    if (focusNode != null) {
      content = Focus(
        focusNode: focusNode,
        child: content,
      );
    }
    
    // Padding ekle
    if (padding != EdgeInsets.zero) {
      content = Padding(
        padding: padding,
        child: content,
      );
    }
    
    // Kaydırılabilir SingleChildScrollView içine al
    return SingleChildScrollView(
      controller: scrollController,
      keyboardDismissBehavior: keyboardDismissBehavior,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      child: content,
    );
  }
}

/// Form alanları için taşmayı önleyen, keyboard açılınca uyumlama sağlayan widget
class ResponsiveFormArea extends StatelessWidget {
  /// İçerik
  final Widget child;
  
  /// Form key
  final GlobalKey<FormState>? formKey;
  
  /// Padding
  final EdgeInsetsGeometry padding;
  
  /// Klavye davranışı
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  const ResponsiveFormArea({
    super.key, 
    required this.child,
    this.formKey,
    this.padding = const EdgeInsets.all(16.0),
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
  });

  @override
  Widget build(BuildContext context) {
    // Form widget'ını oluştur
    final form = Form(
      key: formKey,
      child: child,
    );
    
    // DuyarliIcerikAlani içine yerleştir
    return ResponsiveContentArea(
      padding: padding,
      keyboardDismissBehavior: keyboardDismissBehavior,
      child: form,
    );
  }
} 