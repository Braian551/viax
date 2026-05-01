import 'package:flutter/widgets.dart';

class GlobalMapHolder {
  GlobalMapHolder._();

  static Widget? _mapWidget;
  static String? _ownerKey;

  static Widget resolve({
    required String ownerKey,
    required Widget Function() builder,
  }) {
    if (_mapWidget == null || _ownerKey != ownerKey) {
      _ownerKey = ownerKey;
      _mapWidget = builder();
    }

    return _mapWidget!;
  }

  static void invalidate({String? ownerKey}) {
    if (ownerKey == null || _ownerKey == ownerKey) {
      _mapWidget = null;
      _ownerKey = null;
    }
  }
}
