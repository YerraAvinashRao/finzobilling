import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionHelper {
  /// Request storage permission for PDF/Image saving
  static Future<bool> requestStoragePermission() async {
    // For Android 13+ (API 33+), we need photos permission
    if (await Permission.photos.isGranted) {
      return true;
    }
    
    // For older Android versions
    if (await Permission.storage.isGranted) {
      return true;
    }
    
    // Request appropriate permission
    final photoStatus = await Permission.photos.request();
    if (photoStatus.isGranted) return true;
    
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }
  
  /// Request camera permission for product images
  static Future<bool> requestCameraPermission() async {
    if (await Permission.camera.isGranted) {
      return true;
    }
    
    final status = await Permission.camera.request();
    return status.isGranted;
  }
  
  /// Request photos permission for image picker
  static Future<bool> requestPhotosPermission() async {
    if (await Permission.photos.isGranted) {
      return true;
    }
    
    final status = await Permission.photos.request();
    return status.isGranted;
  }
  
  /// Show permission dialog if denied
  static Future<void> showPermissionDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  /// Request all required permissions at once
  static Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    return await [
      Permission.storage,
      Permission.photos,
      Permission.camera,
    ].request();
  }
}
