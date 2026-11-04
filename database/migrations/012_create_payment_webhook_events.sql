CREATE TABLE payment_webhook_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    payment_provider TEXT NOT NULL DEFAULT 'RAZORPAY',

    provider_event_id TEXT NOT NULL,

    event_type TEXT NOT NULL,

    payload JSONB NOT NULL,

    processing_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (
            processing_status IN (
                'PENDING',
                'PROCESSED',
                'FAILED'
            )
        ),

    processing_error TEXT,

    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ,

    CONSTRAINT unique_provider_webhook_event
        UNIQUE (payment_provider, provider_event_id)
);

CREATE INDEX payment_webhook_events_status_idx
ON payment_webhook_events (processing_status, received_at);