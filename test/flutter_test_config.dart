import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

/// UI regression tests settle with system Reduce Motion enabled. Tests that
/// exercise animation explicitly opt in, without changing functional assertions.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
  });
  await testMain();
}
