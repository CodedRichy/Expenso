import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptScannerService {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String?> scanReceipt() async {
    try {
      final inputImage = await _picker.pickImage(source: ImageSource.camera);
      if (inputImage == null) return null;

      final file = File(inputImage.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(InputImage.fromFile(file));
      
      return recognizedText.text;
    } catch (e) {
      debugPrint('Error scanning receipt: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
