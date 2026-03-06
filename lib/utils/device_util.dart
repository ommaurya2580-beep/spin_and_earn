import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

class DeviceUtil {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Retrieves a unique ID for the device.
  /// Uses AndroidId on Android and IdentifierForVendor on iOS.
  static Future<String?> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id; // Unique ID for the device
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor; // Unique ID for vendor
      }
    } on PlatformException {
      return null;
    }
    return null;
  }
}
