import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ImgBBUploadHelper {
  static const String _apiKey = 'a684012968ee703fd0a3e2690c5a40c2';
  
  static Future<String?> uploadImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload?key=$_apiKey'),
        body: {'image': base64Image},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['url'] as String;
      } else {
        print('ImgBB upload failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading to ImgBB: $e');
      return null;
    }
  }
  
  static Future<List<String>> uploadMultipleImages(List<File> files) async {
    List<String> urls = [];
    
    for (var file in files) {
      final url = await uploadImage(file);
      if (url != null) {
        urls.add(url);
      }
    }
    
    return urls;
  }
}
