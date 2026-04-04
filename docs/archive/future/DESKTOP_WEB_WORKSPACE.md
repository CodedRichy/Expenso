# Desktop / Web Workspace (Internal Only)

**Version**: 1.0  
**Created**: February 2026  
**Status**: Not Started — Trigger Conditions Not Met

---

## Purpose

Serve power users, organizers, and recurring groups who need:

- Full-group visibility
- Historical summaries
- Clean exports and audits
- Administrative controls

---

## Core Principle

| Mobile | Desktop/Web |
|--------|-------------|
| Primary platform | Pro-only multiplier |
| Free-first | Paid add-on |
| Daily use | Periodic admin tasks |

**Rule**: No feature critical to daily use should require desktop. Desktop amplifies; it doesn't gatekeep.

---

## Trigger to Build

Desktop development begins only when **all** conditions are met:

| Condition | Threshold | Why |
|-----------|-----------|-----|
| Export/summary requests | Repeated user requests | Validates demand |
| Group persistence | Groups active 2–3+ months | Long-term organizers need admin tools |
| Mobile Pro conversion | Stabilized (>1% conversion) | Proves willingness to pay |

**Do not build speculatively.** Mobile must prove product-market fit first.

---

## Initial Scope (MVP)

### Read-Only Group Dashboards

| Feature | Description |
|---------|-------------|
| Group overview | All members, total expenses, current balances |
| Expense timeline | Full chronological view with filters |
| Member breakdown | Per-member spending and contribution |

### Monthly Summaries

| Feature | Description |
|---------|-------------|
| Auto-generated reports | Monthly/weekly expense summaries |
| Email delivery | Scheduled summary emails to group admin |
| Shareable links | Read-only summary links for group members |

### Export Tools

| Format | Contents |
|--------|----------|
| PDF | Formatted settlement history, group summary |
| CSV | Raw expense data for spreadsheets |
| JSON | Full data export for power users |

### Admin Controls

| Control | Description |
|---------|-------------|
| Lock periods | Prevent edits to settled cycles |
| Approval workflow | Require admin approval for large expenses |
| Member management | Bulk invite, role assignment |
| Audit log | Track all modifications with timestamps |

---

## Technical Approach

### Stack Options

| Option | Pros | Cons |
|--------|------|------|
| Flutter Web | Code sharing with mobile | Performance, SEO |
| Next.js + React | Best web UX, SSR | Separate codebase |
| Electron + Flutter | Desktop app feel | Distribution complexity |

**Recommendation**: Start with Flutter Web for code sharing. Evaluate React if web-specific needs emerge.

### Data Access

- Same Firestore backend as mobile
- Read-heavy; can use aggressive caching
- Admin writes go through same security rules

### Auth

- Firebase Auth (same as mobile)
- Email/password option for desktop (no OTP friction)
- Link existing phone account to email for desktop access

---

## Monetization Alignment

| Tier | Desktop Access |
|------|----------------|
| Free | None |
| Plus Monthly | None |
| Plus Annual | Read-only dashboards |
| Pro (future) | Full admin controls + exports |

Desktop is a **Pro upsell**, not a free feature. Reinforces "mobile is enough for most users."

---

## What Desktop Is Not

| Not This | Why |
|----------|-----|
| Replacement for mobile | Mobile is primary; desktop is supplement |
| Real-time collaboration | Not a Google Sheets competitor |
| Expense entry UI | Enter expenses on mobile; review on desktop |
| Mandatory for any feature | Core app works without desktop |

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Desktop DAU / Mobile DAU | <5% (supplement, not replacement) |
| Pro conversion from desktop users | >5% |
| Export feature usage | >20% of desktop sessions |
| Admin control usage | >30% of group creators on desktop |

---

## Risks

| Risk | Mitigation |
|------|------------|
| Splitting focus too early | Strict trigger conditions |
| Desktop cannibalizes mobile | No feature parity; desktop is read-heavy |
| Maintenance burden | Shared codebase (Flutter Web) |
| Low adoption | Validate with user research before build |

---

## Future Possibilities (Not Now)

| Feature | When |
|---------|------|
| Team/org accounts | After 200K MAU |
| API access | If B2B demand emerges |
| White-label for PG/hostel owners | After B2B validation |
| Multi-currency reports | After international expansion |

---

## Review Checklist (Before Starting)

- [ ] Export requests from >5% of power users
- [ ] Multiple groups with 3+ month lifespan
- [ ] Pro conversion stable on mobile
- [ ] User research validates desktop demand
- [ ] Flutter Web performance acceptable for use case

---

*Internal document. Do not publish.*
