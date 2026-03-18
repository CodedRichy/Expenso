import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../constants/prompts.dart';

/// Thrown when Groq API returns 429 (Rate Limit) after retry.
class GroqRateLimitException implements Exception {
  GroqRateLimitException([this.message]);
  final String? message;
}

/// Thrown when the parser returns a semantic reject (parseConfidence == 'reject').
/// These must always surface to the user and must not be masked by fallback parsing.
class GroqParserRejectException implements Exception {
  GroqParserRejectException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Result of parsing natural language into structured expense data.
/// splitType: "even" | "exact" | "exclude" | "percentage" | "shares" | "unresolved"
/// - even: split equally among participants
/// - exact: each participant has a specific amount (exactAmountsByName)
/// - exclude: split equally among everyone except excludedNames
/// - percentage: each pays a % of total (percentageByName); should sum to 100
/// - shares: split by units e.g. nights (sharesByName); amount = total * (personShares / totalShares)
/// - unresolved: participants unknown; user must confirm before ledger write
///
/// parseConfidence: "confident" | "constrained" | "reject" — see PARSER_OUTCOME_CONTRACT.md.
class ParsedExpenseResult {
  final double amount;
  final String? currencyCode;
  final String description;
  final String category;
  final String splitType;
  final List<String> participantNames;
  final String? payerName;
  final List<String> excludedNames;
  final Map<String, double> exactAmountsByName;
  final Map<String, double> percentageByName;
  final Map<String, double> sharesByName;
  final String parseConfidence;
  final List<String> constraintFlags;
  final List<String> notes;
  final String? rejectReason;
  final bool needsClarification;
  final String? clarificationQuestion;

  ParsedExpenseResult({
    required this.amount,
    this.currencyCode,
    required this.description,
    required this.category,
    required this.splitType,
    List<String>? participantNames,
    this.payerName,
    List<String>? excludedNames,
    Map<String, double>? exactAmountsByName,
    Map<String, double>? percentageByName,
    Map<String, double>? sharesByName,
    this.parseConfidence = 'confident',
    List<String>? constraintFlags,
    List<String>? notes,
    this.rejectReason,
    this.needsClarification = false,
    this.clarificationQuestion,
  }) : participantNames = participantNames ?? [],
       excludedNames = excludedNames ?? [],
       exactAmountsByName = exactAmountsByName ?? {},
       percentageByName = percentageByName ?? {},
       sharesByName = sharesByName ?? {},
       constraintFlags = constraintFlags ?? [],
       notes = notes ?? [];

  static ParsedExpenseResult fromJson(Map<String, dynamic> json) {
    final amountRaw = json['amount'] ?? json['amt'];
    final amount = (amountRaw is num)
        ? (amountRaw).toDouble()
        : double.tryParse(amountRaw?.toString() ?? '') ?? 0.0;
    final currencyCode = (json['currencyCode'] as String?)?.trim();
    final desc =
        ((json['description'] ?? json['desc']) as String?)?.trim() ?? '';
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
        : split == 'unresolved'
        ? 'unresolved'
        : 'even';
    final parts =
        json['participants'] ?? json['participant'] ?? json['members'];
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
        final numVal = v is num
            ? v.toDouble()
            : double.tryParse(v?.toString() ?? '');
        if (numVal != null) exactMap[name] = numVal;
      }
    }
    final pctRaw =
        json['percentageAmounts'] ??
        json['percentageByPerson'] ??
        json['percentages'];
    Map<String, double> pctMap = {};
    if (pctRaw is Map) {
      for (final entry in pctRaw.entries) {
        final name = entry.key.toString().trim();
        if (name.isEmpty) continue;
        final v = entry.value;
        final numVal = v is num
            ? v.toDouble()
            : double.tryParse(v?.toString() ?? '');
        if (numVal != null) pctMap[name] = numVal;
      }
    }
    final sharesRaw =
        json['sharesAmounts'] ?? json['sharesByPerson'] ?? json['shares'];
    Map<String, double> sharesMap = {};
    if (sharesRaw is Map) {
      for (final entry in sharesRaw.entries) {
        final name = entry.key.toString().trim();
        if (name.isEmpty) continue;
        final v = entry.value;
        final numVal = v is num
            ? v.toDouble()
            : double.tryParse(v?.toString() ?? '');
        if (numVal != null && numVal > 0) sharesMap[name] = numVal;
      }
    }
    final confidence = (json['parseConfidence'] as String?)
        ?.trim()
        .toLowerCase();
    final pc = confidence == 'reject'
        ? 'reject'
        : confidence == 'constrained'
        ? 'constrained'
        : 'confident';
    List<String> flags = [];
    final flagsRaw = json['constraintFlags'];
    if (flagsRaw is List) {
      for (final f in flagsRaw) {
        if (f != null && f.toString().trim().isNotEmpty) {
          flags.add(f.toString().trim());
        }
      }
    }
    List<String> notesList = [];
    final notesRaw = json['notes'];
    if (notesRaw is List) {
      for (final n in notesRaw) {
        if (n != null && n.toString().trim().isNotEmpty) {
          notesList.add(n.toString().trim());
        }
      }
    }
    final needClar = json['needsClarification'] == true;
    final q = (json['clarificationQuestion'] as String?)?.trim();
    final rejectReasonStr = (json['rejectReason'] as String?)?.trim();
    return ParsedExpenseResult(
      amount: amount,
      currencyCode: currencyCode != null && currencyCode.isNotEmpty
          ? currencyCode
          : null,
      description: desc,
      category: category,
      splitType: st,
      participantNames: names,
      payerName: payer != null && payer.isNotEmpty ? payer : null,
      excludedNames: excludedList,
      exactAmountsByName: exactMap.isNotEmpty ? exactMap : null,
      percentageByName: pctMap.isNotEmpty ? pctMap : null,
      sharesByName: sharesMap.isNotEmpty ? sharesMap : null,
      parseConfidence: pc,
      constraintFlags: flags.isNotEmpty ? flags : null,
      notes: notesList.isNotEmpty ? notesList : null,
      rejectReason: rejectReasonStr != null && rejectReasonStr.isNotEmpty
          ? rejectReasonStr
          : null,
      needsClarification: needClar,
      clarificationQuestion: (needClar && q != null && q.isNotEmpty) ? q : null,
    );
  }

  /// API-style JSON for use as a recent example in the prompt (same shape the model outputs).
  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'parseConfidence': parseConfidence,
      'amount': amount,
      'description': description,
      'category': category,
      'splitType': splitType,
      'participants': participantNames,
    };
    if (currencyCode != null && currencyCode!.isNotEmpty) {
      m['currencyCode'] = currencyCode;
    }
    if (payerName != null && payerName!.isNotEmpty) {
      m['payer'] = payerName;
    }
    if (excludedNames.isNotEmpty) m['excluded'] = excludedNames;
    if (exactAmountsByName.isNotEmpty) m['exactAmounts'] = exactAmountsByName;
    if (percentageByName.isNotEmpty) m['percentageAmounts'] = percentageByName;
    if (sharesByName.isNotEmpty) m['sharesAmounts'] = sharesByName;
    if (constraintFlags.isNotEmpty) m['constraintFlags'] = constraintFlags;
    if (notes.isNotEmpty) m['notes'] = notes;
    if (needsClarification) m['needsClarification'] = true;
    if (rejectReason != null) m['rejectReason'] = rejectReason;
    if (clarificationQuestion != null) {
      m['clarificationQuestion'] = clarificationQuestion;
    }
    return m;
  }
}

/// Calls Groq API (Llama 3.3 70B) to parse natural language into structured expense JSON.
/// GROQ_API_KEY must be set in .env.
class GroqExpenseParserService {
  GroqExpenseParserService._();

  static const int _maxRecentExamples = 5;
  static final List<({String input, String json})> _recentExamples = [];

  /// Min seconds between requests to stay under Groq RPM/TPM (see docs/features/GROQ_RATE_LIMITS.md).
  static const int _minIntervalSeconds = 2;
  static int? _lastRequestMs;
  static bool _inFlight = false;

  static Future<void> _throttleForRateLimit() async {
    while (_inFlight) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    final last = _lastRequestMs;
    if (last != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = (now - last) / 1000;
      if (elapsed < _minIntervalSeconds) {
        final wait = (_minIntervalSeconds - elapsed).ceil();
        if (wait > 0) await Future<void>.delayed(Duration(seconds: wait));
      }
    }
  }

  static void _markRequestDone() {
    _lastRequestMs = DateTime.now().millisecondsSinceEpoch;
  }

  /// Call after the user confirms a Magic Bar expense so the next parse can use it as a few-shot example (like the CLI's parser_runs.log).
  static void recordSuccessfulParse(
    String userInput,
    ParsedExpenseResult result,
  ) {
    final trimmed = userInput.trim();
    if (trimmed.isEmpty) return;
    try {
      final json = jsonEncode(result.toJson());
      _recentExamples.add((input: trimmed, json: json));
      if (_recentExamples.length > _maxRecentExamples) {
        _recentExamples.removeAt(0);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'GroqExpenseParserService: failed to cache recent example: $e',
        );
      }
    }
  }

  /// Returns an error message if [result] is invalid; null if valid.
  /// Aligned with CLI (tool/parser_cli.dart): demote confident+unresolved/history; settlements must be rejected.
  /// Hard-rejects mismatches if [expectedCurrencyCode] is provided and [result.currencyCode] differs.
  static String? validateResult(
    ParsedExpenseResult result, {
    String? expectedCurrencyCode,
  }) {
    if (result.amount.isNaN || result.amount.isInfinite) {
      return 'Amount must be a valid number.';
    }
    if (expectedCurrencyCode != null && result.currencyCode != null) {
      if (result.currencyCode!.toUpperCase() !=
          expectedCurrencyCode.toUpperCase()) {
        return 'This group strictly operates in $expectedCurrencyCode. Please enter amounts in $expectedCurrencyCode.';
      }
    }
    if (result.parseConfidence == 'confident' &&
        (result.splitType == 'unresolved' ||
            result.constraintFlags.contains('history'))) {
      return 'Validation: Confident parse cannot have splitType unresolved or history flags.';
    }
    final descLower = result.description.toLowerCase();
    if ((descLower.contains('debt') || descLower.contains('settle')) &&
        result.parseConfidence != 'reject') {
      return 'Validation: Settlements must be REJECTED.';
    }
    return null;
  }

  /// Returns a description of a gap if split amounts don't match total; null if no gap.
  /// Wording aligned with CLI (parser_cli.dart).
  static String? _findGap(ParsedExpenseResult result) {
    const tolerance = 0.01;
    if (result.splitType == 'exact' && result.exactAmountsByName.isNotEmpty) {
      final sum = result.exactAmountsByName.values.fold<double>(
        0,
        (a, b) => a + b,
      );
      if ((sum - result.amount).abs() > tolerance) {
        return 'Exact split: amounts sum to $sum but total is ${result.amount}.';
      }
    }
    if (result.splitType == 'percentage' &&
        result.percentageByName.isNotEmpty) {
      final sum = result.percentageByName.values.fold<double>(
        0,
        (a, b) => a + b,
      );
      if ((sum - 100).abs() > tolerance) {
        return 'Percentage split: sum is $sum, should be 100.';
      }
    }
    return null;
  }

  /// System prompt aligned with PARSER_OUTCOME_CONTRACT.md and CLI parser (tool/parser_cli.dart).
  /// When [recentExamples] is non-empty, appends a RECENT EXAMPLES section (like the CLI's parser_runs.log).
  static String _buildSystemPrompt(
    String memberList, [
    String? currentUserName,
    List<({String input, String json})> recentExamples = const [],
  ]) {
    final recentSection = recentExamples.isNotEmpty
        ? '\n--- RECENT EXAMPLES (from your confirmed expenses) ---\n${recentExamples.map((e) => '"${e.input.replaceAll(r"\", r"\\").replaceAll('"', r'\"')}" -> ${e.json}').join('\n')}\n\n'
        : '';

    return AiPrompts.expenseParserSystem(
      currentUserName: currentUserName ?? '',
      memberList: memberList,
      recentExamplesSection: recentSection,
    );
  }

  /// Returns parsed expense. Allows partial success: if amount is valid, returns a result
  /// even when description or participants are missing. If the API fails, falls back to
  /// local number extraction so the Magic Bar never fails as long as a number is typed.
  /// [currentUserDisplayName] when set is injected into the prompt so "I"/"me"/"my" map to
  /// that name in exactAmounts/sharesAmounts and payer is omitted when the user says they paid.
  static Future<ParsedExpenseResult> parse({
    required String userInput,
    required List<String> groupMemberNames,
    String? currentUserDisplayName,
    String? expectedCurrencyCode,
  }) async {
    final memberList = groupMemberNames.isEmpty
        ? ' (no members listed)'
        : ' ${groupMemberNames.join(", ")}';
    final recent = List<({String input, String json})>.from(_recentExamples);
    final systemPrompt = _buildSystemPrompt(
      memberList,
      currentUserDisplayName?.trim(),
      recent,
    );
    final normalizedInput = expandNumberWordsInText(userInput.trim());

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': normalizedInput},
    ];

    try {
      await _throttleForRateLimit();
      _inFlight = true;
      try {
        final callable = FirebaseFunctions.instanceFor(
          region: 'asia-south1',
        ).httpsCallable('callGroqParser');
        final response = await callable.call({'messages': messages});
        _markRequestDone();

        final map = response.data;
        if (map == null || map is! Map) {
          final fallback = _fallbackParse(
            userInput,
            expectedCurrencyCode: expectedCurrencyCode,
          );
          if (fallback != null) return fallback;
          throw Exception('Invalid response from AI.');
        }
        final Map<String, dynamic> mapCast = Map<String, dynamic>.from(map);

        final choices = mapCast['choices'] as List?;
        final first = choices?.isNotEmpty == true ? choices!.first : null;
        final message = first is Map<String, dynamic> ? first['message'] : null;
        final content = message is Map<String, dynamic>
            ? message['content']
            : null;
        String raw = (content is String) ? content.trim() : '';

        if (raw.isEmpty) {
          final fallback = _fallbackParse(
            userInput,
            expectedCurrencyCode: expectedCurrencyCode,
          );
          if (fallback != null) return fallback;
          throw Exception('No content from AI.');
        }

        raw = raw.replaceAll('\uFEFF', ''); // BOM
        raw = _extractJson(raw);
        raw = _fixCommonJsonIssues(raw);

        Map<String, dynamic>? decoded = _tryDecodeJson(raw);
        if (decoded == null) {
          if (kDebugMode) {
            final preview = raw.length > 400
                ? '${raw.substring(0, 400)}...'
                : raw;
            debugPrint(
              'Groq parse failed (JSON decode). Raw response: $preview',
            );
          }
          final fallback = _fallbackParse(
            userInput,
            expectedCurrencyCode: expectedCurrencyCode,
          );
          if (fallback != null) return fallback;
          throw Exception(
            'Couldn\'t parse that. Try a clearer format like "Dinner 500".',
          );
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
          final fallback = _fallbackParse(
            userInput,
            expectedCurrencyCode: expectedCurrencyCode,
          );
          if (fallback != null) return fallback;
          throw Exception(
            'Couldn\'t parse that. Try a clearer format like "Dinner 500".',
          );
        }

        if (result.parseConfidence == 'reject') {
          final msg = result.rejectReason?.trim().isNotEmpty == true
              ? result.rejectReason!
              : 'Couldn\'t parse that. Try a clearer format like "Dinner 500".';
          throw GroqParserRejectException(msg);
        }

        final validationError = validateResult(
          result,
          expectedCurrencyCode: expectedCurrencyCode,
        );
        if (validationError != null) {
          throw GroqParserRejectException(validationError);
        }

        String? gap;
        if (result.parseConfidence == 'confident') {
          gap = _findGap(result);
        }
        if (gap != null) {
          final fallback = _fallbackParse(
            userInput,
            expectedCurrencyCode: expectedCurrencyCode,
          );
          if (fallback != null) return fallback;
          throw Exception(gap);
        }

        final desc = result.description.trim();
        if (desc.isEmpty) {
          result = ParsedExpenseResult(
            amount: result.amount,
            currencyCode: result.currencyCode,
            description: 'Expense',
            category: result.category,
            splitType: result.splitType,
            participantNames: result.participantNames,
            payerName: result.payerName,
            excludedNames: result.excludedNames,
            exactAmountsByName: result.exactAmountsByName,
            percentageByName: result.percentageByName,
            sharesByName: result.sharesByName,
            parseConfidence: result.parseConfidence,
            constraintFlags: result.constraintFlags,
            notes: result.notes,
            rejectReason: result.rejectReason,
            needsClarification: result.needsClarification,
            clarificationQuestion: result.clarificationQuestion,
          );
        }
        return result;
      } finally {
        _inFlight = false;
      }
    } on GroqRateLimitException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw GroqRateLimitException('Rate limit exceeded. Try again in a moment.');
      }
      final fallback = _fallbackParse(
        userInput,
        expectedCurrencyCode: expectedCurrencyCode,
        groupMemberNames: groupMemberNames,
      );
      if (fallback != null) return fallback;
      rethrow;
    } on GroqParserRejectException {
      // Semantic rejects must propagate as user-facing errors; do not apply fallback.
      rethrow;
    } catch (e) {
      final fallback = _fallbackParse(
        userInput,
        expectedCurrencyCode: expectedCurrencyCode,
        groupMemberNames: groupMemberNames,
      );
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  /// Fallback: extract first number from input and return minimal ParsedExpenseResult if valid.
  /// Also enforces semantic completeness: if the non-numeric portion of the input matches
  /// exactly one group member name (i.e. "Rishi 5"), returns a constrained result with
  /// needsClarification=true — never auto-commits a name+amount with no verb/description.
  static ParsedExpenseResult? _fallbackParse(
    String userInput, {
    String? expectedCurrencyCode,
    List<String> groupMemberNames = const [],
  }) {
    final amount = _extractAmountFromText(userInput);
    if (amount == null || amount <= 0 || amount.isNaN || amount.isInfinite) {
      return null;
    }
    final trimmed = userInput.trim();

    String? currencyCode;
    final upper = trimmed.toUpperCase();
    if (trimmed.contains(r'$') || upper.contains('USD')) {
      currencyCode = 'USD';
    } else if (trimmed.contains('€') || upper.contains('EUR')) {
      currencyCode = 'EUR';
    } else if (trimmed.contains('£') || upper.contains('GBP')) {
      currencyCode = 'GBP';
    } else if (trimmed.contains('¥') || upper.contains('JPY')) {
      currencyCode = 'JPY';
    } else if (trimmed.contains('₹') || upper.contains('INR')) {
      currencyCode = 'INR';
    }

    final description = trimmed.isEmpty
        ? 'Expense'
        : (trimmed.length > 80 ? '${trimmed.substring(0, 80)}\u2026' : trimmed);

    // --- Semantic completeness check (domain rule, not UI rule) ---
    // If the non-numeric portion of the input is solely a member name (e.g. "Rishi 5"),
    // the input has no verb, direction, or description — it is semantically incomplete.
    // Return constrained+needsClarification so every caller surfaces it identically.
    final nonNumeric = trimmed
        .replaceAll(RegExp(r'[\d,]+\.?\d*'), '')
        .replaceAll(RegExp(r'[₹\$€£¥]'), '')
        .trim()
        .toLowerCase();
    if (nonNumeric.isNotEmpty) {
      final isSoloGroup = groupMemberNames.length <= 1;
      
      // Single-word non-numeric portion that matches a group member name exactly.
      final isMemberNameOnly = groupMemberNames.any(
        (name) => name.trim().toLowerCase() == nonNumeric,
      );
      
      // Heuristic: single word with no known verb/preposition is ambiguous if it's NOT a solo group.
      // If it IS a solo group, "Chicken 500" is a perfectly valid "Chicken" expense.
      final hasVerb = RegExp(
        r'\b(paid|bought|covered|for|with|spent|got|took|owe|owes|had|lent|gave|dinner|lunch|breakfast|coffee|uber|cab|rent|groceries|movie|bill|ticket|petrol|hotel|flight)\b',
        caseSensitive: false,
      ).hasMatch(trimmed);

      // We only trigger semanticIncomplete if:
      // 1. It's EXCLUSIVELY a member name (e.g. "Rishi 500") -> Who paid? What for?
      // 2. Or if it's a multi-person group and the input is just "Person 500" or "Item 500" without context.
      if (isMemberNameOnly ||
          (!isSoloGroup && !hasVerb && nonNumeric.split(RegExp(r'\s+')).length <= 1)) {
            
        final suggestionSuffix = isMemberNameOnly 
            ? 'with $nonNumeric' 
            : 'for $nonNumeric';

        final result = ParsedExpenseResult(
          amount: amount,
          currencyCode: currencyCode,
          description: 'Expense',
          category: '',
          splitType: 'unresolved',
          participantNames: [],
          parseConfidence: 'constrained',
          constraintFlags: ['semanticIncomplete'],
          needsClarification: true,
          clarificationQuestion:
              'What was this expense for? Try something like "Dinner $amount $suggestionSuffix".',
        );
        final err = validateResult(
          result,
          expectedCurrencyCode: expectedCurrencyCode,
        );
        if (err != null) throw GroqParserRejectException(err);
        return result;
      }
    }

    final result = ParsedExpenseResult(
      amount: amount,
      currencyCode: currencyCode,
      description: description,
      category: '',
      splitType: 'even',
      participantNames: [],
      parseConfidence: 'constrained',
      constraintFlags: ['fallbackExtraction'],
    );

    final err = validateResult(
      result,
      expectedCurrencyCode: expectedCurrencyCode,
    );
    if (err != null) throw GroqParserRejectException(err);

    return result;
  }

  /// Extracts the first numeric amount from text (handles "500", "1,200", "99.50", "₹500", gibberish with digits).
  /// Expands number words (lakh, crore, million, billion) so "4 lakh" is found as 400000.
  static double? _extractAmountFromText(String text) {
    final expanded = expandNumberWordsInText(text);
    final match = RegExp(r'[\d,]+\.?\d*').firstMatch(expanded);
    if (match == null) return null;
    final cleaned = match.group(0)!.replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  /// Expands locale-aware number words in text so amount extraction and the model see numeric values.
  /// Indian: lakh = 100000, crore = 10000000. International: million = 1000000, billion = 1000000000.
  /// Example: "4 lakh" → "400000", "2.5 crore" → "25000000".
  static String expandNumberWordsInText(String text) {
    const multipliers = {
      'lakh': 100000.0,
      'lacs': 100000.0,
      'lac': 100000.0,
      'crore': 10000000.0,
      'crores': 10000000.0,
      'million': 1000000.0,
      'millions': 1000000.0,
      'billion': 1000000000.0,
      'billions': 1000000000.0,
    };
    String result = text;
    for (final entry in multipliers.entries) {
      final pattern = RegExp(
        r'(\d+(?:\.\d+)?)\s*' + entry.key,
        caseSensitive: false,
      );
      result = result.replaceAllMapped(pattern, (m) {
        final n = double.tryParse(m.group(1) ?? '') ?? 0;
        final value = (n * entry.value).round();
        return value.toString();
      });
    }
    return result;
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
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GroqExpenseParserService: strict JSON decode failed: $e');
      }
    }
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
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GroqExpenseParserService: relaxed JSON decode failed: $e');
      }
    }
    return null;
  }

  /// Extracts a JSON object from raw text (handles markdown, leading/trailing text).
  static String _extractJson(String raw) {
    raw = raw.trim();
    final codeBlockMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(raw);
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
}
