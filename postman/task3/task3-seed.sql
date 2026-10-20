-- Task 3 seed data (local DB only). Safe to re-run: it removes its own rows first.
DELETE FROM customer_orders
 WHERE user_id IN ('AES45678','AES4 5679','AES45680','MULTI001','DEC00001');

INSERT INTO customer_orders (user_id, order_timestamp, order_status, order_total) VALUES
 ('AES45678',  '2021-02-12 23:02:00', 'Confirmed', 1200.00),
 ('AES4 5679', '2021-02-12 09:11:00', 'Cancelled', 2500.00),
 ('AES45680',  '2021-02-12 18:02:00', 'Confirmed', 5100.00),
 ('MULTI001',  '2021-01-05 10:00:00', 'Confirmed',  100.00),
 ('MULTI001',  '2021-01-06 11:30:00', 'Cancelled',  250.75),
 ('MULTI001',  '2021-01-07 23:59:59', 'Confirmed', 3000.00),
 ('DEC00001',  '2021-03-01 08:30:00', 'Confirmed', 1200.50);

-- AES99999 must NOT exist (used by the not-found cases)
SELECT COUNT(*) AS must_be_zero FROM customer_orders WHERE user_id = 'AES99999';
