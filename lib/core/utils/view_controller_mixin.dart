import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Mixin for State classes that create a per-screen GetxController.
///
/// It scopes each controller to a UNIQUE tag tied to this State instance, so
/// two live instances of the same view (e.g. during an `offAllNamed` route
/// swap, or when the same step is pushed twice) never collide on the global
/// registry — which previously caused "TextEditingController used after being
/// disposed" when the old view's `Get.delete` removed the new view's controller.
mixin ViewController<W extends StatefulWidget> on State<W> {
  final String vcTag = UniqueKey().toString();

  /// Register [controller] under this view's unique tag and return it.
  T putVC<T>(T controller) => Get.put<T>(controller, tag: vcTag);

  /// Remove the controller of type [T] registered for this view.
  void deleteVC<T>() {
    if (Get.isRegistered<T>(tag: vcTag)) Get.delete<T>(tag: vcTag);
  }
}
