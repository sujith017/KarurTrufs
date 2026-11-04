ALTER TABLE bookings
ADD CONSTRAINT valid_booking_type_status
CHECK (
    (booking_type = 'CUSTOMER'
        AND status IN (
            'HOLD',
            'CONFIRMED',
            'EXPIRED',
            'CANCELLED',
            'COMPLETED'
        )
    )
    OR
    (booking_type = 'OWNER'
        AND status IN (
            'CONFIRMED',
            'CANCELLED',
            'COMPLETED'
        )
    )
    OR
    (booking_type = 'BLOCK'
        AND status = 'BLOCKED'
    )
);