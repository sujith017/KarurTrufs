BEGIN;

ALTER TABLE date_price_overrides
ADD COLUMN tenant_id UUID;

UPDATE date_price_overrides d
SET tenant_id = c.tenant_id
FROM courts c
WHERE c.id = d.court_id;

ALTER TABLE date_price_overrides
ALTER COLUMN tenant_id SET NOT NULL;

ALTER TABLE date_price_overrides
ADD CONSTRAINT date_price_overrides_court_tenant_fk
FOREIGN KEY (court_id, tenant_id)
REFERENCES courts (id, tenant_id)
ON DELETE RESTRICT;

CREATE INDEX date_price_overrides_tenant_court_date_idx
ON date_price_overrides (tenant_id, court_id, override_date);

COMMIT;