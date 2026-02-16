import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Thrown when Groq API returns 429 (Rate Limit) after retry.
class GroqRateLimitException implements Exception {
  GroqRateLimitException([this.message]);
  final String? message;
}

/// Result of parsing natural language into structured expense data.
/// splitType: "even" | "exact" | "exclude"
/// - even: split equally among participants
/// - exact: each participant has a specific amount (exactAmountsByName)
/// - exclude: split equally among everyone except excludedNames
class ParsedExpenseResult {
  final double amount;
  final String description;
  final String category;
  final String splitType; // "even" | "exact" | "exclude"
  final List<String> participantNames;
  /// Who paid (display name). If set, overrides current user as payer.
  final String? payerName;
  /// For splitType "exclude": names to exclude from the split.
  final List<String> excludedNames;
  /// For splitType "exact": display name -> amount owed.
  final Map<String, double> exactAmountsByName;

  ParsedExpenseResult({
    required this.amount,
    required this.description,
    required this.category,
    required this.splitType,
    List<String>? participantNames,
    this.payerName,
    List<String>? excludedNames,
    Map<String, double>? exactAmountsByName,
  })  : participantNames = participantNames ?? [],
        excludedNames = excludedNames ?? [],
        exactAmountsByName = exactAmountsByName ?? {};

  static ParsedExpenseResult fromJson(Map<String, dynamic> json) {
    final amountRaw = json['amount'] ?? json['amt'];
    final amount = (amountRaw is num)
        ? (amountRaw as num).toDouble()
        : double.tryParse(amountRaw?.toString() ?? '') ?? 0.0;
    final desc = ((json['description'] ?? json['desc']) as String?)?.trim() ?? '';
    final category = (json['category'] as String?)?.trim() ?? '';
    final split = (json['splitType'] as String?)?.trim().toLowerCase();
    final st = split == 'exact'
        ? 'exact'
        : split == 'exclude'
            ? 'exclude'
            : 'even';
    // Accept "participants" or "participant" (some models use singular)
    final parts = json['participants'] ?? json['participant'];
    List<String> names = [];
    if (parts is List) {
      for (final p in parts) {
        if (p != null && p.toString().trim().isNotEmpty) {
          names.add(p.toString().trim());
        }
      }
    } else if (parts != null && parts.toString().trim().isNotEmpty) {
      names.add(parts.toString().trim());
    }
    final payer = (json['payer'] as String?)?.trim();
    final excluded = json['excluded'];
    List<String> excludedList = [];
    if (excluded is List) {
      for (final e in excluded) {
        if (e != null && e.toString().trim().isNotEmpty) {
          excludedList.add(e.toString().trim());
        }
      }
    }
    final exactRaw = json['exactAmounts'];
    Map<String, double> exactMap = {};
    if (exactRaw is Map) {
      for (final entry in exactRaw.entries) {
        final name = entry.key.toString().trim();
        if (name.isEmpty) continue;
        final v = entry.value;
        final numVal = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
        if (numVal != null) exactMap[name] = numVal;
      }
    }
    return ParsedExpenseResult(
      amount: amount,
      description: desc,
      category: category,
      splitType: st,
      participantNames: names,
      payerName: payer != null && payer.isNotEmpty ? payer : null,
      excludedNames: excludedList,
      exactAmountsByName: exactMap.isNotEmpty ? exactMap : null,
    );
  }
}

/// Calls Groq API (Llama 3.3 70B) to parse natural language into structured expense JSON.
/// GROQ_API_KEY must be set in .env.
class GroqExpenseParserService {
  GroqExpenseParserService._();

  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  static String? get _apiKey {
    final key = dotenv.env['GROQ_API_KEY'];
    if (key == null || key.trim().isEmpty) return null;
    return key.trim();
  }

  /// Returns parsed expense or throws on missing key, API error, or unparseable response.
  static Future<ParsedExpenseResult> parse({
    required String userInput,
    required List<String> groupMemberNames,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null) {
      throw Exception('GROQ_API_KEY is not set in environment.');
    }

    final memberList = groupMemberNames.isEmpty
        ? ' (no members listed)'
        : ' ${groupMemberNames.join(", ")}';
    final systemPrompt = '''
You extract expense details from any casual user message and reply with ONLY one valid JSON object. No other text, no markdown, no explanation.

Output format (double quotes for keys and strings; amount as number; no trailing commas):
{"amount":<number>,"description":"<what was bought>","category":"<Food|Transport|etc>","splitType":"even","participants":["<name>",...]}

Member list for names:$memberList
- participants: only include people the user said they are splitting with. Match what they said to this list (e.g. user says "Prasi" and list has "Prasid" -> use "Prasid"). Do NOT add the payer or anyone the user did not mention. If they said "with Prasi", participants must be ["Prasid"] (from list), not someone else. If they mentioned no one to split with, participants: [].
- amount: always extract the money number from the message.
- description: short phrase for what was bought (fix typos/fragments: "ght biriyani" -> "Biriyani", "dinr 500" -> "Dinner").
- category: infer (Food, Transport, etc.) if possible.
- splitType: "even" unless user gives exact per-person amounts or says who to exclude.
- Only add "payer" if user clearly says "X paid" or "paid by X".

Reply with nothing except the single JSON object. Use double-quoted keys and strings only.''';

    final body = {
      'model': _model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userInput.trim()},
      ],
      'temperature': 0.1,
      'max_tokens': 256,
    };

    http.Response response = await _post(apiKey, body);

    if (response.statusCode == 429) {
      await Future<void>.delayed(const Duration(seconds: 2));
      response = await _post(apiKey, body);
      if (response.statusCode == 429) {
        debugPrint('Groq API rate limit (429) after retry: ${response.body}');
        throw GroqRateLimitException('Rate limit exceeded. Try again in a moment.');
      }
    }

    if (response.statusCode != 200) {
      debugPrint('Groq API error: ${response.statusCode} ${response.body}');
      throw Exception('AI request failed. Try again or use a clearer format like "Dinner 500".');
    }

    final map = jsonDecode(response.body) as Map<String, dynamic>?;
    if (map == null) throw Exception('Invalid response from AI.');

    final choices = map['choices'] as List?;
    final first = choices?.isNotEmpty == true ? choices!.first : null;
    final message = first is Map<String, dynamic> ? first['message'] : null;
    final content = message is Map<String, dynamic> ? message['content'] : null;
    String raw = (content is String) ? content.trim() : '';

    if (raw.isEmpty) throw Exception('No content from AI.');

    raw = raw.replaceAll('\uFEFF', ''); // BOM
    raw = _extractJson(raw);
    raw = _fixCommonJsonIssues(raw);

    Map<String, dynamic>? decoded = _tryDecodeJson(raw);
    if (decoded == null) {
      if (kDebugMode) {
        final preview = raw.length > 400 ? '${raw.substring(0, 400)}...' : raw;
        debugPrint('Groq parse failed (JSON decode). Raw response: $preview');
      }
      throw Exception('Couldn\'t parse that. Try a clearer format like "Dinner 500".');
    }

    try {
      return ParsedExpenseResult.fromJson(decoded);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Groq parse failed (fromJson). Decoded: $decoded');
        debugPrint('Error: $e');
        debugPrint(st.toString());
      }
      throw Exception('Couldn\'t parse that. Try a clearer format like "Dinner 500".');
    }
  }

  /// Tries to decode a JSON object from LLM output. Tries strict parse first,
  /// then normalizes smart quotes, then single-quoted style (common with Groq/Llama).
  static Map<String, dynamic>? _tryDecodeJson(String raw) {
    // 1) Strict parse
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) return value;
    } catch (e) {
      if (kDebugMode) debugPrint('Groq JSON strict decode failed: $e');
    }
    // 2) Normalize smart/curly quotes to straight
    String normalized = raw
        .replaceAll('\u201c', '"')
        .replaceAll('\u201d', '"')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'");
    try {
      final value = jsonDecode(normalized);
      if (value is Map<String, dynamic>) return value;
    } catch (_) {}
    // 3) LLM often returns single-quoted JSON; try replacing ' with "
    try {
      final value = jsonDecode(normalized.replaceAll("'", '"'));
      if (value is Map<String, dynamic>) return value;
    } catch (_) {}
    // 4) Some models return unquoted keys (e.g. {amount: 200}); try quoting keys
    try {
      final fixed = normalized.replaceAllMapped(
        RegExp(r'([\{,])\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:'),
        (m) => '${m[1]}"${m[2]}":',
      );
      final value = jsonDecode(fixed);
      if (value is Map<String, dynamic>) return value;
    } catch (_) {}
    return null;
  }

  /// Extracts a JSON object from raw text (handles markdown, leading/trailing text).
  static String _extractJson(String raw) {
    raw = raw.trim();
    // Strip markdown code block if present
    final codeBlockMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false).firstMatch(raw);
    if (codeBlockMatch != null) raw = codeBlockMatch.group(1)?.trim() ?? raw;
    // Find first { and last }; use that as the JSON object
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      raw = raw.substring(start, end + 1);
    }
    return raw.trim();
  }

  /// Fixes common JSON issues from LLM output (trailing commas, etc.).
  static String _fixCommonJsonIssues(String raw) {
    // Remove trailing commas before } or ]
    raw = raw.replaceAll(RegExp(r',(\s*[}\]])'), r'$1');
    return raw;
  }

  static Future<http.Response> _post(String apiKey, Map<String, dynamic> body) {
    return http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }
}
