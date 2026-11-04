
-- Migration 005: Create courts table

CREATE TABLE courts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    venue_id UUID NOT NULL
        REFERENCES venues(id) ON DELETE RESTRICT,

    court_name TEXT NOT NULL,

    sport_name TEXT NOT NULL,

    description TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unique_court_name_per_venue
        UNIQUE (venue_id, court_name)
);

-- Find all courts belonging to a venue.
CREATE INDEX courts_venue_id_idx
ON courts(venue_id);
