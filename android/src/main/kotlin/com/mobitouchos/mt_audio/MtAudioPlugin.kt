package com.mobitouchos.mt_audio

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Minimal Flutter plugin that exposes the artwork [ContentProvider] authority
 * to the Dart side, allowing [MtAssetResolver] to construct `content://` URIs
 * at runtime without consumer configuration.
 */
class MtAudioPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var applicationId: String

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationId = binding.applicationContext.packageName
        channel = MethodChannel(binding.binaryMessenger, "com.mobitouchos.mt_audio/artwork")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getContentProviderAuthority" -> {
                result.success("$applicationId.mt_audio.artwork")
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
