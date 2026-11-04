BEGIN;

ALTER TABLE operating_hours
ADD COLUMN tenant_id UUID;

UPDATE operating_hours o
SET tenant_id = c.tenant_id
FROM courts c
WHERE c.id = o.court_id;

ALTER TABLE operating_hours
ALTER COLUMN tenant_id SET NOT NULL;

ALTER TABLE operating_hours
ADD CONSTRAINT operating_hours_court_tenant_fk
FOREIGN KEY (court_id, tenant_id)
REFERENCES courts (id, tenant_id)
ON DELETE RESTRICT;

CREATE INDEX operating_hours_tenant_court_day_idx
ON operating_hours (tenant_id, court_id, day_of_week);

COMMIT;