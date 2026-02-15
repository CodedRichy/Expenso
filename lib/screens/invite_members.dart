import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
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

  final FocusNode _phoneFocusNode = FocusNode();
  bool _contactsPermissionGranted = false;
  bool _contactsPermissionChecked = false;
  List<fc.Contact> _allContacts = [];
  bool _contactSuggestionsDismissed = false;

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(_onPhoneFocusChange);
  }

  @override
  void dispose() {
    _phoneFocusNode.removeListener(_onPhoneFocusChange);
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onPhoneFocusChange() async {
    if (!_phoneFocusNode.hasFocus) return;
    if (_contactsPermissionChecked) return;
    _contactsPermissionChecked = true;
    final granted = await fc.FlutterContacts.requestPermission();
    if (!mounted) return;
    setState(() {
      _contactsPermissionGranted = granted;
      if (granted) _loadContacts();
    });
  }

  Future<void> _requestContactsAndLoad() async {
    final granted = await fc.FlutterContacts.requestPermission();
    if (!mounted) return;
    setState(() {
      _contactsPermissionGranted = granted;
      if (granted) _loadContacts();
    });
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await fc.FlutterContacts.getContacts(withProperties: true);
      if (!mounted) return;
      setState(() => _allContacts = contacts);
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  static String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) return digits.substring(digits.length - 10);
    return digits;
  }

  List<fc.Contact> get _filteredContacts {
    final nameLower = name.trim().toLowerCase();
    final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');
    if (nameLower.isEmpty && phoneDigits.isEmpty) return [];
    return _allContacts.where((c) {
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
    setState(() {
      name = displayName;
      phone = normalized;
      _contactSuggestionsDismissed = true;
    });
  }

  void handleCopyLink() {
    setState(() {
      linkCopied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          linkCopied = false;
        });
      }
    });
  }

  void handleAddMember() {
    if (phone.length != 10) return;
    final formattedPhone = '+91 ${phone.substring(0, 5)} ${phone.substring(5)}';
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
        return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
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
            // Invite Link
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
            // Add by Phone
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+91',
                          style: TextStyle(
                            fontSize: 17,
                            color: const Color(0xFF6B6B6B),
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
                  if (_contactsPermissionGranted &&
                      !_contactSuggestionsDismissed &&
                      (name.trim().isNotEmpty || phone.isNotEmpty)) ...[
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _filteredContacts.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No matching contacts',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: const Color(0xFF6B6B6B),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _filteredContacts.length,
                              itemBuilder: (context, index) {
                                final c = _filteredContacts[index];
                                final primaryPhone = c.phones.isNotEmpty
                                    ? _normalizePhone(c.phones.first.number)
                                    : '';
                                final phoneDisplay = primaryPhone.length == 10
                                    ? '+91 ${primaryPhone.substring(0, 5)} ${primaryPhone.substring(5)}'
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
            // Members List
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
            // Done Button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
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
                    }
                  } else {
                    final newGroup = Group(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: displayGroupName,
                      status: 'open',
                      amount: 0,
                      statusLine: 'No expenses yet',
                      creatorId: repo.currentUserId,
                      memberIds: [],
                    );
                    Navigator.pushReplacementNamed(
                      context,
                      '/group-detail',
                      arguments: newGroup,
                    );
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
