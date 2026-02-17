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
        ? (amountRaw as num).toDouble()
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

  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  static String? get _apiKey {
    final key = dotenv.env['GROQ_API_KEY'];
    if (key == null || key.trim().isEmpty) return null;
    return key.trim();
  }

  // --- Expenso Secret Formula ---
  // This prompt + few-shot examples are the app's core IP: the rules and training data
  // that turn casual speech into structured expenses (amount, description, splitType,
  // participants, payer). Treat as proprietary. When improving, preserve the
  // splitType decision order (exact → percentage → shares → exclude → even) and disambiguation examples.
  static String _buildSystemPrompt(String memberList) {
    return '''
You are an expense parser. You turn casual user messages into exactly one JSON expense object. Works for any locale and currency. Reply with ONLY that JSON. No other text, no markdown, no explanation.

--- OUTPUT SCHEMA ---
Required in every response:
  "amount" (number): total expense amount
  "description" (string): short phrase, 1-3 words
  "category" (string): e.g. Food, Transport, Utilities, or ""
  "splitType" (string): one of "even" | "exact" | "exclude" | "percentage" | "shares"
  "participants" (array of strings): names from member list who share the cost; use [] for "everyone" or when only payer is involved

Conditional keys (include only when applicable):
  "payer" (string): include only when user explicitly says someone else paid. Omit when user implies they paid ("I paid", "paid by me").
  "excluded" (array of strings): only when splitType is "exclude"; list people excluded from the split.
  "exactAmounts" (object, name -> number): only when splitType is "exact"; map each other person to amount they owe. Do NOT include "me". Sum of exactAmounts + me share = total.
  "percentageAmounts" (object, name -> number): only when splitType is "percentage"; map each person (can include "me") to their percentage 0-100. Sum must equal 100.
  "sharesAmounts" (object, name -> number): only when splitType is "shares"; map each person to their share count (e.g. nights stayed). Amount per person = total * (personShares / totalShares).

--- MEMBER LIST (use ONLY these spellings for any name in participants, payer, excluded, exactAmounts) ---
$memberList
Match typos, nicknames, and partials to this list (e.g. "al" -> Alice, "bob" -> Bob). Output the exact spelling from the list only.

--- FIELD RULES ---

1) amount
- Extract the single numeric total. Ignore currency symbols and thousand separators (1,200 or 1.200 -> 1200).
- "500 bucks", "500 euros", "500 total", "total 500" -> 500. Use digits only; decimals allowed (e.g. 99.50).

2) description
- One short phrase (1-3 words). Fix fragments and typos; normalize to a clear, title-case phrase.
- Fragment map: dinr/dnr -> Dinner; ght/got + next word -> that word (e.g. Biriyani, Groceries); brunch/lunch/snks/snacks/cff/coffee/chai -> proper case; tkt -> Tickets; cab/uber/lyft/taxi/ride/auto -> Transport or Auto; bt -> Groceries; pkd -> Lunch or Expense; petrol/gas/fuel -> Fuel; rent -> Rent; misc -> Miscellaneous.
- Accept any locale-specific terms (pizza, biryani, chai, etc.) and output a clear 1-3 word description. If nothing meaningful, use "Expense".

3) category
- Infer when obvious: Food (dinner, lunch, snacks, coffee, pizza, etc.), Transport (taxi, uber, auto, petrol), Utilities, etc. Leave "" if unclear.

4) splitType (decide in this order; first match wins)
  a) EXACT: User states a specific amount per person ("400 me 600 Bob", "Alice 200 Carol 300", "Bob owes 800"). Output "exact" and "exactAmounts"; never put "me" in exactAmounts.
  b) PERCENTAGE: User gives percentages per person ("60-40", "50% me 50% Bob", "Alice 30% Bob 70%", "split by percentage"). Output "percentage" and "percentageAmounts" (name -> 0-100). Percentages should sum to 100. Can include "me" if user says it.
  c) SHARES: User gives share counts or units ("2 nights Alice 3 nights Bob", "Alice 2 shares Bob 3", "split by nights", "rent 3000, I stayed 2 nights Carol 4 nights"). Output "shares" and "sharesAmounts" (name -> number of shares). Each person pays total * (their shares / total shares).
  d) EXCLUDE: User says someone is left out. Triggers: except X, exclude X, not X, skip X, minus X, bar X, didn't eat, "only for me and Y". Output "exclude" and "excluded". participants stays [].
  e) EVEN: Default. Equal split. Use for "600 with Bob", "500 for me and Carol", "everyone", "50-50", "half and half", or when no amounts/percentages/shares/exclusion stated.

Critical: "600 with Bob" = even. "600: 400 me 200 Bob" = exact. "Rent 60-40" or "50% me 50% Bob" = percentage. "Airbnb 500, Alice 2 nights Bob 3" = shares.

5) participants
- "everyone" / "all" / "all of us" / "the group" -> [] (split among all in group).
- "me and X" / "me and X and Y" -> [X] or [X, Y]; never include "me" in the array.
- "w/", "with", "for", "&", "and" introduce participant names. Match each to member list; output exact spellings only.
- If no one mentioned to split with, use [].

6) payer
- Add "payer":"<name>" only when user clearly says another person paid: "X paid", "paid by X", "X bought", "X got", "X settled", "X covered the bill".
- Omit payer when: "I paid", "I bought", "paid by me", "my treat", "I got the tickets", or no payer mentioned (default = current user).

--- EDGE CASES ---
- If a name cannot be matched to the member list, still include it as the user wrote it (or best guess from list).
- If amount is ambiguous, use the main/total number stated.
- When in doubt between even and exact, prefer even unless per-person amounts are clearly given.
- Always output valid JSON: double-quoted keys and strings, no trailing commas.

--- EXAMPLES (member list: Alice, Bob, Carol) ---
"ght biriyani 200 with al" -> {"amount":200,"description":"Biriyani","category":"Food","splitType":"even","participants":["Alice"]}
"dinr 450 w bob" -> {"amount":450,"description":"Dinner","category":"Food","splitType":"even","participants":["Bob"]}
"pd 120 for chai w carol" -> {"amount":120,"description":"Chai","category":"Food","splitType":"even","participants":["Carol"]}
"tkt for 1200 movies with al" -> {"amount":1200,"description":"Movie Tickets","category":"","splitType":"even","participants":["Alice"]}
"bt groceries 800 w everyone" -> {"amount":800,"description":"Groceries","category":"Food","splitType":"even","participants":[]}
"snks 150 for alice and bob" -> {"amount":150,"description":"Snacks","category":"Food","splitType":"even","participants":["Alice","Bob"]}
"cff 300 w/ bob" -> {"amount":300,"description":"Coffee","category":"Food","splitType":"even","participants":["Bob"]}
"at 150 auto w carol" -> {"amount":150,"description":"Auto","category":"Transport","splitType":"even","participants":["Carol"]}
"pkd 500 for lunch w al" -> {"amount":500,"description":"Lunch","category":"Food","splitType":"even","participants":["Alice"]}
"ice cream 200 w bob" -> {"amount":200,"description":"Ice Cream","category":"Food","splitType":"even","participants":["Bob"]}
"Dinner 2000 split all except Carol" -> {"amount":2000,"description":"Dinner","category":"Food","splitType":"exclude","participants":[],"excluded":["Carol"]}
"1500 for pizza exclude Bob" -> {"amount":1500,"description":"Pizza","category":"Food","splitType":"exclude","participants":[],"excluded":["Bob"]}
"Bowling 3000 but not Alice" -> {"amount":3000,"description":"Bowling","category":"","splitType":"exclude","participants":[],"excluded":["Alice"]}
"Groceries 1000 Carol didn't eat" -> {"amount":1000,"description":"Groceries","category":"Food","splitType":"exclude","participants":[],"excluded":["Carol"]}
"Uber 400 for everyone bar Bob" -> {"amount":400,"description":"Uber","category":"Transport","splitType":"exclude","participants":[],"excluded":["Bob"]}
"Rent 12000 except Alice" -> {"amount":12000,"description":"Rent","category":"","splitType":"exclude","participants":[],"excluded":["Alice"]}
"Movie 800 minus Carol" -> {"amount":800,"description":"Movie","category":"","splitType":"exclude","participants":[],"excluded":["Carol"]}
"Water 200 only for me and Bob" -> {"amount":200,"description":"Water","category":"","splitType":"exclude","participants":[],"excluded":["Alice","Carol"]}
"1000 total 400 for me 600 for Bob" -> {"amount":1000,"description":"Expense","category":"","splitType":"exact","participants":[],"exactAmounts":{"Bob":600}}
"Lunch 500 Alice 200 Carol 300" -> {"amount":500,"description":"Lunch","category":"Food","splitType":"exact","participants":[],"exactAmounts":{"Alice":200,"Carol":300}}
"600 auto 200 for Bob 400 for me" -> {"amount":600,"description":"Auto","category":"Transport","splitType":"exact","participants":[],"exactAmounts":{"Bob":200}}
"Bill 1200 Alice 500 Carol 700" -> {"amount":1200,"description":"Bill","category":"","splitType":"exact","participants":[],"exactAmounts":{"Alice":500,"Carol":700}}
"Rent split 5000 for me 7000 for Bob" -> {"amount":12000,"description":"Rent","category":"","splitType":"exact","participants":[],"exactAmounts":{"Bob":7000}}
"300 snacks 100 me 100 Alice 100 Carol" -> {"amount":300,"description":"Snacks","category":"Food","splitType":"exact","participants":[],"exactAmounts":{"Alice":100,"Carol":100}}
"Tickets 2000 1500 for me 500 for Bob" -> {"amount":2000,"description":"Tickets","category":"","splitType":"exact","participants":[],"exactAmounts":{"Bob":500}}
"Dinner 1500 Bob owes 800 I owe 700" -> {"amount":1500,"description":"Dinner","category":"Food","splitType":"exact","participants":[],"exactAmounts":{"Bob":800}}
"Chai 100 40 Alice 60 me" -> {"amount":100,"description":"Chai","category":"Food","splitType":"exact","participants":[],"exactAmounts":{"Alice":40}}
"Uber 500 250 each for me and Carol" -> {"amount":500,"description":"Uber","category":"Transport","splitType":"exact","participants":[],"exactAmounts":{"Carol":250}}
"I bought pizza for 800" -> {"amount":800,"description":"Pizza","category":"Food","splitType":"even","participants":[]}
"Bob paid 500 for dinner" -> {"amount":500,"description":"Dinner","category":"Food","splitType":"even","participants":[],"payer":"Bob"}
"Paid 300 for coffee" -> {"amount":300,"description":"Coffee","category":"Food","splitType":"even","participants":[]}
"Alice paid for me 1200" -> {"amount":1200,"description":"Expense","category":"","splitType":"even","participants":[],"payer":"Alice"}
"I got the tickets for 2500" -> {"amount":2500,"description":"Tickets","category":"","splitType":"even","participants":[]}
"Spent 400 on auto" -> {"amount":400,"description":"Auto","category":"Transport","splitType":"even","participants":[]}
"Carol settled the bill 1500" -> {"amount":1500,"description":"Bill","category":"","splitType":"even","participants":[],"payer":"Carol"}
"Paid by Bob 600" -> {"amount":600,"description":"Expense","category":"","splitType":"even","participants":[],"payer":"Bob"}
"Alice paid for snacks 450" -> {"amount":450,"description":"Snacks","category":"Food","splitType":"even","participants":[],"payer":"Alice"}
"half and half 400" -> {"amount":400,"description":"Expense","category":"","splitType":"even","participants":[]}
"50-50 600 with Bob" -> {"amount":600,"description":"Expense","category":"","splitType":"even","participants":["Bob"]}
"split between me and Alice 200" -> {"amount":200,"description":"Expense","category":"","splitType":"even","participants":["Alice"]}
"600 with Bob" -> {"amount":600,"description":"Expense","category":"","splitType":"even","participants":["Bob"]}
"500 for me and Carol" -> {"amount":500,"description":"Expense","category":"","splitType":"even","participants":["Carol"]}
"1000 split between me Alice and Bob" -> {"amount":1000,"description":"Expense","category":"","splitType":"even","participants":["Alice","Bob"]}
"600: 400 me 200 Bob" -> {"amount":600,"description":"Expense","category":"","splitType":"exact","participants":[],"exactAmounts":{"Bob":200}}
"900 total I pay 500 Alice 400" -> {"amount":900,"description":"Expense","category":"","splitType":"exact","participants":[],"exactAmounts":{"Alice":400}}
"Dinner 800 not Carol" -> {"amount":800,"description":"Dinner","category":"Food","splitType":"exclude","participants":[],"excluded":["Carol"]}
"800 skip Alice and Bob" -> {"amount":800,"description":"Expense","category":"","splitType":"exclude","participants":[],"excluded":["Alice","Bob"]}
"Snacks 500 could not make it Carol" -> {"amount":500,"description":"Snacks","category":"Food","splitType":"exclude","participants":[],"excluded":["Carol"]}
"Rent 10000 split 60-40 with Bob" -> {"amount":10000,"description":"Rent","category":"","splitType":"percentage","participants":[],"percentageAmounts":{"Alice":60,"Bob":40}}
"Dinner 500 50% me 50% Carol" -> {"amount":500,"description":"Dinner","category":"Food","splitType":"percentage","participants":[],"percentageAmounts":{"Alice":50,"Carol":50}}
"Bill 1200 Alice 30% Bob 70%" -> {"amount":1200,"description":"Bill","category":"","splitType":"percentage","participants":[],"percentageAmounts":{"Alice":30,"Bob":70}}
"Airbnb 1500 Alice 2 nights Bob 3 nights" -> {"amount":1500,"description":"Airbnb","category":"","splitType":"shares","participants":[],"sharesAmounts":{"Alice":2,"Bob":3}}
"Rent 3000 I stayed 2 Carol 4 nights" -> {"amount":3000,"description":"Rent","category":"","splitType":"shares","participants":[],"sharesAmounts":{"Alice":2,"Carol":4}}
"Trip 600 split by shares Alice 1 Bob 2 Carol 3" -> {"amount":600,"description":"Trip","category":"","splitType":"shares","participants":[],"sharesAmounts":{"Alice":1,"Bob":2,"Carol":3}}

Reply with nothing except the single JSON object. Double-quoted keys and strings only. All names must use exact spellings from the member list.''';
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
      'temperature': 0.1,
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

      // Partial success: valid amount is enough; ensure description is non-empty for persistence.
      if (result.amount > 0) {
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
      }

      final fallback = _fallbackParse(userInput);
      if (fallback != null) return fallback;
      throw Exception('Couldn\'t parse that. Try a clearer format like "Dinner 500".');
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
    if (amount == null || amount <= 0) return null;
    final trimmed = userInput.trim();
    final description = trimmed.isEmpty ? 'Expense' : (trimmed.length > 80 ? '${trimmed.substring(0, 80)}…' : trimmed);
    return ParsedExpenseResult(
      amount: amount,
      description: description,
      category: '',
      splitType: 'even',
      participantNames: [],
    );
  }

  /// Extracts the first numeric amount from text (handles "500", "1,200", "₹500").
  static double? _extractAmountFromText(String text) {
    final match = RegExp(r'[\d,]+').firstMatch(text);
    if (match == null) return null;
    final cleaned = match.group(0)!.replaceAll(',', '');
    return double.tryParse(cleaned);
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
