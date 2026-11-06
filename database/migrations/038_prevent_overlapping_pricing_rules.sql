BEGIN;

-- Prevent overlapping weekly pricing rules
-- for the same court and weekday.
ALTER TABLE weekly_price_rules
ADD CONSTRAINT no_overlapping_weekly_price_rules
EXCLUDE USING gist (
    court_id WITH =,
    day_of_week WITH =,
    (
        int4range(
            EXTRACT(EPOCH FROM start_time)::integer,
            EXTRACT(EPOCH FROM end_time)::integer,
            '[)'
        )
    ) WITH &&
);

-- Prevent overlapping date-specific price overrides
-- for the same court and date.
ALTER TABLE date_price_overrides
ADD CONSTRAINT no_overlapping_date_price_overrides
EXCLUDE USING gist (
    court_id WITH =,
    override_date WITH =,
    (
        int4range(
            EXTRACT(EPOCH FROM start_time)::integer,
            EXTRACT(EPOCH FROM end_time)::integer,
            '[)'
        )
    ) WITH &&
);

COMMIT;