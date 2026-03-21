import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptScannerService {
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String?> scanReceipt() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return null;

      final File file = File(image.path);
      final String uid = _supabase.auth.currentUser?.id ?? 'anonymous';
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String storagePath = 'temp/ocr_uploads/$uid/$timestamp.jpg';

      // 1. Upload to Supabase Storage
      await _supabase.storage.from('receipts').upload(storagePath, file, fileOptions: const FileOptions(upsert: true));

      // 2. Call Supabase Edge Function for OCR
      final result = await _supabase.functions.invoke('callOcrScanner', body: {
        'storagePath': storagePath,
      });

      // 3. Cleanup: Delete temp image
      try {
        await _supabase.storage.from('receipts').remove([storagePath]);
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
