import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import '../country_codes.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/models.dart';
import '../repositories/cycle_repository.dart';
import '../services/connectivity_service.dart';
import '../utils/route_args.dart';
import '../widgets/gradient_scaffold.dart';

class InviteMembers extends StatefulWidget {
  final Group? group;
  final String groupName;

  const InviteMembers({
    super.key,
    this.group,
    this.groupName = 'Group Name',
  });

  @override
  State<InviteMembers> createState() => _InviteMembersState();
}

class _InviteMembersState extends State<InviteMembers> {
  String phone = '';
  String name = '';
  bool linkCopied = false;
  String _selectedCountryCode = '+91';

  final FocusNode _phoneFocusNode = FocusNode();
  bool _contactsPermissionGranted = false;
  bool _contactsPermissionChecked = false;
  List<fc.Contact> _allContacts = [];
  bool _contactSuggestionsDismissed = false;

  @override
  void initState() {
    super.initState();
    _requestContactsOnInit();
  }

  Future<void> _requestContactsOnInit() async {
    final granted = await fc.FlutterContacts.requestPermission();
    if (!mounted) return;
    _contactsPermissionChecked = true;
    setState(() {
      _contactsPermissionGranted = granted;
      if (granted) _loadContacts();
    });
  }

  @override
  void dispose() {
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _requestContactsAndLoad() async {
    final status = await Permission.contacts.status;
    if (status.isGranted) {
      setState(() {
        _contactsPermissionGranted = true;
        _loadContacts();
      });
      return;
    }
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    final result = await Permission.contacts.request();
    if (!mounted) return;
    if (result.isGranted) {
      setState(() {
        _contactsPermissionGranted = true;
        _loadContacts();
      });
    } else if (result.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await fc.FlutterContacts.getContacts(withProperties: true);
      if (!mounted) return;
      setState(() => _allContacts = contacts);
    } catch (e, st) {
      debugPrint('InviteMembers._loadContacts failed: $e');
      if (kDebugMode) debugPrint(st.toString());
    }
  }

  static String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) return digits.substring(digits.length - 10);
    return digits;
  }

  List<fc.Contact> _getFilteredContacts(Set<String> existingPhones) {
    final nameLower = name.trim().toLowerCase();
    final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');

    return _allContacts.where((c) {
      if (c.phones.isEmpty) return false;
      bool alreadyInGroup = false;
      for (final p in c.phones) {
        if (existingPhones.contains(_normalizePhone(p.number))) {
          alreadyInGroup = true;
          break;
        }
      }
      if (alreadyInGroup) return false;
      if (nameLower.isEmpty && phoneDigits.isEmpty) return true;
      if (nameLower.isNotEmpty && c.displayName.toLowerCase().contains(nameLower)) return true;
      for (final p in c.phones) {
        final numDigits = p.number.replaceAll(RegExp(r'\D'), '');
        if (phoneDigits.isNotEmpty && (numDigits.contains(phoneDigits) || phoneDigits.contains(numDigits))) return true;
      }
      return false;
    }).toList();
  }

  void _onContactSelected(fc.Contact contact) {
    final displayName = contact.displayName.trim();
    String normalized = '';
    if (contact.phones.isNotEmpty) {
      normalized = _normalizePhone(contact.phones.first.number);
    }
    if (normalized.length != 10) return;

    final group = widget.group ?? RouteArgs.getGroup(context);
    if (group != null) {
      if (ConnectivityService.instance.isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot add member while offline'), behavior: SnackBarBehavior.floating),
        );
        return;
      }
      final formattedPhone = '$_selectedCountryCode$normalized';
      final member = Member(
        id: 'm_${DateTime.now().millisecondsSinceEpoch}',
        name: displayName,
        phone: formattedPhone,
      );
      CycleRepository.instance.addMemberToGroup(group.id, member);
    }
    setState(() {
      name = '';
      phone = '';
    });
  }

  Future<void> handleCopyLink() async {
    final group = widget.group ?? RouteArgs.getGroup(context);
    if (group == null) return;
    final link = 'expenso://join/${group.id}';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    setState(() => linkCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => linkCopied = false);
    });
  }

  void handleAddMember() {
    if (phone.length != 10) return;
    final group = widget.group ?? RouteArgs.getGroup(context);
    if (group != null) {
      if (ConnectivityService.instance.isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot add member while offline'), behavior: SnackBarBehavior.floating),
        );
        return;
      }
      final formattedPhone = '$_selectedCountryCode$phone';
      final member = Member(
        id: 'm_${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim(),
        phone: formattedPhone,
      );
      CycleRepository.instance.addMemberToGroup(group.id, member);
    }
    setState(() {
      phone = '';
      name = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupArg = widget.group ?? RouteArgs.getGroup(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (groupArg == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Group not found'),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Go back')),
            ],
          ),
        ),
      );
    }

    final repo = CycleRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final listMembers = repo.getMembersForGroup(groupArg.id);
        final existingPhones = <String>{};
        for (final m in listMembers) {
          existingPhones.add(_normalizePhone(m.phone));
        }
        final filteredContacts = _getFilteredContacts(existingPhones);

        return GradientScaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: constraints.maxHeight,
                  child: Column(
                    children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.chevron_left),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      const SizedBox(height: 12),
                      Text(groupArg.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      Text('Invite members', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                // Main Input Section
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('SHARE LINK'),
                        _buildLinkCard(isDark, theme),
                        const SizedBox(height: 24),
                        _sectionTitle('ADD BY PHONE'),
                        const SizedBox(height: 12),
                        _buildNameField(isDark, theme),
                        const SizedBox(height: 12),
                        _buildPhoneInputRow(isDark, theme),
                        if (_contactsPermissionGranted && !_contactSuggestionsDismissed) ...[
                          const SizedBox(height: 16),
                          _sectionTitle(name.isEmpty ? 'FROM CONTACTS' : 'SUGGESTIONS'),
                          const SizedBox(height: 12),
                          _buildSuggestionsList(filteredContacts, isDark, theme),
                        ],
                        const SizedBox(height: 24),
                        _sectionTitle('MEMBERS'),
                        _buildMembersList(listMembers, repo, theme),
                        SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
                      ],
                    ),
                  ),
                ),
                // Bottom Button
                _buildDoneButton(isDark, theme, repo, groupArg),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1));
  }

  Widget _buildLinkCard(bool isDark, ThemeData theme) {
    return InkWell(
      onTap: handleCopyLink,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.link, size: 20),
                const SizedBox(width: 12),
                Text(linkCopied ? 'Link copied' : 'Copy invite link'),
              ],
            ),
            Icon(linkCopied ? Icons.check : Icons.content_copy, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField(bool isDark, ThemeData theme) {
    return TextField(
      onChanged: (v) => setState(() => name = v),
      decoration: InputDecoration(
        hintText: 'Name (optional)',
        filled: true,
        fillColor: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildPhoneInputRow(bool isDark, ThemeData theme) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
          ),
          child: PopupMenuButton<String>(
            onSelected: (code) => setState(() => _selectedCountryCode = code),
            itemBuilder: (ctx) => countryCodesWithCurrency
                .map((c) => PopupMenuItem(value: c.dialCode, child: Text('${c.dialCode} ${c.countryCode}')))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Text(_selectedCountryCode),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            focusNode: _phoneFocusNode,
            keyboardType: TextInputType.phone,
            onChanged: (v) => setState(() => phone = v),
            decoration: InputDecoration(
              hintText: 'Phone number',
              filled: true,
              fillColor: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: phone.length == 10 ? handleAddMember : null,
          child: const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildSuggestionsList(List<fc.Contact> contacts, bool isDark, ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: contacts.isEmpty
          ? const Padding(padding: EdgeInsets.all(16), child: Text('No contacts found'))
          : ListView.separated(
              shrinkWrap: true,
              itemCount: contacts.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final c = contacts[index];
                return ListTile(
                  title: Text(c.displayName),
                  subtitle: Text(c.phones.first.number),
                  trailing: const Icon(Icons.person_add_outlined),
                  onTap: () => _onContactSelected(c),
                );
              },
            ),
    );
  }

  Widget _buildMembersList(List<Member> members, CycleRepository repo, ThemeData theme) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: members.length,
      separatorBuilder: (ctx, i) => const Divider(),
      itemBuilder: (ctx, i) {
        final m = members[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(repo.getMemberDisplayName(m.phone)),
          subtitle: Text(m.phone),
        );
      },
    );
  }

  Widget _buildDoneButton(bool isDark, ThemeData theme, CycleRepository repo, Group group) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFFF7F7F8),
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            final updated = repo.getGroup(group.id);
            Navigator.pushReplacementNamed(context, '/group-detail', arguments: updated ?? group);
          },
          child: const Text('Done'),
        ),
      ),
    );
  }
}