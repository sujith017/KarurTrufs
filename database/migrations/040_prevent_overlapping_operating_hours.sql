
BEGIN;

CREATE OR REPLACE FUNCTION check_operating_hours_overlap()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    new_start BIGINT;
    new_duration BIGINT;
    has_overlap BOOLEAN;
BEGIN
    -- Serialize schedule changes for the affected court.
    -- Lock both courts in a consistent order if court_id changes.
    IF TG_OP = 'UPDATE' AND OLD.court_id <> NEW.court_id THEN
        IF OLD.court_id::text < NEW.court_id::text THEN
            PERFORM pg_advisory_xact_lock(
                hashtextextended(OLD.court_id::text, 0)
            );
            PERFORM pg_advisory_xact_lock(
                hashtextextended(NEW.court_id::text, 0)
            );
        ELSE
            PERFORM pg_advisory_xact_lock(
                hashtextextended(NEW.court_id::text, 0)
            );
            PERFORM pg_advisory_xact_lock(
                hashtextextended(OLD.court_id::text, 0)
            );
        END IF;
    ELSE
        PERFORM pg_advisory_xact_lock(
            hashtextextended(NEW.court_id::text, 0)
        );
    END IF;

    -- Convert the new period into seconds on a weekly timeline.
    new_start :=
        NEW.day_of_week::BIGINT * 86400
        + EXTRACT(EPOCH FROM NEW.opens_at)::BIGINT;

    new_duration :=
        CASE
            WHEN NEW.closes_next_day THEN
                86400
                - EXTRACT(EPOCH FROM NEW.opens_at)::BIGINT
                + EXTRACT(EPOCH FROM NEW.closes_at)::BIGINT
            ELSE
                EXTRACT(EPOCH FROM NEW.closes_at)::BIGINT
                - EXTRACT(EPOCH FROM NEW.opens_at)::BIGINT
        END;

    -- Check existing periods, including copies shifted by
    -- one week in either direction to handle Sunday/Monday.
    SELECT EXISTS (
        SELECT 1
        FROM operating_hours oh
        CROSS JOIN generate_series(-1, 1) AS week_shift(n)
        CROSS JOIN LATERAL (
            SELECT
                oh.day_of_week::BIGINT * 86400
                + EXTRACT(EPOCH FROM oh.opens_at)::BIGINT
                    AS period_start,

                CASE
                    WHEN oh.closes_next_day THEN
                        86400
                        - EXTRACT(EPOCH FROM oh.opens_at)::BIGINT
                        + EXTRACT(EPOCH FROM oh.closes_at)::BIGINT
                    ELSE
                        EXTRACT(EPOCH FROM oh.closes_at)::BIGINT
                        - EXTRACT(EPOCH FROM oh.opens_at)::BIGINT
                END AS period_duration
        ) p
        WHERE oh.court_id = NEW.court_id
          AND oh.id IS DISTINCT FROM NEW.id
          AND new_start <
              p.period_start + (week_shift.n * 604800)
              + p.period_duration
          AND p.period_start + (week_shift.n * 604800)
              < new_start + new_duration
    )
    INTO has_overlap;

    IF has_overlap THEN
        RAISE EXCEPTION
            'Operating hours overlap with an existing period for this court.'
            USING ERRCODE = '23P01';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER prevent_operating_hours_overlap
BEFORE INSERT OR UPDATE ON operating_hours
FOR EACH ROW
EXECUTE FUNCTION check_operating_hours_overlap();

COMMIT;
