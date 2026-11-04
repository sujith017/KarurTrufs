BEGIN;

-- Step 1: Make the court and tenant pair
-- uniquely referenceable.

ALTER TABLE courts
ADD CONSTRAINT unique_court_tenant_pair
UNIQUE (id, tenant_id);


-- Step 2: Add tenant_id to bookings.

ALTER TABLE bookings
ADD COLUMN tenant_id UUID;


-- Step 3: Populate tenant_id from the court.

UPDATE bookings b
SET tenant_id = c.tenant_id
FROM courts c
WHERE b.court_id = c.id;


-- Step 4: Make tenant_id mandatory.

ALTER TABLE bookings
ALTER COLUMN tenant_id SET NOT NULL;


-- Step 5: Ensure booking and court
-- belong to the same tenant.

ALTER TABLE bookings
ADD CONSTRAINT bookings_court_tenant_fk
FOREIGN KEY (court_id, tenant_id)
REFERENCES courts (id, tenant_id)
ON DELETE RESTRICT;


-- Step 6: Improve tenant-scoped queries.

CREATE INDEX bookings_tenant_start_idx
ON bookings (tenant_id, start_at);

COMMIT;