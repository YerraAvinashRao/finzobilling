import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class LogoStorageService {
  static final LogoStorageService _instance = LogoStorageService._internal();
  factory LogoStorageService() => _instance;
  LogoStorageService._internal();

  final ImagePicker _picker = ImagePicker();

  // ✅ Pick logo from gallery
  Future<File?> pickLogoFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,  // Optimize for invoice size
        maxHeight: 800,
        imageQuality: 90,
      );

      if (image == null) return null;

      // Save to app directory
      final savedPath = await _saveImageToAppDirectory(File(image.path), 'logo');
      return savedPath;
    } catch (e) {
      debugPrint('❌ Error picking logo from gallery: $e');
      return null;
    }
  }

  // ✅ Capture logo using camera
  Future<File?> captureLogoFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 90,
      );

      if (image == null) return null;

      final savedPath = await _saveImageToAppDirectory(File(image.path), 'logo');
      return savedPath;
    } catch (e) {
      debugPrint('❌ Error capturing logo from camera: $e');
      return null;
    }
  }

  // ✅ Pick signature from gallery
  Future<File?> pickSignatureFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 300,
        imageQuality: 90,
      );

      if (image == null) return null;

      final savedPath = await _saveImageToAppDirectory(File(image.path), 'signature');
      return savedPath;
    } catch (e) {
      debugPrint('❌ Error picking signature: $e');
      return null;
    }
  }

  // ✅ Save image to app's persistent directory
  Future<File?> _saveImageToAppDirectory(File imageFile, String prefix) async {
    try {
      // Get app's document directory
      final appDir = await getApplicationDocumentsDirectory();
      
      // Create 'invoice_assets' subdirectory if it doesn't exist
      final assetsDir = Directory('${appDir.path}/invoice_assets');
      if (!await assetsDir.exists()) {
        await assetsDir.create(recursive: true);
      }

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageFile.path);
      final newPath = '${assetsDir.path}/${prefix}_$timestamp$extension';

      // Copy file to new location
      final savedFile = await imageFile.copy(newPath);
      
      debugPrint('✅ Image saved to: $newPath');
      return savedFile;
    } catch (e) {
      debugPrint('❌ Error saving image: $e');
      return null;
    }
  }

  // ✅ Delete old logo/signature
  Future<bool> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return false;

    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ Deleted image: $imagePath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting image: $e');
      return false;
    }
  }

  // ✅ Check if image file exists
  Future<bool> imageExists(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return false;
    
    try {
      final file = File(imagePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  // ✅ Get image file from path
  File? getImageFile(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    
    final file = File(imagePath);
    return file;
  }

  // ✅ Show picker dialog (Gallery or Camera)
  Future<File?> showLogoPickerDialog({
    required Future<void> Function() onGallery,
    required Future<void> Function() onCamera,
  }) async {
    // This will be called from the UI
    // Returns the selected file
    return null; // Placeholder - actual implementation in UI
  }

  // ✅ Clean up old/unused images
  Future<void> cleanupOldImages() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final assetsDir = Directory('${appDir.path}/invoice_assets');
      
      if (!await assetsDir.exists()) return;

      final files = assetsDir.listSync();
      final now = DateTime.now();
      
      // Delete files older than 90 days that aren't currently in use
      for (var file in files) {
        if (file is File) {
          final stat = await file.stat();
          final age = now.difference(stat.modified).inDays;
          
          if (age > 90) {
            // TODO: Check if file is in current settings before deleting
            debugPrint('Found old file: ${file.path} ($age days old)');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up images: $e');
    }
  }

  // ✅ Get image size in bytes
  Future<int?> getImageSize(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;
    
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;
      
      final size = await file.length();
      return size;
    } catch (e) {
      debugPrint('❌ Error getting image size: $e');
      return null;
    }
  }

  // ✅ Format file size for display
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ✅ Validate image (check if it's a valid image file)
  Future<bool> validateImage(File imageFile) async {
    try {
      // Check file size (max 5MB for logo)
      final size = await imageFile.length();
      if (size > 5 * 1024 * 1024) {
        debugPrint('❌ Image too large: ${formatFileSize(size)}');
        return false;
      }

      // Check file extension
      final ext = path.extension(imageFile.path).toLowerCase();
      if (!['.jpg', '.jpeg', '.png'].contains(ext)) {
        debugPrint('❌ Invalid image format: $ext');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error validating image: $e');
      return false;
    }
  }
}
