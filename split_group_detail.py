import os

path = r'c:\Users\rishi\Documents\GitHub\Expenso\lib\screens\groups\group_detail.dart'
new_path = r'c:\Users\rishi\Documents\GitHub\Expenso\lib\screens\groups\group_detail_smart_bar.dart'

with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Extract imports and _SmartBarSection and _ExpenseConfirmDialog
imports = []
for line in lines:
    if line.startswith('import '):
        imports.append(line)

start_idx = -1
for i, line in enumerate(lines):
    if line.startswith('class _SmartBarSection extends StatefulWidget'):
        start_idx = i
        break

if start_idx != -1:
    widgets_lines = lines[start_idx:]
    new_content = ''.join(imports + ['\n'] + widgets_lines)
    with open(new_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    # modify group_detail.dart to import the new file and replace the classes
    original_lines = lines[:start_idx]
    
    # Add the local import
    import_index = 0
    for i, line in enumerate(original_lines):
        if line.startswith('class '):
            import_index = i
            break
            
    original_lines.insert(import_index, "import 'group_detail_smart_bar.dart';\n")
    
    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(original_lines)
    
    print('Split successful!')
