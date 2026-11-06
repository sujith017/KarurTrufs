BEGIN;

-- Identify whether the operating period ends
-- on the following calendar day.
ALTER TABLE operating_hours
ADD COLUMN closes_next_day BOOLEAN NOT NULL DEFAULT FALSE;

-- Replace the existing time validation.
ALTER TABLE operating_hours
DROP CONSTRAINT valid_operating_time;

ALTER TABLE operating_hours
ADD CONSTRAINT valid_operating_time
CHECK (
    (
        closes_next_day = FALSE
        AND closes_at > opens_at
    )
    OR
    (
        closes_next_day = TRUE
        AND closes_at <= opens_at
    )
);

COMMIT;