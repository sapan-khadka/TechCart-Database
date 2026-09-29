INSERT INTO categories (name)
VALUES
    ('Smartphones'),
    ('Laptops'),
    ('Headphones'),
    ('Accessories')
ON CONFLICT (name) DO NOTHING;

INSERT INTO products (
    category_id, name, description, price, stock_quantity
)
SELECT c.category_id, v.name, v.description, v.price, v.stock
FROM (
    VALUES
    ('Smartphones', 'TechPhone Lite',
     '128 GB storage and a 6.1-inch display.', 299.99, 25),

    ('Smartphones', 'TechPhone Pro',
     '256 GB storage and a 6.7-inch display.', 599.99, 15),

    ('Laptops', 'StudyBook 14',
     '14-inch laptop with 8 GB RAM and 256 GB SSD.',
     549.99, 12),

    ('Laptops', 'WorkBook Pro',
     '15-inch laptop with 16 GB RAM and 512 GB SSD.',
     899.99, 8),

    ('Headphones', 'SoundWave Wireless',
     'Wireless over-ear headphones.', 79.99, 30),

    ('Headphones', 'PocketBuds',
     'Wireless earbuds with a charging case.', 49.99, 40),

    ('Accessories', 'USB-C Charger',
     '30-watt USB-C wall charger.', 24.99, 50),

    ('Accessories', 'Wireless Mouse',
     'Compact wireless mouse.', 19.99, 35)
) AS v(category, name, description, price, stock)
JOIN categories c ON c.name = v.category
WHERE NOT EXISTS (
    SELECT 1
    FROM products p
    WHERE p.category_id = c.category_id
      AND p.name = v.name
);