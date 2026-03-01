import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import '../country_codes.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/models.dart';
import '../repositories/cycle_repository.dart';
import '../services/connectivity_service.dart';
import '../utils/route_args.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/tap_scale.dart';

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

class _InviteMembersState extends State<InviteMembers> with WidgetsBindingObserver {
  String phone = '';
  String name = '';
  bool linkCopied = false;
  String _selectedCountryCode = '+91';

  final FocusNode _phoneFocusNode = FocusNode();
  bool _contactsPermissionGranted = false;
  bool _contactsPermissionChecked = false;
  bool _contactsDenialSeen = false;
  List<fc.Contact> _allContacts = [];
  bool _contactSuggestionsDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkContactsOnInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phoneFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheckContactsPermission();
  }

  Future<void> _recheckContactsPermission() async {
    final status = await Permission.contacts.status;
    if (!mounted) return;
    if (status.isGranted && !_contactsPermissionGranted) {
      setState(() {
        _contactsPermissionGranted = true;
        _contactsPermissionChecked = true;
      });
      _loadContacts();
    }
  }

  Future<void> _checkContactsOnInit() async {
    final status = await Permission.contacts.status;
    if (!mounted) return;
    setState(() {
      _contactsPermissionChecked = true;
      _contactsPermissionGranted = status.isGranted;
      if (status.isDenied || status.isPermanentlyDenied) _contactsDenialSeen = true;
      if (status.isGranted) _loadContacts();
    });
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
    } else {
      setState(() => _contactsDenialSeen = true);
      if (result.isPermanentlyDenied) await openAppSettings();
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
      if (mounted) setState(() {});
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
      for (final p in c.phones) {
        if (existingPhones.contains(_normalizePhone(p.number))) return false;
      }
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

    final group = RouteArgs.getGroup(context);
    if (group != null) {
      if (ConnectivityService.instance.isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot add member while offline'),
            behavior: SnackBarBehavior.floating,
          ),
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
    final group = RouteArgs.getGroup(context);
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
    final group = RouteArgs.getGroup(context);
    if (group != null) {
      if (ConnectivityService.instance.isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot add member while offline'),
            behavior: SnackBarBehavior.floating,
          ),
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
    if (groupArg == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
      final theme = Theme.of(context);
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Group not found',
                  style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Go back and try again.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final displayGroupName = groupArg.name;
    final repo = CycleRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final listMembers = repo.getMembersForGroup(groupArg.id);
        final existingPhones = <String>{};
        for (final m in listMembers) {
          existingPhones.add(_normalizePhone(m.phone));
        }
        for (final id in groupArg.memberIds) {
          if (id.startsWith('p_')) existingPhones.add(_normalizePhone(id.substring(2)));
        }
        final filteredContacts = _getFilteredContacts(existingPhones);
        return GradientScaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.screenPaddingH,
                    AppSpacing.screenHeaderPaddingTop,
                    AppSpacing.screenPaddingH,
                    AppSpacing.space3xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        label: 'Back',
                        button: true,
                         child: TapScale(
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.chevron_left, size: 24),
                          color: Theme.of(context).colorScheme.onSurface,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(32, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      ),
                      const SizedBox(height: 20),
                      Text(displayGroupName, style: context.screenTitle),
                      const SizedBox(height: 4),
                      Text('Invite members', style: context.bodySecondary),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SHARE LINK', style: context.sectionLabel),
                            const SizedBox(height: 12),
                            Semantics(
                              label: linkCopied ? 'Link copied' : 'Copy invite link',
                              button: true,
                              child: TapScale(
                                child: InkWell(
                                  onTap: handleCopyLink,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: context.colorSurface,
                                      border: Border.all(color: context.colorBorder),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.link,
                                              size: 20,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              linkCopied ? 'Link copied' : 'Copy invite link',
                                              style: context.bodyPrimary,
                                            ),
                                          ],
                                        ),
                                        Icon(
                                          linkCopied ? Icons.check : Icons.content_copy,
                                          size: 20,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ADD BY PHONE', style: context.sectionLabel),
                            const SizedBox(height: 12),
                            TextField(
                              onChanged: (value) => setState(() {
                                name = value;
                                _contactSuggestionsDismissed = false;
                              }),
                              decoration: InputDecoration(
                                hintText: 'Name (optional)',
                                helperText: (_contactsPermissionGranted && name.trim().isNotEmpty)
                                    ? 'Suggestions from contacts appear below'
                                    : null,
                                helperMaxLines: 1,
                              ),
                              style: context.input,
                            ),
                            const SizedBox(height: 12),
                            if (!_contactsPermissionGranted && _contactsPermissionChecked && !_contactsDenialSeen) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Contacts access was denied. You can still add members by entering a number below.',
                                style: context.bodySecondary.copyWith(height: 1.4),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _requestContactsAndLoad,
                                icon: Icon(Icons.contacts_outlined, size: 18, color: context.colorPrimary),
                                label: const Text('Access Contacts'),
                                style: TextButton.styleFrom(
                                  foregroundColor: context.colorPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 56,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: context.colorSurface,
                                      border: Border.all(color: context.colorBorderInput),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: PopupMenuButton<String>(
                                      onSelected: (code) => setState(() => _selectedCountryCode = code),
                                      offset: const Offset(0, 48),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      itemBuilder: (context) => countryCodesWithCurrency.map((c) => PopupMenuItem<String>(
                                        value: c.dialCode,
                                        child: Text(
                                          '${c.dialCode} ${c.countryCode}',
                                          style: context.input,
                                        ),
                                      )).toList(),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(_selectedCountryCode, style: context.input),
                                          const SizedBox(width: 4),
                                          Icon(Icons.arrow_drop_down, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SizedBox(
                                    height: 56,
                                    child: TextField(
                                    focusNode: _phoneFocusNode,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    onChanged: (value) => setState(() {
                                      phone = value;
                                      _contactSuggestionsDismissed = false;
                                    }),
                                    onSubmitted: (_) => handleAddMember(),
                                    decoration: const InputDecoration(
                                      hintText: 'Phone number',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                    ),
                                    style: context.input,
                                  ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Semantics(
                                  label: 'Add member by phone',
                                  button: true,
                                  child: TapScale(
                                    child: ElevatedButton(
                                      onPressed: phone.length == 10 ? handleAddMember : null,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        minimumSize: const Size(0, 56),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text('Add', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_contactsPermissionGranted && !_contactSuggestionsDismissed) ...[
                              const SizedBox(height: 16),
                              Text(
                                name.trim().isNotEmpty ? 'SUGGESTIONS FROM CONTACTS' : 'FROM YOUR CONTACTS',
                                style: context.sectionLabel,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 280),
                                decoration: BoxDecoration(
                                  color: context.colorSurface,
                                  border: Border.all(color: context.colorBorder),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: filteredContacts.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          _allContacts.isEmpty
                                              ? 'Loading contacts...'
                                              : (name.trim().isNotEmpty || phone.isNotEmpty)
                                                  ? 'No matching contacts'
                                                  : 'All contacts already added',
                                          style: context.bodySecondary,
                                        ),
                                      )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        padding: EdgeInsets.zero,
                                        itemCount: filteredContacts.length,
                                        itemBuilder: (context, index) {
                                          final c = filteredContacts[index];
                                          final primaryPhone = c.phones.isNotEmpty
                                              ? _normalizePhone(c.phones.first.number)
                                              : '';
                                          final phoneDisplay = primaryPhone.length == 10
                                              ? '$_selectedCountryCode $primaryPhone'
                                              : c.phones.isNotEmpty
                                                  ? c.phones.first.number
                                                  : '';
                                          return TapScale(
                                            scaleDown: 0.99,
                                            child: InkWell(
                                              onTap: () => _onContactSelected(c),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 20,
                                                      backgroundColor: context.colorPrimary,
                                                      child: Text(
                                                        c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '',
                                                        style: context.bodyPrimary.copyWith(color: Theme.of(context).colorScheme.onPrimary),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(c.displayName, style: context.listItemTitle),
                                                          if (phoneDisplay.isNotEmpty) ...[
                                                            const SizedBox(height: 2),
                                                            Text(phoneDisplay, style: context.bodySecondary),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                    Icon(
                                                      Icons.person_add_outlined,
                                                      size: 20,
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: context.colorBorder, width: 1)),
                  ),
                  child: Semantics(
                    label: 'Done',
                    button: true,
                    child: TapScale(
                      child: ElevatedButton(
                        onPressed: () {
                          final updatedGroup = repo.getGroup(groupArg.id);
                          if (updatedGroup != null) {
                            Navigator.pushReplacementNamed(
                              context,
                              '/group-members',
                              arguments: updatedGroup,
                            );
                          } else {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 0),
                        ),
                        child: const Text('Done', style: AppTypography.button),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
