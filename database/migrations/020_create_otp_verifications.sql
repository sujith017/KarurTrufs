CREATE TABLE otp_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    phone TEXT NOT NULL,

    otp_hash TEXT NOT NULL,

    purpose TEXT NOT NULL
        CHECK (
            purpose IN (
                'LOGIN',
                'PHONE_VERIFICATION'
            )
        ),

    expires_at TIMESTAMPTZ NOT NULL,

    verified_at TIMESTAMPTZ,

    attempts INTEGER NOT NULL DEFAULT 0
        CHECK (attempts >= 0),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX otp_verifications_phone_created_idx
ON otp_verifications (phone, created_at DESC);

CREATE INDEX otp_verifications_expiry_idx
ON otp_verifications (expires_at);