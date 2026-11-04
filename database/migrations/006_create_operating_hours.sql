CREATE TABLE operating_hours (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    court_id UUID NOT NULL
        REFERENCES courts(id) ON DELETE RESTRICT,

    day_of_week SMALLINT NOT NULL
        CHECK (day_of_week BETWEEN 0 AND 6),

    opens_at TIME NOT NULL,
    closes_at TIME NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT valid_operating_time
        CHECK (closes_at > opens_at),

    CONSTRAINT unique_court_day_opening
        UNIQUE (court_id, day_of_week, opens_at)
);

CREATE INDEX operating_hours_court_day_idx
ON operating_hours (court_id, day_of_week);