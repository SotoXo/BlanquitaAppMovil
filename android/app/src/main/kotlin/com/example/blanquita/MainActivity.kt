package com.example.blanquita

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var networkStatusBridge: NetworkStatusBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        networkStatusBridge = NetworkStatusBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        networkStatusBridge?.dispose()
        networkStatusBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
