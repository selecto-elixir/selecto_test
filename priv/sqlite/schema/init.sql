-- SQLite Schema for Pagila Database (adapted from PostgreSQL)
-- This is a simplified version suitable for testing

PRAGMA foreign_keys = ON;

-- Language table
CREATE TABLE IF NOT EXISTS language (
    language_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(20) NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Country table
CREATE TABLE IF NOT EXISTS country (
    country_id INTEGER PRIMARY KEY AUTOINCREMENT,
    country VARCHAR(50) NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- City table
CREATE TABLE IF NOT EXISTS city (
    city_id INTEGER PRIMARY KEY AUTOINCREMENT,
    city VARCHAR(50) NOT NULL,
    country_id INTEGER NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (country_id) REFERENCES country(country_id)
);

-- Address table
CREATE TABLE IF NOT EXISTS address (
    address_id INTEGER PRIMARY KEY AUTOINCREMENT,
    address VARCHAR(50) NOT NULL,
    address2 VARCHAR(50),
    district VARCHAR(20) NOT NULL,
    city_id INTEGER NOT NULL,
    postal_code VARCHAR(10),
    phone VARCHAR(20) NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (city_id) REFERENCES city(city_id)
);

-- Actor table
CREATE TABLE IF NOT EXISTS actor (
    actor_id INTEGER PRIMARY KEY AUTOINCREMENT,
    first_name VARCHAR(45) NOT NULL,
    last_name VARCHAR(45) NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Category table
CREATE TABLE IF NOT EXISTS category (
    category_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(25) NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Film table (mpaa_rating as TEXT with CHECK constraint instead of ENUM)
CREATE TABLE IF NOT EXISTS film (
    film_id INTEGER PRIMARY KEY AUTOINCREMENT,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    release_year INTEGER,
    language_id INTEGER NOT NULL,
    original_language_id INTEGER,
    rental_duration INTEGER NOT NULL DEFAULT 3,
    rental_rate DECIMAL(4,2) NOT NULL DEFAULT 4.99,
    length INTEGER,
    replacement_cost DECIMAL(5,2) NOT NULL DEFAULT 19.99,
    rating TEXT CHECK(rating IN ('G', 'PG', 'PG-13', 'R', 'NC-17')) DEFAULT 'G',
    special_features TEXT,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (language_id) REFERENCES language(language_id),
    FOREIGN KEY (original_language_id) REFERENCES language(language_id)
);

-- Film_actor junction table
CREATE TABLE IF NOT EXISTS film_actor (
    actor_id INTEGER NOT NULL,
    film_id INTEGER NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (actor_id, film_id),
    FOREIGN KEY (actor_id) REFERENCES actor(actor_id),
    FOREIGN KEY (film_id) REFERENCES film(film_id)
);

-- Film_category junction table
CREATE TABLE IF NOT EXISTS film_category (
    film_id INTEGER NOT NULL,
    category_id INTEGER NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (film_id, category_id),
    FOREIGN KEY (film_id) REFERENCES film(film_id),
    FOREIGN KEY (category_id) REFERENCES category(category_id)
);

-- Staff table
CREATE TABLE IF NOT EXISTS staff (
    staff_id INTEGER PRIMARY KEY AUTOINCREMENT,
    first_name VARCHAR(45) NOT NULL,
    last_name VARCHAR(45) NOT NULL,
    address_id INTEGER NOT NULL,
    picture BLOB,
    email VARCHAR(50),
    store_id INTEGER NOT NULL,
    active INTEGER NOT NULL DEFAULT 1,
    username VARCHAR(16) NOT NULL,
    password VARCHAR(40),
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (address_id) REFERENCES address(address_id)
);

-- Store table
CREATE TABLE IF NOT EXISTS store (
    store_id INTEGER PRIMARY KEY AUTOINCREMENT,
    manager_staff_id INTEGER NOT NULL,
    address_id INTEGER NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (manager_staff_id) REFERENCES staff(staff_id),
    FOREIGN KEY (address_id) REFERENCES address(address_id)
);

-- Customer table
CREATE TABLE IF NOT EXISTS customer (
    customer_id INTEGER PRIMARY KEY AUTOINCREMENT,
    store_id INTEGER NOT NULL,
    first_name VARCHAR(45) NOT NULL,
    last_name VARCHAR(45) NOT NULL,
    email VARCHAR(50),
    address_id INTEGER NOT NULL,
    active INTEGER NOT NULL DEFAULT 1,
    create_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (store_id) REFERENCES store(store_id),
    FOREIGN KEY (address_id) REFERENCES address(address_id)
);

-- Inventory table
CREATE TABLE IF NOT EXISTS inventory (
    inventory_id INTEGER PRIMARY KEY AUTOINCREMENT,
    film_id INTEGER NOT NULL,
    store_id INTEGER NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (film_id) REFERENCES film(film_id),
    FOREIGN KEY (store_id) REFERENCES store(store_id)
);

-- Rental table
CREATE TABLE IF NOT EXISTS rental (
    rental_id INTEGER PRIMARY KEY AUTOINCREMENT,
    rental_date TIMESTAMP NOT NULL,
    inventory_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    return_date TIMESTAMP,
    staff_id INTEGER NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (inventory_id) REFERENCES inventory(inventory_id),
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    FOREIGN KEY (staff_id) REFERENCES staff(staff_id)
);

-- Payment table
CREATE TABLE IF NOT EXISTS payment (
    payment_id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id INTEGER NOT NULL,
    staff_id INTEGER NOT NULL,
    rental_id INTEGER,
    amount DECIMAL(5,2) NOT NULL,
    payment_date TIMESTAMP NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    FOREIGN KEY (staff_id) REFERENCES staff(staff_id),
    FOREIGN KEY (rental_id) REFERENCES rental(rental_id)
);

-- Create indexes for performance
CREATE INDEX idx_film_title ON film(title);
CREATE INDEX idx_actor_last_name ON actor(last_name);
CREATE INDEX idx_customer_last_name ON customer(last_name);
CREATE INDEX idx_rental_rental_date ON rental(rental_date);
CREATE INDEX idx_payment_customer_id ON payment(customer_id);

-- Create views similar to PostgreSQL version
CREATE VIEW film_list AS
SELECT 
    f.film_id,
    f.title,
    f.description,
    c.name AS category,
    f.rental_rate,
    f.length,
    f.rating,
    GROUP_CONCAT(a.first_name || ' ' || a.last_name) AS actors
FROM film f
LEFT JOIN film_category fc ON f.film_id = fc.film_id
LEFT JOIN category c ON fc.category_id = c.category_id
LEFT JOIN film_actor fa ON f.film_id = fa.film_id
LEFT JOIN actor a ON fa.actor_id = a.actor_id
GROUP BY f.film_id, f.title, f.description, c.name, f.rental_rate, f.length, f.rating;

CREATE VIEW customer_list AS
SELECT 
    cu.customer_id,
    cu.first_name || ' ' || cu.last_name AS name,
    a.address,
    a.postal_code AS zip_code,
    a.phone,
    ci.city,
    co.country,
    CASE WHEN cu.active = 1 THEN 'active' ELSE 'inactive' END AS status,
    cu.store_id
FROM customer cu
JOIN address a ON cu.address_id = a.address_id
JOIN city ci ON a.city_id = ci.city_id
JOIN country co ON ci.country_id = co.country_id;

CREATE VIEW staff_list AS
SELECT 
    s.staff_id,
    s.first_name || ' ' || s.last_name AS name,
    a.address,
    a.postal_code AS zip_code,
    a.phone,
    ci.city,
    co.country
FROM staff s
JOIN address a ON s.address_id = a.address_id
JOIN city ci ON a.city_id = ci.city_id
JOIN country co ON ci.country_id = co.country_id;