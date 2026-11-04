CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    tenant_id UUID NOT NULL
        REFERENCES tenants(id) ON DELETE RESTRICT,

    user_id UUID
        REFERENCES users(id) ON DELETE RESTRICT,

    action TEXT NOT NULL,

    entity_type TEXT NOT NULL,

    entity_id UUID,

    old_values JSONB,

    new_values JSONB,

    ip_address INET,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX audit_logs_tenant_created_idx
ON audit_logs (tenant_id, created_at DESC);

CREATE INDEX audit_logs_entity_idx
ON audit_logs (entity_type, entity_id);