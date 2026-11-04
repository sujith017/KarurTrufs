CREATE TABLE booking_refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    payment_id UUID NOT NULL
        REFERENCES booking_payments(id) ON DELETE RESTRICT,

    provider_refund_id TEXT,

    amount NUMERIC(12,2) NOT NULL
        CHECK (amount > 0),

    currency CHAR(3) NOT NULL DEFAULT 'INR',

    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (
            status IN (
                'PENDING',
                'PROCESSED',
                'FAILED'
            )
        ),

    reason TEXT,

    processed_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX booking_refunds_provider_id_idx
ON booking_refunds (provider_refund_id)
WHERE provider_refund_id IS NOT NULL;

CREATE INDEX booking_refunds_payment_id_idx
ON booking_refunds (payment_id);