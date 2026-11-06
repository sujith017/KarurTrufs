# KarurTrufs — Database Design Document

## 1. Introduction

KarurTrufs uses PostgreSQL as its primary relational database.

The database is hosted on Neon and is shared by all businesses using the platform.

The database is designed to support:

- Multiple businesses (tenants).
- Multiple venues under each business.
- Multiple courts inside each venue.
- Venue-specific operating hours.
- Recurring and date-specific pricing.
- Customer bookings.
- Temporary booking holds.
- Payments and refunds.
- Venue subscriptions.
- Owner and manager permissions.
- Notifications and audit history.
- User authentication and sessions.

The database is designed around relational integrity, tenant isolation, and safe booking operations.

## 2. Database Architecture

### 2.1 Shared database with tenant isolation

KarurTrufs uses one PostgreSQL database for all businesses.

A business is represented by a tenant.

Each tenant can own multiple venues, and each venue can contain multiple courts.

Example:

```text
Tenant A
  |
  |-- Venue A1
  |     |-- Court 1
  |     |-- Court 2
  |
  |-- Venue A2
        |-- Court 1

Tenant B
  |
  |-- Venue B1
        |-- Court 1
```

Important:

- `tenants` represents businesses.
- `venues` represents physical locations.
- `courts` represents playable surfaces.
- `tenant_id` is used in important business records to maintain tenant consistency.

The backend is responsible for checking whether the authenticated user is authorized to access a tenant or venue.

A frontend-supplied `tenant_id` must never be treated as proof of authorization.

### 2.2 Why PostgreSQL?

PostgreSQL was selected because it supports:

- Primary keys and foreign keys.
- Unique constraints.
- Check constraints.
- Transactions.
- Indexes.
- JSONB.
- Generated columns.
- Range types.
- Exclusion constraints.
- Triggers.

These features are particularly useful for preventing overlapping bookings and pricing periods.

## 3. Database Entity Groups

The 21 application tables can be understood in the following groups.

| Group | Tables | Responsibility |
|---|---|---|
| Identity | users, user_auth_identities, otp_verifications, user_sessions | User accounts and authentication |
| Business structure | tenants, tenant_memberships, venues, courts, venue_manager_assignments | Businesses, locations and access |
| Scheduling and pricing | operating_hours, weekly_price_rules, date_price_overrides | Court schedules and prices |
| Bookings | bookings, booking_items | Customer reservations and their slots |
| Payments | booking_payments, payment_webhook_events, booking_refunds | Booking payment processing |
| Subscriptions | venue_subscriptions, subscription_payments | KarurTrufs billing |
| Platform operations | notifications, audit_logs | Notifications and activity history |

---

# 4. Detailed Table Design

## 4.1 Identity and Authentication Tables

### Table 1: `users`

**Purpose:** Stores the application's user accounts.

A user may be a business owner, manager, or customer.

Important columns:

| Column | Purpose |
|---|---|
| id | Unique user identifier (UUID) |
| full_name | User's name |
| email | Email address |
| phone | Phone number |
| password_hash | Hashed password; nullable for passwordless accounts |
| is_active | Whether the account is active |
| email_verified_at | Email verification timestamp |
| phone_verified_at | Phone verification timestamp |
| created_at | Account creation time |
| updated_at | Last update time |

Important design decisions:

- A UUID identifies each user.
- Email is protected by a case-insensitive unique index.
- Phone numbers are unique.
- A user must provide an email or phone number.
- Password hash can be NULL because users may authenticate using Google or OTP.

Why this table exists:

All user-related data references this table. It provides a common identity for owners, managers, and customers.

### Table 2: `user_auth_identities`

**Purpose:** Stores external authentication identities linked to a user.

Example: A user links their Google account to their KarurTrufs account.

Important columns:

| Column | Purpose |
|---|---|
| id | Unique identity record |
| user_id | Related user |
| provider | Authentication provider; currently GOOGLE |
| provider_user_id | User identifier provided by Google |
| provider_email | Email from the provider |
| provider_email_verified | Whether the provider reports the email as verified |
| created_at | Creation time |
| updated_at | Last update time |

Important constraint:

- A provider and provider user ID combination must be unique.

Why this table exists:

It separates external login identities from the main user record.

A user can be linked to an external authentication provider without making the provider's ID the primary application user ID.

### Table 3: `otp_verifications`

**Purpose:** Stores temporary OTP verification records.

Important columns:

| Column | Purpose |
|---|---|
| id | Unique verification record |
| phone | Phone number being verified |
| otp_hash | Hashed OTP, not the plain OTP |
| purpose | LOGIN or PHONE_VERIFICATION |
| expires_at | OTP expiration time |
| verified_at | Successful verification time |
| attempts | Number of verification attempts |
| created_at | Creation time |

Why this table exists:

It supports phone verification and OTP-based login.

Security requirements:

- Never store OTPs in plaintext.
- Enforce expiry.
- Limit verification attempts.
- Apply appropriate rate limits in the backend.

### Table 4: `user_sessions`

**Purpose:** Stores user refresh-session information.

Important columns:

| Column | Purpose |
|---|---|
| id | Unique session ID |
| user_id | Session owner |
| refresh_token_hash | Hashed refresh token |
| device_info | Device information |
| ip_address | Session IP address |
| expires_at | Session expiry |
| revoked_at | Session revocation time |
| last_used_at | Last session activity |
| created_at | Session creation time |

Why this table exists:

It supports session management and logout from individual or all devices.

Security requirement:

Store hashed refresh tokens, not raw refresh tokens.

---

## 4.2 Business Structure and Access Tables

### Table 5: `tenants`

**Purpose:** Represents a business registered on KarurTrufs.

Important columns:

| Column | Purpose |
|---|---|
| id | Unique tenant ID |
| business_name | Business name |
| created_at | Creation time |
| updated_at | Last update time |

Example:

A business named ABC Sports is one tenant.

Why this table exists:

It provides the main ownership and data-isolation boundary for business data.

### Table 6: `tenant_memberships`

**Purpose:** Connects users to businesses.

Important columns:

| Column | Purpose |
|---|---|
| id | Unique membership ID |
| tenant_id | Business |
| user_id | User who belongs to the business |
| role | OWNER |
| created_at | Membership creation time |

Important design decisions:

- The table currently supports OWNER membership only.
- A partial unique index enforces one owner per tenant.
- Tenant and user combinations are unique.

Why managers are not stored here:

Managers have venue-level access rather than automatic business-wide access.

They are handled separately through `venue_manager_assignments`.

This avoids accidentally giving a manager access to every venue under a business.

### Table 7: `venues`

**Purpose:** Stores physical sports venues belonging to a business.

Important columns:

| Column | Purpose |
|---|---|
| id | Unique venue ID |
| tenant_id | Owning business |
| venue_name | Venue name |
| description | Venue description |
| address | Physical address |
| latitude | Latitude coordinate |
| longitude | Longitude coordinate |
| google_maps_url | Maps link |
| timezone | Venue timezone; default Asia/Kolkata |
| is_active | Active/inactive status |
| created_at | Creation time |
| updated_at | Last update time |

Important design decisions:

- A venue belongs to a tenant.
- Latitude and longitude must both be NULL or both be present.
- Coordinate ranges are validated.
- `(id, tenant_id)` is unique to support composite foreign keys.

Why this table exists:

One business may operate multiple physical locations, and each location has its own courts, hours, pricing, and subscription.

### Table 8: `courts`

**Purpose:** Stores playable courts inside a venue.

Important columns:

| Column | Purpose |
|---|---|
| id | Unique court ID |
| venue_id | Parent venue |
| tenant_id | Owning business |
| court_name | Court name |
| sport_name | Sport played on the court |
| description | Optional description |
| is_active | Active/inactive status |
| created_at | Creation time |
| updated_at | Last update time |

Important design decisions:

- Each court belongs to a venue.
- Each court also stores its tenant ID.
- Court names are unique within a venue.
- Composite relationships help ensure tenant consistency.

We chose not to create a separate sports table initially.

The sport name is stored directly in `courts`.

Why this table exists:

A venue may have multiple courts, potentially supporting different sports.

### Table 9: `venue_manager_assignments`

**Purpose:** Assigns managers to specific venues.

Important columns:

| Column | Purpose |
|---|---|
| id | Assignment ID |
| tenant_id | Business |
| venue_id | Venue receiving manager access |
| manager_user_id | Assigned manager |
| assigned_by_user_id | User who created the assignment |
| created_at | Assignment creation time |
| revoked_at | Revocation time |
| revoked_by_user_id | User who revoked the assignment |

Important design decisions:

- A manager is assigned to a venue, not automatically to the entire business.
- The same manager can have assignments for multiple venues.
- Revoked assignments remain in the database for history.
- A partial unique index prevents duplicate active assignments for the same venue and manager.
- Foreign keys protect the referenced records.

Important backend responsibility:

The backend must verify that the assigning user is authorized as the tenant owner.

The database foreign key only confirms that the assigning user exists; it does not prove owner authorization.

---

## 4.3 Scheduling and Pricing Tables

### Table 10: `operating_hours`

**Purpose:** Stores the weekly operating schedule of each court.

Important columns:

| Column | Purpose |
|---|---|
| id | Schedule record ID |
| court_id | Related court |
| tenant_id | Owning business |
| day_of_week | Day of week (0–6) |
| opens_at | Opening time |
| closes_at | Closing time |
| closes_next_day | Whether closing occurs on the following day |
| created_at | Creation time |
| updated_at | Last update time |

Important design decisions:

- Each court can have its own operating hours.
- The table supports seven days of the week.
- `closes_next_day` supports overnight operation.
- Composite foreign keys maintain court and tenant consistency.
- A trigger/function prevents overlapping operating periods.

Why this table exists:

A court's operating schedule is different from its price schedule.

A court can be open from 5 AM to 11 PM while charging different prices at different times.

### Table 11: `weekly_price_rules`

**Purpose:** Stores recurring weekly prices for courts.

Important columns:

| Column | Purpose |
|---|---|
| id | Price rule ID |
| court_id | Related court |
| tenant_id | Owning business |
| day_of_week | Day of week |
| start_time | Start of price period |
| end_time | End of price period |
| price | Price for the period |
| created_at | Creation time |
| updated_at | Last update time |

Example:

Wednesday:

- 5 PM–6 PM: ₹500.
- 6 PM–7 PM: ₹600.

Important design decisions:

- Prices are recurring by weekday and time.
- Composite foreign keys protect tenant consistency.
- A GiST exclusion constraint prevents overlapping pricing periods for the same court and day.

Why this table exists:

Owners should not have to create prices separately for every future date.

A recurring rule automatically applies to matching future dates unless an override takes precedence.

### Table 12: `date_price_overrides`

**Purpose:** Stores prices that apply to a specific calendar date.

Important columns:

| Column | Purpose |
|---|---|
| id | Override ID |
| court_id | Related court |
| tenant_id | Owning business |
| override_date | Specific date |
| start_time | Start time |
| end_time | End time |
| price | Override price |
| created_at | Creation time |
| updated_at | Last update time |

Example:

The regular Wednesday 5 PM–6 PM price is ₹500.

For a particular Wednesday, the owner wants to charge ₹700.

A date-specific override is created for that date.

Important design decisions:

- Date-specific overrides take priority over recurring weekly rules.
- Composite foreign keys maintain tenant consistency.
- A GiST exclusion constraint prevents overlapping overrides for the same court and date.

Why this table exists:

Owners need to charge different prices for holidays, special events, and particular dates without changing their normal recurring pricing.

---

## 4.4 Booking Tables

### Table 13: `bookings`

**Purpose:** Represents a reservation, internal booking, or blocked court period.

Important columns:

| Column | Purpose |
|---|---|
| id | Booking ID |
| court_id | Booked court |
| tenant_id | Owning business |
| customer_id | Customer, when applicable |
| created_by_user_id | User who created the booking |
| booking_type | CUSTOMER, OWNER, or BLOCK |
| status | Current booking status |
| start_at | Booking start timestamp |
| end_at | Booking end timestamp |
| slot_period | Generated time range |
| total_amount | Booking total |
| currency | Currency; INR |
| hold_expires_at | Temporary hold expiry |
| notes | Optional booking notes |
| created_at | Creation time |
| updated_at | Last update time |

Booking types:

- CUSTOMER: A customer reservation.
- OWNER: An owner-created internal booking.
- BLOCK: A blocked court period.

Booking statuses:

- HOLD
- CONFIRMED
- EXPIRED
- CANCELLED
- COMPLETED
- BLOCKED

Important design decisions:

**Generated time range**

`slot_period` is generated from `start_at` and `end_at`.

The range uses `[)` semantics.

This means the start is included and the end is excluded.

For example:

- Booking A: 5 PM–6 PM.
- Booking B: 6 PM–7 PM.

These bookings do not overlap.

**Overlap protection**

A PostgreSQL GiST exclusion constraint prevents overlapping active bookings on the same court.

The constraint applies to active HOLD, CONFIRMED, and BLOCKED bookings.

**Temporary hold**

A customer booking initially has HOLD status.

It has a three-minute hold expiry timestamp.

Important: PostgreSQL does not automatically change a booking to EXPIRED when the timestamp passes.

The backend must implement an expiry worker that updates the booking status.

**Tenant consistency**

Composite foreign keys protect the relationship between a court and its tenant.

**Customer requirement**

A CUSTOMER booking must have a customer ID.

Why this table exists:

It is the central record for every reservation or blocked time period.

### Table 14: `booking_items`

**Purpose:** Stores the individual time slots inside a booking.

Example:

A customer books three consecutive slots:

- 4 PM–5 PM: ₹500.
- 5 PM–6 PM: ₹500.
- 6 PM–7 PM: ₹500.

One booking record contains three booking-item records.

Important columns:

| Column | Purpose |
|---|---|
| id | Booking item ID |
| booking_id | Parent booking |
| slot_start_at | Slot start timestamp |
| slot_end_at | Slot end timestamp |
| slot_period | Generated time range |
| slot_price | Price snapshot |
| created_at | Creation time |

Important design decisions:

- Each item belongs to a booking.
- Each item has its own price snapshot.
- A generated range represents the slot period.
- Unique and exclusion constraints protect item records.

Why store the price in each item?

Suppose the owner changes the price from ₹500 to ₹600 next week.

An existing booking must still retain the original ₹500 price.

Backend responsibility:

Validate that:
- Every item falls within the parent booking.
- Slot durations are valid.
- Slots are consecutive where required.
- The booking total equals the sum of item prices.

These checks are not all enforced by the current database schema.

---

## 4.5 Customer Payment Tables

### Table 15: `booking_payments`

**Purpose:** Stores customer payment transactions for bookings.

Important columns:

| Column | Purpose |
|---|---|
| id | Payment record ID |
| booking_id | Related booking |
| payment_provider | Payment provider |
| provider_order_id | Provider order identifier |
| provider_payment_id | Provider payment identifier |
| amount | Payment amount |
| currency | Currency |
| status | Payment status |
| failure_reason | Failure information |
| paid_at | Successful payment time |
| created_at | Creation time |
| updated_at | Last update time |

Payment statuses:

- PENDING
- SUCCESS
- FAILED
- REFUNDED
- PARTIALLY_REFUNDED

Important design decisions:

- A payment belongs to a booking.
- Provider order IDs and payment IDs have uniqueness protection where applicable.
- Payment state transitions must be validated by the backend.

Why this table exists:

A booking and its payment are different business concepts.

Keeping them separate provides a transaction history and supports payment retries and refunds.

### Table 16: `payment_webhook_events`

**Purpose:** Stores incoming payment-provider webhook events.

Important columns:

| Column | Purpose |
|---|---|
| id | Webhook record ID |
| payment_provider | Payment provider |
| provider_event_id | Unique provider event identifier |
| event_type | Event type |
| payload | Original event payload as JSONB |
| processing_status | Processing state |
| processing_error | Error details |
| received_at | Event receipt time |
| processed_at | Processing completion time |

Processing statuses:

- PENDING
- PROCESSED
- FAILED

Important design decisions:

- Provider and provider event ID are unique together.
- Original payload is retained as JSONB.
- Processing status supports retry and investigation.

Why this table exists:

Payment providers may send the same webhook more than once.

The backend must process events idempotently so repeated deliveries do not create duplicate effects.

### Table 17: `booking_refunds`

**Purpose:** Stores refund records for booking payments.

Important columns:

| Column | Purpose |
|---|---|
| id | Refund ID |
| payment_id | Related payment |
| provider_refund_id | Provider refund identifier |
| amount | Refund amount |
| currency | Currency |
| status | Refund status |
| reason | Refund reason |
| processed_at | Refund completion time |
| created_at | Creation time |
| updated_at | Last update time |

Refund statuses:

- PENDING
- PROCESSED
- FAILED

Important design decisions:

- A refund belongs to a payment.
- Provider refund IDs have uniqueness protection where applicable.
- Refund amounts and state transitions need backend validation.

Why this table exists:

A payment may be refunded fully or partially.

Separate refund records preserve a history of refund attempts and outcomes.

---

## 4.6 Venue Subscription Tables

### Table 18: `venue_subscriptions`

**Purpose:** Stores KarurTrufs subscriptions for individual venues.

Important columns:

| Column | Purpose |
|---|---|
| id | Subscription ID |
| venue_id | Subscribed venue |
| plan_name | Subscription plan |
| billing_cycle | MONTHLY or YEARLY |
| amount | Subscription amount |
| status | Subscription status |
| trial_starts_at | Trial start |
| trial_ends_at | Trial end |
| current_period_starts_at | Current billing period start |
| current_period_ends_at | Current billing period end |
| cancelled_at | Cancellation time |
| created_at | Creation time |
| updated_at | Last update time |

Subscription statuses:

- TRIAL
- ACTIVE
- PAST_DUE
- CANCELLED
- EXPIRED

Important design decisions:

- Subscription is per venue, not per court.
- Multiple courts in one venue are covered by that venue's subscription.
- A business with multiple venues has separate subscriptions.
- A partial unique index prevents multiple current subscriptions in the relevant active/trial/past-due states.
- Subscription periods are validated.

Why this table exists:

It represents the commercial relationship between KarurTrufs and a venue.

Customer booking payments must not be mixed with platform subscription revenue.

### Table 19: `subscription_payments`

**Purpose:** Stores payments made by venue owners to KarurTrufs.

Important columns:

| Column | Purpose |
|---|---|
| id | Subscription payment ID |
| subscription_id | Related subscription |
| payment_provider | Payment provider |
| provider_order_id | Provider order identifier |
| provider_payment_id | Provider payment identifier |
| amount | Payment amount |
| currency | Currency |
| status | Payment status |
| paid_at | Successful payment time |
| failure_reason | Failure details |
| created_at | Creation time |
| updated_at | Last update time |

Payment statuses:

- PENDING
- SUCCESS
- FAILED
- REFUNDED

Important design decisions:

- A payment belongs to a venue subscription.
- Provider order and payment IDs have uniqueness protection where applicable.

Why this table exists:

It keeps KarurTrufs subscription revenue separate from customer booking revenue.

---

## 4.7 Platform Operations Tables

### Table 20: `notifications`

**Purpose:** Stores notifications for application users.

Important columns:

| Column | Purpose |
|---|---|
| id | Notification ID |
| user_id | Recipient |
| tenant_id | Related tenant, when applicable |
| title | Notification title |
| message | Notification message |
| notification_type | Application notification type |
| channel | Delivery channel |
| is_read | Whether the user has read it |
| sent_at | Delivery time |
| created_at | Creation time |

Supported channels:

- IN_APP
- EMAIL
- SMS
- WHATSAPP

Initial implementation will focus on in-app notifications.

Email, SMS, and WhatsApp integrations can be added later.

Why this table exists:

It provides a common record of user notifications regardless of delivery channel.

### Table 21: `audit_logs`

**Purpose:** Stores important application activity for accountability and investigation.

Important columns:

| Column | Purpose |
|---|---|
| id | Audit record ID |
| tenant_id | Related tenant |
| user_id | Actor, nullable |
| action | Action performed |
| entity_type | Type of affected record |
| entity_id | ID of affected record |
| old_values | Previous values as JSONB |
| new_values | New values as JSONB |
| ip_address | Request IP address |
| created_at | Event time |

Examples of events:

- Court created.
- Court updated.
- Pricing changed.
- Manager assigned.
- Booking created.
- Booking cancelled.
- Subscription changed.

Why this table exists:

Audit logs provide a historical record of important operations.

Normal application users must not be allowed to modify or delete audit records.

---

# 5. Important Database Relationships

The following are the major relationships in the database.

| Parent | Child | Relationship |
|---|---|---|
| users | tenant_memberships | One user can have multiple memberships |
| tenants | tenant_memberships | One tenant has membership records |
| tenants | venues | One tenant has multiple venues |
| venues | courts | One venue has multiple courts |
| courts | operating_hours | One court has schedule records |
| courts | weekly_price_rules | One court has recurring price rules |
| courts | date_price_overrides | One court has date-specific overrides |
| courts | bookings | One court has multiple bookings over time |
| bookings | booking_items | One booking has multiple slot items |
| bookings | booking_payments | One booking can have payment records |
| booking_payments | booking_refunds | One payment can have refund records |
| payment_webhook_events | — | Independent record of provider events |
| venues | venue_subscriptions | One venue has subscription history |
| venue_subscriptions | subscription_payments | One subscription has payment records |
| users | user_auth_identities | One user can have linked authentication identities |
| users | otp_verifications | OTP records are associated by phone |
| users | user_sessions | One user can have multiple sessions |
| venues | venue_manager_assignments | One venue can have manager assignments |
| users | venue_manager_assignments | A user can be assigned as manager to multiple venues |
| users | notifications | One user can receive multiple notifications |
| tenants | audit_logs | One tenant can have many audit records |

The exact foreign-key definitions should be understood alongside the actual schema and ER diagram.

Some relationships use composite foreign keys to ensure that a referenced court or venue belongs to the expected tenant.

---

# 6. Important PostgreSQL Concepts Used

## 6.1 Primary keys

A primary key uniquely identifies a row.

Example:

`users.id`

We use UUID identifiers rather than relying on sequential integer IDs.

## 6.2 Foreign keys

A foreign key connects records between tables and prevents references to nonexistent parent records.

Example:

`venues.tenant_id` references `tenants.id`.

## 6.3 Composite foreign keys

A composite foreign key uses more than one column to validate a relationship.

Example:

A court relationship can validate both:

- `court_id`
- `tenant_id`

This helps prevent a record from referencing a court belonging to another tenant.

## 6.4 Unique constraints and indexes

These prevent duplicate data.

Examples:

- Unique email.
- Unique phone.
- One owner per tenant.
- One active manager assignment per venue/user pair.
- Unique provider order IDs.

## 6.5 Check constraints

These validate data conditions.

Examples:

- Valid booking types.
- Valid booking statuses.
- Valid subscription periods.
- Valid coordinates.
- Required customer ID for customer bookings.

## 6.6 Generated columns

Some columns are calculated from other columns.

Example:

`bookings.slot_period` is generated from `start_at` and `end_at`.

This avoids storing a separate time range that could disagree with its source timestamps.

## 6.7 Range types and `[)` semantics

PostgreSQL range values represent a time interval.

The booking range uses `[)`:

- `[` includes the starting time.
- `)` excludes the ending time.

This allows adjacent slots without treating them as overlapping.

## 6.8 Exclusion constraints

Exclusion constraints prevent conflicting records.

KarurTrufs uses them for:

- Overlapping active bookings on the same court.
- Overlapping recurring price periods.
- Overlapping date-specific price periods.

## 6.9 Triggers

Triggers execute database functions in response to certain database operations.

An operating-hours overlap check uses a trigger and the function `check_operating_hours_overlap()`.

The trigger has been created, but its real behaviour and concurrency characteristics still need testing.

## 6.10 JSONB

JSONB stores structured JSON data.

It is used for:

- Payment webhook payloads.
- Audit log old values.
- Audit log new values.

It is useful when the structure is variable or provider-specific.

## 6.11 Indexes

Indexes help PostgreSQL find records efficiently.

They are particularly important for:

- Foreign-key lookups.
- Booking availability.
- Tenant-scoped queries.
- Payment lookups.
- Manager assignments.

Indexes should be selected based on actual query patterns and execution plans as the application develops.

---

# 7. Important Business Rules Not Fully Enforced by the Database

The database protects many important relationships and constraints, but not all business logic belongs in SQL constraints.

The backend must enforce the following.

| Business rule | Backend responsibility |
|---|---|
| Tenant access | Verify the authenticated user has access |
| Manager permissions | Verify access to the particular assigned venue |
| Manager assignment | Verify the assigning user is the tenant owner |
| Booking item validation | Check item times against the parent booking |
| Consecutive slots | Validate the selected slots |
| Booking total | Calculate total from item price snapshots |
| Price selection | Apply date override before weekly rule |
| Booking hold expiry | Update expired HOLD records to EXPIRED |
| Payment confirmation | Verify provider payment and booking state |
| Webhook idempotency | Avoid duplicate processing |
| Refund limits | Prevent excessive refunds |
| Subscription lifecycle | Validate billing and expiry transitions |
| Audit immutability | Prevent normal users from modifying audit records |

---

# 8. Known Limitations and Follow-up Work

The following issues must be addressed as development progresses.

1. `updated_at` defaults to NOW(), but does not automatically update on every UPDATE. The backend must set it explicitly or a trigger can be introduced later.
2. Booking items require backend validation for their relationship to parent booking times.
3. Booking holds require an expiry worker; timestamps alone do not release exclusion constraints.
4. The manager assignment table does not independently verify that the assigning user is the business owner.
5. Row-Level Security is not currently implemented.
6. Webhook processing and payment state transitions require backend implementation.
7. Refund aggregation and validation require backend logic.
8. Subscription lifecycle rules require backend implementation.
9. Operating-hours trigger behaviour and concurrency need real database tests.
10. There is no complete automated database integration-test suite yet.

Do not add new migrations simply to address these points without first evaluating whether the requirement belongs in the database or backend.

---

# 9. Migration History

The database was built through numbered SQL migration files stored in:

`database/migrations/`

Migrations 001–040 have been executed and recorded.

The `schema_migrations` table stores:

- version
- name
- checksum
- applied_at

There are 40 recorded migration entries.

The migration files cover:

- Core entities.
- Business and venue relationships.
- Scheduling and pricing.
- Bookings and payments.
- Subscriptions.
- Authentication.
- Tenant integrity.
- Constraints and indexes.
- Operating-hours and pricing overlap prevention.

A proper automated migration runner has not yet been implemented.

---

# 10. Database Summary

The KarurTrufs database consists of 21 application tables organized around identity, business ownership, venues, courts, scheduling, pricing, bookings, payments, subscriptions, and platform operations.

The main design priorities are:

1. Keep each business's data isolated.
2. Preserve referential integrity.
3. Prevent overlapping bookings.
4. Support recurring and date-specific prices.
5. Preserve historical booking prices.
6. Separate customer payments from platform subscriptions.
7. Support venue-level manager permissions.
8. Keep important activity records for auditing.

The database provides the foundation for the backend, but the application still needs authentication, authorization, transactional business logic, background jobs, payment integration, and automated testing.