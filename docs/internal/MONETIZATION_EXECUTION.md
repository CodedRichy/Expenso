# Expenso – Monetization Execution Plan

**Version**: 2.0  
**Created**: February 2026  
**Updated**: February 2026  
**Status**: Ready for Implementation

---

## Quick Reference

| Decision | Value |
|----------|-------|
| **When to monetize** | After 5K MAU with 40%+ 30-day retention |
| **Pricing** | ₹29/month · ₹249/year · ₹499 lifetime (first 500 only) |
| **Plus features** | Smart Reminders, Settlement Export, Receipt Attachments, Spending Insights, Expense Templates, Custom Categories, Biometric Lock |
| **Never monetize** | Core tracking, groups, invites, settlements, UPI, Magic Bar AI, God Mode math, QR |
| **Revenue expectation** | ₹50K–1.2L/year at 50K–100K MAU |
| **Play Store cut** | 15-30% (factored into projections) |

---

## 1. Core Principles (Locked)

| Principle | Rationale |
|-----------|-----------|
| Core tracking is free forever | Trust, retention, virality |
| No ads, ever | Destroys trust in financial utilities |
| Monetize convenience, not access | Users pay to save time/friction, not to unlock basics |
| Soft paywalls only | Never block core flows; always allow dismissal |
| India-first pricing | Western pricing fails here |

---

## 2. Pricing

### Structure

| Tier | Price | Justification |
|------|-------|---------------|
| **Monthly** | ₹29/month | Less than a chai. Impulse-buy range. |
| **Annual** | ₹249/year (₹20.75/mo) | One movie ticket. 28% savings. |
| **Lifetime** | ₹499 one-time | **First 500 buyers only**, then remove option. |

### UI Display

```
┌─────────────────────────────────────┐
│           Expenso Plus              │
│                                     │
│  ✓ Unlimited smart reminders        │
│  ✓ PDF & CSV exports                │
│  ✓ Receipt attachments              │
│  ✓ Spending insights & trends       │
│  ✓ Expense templates                │
│  ✓ Custom categories                │
│  ✓ Biometric lock                   │
│                                     │
│      ₹249/year ← BEST VALUE         │
│      (save 28%)                     │
│                                     │
│          or ₹29/month               │
│                                     │
│  [Get Plus]                         │
│                                     │
│  ₹499 one-time (X of 500 remaining) │
└─────────────────────────────────────┘
```

---

## 3. Never Monetize

| Feature | Reason |
|---------|--------|
| Expense creation | Core value |
| Unlimited groups | Virality — Splitwise's group limits killed growth |
| Unlimited members | Network effects |
| Member invites | Network effects |
| Settlement view | Core utility |
| UPI deep-links | Differentiator |
| Dynamic UPI QR | India adoption driver |
| Magic Bar (AI parsing) | Core hook — let everyone experience it |
| Debt minimization (God Mode) | Signature math — competitive moat |
| Cross-group identity | Foundation feature, not convenience |
| Sync/backup | Expected baseline |
| Dark mode | Commoditized |
| Expense editing/deletion | Data hygiene |
| Basic categories | Expected |
| Offline entry | Expected baseline |

### Competitive Context

**Splitwise's mistake (2023-2024):**
- Added daily expense limits (3-5/day) and 10-second wait times on free tier
- Charged $70/year — same as Spotify for an occasional-use tool
- Ratings crashed from 4+ stars to below 2 stars
- **Lesson:** Never paywall core actions. Users feel punished, not persuaded.

**Splitkaro (India competitor) paywalls:**
- Group limits (5 free)
- Bills in collections (5 free)
- Full analytics
- Auto-fetch from Swiggy/Zomato
- Priority reminders

**Expenso's advantage:** More generous free tier than both competitors.

---

## 4. Expenso Plus Features

### What Converts (2025 Industry Data)

| Driver | Conversion share |
|--------|------------------|
| Unlock premium content | 26% |
| Special offers/discounts | 23% |
| Extended features/tools | 20% |
| Trial expiration | 17% |
| Ad-free | 6% |
| Privacy/security | 6% |

**Key insight:** People pay to **unlock extra**, not to **remove friction from basics**.

---

### Feature 1: Smart Payment Reminders

**What**: Auto-nudges to group members with outstanding balances.

**User controls**:
- Frequency: every 3 days / weekly / custom
- Tone: friendly / neutral / direct
- Auto-stop when settled

**Why it converts**: Chasing money is socially awkward. Users pay to outsource this. **#1 pain point.**

**Dev effort**: Low

**Paywall trigger**: 2nd tap on "Remind" for same balance.

```
┌─────────────────────────────────────┐
│  🔔 Tired of chasing payments?      │
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

### Feature 2: Settlement Export

**What**: Export settlement history as PDF or CSV.

**Includes**:
- Group name, members
- All expenses with payer, split, date
- Final balances, settlement status

**Why it converts**:
- Flatmate leaving → need proof
- Trip ends → shareable summary
- Tax/reimbursement → formal records

**Dev effort**: Low-Medium

**Free tier**: 1 export per account lifetime (demonstrates value).

**Paywall trigger**: After free export used.

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

### Feature 3: Receipt Attachments

**What**: Attach photos of receipts/bills to expenses.

**Scope (Plus)**: Storing/attaching the receipt image to an expense is gated (3 free, then Plus). **Product decision TBD:** Whether **scan-to-prefill** (camera → OCR → prefill Magic Bar) is part of the same Plus surface or free as an input method with only attachment gated. See docs/features/RECEIPT_SCANNING_AND_ML.md.

**Why it converts**:
- Ends disputes ("show me the bill")
- Power users want unlimited attachments
- Reduces support burden (fewer arguments)

**Dev effort**: Medium

**Free tier**: 3 receipt attachments per account (demonstrates value).

**Paywall trigger**: After 3 free receipts used.

```
┌─────────────────────────────────────┐
│  🧾 Keep your receipts organized    │
│                                     │
│  Attach unlimited receipts with     │
│  Expenso Plus.                      │
│                                     │
│  [Get Plus — ₹29/month]             │
│                                     │
│  Not now                            │
└─────────────────────────────────────┘
```

---

### Feature 4: Spending Insights

**What**: Analytics with category, group, and time breakdowns.

**Includes**:
- Category pie charts (Food, Transport, Entertainment, etc.)
- Monthly trends
- Group spending comparisons
- "Top spender" stats

**Why it converts**: Analytics = premium tier expectation. Power users love data.

**Dev effort**: Medium

**Paywall trigger**: Always Plus (no free tier).

```
┌─────────────────────────────────────┐
│  📊 See where your money goes       │
│                                     │
│  Get spending insights and trends   │
│  with Expenso Plus.                 │
│                                     │
│  [Get Plus — ₹29/month]             │
│                                     │
│  Not now                            │
└─────────────────────────────────────┘
```

---

### Feature 5: Expense Templates

**What**: Save recurring expenses as templates for quick re-entry.

**Use cases**:
- Monthly rent
- Weekly groceries
- Regular subscriptions

**Why it converts**: Convenience for power users with recurring expenses.

**Dev effort**: Low-Medium

**Paywall trigger**: On "Save as template" tap.

---

### Feature 6: Custom Categories

**What**: Create custom expense categories beyond defaults.

**Why it converts**: Personalization = premium feel.

**Dev effort**: Low

**Free tier**: 5 custom categories.

**Paywall trigger**: After 5 custom categories created.

---

### Feature 7: Biometric Lock

**What**: Fingerprint/Face unlock for app access.

**Why it converts**: Security = premium/trust feel. Privacy-conscious users.

**Dev effort**: Low

**Paywall trigger**: Always Plus.

---

## 5. Paywall Rules

### Principles

1. Never block core actions
2. Trigger on pain, not entry
3. One paywall per session max
4. If dismissed, don't show again for 7 days
5. No paywalls on app launch

### Trigger Matrix

| Action | Paywall? | Condition |
|--------|----------|-----------|
| Tap "Remind" | Yes | 2nd time on same balance |
| Tap "Export" | Yes | After 1 free export |
| Attach receipt | Yes | After 3 free receipts |
| View insights | Yes | Always |
| Save template | Yes | Always |
| Create custom category | Yes | After 5 free |
| Enable biometric | Yes | Always |
| Open app | No | Never |
| Create group | No | Never |
| Invite member | No | Never |
| Add expense | No | Never |
| View settlement | No | Never |
| Use UPI link | No | Never |
| Use Magic Bar AI | No | Never |
| Generate UPI QR | No | Never |

### UI Spec

- **Format**: Bottom sheet (not modal)
- **Tone**: Helpful, not desperate
- **Dismiss**: Always visible

---

## 6. Rollout Stages

### Stage 1: Pre-Monetization (0 → 5K MAU)

| Do | Don't |
|----|-------|
| Ship fully-functional free app | Add paywalls |
| Instrument analytics | Show upgrade prompts |
| Identify power users (>10 expenses/mo) | Add ads |
| Collect feedback | Optimize for revenue |

**Exit**: 5K MAU with >40% 30-day retention

---

### Stage 2: Soft Monetization (5K → 25K MAU)

| Action | Details |
|--------|---------|
| Tip jar | ₹49, ₹99, ₹199 one-time. No features. |
| Plus beta | Invite top 5% power users |
| A/B test paywalls | Measure conversion |
| Plus badge | Visible in groups |

**Exit**: >1% conversion on tip jar or beta

---

### Stage 3: Full Monetization (25K+ MAU)

| Stream | Priority |
|--------|----------|
| Plus subscription | Primary |
| Lifetime (limited) | Secondary |
| Group Premium | Future |

---

## 7. Revenue Projections

### Assumptions

| Variable | Value |
|----------|-------|
| Conversion | 0.5% of MAU |
| Revenue mix | 60% annual, 30% monthly, 10% lifetime |
| Monthly churn | 10% |
| Annual churn | 30% |
| Play Store cut | 15% |

### Projections (Net After Play Store)

| MAU | Paying Users | Net Monthly | Net Annual |
|-----|--------------|-------------|------------|
| 25K | 125 | ₹2,465 | ₹29,580 |
| 50K | 250 | ₹4,930 | ₹59,160 |
| 100K | 500 | ₹9,860 | ₹1,18,320 |
| 200K | 1,000 | ₹19,720 | ₹2,36,640 |

**Reality**: Lifestyle business. Covers costs + modest income.

---

## 8. Pre-Launch Checklist

### Technical

- [ ] Play Store billing works
- [ ] Subscription restore works
- [ ] Lifetime purchase tracked (permanent)
- [ ] Paywall renders on low-end Android
- [ ] Free export counter tied to account (not device)
- [ ] Feature flags work
- [ ] Analytics: paywall views, conversions, dismissals

### Legal

- [ ] Privacy policy updated
- [ ] Refund policy: 7-day, no questions
- [ ] Terms include subscription terms
- [ ] Play Store IAP disclosure

### Support

- [ ] Support email ready
- [ ] Billing FAQ written
- [ ] Refund process documented

### Operational

- [ ] Lifetime counter in analytics
- [ ] Alert at 400 lifetime purchases
- [ ] Churn dashboard ready

---

## 9. Risks

| Risk | Mitigation |
|------|------------|
| "Greedy app" perception | Messaging: "Core is free forever" |
| Features don't convert | Start with highest-pain (Reminders) |
| Lifetime spikes, hurts LTV | Cap at 500 |
| Play Store billing bugs | Test extensively |
| Higher churn than expected | Monthly monitoring |

---

## 10. Metrics

### Pre-Launch

| Metric | Target |
|--------|--------|
| MAU | 5K before monetizing |
| 30-day retention | >40% |
| Power users | >15% of MAU |

### Post-Launch

| Metric | Target | Frequency |
|--------|--------|-----------|
| Paywall view rate | <10% of sessions | Weekly |
| Paywall → conversion | >3% | Weekly |
| Monthly churn | <10% | Monthly |
| Annual churn | <30% | Quarterly |
| ARPU | >₹20/month | Monthly |

### Red Flags

| Signal | Threshold | Action |
|--------|-----------|--------|
| Paywall → uninstall | >5% | Reduce frequency |
| Monthly churn | >15% | Survey users |
| Conversion | <1% | Test alternatives |
| "Money grab" reviews | >3/week | Review messaging |

---

## 11. Mistakes to Avoid

| Mistake | Safeguard |
|---------|-----------|
| Gating core features | Core always free |
| Ads | No ads, ever |
| Western pricing | ₹29/month |
| Too many tiers | Free + Plus only |
| Aggressive upsells | 1/session, 7-day cooldown |
| Subscription-only | Lifetime option |
| Monetizing early | Wait for 5K MAU |
| No refund policy | 7-day refund |

---

## 12. Future Opportunities (Not Now)

| Opportunity | When |
|-------------|------|
| Group Premium (one pays, all benefit) | After 50K MAU |
| B2B for PG/hostel owners | After 100K MAU |
| Referral partnerships | After brand established |
| Premium support (WhatsApp) | If volume justifies |

---

## Review Schedule

| Type | Frequency |
|------|-----------|
| Pricing | Quarterly |
| Feature ROI | After each ship |
| Paywall audit | Monthly (first 3 months) |
| Full strategy | Every 6 months |

---

## 13. Feature Tier Summary

### Free Forever

| Feature | Reason |
|---------|--------|
| Expense creation | Core value |
| Unlimited groups | Virality |
| Unlimited members | Network effects |
| Member invites | Network effects |
| Settlement view | Core utility |
| UPI deep-links | Differentiator |
| Dynamic UPI QR | India adoption driver |
| Magic Bar (AI parsing) | Core hook |
| Debt minimization (God Mode) | Signature math |
| Cross-group identity | Foundation |
| Sync/backup | Expected baseline |
| Basic categories | Expected |
| Offline entry | Expected baseline |
| Dark mode | Commoditized |
| Expense editing/deletion | Data hygiene |

### Expenso Plus (₹29/mo · ₹249/yr · ₹499 lifetime)

| Feature | Paywall Trigger | Free Allowance |
|---------|-----------------|----------------|
| Smart Reminders | 2nd remind on same balance | 1 manual remind per balance |
| Settlement Export | After 1 free export | 1 export lifetime |
| Receipt Attachments | After 3 free receipts | 3 receipts lifetime |
| Spending Insights | Always Plus | None |
| Expense Templates | On "Save as template" | None |
| Custom Categories | After 5 custom | 5 custom categories |
| Biometric Lock | Always Plus | None |

### The Rule

> **"Monetize convenience, not access"**
>
> If it saves time or friction → Plus  
> If it's core tracking/payments → Free

---

*Internal document. Do not publish.*
