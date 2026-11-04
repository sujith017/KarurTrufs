
-- Migration 003: Create tenant memberships

CREATE TABLE tenant_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    tenant_id UUID NOT NULL
        REFERENCES tenants(id) ON DELETE CASCADE,

    user_id UUID NOT NULL
        REFERENCES users(id) ON DELETE CASCADE,

    role TEXT NOT NULL
        CHECK (role IN ('OWNER', 'MANAGER')),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unique_user_per_tenant
        UNIQUE (tenant_id, user_id)
);

-- Helps find all businesses a user belongs to.
CREATE INDEX tenant_memberships_user_id_idx
ON tenant_memberships(user_id);
