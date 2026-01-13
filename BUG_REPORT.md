# Bug Report - Data Passing Issues

## Status: 🔍 4 Bugs Found

### ✅ Bug #1: GroupsList → GroupDetail (FIXED)
**Issue**: Clicking on "Movie Night" or "Office Lunch" always showed "Weekend Trip"
**Cause**: GroupsList wasn't passing the clicked group data
**Status**: ✅ **FIXED**
**Solution**: Added `arguments: group` to Navigator.pushNamed

---

### ❌ Bug #2: CreateGroup → InviteMembers
**Issue**: Group name entered in CreateGroup is not shown in InviteMembers
**Cause**: CreateGroup doesn't pass the group name to InviteMembers
**Current Behavior**: InviteMembers always shows default "Group Name"
**Expected Behavior**: Should show the actual group name entered
**Status**: ❌ **NEEDS FIX**

**Impact**: Medium - User sees generic name instead of their custom group name

---

### ❌ Bug #3: InviteMembers → GroupDetail  
**Issue**: After creating group and inviting members, GroupDetail shows default data
**Cause**: InviteMembers doesn't pass the newly created group to GroupDetail
**Current Behavior**: Shows "Weekend Trip" default group
**Expected Behavior**: Should show the newly created group with correct name
**Status**: ❌ **NEEDS FIX**

**Impact**: High - Breaks the group creation flow completely

---

### ❌ Bug #4: GroupDetail → EditExpense
**Issue**: Clicking on any expense always shows "Dinner at Bistro 42"
**Cause**: GroupDetail doesn't pass the clicked expense data to EditExpense
**Current Behavior**: Always shows default expense
**Expected Behavior**: Should show the actual clicked expense details
**Status**: ❌ **NEEDS FIX**

**Impact**: High - User cannot edit the correct expense

---

### ❌ Bug #5: GroupMembers → MemberChange
**Issue**: Clicking on a member doesn't pass member details to MemberChange screen
**Cause**: GroupMembers doesn't pass member data
**Current Behavior**: Shows default member phone number
**Expected Behavior**: Should show the actual clicked member's details
**Status**: ❌ **NEEDS FIX**

**Impact**: Medium - User sees wrong member in confirmation dialog

---

## Summary

**Total Bugs**: 5
- ✅ **Fixed**: 1 (GroupsList → GroupDetail)
- ❌ **Pending**: 4 (CreateGroup, InviteMembers, EditExpense, MemberChange)

## Priority Order for Fixes:
1. 🔴 **HIGH**: Bug #3 (InviteMembers → GroupDetail) - Breaks group creation flow
2. 🔴 **HIGH**: Bug #4 (GroupDetail → EditExpense) - Cannot edit correct expense
3. 🟡 **MEDIUM**: Bug #2 (CreateGroup → InviteMembers) - Shows wrong name
4. 🟡 **MEDIUM**: Bug #5 (GroupMembers → MemberChange) - Shows wrong member

---

## Root Cause Analysis

All bugs stem from the same pattern:
- **Screens are navigating without passing data via `arguments`**
- **Receiving screens have default/fallback data that always displays**
- **Navigation code was set up but data passing was not implemented**

This is typical in UI-only conversions where the focus was on layout/navigation flow rather than state management.
