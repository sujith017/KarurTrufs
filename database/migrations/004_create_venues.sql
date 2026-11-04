
-- Migration 004: Create venues table

CREATE TABLE venues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    tenant_id UUID NOT NULL
        REFERENCES tenants(id) ON DELETE RESTRICT,

    venue_name TEXT NOT NULL,

    description TEXT,

    address TEXT NOT NULL,

    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7),

    google_maps_url TEXT,

    timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT valid_latitude
        CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),

    CONSTRAINT valid_longitude
        CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),

    CONSTRAINT latitude_longitude_together
        CHECK (
            (latitude IS NULL AND longitude IS NULL)
            OR
            (latitude IS NOT NULL AND longitude IS NOT NULL)
        )
);

-- Find all venues belonging to a business.
CREATE INDEX venues_tenant_id_idx
ON venues(tenant_id);
