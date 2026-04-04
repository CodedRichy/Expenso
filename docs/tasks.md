# Tasks: Expenso

## Pending Features (Active Roadmap)

### 1. Multi-Currency Support (P0)
- **Problem**: Groups are currently locked to a single currency.
- **Goal**: Support multiple ISO-4217 currencies and provide approximate conversions for group balance view.

### 2. Push Notification Rollout (P1)
- **Problem**: Users are not notified when they are added to a group or an expense is recorded.
- **Goal**: Full FCM integration for real-time alerts.

### 3. Recurring Expenses (P2)
- **Goal**: Support for monthly rent, subscriptions, and other repetitive group costs.

### 4. Expense Categorization & Reporting (P2)
- **Goal**: Rich visualizations and monthly reports for spending patterns.

---

## Technical Debt & Gaps

### Data Logic (P1)
- [ ] Complete the Supabase migration (remove remaining Firestore dependencies).
- [ ] Add explicit conflict resolution for concurrent expense edits.
- [ ] Improve date handling (move from string-based dates to proper timestamps).

### Infrastructure (P2)
- [ ] Continuous Integration: Expand to full integration test suite on every PR.
- [ ] Offline Storage: Refine `SharedPreferences` usage for larger datasets.

---

## Future Improvements
- **Desktop/Web Workspace**: Expansion beyond mobile for easier large-group management.
- **Bank Integration**: Exploratory phase for automatic transaction import.
- **Social Discovery**: Improved invitation flows between existing contacts.

---
*Updated: April 2026*
