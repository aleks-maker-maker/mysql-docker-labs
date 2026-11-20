USE sales_norm;
START TRANSACTION;

-- Обновление одной позиции оставляет другое имя того же покупателя.
UPDATE sales_unnormalized_2 SET customer_name = 'Дания (новое название)'
WHERE report_id = 1101 AND product_id = 101;
SELECT DISTINCT customer_id, customer_name FROM sales_unnormalized_2 WHERE customer_id = 12;
ROLLBACK;

START TRANSACTION;
-- У покупателя 23 один отчёт. После его удаления покупатель исчезает из исходной таблицы.
DELETE FROM sales_unnormalized_2 WHERE report_id = 1102;
SELECT COUNT(*) AS rows_for_customer_23 FROM sales_unnormalized_2 WHERE customer_id = 23;
ROLLBACK;

START TRANSACTION;
-- В исходной схеме покупатель без отчёта представим только неполной строкой продажи.
INSERT INTO sales_unnormalized_2 (customer_id, customer_name) VALUES (99, 'Новый покупатель');
SELECT * FROM sales_unnormalized_2 WHERE customer_id = 99;
ROLLBACK;
