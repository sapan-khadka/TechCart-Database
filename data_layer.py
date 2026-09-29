import json
import os

import psycopg
from psycopg.rows import dict_row


def get_database_products():
    """Read TechCart products and return a consistent format."""
    connection_string = os.getenv(
        "DATABASE_URL",
        "dbname=techcart"
    )

    with psycopg.connect(
        connection_string,
        row_factory=dict_row
    ) as connection:
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT
                    p.product_id,
                    p.name,
                    p.description,
                    p.price,
                    p.stock_quantity,
                    p.image_url,
                    c.name AS category
                FROM products p
                JOIN categories c
                    ON c.category_id = p.category_id
                ORDER BY p.product_id;
            """)

            rows = cursor.fetchall()

    products = []

    for row in rows:
        products.append({
            "id": f"local:{row['product_id']}",
            "source": "techcart",
            "source_product_id": row["product_id"],
            "name": row["name"],
            "description": row["description"],
            "category": row["category"],
            "price": format(row["price"], ".2f"),
            "currency": "USD",
            "stock_quantity": row["stock_quantity"],
            "image_url": row["image_url"],
            "purchasable": row["stock_quantity"] > 0
        })

    return products


if __name__ == "__main__":
    products = get_database_products()
    print(json.dumps(products, indent=2))
    print(f"\nLoaded {len(products)} local products.")