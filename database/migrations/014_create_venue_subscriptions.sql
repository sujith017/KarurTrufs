CREATE TABLE venue_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    venue_id UUID NOT NULL
        REFERENCES venues(id) ON DELETE RESTRICT,

    plan_name TEXT NOT NULL,

    billing_cycle TEXT NOT NULL DEFAULT 'MONTHLY'
        CHECK (
            billing_cycle IN ('MONTHLY', 'YEARLY')
        ),

    amount NUMERIC(12,2) NOT NULL
        CHECK (amount >= 0),

    status TEXT NOT NULL DEFAULT 'TRIAL'
        CHECK (
            status IN (
                'TRIAL',
                'ACTIVE',
                'PAST_DUE',
                'CANCELLED',
                'EXPIRED'
            )
        ),

    trial_starts_at TIMESTAMPTZ,
    trial_ends_at TIMESTAMPTZ,

    current_period_starts_at TIMESTAMPTZ,
    current_period_ends_at TIMESTAMPTZ,

    cancelled_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT valid_trial_period
        CHECK (
            trial_ends_at IS NULL
            OR trial_starts_at IS NULL
            OR trial_ends_at > trial_starts_at
        )
);

CREATE INDEX venue_subscriptions_venue_id_idx
ON venue_subscriptions (venue_id);

CREATE INDEX venue_subscriptions_status_idx
ON venue_subscriptions (status);