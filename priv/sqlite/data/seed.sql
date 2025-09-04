-- Sample seed data for SQLite Pagila database

-- Insert languages
INSERT INTO language (name) VALUES ('English');
INSERT INTO language (name) VALUES ('Italian');
INSERT INTO language (name) VALUES ('Japanese');
INSERT INTO language (name) VALUES ('Mandarin');
INSERT INTO language (name) VALUES ('French');
INSERT INTO language (name) VALUES ('German');

-- Insert countries
INSERT INTO country (country) VALUES ('Afghanistan');
INSERT INTO country (country) VALUES ('Algeria');
INSERT INTO country (country) VALUES ('American Samoa');
INSERT INTO country (country) VALUES ('Angola');
INSERT INTO country (country) VALUES ('Argentina');
INSERT INTO country (country) VALUES ('Australia');
INSERT INTO country (country) VALUES ('Austria');
INSERT INTO country (country) VALUES ('Brazil');
INSERT INTO country (country) VALUES ('Canada');
INSERT INTO country (country) VALUES ('China');
INSERT INTO country (country) VALUES ('France');
INSERT INTO country (country) VALUES ('Germany');
INSERT INTO country (country) VALUES ('India');
INSERT INTO country (country) VALUES ('Italy');
INSERT INTO country (country) VALUES ('Japan');
INSERT INTO country (country) VALUES ('Mexico');
INSERT INTO country (country) VALUES ('United Kingdom');
INSERT INTO country (country) VALUES ('United States');

-- Insert cities
INSERT INTO city (city, country_id) VALUES ('Kabul', 1);
INSERT INTO city (city, country_id) VALUES ('Batna', 2);
INSERT INTO city (city, country_id) VALUES ('Tafuna', 3);
INSERT INTO city (city, country_id) VALUES ('Benguela', 4);
INSERT INTO city (city, country_id) VALUES ('Cordoba', 5);
INSERT INTO city (city, country_id) VALUES ('Sydney', 6);
INSERT INTO city (city, country_id) VALUES ('Vienna', 7);
INSERT INTO city (city, country_id) VALUES ('São Paulo', 8);
INSERT INTO city (city, country_id) VALUES ('Toronto', 9);
INSERT INTO city (city, country_id) VALUES ('Beijing', 10);
INSERT INTO city (city, country_id) VALUES ('Paris', 11);
INSERT INTO city (city, country_id) VALUES ('Berlin', 12);
INSERT INTO city (city, country_id) VALUES ('Mumbai', 13);
INSERT INTO city (city, country_id) VALUES ('Rome', 14);
INSERT INTO city (city, country_id) VALUES ('Tokyo', 15);
INSERT INTO city (city, country_id) VALUES ('Mexico City', 16);
INSERT INTO city (city, country_id) VALUES ('London', 17);
INSERT INTO city (city, country_id) VALUES ('New York', 18);
INSERT INTO city (city, country_id) VALUES ('Los Angeles', 18);
INSERT INTO city (city, country_id) VALUES ('Chicago', 18);

-- Insert addresses
INSERT INTO address (address, district, city_id, postal_code, phone) 
VALUES ('47 MySakila Drive', 'Alberta', 9, '10001', '555-0100');
INSERT INTO address (address, district, city_id, postal_code, phone) 
VALUES ('28 MySQL Boulevard', 'QLD', 6, '2000', '555-0101');
INSERT INTO address (address, district, city_id, postal_code, phone) 
VALUES ('23 Workhaven Lane', 'Alberta', 9, '10002', '555-0102');
INSERT INTO address (address, district, city_id, postal_code, phone) 
VALUES ('1411 Lillydale Drive', 'QLD', 6, '2001', '555-0103');
INSERT INTO address (address, district, city_id, postal_code, phone) 
VALUES ('692 Joliet Street', 'Attika', 11, '75001', '555-0104');

-- Insert categories
INSERT INTO category (name) VALUES ('Action');
INSERT INTO category (name) VALUES ('Animation');
INSERT INTO category (name) VALUES ('Children');
INSERT INTO category (name) VALUES ('Classics');
INSERT INTO category (name) VALUES ('Comedy');
INSERT INTO category (name) VALUES ('Documentary');
INSERT INTO category (name) VALUES ('Drama');
INSERT INTO category (name) VALUES ('Family');
INSERT INTO category (name) VALUES ('Foreign');
INSERT INTO category (name) VALUES ('Games');
INSERT INTO category (name) VALUES ('Horror');
INSERT INTO category (name) VALUES ('Music');
INSERT INTO category (name) VALUES ('New');
INSERT INTO category (name) VALUES ('Sci-Fi');
INSERT INTO category (name) VALUES ('Sports');
INSERT INTO category (name) VALUES ('Travel');

-- Insert actors
INSERT INTO actor (first_name, last_name) VALUES ('PENELOPE', 'GUINESS');
INSERT INTO actor (first_name, last_name) VALUES ('NICK', 'WAHLBERG');
INSERT INTO actor (first_name, last_name) VALUES ('ED', 'CHASE');
INSERT INTO actor (first_name, last_name) VALUES ('JENNIFER', 'DAVIS');
INSERT INTO actor (first_name, last_name) VALUES ('JOHNNY', 'LOLLOBRIGIDA');
INSERT INTO actor (first_name, last_name) VALUES ('BETTE', 'NICHOLSON');
INSERT INTO actor (first_name, last_name) VALUES ('GRACE', 'MOSTEL');
INSERT INTO actor (first_name, last_name) VALUES ('MATTHEW', 'JOHANSSON');
INSERT INTO actor (first_name, last_name) VALUES ('JOE', 'SWANK');
INSERT INTO actor (first_name, last_name) VALUES ('CHRISTIAN', 'GABLE');
INSERT INTO actor (first_name, last_name) VALUES ('ZERO', 'CAGE');
INSERT INTO actor (first_name, last_name) VALUES ('KARL', 'BERRY');
INSERT INTO actor (first_name, last_name) VALUES ('UMA', 'WOOD');
INSERT INTO actor (first_name, last_name) VALUES ('VIVIEN', 'BERGEN');
INSERT INTO actor (first_name, last_name) VALUES ('CUBA', 'OLIVIER');
INSERT INTO actor (first_name, last_name) VALUES ('FRED', 'COSTNER');
INSERT INTO actor (first_name, last_name) VALUES ('HELEN', 'VOIGHT');
INSERT INTO actor (first_name, last_name) VALUES ('DAN', 'TORN');
INSERT INTO actor (first_name, last_name) VALUES ('BOB', 'FAWCETT');
INSERT INTO actor (first_name, last_name) VALUES ('LUCILLE', 'TRACY');

-- Insert films
INSERT INTO film (title, description, release_year, language_id, rental_duration, rental_rate, length, replacement_cost, rating) 
VALUES ('ACADEMY DINOSAUR', 'A Epic Drama of a Feminist And a Mad Scientist who must Battle a Teacher in The Canadian Rockies', 2006, 1, 6, 0.99, 86, 20.99, 'PG');

INSERT INTO film (title, description, release_year, language_id, rental_duration, rental_rate, length, replacement_cost, rating) 
VALUES ('ACE GOLDFINGER', 'A Astounding Epistle of a Database Administrator And a Explorer who must Find a Car in Ancient China', 2006, 1, 3, 4.99, 48, 12.99, 'G');

INSERT INTO film (title, description, release_year, language_id, rental_duration, rental_rate, length, replacement_cost, rating) 
VALUES ('ADAPTATION HOLES', 'A Astounding Reflection of a Lumberjack And a Car who must Sink a Lumberjack in A Baloon Factory', 2006, 1, 7, 2.99, 50, 18.99, 'NC-17');

INSERT INTO film (title, description, release_year, language_id, rental_duration, rental_rate, length, replacement_cost, rating) 
VALUES ('AFFAIR PREJUDICE', 'A Fanciful Documentary of a Frisbee And a Lumberjack who must Chase a Monkey in A Shark Tank', 2006, 1, 5, 2.99, 117, 26.99, 'G');

INSERT INTO film (title, description, release_year, language_id, rental_duration, rental_rate, length, replacement_cost, rating) 
VALUES ('AFRICAN EGG', 'A Fast-Paced Documentary of a Pastry Chef And a Dentist who must Pursue a Forensic Psychologist in The Gulf of Mexico', 2006, 1, 6, 2.99, 130, 22.99, 'G');

INSERT INTO film (title, description, release_year, language_id, rental_duration, rental_rate, length, replacement_cost, rating) 
VALUES ('AGENT TRUMAN', 'A Intrepid Panorama of a Robot And a Boy who must Escape a Sumo Wrestler in Ancient China', 2006, 1, 3, 2.99, 169, 17.99, 'PG');

INSERT INTO film (title, description, release_year, language_id, rental_duration, rental_rate, length, replacement_cost, rating) 
VALUES ('AIRPLANE SIERRA', 'A Touching Saga of a Hunter And a Butler who must Discover a Butler in A Jet Boat', 2006, 1, 6, 4.99, 62, 28.99, 'PG-13');

INSERT INTO film (title, description, release_year, language_id, rental_duration, rental_rate, length, replacement_cost, rating) 
VALUES ('AIRPORT POLLOCK', 'A Epic Tale of a Moose And a Girl who must Confront a Monkey in Ancient India', 2006, 1, 6, 4.99, 54, 15.99, 'R');

INSERT INTO film (title, description, release_year, language_id, rental_duration, rental_rate, length, replacement_cost, rating) 
VALUES ('ALABAMA DEVIL', 'A Thoughtful Panorama of a Database Administrator And a Mad Scientist who must Outgun a Mad Scientist in A Jet Boat', 2006, 1, 3, 2.99, 114, 21.99, 'PG-13');

INSERT INTO film (title, description, release_year, language_id, rental_duration, rental_rate, length, replacement_cost, rating) 
VALUES ('ALADDIN CALENDAR', 'A Action-Packed Tale of a Man And a Lumberjack who must Reach a Feminist in Ancient China', 2006, 1, 6, 4.99, 63, 24.99, 'NC-17');

-- Insert film_actor relationships
INSERT INTO film_actor (actor_id, film_id) VALUES (1, 1);
INSERT INTO film_actor (actor_id, film_id) VALUES (1, 2);
INSERT INTO film_actor (actor_id, film_id) VALUES (2, 1);
INSERT INTO film_actor (actor_id, film_id) VALUES (2, 3);
INSERT INTO film_actor (actor_id, film_id) VALUES (3, 2);
INSERT INTO film_actor (actor_id, film_id) VALUES (3, 4);
INSERT INTO film_actor (actor_id, film_id) VALUES (4, 3);
INSERT INTO film_actor (actor_id, film_id) VALUES (4, 5);
INSERT INTO film_actor (actor_id, film_id) VALUES (5, 4);
INSERT INTO film_actor (actor_id, film_id) VALUES (5, 6);

-- Insert film_category relationships
INSERT INTO film_category (film_id, category_id) VALUES (1, 1);
INSERT INTO film_category (film_id, category_id) VALUES (1, 7);
INSERT INTO film_category (film_id, category_id) VALUES (2, 1);
INSERT INTO film_category (film_id, category_id) VALUES (3, 11);
INSERT INTO film_category (film_id, category_id) VALUES (4, 5);
INSERT INTO film_category (film_id, category_id) VALUES (5, 6);
INSERT INTO film_category (film_id, category_id) VALUES (6, 1);
INSERT INTO film_category (film_id, category_id) VALUES (7, 14);
INSERT INTO film_category (film_id, category_id) VALUES (8, 7);
INSERT INTO film_category (film_id, category_id) VALUES (9, 7);
INSERT INTO film_category (film_id, category_id) VALUES (10, 1);

-- Insert staff
INSERT INTO staff (first_name, last_name, address_id, email, store_id, active, username, password) 
VALUES ('Mike', 'Hillyer', 1, 'Mike.Hillyer@sakilastaff.com', 1, 1, 'Mike', '8cb2237d0679ca88db6464eac60da96345513964');

INSERT INTO staff (first_name, last_name, address_id, email, store_id, active, username, password) 
VALUES ('Jon', 'Stephens', 2, 'Jon.Stephens@sakilastaff.com', 2, 1, 'Jon', '8cb2237d0679ca88db6464eac60da96345513964');

-- Insert stores
INSERT INTO store (manager_staff_id, address_id) VALUES (1, 1);
INSERT INTO store (manager_staff_id, address_id) VALUES (2, 2);

-- Insert customers
INSERT INTO customer (store_id, first_name, last_name, email, address_id, active) 
VALUES (1, 'MARY', 'SMITH', 'MARY.SMITH@sakilacustomer.org', 1, 1);

INSERT INTO customer (store_id, first_name, last_name, email, address_id, active) 
VALUES (1, 'PATRICIA', 'JOHNSON', 'PATRICIA.JOHNSON@sakilacustomer.org', 2, 1);

INSERT INTO customer (store_id, first_name, last_name, email, address_id, active) 
VALUES (2, 'LINDA', 'WILLIAMS', 'LINDA.WILLIAMS@sakilacustomer.org', 3, 1);

INSERT INTO customer (store_id, first_name, last_name, email, address_id, active) 
VALUES (2, 'BARBARA', 'JONES', 'BARBARA.JONES@sakilacustomer.org', 4, 1);

INSERT INTO customer (store_id, first_name, last_name, email, address_id, active) 
VALUES (1, 'ELIZABETH', 'BROWN', 'ELIZABETH.BROWN@sakilacustomer.org', 5, 1);

-- Insert inventory
INSERT INTO inventory (film_id, store_id) VALUES (1, 1);
INSERT INTO inventory (film_id, store_id) VALUES (1, 1);
INSERT INTO inventory (film_id, store_id) VALUES (1, 2);
INSERT INTO inventory (film_id, store_id) VALUES (2, 1);
INSERT INTO inventory (film_id, store_id) VALUES (2, 2);
INSERT INTO inventory (film_id, store_id) VALUES (3, 1);
INSERT INTO inventory (film_id, store_id) VALUES (3, 2);
INSERT INTO inventory (film_id, store_id) VALUES (4, 1);
INSERT INTO inventory (film_id, store_id) VALUES (5, 2);
INSERT INTO inventory (film_id, store_id) VALUES (6, 1);

-- Insert rentals
INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id, return_date) 
VALUES ('2022-05-24 22:53:30', 1, 1, 1, '2022-05-26 22:04:30');

INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id, return_date) 
VALUES ('2022-05-24 22:54:33', 2, 1, 1, '2022-05-28 19:40:33');

INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id, return_date) 
VALUES ('2022-05-24 23:03:39', 3, 1, 1, '2022-06-01 22:12:39');

INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id, return_date) 
VALUES ('2022-05-24 23:04:41', 4, 2, 2, '2022-06-03 01:43:41');

INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id, return_date) 
VALUES ('2022-05-24 23:05:21', 5, 2, 1, '2022-06-02 04:33:21');

-- Insert payments
INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date) 
VALUES (1, 1, 1, 2.99, '2022-05-25 11:30:37');

INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date) 
VALUES (1, 1, 2, 0.99, '2022-05-28 10:35:23');

INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date) 
VALUES (1, 1, 3, 5.99, '2022-06-15 00:54:12');

INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date) 
VALUES (2, 2, 4, 0.99, '2022-06-15 18:02:53');

INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date) 
VALUES (2, 1, 5, 9.99, '2022-06-15 21:08:06');