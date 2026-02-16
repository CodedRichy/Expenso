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
    final amount = (json['amount'] is num)
        ? (json['amount'] as num).toDouble()
        : double.tryParse(json['amount']?.toString() ?? '') ?? 0.0;
    final desc = (json['description'] as String?)?.trim() ?? '';
    final category = (json['category'] as String?)?.trim() ?? '';
    final split = (json['splitType'] as String?)?.trim().toLowerCase();
    final st = split == 'exact'
        ? 'exact'
        : split == 'exclude'
            ? 'exclude'
            : 'even';
    final parts = json['participants'];
    List<String> names = [];
    if (parts is List) {
      for (final p in parts) {
        if (p != null && p.toString().trim().isNotEmpty) {
          names.add(p.toString().trim());
        }
      }
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
    if (exactRaw is Map<String, dynamic>) {
      for (final entry in exactRaw.entries) {
        final name = entry.key.trim();
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
You are a Financial Data Parser. You must return ONLY valid raw JSON with no markdown, no code fence, and no explanation.
Use these keys: "amount" (number), "description" (string), "category" (string), "splitType" ("even" | "exact" | "exclude"), "participants" (array of strings), and optionally "payer" (string), "excluded" (array of strings), "exactAmounts" (object name->number).
- amount: the expense amount as a number (e.g. 500 or 1200.50).
- description: short description of the expense (e.g. "Dinner", "Uber to airport").
- category: a short category label (e.g. "Food", "Transport").
- splitType: "even" = split equally among participants; "exact" = specific amounts per person (provide "exactAmounts"); "exclude" = split equally among everyone EXCEPT the people in "excluded". Use "even" when unclear.
- participants: display names of people in the split. Use ONLY names from this list:$memberList. If user says "split with X" or "with X and Y", put those names. If no one else mentioned, use [].
- payer: (optional) display name of who paid. Use ONLY from the list. If user says "X paid 500 for me" or "paid by X", set payer to X. If not mentioned, omit or leave empty.
- excluded: (optional) only for splitType "exclude". Array of display names to exclude from the split (they don't owe anything). Use names from the list.
- exactAmounts: (optional) only for splitType "exact". Object mapping display name to amount owed, e.g. {"Alice": 200, "Bob": 300}. Sum must equal "amount". Use names from the list.
Return nothing but the JSON object.''';

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

    // Strip optional markdown code block
    final codeBlockMatch = RegExp(r'^```(?:json)?\s*([\s\S]*?)```', caseSensitive: false).firstMatch(raw);
    if (codeBlockMatch != null) raw = codeBlockMatch.group(1)?.trim() ?? raw;

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) throw Exception('AI did not return a JSON object.');

    return ParsedExpenseResult.fromJson(decoded);
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
