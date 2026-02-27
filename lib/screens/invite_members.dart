import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import '../country_codes.dart';
import '../models/models.dart';
import '../repositories/cycle_repository.dart';
import '../services/connectivity_service.dart';
import '../utils/route_args.dart';
import '../widgets/gradient_scaffold.dart';

class InviteMembers extends StatefulWidget {
  final String groupName;

  const InviteMembers({
    super.key,
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
    final groupArg = RouteArgs.getGroup(context);
    if (groupArg == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
      return const Scaffold(body: SizedBox.shrink());
    }
    final displayGroupName = groupArg.name;
    final repo = CycleRepository.instance;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.chevron_left, size: 24),
                    color: theme.colorScheme.onSurface,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    displayGroupName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Invite members',
                    style: TextStyle(
                      fontSize: 17,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SHARE LINK',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    label: linkCopied ? 'Link copied' : 'Copy invite link',
                    button: true,
                    child: InkWell(
                    onTap: handleCopyLink,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
                        border: Border.all(color: theme.dividerColor),
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
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                linkCopied ? 'Link copied' : 'Copy invite link',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            linkCopied ? Icons.check : Icons.content_copy,
                            size: 20,
                            color: linkCopied ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ADD BY PHONE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => setState(() {
                      name = value;
                      _contactSuggestionsDismissed = false;
                    }),
                    decoration: InputDecoration(
                      hintText: 'Name (optional)',
                      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      filled: true,
                      fillColor: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.colorScheme.onSurface),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: TextStyle(fontSize: 17, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 12),
                  if (!_contactsPermissionGranted && _contactsPermissionChecked) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Contacts access was denied. You can still add members by entering a number below.',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextButton.icon(
                        onPressed: _requestContactsAndLoad,
                        icon: Icon(Icons.contacts_outlined, size: 18, color: theme.colorScheme.primary),
                        label: Text(
                          'Access Contacts',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: PopupMenuButton<String>(
                          onSelected: (code) => setState(() => _selectedCountryCode = code),
                          offset: const Offset(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          itemBuilder: (context) => countryCodesWithCurrency.map((c) => PopupMenuItem<String>(
                            value: c.dialCode,
                            child: Text(
                              '${c.dialCode} ${c.countryCode}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          )).toList(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _selectedCountryCode,
                                  style: TextStyle(fontSize: 17, color: theme.colorScheme.onSurface),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down, size: 20, color: theme.colorScheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
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
                          decoration: InputDecoration(
                            hintText: 'Phone number',
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            filled: true,
                            fillColor: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: theme.dividerColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: theme.dividerColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: theme.colorScheme.onSurface),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          style: TextStyle(
                            fontSize: 17,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        label: 'Add member by phone',
                        button: true,
                        child: ElevatedButton(
                        onPressed: phone.length == 10 ? handleAddMember : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      ),
                    ],
                  ),
                  if (_contactsPermissionGranted && !_contactSuggestionsDismissed) ...[
                    const SizedBox(height: 16),
                    Text(
                      'FROM YOUR CONTACTS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
                        border: Border.all(color: theme.dividerColor),
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
                                style: TextStyle(
                                  fontSize: 15,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
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
                                return InkWell(
                                  onTap: () => _onContactSelected(c),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: index > 0
                                            ? BorderSide(color: theme.dividerColor, width: 1)
                                            : BorderSide.none,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c.displayName,
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w500,
                                                  color: theme.colorScheme.onSurface,
                                                ),
                                              ),
                                              if (phoneDisplay.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  phoneDisplay,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: theme.colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.person_add_outlined,
                                          size: 20,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: Text(
                        'MEMBERS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: listMembers.length,
                        itemBuilder: (context, index) {
                          final member = listMembers[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                top: index > 0
                                    ? BorderSide(color: theme.dividerColor, width: 1)
                                    : BorderSide.none,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  repo.getMemberDisplayName(member.phone),
                                  style: TextStyle(
                                    fontSize: 17,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                if (member.name.isNotEmpty)
                                  Text(
                                    member.phone,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFFF7F7F8),
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  final updatedGroup = repo.getGroup(groupArg.id);
                  if (updatedGroup != null) {
                    Navigator.pushReplacementNamed(
                      context,
                      '/group-detail',
                      arguments: updatedGroup,
                    );
                  } else {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
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
