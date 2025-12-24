package com.auracast.auracast_hub

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.auracast.auracast_hub.audio.AudioEnginePlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AuracastPlugin())
        flutterEngine.plugins.add(AudioEnginePlugin())
    }
}
