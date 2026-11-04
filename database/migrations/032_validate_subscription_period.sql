ALTER TABLE venue_subscriptions
ADD CONSTRAINT valid_subscription_period
CHECK (
    current_period_ends_at IS NULL
    OR current_period_starts_at IS NULL
    OR current_period_ends_at > current_period_starts_at
);