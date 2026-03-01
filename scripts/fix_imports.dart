import 'dart:io';

void main() async {
  final dir = Directory('lib/screens');
  final files = await dir.list(recursive: true).where((e) => e.path.endsWith('.dart')).toList();
  
  for (var file in files) {
    if (file is File) {
      String content = await file.readAsString();
      bool changed = false;
      
      final tapScaleImport = "import '../widgets/tap_scale.dart';";
      if (content.contains('TapScale') && !content.contains(tapScaleImport)) {
        content = _addImport(content, tapScaleImport);
        changed = true;
      }
      
      final staggeredImport = "import '../widgets/staggered_list_item.dart';";
      if (content.contains('StaggeredListItem') && !content.contains(staggeredImport)) {
        content = _addImport(content, staggeredImport);
        changed = true;
      }
      
      final fadeInImport = "import '../widgets/fade_in.dart';";
      if (content.contains('FadeIn') && !content.contains(fadeInImport)) {
        content = _addImport(content, fadeInImport);
        changed = true;
      }
      
      if (changed) {
        await file.writeAsString(content);

      }
    }
  }
}

String _addImport(String content, String importStr) {
  final lines = content.split('\n');
  int lastImportIdx = -1;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].trimLeft().startsWith('import ')) {
      lastImportIdx = i;
    }
  }
  
  if (lastImportIdx != -1) {
    lines.insert(lastImportIdx + 1, importStr);
  } else {
    lines.insert(0, importStr);
  }
  return lines.join('\n');
}
