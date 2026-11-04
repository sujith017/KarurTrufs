BEGIN;

-- Step 1: Ensure venue ID and tenant ID form
-- a valid unique reference pair.

ALTER TABLE venues
ADD CONSTRAINT unique_venue_tenant_pair
UNIQUE (id, tenant_id);


-- Step 2: Add tenant_id to courts.

ALTER TABLE courts
ADD COLUMN tenant_id UUID;


-- Step 3: Populate tenant_id using the
-- court's existing venue relationship.

UPDATE courts c
SET tenant_id = v.tenant_id
FROM venues v
WHERE c.venue_id = v.id;


-- Step 4: Make tenant_id mandatory.

ALTER TABLE courts
ALTER COLUMN tenant_id SET NOT NULL;


-- Step 5: Enforce that the court's tenant
-- matches the tenant that owns its venue.

ALTER TABLE courts
ADD CONSTRAINT courts_venue_tenant_fk
FOREIGN KEY (venue_id, tenant_id)
REFERENCES venues (id, tenant_id)
ON DELETE RESTRICT;


-- Step 6: Improve tenant-scoped queries.

CREATE INDEX courts_tenant_id_idx
ON courts (tenant_id);

COMMIT;