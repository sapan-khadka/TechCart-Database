import json
from decimal import Decimal
from urllib.error import URLError
from urllib.request import Request, urlopen

from data_layer import get_database_products


EXTERNAL_CATEGORIES = {
    "smartphones": "Smartphones",
    "laptops": "Laptops",
}


def get_external_products():
    """Read external sample products without copying them into PostgreSQL."""
    products = []
    warnings = []

    for source_category, category_name in EXTERNAL_CATEGORIES.items():
        url = (
            "https://dummyjson.com/products/category/"
            f"{source_category}?limit=0"
        )

        try:
            request = Request(
                url,
                headers={"User-Agent": "TechCart-Prototype/1.0"}
            )

            with urlopen(request, timeout=10) as response:
                data = json.load(response, parse_float=Decimal)

            # Build this category separately before adding it.
            category_products = []

            for item in data["products"]:
                price = Decimal(str(item["price"]))
                stock = item["stock"]

                if not price.is_finite() or price < 0:
                    raise ValueError("Invalid product price")

                if type(stock) is not int or stock < 0:
                    raise ValueError("Invalid stock quantity")

                category_products.append({
                    "id": f"external:{item['id']}",
                    "source": "dummyjson",
                    "source_product_id": item["id"],
                    "name": item["title"],
                    "description": item.get("description", ""),
                    "category": category_name,
                    "price": format(price, ".2f"),
                    # Prototype convention for sample prices.
                    "currency": "USD",
                    "stock_quantity": stock,
                    "image_url": item.get("thumbnail"),
                    "purchasable": False
                })

            products.extend(category_products)

        except (
            URLError, TimeoutError, OSError,
            ValueError, KeyError, TypeError
        ) as error:
            warnings.append(
                f"External {category_name} unavailable: "
                f"{type(error).__name__}"
            )

    return products, warnings


def get_unified_products():
    """One entry point for the combined product catalog."""
    local_products = get_database_products()
    external_products, warnings = get_external_products()

    return {
        "products": local_products + external_products,
        "counts": {
            "local": len(local_products),
            "external": len(external_products),
            "total": len(local_products) + len(external_products)
        },
        "warnings": warnings
    }


if __name__ == "__main__":
    result = get_unified_products()
    print(json.dumps(result, indent=2))