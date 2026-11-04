BEGIN;

CREATE TABLE venue_manager_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    tenant_id UUID NOT NULL,
    venue_id UUID NOT NULL,
    manager_user_id UUID NOT NULL,

    assigned_by_user_id UUID NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    revoked_at TIMESTAMPTZ,
    revoked_by_user_id UUID
        REFERENCES users(id) ON DELETE RESTRICT,

    -- Ensure the venue belongs to the specified business
    CONSTRAINT venue_manager_assignment_venue_tenant_fk
        FOREIGN KEY (venue_id, tenant_id)
        REFERENCES venues (id, tenant_id)
        ON DELETE RESTRICT
);

-- A manager can have only one active assignment per venue
CREATE UNIQUE INDEX one_active_manager_assignment
ON venue_manager_assignments (venue_id, manager_user_id)
WHERE revoked_at IS NULL;

-- Find all venues assigned to a manager
CREATE INDEX venue_manager_assignments_user_idx
ON venue_manager_assignments (manager_user_id, tenant_id)
WHERE revoked_at IS NULL;

COMMIT;