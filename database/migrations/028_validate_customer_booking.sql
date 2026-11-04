ALTER TABLE bookings
ADD CONSTRAINT customer_booking_requires_customer
CHECK (
    booking_type <> 'CUSTOMER'
    OR customer_id IS NOT NULL
);