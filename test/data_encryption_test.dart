import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

const _prefix = 'e:';
final _aes = AesGcm.with256bits();

List<int> _decodeKey(String base64Key) {
  return base64.decode(base64Key);
}

String _encodeCiphertext(List<int> nonce, List<int> ciphertext, List<int> tag) {
  final bytes = [...nonce, ...ciphertext, ...tag];
  return _prefix + base64.encode(bytes);
}

Future<String> _encrypt(List<int> keyBytes, String plaintext) async {
  final key = SecretKey(keyBytes);
  final nonce = _aes.newNonce();
  final secretBox = await _aes.encrypt(
    utf8.encode(plaintext),
    secretKey: key,
    nonce: nonce,
  );
  return _encodeCiphertext(
    nonce,
    secretBox.cipherText,
    secretBox.mac.bytes,
  );
}

Future<String> _decrypt(List<int> keyBytes, String ciphertext) async {
  if (!ciphertext.startsWith(_prefix)) return ciphertext;
  final bytes = base64.decode(ciphertext.substring(_prefix.length));
  if (bytes.length < 12 + 16) return ciphertext;
  final nonce = bytes.sublist(0, 12);
  final tag = bytes.sublist(bytes.length - 16);
  final ct = bytes.sublist(12, bytes.length - 16);
  final secretBox = SecretBox(ct, nonce: nonce, mac: Mac(tag));
  final key = SecretKey(keyBytes);
  final decrypted = await _aes.decrypt(secretBox, secretKey: key);
  return utf8.decode(decrypted);
}

bool _isEncrypted(dynamic v) =>
    v is String && v.startsWith(_prefix) && v.length > _prefix.length;

void main() {
  group('Data Encryption', () {
    late List<int> testKey;

    setUp(() {
      testKey = List.generate(32, (i) => i);
    });

    test('encrypt produces prefixed ciphertext', () async {
      const plaintext = 'Hello, World!';
      final encrypted = await _encrypt(testKey, plaintext);
      
      expect(encrypted.startsWith(_prefix), isTrue);
      expect(_isEncrypted(encrypted), isTrue);
      expect(encrypted.length > _prefix.length + 28, isTrue);
    });

    test('decrypt restores original plaintext', () async {
      const plaintext = 'Hello, World!';
      final encrypted = await _encrypt(testKey, plaintext);
      final decrypted = await _decrypt(testKey, encrypted);
      
      expect(decrypted, equals(plaintext));
    });

    test('encrypt/decrypt with various data types', () async {
      final testCases = [
        'Simple string',
        '12345.67',
        '{"key": "value", "num": 123}',
        '["item1", "item2", "item3"]',
        'Special chars: @#\$%^&*()',
        'Unicode: 日本語 中文 한국어',
        '',
      ];

      for (final plaintext in testCases) {
        final encrypted = await _encrypt(testKey, plaintext);
        final decrypted = await _decrypt(testKey, encrypted);
        expect(decrypted, equals(plaintext), reason: 'Failed for: $plaintext');
      }
    });

    test('decrypt returns original if not encrypted', () async {
      const plaintext = 'Not encrypted text';
      final result = await _decrypt(testKey, plaintext);
      
      expect(result, equals(plaintext));
    });

    test('different encryptions of same text produce different ciphertexts', () async {
      const plaintext = 'Same text';
      final encrypted1 = await _encrypt(testKey, plaintext);
      final encrypted2 = await _encrypt(testKey, plaintext);
      
      expect(encrypted1, isNot(equals(encrypted2)));
      
      final decrypted1 = await _decrypt(testKey, encrypted1);
      final decrypted2 = await _decrypt(testKey, encrypted2);
      expect(decrypted1, equals(plaintext));
      expect(decrypted2, equals(plaintext));
    });

    test('wrong key fails to decrypt', () async {
      const plaintext = 'Secret data';
      final encrypted = await _encrypt(testKey, plaintext);
      
      final wrongKey = List.generate(32, (i) => 255 - i);
      
      expect(
        () async => await _decrypt(wrongKey, encrypted),
        throwsA(anything),
      );
    });

    test('base64 key decoding works correctly', () {
      final key32Bytes = List.generate(32, (i) => i);
      final base64Key = base64.encode(key32Bytes);
      final decoded = _decodeKey(base64Key);
      
      expect(decoded, equals(key32Bytes));
      expect(decoded.length, equals(32));
    });

    test('encrypt/decrypt JSON map round trip', () async {
      final originalMap = {
        'description': 'Lunch expense',
        'amount': 150.50,
        'participantIds': ['user1', 'user2'],
        'splits': {'user1': 75.25, 'user2': 75.25},
      };
      
      final jsonStr = jsonEncode(originalMap);
      final encrypted = await _encrypt(testKey, jsonStr);
      final decrypted = await _decrypt(testKey, encrypted);
      final restoredMap = jsonDecode(decrypted);
      
      expect(restoredMap, equals(originalMap));
    });

    test('large text encryption/decryption', () async {
      final largeText = 'A' * 10000;
      final encrypted = await _encrypt(testKey, largeText);
      final decrypted = await _decrypt(testKey, encrypted);
      
      expect(decrypted, equals(largeText));
    });
  });
}
