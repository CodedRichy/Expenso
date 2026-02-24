import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import '../models/models.dart';
import '../repositories/cycle_repository.dart';

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

  static const List<Map<String, String>> _countryCodes = [
    {'code': '+91', 'country': 'IN', 'name': 'India'},
    {'code': '+1', 'country': 'US', 'name': 'United States'},
    {'code': '+44', 'country': 'GB', 'name': 'United Kingdom'},
    {'code': '+971', 'country': 'AE', 'name': 'UAE'},
    {'code': '+65', 'country': 'SG', 'name': 'Singapore'},
    {'code': '+61', 'country': 'AU', 'name': 'Australia'},
    {'code': '+49', 'country': 'DE', 'name': 'Germany'},
    {'code': '+33', 'country': 'FR', 'name': 'France'},
    {'code': '+81', 'country': 'JP', 'name': 'Japan'},
    {'code': '+86', 'country': 'CN', 'name': 'China'},
    {'code': '+82', 'country': 'KR', 'name': 'South Korea'},
    {'code': '+55', 'country': 'BR', 'name': 'Brazil'},
    {'code': '+52', 'country': 'MX', 'name': 'Mexico'},
    {'code': '+7', 'country': 'RU', 'name': 'Russia'},
    {'code': '+27', 'country': 'ZA', 'name': 'South Africa'},
  ];

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
    
    final formattedPhone = '$_selectedCountryCode$normalized';
    final group = ModalRoute.of(context)?.settings.arguments as Group?;
    if (group != null) {
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
    final group = ModalRoute.of(context)?.settings.arguments as Group?;
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
    final formattedPhone = '$_selectedCountryCode$phone';
    final group = ModalRoute.of(context)?.settings.arguments as Group?;
    if (group != null) {
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
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final Group? groupArg = routeArgs is Group ? routeArgs : null;
    final String displayGroupName = groupArg?.name ?? (routeArgs is String ? routeArgs : widget.groupName);
    final repo = CycleRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final listMembers = groupArg != null ? repo.getMembersForGroup(groupArg.id) : <Member>[];
        final existingPhones = <String>{};
        for (final m in listMembers) {
          existingPhones.add(_normalizePhone(m.phone));
        }
        if (groupArg != null) {
          for (final id in groupArg.memberIds) {
            if (id.startsWith('p_')) existingPhones.add(_normalizePhone(id.substring(2)));
          }
        }
        final filteredContacts = _getFilteredContacts(existingPhones);
        return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
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
                    color: const Color(0xFF1A1A1A),
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
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Invite members',
                    style: TextStyle(
                      fontSize: 17,
                      color: const Color(0xFF6B6B6B),
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
                      color: const Color(0xFF9B9B9B),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: handleCopyLink,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE5E5E5)),
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
                                color: const Color(0xFF6B6B6B),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                linkCopied ? 'Link copied' : 'Copy invite link',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            linkCopied ? Icons.check : Icons.content_copy,
                            size: 20,
                            color: linkCopied ? const Color(0xFF1A1A1A) : const Color(0xFF6B6B6B),
                          ),
                        ],
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
                      color: const Color(0xFF9B9B9B),
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
                      hintStyle: TextStyle(color: const Color(0xFFB0B0B0)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF1A1A1A)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: TextStyle(fontSize: 17, color: const Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 12),
                  if (!_contactsPermissionGranted && _contactsPermissionChecked) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Contacts access was denied. You can still add members by entering a number below.',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF6B6B6B),
                          height: 1.4,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextButton.icon(
                        onPressed: _requestContactsAndLoad,
                        icon: Icon(Icons.contacts_outlined, size: 18, color: const Color(0xFF5B7C99)),
                        label: Text(
                          'Access Contacts',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF5B7C99),
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
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: PopupMenuButton<String>(
                          onSelected: (code) => setState(() => _selectedCountryCode = code),
                          offset: const Offset(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          itemBuilder: (context) => _countryCodes.map((c) => PopupMenuItem<String>(
                            value: c['code'],
                            child: Text(
                              '${c['code']} ${c['country']}',
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
                                  style: const TextStyle(fontSize: 17, color: Color(0xFF1A1A1A)),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF6B6B6B)),
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
                              color: const Color(0xFFB0B0B0),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF1A1A1A)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          style: TextStyle(
                            fontSize: 17,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: phone.length == 10 ? handleAddMember : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A1A),
                          disabledBackgroundColor: const Color(0xFFE5E5E5),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: const Color(0xFFB0B0B0),
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
                    ],
                  ),
                  if (_contactsPermissionGranted && !_contactSuggestionsDismissed) ...[
                    const SizedBox(height: 16),
                    Text(
                      'FROM YOUR CONTACTS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9B9B9B),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE5E5E5)),
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
                                  color: const Color(0xFF6B6B6B),
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
                                            ? const BorderSide(color: Color(0xFFE5E5E5), width: 1)
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
                                                  color: const Color(0xFF1A1A1A),
                                                ),
                                              ),
                                              if (phoneDisplay.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  phoneDisplay,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: const Color(0xFF6B6B6B),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.person_add_outlined,
                                          size: 20,
                                          color: const Color(0xFF9B9B9B),
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
                      color: const Color(0xFFE5E5E5),
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
                          color: const Color(0xFF9B9B9B),
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
                                    ? const BorderSide(color: Color(0xFFE5E5E5), width: 1)
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
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                                if (member.name.isNotEmpty)
                                  Text(
                                    member.phone,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: const Color(0xFF6B6B6B),
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
                color: const Color(0xFFF7F7F8),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFFE5E5E5),
                    width: 1,
                  ),
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  if (groupArg != null) {
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
                  } else {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
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
