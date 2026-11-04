CREATE TABLE date_price_overrides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    court_id UUID NOT NULL
        REFERENCES courts(id) ON DELETE RESTRICT,

    override_date DATE NOT NULL,

    start_time TIME NOT NULL,
    end_time TIME NOT NULL,

    price NUMERIC(12,2) NOT NULL
        CHECK (price >= 0),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT valid_override_slot
        CHECK (end_time > start_time),

    CONSTRAINT unique_court_date_slot
        UNIQUE (court_id, override_date, start_time)
);

CREATE INDEX date_price_overrides_lookup_idx
ON date_price_overrides (court_id, override_date);