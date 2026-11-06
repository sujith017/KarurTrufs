# KarurTrufs — Database Relationships and ER Design

## 1. Introduction

This document explains how the 21 application tables in KarurTrufs are connected.

It focuses on:

- Primary key relationships.
- Foreign key relationships.
- One-to-many relationships.
- Many-to-many relationships.
- Tenant-level data isolation.
- Booking and payment relationships.
- Important database design decisions.

The database uses PostgreSQL and a shared multi-tenant architecture.

The ER diagram should be viewed alongside this document.

## 2. Overall Entity Relationship Structure

The main business relationship is:

```text
TENANTS
   |
   | 1:N
   v
VENUES
   |
   | 1:N
   v
COURTS
   |
   | 1:N
   +---------------------+
   |                     |
   v                     v
OPERATING_HOURS     WEEKLY_PRICE_RULES
                         |
                    DATE_PRICE_OVERRIDES
```

The booking relationship is:

```text
COURTS
   |
   | 1:N
   v
BOOKINGS
   |
   | 1:N
   v
BOOKING_ITEMS

BOOKINGS
   |
   | 1:N
   v
BOOKING_PAYMENTS
   |
   | 1:N
   v
BOOKING_REFUNDS
```

The subscription relationship is:

```text
VENUES
   |
   | 1:N
   v
VENUE_SUBSCRIPTIONS
   |
   | 1:N
   v
SUBSCRIPTION_PAYMENTS
```

The identity and access relationship is:

```text
USERS
   |
   +---- TENANT_MEMBERSHIPS ---- TENANTS
   |
   +---- USER_AUTH_IDENTITIES
   |
   +---- USER_SESSIONS
   |
   +---- NOTIFICATIONS
   |
   +---- VENUE_MANAGER_ASSIGNMENTS ---- VENUES
```

These are conceptual relationships. Refer to the actual foreign-key definitions for exact database cardinalities and optionality.

## 3. Main Business Relationships

### 3.1 Tenant to Venue

Relationship: One-to-many.

```text
tenants (1) -------- (N) venues
```

A business can have multiple venues.

Every venue belongs to one tenant.

Example:

```text
Business: ABC Sports
   |
   |-- Venue: Karur Sports Arena
   |-- Venue: Play Karur
   |-- Venue: Matrix Turf
```

Database columns:

- `tenants.id`
- `venues.tenant_id`

The `venues.tenant_id` foreign key references `tenants.id`.

Why this relationship exists:

A business can operate multiple physical locations, while all its venues remain under one business account.

### 3.2 Venue to Court

Relationship: One-to-many.

```text
venues (1) -------- (N) courts
```

A venue can have multiple courts.

Every court belongs to one venue.

Example:

```text
Karur Sports Arena
   |
   |-- Football Court
   |-- Cricket Net 1
   |-- Cricket Net 2
```

Database columns:

- `venues.id`
- `courts.venue_id`

The court also stores `tenant_id` to maintain tenant consistency.

### 3.3 User to Tenant Membership

Relationship: One-to-many through `tenant_memberships`.

```text
users (1) -------- (N) tenant_memberships
tenants (1) ------ (N) tenant_memberships
```

The membership table connects users to businesses.

A user can have multiple membership records, and a tenant has its membership records.

Currently, the membership role is OWNER only.

A partial unique index ensures that a tenant has at most one owner.

Why this relationship exists:

It separates user identity from business ownership.

A user account and a business account are different concepts.

### 3.4 User to Venue Manager Assignment

Relationship: One-to-many through `venue_manager_assignments`.

```text
users (1) -------- (N) venue_manager_assignments
venues (1) ------- (N) venue_manager_assignments
```

The assignment table connects a manager to a specific venue.

Example:

```text
Business A
   |
   |-- Venue 1
   |      |
   |      |-- Manager X
   |
   |-- Venue 2
          |
          |-- Manager Y
```

Manager X must not automatically receive access to Venue 2.

Important columns:

- `venue_manager_assignments.tenant_id`
- `venue_manager_assignments.venue_id`
- `venue_manager_assignments.manager_user_id`
- `venue_manager_assignments.assigned_by_user_id`

The database supports assignment history through revocation fields.

The backend must verify that the user creating an assignment is authorized to do so.

### 3.5 Court to Operating Hours

Relationship: One-to-many.

```text
courts (1) -------- (N) operating_hours
```

Each court can have multiple weekly operating-hour records.

Example:

```text
Football Court
   |
   |-- Monday: 05:00–23:00
   |-- Tuesday: 05:00–23:00
   |-- Wednesday: 05:00–23:00
```

Why this relationship exists:

Different courts in the same venue may have different operating schedules.

### 3.6 Court to Weekly Price Rules

Relationship: One-to-many.

```text
courts (1) -------- (N) weekly_price_rules
```

Each court can have multiple recurring price rules.

Example:

```text
Football Court
   |
   |-- Monday, 05:00–06:00: ₹500
   |-- Monday, 06:00–07:00: ₹600
   |-- Tuesday, 05:00–06:00: ₹450
```

### 3.7 Court to Date Price Overrides

Relationship: One-to-many.

```text
courts (1) -------- (N) date_price_overrides
```

Each court can have multiple date-specific pricing overrides.

Example:

```text
Football Court
   |
   |-- 11 November, 05:00–06:00: ₹700
   |-- 25 December, 05:00–06:00: ₹900
```

The backend must prioritize date-specific pricing over weekly recurring pricing.

## 4. Booking Relationships

### 4.1 Court to Booking

Relationship: One-to-many.

```text
courts (1) -------- (N) bookings
```

A court can have many bookings over time.

A booking belongs to one court.

The database prevents overlapping active booking periods for the same court.

### 4.2 User to Booking

The `bookings` table contains two user references:

- `customer_id`
- `created_by_user_id`

They represent different concepts.

`customer_id` identifies the customer making the reservation.

`created_by_user_id` identifies the user who created the booking.

For example:

An owner may create an internal booking on behalf of their venue.

The customer and creator need not be the same person.

Customer bookings require a customer ID. Other booking types have different rules.

### 4.3 Booking to Booking Items

Relationship: One-to-many.

```text
bookings (1) -------- (N) booking_items
```

One booking can contain multiple slot items.

Example:

```text
Booking ID: B001
   |
   |-- 04:00–05:00: ₹500
   |-- 05:00–06:00: ₹500
   |-- 06:00–07:00: ₹500
```

The total amount is ₹1,500.

Each booking item stores its own price snapshot.

Why this relationship exists:

It allows customers to reserve multiple consecutive slots as one booking while retaining the price of each slot.

### 4.4 Booking to Booking Payments

Relationship: One-to-many.

```text
bookings (1) -------- (N) booking_payments
```

A booking can have payment records.

Keeping payments separate from bookings supports retries, failed attempts, and payment history.

### 4.5 Booking Payment to Refund

Relationship: One-to-many.

```text
booking_payments (1) -------- (N) booking_refunds
```

A payment can have refund records.

Example:

```text
Payment: ₹1,500
   |
   |-- Refund 1: ₹500
   |-- Refund 2: ₹250
```

The backend must ensure that cumulative refunds do not exceed the refundable amount.

### 4.6 Payment Webhook Events

`payment_webhook_events` stores events received from payment providers.

It is not directly connected to a booking through a foreign key in the current schema.

The provider event ID and provider combination are unique.

Why this table exists:

Payment providers may send duplicate webhook events. The backend needs to record and process these events safely.

## 5. Subscription Relationships

### 5.1 Venue to Venue Subscription

Relationship: One-to-many over time.

```text
venues (1) -------- (N) venue_subscriptions
```

A venue can have subscription history.

Only one current subscription is allowed for the relevant active, trial, and past-due states under the partial unique index.

Example:

```text
Karur Sports Arena
   |
   |-- Trial Subscription
   |-- Monthly Subscription
   |-- Renewed Subscription
```

Why this relationship exists:

The subscription is billed per venue, not per court.

A business with multiple venues has separate venue subscription records.

### 5.2 Venue Subscription to Subscription Payments

Relationship: One-to-many.

```text
venue_subscriptions (1) -------- (N) subscription_payments
```

Each subscription can have multiple payment records over time.

These payments represent money paid by the business owner to KarurTrufs.

They are separate from customer booking payments.

## 6. Authentication Relationships

### 6.1 User to Authentication Identities

Relationship: One-to-many.

```text
users (1) -------- (N) user_auth_identities
```

A user can have linked external authentication identities.

For example, a user may connect a Google identity to an existing KarurTrufs account.

### 6.2 User to Sessions

Relationship: One-to-many.

```text
users (1) -------- (N) user_sessions
```

A user can have multiple sessions across different devices.

This supports device-specific session revocation and logout from all devices.

### 6.3 OTP Verification Records

`otp_verifications` stores verification records associated with phone numbers.

It uses the phone number rather than a direct user foreign key in the current design.

This supports verification before or during account creation.

The backend must enforce OTP purpose, expiry, attempt limits, and successful verification.

## 7. Notifications and Audit Relationships

### 7.1 User to Notifications

Relationship: One-to-many.

```text
users (1) -------- (N) notifications
```

A user can receive multiple notifications.

A notification can optionally contain a tenant reference.

### 7.2 Tenant to Audit Logs

Relationship: One-to-many.

```text
tenants (1) -------- (N) audit_logs
```

A tenant can have multiple audit records.

Audit records may also identify the user who performed the action.

The actor user ID is nullable to allow records without an associated authenticated user, where applicable.

Normal users must not be able to modify or delete audit records.

## 8. Composite Foreign Keys and Tenant Integrity

KarurTrufs uses composite foreign keys in several important relationships.

A normal foreign key checks one referenced column.

A composite foreign key checks multiple columns together.

Example:

```text
courts:
    id
    tenant_id

bookings:
    court_id
    tenant_id
```

The booking should reference a court belonging to the same tenant.

Conceptually:

```text
bookings(court_id, tenant_id)
          |
          v
courts(id, tenant_id)
```

This prevents a booking from referencing a court under a different tenant.

Similar tenant consistency checks exist in important scheduling and pricing relationships.

This database protection complements backend authorization. It does not replace authorization.

## 9. Important Relationship Summary

| Parent table | Child table | Relationship | Purpose |
|---|---|---|---|
| tenants | venues | 1:N | Business owns venues |
| tenants | tenant_memberships | 1:N | Business ownership membership |
| users | tenant_memberships | 1:N | User membership records |
| venues | courts | 1:N | Venue contains courts |
| users | venue_manager_assignments | 1:N | User can receive multiple assignments |
| venues | venue_manager_assignments | 1:N | Venue can have managers |
| courts | operating_hours | 1:N | Court schedules |
| courts | weekly_price_rules | 1:N | Recurring prices |
| courts | date_price_overrides | 1:N | Specific-date prices |
| courts | bookings | 1:N | Court booking history |
| bookings | booking_items | 1:N | Booking contains slots |
| bookings | booking_payments | 1:N | Booking payment records |
| booking_payments | booking_refunds | 1:N | Payment refund records |
| venues | venue_subscriptions | 1:N | Venue subscription history |
| venue_subscriptions | subscription_payments | 1:N | Subscription payment history |
| users | user_auth_identities | 1:N | External login identities |
| users | user_sessions | 1:N | User sessions |
| users | notifications | 1:N | User notifications |
| tenants | audit_logs | 1:N | Business audit history |

The table describes the intended business relationships. Exact foreign-key optionality and uniqueness should be checked against the live PostgreSQL schema.

## 10. Important Design Principles

The KarurTrufs relationship design follows these principles:

1. A business is represented by a tenant.
2. A tenant can own multiple venues.
3. A venue can contain multiple courts.
4. Managers receive venue-level assignments rather than automatic business-wide access.
5. Operating hours and pricing are separate concepts.
6. Weekly prices and date-specific overrides are stored separately.
7. One booking can contain multiple slot items.
8. Booking and payment records are separate.
9. Booking payments and subscription payments are separate.
10. Venue subscriptions are billed per venue.
11. Composite foreign keys help protect tenant consistency.
12. Backend authorization remains responsible for access control.

## 11. ER Diagram Reference

The visual ER diagram is maintained in dbdiagram.io.

Use the diagram to inspect:

- Primary keys.
- Foreign keys.
- One-to-many relationships.
- Composite relationships.
- Entity dependencies.

Keep the diagram synchronized with the actual PostgreSQL schema as future migrations are introduced.

## 12. Current Status

The database contains 21 application tables.

Forty numbered migrations have been executed and recorded.

The schema has been exported from Neon and imported into dbdiagram.io.

The database design is ready for documentation review. Backend implementation and automated integration tests are still pending.