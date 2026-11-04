
-- Migration 001: Create users table

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    full_name TEXT NOT NULL,

    email TEXT,
    phone TEXT,

    password_hash TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT users_email_or_phone_required
        CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

-- Email must be unique, ignoring uppercase/lowercase differences.
CREATE UNIQUE INDEX users_email_unique_idx
ON users (LOWER(email))
WHERE email IS NOT NULL;

-- Phone numbers must be unique.
CREATE UNIQUE INDEX users_phone_unique_idx
ON users (phone)
WHERE phone IS NOT NULL;
