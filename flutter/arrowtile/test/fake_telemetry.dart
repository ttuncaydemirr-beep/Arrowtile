// Testler için sahte telemetri (docs/19): Firebase'e dokunmaz, gönderilen olayları kaydeder.
import 'package:arrowtile/core/consent_gate.dart';
import 'package:arrowtile/core/telemetry.dart';
import 'package:flutter/foundation.dart';

class LoggedEvent {
  final String name;
  final Map<String, Object> params;
  const LoggedEvent(this.name, this.params);
  @override
  String toString() => '$name $params';
}

class FakeTelemetry extends Telemetry {
  final List<LoggedEvent> events = <LoggedEvent>[];
  final List<TelemetryConsent> consents = <TelemetryConsent>[];
  final Map<String, String?> userProps = <String, String?>{};
  final List<Map<String, Object?>> purchases = <Map<String, Object?>>[];
  final List<Object> fatals = <Object>[];
  final List<FlutterErrorDetails> flutterFatals = <FlutterErrorDetails>[];
  bool throwOnLog = false; // telemetri bozulsa bile oyun etkilenmemeli

  @override
  Future<bool> init() async => true;
  @override
  Future<void> setConsent(TelemetryConsent c) async => consents.add(c);
  @override
  Future<void> logEvent(String name, Map<String, Object> params) async {
    if (throwOnLog) throw StateError('boom');
    events.add(LoggedEvent(name, params));
  }

  @override
  Future<void> logPurchase({required String productId, String? currency, double? value}) async {
    purchases.add(<String, Object?>{'id': productId, 'currency': currency, 'value': value});
  }

  @override
  Future<void> setUserProperty(String name, String? value) async => userProps[name] = value;
  @override
  void recordFlutterFatal(FlutterErrorDetails details) => flutterFatals.add(details);
  @override
  void recordFatal(Object error, StackTrace stack) => fatals.add(error);

  Iterable<LoggedEvent> named(String n) => events.where((LoggedEvent e) => e.name == n);
}
