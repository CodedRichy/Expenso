import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';

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
  bool linkCopied = false;
  List<Member> members = [
    Member(id: '1', phone: '+91 98765 43210', status: 'joined'),
    Member(id: '2', phone: '+91 87654 32109', status: 'invited'),
  ];

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
    if (phone.length == 10) {
      setState(() {
        members.add(
          Member(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            phone: '+91 ${phone.substring(0, 5)} ${phone.substring(5)}',
            status: 'invited',
          ),
        );
        phone = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get group name from route arguments or use the widget's groupName
    final routeGroupName = ModalRoute.of(context)?.settings.arguments as String?;
    final displayGroupName = routeGroupName ?? widget.groupName;
    
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
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          onChanged: (value) {
                            setState(() {
                              phone = value;
                            });
                          },
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
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final isJoined = member.status == 'joined';
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
                                  member.phone,
                                  style: TextStyle(
                                    fontSize: 17,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                                Text(
                                  isJoined ? 'Joined' : 'Invited',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isJoined ? const Color(0xFF1A1A1A) : const Color(0xFF6B6B6B),
                                    fontWeight: isJoined ? FontWeight.w500 : FontWeight.w400,
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
                  // Create a new group with the entered data
                  final newGroup = Group(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: displayGroupName,
                    status: 'open',
                    amount: 0,
                    statusLine: 'No expenses yet',
                  );
                  Navigator.pushReplacementNamed(
                    context,
                    '/group-detail',
                    arguments: newGroup,
                  );
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
  }
}
