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
-- Run the actual checkout function.
SELECT checkout_cart(:test_user_id::BIGINT)
    AS test_order_id \gset

-- Check the created order.
SELECT order_id, total_amount, status
FROM orders
WHERE order_id = :test_order_id;

-- Check the saved order items.
SELECT
    p.name,
    oi.quantity,
    oi.unit_price,
    oi.quantity * oi.unit_price AS subtotal
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
WHERE oi.order_id = :test_order_id
ORDER BY p.name;

-- Check remaining stock.
SELECT name, stock_quantity
FROM products
WHERE name IN ('TechPhone Lite', 'USB-C Charger')
ORDER BY name;

-- Check that the cart is empty.
SELECT COUNT(*) AS remaining_cart_items
FROM cart_items
WHERE cart_id = :test_cart_id;

-- Undo the test order and restore stock.
DO $$
DECLARE
    v_user_id BIGINT;
    v_cart_id BIGINT;
BEGIN
    SELECT u.user_id, c.cart_id
    INTO v_user_id, v_cart_id
    FROM users u
    JOIN carts c ON c.user_id = u.user_id
    WHERE u.email = 'cart-test@example.com';

    -- Checkout already emptied this cart.
    BEGIN
        PERFORM checkout_cart(v_user_id);
        RAISE EXCEPTION 'FAIL: Empty cart was accepted';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM = 'Cannot check out an empty cart' THEN
            RAISE NOTICE 'PASS: Empty cart rejected';
        ELSE
            RAISE;
        END IF;
    END;

    -- Request one more phone than is available.
    INSERT INTO cart_items (cart_id, product_id, quantity)
    SELECT v_cart_id, product_id, stock_quantity + 1
    FROM products
    WHERE name = 'TechPhone Lite';

    BEGIN
        PERFORM checkout_cart(v_user_id);
        RAISE EXCEPTION 'FAIL: Insufficient stock was accepted';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM = 'Insufficient stock for a cart item' THEN
            RAISE NOTICE 'PASS: Insufficient stock rejected';
        ELSE
            RAISE;
        END IF;
    END;
END;
$$;
ROLLBACK;