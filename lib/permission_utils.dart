import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

abstract class PermissionUtils {
  // 카메라 권한 체크
  static Future<bool> checkCameraPermission(BuildContext context, bool mounted) async {
    final cameraPermissionStatus = await Permission.camera.request();
    if (!mounted) return false;

    if (cameraPermissionStatus.isGranted) {
      return true;
    } else {
      return false;
    }
  }

  // 갤러리보드 권한 체크 ( 운영체제 고려 )
  static Future<bool> checkGalleryPermission(BuildContext context, bool mounted) async {
    // 최초 권한 요청 후 권한 상태 값 반환
    final galleryPermissionStatus = Platform.isAndroid ? await checkAndroidPermission() : await Permission.photos.request();
    if (!mounted) return false;

    if(galleryPermissionStatus.isGranted) {
      return true;
    } else {
      return false;
    }

  }

  static Future<PermissionStatus> checkAndroidPermission() async {
    DeviceInfoPlugin plugin = DeviceInfoPlugin();
    AndroidDeviceInfo android = await plugin.androidInfo;
    if (android.version.sdkInt < 33) {
      return await Permission.storage.request();
    } else {
      return await Permission.photos.request();
    }
  }
}