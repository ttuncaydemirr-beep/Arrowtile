// Arrowtile — haptics_service.dart: titreşim desenleri (theme.js THEME.vibrate) `vibration` paketiyle.
// Not: JS navigator.vibrate deseni [titreş, bekle, titreş …]; Android desenleri [bekle, titreş, bekle …] ile başlar,
// bu yüzden başa 0 eklenir.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class HapticsService {
  bool enabled = true;
  bool? _has;

  static const Map<String, List<int>> patterns = <String, List<int>>{
    // 1.2.0 (docs/17 §7, theme.js vibrate): tüm olaylarda TEK kısa darbe (16 ms); ok hareketi başına tek titreşim (1.1.5)
    'tap': <int>[16],
    'slideOut': <int>[16],
    'bump': <int>[16],
    'levelWin': <int>[16],
    'error': <int>[16],
    'button': <int>[16],
  };

  /// Test: istenen her titreşimin adı (1.1.5: ok hareketi başına tek titreşim denetimi).
  @visibleForTesting
  static void Function(String name)? debugSink;

  Future<void> buzz(String name) async {
    debugSink?.call(name);
    if (!enabled) return;
    final List<int>? pat = patterns[name];
    if (pat == null) return;
    try {
      _has ??= await Vibration.hasVibrator();
      if (_has != true) return;
      if (pat.length == 1) {
        await Vibration.vibrate(duration: pat[0]);
      } else {
        await Vibration.vibrate(pattern: <int>[0, ...pat]);
      }
    } catch (_) {
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }
}
