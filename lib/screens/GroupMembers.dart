import 'package:flutter/material.dart';
import '../models/models.dart';

class GroupMembers extends StatelessWidget {
  final String groupName;
  final List<Member>? members;

  const GroupMembers({
    super.key,
    this.groupName = 'Weekend Trip',
    this.members,
  });

  @override
  Widget build(BuildContext context) {
    final defaultMembers = members ??
        [
          Member(id: '1', phone: '+91 98765 43210', status: 'joined'),
          Member(id: '2', phone: '+91 87654 32109', status: 'joined'),
          Member(id: '3', phone: '+91 76543 21098', status: 'invited'),
        ];

    final joinedMembers = defaultMembers.where((m) => m.status == 'joined').toList();
    final invitedMembers = defaultMembers.where((m) => m.status == 'invited').toList();

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
                    groupName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${joinedMembers.length} member${joinedMembers.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 17,
                      color: const Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ),
            ),
            // Members List
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Joined Members
                    if (joinedMembers.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                        child: Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF9B9B9B),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      ...joinedMembers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final member = entry.value;
                        return InkWell(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/member-change',
                              arguments: member.phone,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                top: index > 0
                                    ? const BorderSide(color: Color(0xFFE5E5E5), width: 1)
                                    : BorderSide.none,
                              ),
                            ),
                            child: Text(
                              member.phone,
                              style: TextStyle(
                                fontSize: 17,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 24),
                    ],
                    // Invited Members
                    if (invitedMembers.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                        child: Text(
                          'PENDING',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF9B9B9B),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      ...invitedMembers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final member = entry.value;
                        return InkWell(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/member-change',
                              arguments: member.phone,
                            );
                          },
                          child: Container(
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
                                    color: const Color(0xFF6B6B6B),
                                  ),
                                ),
                                Text(
                                  'Invited',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: const Color(0xFF6B6B6B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
