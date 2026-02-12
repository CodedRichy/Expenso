import 'package:flutter/material.dart';
import '../models/models.dart';
import '../repositories/cycle_repository.dart';

class GroupMembers extends StatelessWidget {
  const GroupMembers({super.key});

  @override
  Widget build(BuildContext context) {
    final group = ModalRoute.of(context)!.settings.arguments as Group;
    final repo = CycleRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final listMembers = repo.getMembersForGroup(group.id);
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
                        group.name,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${listMembers.length} member${listMembers.length != 1 ? 's' : ''}',
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
                  child: listMembers.isEmpty
                      ? Center(
                          child: Text(
                            'No members yet',
                            style: TextStyle(
                              fontSize: 17,
                              color: const Color(0xFF6B6B6B),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              ...listMembers.asMap().entries.map((entry) {
                                final index = entry.key;
                                final member = entry.value;
                                return InkWell(
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/member-change',
                                      arguments: {
                                        'groupName': group.name,
                                        'memberPhone': member.phone,
                                        'action': 'remove',
                                      },
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: index > 0
                                            ? const BorderSide(
                                                color: Color(0xFFE5E5E5),
                                                width: 1,
                                              )
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
                                                repo.getMemberDisplayName(member.phone),
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  color: const Color(0xFF1A1A1A),
                                                ),
                                              ),
                                              if (member.name.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  member.phone,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: const Color(0xFF9B9B9B),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
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
