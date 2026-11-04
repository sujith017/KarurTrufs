ALTER TABLE bookings
ADD CONSTRAINT hold_expiry_only_for_hold
CHECK (
    status = 'HOLD'
    OR hold_expires_at IS NULL
);