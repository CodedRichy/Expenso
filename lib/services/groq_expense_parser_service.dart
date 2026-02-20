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
/// splitType: "even" | "exact" | "exclude" | "percentage" | "shares"
/// - even: split equally among participants
/// - exact: each participant has a specific amount (exactAmountsByName)
/// - exclude: split equally among everyone except excludedNames
/// - percentage: each pays a % of total (percentageByName); should sum to 100
/// - shares: split by units e.g. nights (sharesByName); amount = total * (personShares / totalShares)
class ParsedExpenseResult {
  final double amount;
  final String description;
  final String category;
  final String splitType; // "even" | "exact" | "exclude" | "percentage" | "shares"
  final List<String> participantNames;
  /// Who paid (display name). If set, overrides current user as payer.
  final String? payerName;
  /// For splitType "exclude": names to exclude from the split.
  final List<String> excludedNames;
  /// For splitType "exact": display name -> amount owed.
  final Map<String, double> exactAmountsByName;
  /// For splitType "percentage": display name -> percentage (0-100). May include "me". Sum should be 100.
  final Map<String, double> percentageByName;
  /// For splitType "shares": display name -> number of shares (e.g. nights). Amount = total * (shares / totalShares).
  final Map<String, double> sharesByName;

  ParsedExpenseResult({
    required this.amount,
    required this.description,
    required this.category,
    required this.splitType,
    List<String>? participantNames,
    this.payerName,
    List<String>? excludedNames,
    Map<String, double>? exactAmountsByName,
    Map<String, double>? percentageByName,
    Map<String, double>? sharesByName,
  })  : participantNames = participantNames ?? [],
        excludedNames = excludedNames ?? [],
        exactAmountsByName = exactAmountsByName ?? {},
        percentageByName = percentageByName ?? {},
        sharesByName = sharesByName ?? {};

  static ParsedExpenseResult fromJson(Map<String, dynamic> json) {
    final amountRaw = json['amount'] ?? json['amt'];
    final amount = (amountRaw is num)
        ? (amountRaw).toDouble()
        : double.tryParse(amountRaw?.toString() ?? '') ?? 0.0;
    final desc = ((json['description'] ?? json['desc']) as String?)?.trim() ?? '';
    final category = (json['category'] as String?)?.trim() ?? '';
    final split = (json['splitType'] as String?)?.trim().toLowerCase();
    final st = split == 'exact'
        ? 'exact'
        : split == 'exclude'
            ? 'exclude'
            : split == 'percentage'
                ? 'percentage'
                : split == 'shares'
                    ? 'shares'
                    : 'even';
    final parts = json['participants'] ?? json['participant'] ?? json['members'];
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
    final pctRaw = json['percentageAmounts'] ?? json['percentageByPerson'] ?? json['percentages'];
    Map<String, double> pctMap = {};
    if (pctRaw is Map) {
      for (final entry in pctRaw.entries) {
        final name = entry.key.toString().trim();
        if (name.isEmpty) continue;
        final v = entry.value;
        final numVal = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
        if (numVal != null) pctMap[name] = numVal;
      }
    }
    final sharesRaw = json['sharesAmounts'] ?? json['sharesByPerson'] ?? json['shares'];
    Map<String, double> sharesMap = {};
    if (sharesRaw is Map) {
      for (final entry in sharesRaw.entries) {
        final name = entry.key.toString().trim();
        if (name.isEmpty) continue;
        final v = entry.value;
        final numVal = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
        if (numVal != null && numVal > 0) sharesMap[name] = numVal;
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
      percentageByName: pctMap.isNotEmpty ? pctMap : null,
      sharesByName: sharesMap.isNotEmpty ? sharesMap : null,
    );
  }
}

/// Calls Groq API (Llama 3.3 70B) to parse natural language into structured expense JSON.
/// GROQ_API_KEY must be set in .env.
class GroqExpenseParserService {
  GroqExpenseParserService._();

  /// Returns an error message if [result] is invalid (amount not positive or not finite); null if valid.
  static String? validateResult(ParsedExpenseResult result) {
    if (result.amount.isNaN || result.amount.isInfinite) {
      return 'Amount must be a valid number.';
    }
    if (result.amount <= 0) {
      return 'Amount must be greater than 0.';
    }
    return null;
  }

  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  static String? get _apiKey {
    final key = dotenv.env['GROQ_API_KEY'];
    if (key == null || key.trim().isEmpty) return null;
    return key.trim();
  }

  /// System prompt for expense parsing. When a parse error occurs: document it in
  /// docs/GROQ_PROMPT_REFINEMENT.md and add a rule, anti-pattern in COMMON MISTAKES,
  /// or few-shot example to the prompt. Preserve splitType order: exact → percentage → shares → exclude → even.
  static String _buildSystemPrompt(String memberList) {
    return '''
You are an expense parser. Turn the user message into exactly one JSON expense object. Any locale/currency. Reply with ONLY that JSON—no other text, markdown, or explanation.

--- OUTPUT SCHEMA (required every time) ---
amount (number), description (string, 1–3 words), category (string or ""), splitType ("even"|"exact"|"exclude"|"percentage"|"shares"), participants (array of strings from member list; [] = everyone or when only payer is named).
Optional: payer (string), excluded (array), exactAmounts (name→number), percentageAmounts (name→0–100, sum 100), sharesAmounts (name→shares). Include only when splitType or phrasing requires it.
Example shape: {"amount":200,"description":"Dinner","category":"Food","splitType":"even","participants":["B"]}

--- SCENARIO (infer in this order) ---
1) WHO PAID? "X paid", "paid by X", "X bought/got/covered" → payer X. Else omit payer (current user).
2) WHO SHARES? "with X" / "for me and X" → participants = [X] or [X,Y] (never "me"). "everyone"/"all"/"the group" OR payer named but no "with Y" → participants = [].
3) SPLIT TYPE? Per-person amounts → exact. Percentages → percentage. Share counts (nights, etc.) → shares. Someone excluded → exclude. Else → even.
Key: "X paid 200" (no "with Y") = payer:X, participants:[], even. "200 with X" or "dinner with X 200" = participants:[X], even.

--- MEMBER LIST (use ONLY these spellings) ---
$memberList
Match typos/nicknames to this list; output exact spelling only.

--- FIELD RULES ---
• amount: One numeric total. Strip currency and thousand separators (1,200 → 1200). Decimals OK.
• description: 1–3 words, title-case. Abbreviations: dinr→Dinner, cff→Coffee, tkt→Tickets, uber/cab→Transport, bt→Groceries, ght+word→that word. Else "Expense".
• category: Food/Transport/Utilities when obvious; "" otherwise.
• splitType (first match): (a) exact — per-person amounts; exactAmounts, no "me". (b) percentage — percentageAmounts sum 100. (c) shares — sharesAmounts (e.g. nights). (d) exclude — excluded list; triggers: except/exclude/not/skip/minus/bar/didn't eat/only for me and Y. (e) even — default.
• participants: Others only (app adds current user). "with X" → [X]. "me and A and B" → [A,B]. "everyone" or payer-only → [].
• payer: Set only when someone else paid; omit for "I paid" or unspecified.

--- EDGE CASES ---
Unmatched name → use as written or best guess from list. Ambiguous amount → use main total. Even vs exact unclear → prefer even unless per-person amounts given. Output valid JSON: double-quoted keys/strings, no trailing commas.

--- COMMON MISTAKES (wrong → right) ---
"X paid 200" no "with Y" → RIGHT: participants:[], payer:X. "200 with X" / "dinner 300 with B" → RIGHT: participants:[X] or [B] (not [] or ["me",…]). Other person paid → RIGHT: include payer. "amount with A and B" → RIGHT: participants:["A","B"]. "dinner with X 200" → RIGHT: participants:[X].

--- EXAMPLES (member list: A, B, C) ---
"ght biriyani 200 with a" -> {"amount":200,"description":"Biriyani","category":"Food","splitType":"even","participants":["A"]}
"dinr 450 w b" -> {"amount":450,"description":"Dinner","category":"Food","splitType":"even","participants":["B"]}
"bt groceries 800 w everyone" -> {"amount":800,"description":"Groceries","category":"Food","splitType":"even","participants":[]}
"snks 150 for a and b" -> {"amount":150,"description":"Snacks","category":"Food","splitType":"even","participants":["A","B"]}
"600 with B" -> {"amount":600,"description":"Expense","category":"","splitType":"even","participants":["B"]}
"dinner with A 300" -> {"amount":300,"description":"Dinner","category":"Food","splitType":"even","participants":["A"]}
"I had dinner with B 200" -> {"amount":200,"description":"Dinner","category":"Food","splitType":"even","participants":["B"]}
"B paid 200" -> {"amount":200,"description":"Expense","category":"","splitType":"even","participants":[],"payer":"B"}
"B paid 500 for dinner" -> {"amount":500,"description":"Dinner","category":"Food","splitType":"even","participants":[],"payer":"B"}
"C settled the bill 1500" -> {"amount":1500,"description":"Bill","category":"","splitType":"even","participants":[],"payer":"C"}
"I bought pizza for 800" -> {"amount":800,"description":"Pizza","category":"Food","splitType":"even","participants":[]}
"Dinner 2000 split all except C" -> {"amount":2000,"description":"Dinner","category":"Food","splitType":"exclude","participants":[],"excluded":["C"]}
"1500 for pizza exclude B" -> {"amount":1500,"description":"Pizza","category":"Food","splitType":"exclude","participants":[],"excluded":["B"]}
"Dinner 800 not C" -> {"amount":800,"description":"Dinner","category":"Food","splitType":"exclude","participants":[],"excluded":["C"]}
"1000 total 400 for me 600 for B" -> {"amount":1000,"description":"Expense","category":"","splitType":"exact","participants":[],"exactAmounts":{"B":600}}
"Lunch 500 A 200 C 300" -> {"amount":500,"description":"Lunch","category":"Food","splitType":"exact","participants":[],"exactAmounts":{"A":200,"C":300}}
"600: 400 me 200 B" -> {"amount":600,"description":"Expense","category":"","splitType":"exact","participants":[],"exactAmounts":{"B":200}}
"Dinner 1500 B owes 800 I owe 700" -> {"amount":1500,"description":"Dinner","category":"Food","splitType":"exact","participants":[],"exactAmounts":{"B":800}}
"Rent 10000 split 60-40 with B" -> {"amount":10000,"description":"Rent","category":"","splitType":"percentage","participants":[],"percentageAmounts":{"A":60,"B":40}}
"Bill 1200 A 30% B 70%" -> {"amount":1200,"description":"Bill","category":"","splitType":"percentage","participants":[],"percentageAmounts":{"A":30,"B":70}}
"Airbnb 1500 A 2 nights B 3 nights" -> {"amount":1500,"description":"Airbnb","category":"","splitType":"shares","participants":[],"sharesAmounts":{"A":2,"B":3}}
"Rent 3000 I stayed 2 C 4 nights" -> {"amount":3000,"description":"Rent","category":"","splitType":"shares","participants":[],"sharesAmounts":{"A":2,"C":4}}

Output only the single JSON object. Double-quoted keys and strings. Names from member list only.''';
  }

  /// Returns parsed expense. Allows partial success: if amount is valid, returns a result
  /// even when description or participants are missing. If the API fails, falls back to
  /// local number extraction so the Magic Bar never fails as long as a number is typed.
  static Future<ParsedExpenseResult> parse({
    required String userInput,
    required List<String> groupMemberNames,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null) {
      final fallback = _fallbackParse(userInput);
      if (fallback != null) return fallback;
      throw Exception('GROQ_API_KEY is not set in environment.');
    }

    final memberList = groupMemberNames.isEmpty
        ? ' (no members listed)'
        : ' ${groupMemberNames.join(", ")}';
    final systemPrompt = _buildSystemPrompt(memberList);

    final body = {
      'model': _model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userInput.trim()},
      ],
      'temperature': 0,
      'max_tokens': 256,
    };

    try {
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
        final fallback = _fallbackParse(userInput);
        if (fallback != null) return fallback;
        throw Exception('AI request failed. Try again or use a clearer format like "Dinner 500".');
      }

      final map = jsonDecode(response.body) as Map<String, dynamic>?;
      if (map == null) {
        final fallback = _fallbackParse(userInput);
        if (fallback != null) return fallback;
        throw Exception('Invalid response from AI.');
      }

      final choices = map['choices'] as List?;
      final first = choices?.isNotEmpty == true ? choices!.first : null;
      final message = first is Map<String, dynamic> ? first['message'] : null;
      final content = message is Map<String, dynamic> ? message['content'] : null;
      String raw = (content is String) ? content.trim() : '';

      if (raw.isEmpty) {
        final fallback = _fallbackParse(userInput);
        if (fallback != null) return fallback;
        throw Exception('No content from AI.');
      }

      raw = raw.replaceAll('\uFEFF', ''); // BOM
      raw = _extractJson(raw);
      raw = _fixCommonJsonIssues(raw);

      Map<String, dynamic>? decoded = _tryDecodeJson(raw);
      if (decoded == null) {
        if (kDebugMode) {
          final preview = raw.length > 400 ? '${raw.substring(0, 400)}...' : raw;
          debugPrint('Groq parse failed (JSON decode). Raw response: $preview');
        }
        final fallback = _fallbackParse(userInput);
        if (fallback != null) return fallback;
        throw Exception('Couldn\'t parse that. Try a clearer format like "Dinner 500".');
      }

      ParsedExpenseResult result;
      try {
        result = ParsedExpenseResult.fromJson(decoded);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('Groq parse failed (fromJson). Decoded: $decoded');
          debugPrint('Error: $e');
          debugPrint(st.toString());
        }
        final fallback = _fallbackParse(userInput);
        if (fallback != null) return fallback;
        throw Exception('Couldn\'t parse that. Try a clearer format like "Dinner 500".');
      }

      final validationError = validateResult(result);
      if (validationError != null) {
        final fallback = _fallbackParse(userInput);
        if (fallback != null) return fallback;
        throw Exception(validationError);
      }

      final desc = result.description.trim();
      if (desc.isEmpty) {
        result = ParsedExpenseResult(
          amount: result.amount,
          description: 'Expense',
          category: result.category,
          splitType: result.splitType,
          participantNames: result.participantNames,
          payerName: result.payerName,
          excludedNames: result.excludedNames,
          exactAmountsByName: result.exactAmountsByName,
          percentageByName: result.percentageByName,
          sharesByName: result.sharesByName,
        );
      }
      return result;
    } on GroqRateLimitException {
      rethrow;
    } catch (e) {
      final fallback = _fallbackParse(userInput);
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  /// Fallback: extract first number from input and return minimal ParsedExpenseResult if valid.
  static ParsedExpenseResult? _fallbackParse(String userInput) {
    final amount = _extractAmountFromText(userInput);
    if (amount == null || amount <= 0 || amount.isNaN || amount.isInfinite) return null;
    final trimmed = userInput.trim();
    final description = trimmed.isEmpty
        ? 'Expense'
        : (trimmed.length > 80 ? '${trimmed.substring(0, 80)}…' : trimmed);
    return ParsedExpenseResult(
      amount: amount,
      description: description,
      category: '',
      splitType: 'even',
      participantNames: [],
    );
  }

  /// Extracts the first numeric amount from text (handles "500", "1,200", "99.50", "₹500", gibberish with digits).
  static double? _extractAmountFromText(String text) {
    final match = RegExp(r'[\d,]+\.?\d*').firstMatch(text);
    if (match == null) return null;
    final cleaned = match.group(0)!.replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  /// Tries to decode a JSON object from LLM output. Tries strict parse first,
  /// then normalizes smart quotes, then single-quoted style (common with Groq/Llama).
  static Map<String, dynamic>? _tryDecodeJson(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) return value;
    } catch (e) {
      if (kDebugMode) debugPrint('Groq JSON strict decode failed: $e');
    }
    String normalized = raw
        .replaceAll('\u201c', '"')
        .replaceAll('\u201d', '"')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'");
    try {
      final value = jsonDecode(normalized);
      if (value is Map<String, dynamic>) return value;
    } catch (_) {}
    try {
      final value = jsonDecode(normalized.replaceAll("'", '"'));
      if (value is Map<String, dynamic>) return value;
    } catch (_) {}
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
    final codeBlockMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false).firstMatch(raw);
    if (codeBlockMatch != null) raw = codeBlockMatch.group(1)?.trim() ?? raw;
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      raw = raw.substring(start, end + 1);
    }
    return raw.trim();
  }

  /// Fixes common JSON issues from LLM output (trailing commas, etc.).
  static String _fixCommonJsonIssues(String raw) {
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
