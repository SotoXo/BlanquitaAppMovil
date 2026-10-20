import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

/// UI regression tests settle with system Reduce Motion enabled. Tests that
/// exercise animation explicitly opt in, without changing functional assertions.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    // Native socket unit tests must retain their real HttpClient. Only reduce
    // motion when that test library already owns a widget binding.
    TestWidgetsFlutterBinding binding;
    try {
      binding = TestWidgetsFlutterBinding.instance;
    } catch (_) {
      return;
    }
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
  });
  await testMain();
}
