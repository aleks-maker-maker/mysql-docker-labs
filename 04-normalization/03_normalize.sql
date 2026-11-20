USE sales_norm;

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL
);

CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL
);

CREATE TABLE reports (
    report_id INT PRIMARY KEY,
    report_date DATE NOT NULL,
    customer_id INT NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE report_items (
    report_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    PRIMARY KEY (report_id, product_id),
    FOREIGN KEY (report_id) REFERENCES reports(report_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

START TRANSACTION;
INSERT INTO customers SELECT DISTINCT customer_id, customer_name FROM sales_unnormalized_2;
INSERT INTO products SELECT DISTINCT product_id, product_name, price FROM sales_unnormalized_2;
INSERT INTO reports SELECT DISTINCT report_id, report_date, customer_id FROM sales_unnormalized_2;
INSERT INTO report_items SELECT report_id, product_id, quantity FROM sales_unnormalized_2;
COMMIT;

SHOW TABLES;
SHOW CREATE TABLE report_items\G
