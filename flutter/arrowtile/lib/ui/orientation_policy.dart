// Arrowtile — orientation_policy.dart: 1.2.2 (docs/28). Yön kilidi yalnızca telefonlarda; büyük ekranlarda (tablet, katlanabilir açık)
// tüm yönler serbest. Manifestte android:screenOrientation YOK (Android 16 / targetSdk 36 büyük ekranlarda zaten yok sayar).
import 'dart:ui' show FlutterView, Size;

import 'package:flutter/services.dart';

/// Büyük ekran eşiği (mantıksal piksel): en kısa kenar ≥ 600 → tablet / katlanabilir (Android'in sw600dp ölçütü).
const double kLargeScreenShortestSide = 600;

/// [logicalSize] (mantıksal px) büyük ekran mı?
bool isLargeScreen(Size logicalSize) => logicalSize.shortestSide >= kLargeScreenShortestSide;

/// Bir görünümün (fiziksel boyut / piksel oranı) mantıksal boyutu.
Size logicalSizeOf(FlutterView view) {
  final double r = view.devicePixelRatio <= 0 ? 1.0 : view.devicePixelRatio;
  return view.physicalSize / r;
}

/// Telefonda yalnızca dikey (portraitUp), büyük ekranda tüm yönler.
List<DeviceOrientation> orientationsFor(Size logicalSize) =>
    isLargeScreen(logicalSize) ? DeviceOrientation.values : const <DeviceOrientation>[DeviceOrientation.portraitUp];

bool? _lastLarge;

/// Politikayı uygular; boyut sınıfı değişmediyse platform çağrısı yapmaz (katlanabilir açılıp kapanınca yeniden değerlendirilir).
Future<void> applyOrientationPolicy(FlutterView view) async {
  final Size s = logicalSizeOf(view);
  if (s.isEmpty) return;
  final bool large = isLargeScreen(s);
  if (_lastLarge == large) return;
  _lastLarge = large;
  await SystemChrome.setPreferredOrientations(orientationsFor(s));
}
