CREATE UNIQUE INDEX one_current_subscription_per_venue
ON venue_subscriptions (venue_id)
WHERE status IN ('TRIAL', 'ACTIVE', 'PAST_DUE');