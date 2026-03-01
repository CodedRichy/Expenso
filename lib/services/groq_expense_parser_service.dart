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
  })  : participantNames = participantNames ?? [],
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
                    : split == 'unresolved'
                        ? 'unresolved'
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
    final confidence = (json['parseConfidence'] as String?)?.trim().toLowerCase();
    final pc = confidence == 'reject'
        ? 'reject'
        : confidence == 'constrained'
            ? 'constrained'
            : 'confident';
    List<String> flags = [];
    final flagsRaw = json['constraintFlags'];
    if (flagsRaw is List) {
      for (final f in flagsRaw) {
        if (f != null && f.toString().trim().isNotEmpty) flags.add(f.toString().trim());
      }
    }
    List<String> notesList = [];
    final notesRaw = json['notes'];
    if (notesRaw is List) {
      for (final n in notesRaw) {
        if (n != null && n.toString().trim().isNotEmpty) notesList.add(n.toString().trim());
      }
    }
    final needClar = json['needsClarification'] == true;
    final q = (json['clarificationQuestion'] as String?)?.trim();
    final rejectReasonStr = (json['rejectReason'] as String?)?.trim();
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
      parseConfidence: pc,
      constraintFlags: flags.isNotEmpty ? flags : null,
      notes: notesList.isNotEmpty ? notesList : null,
      rejectReason: rejectReasonStr != null && rejectReasonStr.isNotEmpty ? rejectReasonStr : null,
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
    if (payerName != null && payerName!.isNotEmpty) m['payer'] = payerName;
    if (excludedNames.isNotEmpty) m['excluded'] = excludedNames;
    if (exactAmountsByName.isNotEmpty) m['exactAmounts'] = exactAmountsByName;
    if (percentageByName.isNotEmpty) m['percentageAmounts'] = percentageByName;
    if (sharesByName.isNotEmpty) m['sharesAmounts'] = sharesByName;
    if (constraintFlags.isNotEmpty) m['constraintFlags'] = constraintFlags;
    if (notes.isNotEmpty) m['notes'] = notes;
    if (needsClarification) m['needsClarification'] = true;
    if (rejectReason != null) m['rejectReason'] = rejectReason;
    if (clarificationQuestion != null) m['clarificationQuestion'] = clarificationQuestion;
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
  static void recordSuccessfulParse(String userInput, ParsedExpenseResult result) {
    final trimmed = userInput.trim();
    if (trimmed.isEmpty) return;
    try {
      final json = jsonEncode(result.toJson());
      _recentExamples.add((input: trimmed, json: json));
      if (_recentExamples.length > _maxRecentExamples) {
        _recentExamples.removeAt(0);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('GroqExpenseParserService: failed to cache recent example: $e');
    }
  }

  /// Returns an error message if [result] is invalid; null if valid.
  /// For confident: amount > 0, splitType not unresolved, and exact/percentage sums match.
  /// Aligned with CLI (parser_cli.dart): demote confident+unresolved/history; settlements must be rejected.
  static String? validateResult(ParsedExpenseResult result) {
    if (result.amount.isNaN || result.amount.isInfinite) {
      return 'Amount must be a valid number.';
    }
    if (result.parseConfidence == 'confident' &&
        (result.splitType == 'unresolved' || result.constraintFlags.contains('history'))) {
      return 'Validation: Confident parse cannot have splitType unresolved or history flags.';
    }
    final descLower = result.description.toLowerCase();
    if ((descLower.contains('debt') || descLower.contains('settle')) &&
        result.parseConfidence != 'reject') {
      return 'Validation: Settlements must be REJECTED.';
    }
    if (result.parseConfidence == 'confident') {
      if (result.amount <= 0) return 'Amount must be greater than 0.';
      if (result.splitType == 'unresolved') {
        return 'Confident parse cannot have splitType unresolved.';
      }
      final gap = _findGap(result);
      if (gap != null) return gap;
    }
    return null;
  }

  /// Returns a description of a gap if split amounts don't match total; null if no gap.
  /// Wording aligned with CLI (parser_cli.dart).
  static String? _findGap(ParsedExpenseResult result) {
    const tolerance = 0.01;
    if (result.splitType == 'exact' && result.exactAmountsByName.isNotEmpty) {
      final sum = result.exactAmountsByName.values.fold<double>(0, (a, b) => a + b);
      if ((sum - result.amount).abs() > tolerance) {
        return 'Exact split: amounts sum to $sum but total is ${result.amount}.';
      }
    }
    if (result.splitType == 'percentage' && result.percentageByName.isNotEmpty) {
      final sum = result.percentageByName.values.fold<double>(0, (a, b) => a + b);
      if ((sum - 100).abs() > tolerance) {
        return 'Percentage split: sum is $sum, should be 100.';
      }
    }
    return null;
  }

  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  // Model aligned with CLI parser (tool/parser_cli.dart) for consistent behavior.
  static const String _model = 'meta-llama/llama-4-scout-17b-16e-instruct';

  static String? get _apiKey {
    final key = dotenv.env['GROQ_API_KEY'];
    if (key == null || key.trim().isEmpty) return null;
    return key.trim();
  }

  /// System prompt aligned with PARSER_OUTCOME_CONTRACT.md and CLI parser (tool/parser_cli.dart).
  /// When [recentExamples] is non-empty, appends a RECENT EXAMPLES section (like CLI's parser_runs.log).
  static String _buildSystemPrompt(
    String memberList, [
    String? currentUserName,
    List<({String input, String json})> recentExamples = const [],
  ]) {
    final currentUser = currentUserName?.trim().isNotEmpty == true ? currentUserName!.trim() : '(not set)';
    final recentSection = recentExamples.isNotEmpty
        ? '\n--- RECENT EXAMPLES (from your confirmed expenses) ---\n${recentExamples.map((e) => '"${e.input.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}" -> ${e.json}').join('\n')}\n\n'
        : '';
    return '''
You are an expense parser. This prompt is designed to work with any language model—follow these instructions exactly. Turn the user message into exactly ONE JSON expense object. Any locale/currency. Reply with ONLY that JSON—no other text, markdown, or explanation.

--- CORE ACCOUNTING RULES (source of truth; follow exactly) ---
1. PAYER: If "I" paid/covered, payer = "$currentUser". If no payer is mentioned, DEFAULT to "$currentUser". ONLY use other names if the text explicitly states they paid.
2. TOTAL SUM CONSISTENCY: The sum of all individual shares (exact/percentage/shares) MUST equal the total amount.
3. THE REMAINDER RULE: If the user specifies an amount for only one person (e.g., "Dinner 3000, Sam's dessert was 400"), you MUST: Assign the specific amount (400) to that person. Divide the remaining balance (2600) equally among EVERYONE in the group (including the specific person and the payer). Add their equal share to their specific amount. If a specific amount is mentioned for one person, the remaining amount MUST be distributed among all participants. If participants are listed but no specific amounts are given for them, split the remainder evenly.
4. PARTICIPANTS: "Everyone", "Usual gang", "The group" = All members in the list. If "everyone except X", set splitType to "exclude", put X in the "excluded" array, leave "participants" empty—do NOT manually resolve the participants into a list. participants[] should ONLY contain names OTHER than the payer.

IMPORTANT: If the message contains multiple expenses or intents, you MUST still output only ONE object and mark it as constrained with constraintFlags ["multiIntent"]. Do NOT collapse multiple expenses into one amount.

--- OUTPUT SCHEMA (required every time) ---
parseConfidence ("confident"|"constrained"|"reject"),
amount (number; use 0 if unknown),
description (string),
category (string or ""),
splitType ("even"|"exact"|"exclude"|"percentage"|"shares"|"unresolved"),
participants (array; [] = everyone ONLY when explicitly stated or safely defaultable)

Optional:
payer (string; ONLY from member list; when "I paid" set to current user name explicitly),
excluded (array),
exactAmounts,
percentageAmounts,
sharesAmounts,
constraintFlags (array; REQUIRED when constrained),
notes (array of strings; non-actionable metadata),
needsClarification (boolean; true when reject, or when constrained and you need to ask the user something),
rejectReason (string; ONLY when reject)

When parseConfidence is "reject":
- set needsClarification = true
- do NOT ask a question
- do NOT create a ledger-impacting expense

Example:
{"parseConfidence":"confident","amount":200,"description":"Dinner","category":"Food","splitType":"even","participants":[],"payer":"$currentUser"}

--- SCENARIO (infer strictly in this order) ---

1) WHO PAID?
- "X paid", "paid by X", "X bought/got/covered" → payer = X (ONLY if X is in member list)
- "I paid", "I covered", "I bought" → payer = current user name explicitly
- If payer not in member list → omit payer
- NEVER invent a payer

2) WHO SHARES?
- "with X", "for me and X" → participants = [X] (NEVER include current user)
- "for A and B" when current user is A → participants = [B]
- "everyone", "all", "the group" AND explicitly stated → participants = []
- If participants unclear ("some of us", "you know who", "usual people"):
  → participants = []
  → splitType = "unresolved"
  → constraintFlags MUST include "participantsUnknown" or "participantsInferredFromHistory"
- NEVER assign even/exact/etc when participants are unknown

3) SPLIT TYPE?
- If participants unknown → splitType = "unresolved"
- Per-person amounts → exact
- Percentages → percentage
- Shares → shares
- Explicit exclusions → exclude
- Else (participants known or explicitly everyone) → even

--- MEMBER LIST (use ONLY these spellings) ---
$memberList
Current user name: $currentUser
Match nicknames/typos to this list. Output exact spelling only.

--- FIELD RULES ---
• amount: ONE numeric total. Strip currency symbols and separators (1,200 → 1200). Decimals allowed.
• **Number words (locale-aware):** Expand before output. Indian: lakh = 100000, crore = 10000000 (e.g. "4 lakh" → 400000, "2.5 crore" → 25000000). International: million = 1000000, billion = 1000000000. Always output the final numeric amount (e.g. 400000 not 4).
• description: 1–3 words, Title Case. Abbreviations: dinr→Dinner, cff→Coffee, tkt→Tickets, uber/cab→Transport, bt→Groceries, ght+word→that word. Else "Expense".
• category: Food / Transport / Utilities when obvious; else "".
• participants: Others only. NEVER include current user.
• splitType:
  - exact → exactAmounts MUST include everyone involved; sum MUST equal total
  - percentage → percentageAmounts MUST sum to 100
  - shares → sharesAmounts MUST include everyone
  - exclude → excluded list REQUIRED
• exactAmounts / sharesAmounts MUST include current user ONLY when explicitly stated ("I had 800", "I took 2 shares")
• payer MUST be explicit or omitted; NEVER inferred from history

--- "OWES ME" / "I OWE" (debt direction) ---
• "X owes me <amount>" or "user B owes me 4 lakh": X/B is the debtor, current user is the creditor. Output: amount = <amount in digits (e.g. 400000)>, payer = current user (creditor), participants = [X or B], splitType = "exact", exactAmounts = { currentUser: 0, X: amount } so the debtor's share is the full amount.
• "I owe X <amount>" or "I owe user B 500": current user is the debtor, X/B is the creditor. Output: amount = <amount>, payer = X (creditor), participants = [current user], splitType = "exact", exactAmounts = { X: 0, currentUser: amount }.
• Match "user b" / "user B" to member list (e.g. B); use exact spelling from MEMBER LIST.

--- CONFIDENCE RULES (NON-NEGOTIABLE) ---

RULE A (Integrity): If splitType is "unresolved", parseConfidence MUST be "constrained". NEVER mark a history-dependent split as confident.
RULE B (Exactness): If splitType is "exact", exactAmounts MUST be populated and their sum MUST exactly equal the total amount. If you cannot calculate the specific numbers, use splitType: "unresolved" and mark as "constrained".
RULE C (Participant Guard): If the user says "Everyone except X", set splitType to "exclude", put X in the "excluded" array, and leave "participants" empty. Do NOT manually resolve the participants into a list.
RULE D (Settlement): "Clear my debt", "paid me back" = Settlement. If the intent is settling a debt instead of a shared group expense, set parseConfidence: "reject".

--- STEP-BY-STEP CALCULATION (for exact splits) ---
Before generating JSON, calculate the balance: Total Amount = [X]. Specified Exact Amounts = Sum of all mentioned individual costs. Remainder = (Total Amount) - (Specified Exact Amounts). Split the Remainder equally among all participants (including those with exact amounts). Final exactAmounts for each person = (Their share of remainder) + (Their specific cost, if any). Ensure the sum of exactAmounts matches the Total Amount exactly. CRITICAL: exactAmounts values MUST be raw numbers (e.g. 650), NEVER strings with math (e.g. "2600/4").

CONFIDENT only if ALL true:
- amount > 0
- exactly ONE expense intent
- payer known or safely defaulted ("I paid")
- participants explicit or explicitly everyone
- NO history-based inference ("same as usual")
- NO settlement language
- NO future intent

CONSTRAINED if:
- amount known BUT participants unknown
- history-based inference detected
- distribution deferred ("we'll divide later")
- settlement mentioned alongside expense
- multiple intents detected (set constraintFlags ["multiIntent"])
- advance payment not yet distributed

REJECT if:
- no amount AND ledger mutation implied
- settlement-only message ("clear what I owed") with no expense
- future intent ("I'll take care of mine next time")
- intent cannot be safely classified

--- SETTLEMENT VS EXPENSE ---
- Repaying debt = settlement, NOT an expense
- Settlement-only messages → constrained with constraintFlags ["settlementNotExpense"] OR reject if amount missing
- Expense + "already paid back" → record expense; settlements handled separately (constraintFlags ["settlementsRecordedSeparately"])

--- NOTES ---
- Narrative text ("exclude leftovers", "mostly", "even things out") → notes[]
- Notes NEVER affect money

--- CRITICAL SAFETY RULES ---
• NEVER invent participants, amounts, splits, or settlements
• NEVER upgrade confidence based on history
• participants: [] WITHOUT a constraint flag means explicit "everyone"
• participants: [] WITH participantsUnknown means UNKNOWN
• Applied ledger entries must be safe under zero-sum accounting

--- COMMON MISTAKES (wrong → right) ---
"X paid 200" no "with Y" → RIGHT: participants:[], payer:X. "200 with X" / "dinner 300 with B" → RIGHT: participants:[X] or [B]. "Split between A, B, C" with current user A → RIGHT: participants:[B,C]. "I had 800, B 200" total 1000 → RIGHT: exactAmounts include current user so sum=1000. "I took 2 shares, B 1" → RIGHT: sharesAmounts include current user. Payer name not in list → RIGHT: omit payer.

--- EXAMPLES (member list: A, B, C; current user: A) ---
"dinner 200 with B" -> {"parseConfidence":"confident","amount":200,"description":"Dinner","category":"Food","splitType":"even","participants":["B"]}
"B paid 500 for dinner" -> {"parseConfidence":"confident","amount":500,"description":"Dinner","category":"Food","splitType":"even","participants":[],"payer":"B"}
"I bought pizza for 800" -> {"parseConfidence":"confident","amount":800,"description":"Pizza","category":"Food","splitType":"even","participants":[]}
"1000 total 400 for me 600 for B" -> {"parseConfidence":"confident","amount":1000,"description":"Expense","category":"","splitType":"exact","participants":[],"exactAmounts":{"A":400,"B":600}}
"Rent 10000 split 60-40 with B" -> {"parseConfidence":"confident","amount":10000,"description":"Rent","category":"","splitType":"percentage","participants":[],"percentageAmounts":{"A":60,"B":40}}
"user B owes me 4 lakh" -> {"parseConfidence":"confident","amount":400000,"description":"Debt","category":"","splitType":"exact","participants":["B"],"payer":"A","exactAmounts":{"A":0,"B":400000}}
"I owe B 500" -> {"parseConfidence":"confident","amount":500,"description":"Debt","category":"","splitType":"exact","participants":["A"],"payer":"B","exactAmounts":{"B":0,"A":500}}
$recentSection--- OUTPUT ---
Output ONE valid JSON object only. Double-quoted keys/strings. No trailing commas.''';
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
    final recent = List<({String input, String json})>.from(_recentExamples);
    final systemPrompt = _buildSystemPrompt(memberList, currentUserDisplayName?.trim(), recent);
    final normalizedInput = expandNumberWordsInText(userInput.trim());

    final body = {
      'model': _model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': normalizedInput},
      ],
      'temperature': 0,
      'max_tokens': 256,
    };

    try {
      await _throttleForRateLimit();
      _inFlight = true;
      try {
        http.Response response = await _post(apiKey, body);
        _markRequestDone();

        if (response.statusCode == 429) {
          final wait1 = _retryAfterSeconds(response);
          await Future<void>.delayed(Duration(seconds: wait1));
          response = await _post(apiKey, body);
          _markRequestDone();
          if (response.statusCode == 429) {
            final wait2 = (wait1 * 2).clamp(2, 60);
            await Future<void>.delayed(Duration(seconds: wait2));
            debugPrint('Groq API rate limit (429) after backoff: ${response.body}');
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

      if (result.parseConfidence == 'reject') {
        final msg = result.rejectReason?.trim().isNotEmpty == true
            ? result.rejectReason!
            : 'Couldn\'t parse that. Try a clearer format like "Dinner 500".';
        throw Exception(msg);
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
      parseConfidence: 'constrained',
      constraintFlags: ['fallbackExtraction'],
    );
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
      if (kDebugMode) debugPrint('GroqExpenseParserService: strict JSON decode failed: $e');
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
      if (kDebugMode) debugPrint('GroqExpenseParserService: relaxed JSON decode failed: $e');
    }
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

  static int _retryAfterSeconds(http.Response response) {
    final v = response.headers['retry-after']?.trim();
    if (v == null || v.isEmpty) return 2;
    final s = int.tryParse(v);
    if (s == null || s < 1) return 2;
    if (s > 60) return 60;
    return s;
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
