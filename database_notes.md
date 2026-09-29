# TechCart Database Design

## Tables

### users
- user_id — primary key
- name
- email — required and unique
- password_hash — required (never store a plain password)

### categories
- category_id — primary key
- name — required and unique

### products
- product_id — primary key
- category_id — foreign key to categories
- name — required
- description
- price — zero or greater
- stock_quantity — zero or greater
- image_url

### carts
- cart_id — primary key
- user_id — foreign key to users
- status — active or checked_out

### cart_items
- cart_item_id — primary key
- cart_id — foreign key to carts
- product_id — foreign key to products
- quantity — greater than zero

### orders
- order_id — primary key
- user_id — foreign key to users
- order_date
- total_amount — zero or greater
- status

### order_items
- order_item_id — primary key
- order_id — foreign key to orders
- product_id — foreign key to products
- quantity — greater than zero
- unit_price — price when the order was placed