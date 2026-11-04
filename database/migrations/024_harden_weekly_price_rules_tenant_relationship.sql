BEGIN;

ALTER TABLE weekly_price_rules
ADD COLUMN tenant_id UUID;

UPDATE weekly_price_rules w
SET tenant_id = c.tenant_id
FROM courts c
WHERE c.id = w.court_id;

ALTER TABLE weekly_price_rules
ALTER COLUMN tenant_id SET NOT NULL;

ALTER TABLE weekly_price_rules
ADD CONSTRAINT weekly_price_rules_court_tenant_fk
FOREIGN KEY (court_id, tenant_id)
REFERENCES courts (id, tenant_id)
ON DELETE RESTRICT;

CREATE INDEX weekly_price_rules_tenant_court_day_idx
ON weekly_price_rules (tenant_id, court_id, day_of_week);

COMMIT;