# TechCart Database and Data Virtualization

Developer: Sapan Khadka

## Requirements

- PostgreSQL
- Python (tested with Python 3.14)
- Dependencies listed in requirements.txt

## First-time setup

Run these commands from the project folder.
Use a new, empty database for schema installation.

```bash
createdb techcart
psql -d techcart -v ON_ERROR_STOP=1 -1 -f schema.sql
psql -d techcart -v ON_ERROR_STOP=1 -1 -f sample_data.sql
psql -d techcart -v ON_ERROR_STOP=1 -f checkout.sql

python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

The default connection is dbname=techcart using the
current operating-system user's PostgreSQL role.
Set DATABASE_URL for a different database connection.

## Run the combined product catalog

```bash
python virtualization.py
```

The catalog combines PostgreSQL products and DummyJSON
smartphones and laptops without storing external products
in PostgreSQL.

## Backend integration

A Python backend can import:

```python
from virtualization import get_unified_products

result = get_unified_products()
```

The result contains products, counts, and warnings.

Product IDs:
- local:<id> identifies a PostgreSQL product.
- external:<id> identifies a DummyJSON product.

Prices are decimal strings. USD is the prototype currency
convention. Local image URLs are currently empty.

External products are browse-only. The backend must reject
external IDs for cart and checkout operations.

## Checkout

The database function checkout_cart(user_id) creates an
order, saves purchase prices, reduces stock, and empties
the cart. It returns the new order ID.

The backend must supply the authenticated user's ID and
enforce ownership checks for carts and orders.

## Tests

```bash
psql -d techcart -v ON_ERROR_STOP=1 -P pager=off -f test_cart.sql
psql -d techcart -v ON_ERROR_STOP=1 -P pager=off -f test_order.sql
psql -d techcart -v ON_ERROR_STOP=1 -P pager=off -f test_checkout.sql
```

Tests roll back their temporary data changes.

## Current limitations

- No HTTP API endpoints are included.
- Android integration is still pending.
- External requests are made on each catalog call.
- External failures return warnings alongside local products.
- A PostgreSQL connection failure stops catalog retrieval.