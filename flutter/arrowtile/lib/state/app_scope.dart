// Arrowtile — app_scope.dart: AppController'ı widget ağacına taşıyan InheritedNotifier.
import 'package:flutter/widgets.dart';

import 'app_controller.dart';

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);

  /// Değişiklikleri dinleyerek (build içinde).
  static AppController of(BuildContext context) {
    final AppScope? s = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(s != null, 'AppScope bulunamadı');
    return s!.notifier!;
  }

  /// Dinlemeden (olay işleyicilerinde).
  static AppController read(BuildContext context) {
    final InheritedElement? e = context.getElementForInheritedWidgetOfExactType<AppScope>();
    assert(e != null, 'AppScope bulunamadı');
    return (e!.widget as AppScope).notifier!;
  }
}
