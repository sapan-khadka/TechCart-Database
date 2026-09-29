CREATE OR REPLACE FUNCTION checkout_cart(p_user_id BIGINT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_cart_id BIGINT;
    v_order_id BIGINT;
    v_total NUMERIC(12, 2);
BEGIN
    -- Find and lock this user's cart during checkout.
    SELECT cart_id INTO v_cart_id
    FROM carts
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No cart found for this user';
    END IF;

    -- Lock the cart's existing items.
    PERFORM cart_item_id
    FROM cart_items
    WHERE cart_id = v_cart_id
    FOR UPDATE;

    IF NOT EXISTS (
        SELECT 1 FROM cart_items WHERE cart_id = v_cart_id
    ) THEN
        RAISE EXCEPTION 'Cannot check out an empty cart';
    END IF;

    -- Lock products in a consistent order.
    PERFORM p.product_id
    FROM products p
    JOIN cart_items ci ON ci.product_id = p.product_id
    WHERE ci.cart_id = v_cart_id
    ORDER BY p.product_id
    FOR UPDATE OF p;

    -- Reject the order if any product lacks enough stock.
    IF EXISTS (
        SELECT 1
        FROM cart_items ci
        JOIN products p ON p.product_id = ci.product_id
        WHERE ci.cart_id = v_cart_id
          AND ci.quantity > p.stock_quantity
    ) THEN
        RAISE EXCEPTION 'Insufficient stock for a cart item';
    END IF;

    -- Calculate the total using database prices.
    SELECT SUM(ci.quantity * p.price) INTO v_total
    FROM cart_items ci
    JOIN products p ON p.product_id = ci.product_id
    WHERE ci.cart_id = v_cart_id;

    INSERT INTO orders (user_id, total_amount)
    VALUES (p_user_id, v_total)
    RETURNING order_id INTO v_order_id;

    -- Save the quantities and purchase prices.
    INSERT INTO order_items (
        order_id, product_id, quantity, unit_price
    )
    SELECT v_order_id, ci.product_id, ci.quantity, p.price
    FROM cart_items ci
    JOIN products p ON p.product_id = ci.product_id
    WHERE ci.cart_id = v_cart_id;

    -- Reduce stock.
    UPDATE products p
    SET stock_quantity = p.stock_quantity - ci.quantity
    FROM cart_items ci
    WHERE ci.product_id = p.product_id
      AND ci.cart_id = v_cart_id;

    -- Empty the cart after creating the order.
    DELETE FROM cart_items WHERE cart_id = v_cart_id;

    RETURN v_order_id;
END;
$$;