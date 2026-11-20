USE sales_norm;

SELECT 'исходная' AS scheme, COUNT(DISTINCT report_id) AS reports,
       COUNT(DISTINCT customer_id) AS customers, COUNT(DISTINCT product_id) AS products,
       COUNT(*) AS items, SUM(price * quantity) AS total
FROM sales_unnormalized_2
UNION ALL
SELECT '3НФ', COUNT(DISTINCT r.report_id), COUNT(DISTINCT r.customer_id),
       COUNT(DISTINCT p.product_id), COUNT(*), SUM(p.price * i.quantity)
FROM report_items i JOIN reports r USING (report_id) JOIN products p USING (product_id);

SELECT SUM(p.price * i.quantity) AS total_customer_12
FROM reports r JOIN report_items i USING (report_id) JOIN products p USING (product_id)
WHERE r.customer_id = 12;

SELECT r.report_id, COUNT(*) AS item_count, SUM(p.price * i.quantity) AS report_total
FROM reports r JOIN report_items i USING (report_id) JOIN products p USING (product_id)
GROUP BY r.report_id
ORDER BY r.report_id;

SELECT
    (SELECT COUNT(*) FROM sales_unnormalized_2) = (SELECT COUNT(*) FROM report_items)
    AND (SELECT COUNT(DISTINCT report_id) FROM sales_unnormalized_2) = (SELECT COUNT(*) FROM reports)
    AND (SELECT COUNT(DISTINCT customer_id) FROM sales_unnormalized_2) = (SELECT COUNT(*) FROM customers)
    AND (SELECT COUNT(DISTINCT product_id) FROM sales_unnormalized_2) = (SELECT COUNT(*) FROM products)
    AND (SELECT SUM(price * quantity) FROM sales_unnormalized_2) =
        (SELECT SUM(p.price * i.quantity) FROM report_items i JOIN products p USING (product_id))
    AND NOT EXISTS (
        SELECT 1
        FROM sales_unnormalized_2 s
        LEFT JOIN reports r ON r.report_id = s.report_id AND r.report_date = s.report_date
            AND r.customer_id = s.customer_id
        LEFT JOIN customers c ON c.customer_id = r.customer_id AND c.customer_name = s.customer_name
        LEFT JOIN report_items i ON i.report_id = r.report_id AND i.product_id = s.product_id
            AND i.quantity = s.quantity
        LEFT JOIN products p ON p.product_id = i.product_id AND p.product_name = s.product_name
            AND p.price = s.price
        WHERE c.customer_id IS NULL OR p.product_id IS NULL
    ) AS normalization_ok;
