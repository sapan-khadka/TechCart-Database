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
ROLLBACK;