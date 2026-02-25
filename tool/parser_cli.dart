// CLI for testing the expense parser. Uses GROQTRIAL_API_KEY from .env.
// Iterate on this CLI until perfect; do not touch the app parser (groq_expense_parser_service.dart) until then.
// Includes "curious student" behavior: when unclear, output needsClarification + clarificationQuestion instead of guessing.
// Records each run to tool/parser_runs.log (input + raw JSON + parsed params) for debugging splits.
// Run: dart tool/parser_cli.dart "Dinner 500"
//      dart tool/parser_cli.dart "my food 400 alex 200" "Rishi, Prasi, Alex" "Rishi"

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
const _model = 'llama-3.3-70b-versatile';
const _logPath = 'tool/parser_runs.log';
const _rateLimitTpm = 12000;
const _minIntervalSeconds = 4;

const _lastRequestStampPath = 'tool/.parser_last_request';

void main(List<String> args) async {
  final env = _loadEnv();
  final apiKey = env['GROQTRIAL_API_KEY']?.trim();
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Set GROQTRIAL_API_KEY in .env');
    exit(1);
  }

  final userInput = args.isEmpty ? 'Dinner 500' : args[0];
  final memberListStr = args.length > 1
      ? args[1].split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).join(", ")
      : 'Rishi, Prasi, Alex, Sam, Jordan';
  final memberList = ' $memberListStr';
  final members = memberListStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  final currentUser = args.length > 2 ? args[2].trim() : (members.isNotEmpty ? members.first : null);

  stdout.writeln('Input: "$userInput"');
  stdout.writeln('Members:$memberList');
  if (currentUser != null) stdout.writeln('Current user: $currentUser');
  stdout.writeln('---');

  final recentExamples = _loadRecentExamplesFromLog(10);
  if (recentExamples.isNotEmpty) stdout.writeln('Using ${recentExamples.length} recent examples from log.');
  final systemPrompt = _buildSystemPrompt(memberList, currentUser, recentExamples);
  final body = {
    'model': _model,
    'messages': [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userInput.trim()},
    ],
    'temperature': 0,
    'max_tokens': 256,
  };

  await _throttleForRateLimit();
  http.Response response = await _post(apiKey, body);
  _markRequestDone();
  if (response.statusCode == 429) {
    final waitSeconds = _retryAfterSeconds(response);
    stdout.writeln('429 rate limit; waiting ${waitSeconds}s...');
    await Future<void>.delayed(Duration(seconds: waitSeconds));
    response = await _post(apiKey, body);
    _markRequestDone();
    if (response.statusCode == 429) {
      stderr.writeln('Still rate limited. Try again later.');
      _recordRun(userInput: userInput, members: memberListStr, rawJson: null, result: null, error: '429 rate limit');
      exit(1);
    }
  }

  if (response.statusCode != 200) {
    stderr.writeln('API ${response.statusCode}: ${response.body}');
    _recordRun(userInput: userInput, members: memberListStr, rawJson: null, result: null, error: 'API ${response.statusCode}');
    exit(1);
  }

  final map = jsonDecode(response.body) as Map<String, dynamic>?;
  if (map == null) {
    stderr.writeln('Invalid API response.');
    _recordRun(userInput: userInput, members: memberListStr, rawJson: null, result: null, error: 'Invalid API response');
    exit(1);
  }

  final choices = map['choices'] as List?;
  final first = choices?.isNotEmpty == true ? choices!.first : null;
  final message = first is Map<String, dynamic> ? first['message'] : null;
  final content = message is Map<String, dynamic> ? message['content'] : null;
  String raw = (content is String) ? content.trim() : '';

  if (raw.isEmpty) {
    stderr.writeln('Empty content from API.');
    _recordRun(userInput: userInput, members: memberListStr, rawJson: null, result: null, error: 'Empty content from API');
    exit(1);
  }

  raw = raw.replaceAll('\uFEFF', '');
  raw = _extractJson(raw);
  raw = _fixCommonJsonIssues(raw);

  stdout.writeln('Raw JSON from API:');
  stdout.writeln(raw);
  stdout.writeln('---');

  final decoded = _tryDecodeJson(raw);
  if (decoded == null) {
    stderr.writeln('Failed to decode JSON.');
    _recordRun(userInput: userInput, members: memberListStr, rawJson: raw, result: null, error: 'Failed to decode JSON');
    exit(1);
  }

  ParsedExpenseResult result;
  try {
    result = ParsedExpenseResult.fromJson(decoded);
  } catch (e) {
    stderr.writeln('fromJson error: $e');
    _recordRun(userInput: userInput, members: memberListStr, rawJson: raw, result: null, error: 'fromJson: $e');
    exit(1);
  }

  final validationError = _validateResult(result);
  if (validationError != null) {
    stderr.writeln('Validation: $validationError');
    _recordRun(userInput: userInput, members: memberListStr, rawJson: raw, result: result, error: 'Validation: $validationError');
    exit(1);
  }

  final gap = result.parseConfidence == 'confident' ? _findGap(result) : null;
  if (gap != null) {
    stderr.writeln('GAP: $gap');
    _recordRun(userInput: userInput, members: memberListStr, rawJson: raw, result: result, error: 'GAP: $gap');
    exit(1);
  }

  if (result.description.trim().isEmpty) {
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
      needsClarification: result.needsClarification,
      clarificationQuestion: result.clarificationQuestion,
      parseConfidence: result.parseConfidence,
      constraintFlags: result.constraintFlags,
      notes: result.notes,
      rejectReason: result.rejectReason,
    );
  }

  _recordRun(userInput: userInput, members: memberListStr, rawJson: raw, result: result, error: null);

  final outcome = result.parseConfidence == 'reject'
      ? 'REJECT'
      : result.parseConfidence == 'constrained'
          ? 'CONSTRAINED'
          : 'CONFIDENT';
  stdout.writeln('Outcome: $outcome');
  if (result.constraintFlags.isNotEmpty) stdout.writeln('  constraintFlags: ${result.constraintFlags}');
  if (result.notes.isNotEmpty) stdout.writeln('  notes: ${result.notes}');
  stdout.writeln('Parsed: amount=${result.amount} description="${result.description}" category="${result.category}" splitType=${result.splitType} participants=${result.participantNames} payer=${result.payerName}');
  if (result.excludedNames.isNotEmpty) stdout.writeln('  excluded: ${result.excludedNames}');
  if (result.exactAmountsByName.isNotEmpty) stdout.writeln('  exactAmounts: ${result.exactAmountsByName}');
  if (result.percentageByName.isNotEmpty) stdout.writeln('  percentageAmounts: ${result.percentageByName}');
  if (result.sharesByName.isNotEmpty) stdout.writeln('  sharesAmounts: ${result.sharesByName}');
  if (result.parseConfidence == 'reject') {
    if (result.rejectReason != null) stdout.writeln('  rejectReason: ${result.rejectReason}');
    stdout.writeln('(Needs clarification — no questions; do not write to ledger)');
  } else if (result.needsClarification && result.clarificationQuestion != null) {
    stdout.writeln('NEEDS CLARIFICATION: ${result.clarificationQuestion}');
  }
  stdout.writeln('OK');
  stdout.writeln('Recorded to $_logPath');
}

String? _findGap(ParsedExpenseResult result) {
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

void _recordRun({
  required String userInput,
  required String members,
  required String? rawJson,
  required ParsedExpenseResult? result,
  required String? error,
}) {
  final now = DateTime.now().toUtc();
  final ts = '${now.toIso8601String().replaceFirst('T', ' ').substring(0, 19)}Z';
  final buf = StringBuffer();
  buf.writeln('');
  buf.writeln('---');
  buf.writeln('$ts');
  buf.writeln('INPUT: "$userInput"');
  buf.writeln('MEMBERS: $members');
  if (rawJson != null) buf.writeln('RAW_JSON: $rawJson');
  if (error != null) buf.writeln('ERROR: $error');
  if (result != null) {
    buf.writeln('PARAMS:');
    buf.writeln('  amount: ${result.amount}');
    buf.writeln('  description: "${result.description}"');
    buf.writeln('  category: "${result.category}"');
    buf.writeln('  splitType: ${result.splitType}');
    buf.writeln('  participants: ${result.participantNames}');
    buf.writeln('  payer: ${result.payerName ?? "(none)"}');
    buf.writeln('  excluded: ${result.excludedNames}');
    buf.writeln('  exactAmounts: ${result.exactAmountsByName}');
    buf.writeln('  percentageAmounts: ${result.percentageByName}');
    buf.writeln('  sharesAmounts: ${result.sharesByName}');
    buf.writeln('  parseConfidence: ${result.parseConfidence}');
    if (result.constraintFlags.isNotEmpty) buf.writeln('  constraintFlags: ${result.constraintFlags}');
    if (result.notes.isNotEmpty) buf.writeln('  notes: ${result.notes}');
    if (result.rejectReason != null) buf.writeln('  rejectReason: ${result.rejectReason}');
    if (result.needsClarification) buf.writeln('  needsClarification: true');
    if (result.clarificationQuestion != null) buf.writeln('  clarificationQuestion: "${result.clarificationQuestion}"');
  }
  try {
    final file = File(_logPath);
    file.writeAsStringSync(buf.toString(), mode: FileMode.append);
  } catch (_) {}
}

List<({String input, String json})> _loadRecentExamplesFromLog(int maxCount) {
  final file = File(_logPath);
  if (!file.existsSync()) return [];
  final content = file.readAsStringSync();
  final blocks = content.split(RegExp(r'\n---\n'));
  final good = <({String input, String json})>[];
  for (final block in blocks) {
    if (block.trim().isEmpty) continue;
    if (block.contains('ERROR:')) continue;
    String? input;
    String? rawJson;
    for (final line in block.split('\n')) {
      if (line.startsWith('INPUT: ')) {
        final rest = line.substring(7).trim();
        if (rest.length >= 2 && rest.startsWith('"') && rest.endsWith('"')) {
          input = rest.substring(1, rest.length - 1);
        }
      } else if (line.startsWith('RAW_JSON: ')) {
        rawJson = line.substring(10).trim();
      }
    }
    if (input != null && rawJson != null && rawJson.startsWith('{')) {
      good.add((input: input, json: rawJson));
    }
  }
  if (good.length <= maxCount) return good;
  return good.sublist(good.length - maxCount);
}

Map<String, String> _loadEnv() {
  final file = File('.env');
  if (!file.existsSync()) return {};
  final out = <String, String>{};
  for (final line in file.readAsStringSync().split('\n')) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    final i = t.indexOf('=');
    if (i <= 0) continue;
    final k = t.substring(0, i).trim();
    var v = t.substring(i + 1).trim();
    if (v.startsWith('"') && v.endsWith('"')) v = v.substring(1, v.length - 1);
    if (v.startsWith("'") && v.endsWith("'")) v = v.substring(1, v.length - 1);
    out[k] = v;
  }
  return out;
}

String _buildSystemPrompt(String memberList, [String? currentUserName, List<({String input, String json})> recentExamples = const []]) {
  final currentUserLine = currentUserName != null && currentUserName.isNotEmpty
      ? '\nCurrent user (I/me/my — use this name in exactAmounts and sharesAmounts when the message says "I had X", "my X was N", "I took N shares", or "rest between me and X"): $currentUserName'
      : '';
  return '''
You are an expense parser. This prompt is designed to work with any language model—follow these instructions exactly. Turn the user message into exactly one JSON expense object. Any locale/currency. Reply with ONLY that JSON—no other text, markdown, or explanation.

--- OUTPUT SCHEMA (required every time) ---
parseConfidence ("confident"|"constrained"|"reject"), amount (number; use 0 if unknown), description (string), category (string or ""), splitType ("even"|"exact"|"exclude"|"percentage"|"shares"|"unresolved"), participants (array; [] = everyone only when appropriate and known).
Optional: payer (string; when "I paid" set to current user name explicitly), excluded (array), exactAmounts, percentageAmounts, sharesAmounts, constraintFlags (array; only when constrained), notes (array of strings; non-actionable metadata e.g. "Excludes leftovers from previous day"), needsClarification (boolean; true when reject), rejectReason (string; when reject e.g. "futureIntentNotRecordable"). When parseConfidence is "reject" do NOT set clarificationQuestion (no questions).
Example: {"parseConfidence":"confident","amount":200,"description":"Dinner","category":"Food","splitType":"even","participants":["B"],"payer":"Rishi"}

--- SCENARIO (infer in this order) ---
1) WHO PAID? "X paid", "paid by X", "X bought/got/covered" → payer X (only if X is in member list). "I paid" / "I had to pay" → set payer to current user name explicitly. Payer not in list → omit payer.
2) WHO SHARES? "with X" / "for me and X" → participants = [X] or [X,Y] — never include current user. "everyone"/"all"/"the group" AND known → participants = []. If participants unknown (e.g. "some of us", "you know who") → participants = [], splitType = "unresolved", constraintFlags include participantsUnknown. Never assign a split strategy (even/exact/…) when participants are unknown.
3) SPLIT TYPE? If participants unknown → splitType "unresolved" (never even/exact/… with unknown participants). Per-person amounts → exact. Percentages → percentage. Shares → shares. Someone excluded → exclude. Else (and participants known) → even.
Key: "X paid 200" (no "with Y") = payer:X, participants:[], even. "200 with X" = participants:[X], even. Participants unclear → splitType "unresolved", participantsUnknown.

--- MEMBER LIST (use ONLY these spellings) ---
$memberList$currentUserLine
Match typos/nicknames to this list; output exact spelling only. Payer must be from this list or omit.

--- FIELD RULES ---
• amount: One numeric total. Strip currency and thousand separators (1,200 → 1200). Decimals OK.
• description: 1–3 words, title-case. Abbreviations: dinr→Dinner, cff→Coffee, tkt→Tickets, uber/cab→Transport, bt→Groceries, ght+word→that word. Else "Expense".
• category: Food/Transport/Utilities when obvious; "" otherwise.
• splitType (first match): (a) exact — per-person amounts; exactAmounts must include everyone in the split; sum must equal total. (b) percentage — percentageAmounts sum 100. (c) shares — sharesAmounts must include everyone. (d) exclude — excluded list. (e) even — default.
• participants: Others only — never include current user. "Split between A, B, C" when current user is A → participants:[B,C]. "with X" → [X]. "everyone" or payer-only → [].
• exactAmounts: Must include current user when message says "I had X", "my X was N", or "rest between me and X". Use current user name from the prompt so sum = total.
• sharesAmounts: Must include current user when message says "I took N shares". Use current user name so every person in the split has an entry.
• payer: Only from member list. Omit for "I paid" or if name not in list.

--- OUTCOME CONTRACT (anything else corrupts balances) ---
• Confident parse → parseConfidence: "confident". Full valid expense; no flags; amount > 0. Never confident when amount missing, when participants inferred from history ("same as usual"), or when anything is inferred from history.
• Constrained parse → parseConfidence: "constrained". Intent clear but something missing/ambiguous. Set constraintFlags: amountUnresolved, participantsUnknown, participantWeightsAmbiguous, distributionDeferred (or pendingSettlement), advanceNotDistributed, participantsInferredFromHistory (never then confident), multiIntent (one sentence = multiple expenses), settlementNotExpense (repaying debt only), settlementsRecordedSeparately, selfOnly, balanceSmoothingNote. Use notes[] for non-actionable text (e.g. "Excludes leftovers from previous day"). Write partial/flagged entry.
• Reject → parseConfidence: "reject", needsClarification: true. Do NOT set clarificationQuestion. Optional rejectReason e.g. "futureIntentNotRecordable". Reject when: no amount and ledger mutation implied; no participants and no rule; future intent ("I'll take care of mine next time") → rejectReason futureIntentNotRecordable; message is settlement-only with no expense. Never allow future intent into accounting.

--- CRITICAL RULES ---
• One sentence ≠ one expense. If the message describes two or more distinct expenses (e.g. "Sam paid for the hotel, I booked the cab"), emit multiple intents: use constrained + constraintFlags ["multiIntent"] and describe both (e.g. in notes or two expense objects if schema supports). Do not collapse into one generic expense.
• Settlement vs expense: "to clear what I owed" / repaying a debt = settlement only. Do NOT create an expense; use constrained + settlementNotExpense (or reject). Expense + "already paid back" = record expense; settlements are separate ledger events; use settlementsRecordedSeparately.
• History-based ("same as usual people", "usual people") → always constrained, constraintFlags ["participantsInferredFromHistory"]. Never confident. Set payer to current user when "I paid".
• Future intent ("I'll take care of mine next time") → reject, rejectReason "futureIntentNotRecordable". No ledger entry.
--- WHEN UNCLEAR ---
If you can still record a constrained partial (e.g. payer known, amount missing → amountUnresolved), use "constrained" and constraintFlags. If impossible to infer safely, use "reject"; never ask a question.

--- EDGE CASES ---
Unmatched name → use as written or best guess. Ambiguous amount → use main total or amountUnresolved. Reject when no amount and debt/ledger mutation implied. Output valid JSON: double-quoted keys/strings, no trailing commas.

--- COMMON MISTAKES (wrong → right) ---
"X paid 200" no "with Y" → RIGHT: participants:[], payer:X. "200 with X" / "dinner 300 with B" → RIGHT: participants:[X] or [B]. "Split between A, B, C" with current user A → RIGHT: participants:[B,C]. "I had 800, B 200" total 1000 → RIGHT: exactAmounts {"A":800,"B":200}, sum=1000. "I paid" → RIGHT: payer = current user name. Participants unknown (e.g. "dinner 3600, drinks separate", who shares unclear) → RIGHT: splitType "unresolved", constraintFlags ["participantsUnknown"]; never even + participants:[]. "Same as usual people" → RIGHT: constrained, participantsInferredFromHistory; never confident. "Sam paid hotel, I booked cab" → RIGHT: two intents (multiIntent); do not collapse to one expense. "Clear what I owed" → RIGHT: settlement only; constraintFlags ["settlementNotExpense"]; no expense. "I'll take care of mine next time" → RIGHT: reject, rejectReason "futureIntentNotRecordable". Unclear who shares → constrained + participantsUnknown or reject; do not ask a question.

--- EXAMPLES ---
${recentExamples.isNotEmpty ? recentExamples.map((e) => '"${e.input.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}" -> ${e.json}').join('\n') : '"Dinner 500" -> {"parseConfidence":"confident","amount":500,"description":"Dinner","category":"Food","splitType":"even","participants":[]}\n"B paid 200" -> {"parseConfidence":"confident","amount":200,"description":"Expense","category":"","splitType":"even","participants":[],"payer":"B"}\n"600 with B" -> {"parseConfidence":"confident","amount":600,"description":"Expense","category":"","splitType":"even","participants":["B"]}'}

--- OUTCOME EXAMPLES ---
Confident (full valid): {"parseConfidence":"confident","amount":500,"description":"Dinner","category":"Food","splitType":"even","participants":[],"payer":"Rishi"}
Constrained (participants unknown): {"parseConfidence":"constrained","amount":3600,"description":"Dinner","category":"Food","splitType":"unresolved","participants":[],"constraintFlags":["participantsUnknown"]}
Constrained (amount unknown): {"parseConfidence":"constrained","amount":0,"description":"Tickets","category":"","splitType":"even","participants":[],"payer":"B","constraintFlags":["amountUnresolved"],"needsClarification":true}
Reject (future intent): {"parseConfidence":"reject","amount":0,"description":"","category":"","splitType":"even","participants":[],"needsClarification":true,"rejectReason":"futureIntentNotRecordable"}

Output only the single JSON object. Double-quoted keys and strings. Names from member list only.''';
}

String? _validateResult(ParsedExpenseResult result) {
  if (result.amount.isNaN || result.amount.isInfinite) return 'Amount must be a valid number.';
  if (result.parseConfidence == 'confident' && result.amount <= 0) return 'Amount must be greater than 0.';
  if (result.parseConfidence == 'confident' && result.splitType == 'unresolved') return 'Confident parse cannot have splitType unresolved.';
  return null;
}

String _extractJson(String raw) {
  raw = raw.trim();
  final codeBlockMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false).firstMatch(raw);
  if (codeBlockMatch != null) raw = codeBlockMatch.group(1)?.trim() ?? raw;
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start != -1 && end != -1 && end > start) raw = raw.substring(start, end + 1);
  return raw.trim();
}

String _fixCommonJsonIssues(String raw) {
  return raw.replaceAll(RegExp(r',(\s*[}\]])'), r'$1');
}

Map<String, dynamic>? _tryDecodeJson(String raw) {
  try {
    final value = jsonDecode(raw);
    if (value is Map<String, dynamic>) return value;
  } catch (_) {}
  final normalized = raw
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

Future<void> _throttleForRateLimit() async {
  final file = File(_lastRequestStampPath);
  if (!file.existsSync()) return;
  final line = file.readAsStringSync().trim();
  final lastMs = int.tryParse(line);
  if (lastMs == null) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  final elapsed = (now - lastMs) / 1000;
  if (elapsed < _minIntervalSeconds) {
    final wait = (_minIntervalSeconds - elapsed).ceil();
    if (wait > 0) {
      stdout.writeln('Rate limit $_rateLimitTpm TPM: waiting ${wait}s...');
      await Future<void>.delayed(Duration(seconds: wait));
    }
  }
}

void _markRequestDone() {
  try {
    File(_lastRequestStampPath).writeAsStringSync(DateTime.now().millisecondsSinceEpoch.toString());
  } catch (_) {}
}

int _retryAfterSeconds(http.Response response) {
  final v = response.headers['retry-after']?.trim();
  if (v == null || v.isEmpty) return 2;
  final s = int.tryParse(v);
  if (s == null || s < 1) return 2;
  if (s > 60) return 60;
  return s;
}

Future<http.Response> _post(String apiKey, Map<String, dynamic> body) {
  return http.post(
    Uri.parse(_baseUrl),
    headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
}

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
  final bool needsClarification;
  final String? clarificationQuestion;
  final String parseConfidence;
  final List<String> constraintFlags;
  final List<String> notes;
  final String? rejectReason;

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
    this.needsClarification = false,
    this.clarificationQuestion,
    this.parseConfidence = 'confident',
    List<String>? constraintFlags,
    List<String>? notes,
    this.rejectReason,
  })  : participantNames = participantNames ?? [],
        constraintFlags = constraintFlags ?? [],
        excludedNames = excludedNames ?? [],
        exactAmountsByName = exactAmountsByName ?? {},
        percentageByName = percentageByName ?? {},
        sharesByName = sharesByName ?? {},
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
        if (p != null && p.toString().trim().isNotEmpty) names.add(p.toString().trim());
      }
    } else if (parts != null && parts.toString().trim().isNotEmpty) {
      names.add(parts.toString().trim());
    }
    final payer = (json['payer'] as String?)?.trim();
    final excluded = json['excluded'];
    List<String> excludedList = [];
    if (excluded is List) {
      for (final e in excluded) {
        if (e != null && e.toString().trim().isNotEmpty) excludedList.add(e.toString().trim());
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
    final needClar = json['needsClarification'] == true;
    final q = (json['clarificationQuestion'] as String?)?.trim();
    final confidence = (json['parseConfidence'] as String?)?.trim().toLowerCase();
    final pc = confidence == 'reject' ? 'reject' : confidence == 'constrained' ? 'constrained' : 'confident';
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
    final rejectReason = (json['rejectReason'] as String?)?.trim();
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
      needsClarification: needClar,
      clarificationQuestion: (needClar && q != null && q.isNotEmpty) ? q : null,
      parseConfidence: pc,
      constraintFlags: flags,
      notes: notesList.isNotEmpty ? notesList : null,
      rejectReason: rejectReason != null && rejectReason.isNotEmpty ? rejectReason : null,
    );
  }
}
