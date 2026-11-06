--
-- PostgreSQL database dump
--

\restrict K1Ts1xbxX2grG28377zC5AIFdD2YhqBYxFm191w8f86CPXCHkmcMmBs6d7QrPiZ

-- Dumped from database version 18.6 (ac70818)
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: check_operating_hours_overlap(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_operating_hours_overlap() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_start BIGINT;
    new_duration BIGINT;
    has_overlap BOOLEAN;
BEGIN
    -- Serialize schedule changes for the affected court.
    -- Lock both courts in a consistent order if court_id changes.
    IF TG_OP = 'UPDATE' AND OLD.court_id <> NEW.court_id THEN
        IF OLD.court_id::text < NEW.court_id::text THEN
            PERFORM pg_advisory_xact_lock(
                hashtextextended(OLD.court_id::text, 0)
            );
            PERFORM pg_advisory_xact_lock(
                hashtextextended(NEW.court_id::text, 0)
            );
        ELSE
            PERFORM pg_advisory_xact_lock(
                hashtextextended(NEW.court_id::text, 0)
            );
            PERFORM pg_advisory_xact_lock(
                hashtextextended(OLD.court_id::text, 0)
            );
        END IF;
    ELSE
        PERFORM pg_advisory_xact_lock(
            hashtextextended(NEW.court_id::text, 0)
        );
    END IF;

    -- Convert the new period into seconds on a weekly timeline.
    new_start :=
        NEW.day_of_week::BIGINT * 86400
        + EXTRACT(EPOCH FROM NEW.opens_at)::BIGINT;

    new_duration :=
        CASE
            WHEN NEW.closes_next_day THEN
                86400
                - EXTRACT(EPOCH FROM NEW.opens_at)::BIGINT
                + EXTRACT(EPOCH FROM NEW.closes_at)::BIGINT
            ELSE
                EXTRACT(EPOCH FROM NEW.closes_at)::BIGINT
                - EXTRACT(EPOCH FROM NEW.opens_at)::BIGINT
        END;

    -- Check existing periods, including copies shifted by
    -- one week in either direction to handle Sunday/Monday.
    SELECT EXISTS (
        SELECT 1
        FROM operating_hours oh
        CROSS JOIN generate_series(-1, 1) AS week_shift(n)
        CROSS JOIN LATERAL (
            SELECT
                oh.day_of_week::BIGINT * 86400
                + EXTRACT(EPOCH FROM oh.opens_at)::BIGINT
                    AS period_start,

                CASE
                    WHEN oh.closes_next_day THEN
                        86400
                        - EXTRACT(EPOCH FROM oh.opens_at)::BIGINT
                        + EXTRACT(EPOCH FROM oh.closes_at)::BIGINT
                    ELSE
                        EXTRACT(EPOCH FROM oh.closes_at)::BIGINT
                        - EXTRACT(EPOCH FROM oh.opens_at)::BIGINT
                END AS period_duration
        ) p
        WHERE oh.court_id = NEW.court_id
          AND oh.id IS DISTINCT FROM NEW.id
          AND new_start <
              p.period_start + (week_shift.n * 604800)
              + p.period_duration
          AND p.period_start + (week_shift.n * 604800)
              < new_start + new_duration
    )
    INTO has_overlap;

    IF has_overlap THEN
        RAISE EXCEPTION
            'Operating hours overlap with an existing period for this court.'
            USING ERRCODE = '23P01';
    END IF;

    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    user_id uuid,
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid,
    old_values jsonb,
    new_values jsonb,
    ip_address inet,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: booking_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.booking_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    booking_id uuid NOT NULL,
    slot_start_at timestamp with time zone NOT NULL,
    slot_end_at timestamp with time zone NOT NULL,
    slot_price numeric(12,2) NOT NULL,
    slot_period tstzrange GENERATED ALWAYS AS (tstzrange(slot_start_at, slot_end_at, '[)'::text)) STORED,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT booking_items_slot_price_check CHECK ((slot_price >= (0)::numeric)),
    CONSTRAINT valid_booking_item_time CHECK ((slot_end_at > slot_start_at))
);


--
-- Name: booking_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.booking_payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    booking_id uuid NOT NULL,
    payment_provider text DEFAULT 'RAZORPAY'::text NOT NULL,
    provider_order_id text,
    provider_payment_id text,
    amount numeric(12,2) NOT NULL,
    currency character(3) DEFAULT 'INR'::bpchar NOT NULL,
    status text DEFAULT 'PENDING'::text NOT NULL,
    failure_reason text,
    paid_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT booking_payments_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT booking_payments_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'SUCCESS'::text, 'FAILED'::text, 'REFUNDED'::text, 'PARTIALLY_REFUNDED'::text])))
);


--
-- Name: booking_refunds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.booking_refunds (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    payment_id uuid NOT NULL,
    provider_refund_id text,
    amount numeric(12,2) NOT NULL,
    currency character(3) DEFAULT 'INR'::bpchar NOT NULL,
    status text DEFAULT 'PENDING'::text NOT NULL,
    reason text,
    processed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT booking_refunds_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT booking_refunds_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'PROCESSED'::text, 'FAILED'::text])))
);


--
-- Name: bookings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bookings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    court_id uuid NOT NULL,
    customer_id uuid,
    created_by_user_id uuid,
    booking_type text NOT NULL,
    status text NOT NULL,
    start_at timestamp with time zone NOT NULL,
    end_at timestamp with time zone NOT NULL,
    slot_period tstzrange GENERATED ALWAYS AS (tstzrange(start_at, end_at, '[)'::text)) STORED,
    total_amount numeric(12,2) DEFAULT 0 NOT NULL,
    currency character(3) DEFAULT 'INR'::bpchar NOT NULL,
    hold_expires_at timestamp with time zone,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    tenant_id uuid NOT NULL,
    CONSTRAINT bookings_booking_type_check CHECK ((booking_type = ANY (ARRAY['CUSTOMER'::text, 'OWNER'::text, 'BLOCK'::text]))),
    CONSTRAINT bookings_status_check CHECK ((status = ANY (ARRAY['HOLD'::text, 'CONFIRMED'::text, 'EXPIRED'::text, 'CANCELLED'::text, 'COMPLETED'::text, 'BLOCKED'::text]))),
    CONSTRAINT bookings_total_amount_check CHECK ((total_amount >= (0)::numeric)),
    CONSTRAINT customer_booking_requires_customer CHECK (((booking_type <> 'CUSTOMER'::text) OR (customer_id IS NOT NULL))),
    CONSTRAINT hold_expiry_only_for_hold CHECK (((status = 'HOLD'::text) OR (hold_expires_at IS NULL))),
    CONSTRAINT hold_requires_expiry CHECK (((status <> 'HOLD'::text) OR (hold_expires_at IS NOT NULL))),
    CONSTRAINT valid_booking_time CHECK ((end_at > start_at)),
    CONSTRAINT valid_booking_type_status CHECK ((((booking_type = 'CUSTOMER'::text) AND (status = ANY (ARRAY['HOLD'::text, 'CONFIRMED'::text, 'EXPIRED'::text, 'CANCELLED'::text, 'COMPLETED'::text]))) OR ((booking_type = 'OWNER'::text) AND (status = ANY (ARRAY['CONFIRMED'::text, 'CANCELLED'::text, 'COMPLETED'::text]))) OR ((booking_type = 'BLOCK'::text) AND (status = 'BLOCKED'::text))))
);


--
-- Name: courts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.courts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    venue_id uuid NOT NULL,
    court_name text NOT NULL,
    sport_name text NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    tenant_id uuid NOT NULL
);


--
-- Name: date_price_overrides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.date_price_overrides (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    court_id uuid NOT NULL,
    override_date date NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    price numeric(12,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    tenant_id uuid NOT NULL,
    CONSTRAINT date_price_overrides_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT valid_override_slot CHECK ((end_time > start_time))
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    tenant_id uuid,
    title text NOT NULL,
    message text NOT NULL,
    notification_type text NOT NULL,
    channel text DEFAULT 'IN_APP'::text NOT NULL,
    is_read boolean DEFAULT false NOT NULL,
    sent_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT notifications_channel_check CHECK ((channel = ANY (ARRAY['IN_APP'::text, 'EMAIL'::text, 'SMS'::text, 'WHATSAPP'::text])))
);


--
-- Name: operating_hours; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operating_hours (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    court_id uuid NOT NULL,
    day_of_week smallint NOT NULL,
    opens_at time without time zone NOT NULL,
    closes_at time without time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    tenant_id uuid NOT NULL,
    closes_next_day boolean DEFAULT false NOT NULL,
    CONSTRAINT operating_hours_day_of_week_check CHECK (((day_of_week >= 0) AND (day_of_week <= 6))),
    CONSTRAINT valid_operating_time CHECK ((((closes_next_day = false) AND (closes_at > opens_at)) OR ((closes_next_day = true) AND (closes_at <= opens_at))))
);


--
-- Name: otp_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.otp_verifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    phone text NOT NULL,
    otp_hash text NOT NULL,
    purpose text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    verified_at timestamp with time zone,
    attempts integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT otp_verifications_attempts_check CHECK ((attempts >= 0)),
    CONSTRAINT otp_verifications_purpose_check CHECK ((purpose = ANY (ARRAY['LOGIN'::text, 'PHONE_VERIFICATION'::text])))
);


--
-- Name: payment_webhook_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_webhook_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    payment_provider text DEFAULT 'RAZORPAY'::text NOT NULL,
    provider_event_id text NOT NULL,
    event_type text NOT NULL,
    payload jsonb NOT NULL,
    processing_status text DEFAULT 'PENDING'::text NOT NULL,
    processing_error text,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    processed_at timestamp with time zone,
    CONSTRAINT payment_webhook_events_processing_status_check CHECK ((processing_status = ANY (ARRAY['PENDING'::text, 'PROCESSED'::text, 'FAILED'::text])))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying(20) NOT NULL,
    name character varying(255) NOT NULL,
    checksum text,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: subscription_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscription_payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    subscription_id uuid NOT NULL,
    payment_provider text DEFAULT 'RAZORPAY'::text NOT NULL,
    provider_order_id text,
    provider_payment_id text,
    amount numeric(12,2) NOT NULL,
    currency character(3) DEFAULT 'INR'::bpchar NOT NULL,
    status text DEFAULT 'PENDING'::text NOT NULL,
    paid_at timestamp with time zone,
    failure_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT subscription_payments_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT subscription_payments_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'SUCCESS'::text, 'FAILED'::text, 'REFUNDED'::text])))
);


--
-- Name: tenant_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_memberships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT tenant_memberships_owner_only CHECK ((role = 'OWNER'::text))
);


--
-- Name: tenants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_auth_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_auth_identities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    provider text NOT NULL,
    provider_user_id text NOT NULL,
    provider_email text,
    provider_email_verified boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_auth_identities_provider_check CHECK ((provider = 'GOOGLE'::text))
);


--
-- Name: user_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    refresh_token_hash text NOT NULL,
    device_info text,
    ip_address inet,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    last_used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    full_name text NOT NULL,
    email text,
    phone text,
    password_hash text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    email_verified_at timestamp with time zone,
    phone_verified_at timestamp with time zone,
    CONSTRAINT users_email_or_phone_required CHECK (((email IS NOT NULL) OR (phone IS NOT NULL)))
);


--
-- Name: venue_manager_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.venue_manager_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    venue_id uuid NOT NULL,
    manager_user_id uuid NOT NULL,
    assigned_by_user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    revoked_by_user_id uuid
);


--
-- Name: venue_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.venue_subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    venue_id uuid NOT NULL,
    plan_name text NOT NULL,
    billing_cycle text DEFAULT 'MONTHLY'::text NOT NULL,
    amount numeric(12,2) NOT NULL,
    status text DEFAULT 'TRIAL'::text NOT NULL,
    trial_starts_at timestamp with time zone,
    trial_ends_at timestamp with time zone,
    current_period_starts_at timestamp with time zone,
    current_period_ends_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT valid_subscription_period CHECK (((current_period_ends_at IS NULL) OR (current_period_starts_at IS NULL) OR (current_period_ends_at > current_period_starts_at))),
    CONSTRAINT valid_trial_period CHECK (((trial_ends_at IS NULL) OR (trial_starts_at IS NULL) OR (trial_ends_at > trial_starts_at))),
    CONSTRAINT venue_subscriptions_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT venue_subscriptions_billing_cycle_check CHECK ((billing_cycle = ANY (ARRAY['MONTHLY'::text, 'YEARLY'::text]))),
    CONSTRAINT venue_subscriptions_status_check CHECK ((status = ANY (ARRAY['TRIAL'::text, 'ACTIVE'::text, 'PAST_DUE'::text, 'CANCELLED'::text, 'EXPIRED'::text])))
);


--
-- Name: venues; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.venues (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    venue_name text NOT NULL,
    description text,
    address text NOT NULL,
    latitude numeric(10,7),
    longitude numeric(10,7),
    google_maps_url text,
    timezone text DEFAULT 'Asia/Kolkata'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT latitude_longitude_together CHECK ((((latitude IS NULL) AND (longitude IS NULL)) OR ((latitude IS NOT NULL) AND (longitude IS NOT NULL)))),
    CONSTRAINT valid_latitude CHECK (((latitude IS NULL) OR ((latitude >= ('-90'::integer)::numeric) AND (latitude <= (90)::numeric)))),
    CONSTRAINT valid_longitude CHECK (((longitude IS NULL) OR ((longitude >= ('-180'::integer)::numeric) AND (longitude <= (180)::numeric))))
);


--
-- Name: weekly_price_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.weekly_price_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    court_id uuid NOT NULL,
    day_of_week smallint NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    price numeric(12,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    tenant_id uuid NOT NULL,
    CONSTRAINT valid_price_slot CHECK ((end_time > start_time)),
    CONSTRAINT weekly_price_rules_day_of_week_check CHECK (((day_of_week >= 0) AND (day_of_week <= 6))),
    CONSTRAINT weekly_price_rules_price_check CHECK ((price >= (0)::numeric))
);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: booking_items booking_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_items
    ADD CONSTRAINT booking_items_pkey PRIMARY KEY (id);


--
-- Name: booking_payments booking_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_payments
    ADD CONSTRAINT booking_payments_pkey PRIMARY KEY (id);


--
-- Name: booking_refunds booking_refunds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_refunds
    ADD CONSTRAINT booking_refunds_pkey PRIMARY KEY (id);


--
-- Name: bookings bookings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_pkey PRIMARY KEY (id);


--
-- Name: courts courts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courts
    ADD CONSTRAINT courts_pkey PRIMARY KEY (id);


--
-- Name: date_price_overrides date_price_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.date_price_overrides
    ADD CONSTRAINT date_price_overrides_pkey PRIMARY KEY (id);


--
-- Name: bookings no_overlapping_active_bookings; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT no_overlapping_active_bookings EXCLUDE USING gist (court_id WITH =, slot_period WITH &&) WHERE ((status = ANY (ARRAY['HOLD'::text, 'CONFIRMED'::text, 'BLOCKED'::text])));


--
-- Name: booking_items no_overlapping_booking_items; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_items
    ADD CONSTRAINT no_overlapping_booking_items EXCLUDE USING gist (booking_id WITH =, slot_period WITH &&);


--
-- Name: date_price_overrides no_overlapping_date_price_overrides; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.date_price_overrides
    ADD CONSTRAINT no_overlapping_date_price_overrides EXCLUDE USING gist (court_id WITH =, override_date WITH =, int4range((EXTRACT(epoch FROM start_time))::integer, (EXTRACT(epoch FROM end_time))::integer, '[)'::text) WITH &&);


--
-- Name: weekly_price_rules no_overlapping_weekly_price_rules; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_price_rules
    ADD CONSTRAINT no_overlapping_weekly_price_rules EXCLUDE USING gist (court_id WITH =, day_of_week WITH =, int4range((EXTRACT(epoch FROM start_time))::integer, (EXTRACT(epoch FROM end_time))::integer, '[)'::text) WITH &&);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: operating_hours operating_hours_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operating_hours
    ADD CONSTRAINT operating_hours_pkey PRIMARY KEY (id);


--
-- Name: otp_verifications otp_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.otp_verifications
    ADD CONSTRAINT otp_verifications_pkey PRIMARY KEY (id);


--
-- Name: payment_webhook_events payment_webhook_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_webhook_events
    ADD CONSTRAINT payment_webhook_events_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_name_key UNIQUE (name);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: subscription_payments subscription_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_payments
    ADD CONSTRAINT subscription_payments_pkey PRIMARY KEY (id);


--
-- Name: tenant_memberships tenant_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_memberships
    ADD CONSTRAINT tenant_memberships_pkey PRIMARY KEY (id);


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);


--
-- Name: booking_items unique_booking_slot; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_items
    ADD CONSTRAINT unique_booking_slot UNIQUE (booking_id, slot_start_at);


--
-- Name: date_price_overrides unique_court_date_slot; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.date_price_overrides
    ADD CONSTRAINT unique_court_date_slot UNIQUE (court_id, override_date, start_time);


--
-- Name: operating_hours unique_court_day_opening; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operating_hours
    ADD CONSTRAINT unique_court_day_opening UNIQUE (court_id, day_of_week, opens_at);


--
-- Name: courts unique_court_name_per_venue; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courts
    ADD CONSTRAINT unique_court_name_per_venue UNIQUE (venue_id, court_name);


--
-- Name: courts unique_court_tenant_pair; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courts
    ADD CONSTRAINT unique_court_tenant_pair UNIQUE (id, tenant_id);


--
-- Name: weekly_price_rules unique_court_weekly_slot; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_price_rules
    ADD CONSTRAINT unique_court_weekly_slot UNIQUE (court_id, day_of_week, start_time);


--
-- Name: user_auth_identities unique_provider_identity; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_auth_identities
    ADD CONSTRAINT unique_provider_identity UNIQUE (provider, provider_user_id);


--
-- Name: payment_webhook_events unique_provider_webhook_event; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_webhook_events
    ADD CONSTRAINT unique_provider_webhook_event UNIQUE (payment_provider, provider_event_id);


--
-- Name: tenant_memberships unique_user_per_tenant; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_memberships
    ADD CONSTRAINT unique_user_per_tenant UNIQUE (tenant_id, user_id);


--
-- Name: venues unique_venue_tenant_pair; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT unique_venue_tenant_pair UNIQUE (id, tenant_id);


--
-- Name: user_auth_identities user_auth_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_auth_identities
    ADD CONSTRAINT user_auth_identities_pkey PRIMARY KEY (id);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);


--
-- Name: user_sessions user_sessions_refresh_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_refresh_token_hash_key UNIQUE (refresh_token_hash);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: venue_manager_assignments venue_manager_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_manager_assignments
    ADD CONSTRAINT venue_manager_assignments_pkey PRIMARY KEY (id);


--
-- Name: venue_subscriptions venue_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_subscriptions
    ADD CONSTRAINT venue_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: venues venues_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_pkey PRIMARY KEY (id);


--
-- Name: weekly_price_rules weekly_price_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_price_rules
    ADD CONSTRAINT weekly_price_rules_pkey PRIMARY KEY (id);


--
-- Name: audit_logs_entity_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_entity_idx ON public.audit_logs USING btree (entity_type, entity_id);


--
-- Name: audit_logs_tenant_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_tenant_created_idx ON public.audit_logs USING btree (tenant_id, created_at DESC);


--
-- Name: booking_items_booking_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX booking_items_booking_id_idx ON public.booking_items USING btree (booking_id);


--
-- Name: booking_payments_booking_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX booking_payments_booking_id_idx ON public.booking_payments USING btree (booking_id);


--
-- Name: booking_payments_provider_order_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX booking_payments_provider_order_idx ON public.booking_payments USING btree (payment_provider, provider_order_id) WHERE (provider_order_id IS NOT NULL);


--
-- Name: booking_payments_provider_payment_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX booking_payments_provider_payment_idx ON public.booking_payments USING btree (payment_provider, provider_payment_id) WHERE (provider_payment_id IS NOT NULL);


--
-- Name: booking_refunds_payment_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX booking_refunds_payment_id_idx ON public.booking_refunds USING btree (payment_id);


--
-- Name: booking_refunds_provider_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX booking_refunds_provider_id_idx ON public.booking_refunds USING btree (provider_refund_id) WHERE (provider_refund_id IS NOT NULL);


--
-- Name: bookings_court_start_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX bookings_court_start_idx ON public.bookings USING btree (court_id, start_at);


--
-- Name: bookings_customer_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX bookings_customer_id_idx ON public.bookings USING btree (customer_id);


--
-- Name: bookings_status_expiry_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX bookings_status_expiry_idx ON public.bookings USING btree (status, hold_expires_at) WHERE (status = 'HOLD'::text);


--
-- Name: bookings_tenant_start_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX bookings_tenant_start_idx ON public.bookings USING btree (tenant_id, start_at);


--
-- Name: courts_tenant_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX courts_tenant_id_idx ON public.courts USING btree (tenant_id);


--
-- Name: courts_venue_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX courts_venue_id_idx ON public.courts USING btree (venue_id);


--
-- Name: date_price_overrides_lookup_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX date_price_overrides_lookup_idx ON public.date_price_overrides USING btree (court_id, override_date);


--
-- Name: date_price_overrides_tenant_court_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX date_price_overrides_tenant_court_date_idx ON public.date_price_overrides USING btree (tenant_id, court_id, override_date);


--
-- Name: notifications_tenant_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_tenant_id_idx ON public.notifications USING btree (tenant_id);


--
-- Name: notifications_unread_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_unread_idx ON public.notifications USING btree (user_id, is_read) WHERE (is_read = false);


--
-- Name: notifications_user_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_user_created_idx ON public.notifications USING btree (user_id, created_at DESC);


--
-- Name: one_active_manager_assignment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX one_active_manager_assignment ON public.venue_manager_assignments USING btree (venue_id, manager_user_id) WHERE (revoked_at IS NULL);


--
-- Name: one_current_subscription_per_venue; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX one_current_subscription_per_venue ON public.venue_subscriptions USING btree (venue_id) WHERE (status = ANY (ARRAY['TRIAL'::text, 'ACTIVE'::text, 'PAST_DUE'::text]));


--
-- Name: one_owner_per_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX one_owner_per_tenant ON public.tenant_memberships USING btree (tenant_id) WHERE (role = 'OWNER'::text);


--
-- Name: operating_hours_court_day_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operating_hours_court_day_idx ON public.operating_hours USING btree (court_id, day_of_week);


--
-- Name: operating_hours_tenant_court_day_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operating_hours_tenant_court_day_idx ON public.operating_hours USING btree (tenant_id, court_id, day_of_week);


--
-- Name: otp_verifications_expiry_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX otp_verifications_expiry_idx ON public.otp_verifications USING btree (expires_at);


--
-- Name: otp_verifications_phone_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX otp_verifications_phone_created_idx ON public.otp_verifications USING btree (phone, created_at DESC);


--
-- Name: payment_webhook_events_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payment_webhook_events_status_idx ON public.payment_webhook_events USING btree (processing_status, received_at);


--
-- Name: subscription_payments_provider_order_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX subscription_payments_provider_order_idx ON public.subscription_payments USING btree (payment_provider, provider_order_id) WHERE (provider_order_id IS NOT NULL);


--
-- Name: subscription_payments_provider_payment_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX subscription_payments_provider_payment_idx ON public.subscription_payments USING btree (payment_provider, provider_payment_id) WHERE (provider_payment_id IS NOT NULL);


--
-- Name: subscription_payments_subscription_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX subscription_payments_subscription_id_idx ON public.subscription_payments USING btree (subscription_id);


--
-- Name: tenant_memberships_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tenant_memberships_user_id_idx ON public.tenant_memberships USING btree (user_id);


--
-- Name: user_auth_identities_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_auth_identities_user_id_idx ON public.user_auth_identities USING btree (user_id);


--
-- Name: user_sessions_expiry_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_sessions_expiry_idx ON public.user_sessions USING btree (expires_at);


--
-- Name: user_sessions_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_sessions_user_id_idx ON public.user_sessions USING btree (user_id);


--
-- Name: users_email_unique_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_unique_idx ON public.users USING btree (lower(email)) WHERE (email IS NOT NULL);


--
-- Name: users_phone_unique_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_phone_unique_idx ON public.users USING btree (phone) WHERE (phone IS NOT NULL);


--
-- Name: venue_manager_assignments_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX venue_manager_assignments_user_idx ON public.venue_manager_assignments USING btree (manager_user_id, tenant_id) WHERE (revoked_at IS NULL);


--
-- Name: venue_manager_assignments_venue_tenant_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX venue_manager_assignments_venue_tenant_idx ON public.venue_manager_assignments USING btree (venue_id, tenant_id);


--
-- Name: venue_subscriptions_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX venue_subscriptions_status_idx ON public.venue_subscriptions USING btree (status);


--
-- Name: venue_subscriptions_venue_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX venue_subscriptions_venue_id_idx ON public.venue_subscriptions USING btree (venue_id);


--
-- Name: venues_tenant_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX venues_tenant_id_idx ON public.venues USING btree (tenant_id);


--
-- Name: weekly_price_rules_court_day_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX weekly_price_rules_court_day_idx ON public.weekly_price_rules USING btree (court_id, day_of_week);


--
-- Name: weekly_price_rules_tenant_court_day_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX weekly_price_rules_tenant_court_day_idx ON public.weekly_price_rules USING btree (tenant_id, court_id, day_of_week);


--
-- Name: operating_hours prevent_operating_hours_overlap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_operating_hours_overlap BEFORE INSERT OR UPDATE ON public.operating_hours FOR EACH ROW EXECUTE FUNCTION public.check_operating_hours_overlap();


--
-- Name: audit_logs audit_logs_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE RESTRICT;


--
-- Name: audit_logs audit_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: booking_items booking_items_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_items
    ADD CONSTRAINT booking_items_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE RESTRICT;


--
-- Name: booking_payments booking_payments_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_payments
    ADD CONSTRAINT booking_payments_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE RESTRICT;


--
-- Name: booking_refunds booking_refunds_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_refunds
    ADD CONSTRAINT booking_refunds_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.booking_payments(id) ON DELETE RESTRICT;


--
-- Name: bookings bookings_court_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_court_id_fkey FOREIGN KEY (court_id) REFERENCES public.courts(id) ON DELETE RESTRICT;


--
-- Name: bookings bookings_court_tenant_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_court_tenant_fk FOREIGN KEY (court_id, tenant_id) REFERENCES public.courts(id, tenant_id) ON DELETE RESTRICT;


--
-- Name: bookings bookings_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: bookings bookings_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: courts courts_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courts
    ADD CONSTRAINT courts_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE RESTRICT;


--
-- Name: courts courts_venue_tenant_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courts
    ADD CONSTRAINT courts_venue_tenant_fk FOREIGN KEY (venue_id, tenant_id) REFERENCES public.venues(id, tenant_id) ON DELETE RESTRICT;


--
-- Name: date_price_overrides date_price_overrides_court_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.date_price_overrides
    ADD CONSTRAINT date_price_overrides_court_id_fkey FOREIGN KEY (court_id) REFERENCES public.courts(id) ON DELETE RESTRICT;


--
-- Name: date_price_overrides date_price_overrides_court_tenant_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.date_price_overrides
    ADD CONSTRAINT date_price_overrides_court_tenant_fk FOREIGN KEY (court_id, tenant_id) REFERENCES public.courts(id, tenant_id) ON DELETE RESTRICT;


--
-- Name: notifications notifications_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE RESTRICT;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: operating_hours operating_hours_court_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operating_hours
    ADD CONSTRAINT operating_hours_court_id_fkey FOREIGN KEY (court_id) REFERENCES public.courts(id) ON DELETE RESTRICT;


--
-- Name: operating_hours operating_hours_court_tenant_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operating_hours
    ADD CONSTRAINT operating_hours_court_tenant_fk FOREIGN KEY (court_id, tenant_id) REFERENCES public.courts(id, tenant_id) ON DELETE RESTRICT;


--
-- Name: subscription_payments subscription_payments_subscription_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_payments
    ADD CONSTRAINT subscription_payments_subscription_id_fkey FOREIGN KEY (subscription_id) REFERENCES public.venue_subscriptions(id) ON DELETE RESTRICT;


--
-- Name: tenant_memberships tenant_memberships_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_memberships
    ADD CONSTRAINT tenant_memberships_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tenant_memberships tenant_memberships_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_memberships
    ADD CONSTRAINT tenant_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_auth_identities user_auth_identities_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_auth_identities
    ADD CONSTRAINT user_auth_identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: user_sessions user_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: venue_manager_assignments venue_manager_assignment_venue_tenant_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_manager_assignments
    ADD CONSTRAINT venue_manager_assignment_venue_tenant_fk FOREIGN KEY (venue_id, tenant_id) REFERENCES public.venues(id, tenant_id) ON DELETE RESTRICT;


--
-- Name: venue_manager_assignments venue_manager_assignments_assigned_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_manager_assignments
    ADD CONSTRAINT venue_manager_assignments_assigned_by_user_id_fkey FOREIGN KEY (assigned_by_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: venue_manager_assignments venue_manager_assignments_manager_user_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_manager_assignments
    ADD CONSTRAINT venue_manager_assignments_manager_user_fk FOREIGN KEY (manager_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: venue_manager_assignments venue_manager_assignments_revoked_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_manager_assignments
    ADD CONSTRAINT venue_manager_assignments_revoked_by_user_id_fkey FOREIGN KEY (revoked_by_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: venue_subscriptions venue_subscriptions_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_subscriptions
    ADD CONSTRAINT venue_subscriptions_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE RESTRICT;


--
-- Name: venues venues_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE RESTRICT;


--
-- Name: weekly_price_rules weekly_price_rules_court_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_price_rules
    ADD CONSTRAINT weekly_price_rules_court_id_fkey FOREIGN KEY (court_id) REFERENCES public.courts(id) ON DELETE RESTRICT;


--
-- Name: weekly_price_rules weekly_price_rules_court_tenant_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_price_rules
    ADD CONSTRAINT weekly_price_rules_court_tenant_fk FOREIGN KEY (court_id, tenant_id) REFERENCES public.courts(id, tenant_id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict K1Ts1xbxX2grG28377zC5AIFdD2YhqBYxFm191w8f86CPXCHkmcMmBs6d7QrPiZ

