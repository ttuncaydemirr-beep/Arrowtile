// Arrowtile — haptics_service.dart: titreşim desenleri (theme.js THEME.vibrate) `vibration` paketiyle.
// Not: JS navigator.vibrate deseni [titreş, bekle, titreş …]; Android desenleri [bekle, titreş, bekle …] ile başlar,
// bu yüzden başa 0 eklenir.
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class HapticsService {
  bool enabled = true;
  bool? _has;

  static const Map<String, List<int>> patterns = <String, List<int>>{
    'tap': <int>[8],
    'slideOut': <int>[12],
    'bump': <int>[30, 40, 30],
    'levelWin': <int>[20, 60, 20, 60, 40],
    'error': <int>[60],
    'button': <int>[6],
  };

  Future<void> buzz(String name) async {
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
