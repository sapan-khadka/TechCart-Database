BEGIN;

-- Temporary test customer; this is not a login account.
INSERT INTO users (name, email, password_hash)
VALUES (
    'Cart Test User',
    'cart-test@example.com',
    'TEST_ONLY_NOT_A_VALID_PASSWORD_HASH'
)
RETURNING user_id AS test_user_id \gset

-- Create the customer's cart.
INSERT INTO carts (user_id)
VALUES (:test_user_id)
RETURNING cart_id AS test_cart_id \gset

-- Add one phone and two chargers.
INSERT INTO cart_items (cart_id, product_id, quantity)
SELECT
    :test_cart_id,
    product_id,
    CASE
        WHEN name = 'USB-C Charger' THEN 2
        ELSE 1
    END
FROM products
WHERE name IN ('TechPhone Lite', 'USB-C Charger');

-- Show the cart contents.
SELECT
    p.name,
    ci.quantity,
    p.price AS unit_price,
    ci.quantity * p.price AS subtotal
FROM cart_items ci
JOIN products p ON p.product_id = ci.product_id
WHERE ci.cart_id = :test_cart_id
ORDER BY p.name;

-- Calculate the total.
SELECT
    COALESCE(SUM(ci.quantity * p.price), 0) AS cart_total
FROM cart_items ci
JOIN products p ON p.product_id = ci.product_id
WHERE ci.cart_id = :test_cart_id;

-- Remove the temporary test customer, cart, and cart items.
-- Create an order using the cart total.
INSERT INTO orders (user_id, total_amount)
SELECT
    :test_user_id,
    SUM(ci.quantity * p.price)
FROM cart_items ci
JOIN products p ON p.product_id = ci.product_id
WHERE ci.cart_id = :test_cart_id
RETURNING order_id AS test_order_id \gset

-- Copy cart items into the order, saving current prices.
INSERT INTO order_items (
    order_id, product_id, quantity, unit_price
)
SELECT
    :test_order_id,
    ci.product_id,
    ci.quantity,
    p.price
FROM cart_items ci
JOIN products p ON p.product_id = ci.product_id
WHERE ci.cart_id = :test_cart_id;

-- Temporarily change the phone's catalog price.
UPDATE products
SET price = 329.99
WHERE name = 'TechPhone Lite';

-- Check that the order still has the original prices.
SELECT
    p.name,
    oi.quantity,
    p.price AS current_catalog_price,
    oi.unit_price AS purchase_price,
    oi.quantity * oi.unit_price AS subtotal
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
WHERE oi.order_id = :test_order_id
ORDER BY p.name;

-- Verify the saved order total matches its items.
SELECT
    o.total_amount AS saved_total,
    SUM(oi.quantity * oi.unit_price) AS calculated_total,
    o.total_amount = SUM(oi.quantity * oi.unit_price)
        AS totals_match
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_id = :test_order_id
GROUP BY o.order_id, o.total_amount;

-- Undo test records and the temporary price change.
ROLLBACK;