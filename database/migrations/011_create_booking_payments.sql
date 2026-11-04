CREATE TABLE booking_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    booking_id UUID NOT NULL
        REFERENCES bookings(id) ON DELETE RESTRICT,

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
                'REFUNDED',
                'PARTIALLY_REFUNDED'
            )
        ),

    failure_reason TEXT,

    paid_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX booking_payments_provider_payment_idx
ON booking_payments (payment_provider, provider_payment_id)
WHERE provider_payment_id IS NOT NULL;

CREATE INDEX booking_payments_booking_id_idx
ON booking_payments (booking_id);