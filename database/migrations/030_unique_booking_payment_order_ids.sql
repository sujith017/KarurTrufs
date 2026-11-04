CREATE UNIQUE INDEX booking_payments_provider_order_idx
ON booking_payments (payment_provider, provider_order_id)
WHERE provider_order_id IS NOT NULL;