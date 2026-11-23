import 'package:flutter/services.dart';

class NativeImagePicker {
  static const MethodChannel _channel = MethodChannel('com.yaalu.dating/native_image_picker');

  // Direct Gallery Pick using native Android MediaStore/Intent
  static Future<String?> pickFromGallery() async {
    try {
      final String? path = await _channel.invokeMethod('pickImageFromGallery');
      return path;
    } catch (_) {
      return null;
    }
  }

  // Direct Camera Capture using native Android Camera Intent
  static Future<String?> takePhoto() async {
    try {
      final String? path = await _channel.invokeMethod('takePhotoWithCamera');
      return path;
    } catch (_) {
      return null;
    }
  }
}
