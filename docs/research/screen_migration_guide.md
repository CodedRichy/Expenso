# Screen-by-Screen Migration Guide
## Expenso UI Redesign: From Current to Glassmorphic v2.1

**Target:** Clean, modern, crisp, interactive UI based on 2025/2026 design research  
**Timeline:** 4-6 weeks (20 screens total)  
**Last updated:** March 18, 2026

---

## Migration Overview

### Priority Order (Based on User Impact)

**Week 1: Core Flows (Highest Impact)**
1. GroupDetail — Main screen users live in
2. ExpenseInput — Core interaction (add expense)
3. SettlementConfirmation — Money moment

**Week 2: Entry & List Screens**
4. GroupsList — First impression
5. CreateGroup — Group creation flow
6. InviteMembers — Onboarding new members

**Week 3: Secondary Flows**
7. Profile — Settings & account
8. EditExpense — Edit existing expense
9. CycleHistory / CycleHistoryDetail — Past cycles
10. GroupMembers — Member management

**Week 4: Edge Cases & Polish**
11. PaymentResult — Post-payment feedback
12. CycleSettled — Cycle completion
13. PhoneAuth — Login flow
14. OnboardingName — First-run experience
15. EmptyStates / ErrorStates — Edge cases
16. UndoExpense, MemberChange — Supporting flows
17. SplashScreen — Already minimal, minor updates only

---

## Pre-Migration Checklist

Before touching ANY screen:

- [ ] Read `expenso_design_system_v2.1.md` thoroughly
- [ ] Update `lib/design/colors.dart` with glassmorphic palette
- [ ] Update `lib/design/typography.dart` with new scale (36px display, 600 weight)
- [ ] Update `lib/design/spacing.dart` (16×24 button padding, 24px card padding)
- [ ] Create `lib/widgets/glass_card.dart` component
- [ ] Create `lib/widgets/tap_scale.dart` micro-interaction widget
- [ ] Create `lib/widgets/animated_number.dart` for amount transitions
- [ ] Test dark mode with new glassmorphic tokens

---

## Global Changes (Apply to ALL Screens)

### 1. Update GradientScaffold

**File:** `lib/widgets/gradient_scaffold.dart`

**Current:**
```dart
// Dark mode: #0B0B0D → #121216 gradient
```

**New:**
```dart
// Light mode: Solid #F8F9FA (soft gray)
// Dark mode: Same gradient but with glassmorphic surface overlays

class GradientScaffold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark 
        ? Color(0xFF0A0A0A)  // Near-black
        : Color(0xFFF8F9FA),  // Soft gray (NEW)
      body: isDark
        ? Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A0A0A), Color(0xFF121216)],
              ),
            ),
            child: child,
          )
        : child,
    );
  }
}
```

### 2. Create GlassCard Component

**File:** `lib/widgets/glass_card.dart`

```dart
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? borderRadius;
  final Color? backgroundColor;
  final double? blur;
  
  const GlassCard({
    Key? key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.blur,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? 16),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blur ?? 20,
          sigmaY: blur ?? 20,
        ),
        child: Container(
          padding: padding ?? EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: backgroundColor ?? (isDark 
              ? Color(0xE61A1A1E)  // 90% opacity dark
              : Color(0xB3FFFFFF)), // 70% opacity white
            borderRadius: BorderRadius.circular(borderRadius ?? 16),
            border: Border.all(
              color: isDark 
                ? Color(0x33FFFFFF)  // 20% white
                : Color(0x14000000), // 8% black
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark 
                  ? Color(0x66000000)  // 40% black
                  : Color(0x0A000000), // 4% black
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
```

### 3. Create TapScale Widget

**File:** `lib/widgets/tap_scale.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double targetScale;
  final Duration duration;
  final bool enableHaptic;

  const TapScale({
    Key? key,
    required this.child,
    this.onTap,
    this.targetScale = 0.96,
    this.duration = const Duration(milliseconds: 100),
    this.enableHaptic = false,
  }) : super(key: key);

  @override
  _TapScaleState createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        if (widget.enableHaptic) {
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? widget.targetScale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
```

### 4. Create AnimatedNumber Widget

**File:** `lib/widgets/animated_number.dart`

```dart
import 'package:flutter/material.dart';

class AnimatedNumber extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;

  const AnimatedNumber({
    Key? key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      builder: (context, animatedValue, child) {
        return Text(
          '$prefix${animatedValue.toStringAsFixed(0)}$suffix',
          style: style,
        );
      },
    );
  }
}
```

---

## Screen #1: GroupDetail (Highest Priority)

**File:** `lib/screens/groups/group_detail.dart`  
**Effort:** 6-8 hours  
**Complexity:** High

### Current Issues
- Status card uses gradient (not glassmorphic)
- Expense list items are separate cards (not unified list)
- No FAB (add expense buried in bottom sheet)
- No hover states or micro-interactions
- Borders are 0.5px (too subtle)

### Migration Steps

#### Step 1: Update Header (30 min)

**Current:**
```dart
Padding(
  padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
  child: Row(...),
)
```

**New:**
```dart
Padding(
  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
  child: Row(
    children: [
      TapScale(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withOpacity(0.08), width: 1),
          ),
          child: Icon(Icons.arrow_back, size: 20),
        ),
      ),
      SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.groupName,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 2),
            Text(
              'Active · 3 of 4 settled',
              style: TextStyle(fontSize: 13, color: context.colorTextSecondary),
            ),
          ],
        ),
      ),
      SecondaryButton(
        label: 'Members',
        onPressed: () => Navigator.pushNamed(context, '/group-members'),
      ),
    ],
  ),
)
```

#### Step 2: Replace Decision Clarity Card with GlassCard (1 hour)

**Current:**
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(...),
    borderRadius: BorderRadius.circular(12),
  ),
  child: _DecisionClarityCard(...),
)
```

**New:**
```dart
GlassCard(
  padding: EdgeInsets.all(24),
  borderRadius: 16,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'YOUR STATUS',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: context.colorTextTertiary,
          letterSpacing: 0.5,
        ),
      ),
      SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          AnimatedNumber(
            value: yourBalance,
            prefix: '₹',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w600,
              color: yourBalance >= 0 ? Color(0xFF10B981) : Color(0xFFEF4444),
            ),
          ),
          SizedBox(width: 8),
          Text(
            yourBalance >= 0 ? 'credit' : 'debt',
            style: TextStyle(fontSize: 15, color: context.colorTextSecondary),
          ),
        ],
      ),
      SizedBox(height: 16),
      Container(
        height: 1,
        color: Colors.black.withOpacity(0.06),
      ),
      SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cycle total',
                  style: TextStyle(fontSize: 12, color: context.colorTextTertiary),
                ),
                SizedBox(height: 4),
                AnimatedNumber(
                  value: cycleTotal,
                  prefix: '₹',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You spent',
                  style: TextStyle(fontSize: 12, color: context.colorTextTertiary),
                ),
                SizedBox(height: 4),
                AnimatedNumber(
                  value: youSpent,
                  prefix: '₹',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  ),
)
```

#### Step 3: Update Button Row (30 min)

**Current:**
```dart
Row(
  children: [
    Expanded(child: PrimaryButton(...)),
    SizedBox(width: 8),
    IconButton(...),
  ],
)
```

**New:**
```dart
Padding(
  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  child: Row(
    children: [
      Expanded(
        child: TapScale(
          enableHaptic: true,
          child: ElevatedButton(
            onPressed: onSettle,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colorPrimary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text('Settle up', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
      SizedBox(width: 10),
      TapScale(
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black.withOpacity(0.08), width: 1),
          ),
          child: Center(child: Text('💳', style: TextStyle(fontSize: 20))),
        ),
      ),
    ],
  ),
)
```

#### Step 4: Rebuild Expense List (2 hours)

**Current:**
```dart
// Separate cards with gaps
ListView.builder(
  itemBuilder: (context, index) => Card(...),
)
```

**New:**
```dart
// Unified card with 1px separators
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.black.withOpacity(0.06), width: 1),
  ),
  child: ListView.separated(
    shrinkWrap: true,
    physics: NeverScrollableScrollPhysics(),
    itemCount: expenses.length,
    separatorBuilder: (context, index) => Container(
      height: 1,
      color: Colors.black.withOpacity(0.04),
    ),
    itemBuilder: (context, index) {
      final expense = expenses[index];
      return TapScale(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pushNamed(context, '/edit-expense', arguments: expense);
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.description,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Paid by ${expense.payerName} · ${expense.participantSummary}',
                      style: TextStyle(fontSize: 13, color: context.colorTextSecondary),
                    ),
                  ],
                ),
              ),
              AnimatedNumber(
                value: expense.amount,
                prefix: '₹',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    },
  ),
)
```

#### Step 5: Add FAB (30 min)

**New:**
```dart
// Add to Scaffold
floatingActionButton: TapScale(
  targetScale: 0.9,
  onTap: () {
    HapticFeedback.heavyImpact();
    Navigator.pushNamed(context, '/expense-input', arguments: group);
  },
  child: Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      color: context.colorPrimary,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Icon(Icons.add, size: 24, color: Colors.white),
  ),
),
```

#### Step 6: Add Stagger Animation (1 hour)

**New:**
```dart
// Wrap ListView with AnimatedList or use StaggeredListItem widget
itemBuilder: (context, index) {
  return StaggeredListItem(
    index: index,
    child: TapScale(...), // expense item
  );
}
```

### Testing Checklist for GroupDetail

- [ ] GlassCard blur works in light/dark mode
- [ ] Numbers animate smoothly when balance changes
- [ ] All buttons have scale-down on press
- [ ] Haptics fire on FAB tap and primary actions
- [ ] Expense list items have hover state
- [ ] List staggers on initial load
- [ ] Dark mode: frosted glass is visible
- [ ] Borders are 1px (not 0.5px)
- [ ] Border radius: 16px on cards, 8px on buttons
- [ ] Spacing matches design system (20px horizontal, 24px padding)

---

## Screen #2: ExpenseInput

**File:** `lib/screens/expenses/expense_input.dart`  
**Effort:** 4-5 hours  
**Complexity:** Medium

### Current Issues
- Magic Bar not visually prominent
- No transition between input → confirmation states
- Manual form feels equal to Magic Bar (should be secondary)

### Migration Steps

#### Step 1: Highlight Magic Bar (1.5 hours)

**Current:**
```dart
TextField(
  decoration: InputDecoration(hintText: 'e.g. Dinner 1200 with'),
)
```

**New:**
```dart
Container(
  padding: EdgeInsets.all(24),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE6F1FB), Color(0xFFEAF3DE)],
    ),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Color(0xFF3B82F6), width: 1),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text('✨', style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Text(
            'Magic Bar',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      SizedBox(height: 12),
      TextField(
        decoration: InputDecoration(
          hintText: 'e.g. Dinner 3200 with Priya and Rahul',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.black.withOpacity(0.1), width: 1),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
      SizedBox(height: 12),
      Text(
        'Type naturally. I\'ll parse the amount, who paid, and who\'s involved.',
        style: TextStyle(fontSize: 12, color: context.colorTextSecondary, height: 1.5),
      ),
    ],
  ),
)
```

#### Step 2: Add State Transition Animation (1 hour)

**Current:**
```dart
// Switches between views instantly
if (showConfirmation) _buildConfirmation() else _buildInput()
```

**New:**
```dart
AnimatedSwitcher(
  duration: Duration(milliseconds: 220),
  transitionBuilder: (child, animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, 0.1),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  },
  child: showConfirmation
    ? _buildConfirmation(key: ValueKey('confirmation'))
    : _buildInput(key: ValueKey('input')),
)
```

#### Step 3: Style Confirmation Card (1 hour)

**New:**
```dart
GlassCard(
  padding: EdgeInsets.all(20),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'PARSED EXPENSE',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: context.colorTextTertiary,
          letterSpacing: 0.5,
        ),
      ),
      SizedBox(height: 12),
      _buildField('Description', parsedDescription),
      SizedBox(height: 16),
      _buildAmountField('Total amount', parsedAmount),
      SizedBox(height: 16),
      Container(height: 1, color: Colors.black.withOpacity(0.06)),
      SizedBox(height: 12),
      Text('Split', style: TextStyle(fontSize: 14, color: context.colorTextSecondary)),
      SizedBox(height: 8),
      ...splits.map((split) => _buildSplitRow(split)),
      SizedBox(height: 16),
      TapScale(
        enableHaptic: true,
        child: ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colorPrimary,
            minimumSize: Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: Text('Confirm expense', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ),
      ),
    ],
  ),
)
```

#### Step 4: De-emphasize Manual Form (30 min)

**New:**
```dart
// Add clear visual separation
Container(
  margin: EdgeInsets.only(top: 20),
  padding: EdgeInsets.only(top: 20),
  decoration: BoxDecoration(
    border: Border(top: BorderSide(color: Colors.black.withOpacity(0.1), width: 1)),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Or enter manually',
        style: TextStyle(fontSize: 13, color: context.colorTextSecondary),
      ),
      SizedBox(height: 12),
      // Manual form fields (smaller, less prominent)
      ...
    ],
  ),
)
```

### Testing Checklist for ExpenseInput

- [ ] Magic Bar gradient visible in light/dark
- [ ] Transition animation smooth (220ms)
- [ ] Confirm button has haptic feedback
- [ ] Manual form clearly secondary
- [ ] GlassCard for confirmation visible
- [ ] All amounts use AnimatedNumber

---

## Screen #3: SettlementConfirmation

**File:** `lib/screens/settlement/settlement_confirmation.dart`  
**Effort:** 5-6 hours  
**Complexity:** Medium-High

### Current Issues
- Payment cards not visually distinct
- No stagger animation on card appearance
- Progress indicator not prominent
- "Mark as paid" vs "Pay via UPI" unclear

### Migration Steps

#### Step 1: Add Progress Banner (45 min)

**New:**
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(
    color: Color(0xFFD1FAE5),
    borderRadius: BorderRadius.circular(8),
    border: Border(
      left: BorderSide(color: Color(0xFF10B981), width: 3),
    ),
  ),
  child: Row(
    children: [
      Text('✓', style: TextStyle(fontSize: 16)),
      SizedBox(width: 8),
      Text(
        '3 of 4 payments settled',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF047857),
        ),
      ),
    ],
  ),
)
```

#### Step 2: Redesign Payment Cards (2 hours)

**Current:**
```dart
Card(
  child: Column(
    children: [
      Text('Pay ${payee}'),
      Text('₹$amount'),
      ElevatedButton('Pay via UPI'),
    ],
  ),
)
```

**New:**
```dart
GlassCard(
  padding: EdgeInsets.all(20),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pay ${payee}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    upiId,
                    style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
          AnimatedNumber(
            value: amount,
            prefix: '₹',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      SizedBox(height: 16),
      Container(height: 1, color: Colors.black.withOpacity(0.06)),
      SizedBox(height: 16),
      Column(
        children: [
          TapScale(
            enableHaptic: true,
            child: ElevatedButton(
              onPressed: onPayViaUPI,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colorPrimary,
                minimumSize: Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Pay via UPI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  SizedBox(width: 8),
                  Text('↗', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          SizedBox(height: 8),
          OutlinedButton(
            onPressed: onMarkAsPaid,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, 48),
              side: BorderSide(color: Colors.black.withOpacity(0.1), width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Mark as paid', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    ],
  ),
)
```

#### Step 3: Style Incoming Payments (1.5 hours)

**New:**
```dart
// Confirmed payments
GlassCard(
  padding: EdgeInsets.all(16),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('From ${payer}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Row(
            children: [
              Text('✓', style: TextStyle(fontSize: 12)),
              SizedBox(width: 6),
              Text('Confirmed', style: TextStyle(fontSize: 13, color: Color(0xFF047857))),
            ],
          ),
        ],
      ),
      AnimatedNumber(
        value: amount,
        prefix: '₹',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Color(0xFF10B981)),
      ),
    ],
  ),
)

// Pending confirmation
GlassCard(
  padding: EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('From ${payer}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          AnimatedNumber(value: amount, prefix: '₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        ],
      ),
      SizedBox(height: 12),
      Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Awaiting your confirmation',
          style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
        ),
      ),
      SizedBox(height: 12),
      TapScale(
        child: ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colorPrimary,
            minimumSize: Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('Confirm received', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ),
    ],
  ),
)
```

#### Step 4: Add Card Stagger (1 hour)

**New:**
```dart
ListView.builder(
  itemCount: paymentCards.length,
  itemBuilder: (context, index) {
    return StaggeredListItem(
      index: index,
      child: Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: paymentCards[index],
      ),
    );
  },
)
```

### Testing Checklist for SettlementConfirmation

- [ ] Progress banner visible at top
- [ ] Payment cards stagger on load
- [ ] UPI button clearly primary (dark bg)
- [ ] Mark as paid clearly secondary (outline)
- [ ] Confirmed vs pending visually distinct
- [ ] All buttons have TapScale
- [ ] GlassCard visible in light/dark mode

---

## Screen #4-20: Quick Migration Notes

### GroupsList
- Wrap each group in `TapScale`
- Add stagger animation to list
- Make FAB more prominent (56×56, shadow)
- Use GlassCard for invitation cards

### CreateGroup
- GlassCard for form container
- Increase button padding to 16×24
- Add haptic on "Create" button
- Animate rhythm/day selector changes

### Profile
- Section headers: 11px uppercase
- Use GlassCard for payment settings
- Theme toggle already animated (keep it)
- Group settings into visual sections

### EditExpense
- Same as ExpenseInput
- GlassCard for form
- AnimatedNumber for amount field
- TapScale on Save button

### CycleHistory / CycleHistoryDetail
- Stagger list items
- GlassCard for individual cycles
- AnimatedNumber for amounts
- 1px separators (not gaps)

### PaymentResult
- SUCCESS: Scale animation on checkmark (elastic curve, 400ms)
- Add haptic on success
- GlassCard for result container

### EmptyStates / ErrorStates
- FadeIn animation (280ms)
- Center content
- Make CTA buttons more prominent

### PhoneAuth / OnboardingName
- AnimatedSwitcher for step transitions
- GlassCard for input containers
- Haptic on submit

---

## Post-Migration Checklist (All Screens)

After migrating each screen:

- [ ] GlassCard used for all major containers
- [ ] Border radius: 16px cards, 8px buttons
- [ ] Borders: 1px (not 0.5px)
- [ ] Typography: 36px amounts, 15px body, 11px labels
- [ ] Spacing: 20px horizontal, 24px card padding, 16×24 buttons
- [ ] All buttons wrapped in TapScale
- [ ] Haptics on primary actions
- [ ] AnimatedNumber for all amounts
- [ ] Lists use stagger animation
- [ ] Dark mode tested
- [ ] Hover states on list items
- [ ] No hardcoded colors (use context.colorXxx)

---

## Common Pitfalls & Solutions

### Issue: BackdropFilter not working
**Solution:** Ensure parent has transparent background, not solid color

### Issue: Stagger animation stutters
**Solution:** Cap delay at 500ms (`min(index * 50, 500)`)

### Issue: GlassCard invisible in dark mode
**Solution:** Adjust opacity: light 70%, dark 90%

### Issue: AnimatedNumber jumps
**Solution:** Use `TweenAnimationBuilder` with proper begin/end values

### Issue: TapScale not responsive
**Solution:** Wrap button directly, not parent container

---

## Testing Protocol

For each migrated screen:

1. **Visual audit** — Compare to mockup pixel-by-pixel
2. **Interaction audit** — Press every button, verify scale + haptic
3. **Animation audit** — Check all transitions (200-300ms)
4. **Dark mode audit** — Toggle theme, verify glassmorphism visible
5. **Performance audit** — No jank, smooth 60fps
6. **Accessibility audit** — Test with screen reader

---

## Timeline & Progress Tracking

| Week | Screens | Status |
|------|---------|--------|
| 1 | GroupDetail, ExpenseInput, SettlementConfirmation | Not Started |
| 2 | GroupsList, CreateGroup, InviteMembers | Not Started |
| 3 | Profile, EditExpense, CycleHistory, GroupMembers | Not Started |
| 4 | PaymentResult, CycleSettled, PhoneAuth, OnboardingName, Edge cases | Not Started |

---

**Document version:** 1.0  
**Last updated:** March 18, 2026  
**Next review:** After Week 1 completion
