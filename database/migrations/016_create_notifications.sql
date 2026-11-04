CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,

    tenant_id UUID
        REFERENCES tenants(id) ON DELETE RESTRICT,

    title TEXT NOT NULL,
    message TEXT NOT NULL,

    notification_type TEXT NOT NULL,

    channel TEXT NOT NULL DEFAULT 'IN_APP'
        CHECK (
            channel IN (
                'IN_APP',
                'EMAIL',
                'SMS',
                'WHATSAPP'
            )
        ),

    is_read BOOLEAN NOT NULL DEFAULT FALSE,

    sent_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX notifications_user_created_idx
ON notifications (user_id, created_at DESC);

CREATE INDEX notifications_unread_idx
ON notifications (user_id, is_read)
WHERE is_read = FALSE;