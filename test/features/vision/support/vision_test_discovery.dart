import 'package:blanquita/features/vision/services/vision_discovery_service.dart';

class TestVisionDiscovery extends VisionDiscoveryService {
  TestVisionDiscovery([Future<Uri?> Function()? result])
    : result = result ?? (() async => null);

  Future<Uri?> Function() result;
  int calls = 0;
  int cancellations = 0;
  @override
  Future<Uri?> discover() {
    calls++;
    return result();
  }

  @override
  void cancel() => cancellations++;
  @override
  void dispose() => cancel();
}
