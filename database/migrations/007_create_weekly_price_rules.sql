CREATE TABLE weekly_price_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    court_id UUID NOT NULL
        REFERENCES courts(id) ON DELETE RESTRICT,

    day_of_week SMALLINT NOT NULL
        CHECK (day_of_week BETWEEN 0 AND 6),

    start_time TIME NOT NULL,
    end_time TIME NOT NULL,

    price NUMERIC(12,2) NOT NULL
        CHECK (price >= 0),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT valid_price_slot
        CHECK (end_time > start_time),

    CONSTRAINT unique_court_weekly_slot
        UNIQUE (court_id, day_of_week, start_time)
);

CREATE INDEX weekly_price_rules_court_day_idx
ON weekly_price_rules (court_id, day_of_week);