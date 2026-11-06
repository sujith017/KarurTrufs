# KarurTrufs — Development Roadmap

## 1. Purpose

This document defines the development plan for KarurTrufs, from the completed project foundation and database design through backend development, frontend integration, testing, deployment, and the first pilot venues.

The project will be developed incrementally. Each phase should be implemented, tested, and understood before moving to the next.

---

## 2. Current Project Status

### Phase 1 — Project Foundation

**Status: Completed**

- [x] Finalized the KarurTrufs project concept.
- [x] Selected React, TypeScript, and Vite for the frontend.
- [x] Selected Node.js, Express, and TypeScript for the backend.
- [x] Selected PostgreSQL with Neon as the hosted database.
- [x] Created separate frontend and backend applications.
- [x] Set up the initial project folder structure.
- [x] Installed and configured the required development tools.
- [x] Created the Neon PostgreSQL project.
- [x] Configured backend database connectivity.
- [x] Verified that the frontend and backend setup works.

### Phase 2 — Database Design and Implementation

**Status: Completed**

- [x] Designed the multi-tenant database structure.
- [x] Created the 21 application tables.
- [x] Implemented migrations 001–040.
- [x] Added foreign keys and tenant relationship constraints.
- [x] Added indexes and uniqueness constraints.
- [x] Added booking overlap protection.
- [x] Added weekly and date-specific pricing overlap protection.
- [x] Added operating-hours overlap validation.
- [x] Created and populated the `schema_migrations` tracking table.
- [x] Exported the database schema.
- [x] Created the database ER diagram using dbdiagram.io.

**Important:** Database creation is complete, but this does not mean the application is production-ready. Backend validation, authorization, transactions, concurrency handling, and automated tests are still required.

### Phase 3 — Technical Documentation

**Status: In progress**

Documentation files:

- [x] `docs/architecture.md`
- [x] `docs/database-design.md`
- [x] `docs/database-relationships.md`
- [ ] `docs/development-roadmap.md`

After completing this roadmap, review all four documents together and keep them updated as the implementation evolves.

---

## 3. Backend Development

The backend will be built as a modular monolith using Express and TypeScript.

### Phase 4 — Backend Foundation

**Status: Pending**

Tasks:

- [ ] Inspect and organize the existing backend folder structure.
- [ ] Review the existing database connection and configuration.
- [ ] Establish a consistent environment-variable configuration.
- [ ] Implement centralized error handling.
- [ ] Implement request validation.
- [ ] Establish a consistent API response structure.
- [ ] Add request logging.
- [ ] Organize routes, controllers, services, and database queries.
- [ ] Establish API versioning under `/api/v1`.
- [ ] Add a consistent approach to database transactions.

**Expected outcome:** A clean backend foundation that can support the application modules.

### Phase 5 — Database Migration Management

**Status: Pending**

The database already contains migrations 001–040, and the `schema_migrations` table has been populated manually.

Tasks:

- [ ] Inspect the current migration files and backend dependencies.
- [ ] Choose an appropriate migration execution strategy.
- [ ] Implement migration tracking and execution.
- [ ] Ensure already-applied migrations are not executed again.
- [ ] Validate migration ordering and failure handling.
- [ ] Document how to create and apply future migrations.

**Important:** Do not rerun the existing migrations against Neon. The migration runner must recognize the existing applied versions.

### Phase 6 — Authentication

**Status: Pending**

Authentication must support customers, owners, and managers.

Tasks:

- [ ] Implement user registration and login.
- [ ] Implement password hashing and password verification.
- [ ] Implement Google OAuth login.
- [ ] Implement phone OTP verification.
- [ ] Support linking a Google account to an existing account.
- [ ] Implement access-token handling.
- [ ] Implement refresh-token rotation and session management.
- [ ] Implement logout from the current device.
- [ ] Implement logout from all devices.
- [ ] Implement account activation and verification checks.

**Expected outcome:** Users can securely register, authenticate, and manage their sessions.

### Phase 7 — Authorization and Tenant Isolation

**Status: Pending**

Authentication identifies the user. Authorization determines what that user is allowed to do.

Tasks:

- [ ] Implement tenant membership checks.
- [ ] Implement owner authorization.
- [ ] Implement venue-specific manager authorization.
- [ ] Implement customer authorization.
- [ ] Ensure managers can access only their assigned venues.
- [ ] Ensure managers cannot access owner-only operations.
- [ ] Derive tenant and venue access from authenticated backend context.
- [ ] Never trust a frontend-supplied `tenant_id` as proof of access.
- [ ] Test cross-tenant access restrictions.

**Expected outcome:** Users can access only the businesses, venues, and operations permitted by their roles.

### Phase 8 — Business and Venue Management

**Status: Pending**

Tasks:

- [ ] Create a business.
- [ ] Associate the business owner with the business.
- [ ] Retrieve business details.
- [ ] Update business details.
- [ ] Create venues.
- [ ] Update venue details.
- [ ] Store venue address and map coordinates.
- [ ] Support Google Maps location information.
- [ ] Activate and deactivate venues.
- [ ] Retrieve venues belonging to an authorized business.

### Phase 9 — Court Management

**Status: Pending**

Tasks:

- [ ] Create courts within a venue.
- [ ] Store court name and sport name.
- [ ] Update court details.
- [ ] Activate and deactivate courts.
- [ ] Retrieve courts for a venue.
- [ ] Enforce owner-only court management.

### Phase 10 — Operating Hours and Pricing

**Status: Pending**

Tasks:

- [ ] Create weekly operating hours for courts.
- [ ] Update and delete operating-hour records.
- [ ] Support overnight operating hours.
- [ ] Validate overlapping operating hours.
- [ ] Create recurring weekly price rules.
- [ ] Update recurring prices.
- [ ] Create date-specific price overrides.
- [ ] Calculate the effective price for a requested slot.
- [ ] Give date-specific overrides priority over weekly pricing.
- [ ] Preserve existing bookings and explicit date overrides when recurring prices change.

**Expected outcome:** Owners can configure court availability and pricing without affecting existing bookings.

### Phase 11 — Availability and Booking

**Status: Pending**

Tasks:

- [ ] Retrieve available courts and time slots.
- [ ] Calculate availability using operating hours.
- [ ] Calculate the effective price for each slot.
- [ ] Prevent customers from booking unavailable slots.
- [ ] Support multiple consecutive one-hour slots in one booking.
- [ ] Create booking records and booking items.
- [ ] Implement the three-minute temporary booking hold.
- [ ] Confirm bookings after successful payment.
- [ ] Expire unpaid holds.
- [ ] Release expired slots.
- [ ] Support owner-created internal bookings.
- [ ] Support owner-created court blocks.
- [ ] Implement booking cancellation.
- [ ] Implement booking completion.
- [ ] Handle concurrent booking attempts safely.

**Important implementation considerations:**

- Use PostgreSQL transactions for booking operations.
- Handle exclusion-constraint violations safely.
- Never rely only on frontend availability checks.
- Implement a backend process to expire overdue holds.
- Handle payments that arrive after a booking hold has expired.

### Phase 12 — Payment Integration

**Status: Pending**

Tasks:

- [ ] Integrate Razorpay for customer booking payments.
- [ ] Create payment orders through the backend.
- [ ] Associate payment orders with bookings.
- [ ] Verify payment signatures.
- [ ] Implement payment webhooks.
- [ ] Process webhook events idempotently.
- [ ] Update booking and payment statuses safely.
- [ ] Handle failed and pending payments.
- [ ] Handle late payments.
- [ ] Implement refunds.
- [ ] Track partial and complete refunds.

**Expected outcome:** Customers can pay securely and bookings are confirmed only after verified payment.

### Phase 13 — Subscription Management

**Status: Pending**

Tasks:

- [ ] Implement venue trial creation.
- [ ] Implement subscription plan selection.
- [ ] Implement monthly and yearly billing.
- [ ] Integrate subscription payments.
- [ ] Handle subscription renewal.
- [ ] Handle failed payments.
- [ ] Handle past-due subscriptions.
- [ ] Handle cancellation and expiry.
- [ ] Enforce subscription rules for each venue.
- [ ] Preserve venue and booking history after subscription expiry.

**Business rule:** Each venue has its own subscription. Multiple courts within one venue are covered by that venue's subscription.

### Phase 14 — Manager Management

**Status: Pending**

Tasks:

- [ ] Allow owners to assign managers to venues.
- [ ] Allow owners to revoke manager assignments.
- [ ] Retrieve managers assigned to a venue.
- [ ] Ensure assignments are venue-specific.
- [ ] Enforce manager permissions on every protected API.

### Phase 15 — Notifications, Reports, and Audit Logs

**Status: Pending**

Tasks:

- [ ] Implement in-app notifications.
- [ ] Notify customers about booking status changes.
- [ ] Notify owners about bookings and payments.
- [ ] Implement booking history.
- [ ] Implement revenue reports.
- [ ] Calculate gross revenue, refunds, and net revenue.
- [ ] Support today, yesterday, past seven days, this month, previous month, and custom date ranges.
- [ ] Keep app booking revenue separate from KarurTrufs subscription revenue.
- [ ] Record important business actions in audit logs.
- [ ] Prevent normal users from modifying or deleting audit records.

---

## 4. Testing and Reliability

### Phase 16 — Backend Testing

**Status: Pending**

Tasks:

- [ ] Add unit tests for business logic.
- [ ] Add API integration tests.
- [ ] Add database integration tests.
- [ ] Test authentication and session handling.
- [ ] Test owner and manager permissions.
- [ ] Test tenant isolation.
- [ ] Test operating-hour validation.
- [ ] Test recurring and date-specific pricing.
- [ ] Test booking creation and cancellation.
- [ ] Test simultaneous booking attempts.
- [ ] Test hold expiry.
- [ ] Test payment webhook idempotency.
- [ ] Test refunds.
- [ ] Test subscription lifecycle.
- [ ] Test revenue calculations.

**Expected outcome:** Core business rules are verified before relying on real venues and customers.

---

## 5. Frontend Development

### Phase 17 — Customer Application

**Status: Pending**

Tasks:

- [ ] Build responsive customer-facing pages.
- [ ] Implement registration and login screens.
- [ ] Build venue discovery and search.
- [ ] Build public venue pages.
- [ ] Display venue location and court details.
- [ ] Display available slots and prices.
- [ ] Support selecting multiple consecutive slots.
- [ ] Display the booking summary.
- [ ] Integrate payment checkout.
- [ ] Display booking confirmation.
- [ ] Build customer booking history.
- [ ] Build cancellation and refund status views.

### Phase 18 — Owner Dashboard

**Status: Pending**

Tasks:

- [ ] Build owner registration and onboarding.
- [ ] Build business and venue management screens.
- [ ] Build court management screens.
- [ ] Build weekly operating-hours editor.
- [ ] Build weekly pricing editor.
- [ ] Build date-specific pricing editor.
- [ ] Build booking calendar.
- [ ] Build internal booking and court-blocking screens.
- [ ] Build revenue dashboard.
- [ ] Build subscription management screens.
- [ ] Build manager assignment screens.
- [ ] Build notification views.

### Phase 19 — Manager Dashboard

**Status: Pending**

Tasks:

- [ ] Build manager login and venue selection.
- [ ] Display bookings for assigned venues.
- [ ] Display customer details permitted by the role.
- [ ] Display revenue reports.
- [ ] Hide owner-only management operations.
- [ ] Ensure backend authorization remains the actual security boundary.

---

## 6. Deployment and Pilot Launch

### Phase 20 — Deployment

**Status: Pending**

Tasks:

- [ ] Select frontend hosting.
- [ ] Select backend hosting.
- [ ] Configure production environment variables.
- [ ] Configure production database access.
- [ ] Configure HTTPS and domain names.
- [ ] Configure CORS and security headers.
- [ ] Configure database backups.
- [ ] Configure application logging and monitoring.
- [ ] Configure error reporting.
- [ ] Verify database migration and rollback procedures.
- [ ] Test the deployed application end to end.

### Phase 21 — Pilot Launch

**Status: Pending**

Tasks:

- [ ] Onboard the first turf venue.
- [ ] Configure its courts, hours, and prices.
- [ ] Test owner and manager workflows.
- [ ] Test customer booking and payment workflows.
- [ ] Collect feedback from venue owners.
- [ ] Track actual bookings and active usage.
- [ ] Identify usability problems.
- [ ] Fix critical issues.
- [ ] Improve onboarding and documentation.
- [ ] Validate subscription pricing with real customers.

**Initial goal:** Launch with a small number of pilot venues before expanding.

---

## 7. Future Enhancements

These features are intentionally postponed until the core booking platform is stable.

- Dynamic pricing recommendations using historical booking data.
- ML-based demand forecasting.
- Advanced revenue analytics.
- Automated marketing and customer retention.
- WhatsApp, SMS, and email notifications.
- Mobile application.
- Multiple owners per business.
- Advanced discounts and promotional offers.
- Additional payment providers.
- Multi-city expansion.
- Advanced business intelligence.

---

## 8. Development Principles

The following principles will guide implementation:

1. Build one module at a time.
2. Understand the database and business rules before writing complex API logic.
3. Keep frontend and backend responsibilities separate.
4. Keep business logic inside backend services rather than frontend components.
5. Validate all user input on the backend.
6. Enforce authorization on every protected operation.
7. Use database transactions for operations that modify related records.
8. Preserve booking and payment history.
9. Test important business rules before moving forward.
10. Keep documentation synchronized with actual implementation.
11. Avoid premature microservices and unnecessary complexity.
12. Prefer maintainable, understandable code over shortcuts.

---

## 9. Immediate Next Steps

After completing this documentation:

1. Review all four documentation files for consistency.
2. Inspect the current backend folder structure and `package.json`.
3. Review the existing database connection implementation.
4. Decide and implement the migration runner without rerunning migrations 001–040.
5. Begin the backend foundation phase.

**The next development milestone is a reliable backend foundation, followed by authentication and authorization.**