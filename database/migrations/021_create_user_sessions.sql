CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,

    refresh_token_hash TEXT NOT NULL UNIQUE,

    device_info TEXT,

    ip_address INET,

    expires_at TIMESTAMPTZ NOT NULL,

    revoked_at TIMESTAMPTZ,

    last_used_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX user_sessions_user_id_idx
ON user_sessions (user_id);

CREATE INDEX user_sessions_expiry_idx
ON user_sessions (expires_at);