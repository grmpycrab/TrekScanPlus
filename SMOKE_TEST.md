# TrekScanPlus — Deployment Smoke Test Checklist

Run this checklist after every deployment to catch regressions early.
Mark each item ✅ Pass, ❌ Fail (note the failure), or ⏭ Skip (with reason).

---

## 1. Authentication

| # | Check | Result |
|---|-------|--------|
| 1.1 | Register a new account with email + password | |
| 1.2 | Verify email (check inbox for verification link) | |
| 1.3 | Log in with verified account | |
| 1.4 | Log out and confirm redirect to login screen | |
| 1.5 | Unverified account is blocked — cannot reach main screen | |
| 1.6 | Admin portal login works with seeded admin email | |

---

## 2. Group Booking (Mobile App)

| # | Check | Result |
|---|-------|--------|
| 2.1 | Tap booking tab — opens booking history (not legacy form) | |
| 2.2 | Tap **+** FAB — navigates to `GroupBookingEntryScreen` | |
| 2.3 | Tap calendar date on home → jumps to `GroupBookingEntryScreen` | |
| 2.4 | **Create a Group**: fill required fields, submit — group appears in Firestore `groupBookings` | |
| 2.5 | **Join a Group**: browse active groups, submit join request — request visible under group's `joinRequests` | |
| 2.6 | Group organizer sees incoming join requests in `OrganizerRequestsScreen` | |
| 2.7 | Existing individual bookings still visible in the booking history tabs | |

---

## 3. Group Booking (Admin Dashboard)

| # | Check | Result |
|---|-------|--------|
| 3.1 | `GroupBookingsPanel` loads — lists groups with correct statuses | |
| 3.2 | Approve a join request — `currentSlots` increments, status updates | |
| 3.3 | Decline a join request — reason saved, user notified | |
| 3.4 | Group marked `full` when `currentSlots` reaches `maxSlots` | |
| 3.5 | Filtering by status (open / pending_review / approved / declined) works | |

---

## 4. Pricing Configuration (Admin Dashboard)

| # | Check | Result |
|---|-------|--------|
| 4.1 | Active pricing version displays correctly on `PricingUtility` page | |
| 4.2 | **Create new version**: fill resolution ref, type, effective date — version saved to `pricingVersions` | |
| 4.3 | Previous version transitions to `superseded` status after new version is created | |
| 4.4 | **Memorandum upload**: attach a PDF/image in the new-version modal — file visible in Firebase Storage under `pricing/memorandums/` | |
| 4.5 | Uploaded memorandum link appears in the expanded version history row | |
| 4.6 | Version history list shows all versions newest-first | |

---

## 5. Cross-Device Sync

| # | Check | Result |
|---|-------|--------|
| 5.1 | Submit a group booking on mobile — appears in admin dashboard within ~5 s | |
| 5.2 | Admin approves join request — status updates on mobile app in real time | |
| 5.3 | Pricing update in admin portal — new rates reflect in mobile app booking flow | |
| 5.4 | Notification delivered to mobile when booking status changes | |

---

## 6. Individual Booking Flow (Legacy — backwards compat)

| # | Check | Result |
|---|-------|--------|
| 6.1 | Existing individual bookings still visible in Upcoming / Previous / All tabs | |
| 6.2 | Booking detail / edit sheet opens for an existing individual booking | |
| 6.3 | Cancel individual booking — status updates to `cancelled` | |
| 6.4 | Archive booking — disappears from main list, visible in Archived Bookings | |

---

## 7. Admin — General

| # | Check | Result |
|---|-------|--------|
| 7.1 | `ClimbRequest` page loads and lists pending individual bookings | |
| 7.2 | Approve / reject / request changes on an individual booking | |
| 7.3 | Certificates page loads without error | |
| 7.4 | No console errors on initial admin portal load | |

---

## Notes

- **Environment tested:** `[ ] Local` `[ ] Staging` `[ ] Production`
- **Date:**
- **Tester:**
- **Build / commit:**
- **Failures logged at:** (link to issue tracker)
