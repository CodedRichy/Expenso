# Expenso – Monetization Strategy & Execution Guide

**Document Type**: Internal Product Strategy  
**Version**: 2.0  
**Created**: February 2026  
**Status**: Active  
**Audience**: Product owner, future contributors

---

## Quick Reference — What You Need to Know

| Topic | Decision |
|-------|----------|
| **When to monetize** | After 5K MAU with 40%+ 30-day retention |
| **Pricing** | ₹29/month · ₹249/year · ₹499 lifetime (first 500 only) |
| **Plus v1 features** | Smart Reminders (ship first), Export PDF/CSV (ship second) |
| **Plus v2 features** | Expense Templates (deferred) |
| **Never monetize** | Core tracking, groups, invites, settlements, UPI links, sync |
| **Revenue target** | ₹50K–1L/year at 50K MAU (use 0.5% conversion for planning) |
| **Play Store cut** | 15-30% — factor into all projections |

---

## Purpose

This document contains:

1. **Finalized monetization decisions** — what's settled, don't re-debate
2. **Implementation specifications** — pricing, features, paywall triggers
3. **Stress-test prompt** — for validating future monetization ideas
4. **Interpretation guide** — to avoid blindly trusting AI responses
5. **Pre-launch checklist** — everything to verify before going live

This is an internal execution document, not marketing material.

---

## Section 1: Finalized Monetization Decisions

These decisions are **locked**. Do not re-debate unless user research contradicts them.

### Core Principles

| Principle | Rationale |
|-----------|-----------|
| Core tracking is free forever | Trust, retention, virality — gating basics kills the app |
| No ads, ever | Ads destroy trust in financial utilities |
| Monetize convenience, not access | Users pay to save time/friction, not to unlock basics |
| Soft paywalls only | Never block a core flow; always allow dismissal |
| India-first pricing | Western pricing fails here; benchmark against local apps |

### Pricing Structure (Final)

| Tier | Price | Justification |
|------|-------|---------------|
| **Monthly** | ₹29/month | Less than a chai. Impulse-buy territory. |
| **Annual** | ₹249/year (₹20.75/mo) | One movie ticket. 28% savings creates urgency. |
| **Lifetime** | ₹499 one-time | One nice dinner. **Limited to first 500 buyers**, then sunset. |

**Why limit lifetime**: Prevents cannibalization of recurring revenue. Creates urgency. After 500 sold or 6 months post-launch (whichever first), remove the option.

### Pricing Display (UI Spec)

```
┌─────────────────────────────────────┐
│         Expenso Plus                │
│                                     │
│    ₹249/year  ← BEST VALUE          │
│    (save 28%)                       │
│                                     │
│         or ₹29/month                │
│                                     │
│  [Get Plus]                         │
│                                     │
│  ₹499 one-time (limited offer)      │
│  [X of 500 remaining]               │
└─────────────────────────────────────┘
```

### What to Never Monetize

| Feature | Reason |
|---------|--------|
| Expense creation | Core value proposition |
| Group creation (unlimited) | Virality depends on free groups |
| Member invites | Network effects |
| Basic settlement view | Core utility |
| UPI deep-links for payment | Differentiator vs Splitwise |
| Sync/backup | Expected baseline; charging feels like hostage-taking |
| Dark mode | Commoditized |
| Basic notifications | "You were added to a group" must be free |
| Expense editing/deletion | Core data hygiene |

---

## Section 2: Expenso Plus v1 — Feature Specification

**Constraint**: Maximum 2 features for v1. Ship lean, validate, iterate.

### Feature 1: Smart Payment Reminders (Ship First)

**What it does**:  
Automatically sends in-app nudges to group members with outstanding balances.

**User controls**:
- Reminder frequency: every 3 days / weekly / custom
- Tone: friendly / neutral / direct
- Auto-stop when settled

**Why it converts**:  
Chasing money is socially awkward. Users pay to outsource this discomfort.

**Implementation notes**:
- Local notifications + optional push
- Message format: "Rahul, you owe ₹340 to the Goa Trip group"
- Settings: enable/disable per group
- Dev effort: Low

**Paywall trigger**:  
When user taps "Remind" on an unsettled balance for the **2nd time**:

```
┌─────────────────────────────────────┐
│  🔔 Tired of chasing payments?     │
│                                     │
│  Expenso Plus sends automatic       │
│  reminders so you don't have to.    │
│                                     │
│  [Enable Plus — ₹29/month]          │
│                                     │
│  Maybe later                        │
└─────────────────────────────────────┘
```

---

### Feature 2: Settlement History Export (Ship Second)

**What it does**:  
Export full settlement history as PDF (formatted) or CSV (raw data).

**Export includes**:
- Group name, members
- All expenses with payer, split, date
- Final balances
- Settlement status

**Why it converts**:
- Flatmate leaving → need final settlement proof
- Trip ends → want clean summary to share
- Tax/reimbursement → need formal records

**Implementation notes**:
- PDF: formatted, branded, shareable
- CSV: raw data for spreadsheet users
- **1 free export per account lifetime** (demonstrates value)
- Dev effort: Low-Medium

**Paywall trigger**:  
When user taps "Export" or "Share Summary" **after using their 1 free export**:

```
┌─────────────────────────────────────┐
│  📄 Export your settlement history  │
│                                     │
│  Get PDF and CSV exports with       │
│  Expenso Plus.                      │
│                                     │
│  [Get Plus — ₹29/month]             │
│                                     │
│  Not now                            │
└─────────────────────────────────────┘
```

---

### Feature 3: Expense Templates (Deferred to v2)

**Status**: Not in v1. Build after validating Reminders + Export.

**Reason for deferral**:
- Smaller target segment (power users only)
- Higher dev effort (fuzzy matching is complex)
- Less clear paywall moment

**v2 approach** (when ready):
- Manual "Save as template" button (not auto-detection)
- Clearer paywall trigger: user explicitly wants to save
- Simpler implementation

---

## Section 3: Paywall Behavior Specification

### Principles

1. **Never block core actions** — expense creation, settling, viewing balances
2. **Trigger on pain, not entry** — show paywall when user feels friction
3. **One paywall per session max** — if dismissed, don't show again for 7 days
4. **Soft dismiss always available** — no forced decisions
5. **No paywalls on app launch** — ever

### Trigger Matrix

| User Action | Paywall? | Condition |
|-------------|----------|-----------|
| Tap "Remind" on unsettled balance | Yes | 2nd reminder on same balance |
| Tap "Export" or "Share Summary" | Yes | After 1 free export used |
| Open app | **No** | Never |
| Create group | **No** | Never |
| Invite member | **No** | Never |
| Add expense | **No** | Never |
| View settlement | **No** | Never |
| Use UPI deep-link | **No** | Never |

### Paywall UI Specification

**Format**: Bottom sheet (not full-screen modal)  
**Tone**: Helpful, not desperate  
**Animation**: Subtle slide-up  
**Dismiss**: Always visible, subtle styling

**Copy formula**:
```
[Icon: relevant to feature]
[Headline: 6 words max, benefit-focused]
[Subhead: 1 sentence explaining value]
[Primary CTA: Get Plus — ₹29/month]
[Secondary link: View all Plus features]
[Dismiss: Maybe later / Not now]
```

### Dismiss Behavior

| Action | Result |
|--------|--------|
| Tap dismiss | Close paywall, don't show again for 7 days |
| Tap outside sheet | Same as dismiss |
| Complete purchase | Close paywall, unlock feature |
| View all features | Navigate to Plus info screen |

---

## Section 4: Stage-Wise Rollout Plan

### Stage 1: Pre-Monetization (0 → 5K MAU)

**Goal**: Prove retention, not revenue.

| Do | Don't |
|----|-------|
| Ship fully-functional free app | Add any paywalls |
| Instrument analytics (expense frequency, group size, settlement rate) | Show "upgrade" prompts |
| Define "power user" (>10 expenses/month OR >3 active groups) | Add ads |
| Collect qualitative feedback | Optimize for revenue |

**Exit criteria**: 5K MAU with >40% 30-day retention

---

### Stage 2: Soft Monetization (5K → 25K MAU)

**Goal**: Test willingness-to-pay with low friction.

| Action | Details |
|--------|---------|
| Add "Support Expenso" tip jar | One-time ₹49, ₹99, ₹199. No features. Pure gratitude. |
| Launch Plus beta (invite-only) | Top 5% power users. Test pricing. |
| A/B test paywall triggers | Measure conversion at different touchpoints |
| Add Plus badge | Visible in groups for social proof |

**Exit criteria**: >1% conversion on tip jar or Plus beta

---

### Stage 3: Full Monetization (25K+ MAU)

**Goal**: Scale revenue while maintaining trust.

| Stream | Priority |
|--------|----------|
| Expenso Plus subscription | Primary |
| Lifetime purchase (limited) | Secondary |
| Group Premium (one pays, all benefit) | Future consideration |

---

## Section 5: Revenue Projections (Conservative)

### Assumptions (Use These for Planning)

| Variable | Conservative | Notes |
|----------|--------------|-------|
| Conversion rate | **0.5%** of MAU | Not 0.75% — use lower bound |
| Revenue mix | 60% annual, 30% monthly, 10% lifetime | |
| Monthly churn | 10% | |
| Annual churn | 30% | |
| Play Store cut | **15-30%** | Reduces effective revenue |

### Projections (After Play Store Cut)

Assuming 15% Play Store cut (small developer rate):

| MAU | Paying Users (0.5%) | Gross Monthly | Net Monthly (85%) | Net Annual |
|-----|---------------------|---------------|-------------------|------------|
| 25K | 125 | ₹2,900 | ₹2,465 | ₹29,580 |
| 50K | 250 | ₹5,800 | ₹4,930 | ₹59,160 |
| 100K | 500 | ₹11,600 | ₹9,860 | ₹1,18,320 |
| 200K | 1,000 | ₹23,200 | ₹19,720 | ₹2,36,640 |

### Reality Check

| Scale | Net Annual Revenue | What It Means |
|-------|-------------------|---------------|
| 50K MAU | ~₹60K ($720) | Covers hosting, minimal income |
| 100K MAU | ~₹1.2L ($1,440) | Meaningful side income |
| 200K MAU | ~₹2.4L ($2,880) | Sustainable solo project |
| 500K MAU | ~₹6L ($7,200) | Part-time salary equivalent |

**Bottom line**: This is a lifestyle business. Revenue covers costs and provides modest income. That's the realistic goal.

---

## Section 6: Pre-Launch Checklist

Complete all items before enabling monetization:

### Technical

- [ ] Subscription flow works (Play Store billing)
- [ ] Subscription restore works (user reinstalls app)
- [ ] Lifetime purchase tracked correctly (one-time, permanent)
- [ ] Paywall UI renders correctly on low-end Android
- [ ] Free export counter persists across reinstalls (tied to account, not device)
- [ ] Feature flags for Plus features work correctly
- [ ] Analytics tracks: paywall views, conversions, dismissals

### Legal/Policy

- [ ] Privacy policy updated for payment data handling
- [ ] Refund policy documented (7-day, no questions asked)
- [ ] Terms of service include subscription terms
- [ ] Play Store listing updated with IAP disclosure

### Support

- [ ] Support email ready
- [ ] FAQ for common billing questions
- [ ] Process for handling refund requests

### Operational

- [ ] Lifetime purchase counter visible in admin/analytics
- [ ] Alert when lifetime purchases hit 400 (prepare to sunset)
- [ ] Churn tracking dashboard ready

---

## Section 7: Known Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Users perceive app as "greedy" | Medium | Clear messaging: "Core is free forever. Plus is optional." |
| Plus features don't convert | Medium | Start with highest-pain feature (Reminders). Pivot if needed. |
| Lifetime buyers spike, hurt LTV | Low-Medium | Cap at 500, then sunset |
| Play Store billing bugs | Low | Test extensively; have Razorpay fallback for web |
| Competition undercuts price | Low | Compete on UX quality, not price |
| Churn higher than projected | Medium | Monthly monitoring; improve value prop if needed |

---

## Section 8: The Stress-Test Prompt

Use this prompt as-is when you need to:
- Validate monetization decisions
- Get a second opinion on pricing
- Stress-test a new paid feature idea
- Sanity-check paywall triggers

### The Prompt

```
You are a senior product manager and monetization expert who has built and monetized consumer fintech/utility apps in India as a solo developer or small team.

Context:
I am building Expenso, a closed-source, mobile-first group expense management app (similar to Splitwise) with strong ledger integrity and settlement logic.

Constraints (assume all are true):
- India-first, price-sensitive users
- Solo developer, minimal monthly burn
- Core expense tracking must remain free forever
- Monetization must be ethical, low-friction, and trust-preserving
- Goal is sustainability and steady income, not VC-scale growth

Known truths (do not debate these):
- Expense apps are low-ARPU utilities
- Typical paid conversion is ~1–3%
- Users pay to reduce social friction, mental load, and time—not for basic tracking
- Splitwise monetizes tracking friction but under-monetizes settlement and group control

Task:
1. Propose a stage-wise monetization plan suitable for a solo developer.
2. Define Expenso Plus v1 with no more than 3 paid features, chosen for highest ROI.
3. Specify exact behavioral triggers for paywalls (what user action causes it).
4. Recommend India-appropriate pricing (monthly, yearly, optional lifetime) and justify psychologically.
5. Clearly list what should never be monetized and why.
6. Provide realistic revenue expectations (conservative assumptions only).

Output rules:
- Be blunt and execution-focused
- No startup buzzwords
- No VC or unicorn assumptions
- Assume users are skeptical and price-sensitive
- Write as a product execution document, not a blog post
```

---

## Section 9: How to Use the Stress-Test Prompt

### When to Run It

| Situation | Action |
|-----------|--------|
| Planning a new paid feature | Run prompt, compare output to your idea |
| Unsure about pricing | Run prompt, note the reasoning behind prices |
| Considering a paywall change | Run prompt, check if triggers align |
| Quarterly strategy review | Run prompt, look for drift from your current plan |
| After major product change | Run prompt, validate monetization still fits |

### How to Run It

1. **Copy the prompt exactly** — don't paraphrase
2. **Paste into your LLM of choice** (Claude, GPT-4, Cursor)
3. **Read the output critically** — see Section 3
4. **Compare to current plan** — look for gaps or confirmations
5. **Document any changes** — update `MONETIZATION_EXECUTION.md` if needed

### What to Extract from Output

| Look For | Why It Matters |
|----------|----------------|
| Feature suggestions different from yours | May reveal blind spots |
| Pricing that differs from yours | Validate or reconsider |
| Paywall triggers you haven't considered | Opportunity or anti-pattern |
| "Never monetize" items you're considering | Strong signal to stop |
| Revenue numbers far from yours | Check your assumptions |

---

## Section 10: Interpretation Guide

AI outputs are useful but not authoritative. Apply these filters:

### Trust Signals (Output Is Likely Reliable)

| Signal | Example |
|--------|---------|
| Cites specific behavioral triggers | "When user taps Remind for the 2nd time" |
| Gives concrete numbers with reasoning | "₹29/month because < cost of chai" |
| Identifies anti-patterns with explanation | "Don't gate groups—kills virality" |
| Acknowledges uncertainty | "Conversion may be lower if..." |
| Matches your user research | Confirms what you've heard from real users |

### Warning Signs (Question the Output)

| Signal | Example |
|--------|---------|
| Generic advice | "Focus on value proposition" |
| Ignores constraints you specified | Suggests ads despite "no ads" constraint |
| Unrealistic numbers | "5% conversion in India is achievable" |
| Features that don't match your app | Suggests currency conversion for India-only app |
| Buzzwords | "Leverage synergies", "growth hacking" |

### How to Cross-Validate

1. **Run the prompt on 2-3 different LLMs** — look for consensus
2. **Compare to your user feedback** — real data beats AI opinion
3. **Check against Splitwise/competitors** — what actually works
4. **Apply the "would I pay for this?" test** — be honest
5. **Ask a non-technical friend** — if they don't get it, users won't

---

## Section 11: Prompt Variants

Use these modified prompts for specific questions:

### Variant A: Feature Validation

```
[Insert master prompt context]

I am considering adding this paid feature: [DESCRIBE FEATURE]

Evaluate:
1. Will this convert in India? Why or why not?
2. What's the right paywall trigger for this feature?
3. Does this cannibalize free value or add new value?
4. What's the dev effort vs. conversion ROI?
5. Is there a simpler version that would convert equally well?
```

### Variant B: Pricing Validation

```
[Insert master prompt context]

I am considering this pricing: [YOUR PRICING]

Evaluate:
1. Is this appropriate for India? Compare to local benchmarks.
2. What psychological barriers exist at this price?
3. Should I offer lifetime? At what multiple of annual?
4. What's the optimal annual vs. monthly discount?
5. How should I display these prices in the UI?
```

### Variant C: Paywall Audit

```
[Insert master prompt context]

Here are my current paywall triggers: [LIST YOUR TRIGGERS]

Evaluate:
1. Are any of these too aggressive (will cause churn)?
2. Are any too passive (missing conversion)?
3. What's the optimal frequency of paywall display?
4. Should any of these be time-based vs. action-based?
5. What dismiss behavior is optimal?
```

### Variant D: Anti-Pattern Check

```
[Insert master prompt context]

I am considering this monetization approach: [DESCRIBE APPROACH]

Tell me:
1. What are the risks of this approach?
2. Have similar apps tried this? What happened?
3. How might users perceive this negatively?
4. What's the worst-case scenario?
5. Is there a less risky alternative?
```

---

## Section 12: Decision Log Template

After running the prompt, log your decision:

```markdown
## Monetization Decision: [TOPIC]

**Date**: YYYY-MM-DD

**Prompt Used**: Master / Variant A / B / C / D

**AI Recommendation Summary**:
- [Key point 1]
- [Key point 2]
- [Key point 3]

**My Decision**:
- [ ] Accept recommendation
- [ ] Reject recommendation
- [ ] Modify and accept

**Reasoning**:
[Why you agreed or disagreed with the AI]

**Action Items**:
- [ ] [Specific task]
- [ ] [Specific task]

**Review Date**: [When to revisit this decision]
```

---

## Section 13: Review Schedule

| Review Type | Frequency | Focus |
|-------------|-----------|-------|
| Pricing validation | Quarterly | Is pricing still appropriate? |
| Feature ROI | After each Plus feature ships | Is it converting? |
| Paywall audit | Monthly (first 3 months post-launch) | Conversion rates, churn impact |
| Full strategy review | Every 6 months | Is the model working? |

---

## Section 14: Metrics to Track

### Pre-Launch (Current Phase)

| Metric | Target | How to Measure |
|--------|--------|----------------|
| MAU | 5K before monetization | Firebase Analytics |
| 30-day retention | >40% | Firebase Analytics |
| Power user % | >15% of MAU | Custom event: >10 expenses/month |
| Qualitative feedback | Ongoing | In-app feedback, reviews |

### Post-Launch

| Metric | Target | Frequency |
|--------|--------|-----------|
| Paywall view rate | <10% of sessions | Weekly |
| Paywall → conversion | >3% | Weekly |
| Plus subscriber count | Growth | Weekly |
| Plus churn (monthly) | <10%/month | Monthly |
| Plus churn (annual) | <30%/year | Quarterly |
| ARPU (paying users) | >₹20/month | Monthly |
| NPS (free users) | >40 | Quarterly |
| NPS (Plus users) | >50 | Quarterly |
| Lifetime purchases remaining | Track countdown from 500 | Weekly |

### Red Flags (Investigate Immediately)

| Signal | Threshold | Action |
|--------|-----------|--------|
| Paywall view → uninstall | >5% | Reduce paywall frequency |
| Monthly churn | >15% | Survey churned users |
| Conversion rate | <1% | Test different features/pricing |
| 1-star reviews mentioning "money grab" | >3 in a week | Review messaging, consider rollback |

---

## Section 15: Common Monetization Mistakes (Avoid These)

| Mistake | Why It Kills You | Expenso Safeguard |
|---------|------------------|-------------------|
| Gating core features | Users churn before experiencing value | Core tracking always free |
| Ads in utility app | Destroys trust in financial context | No ads, ever |
| Western pricing in India | ₹400/month = 0.1% conversion | ₹29/month |
| Too many tiers | Cognitive overload | 2 tiers max (free + Plus) |
| Aggressive upsells | Every-session popups → uninstalls | 1 paywall per session max, 7-day cooldown |
| Subscription-only | Indians hate recurring | Lifetime option included |
| Monetizing too early | Need retention proof first | Wait for 5K MAU |
| Building for whales | No whales in expense-splitting | Monetize the mass |
| Complex onboarding for Plus | Friction kills conversion | One-tap purchase |
| No refund policy | Bad reviews, chargebacks | 7-day refund, no questions |

---

## Section 16: Future Monetization Opportunities (Not Now)

Consider these **after** Plus v1 is validated and stable:

| Opportunity | Description | When to Explore |
|-------------|-------------|-----------------|
| **Group Premium** | One person pays ₹199/month, entire group gets Plus | After 50K MAU |
| **B2B: PG/Hostel owners** | White-label for landlords managing 10+ tenants | After 100K MAU |
| **Referral partnerships** | Credit cards, wallets that benefit from split data | After establishing brand |
| **Premium support (WhatsApp)** | Direct support channel for Plus users | If support volume justifies |
| **Anonymized insights** | Aggregate spending data (no PII) for research | Far future, if ever |

---

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2026-02 | Initial document created | — |
| 2026-02 | v2.0: Added finalized decisions, feature specs, pre-launch checklist, risk matrix, metrics, anti-patterns | — |

---

## Document Map

Quick navigation:

| Section | Content |
|---------|---------|
| §1 | Finalized decisions (locked) |
| §2 | Plus v1 feature specs |
| §3 | Paywall behavior |
| §4 | Rollout stages |
| §5 | Revenue projections |
| §6 | Pre-launch checklist |
| §7 | Risks & mitigations |
| §8 | Stress-test prompt |
| §9-11 | How to use prompt |
| §12 | Decision log template |
| §13 | Review schedule |
| §14 | Metrics |
| §15 | Mistakes to avoid |
| §16 | Future opportunities |

---

*This document is internal. Do not publish externally.*
