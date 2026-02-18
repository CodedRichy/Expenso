// Run: dart tool/groq_debug.dart "Dinner 500" — paste output to fix parser.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

void main(List<String> args) async {
  final env = _loadEnv();
  final apiKey = env['GROQ_API_KEY']?.trim();
  if (apiKey == null || apiKey.isEmpty) {
    stdout.writeln('Set GROQ_API_KEY in .env');
    exit(1);
  }
  final input = args.isEmpty ? 'Dinner 500' : args.join(' ');
  final memberList = ' Prasid, Rishi';

  final systemPrompt = '''
You extract expense details from any casual user message and reply with ONLY one valid JSON object. No other text, no markdown, no explanation.

Output format (double quotes for keys and strings; amount as number; no trailing commas):
{"amount":<number>,"description":"<what was bought>","category":"<Food|Transport|etc>","splitType":"even","participants":["<name>",...]}

Member list for names:$memberList
- Match partial names to this list. If no one else mentioned, participants: [].
- amount: always extract the money number. description: short phrase. category: infer. splitType: "even".
- Reply with nothing except the single JSON object. Use double-quoted keys and strings only.''';

  final res = await http.post(
    Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
    headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
    body: jsonEncode({
      'model': 'llama-3.3-70b-versatile',
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': input},
      ],
      'temperature': 0.1,
      'max_tokens': 256,
    }),
  );

  stdout.writeln('Status: ${res.statusCode}\n');
  if (res.statusCode != 200) {
    stdout.writeln(res.body);
    return;
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>?;
  final choices = map?['choices'];
  final bool hasContent = choices is List && choices.isNotEmpty;
  Object? content;
  if (hasContent) {
    final first = choices[0];
    final message = (first is Map<String, dynamic>) ? first['message'] : null;
    content = (message is Map<String, dynamic>) ? message['content'] : null;
  }
  final String raw = (content is String) ? content.trim() : '';
  stdout.writeln('--- Raw content from Groq (this is what we try to parse) ---');
  stdout.writeln(raw);
  stdout.writeln('--- End ---');
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
