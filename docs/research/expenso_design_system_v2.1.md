# Expenso Design System v2.1 (Research Edition)
**Clean. Modern. Crisp. Interactive.**

Based on 2025/2026 UI/UX research + fintech best practices

Last updated: March 18, 2026

---

## Research Summary

After analyzing 30+ sources on mobile UI trends (2025/2026) and fintech UX best practices, here are the **non-negotiable principles** for modern, interactive apps:

### Key Findings

**What users expect in 2025/2026:**
1. **Glassmorphism** — translucent, frosted-glass surfaces create depth while maintaining minimalism
2. **Micro-interactions** — subtle animations (200-500ms) that provide instant feedback and build trust
3. **Rounded corners** — soft, approachable edges (reflecting warmth and human-centric design)
4. **Bottom navigation** — essential for larger screens and one-handed use
5. **Minimalist with purpose** — clean layouts with bold accents, generous whitespace, intentional details
6. **Passwordless auth** — biometrics, OTP as standard (81% of users prefer biometrics)
7. **Real-time feedback** — instant confirmations, haptics, progress indicators (critical for fintech)
8. **Card-based layouts** — bento grids, swipeable cards for efficient content scanning

**What kills trust in fintech apps:**
- Cluttered layouts, slow load times, weak security cues, confusing navigation
- 53% of users abandon apps that take >3s to load; 88% won't return after a bad experience
- Errors without clear recovery paths hurt retention

**Fintech-specific requirements:**
- Real-time notifications, clean minimal layout, key info front-and-center
- Clear permission screens showing exactly what data is shared
- Grouped, color-coded cards for expenses/investments/savings
- Microinteractions for every action (loading bars, confirmations, animations)
- Trustworthy + approachable palette (not cold corporate)

---

## Design Philosophy (Revised)

**Three words that define Expenso:**
1. **Clean** — Glassmorphic surfaces, generous whitespace, zero visual noise
2. **Modern** — Rounded corners, fluid animations, bottom nav, 2025 aesthetics
3. **Interactive** — Every tap feels alive through micro-interactions and haptics

**Visual Principles:**
- **Numbers are heroes** — Always the biggest, boldest element
- **Glass over gradients** — Translucent frosted layers create depth without noise
- **Motion = feedback** — Every action gets a response (200-300ms animations)
- **Rounded = approachable** — 12-16px radii on cards, 8px on buttons
- **Trust through clarity** — Security is visible, errors are recoverable
- **Progressive disclosure** — Show what matters, hide complexity

---

## Foundation Tokens (Research-Backed)

### Color Palette (Glassmorphism-Ready)

#### Light Mode
```dart
// Primary
const primary = Color(0xFF1A1A1A);          // Black - CTAs, headlines
const primaryVariant = Color(0xFF3A3A3A);   // Dark gray

// Text Hierarchy (High Contrast for Readability)
const textPrimary = Color(0xFF0A0A0A);      // Near-black for maximum contrast
const textSecondary = Color(0xFF6B6B6B);    // Mid-gray
const textTertiary = Color(0xFF9B9B9B);     // Light gray for hints
const textDisabled = Color(0xFFB0B0B0);

// Backgrounds (Layered for Glassmorphism)
const background = Color(0xFFF8F9FA);       // Soft gray (not pure white)
const surface = Color(0xFFFFFFFF);          // Card surfaces
const surfaceGlass = Color(0xF0FFFFFF);     // Frosted glass (94% opacity)
const surfaceVariant = Color(0xFFF5F6F7);   // Secondary surfaces

// Borders (Subtle, Glassmorphic)
const border = Color(0x18000000);           // 9% opacity black
const borderInput = Color(0x30000000);      // 19% opacity for inputs
const borderFocused = Color(0xFF1A1A1A);    // Solid on focus

// Semantic (Fintech Trust Colors)
const success = Color(0xFF10B981);          // Modern green (not dark forest)
const successLight = Color(0xFF6EE7B7);
const successBackground = Color(0xFFD1FAE5);

const error = Color(0xFFEF4444);            // Bright red (urgent but not alarming)
const errorBackground = Color(0xFFFEE2E2);

const warning = Color(0xFFF59E0B);          // Amber
const warningBackground = Color(0xFFFEF3C7);

const info = Color(0xFF3B82F6);             // Trust blue
const infoBackground = Color(0xFFDBEAFE);

// Glassmorphic Overlays
const glassFrost = Color(0x80FFFFFF);       // 50% white for blur effect
const glassShadow = Color(0x0A000000);      // Subtle shadow (4% opacity)
```

#### Dark Mode
```dart
// Primary
const primary = Color(0xFFE5E5E5);
const primaryVariant = Color(0xFFB0B0B0);

// Text
const textPrimary = Color(0xFFF5F5F5);
const textSecondary = Color(0xFFB0B0B0);
const textTertiary = Color(0xFF808080);

// Backgrounds (Dark Glassmorphism)
const background = Color(0xFF0A0A0A);       // Near-black
const backgroundGradient = Color(0xFF121216); // Subtle gradient end
const surface = Color(0xFF1A1A1E);          // Cards
const surfaceGlass = Color(0xE61A1A1E);     // Frosted glass (90% opacity)
const surfaceVariant = Color(0xFF232329);

// Borders (Lighter in Dark Mode)
const border = Color(0x20FFFFFF);           // 13% white
const borderInput = Color(0x35FFFFFF);      // 21% white
const borderFocused = Color(0xFFE5E5E5);

// Semantic (Adjusted for Dark)
const success = Color(0xFF34D399);
const error = Color(0xFFF87171);
const warning = Color(0xFFFBBF24);
const info = Color(0xFF60A5FA);

// Glassmorphic Overlays
const glassFrost = Color(0x401A1A1E);       // 25% surface for frost
const glassShadow = Color(0x40000000);      // Stronger shadow (25%)
```

### Typography Scale (Modern, Readable)

```dart
// Display (Amounts, Big Numbers)
const displayLarge = TextStyle(
  fontSize: 36,                    // Bigger than before
  fontWeight: FontWeight.w600,      // Medium-bold (not 500)
  height: 1.1,
  letterSpacing: -0.8,
);

const displayMedium = TextStyle(
  fontSize: 28,
  fontWeight: FontWeight.w600,
  height: 1.2,
  letterSpacing: -0.5,
);

// Headings (Softer than Display)
const headingLarge = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w500,      // Back to 500 for headings
  height: 1.3,
);

const headingMedium = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w500,
  height: 1.3,
);

// Body (Highly Readable)
const bodyLarge = TextStyle(
  fontSize: 17,                    // iOS standard (up from 16)
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const bodyMedium = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

// Labels
const labelLarge = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 1.4,
);

const labelSmall = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,     // Slightly bolder for tiny text
  height: 1.3,
  letterSpacing: 0.4,
);
```

### Spacing System (Refined)

```dart
// Base scale (8pt grid)
const space4 = 4.0;
const space8 = 8.0;
const space12 = 12.0;
const space16 = 16.0;
const space20 = 20.0;
const space24 = 24.0;
const space32 = 32.0;

// Semantic spacing
const screenPaddingH = 20.0;
const screenPaddingTop = 16.0;      // Tighter (was 20)
const cardPadding = 20.0;
const cardGap = 16.0;               // Increased from 12
const listItemPaddingV = 16.0;
const listItemPaddingH = 20.0;
const buttonPaddingV = 16.0;        // Increased from 14
const buttonPaddingH = 24.0;        // Increased from 20
```

### Border Radius (Rounded, Modern)

```dart
const radiusSmall = 8.0;            // Buttons, badges (up from 6)
const radiusMedium = 12.0;          // Cards (unchanged)
const radiusLarge = 16.0;           // Major containers (unchanged)
const radiusXL = 20.0;              // Modals, sheets (up from 16)
const radiusFull = 999.0;           // Pills, circles
```

### Glassmorphic Effects

```dart
// Frosted Glass Card
BoxDecoration glassCard = BoxDecoration(
  color: surfaceGlass,              // 94% opacity white
  borderRadius: BorderRadius.circular(radiusMedium),
  border: Border.all(color: border, width: 1),
  boxShadow: [
    BoxShadow(
      color: glassShadow,
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ],
);

// Backdrop Blur (requires BackdropFilter widget)
BackdropFilter(
  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
  child: Container(
    decoration: BoxDecoration(
      color: glassFrost,
      borderRadius: BorderRadius.circular(radiusMedium),
    ),
  ),
)
```

---

## Component Library (Interactive, Modern)

### 1. Glass Status Card (Your Balance)

**Research:** Grouped, color-coded cards with clear visual hierarchy

**Specs:**
- Background: Glassmorphic (frosted with blur)
- Border: 1px subtle (not 0.5px)
- Border radius: `radiusLarge` (16px)
- Padding: 24px (more generous)
- Shadow: Soft, elevated (blurRadius: 20)
- Micro-interaction: Subtle scale on tap (0.98, 120ms)

```dart
BackdropFilter(
  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
  child: TapScale(  // Micro-interaction
    child: Container(
      decoration: BoxDecoration(
        color: surfaceGlass,
        borderRadius: BorderRadius.circular(radiusLarge),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: glassShadow,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR STATUS', style: labelSmall.copyWith(color: textTertiary)),
          SizedBox(height: 8),
          AnimatedSwitcher(  // Smooth number transitions
            duration: Duration(milliseconds: 300),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('₹2,340', style: displayLarge.copyWith(color: success)),
                SizedBox(width: 8),
                Text('credit', style: bodyMedium.copyWith(color: textSecondary)),
              ],
            ),
          ),
          // ... rest of card
        ],
      ),
    ),
  ),
)
```

### 2. Interactive Expense List Item

**Research:** Button animations, swipe gestures, instant feedback

**Specs:**
- Background: Surface white
- Padding: 16px vertical, 20px horizontal
- Border radius: 12px (on parent container)
- Tap: Scale to 0.98 + haptic (80ms)
- Swipe: Reveal actions (edit/delete) with spring animation
- Separator: 1px between items

```dart
TapScale(
  onTap: () {
    HapticFeedback.lightImpact();
    Navigator.push(...);
  },
  child: Container(
    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    decoration: BoxDecoration(
      color: surface,
      border: Border(bottom: BorderSide(color: border, width: 1)),
    ),
    child: Row(
      children: [
        // Animated avatar/icon
        Hero(
          tag: 'expense-${expense.id}',
          child: Container(...),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(expense.description, style: bodyMedium.copyWith(fontWeight: FontWeight.w500)),
              SizedBox(height: 4),
              Text('Paid by ${expense.payer}', style: labelLarge.copyWith(color: textSecondary)),
            ],
          ),
        ),
        // Animated amount counter
        AnimatedNumber(
          value: expense.amount,
          style: bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  ),
)
```

### 3. Modern Primary Button

**Research:** Button animations confirm action, 200-500ms duration

**Specs:**
- Background: Primary black (light) / Primary white (dark)
- Border radius: `radiusSmall` (8px)
- Padding: 16px × 24px (increased)
- Font: `bodyMedium` (15px, weight 600)
- Press: Scale 0.96 + haptic (100ms)
- Loading: Spinner with pulse animation

```dart
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 100),
      transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
      child: ElevatedButton(
        onPressed: loading ? null : () {
          HapticFeedback.mediumImpact();
          onPressed?.call();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colorPrimary,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          elevation: 0,
        ),
        child: loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label, style: bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
```

### 4. Floating Action Button (Bottom Navigation)

**Research:** Bottom navigation essential for modern apps, one-handed use

**Specs:**
- Position: Bottom-right, 16px from edge
- Size: 56×56 (Material standard)
- Border radius: `radiusFull`
- Shadow: Elevated (blurRadius: 12)
- Icon: 24px
- Press: Scale 0.9 + haptic + rotation (120ms)

```dart
Positioned(
  bottom: 16 + MediaQuery.of(context).padding.bottom,
  right: 16,
  child: TapScale(
    targetScale: 0.9,
    onTap: () {
      HapticFeedback.heavyImpact();
      Navigator.pushNamed(context, '/expense-input');
    },
    child: Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: context.colorPrimary,
        borderRadius: BorderRadius.circular(radiusFull),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(Icons.add, size: 24, color: Colors.white),
    ),
  ),
)
```

### 5. Bottom Navigation Bar

**Research:** Bottom nav is becoming critical for larger screens

```dart
BottomNavigationBar(
  currentIndex: _selectedIndex,
  onTap: (index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  },
  items: [
    BottomNavigationBarItem(
      icon: Icon(Icons.receipt_long),
      label: 'Expenses',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.account_balance_wallet),
      label: 'Balances',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.history),
      label: 'History',
    ),
  ],
  selectedItemColor: context.colorPrimary,
  unselectedItemColor: context.colorTextTertiary,
  showUnselectedLabels: true,
  type: BottomNavigationBarType.fixed,
  elevation: 8,
  backgroundColor: context.colorSurface,
)
```

### 6. Micro-Interaction: Success Checkmark

**Research:** Celebratory animations reinforce desired behavior

```dart
class SuccessCheckmark extends StatefulWidget {
  @override
  _SuccessCheckmarkState createState() => _SuccessCheckmarkState();
}

class _SuccessCheckmarkState extends State<SuccessCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    _controller.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: success,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check, size: 48, color: Colors.white),
      ),
    );
  }
}
```

### 7. Smart Loading States (Skeleton + Shimmer)

**Research:** 53% of users abandon slow apps; loading states critical

```dart
// Use existing SkeletonShimmer but with glassmorphic styling
Shimmer.fromColors(
  baseColor: surface,
  highlightColor: surfaceGlass,
  child: Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radiusMedium),
      border: Border.all(color: border, width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 100, height: 12, color: Colors.white),
        SizedBox(height: 8),
        Container(width: double.infinity, height: 32, color: Colors.white),
      ],
    ),
  ),
)
```

---

## Animation Standards (Research-Based)

### Timing (Industry Standard)

**Research:** Ideal micro-interaction duration: 200-500ms

```dart
// Micro-interactions (feedback)
const microFast = Duration(milliseconds: 80);    // Button press
const microMedium = Duration(milliseconds: 200); // State change
const microSlow = Duration(milliseconds: 300);   // Number counter

// Transitions (page/modal)
const transitionFast = Duration(milliseconds: 250);
const transitionMedium = Duration(milliseconds: 350);

// Celebrations (success moments)
const celebration = Duration(milliseconds: 400);
```

### Curves (Expressive)

```dart
const easeOutCubic = Curves.easeOutCubic;     // Default exit
const easeInOutCubic = Curves.easeInOutCubic; // State transitions
const elasticOut = Curves.elasticOut;         // Success moments
const spring = Curves.fastOutSlowIn;          // Natural motion
```

### Haptic Feedback Map

**Research:** Haptic feedback for every user action in fintech

```dart
// Primary actions
HapticFeedback.mediumImpact()  // Confirm, Submit, Pay
HapticFeedback.heavyImpact()   // Success, Add expense (FAB)
HapticFeedback.lightImpact()   // Secondary buttons, taps
HapticFeedback.selectionClick() // Tab changes, toggles
```

### Stagger Animations (Lists)

```dart
// Delay calculation
int delayMs(int index) => min(index * 50, 500); // Cap at 500ms

// Implementation
@override
Widget build(BuildContext context) {
  return AnimatedList(
    initialItemCount: items.length,
    itemBuilder: (context, index, animation) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Interval(
            delayMs(index) / 1000,
            1.0,
            curve: easeOutCubic,
          ),
        )),
        child: FadeTransition(
          opacity: animation,
          child: ExpenseListItem(expense: items[index]),
        ),
      );
    },
  );
}
```

---

## Screen Templates (Modern Layouts)

### Template 1: Glass Card Detail Screen (GroupDetail)

**Research:** Clean, layered, key metrics front-and-center

```
┌─────────────────────────────────┐
│ ← Back    Goa Trip              │  <- Glassmorphic header
│           Active · 3 of 4       │
│                                 │
│ [Glass Status Card]             │  <- Frosted, blurred
│ ┌─────────────────────────┐    │
│ │ YOUR STATUS             │    │
│ │ ₹2,340 credit           │    │
│ │ ─────────────────       │    │
│ │ Cycle total | You spent │    │
│ └─────────────────────────┘    │
│                                 │
│ [Settle up] [💳]                │  <- Bottom-aligned CTAs
│                                 │
│ RECENT EXPENSES          [+Add] │
│ ┌─────────────────────────┐    │
│ │ Dinner · Rahul    ₹3200 │    │
│ │ Scooter · You     ₹800  │    │
│ └─────────────────────────┘    │
│                                 │
│                         [FAB]   │  <- Bottom-right
└─────────────────────────────────┘
```

### Template 2: Bottom Nav + Tabs (Multi-View)

**Research:** Bottom navigation for multi-directional flows

```
┌─────────────────────────────────┐
│ Group Detail                    │
│                                 │
│ [Expenses] [Balances] [History] │  <- Segmented control
│                                 │
│ [Content based on selected tab] │
│                                 │
│                                 │
│                                 │
│ ┌───────────────────────────┐  │
│ │ ⊡ Expenses | ⊡ Groups | 👤 │  │  <- Bottom nav
│ └───────────────────────────┘  │
└─────────────────────────────────┘
```

---

## Implementation Checklist (Updated)

For every screen, verify:

- [ ] Uses glassmorphic surfaces (BackdropFilter + frosted container)
- [ ] Border radius: 12-16px on cards, 8px on buttons
- [ ] All borders are 1px (not 0.5px)
- [ ] Micro-interactions on all primary actions (scale + haptic)
- [ ] Loading states use shimmer with glassmorphic styling
- [ ] Numbers animate on change (AnimatedSwitcher or custom counter)
- [ ] Lists use stagger animation on entry
- [ ] Bottom navigation for multi-section apps
- [ ] Success moments have celebratory animation (scale + elastic)
- [ ] Haptic feedback on every tap
- [ ] Spacing uses 8pt grid (8, 16, 24, 32)
- [ ] Typography: displayLarge (36px) for amounts, bodyMedium (15px) for text
- [ ] Dark mode tested with glassmorphism

---

## Migration Priority (Research-Driven)

### Phase 1: Foundation (Week 1)
1. Update color tokens with glassmorphic values
2. Add BackdropFilter widget wrapper
3. Update border radius across all components
4. Increase button padding (16×24)

### Phase 2: Micro-Interactions (Week 1-2)
1. Wrap all buttons in TapScale widget
2. Add haptics to primary actions
3. Implement stagger animation for lists
4. Add success checkmark animation

### Phase 3: Core Screens (Week 2-3)
1. GroupDetail (glassmorphic status card + staggered list)
2. ExpenseInput (animated form + Magic Bar highlight)
3. SettlementConfirmation (real-time progress + confirmations)

### Phase 4: Polish (Week 3-4)
1. Number counter animations
2. Bottom navigation bar
3. Loading skeleton with shimmer
4. Dark mode glassmorphism audit

---

## Design References

**Inspiration (from research):**
- Revolut: sleek, fast, layered navigation, sharp micro-interactions
- Mono: clean, intentional structure, gamification
- Chime: real-time alerts, intuitive navigation, clean home screen
- Apple iOS 26: "Liquid Glass" aesthetic, translucent fluid effects

---

## What NOT to Do

**Avoid:**
- ❌ Flat cards without glassmorphism (feels dated in 2025)
- ❌ Sharp corners on cards (rounded = modern + approachable)
- ❌ Actions without haptic feedback (feels unresponsive)
- ❌ Instant state changes (needs 200-300ms transition)
- ❌ Top-only navigation (bottom nav is standard now)
- ❌ Pure white backgrounds (soft gray reduces eye strain)
- ❌ Border thinner than 1px (too subtle on high-DPI screens)
- ❌ Complex gradients (glassmorphism replaced gradients)

**Do:**
- ✅ Frosted glass cards with blur
- ✅ Rounded corners everywhere (12-16px)
- ✅ Haptics + scale on every tap
- ✅ Smooth 200-300ms animations
- ✅ Bottom navigation for sections
- ✅ Soft gray backgrounds (#F8F9FA)
- ✅ 1px borders with subtle opacity
- ✅ Simple glassmorphic overlays

---

## Research Citations

This design system incorporates findings from:
- Mobile UI/UX trends (2025/2026): minimalism, glassmorphism, rounded corners, bottom nav
- Fintech UX best practices: trust cues, real-time feedback, micro-interactions
- Micro-interaction research: 200-500ms timing, haptics, instant feedback
- Banking app design: clean layouts, color-coded cards, progressive disclosure

**Document version:** 2.1 (Research Edition)  
**Last audit:** March 18, 2026  
**Next review:** After Phase 2 completion
