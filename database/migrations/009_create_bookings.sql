-- Required for PostgreSQL GiST equality support on UUID
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    court_id UUID NOT NULL
        REFERENCES courts(id) ON DELETE RESTRICT,

    customer_id UUID
        REFERENCES users(id) ON DELETE RESTRICT,

    created_by_user_id UUID
        REFERENCES users(id) ON DELETE RESTRICT,

    booking_type TEXT NOT NULL
        CHECK (booking_type IN ('CUSTOMER', 'OWNER', 'BLOCK')),

    status TEXT NOT NULL
        CHECK (
            status IN (
                'HOLD',
                'CONFIRMED',
                'EXPIRED',
                'CANCELLED',
                'COMPLETED',
                'BLOCKED'
            )
        ),

    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,

    slot_period TSTZRANGE GENERATED ALWAYS AS (
        tstzrange(start_at, end_at, '[)')
    ) STORED,

    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0
        CHECK (total_amount >= 0),

    currency CHAR(3) NOT NULL DEFAULT 'INR',

    hold_expires_at TIMESTAMPTZ,

    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT valid_booking_time
        CHECK (end_at > start_at),

    CONSTRAINT hold_requires_expiry
        CHECK (status <> 'HOLD' OR hold_expires_at IS NOT NULL)
);

-- Prevent overlapping active bookings on the same court
ALTER TABLE bookings
ADD CONSTRAINT no_overlapping_active_bookings
EXCLUDE USING GIST (
    court_id WITH =,
    slot_period WITH &&
)
WHERE (
    status IN ('HOLD', 'CONFIRMED', 'BLOCKED')
);

CREATE INDEX bookings_court_start_idx
ON bookings (court_id, start_at);

CREATE INDEX bookings_customer_id_idx
ON bookings (customer_id);

CREATE INDEX bookings_status_expiry_idx
ON bookings (status, hold_expires_at)
WHERE status = 'HOLD';