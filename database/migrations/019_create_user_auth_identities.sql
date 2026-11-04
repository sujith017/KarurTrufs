CREATE TABLE user_auth_identities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,

    provider TEXT NOT NULL
        CHECK (provider IN ('GOOGLE')),

    provider_user_id TEXT NOT NULL,

    provider_email TEXT,

    provider_email_verified BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unique_provider_identity
        UNIQUE (provider, provider_user_id)
);

CREATE INDEX user_auth_identities_user_id_idx
ON user_auth_identities (user_id);