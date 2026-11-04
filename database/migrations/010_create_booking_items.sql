CREATE TABLE booking_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    booking_id UUID NOT NULL
        REFERENCES bookings(id) ON DELETE RESTRICT,

    slot_start_at TIMESTAMPTZ NOT NULL,
    slot_end_at TIMESTAMPTZ NOT NULL,

    -- Price agreed for this particular hourly slot
    slot_price NUMERIC(12,2) NOT NULL
        CHECK (slot_price >= 0),

    slot_period TSTZRANGE GENERATED ALWAYS AS (
        tstzrange(slot_start_at, slot_end_at, '[)')
    ) STORED,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT valid_booking_item_time
        CHECK (slot_end_at > slot_start_at),

    CONSTRAINT unique_booking_slot
        UNIQUE (booking_id, slot_start_at)
);

-- Prevent overlapping items within the same booking
ALTER TABLE booking_items
ADD CONSTRAINT no_overlapping_booking_items
EXCLUDE USING GIST (
    booking_id WITH =,
    slot_period WITH &&
);

CREATE INDEX booking_items_booking_id_idx
ON booking_items (booking_id);