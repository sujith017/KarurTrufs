CREATE TABLE subscription_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    subscription_id UUID NOT NULL
        REFERENCES venue_subscriptions(id) ON DELETE RESTRICT,

    payment_provider TEXT NOT NULL DEFAULT 'RAZORPAY',

    provider_order_id TEXT,
    provider_payment_id TEXT,

    amount NUMERIC(12,2) NOT NULL
        CHECK (amount > 0),

    currency CHAR(3) NOT NULL DEFAULT 'INR',

    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (
            status IN (
                'PENDING',
                'SUCCESS',
                'FAILED',
                'REFUNDED'
            )
        ),

    paid_at TIMESTAMPTZ,

    failure_reason TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX subscription_payments_provider_payment_idx
ON subscription_payments (payment_provider, provider_payment_id)
WHERE provider_payment_id IS NOT NULL;

CREATE INDEX subscription_payments_subscription_id_idx
ON subscription_payments (subscription_id);