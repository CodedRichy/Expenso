/// UI workflow helpers for expense normalization.
/// 
/// This file contains UI-specific concepts that bridge the gap between
/// parsing (names) and accounting (IDs). These are NOT part of the core
/// accounting model and should not be used in balance computation.
/// 
/// Key distinction:
/// - [ParticipantSlot] is a UI concept for confirmation dialogs
/// - [NormalizedExpense] is an accounting concept for ledger computation
/// 
/// The workflow is: ParsedExpenseResult → ParticipantSlots (UI) → NormalizedExpense (accounting)
/// 
/// ## Currency Handling
/// - UI layer works with doubles for display
/// - Conversion to [MoneyMinor] happens once at normalization boundary
/// - Remainder from integer division is handled deterministically

import '../models/models.dart';
import '../models/money_minor.dart';
import '../models/normalized_expense.dart';
import '../services/groq_expense_parser_service.dart';

const double _tolerance = 0.01;

/// UI-only class for displaying and editing participant assignments.
/// 
/// This is used in confirmation dialogs where users can:
/// - See which names mapped to which members
/// - Manually assign unresolved names to members
/// - Edit amounts for exact splits
/// 
/// This class should NEVER be used for balance computation.
/// Convert to [NormalizedExpense] before any accounting operations.
/// 
/// Note: [amount] is a double for UI display. It will be converted to
/// [MoneyMinor] (integer) at the normalization boundary.
class ParticipantSlot {
  final String name;
  final double amount;
  final String? memberId;
  final bool isGuessed;

  ParticipantSlot({
    required this.name,
    required this.amount,
    this.memberId,
    this.isGuessed = false,
  });

  ParticipantSlot copyWith({
    String? name,
    double? amount,
    String? memberId,
    bool? isGuessed,
  }) {
    return ParticipantSlot(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      memberId: memberId ?? this.memberId,
      isGuessed: isGuessed ?? this.isGuessed,
    );
  }

  bool get isResolved => memberId != null && memberId!.isNotEmpty;
}

/// Result of attempting to normalize a parsed expense.
sealed class NormalizationResult {}

/// Normalization succeeded - expense is ready for accounting.
class NormalizationSuccess extends NormalizationResult {
  final NormalizedExpense expense;
  NormalizationSuccess(this.expense);
}

/// Normalization needs user confirmation before proceeding.
/// 
/// This is a UI workflow state, not an accounting state.
/// Contains [ParticipantSlot]s for the confirmation dialog.
class NormalizationNeedsConfirmation extends NormalizationResult {
  final double amount;
  final String description;
  final String category;
  final String date;
  final String splitType;
  final String payerId;
  final String currencyCode;
  final List<ParticipantSlot> slots;
  final List<String> unresolvedNames;
  final String? validationWarning;

  NormalizationNeedsConfirmation({
    required this.amount,
    required this.description,
    required this.category,
    required this.date,
    required this.splitType,
    required this.payerId,
    required this.currencyCode,
    required this.slots,
    required this.unresolvedNames,
    this.validationWarning,
  });
}

/// Normalization failed with an unrecoverable error.
class NormalizationError extends NormalizationResult {
  final String message;
  NormalizationError(this.message);
}

/// Context for resolving names to member IDs.
/// 
/// This is a UI/workflow helper that uses current group membership
/// and contact information to fuzzy-match names from parsed input.
class NameResolutionContext {
  final List<Member> members;
  final String currentUserId;
  final String currentUserName;
  final Map<String, List<String>>? contactNameToNormalizedPhones;
  
  late final Map<String, String>? _phoneToContactName;
  late final List<Member> _activeMembers;

  NameResolutionContext({
    required this.members,
    required this.currentUserId,
    required this.currentUserName,
    this.contactNameToNormalizedPhones,
  }) {
    _activeMembers = members.where((m) => !m.id.startsWith('p_')).toList();
    
    if (contactNameToNormalizedPhones != null) {
      _phoneToContactName = {};
      for (final entry in contactNameToNormalizedPhones!.entries) {
        for (final p in entry.value) {
          _phoneToContactName![p] = entry.key;
        }
      }
    } else {
      _phoneToContactName = null;
    }
  }

  List<Member> get activeMembers => _activeMembers;
  List<String> get allMemberIds => _activeMembers.map((m) => m.id).toList();

  String getMemberDisplayName(String memberId) {
    if (memberId == currentUserId) {
      return currentUserName.isNotEmpty ? currentUserName : 'You';
    }
    final member = _activeMembers.cast<Member?>().firstWhere(
      (m) => m?.id == memberId,
      orElse: () => null,
    );
    return member?.name ?? memberId;
  }

  ({String? id, bool isGuessed}) resolveNameToId(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return (id: null, isGuessed: false);

    if (n == 'me' || n == 'i' || n == 'you') {
      return (id: currentUserId.isNotEmpty ? currentUserId : null, isGuessed: false);
    }
    if (currentUserName.isNotEmpty && currentUserName.toLowerCase() == n) {
      return (id: currentUserId.isNotEmpty ? currentUserId : null, isGuessed: false);
    }

    String? exactMatch;
    final similarMatchIds = <String>{};

    for (final m in _activeMembers) {
      final displayLower = getMemberDisplayName(m.id).trim().toLowerCase();
      if (displayLower.isNotEmpty && _nameSimilar(n, displayLower)) {
        if (displayLower == n) {
          exactMatch = m.id;
          break;
        }
        similarMatchIds.add(m.id);
      }

      final contactLower = _phoneToContactName?[_normalizePhoneForMatch(m.phone)]?.trim().toLowerCase();
      if (contactLower != null && contactLower.isNotEmpty && _nameSimilar(n, contactLower)) {
        if (contactLower == n) {
          exactMatch = m.id;
          break;
        }
        similarMatchIds.add(m.id);
      }
    }

    if (exactMatch != null) return (id: exactMatch, isGuessed: false);
    if (similarMatchIds.length == 1) return (id: similarMatchIds.single, isGuessed: true);
    return (id: null, isGuessed: false);
  }

  Set<String> memberIdsMatchingName(String name, List<Member> candidates) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return {};
    final ids = <String>{};
    for (final m in candidates) {
      final displayLower = getMemberDisplayName(m.id).trim().toLowerCase();
      if (displayLower.isNotEmpty && _nameSimilar(n, displayLower)) ids.add(m.id);
      final contactLower = _phoneToContactName?[_normalizePhoneForMatch(m.phone)]?.trim().toLowerCase();
      if (contactLower != null && contactLower.isNotEmpty && _nameSimilar(n, contactLower)) ids.add(m.id);
    }
    return ids;
  }
}

bool _nameSimilar(String parsedLower, String otherLower) {
  if (parsedLower == otherLower) return true;
  if (otherLower.contains(parsedLower) || parsedLower.contains(otherLower)) return true;
  if (otherLower.startsWith(parsedLower) || parsedLower.startsWith(otherLower)) return true;
  return false;
}

String _normalizePhoneForMatch(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
}

/// Main entry point for normalizing a parsed expense.
/// 
/// This function bridges parsing (names) and accounting (IDs).
/// It returns one of:
/// - [NormalizationSuccess]: Ready for accounting
/// - [NormalizationNeedsConfirmation]: Needs UI resolution
/// - [NormalizationError]: Unrecoverable error
NormalizationResult normalizeExpense({
  required ParsedExpenseResult parsed,
  required List<Member> members,
  required String currentUserId,
  required String currentUserName,
  String currencyCode = 'INR',
  Map<String, List<String>>? contactNameToNormalizedPhones,
  String date = 'Today',
}) {
  if (parsed.amount <= 0 || parsed.amount.isNaN || parsed.amount.isInfinite) {
    return NormalizationError('Amount must be positive and finite');
  }
  if (parsed.description.trim().isEmpty) {
    return NormalizationError('Description cannot be empty');
  }

  final ctx = NameResolutionContext(
    members: members,
    currentUserId: currentUserId,
    currentUserName: currentUserName,
    contactNameToNormalizedPhones: contactNameToNormalizedPhones,
  );

  if (ctx.activeMembers.isEmpty) {
    return NormalizationError('No active members in group');
  }

  String payerId = currentUserId;
  if (parsed.payerName != null && parsed.payerName!.trim().isNotEmpty) {
    final resolved = ctx.resolveNameToId(parsed.payerName!.trim());
    if (resolved.id != null) {
      payerId = resolved.id!;
    }
  }

  if (payerId.isEmpty || payerId.startsWith('p_')) {
    return NormalizationError('Invalid payer');
  }

  final splitType = _capitalizeSplitType(parsed.splitType);
  final List<ParticipantSlot> slots;
  String? validationWarning;
  final unresolvedNames = <String>[];

  switch (parsed.splitType.toLowerCase()) {
    case 'exclude':
      final result = _buildExcludeSlots(parsed, ctx);
      slots = result.slots;
      unresolvedNames.addAll(result.unresolvedNames);

    case 'exact':
      final result = _buildExactSlots(parsed, ctx, currentUserId);
      slots = result.slots;
      unresolvedNames.addAll(result.unresolvedNames);
      validationWarning = result.validationWarning;

    case 'percentage':
      final result = _buildPercentageSlots(parsed, ctx, currentUserId);
      slots = result.slots;
      unresolvedNames.addAll(result.unresolvedNames);
      validationWarning = result.validationWarning;

    case 'shares':
      final result = _buildSharesSlots(parsed, ctx, currentUserId);
      slots = result.slots;
      unresolvedNames.addAll(result.unresolvedNames);
      validationWarning = result.validationWarning;

    default:
      final result = _buildEvenSlots(parsed, ctx, currentUserId);
      slots = result.slots;
      unresolvedNames.addAll(result.unresolvedNames);
  }

  _resolveUnresolvedSlots(slots, ctx);

  final stillUnresolved = slots.where((s) => !s.isResolved).toList();

  if (stillUnresolved.isNotEmpty || validationWarning != null) {
    return NormalizationNeedsConfirmation(
      amount: parsed.amount,
      description: parsed.description.trim(),
      category: parsed.category.trim(),
      date: date,
      splitType: splitType,
      payerId: payerId,
      currencyCode: currencyCode,
      slots: slots,
      unresolvedNames: stillUnresolved.map((s) => s.name).toList(),
      validationWarning: validationWarning,
    );
  }

  try {
    final normalized = buildNormalizedExpenseFromSlots(
      amount: parsed.amount,
      description: parsed.description.trim(),
      category: parsed.category.trim(),
      date: date,
      payerId: payerId,
      slots: slots,
      splitType: splitType,
      allMemberIds: ctx.allMemberIds,
      currencyCode: currencyCode,
    );
    return NormalizationSuccess(normalized);
  } on NormalizedExpenseError catch (e) {
    return NormalizationError(e.message);
  }
}

/// Converts resolved ParticipantSlots to a NormalizedExpense.
/// 
/// This is the bridge from UI workflow (doubles) to accounting model (integers).
/// All slots must have resolved memberIds before calling this.
/// 
/// ## Remainder Handling
/// When splitting amounts, integer division may produce a remainder.
/// The remainder is assigned to the payer (deterministic, documented).
/// 
/// Example: 100.00 INR split among 3 people
/// - Total minor units: 10000 paise
/// - Base share: 10000 ÷ 3 = 3333 paise each
/// - Remainder: 10000 - (3333 × 3) = 1 paise
/// - Payer gets: 3333 + 1 = 3334 paise
NormalizedExpense buildNormalizedExpenseFromSlots({
  required double amount,
  required String description,
  required String category,
  required String date,
  required String payerId,
  required List<ParticipantSlot> slots,
  required String splitType,
  required List<String> allMemberIds,
  String currencyCode = 'INR',
  List<String>? excludedIds,
}) {
  final totalMinor = MoneyConversion.parseToMinor(amount, currencyCode);
  
  final payerContributions = <String, MoneyMinor>{
    payerId: totalMinor,
  };

  Map<String, MoneyMinor> participantShares;

  if (splitType == 'Exclude') {
    participantShares = _splitExclude(
      totalMinor: totalMinor.amountMinor,
      currencyCode: currencyCode,
      allMemberIds: allMemberIds,
      excludedIds: excludedIds ?? slots.map((s) => s.memberId).whereType<String>().toList(),
      payerId: payerId,
    );
  } else {
    participantShares = _splitFromSlots(
      totalMinor: totalMinor.amountMinor,
      currencyCode: currencyCode,
      slots: slots,
      payerId: payerId,
    );
  }

  return NormalizedExpense(
    total: totalMinor,
    description: description,
    category: category,
    date: date,
    payerContributionsByMemberId: payerContributions,
    participantSharesByMemberId: participantShares,
  );
}

/// Splits total among non-excluded members, assigning remainder to payer.
Map<String, MoneyMinor> _splitExclude({
  required int totalMinor,
  required String currencyCode,
  required List<String> allMemberIds,
  required List<String> excludedIds,
  required String payerId,
}) {
  final excludedSet = excludedIds.toSet();
  final includedIds = allMemberIds.where((id) => !excludedSet.contains(id)).toList();
  
  if (includedIds.isEmpty) {
    return {payerId: MoneyMinor(totalMinor, currencyCode)};
  }

  return _splitEvenlyWithRemainder(
    totalMinor: totalMinor,
    currencyCode: currencyCode,
    participantIds: includedIds,
    remainderId: payerId,
  );
}

/// Converts slot amounts to integer shares, assigning remainder to payer.
Map<String, MoneyMinor> _splitFromSlots({
  required int totalMinor,
  required String currencyCode,
  required List<ParticipantSlot> slots,
  required String payerId,
}) {
  final resolvedSlots = slots.where((s) => s.isResolved).toList();
  if (resolvedSlots.isEmpty) {
    return {payerId: MoneyMinor(totalMinor, currencyCode)};
  }

  final computed = <String, int>{};
  int allocated = 0;

  for (final slot in resolvedSlots) {
    final minor = MoneyConversion.parseToMinor(slot.amount, currencyCode);
    final id = slot.memberId!;
    computed[id] = (computed[id] ?? 0) + minor.amountMinor;
    allocated += minor.amountMinor;
  }

  final remainder = totalMinor - allocated;
  if (remainder != 0) {
    computed[payerId] = (computed[payerId] ?? 0) + remainder;
  }

  return computed.map((id, amt) => MapEntry(id, MoneyMinor(amt, currencyCode)));
}

/// Splits evenly with deterministic remainder assignment.
Map<String, MoneyMinor> _splitEvenlyWithRemainder({
  required int totalMinor,
  required String currencyCode,
  required List<String> participantIds,
  required String remainderId,
}) {
  final count = participantIds.length;
  final baseShare = totalMinor ~/ count;
  final remainder = totalMinor - (baseShare * count);

  final result = <String, MoneyMinor>{};
  for (final id in participantIds) {
    result[id] = MoneyMinor(baseShare, currencyCode);
  }

  if (remainder > 0) {
    if (result.containsKey(remainderId)) {
      result[remainderId] = MoneyMinor(
        result[remainderId]!.amountMinor + remainder,
        currencyCode,
      );
    } else {
      result[participantIds.first] = MoneyMinor(
        result[participantIds.first]!.amountMinor + remainder,
        currencyCode,
      );
    }
  }

  return result;
}

String _capitalizeSplitType(String splitType) {
  switch (splitType.toLowerCase()) {
    case 'exact':
      return 'Exact';
    case 'exclude':
      return 'Exclude';
    case 'percentage':
      return 'Percentage';
    case 'shares':
      return 'Shares';
    default:
      return 'Even';
  }
}

({List<ParticipantSlot> slots, List<String> unresolvedNames}) _buildExcludeSlots(
  ParsedExpenseResult parsed,
  NameResolutionContext ctx,
) {
  final slots = <ParticipantSlot>[];
  final unresolvedNames = <String>[];

  for (final name in parsed.excludedNames) {
    final resolved = ctx.resolveNameToId(name);
    slots.add(ParticipantSlot(
      name: name,
      amount: 0,
      memberId: resolved.id,
      isGuessed: resolved.isGuessed,
    ));
    if (resolved.id == null) unresolvedNames.add(name);
  }

  return (slots: slots, unresolvedNames: unresolvedNames);
}

({List<ParticipantSlot> slots, List<String> unresolvedNames, String? validationWarning}) _buildExactSlots(
  ParsedExpenseResult parsed,
  NameResolutionContext ctx,
  String currentUserId,
) {
  final slots = <ParticipantSlot>[];
  final unresolvedNames = <String>[];

  for (final entry in parsed.exactAmountsByName.entries) {
    final resolved = ctx.resolveNameToId(entry.key);
    slots.add(ParticipantSlot(
      name: entry.key,
      amount: entry.value,
      memberId: resolved.id,
      isGuessed: resolved.isGuessed,
    ));
    if (resolved.id == null) unresolvedNames.add(entry.key);
  }

  final assignedSum = slots.fold(0.0, (sum, s) => sum + s.amount);
  String? validationWarning;

  if ((assignedSum - parsed.amount).abs() > _tolerance) {
    if (assignedSum < parsed.amount) {
      final remainder = parsed.amount - assignedSum;
      final existingCurrentUser = slots.where((s) => s.memberId == currentUserId).toList();
      if (existingCurrentUser.isNotEmpty) {
        final idx = slots.indexOf(existingCurrentUser.first);
        slots[idx] = slots[idx].copyWith(amount: slots[idx].amount + remainder);
      } else {
        slots.add(ParticipantSlot(
          name: ctx.getMemberDisplayName(currentUserId),
          amount: remainder,
          memberId: currentUserId,
          isGuessed: false,
        ));
      }
    } else {
      validationWarning = 'Exact amounts (${assignedSum.toStringAsFixed(2)}) exceed total (${parsed.amount.toStringAsFixed(2)})';
    }
  }

  return (slots: slots, unresolvedNames: unresolvedNames, validationWarning: validationWarning);
}

({List<ParticipantSlot> slots, List<String> unresolvedNames, String? validationWarning}) _buildPercentageSlots(
  ParsedExpenseResult parsed,
  NameResolutionContext ctx,
  String currentUserId,
) {
  final slots = <ParticipantSlot>[];
  final unresolvedNames = <String>[];

  final percentageSum = parsed.percentageByName.values.fold(0.0, (a, b) => a + b);
  String? validationWarning;

  if ((percentageSum - 100.0).abs() > _tolerance) {
    validationWarning = 'Percentages must sum to 100% (got ${percentageSum.toStringAsFixed(1)}%)';
  }

  for (final entry in parsed.percentageByName.entries) {
    final name = entry.key;
    final pct = entry.value;
    final calculatedAmount = parsed.amount * (pct / 100);

    String? memberId;
    bool isGuessed = false;
    String displayName = name;

    final nameLower = name.trim().toLowerCase();
    if (nameLower == 'me' || nameLower == 'i') {
      memberId = currentUserId;
      displayName = ctx.getMemberDisplayName(currentUserId);
    } else {
      final resolved = ctx.resolveNameToId(name);
      memberId = resolved.id;
      isGuessed = resolved.isGuessed;
      if (memberId == null) unresolvedNames.add(name);
    }

    slots.add(ParticipantSlot(
      name: displayName,
      amount: calculatedAmount,
      memberId: memberId,
      isGuessed: isGuessed,
    ));
  }

  return (slots: slots, unresolvedNames: unresolvedNames, validationWarning: validationWarning);
}

({List<ParticipantSlot> slots, List<String> unresolvedNames, String? validationWarning}) _buildSharesSlots(
  ParsedExpenseResult parsed,
  NameResolutionContext ctx,
  String currentUserId,
) {
  final slots = <ParticipantSlot>[];
  final unresolvedNames = <String>[];
  String? validationWarning;

  final totalShares = parsed.sharesByName.values.fold(0.0, (a, b) => a + b);

  if (totalShares <= 0) {
    validationWarning = 'Total shares must be greater than 0';
    return (slots: slots, unresolvedNames: unresolvedNames, validationWarning: validationWarning);
  }

  for (final entry in parsed.sharesByName.entries) {
    final name = entry.key;
    final personShares = entry.value;
    final calculatedAmount = parsed.amount * (personShares / totalShares);

    String? memberId;
    bool isGuessed = false;
    String displayName = name;

    final nameLower = name.trim().toLowerCase();
    if (nameLower == 'me' || nameLower == 'i') {
      memberId = currentUserId;
      displayName = ctx.getMemberDisplayName(currentUserId);
    } else {
      final resolved = ctx.resolveNameToId(name);
      memberId = resolved.id;
      isGuessed = resolved.isGuessed;
      if (memberId == null) unresolvedNames.add(name);
    }

    slots.add(ParticipantSlot(
      name: displayName,
      amount: calculatedAmount,
      memberId: memberId,
      isGuessed: isGuessed,
    ));
  }

  return (slots: slots, unresolvedNames: unresolvedNames, validationWarning: validationWarning);
}

({List<ParticipantSlot> slots, List<String> unresolvedNames}) _buildEvenSlots(
  ParsedExpenseResult parsed,
  NameResolutionContext ctx,
  String currentUserId,
) {
  final slots = <ParticipantSlot>[];
  final unresolvedNames = <String>[];

  final names = parsed.participantNames;

  if (names.isEmpty) {
    final perShare = parsed.amount / ctx.activeMembers.length;
    for (final m in ctx.activeMembers) {
      slots.add(ParticipantSlot(
        name: ctx.getMemberDisplayName(m.id),
        amount: perShare,
        memberId: m.id,
        isGuessed: false,
      ));
    }
  } else {
    final seenIds = <String>{};
    final resolvedSlots = <ParticipantSlot>[];

    for (final name in names) {
      final resolved = ctx.resolveNameToId(name);
      if (resolved.id != null && resolved.id!.isNotEmpty) {
        if (!seenIds.contains(resolved.id)) {
          seenIds.add(resolved.id!);
          resolvedSlots.add(ParticipantSlot(
            name: name,
            amount: 0,
            memberId: resolved.id,
            isGuessed: resolved.isGuessed,
          ));
        }
      } else {
        resolvedSlots.add(ParticipantSlot(
          name: name,
          amount: 0,
          memberId: null,
          isGuessed: false,
        ));
        unresolvedNames.add(name);
      }
    }

    if (!seenIds.contains(currentUserId)) {
      seenIds.add(currentUserId);
      resolvedSlots.insert(0, ParticipantSlot(
        name: ctx.getMemberDisplayName(currentUserId),
        amount: 0,
        memberId: currentUserId,
        isGuessed: false,
      ));
    }

    final splitCount = resolvedSlots.length;
    final perShare = splitCount > 0 ? parsed.amount / splitCount : parsed.amount;
    for (final slot in resolvedSlots) {
      slots.add(slot.copyWith(amount: perShare));
    }
  }

  return (slots: slots, unresolvedNames: unresolvedNames);
}

void _resolveUnresolvedSlots(List<ParticipantSlot> slots, NameResolutionContext ctx) {
  Set<String> assignedIds() =>
      slots.where((s) => s.isResolved).map((s) => s.memberId!).toSet();

  List<Member> unassigned(Set<String> assigned) =>
      ctx.activeMembers.where((m) => !assigned.contains(m.id)).toList();

  bool changed = true;
  while (changed) {
    changed = false;
    final assigned = assignedIds();
    final unassignedMembers = unassigned(assigned);

    for (var i = 0; i < slots.length; i++) {
      if (slots[i].isResolved) continue;

      final matchIds = ctx.memberIdsMatchingName(slots[i].name, unassignedMembers);
      if (matchIds.length == 1) {
        slots[i] = slots[i].copyWith(
          memberId: matchIds.single,
          isGuessed: true,
        );
        changed = true;
        break;
      }
    }
  }
}
