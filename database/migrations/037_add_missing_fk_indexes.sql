BEGIN;

CREATE INDEX IF NOT EXISTS notifications_tenant_id_idx
ON notifications (tenant_id);

CREATE INDEX IF NOT EXISTS venue_manager_assignments_venue_tenant_idx
ON venue_manager_assignments (venue_id, tenant_id);

COMMIT;