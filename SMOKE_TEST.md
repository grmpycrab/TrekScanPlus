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

---

## 8. Porter Ratio & Slot Capacity

| # | Check | Result |
|---|-------|--------|
| 8.1 | Group with 5 trekkers shows **1 porter** automatically allocated in Step 2 slot counter | |
| 8.2 | Group with 9 trekkers shows **1 porter**; group with 10 trekkers shows **2 porters** | |
| 8.3 | Step 3 Review shows "Porter Allocation" card when `porterCount > 0` with correct ₱ total | |
| 8.4 | Date picker availability shows "X trekkers + Y porters" breakdown in "Site Capacity Used" | |
| 8.5 | `DateValidationService` counts both `bookings` AND `groupBookings` toward site slots used | |
| 8.6 | Remaining trekker slots = `floor((maxSlots − usedSiteSlots) × 5 / 6)` — verify with 30-slot day | |
| 8.7 | Group booking with 25 trekkers (5 porters) on a 30-slot day shows 0 remaining trekker slots | |

---

## 9. Pricing Display (Estimate Only)

| # | Check | Result |
|---|-------|--------|
| 9.1 | `PriceSummaryWidget` shows correct per-member price from **PricingService** (not hardcoded ₱3000) | |
| 9.2 | After admin updates base price in Pricing Utility, mobile booking flow reflects new price within ~5 s | |
| 9.3 | `PriceSummaryWidget` footer reads "Estimate only — actual payment is collected at the ranger station" | |
| 9.4 | Step 3 Review in group flow footer reads "Payment is collected at the ranger station on trek day" | |
| 9.5 | No screen in the app shows a payment form, checkout button, or online payment option | |
| 9.6 | Category discount labels use correct keys: `student`, `senior_citizen`, `davao_oriental_resident`, `ocfdo`, `children_8_15`, `mfsm`, `outside_davao_oriental` | |

---

## 10. Document Requirements (Group & Guest Members)

| # | Check | Result |
|---|-------|--------|
| 10.1 | `DocumentRequirements.getRequiredDocumentsForCategory('davao_oriental_resident')` returns 3 docs (not null) | |
| 10.2 | `DocumentRequirements.getRequiredDocumentsForCategory('ocfdo')` returns 3 docs including OCF ID | |
| 10.3 | `DocumentRequirements.getRequiredDocumentsForCategory('children_8_15')` returns 3 docs including Parent Consent | |
| 10.4 | `DocumentRequirements.getRequiredDocumentsForCategory('outside_davao_oriental')` returns 2 docs (Medical + Gov't ID) | |
| 10.5 | `DocumentRequirements.getDiscountForCategory('davao_oriental_resident')` returns `50` (was silently returning `null` before fix) | |
| 10.6 | `PriceSummaryWidget` shows discount badge for `davao_oriental_resident`, `ocfdo`, `children_8_15` members | |

---

## Notes

- **Environment tested:** `[ ] Local` `[ ] Staging` `[ ] Production`
- **Date:**
- **Tester:**
- **Build / commit:**
- **Failures logged at:** (link to issue tracker)
