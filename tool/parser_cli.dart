// CLI for testing the expense parser. Uses GROQTRIAL_API_KEY from .env.
// Iterate on this CLI until perfect; do not touch the app parser (groq_expense_parser_service.dart) until then.
// Includes "curious student" behavior: when unclear, output needsClarification + clarificationQuestion instead of guessing.
// Records each run to tool/parser_runs.log (input + raw JSON + parsed params) for debugging splits.
// Prompt size is capped (e.g. _maxRecentExamples) to avoid Groq rate limits on single-request tokens.
// Run: dart tool/parser_cli.dart "Dinner 500"
//      dart tool/parser_cli.dart "my food 400 alex 200" "Rishi, Prasi, Alex" "Rishi"
// Batch (stress cases, rate-limited): dart tool/parser_cli.dart --stress [file]
//      Default file: tool/parser_stress_inputs.txt

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
const _model = 'llama-3.3-70b-versatile';
const _logPath = 'tool/parser_runs.log';
const _rateLimitTpm = 12000;
const _minIntervalSeconds = 4;
const _maxRecentExamples = 5;

const _lastRequestStampPath = 'tool/.parser_last_request';
const _stressInputsPath = 'tool/parser_stress_inputs.txt';

void main(List<String> args) async {
  final env = _loadEnv();
  final apiKey = env['GROQTRIAL_API_KEY']?.trim();
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Set GROQTRIAL_API_KEY in .env');
    exit(1);
  }

  if (args.isNotEmpty && args[0] == '--stress') {
    await _runBatch(apiKey, args.length > 1 ? args[1] : _stressInputsPath);
    return;
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

  final run = await _runOne(apiKey, userInput, memberListStr, currentUser);
  if (run.error != null) {
    stderr.writeln(run.error!);
    exit(1);
  }
  final result = run.result!;
  stdout.writeln('Raw JSON from API:');
  stdout.writeln(run.rawJson ?? '');
  stdout.writeln('---');
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
  buf.writeln(ts);
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

Future<void> _runBatch(String apiKey, String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('File not found: $path');
    exit(1);
  }
  final lines = file
      .readAsStringSync()
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  const memberListStr = 'Rishi, Prasi, Alex, Sam, Jordan';
  const currentUser = 'Rishi';
  var rateLimited = 0;
  stdout.writeln('Stress run: ${lines.length} inputs from $path (${_minIntervalSeconds}s between requests)');
  stdout.writeln('---');
  for (var i = 0; i < lines.length; i++) {
    final input = lines[i];
    final preview = input.length > 55 ? '${input.substring(0, 55)}...' : input;
    final run = await _runOne(apiKey, input, memberListStr, currentUser);
    if (run.error == '429 rate limit') {
      rateLimited++;
      stdout.writeln('[${i + 1}/${lines.length}] $preview ... rate-limited');
    } else {
      final status = run.error != null ? 'ERROR: ${run.error}' : (run.result!.parseConfidence == 'reject' ? 'REJECT' : run.result!.parseConfidence == 'constrained' ? 'CONSTRAINED' : 'CONFIDENT');
      stdout.writeln('[${i + 1}/${lines.length}] $preview ... $status');
    }
  }
  stdout.writeln('Done. ${rateLimited > 0 ? '$rateLimited rate-limited. ' : ''}Runs recorded to $_logPath');
}

Future<({ParsedExpenseResult? result, String? rawJson, String? error})> _runOne(
  String apiKey,
  String userInput,
  String memberListStr,
  String? currentUser,
) async {
  final memberList = ' $memberListStr';
  final recentExamples = _loadRecentExamplesFromLog(_maxRecentExamples);
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
  while (response.statusCode == 429 || response.statusCode >= 500) {
    stderr.writeln('Transient error (HTTP ${response.statusCode}). Waiting to retry...');
    final waitSeconds = _retryAfterSeconds(response);
    await Future<void>.delayed(Duration(seconds: waitSeconds));
    response = await _post(apiKey, body);
    _markRequestDone();
  }
  if (response.statusCode != 200) {
    if (response.statusCode != 429) {
      _recordRun(userInput: userInput, members: memberListStr, rawJson: null, result: null, error: 'API ${response.statusCode}');
    }
    return (result: null, rawJson: null, error: response.statusCode == 429 ? '429 rate limit' : 'API ${response.statusCode}');
  }
  final map = jsonDecode(response.body) as Map<String, dynamic>?;
  if (map == null) {
    _recordRun(userInput: userInput, members: memberListStr, rawJson: null, result: null, error: 'Invalid API response');
    return (result: null, rawJson: null, error: 'Invalid API response');
  }
  final choices = map['choices'] as List?;
  final first = choices?.isNotEmpty == true ? choices!.first : null;
  final message = first is Map<String, dynamic> ? first['message'] : null;
  final content = message is Map<String, dynamic> ? message['content'] : null;
  String raw = (content is String) ? content.trim() : '';
  if (raw.isEmpty) {
    _recordRun(userInput: userInput, members: memberListStr, rawJson: null, result: null, error: 'Empty content from API');
    return (result: null, rawJson: null, error: 'Empty content from API');
  }
  raw = raw.replaceAll('\uFEFF', '');
  raw = _extractJson(raw);
  raw = _fixCommonJsonIssues(raw);
  final decoded = _tryDecodeJson(raw);
  if (decoded == null) {
    _recordRun(userInput: userInput, members: memberListStr, rawJson: raw, result: null, error: 'Failed to decode JSON');
    return (result: null, rawJson: raw, error: 'Failed to decode JSON');
  }
  ParsedExpenseResult result;
  try {
    result = ParsedExpenseResult.fromJson(decoded);
  } catch (e) {
    _recordRun(userInput: userInput, members: memberListStr, rawJson: null, result: null, error: 'fromJson: $e');
    return (result: null, rawJson: null, error: 'fromJson: $e');
  }
  final validationError = _validateResult(result);
  if (validationError != null) {
    _recordRun(userInput: userInput, members: memberListStr, rawJson: raw, result: result, error: 'Validation: $validationError');
    return (result: result, rawJson: raw, error: validationError);
  }
  final gap = result.parseConfidence == 'confident' ? _findGap(result) : null;
  if (gap != null) {
    _recordRun(userInput: userInput, members: memberListStr, rawJson: raw, result: result, error: 'GAP: $gap');
    return (result: result, rawJson: raw, error: gap);
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
  return (result: result, rawJson: raw, error: null);
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
  final currentUser = currentUserName ?? '(not set)';
  return '''
You are a high-precision financial parsing engine. Convert the user's message into exactly ONE JSON expense object. 

--- CORE ACCOUNTING RULES ---
1. PAYER: If "I" paid/covered, payer = "$currentUser". If no payer is mentioned, DEFAULT to "$currentUser". ONLY use other names if the text explicitly states they paid.
2. TOTAL SUM CONSISTENCY: The sum of all individual shares (exact/percentage/shares) MUST equal the total amount. 
3. THE REMAINDER RULE: If the user specifies an amount for only one person (e.g., "Dinner 3000, Sam's dessert was 400"), you MUST:
   - Assign the specific amount (400) to that person.
   - Divide the remaining balance (2600) equally among EVERYONE in the group (including the specific person and the payer).
   - Add their equal share to their specific amount.
4. PARTICIPANTS: 
   - "Everyone", "Usual gang", "The group" = All members in the list.
   - If "everyone except X", include all members MINUS X.
   - participants[] should ONLY contain names OTHER than the payer.

--- OUTPUT SCHEMA ---
{
  "parseConfidence": "confident" | "constrained" | "reject",
  "amount": number,
  "description": string,
  "category": "Food"|"Transport"|"Utilities"|"Entertainment"|"Groceries"|"",
  "splitType": "even"|"exact"|"exclude"|"percentage"|"shares"|"unresolved",
  "participants": string[],
  "payer": string,
  "exactAmounts": { "Name": number },
  "constraintFlags": string[],
  "notes": string[]
}

--- MEMBER LIST ---
$memberList
Current user: $currentUser

--- CONFIDENCE CRITERIA ---
- CONSTRAINED if you have to guess participants ("some of us") or if "history" is mentioned.
- REJECT only if there is no amount AND no way to imply one.

${recentExamples.isNotEmpty ? '--- RECENT EXAMPLES ---\n${recentExamples.map((e) => '"${e.input}" -> ${e.json}').join('\n')}\n\n' : ''}
Return ONLY JSON.''';
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
      stderr.writeln('Rate limit $_rateLimitTpm TPM: waiting ${wait}s...');
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
