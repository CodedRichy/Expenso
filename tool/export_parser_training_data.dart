// Exports successful runs from parser_runs.log to JSONL for fine-tuning.
// Run: dart tool/export_parser_training_data.dart
// Output: tool/parser_training_data.jsonl (one {"input":"...","output":"..."} per line).

import 'dart:convert';
import 'dart:io';

const _logPath = 'tool/parser_runs.log';
const _outPath = 'tool/parser_training_data.jsonl';

void main() {
  final file = File(_logPath);
  if (!file.existsSync()) {
    stderr.writeln('$_logPath not found.');
    exit(1);
  }
  final content = file.readAsStringSync();
  final blocks = content.split(RegExp(r'\n---\n'));
  final examples = <Map<String, String>>[];
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
      examples.add({'input': input, 'output': rawJson});
    }
  }
  final deduped = <String, Map<String, String>>{};
  for (final e in examples) {
    deduped[e['input']!] = e;
  }
  final list = deduped.values.toList();
  final out = File(_outPath);
  out.writeAsStringSync(
    list.map((e) => jsonEncode(e)).join('\n') + (list.isEmpty ? '' : '\n'),
  );
  stdout.writeln('Exported ${list.length} examples to $_outPath');
}
