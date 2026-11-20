USE sales_norm;
START TRANSACTION;
UPDATE customers SET customer_name = 'Дания (новое название)' WHERE customer_id = 12;
SELECT r.report_id, c.customer_name FROM reports r JOIN customers c USING (customer_id)
WHERE c.customer_id = 12 ORDER BY r.report_id;
ROLLBACK;

START TRANSACTION;
DELETE FROM report_items WHERE report_id = 1102;
DELETE FROM reports WHERE report_id = 1102;
SELECT * FROM customers WHERE customer_id = 23;
ROLLBACK;

START TRANSACTION;
INSERT INTO customers (customer_id, customer_name) VALUES (99, 'Новый покупатель');
SELECT c.customer_id, c.customer_name, r.report_id
FROM customers c LEFT JOIN reports r USING (customer_id) WHERE c.customer_id = 99;
ROLLBACK;

RENAME TABLE sales_unnormalized_2 TO sales_source_verified;
SHOW TABLES;
