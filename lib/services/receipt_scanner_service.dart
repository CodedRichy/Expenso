import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptScannerService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> scanReceipt() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return null;

      final File file = File(image.path);
      final String uid = _auth.currentUser?.uid ?? 'anonymous';
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String storagePath = 'temp/ocr_uploads/$uid/$timestamp.jpg';

      // 1. Upload to Firebase Storage
      final Reference ref = _storage.ref().child(storagePath);
      await ref.putFile(file);

      // 2. Call Cloud Function for OCR
      final HttpsCallable callable = _functions.httpsCallable('callOcrScanner');
      final result = await callable.call({
        'storagePath': storagePath,
      });

      // 3. Cleanup: Delete temp image
      try {
        await ref.delete();
      } catch (e) {
        debugPrint('Error deleting temp OCR image: $e');
      }

      if (result.data != null && result.data['text'] != null) {
        return result.data['text'] as String;
      }

      return null;
    } catch (e) {
      debugPrint('Error scanning receipt: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    // No-op for now as we don't have a persistent recognizer
  }
}
