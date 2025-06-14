import 'package:flutter/foundation.dart';
import '../services/remote_config_service.dart';
import '../services/logger_service.dart';

class RemoteConfigState {
  final bool isYukleniyor;
  final String? hata;

  const RemoteConfigState({
    this.isYukleniyor = false,
    this.hata,
  });

  RemoteConfigState copyWith({
    bool? isYukleniyor,
    String? hata,
  }) {
    return RemoteConfigState(
      isYukleniyor: isYukleniyor ?? this.isYukleniyor,
      hata: hata,
    );
  }
}

class RemoteConfigController extends ChangeNotifier {
  final RemoteConfigService _remoteConfigService;
  final LoggerService _logger;

  RemoteConfigState _state = const RemoteConfigState();
  RemoteConfigState get state => _state;

  RemoteConfigController({
    required RemoteConfigService remoteConfigService,
    LoggerService? logger,
  })  : _remoteConfigService = remoteConfigService,
        _logger = logger ?? LoggerService();

  void _setState(RemoteConfigState newState) {
    _state = newState;
    notifyListeners();
  }

  // Welcome message metodları kaldırıldı

  /// Hata durumunu temizler
  void hatayiTemizle() {
    _setState(state.copyWith(hata: null));
  }
} 