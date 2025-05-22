------- drop any table with this name in the database that exists

DROP TABLE IF EXISTS delivery CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS product CASCADE;
DROP TABLE IF EXISTS customer CASCADE;
DROP TABLE IF EXISTS address CASCADE;
DROP TABLE IF EXISTS sub_category CASCADE;
DROP TABLE IF EXISTS category CASCADE;


------------create tables with their attribute and entities
-- CATEGORY TABLE
CREATE TABLE category (
    category_id SERIAL PRIMARY KEY,
    category_name TEXT NOT NULL UNIQUE
);

-- SUB-CATEGORY TABLE
CREATE TABLE sub_category (
    sub_category_id SERIAL PRIMARY KEY,
    sub_category_name TEXT NOT NULL,
    category_id INT NOT NULL,
    CONSTRAINT fk_sub_category_category_id FOREIGN KEY (category_id)
        REFERENCES category (category_id)
);

-- ADDRESS TABLE
CREATE TABLE address (
    address_id SERIAL PRIMARY KEY,
    country_name TEXT NOT NULL,
    state_name TEXT NOT NULL,
    region TEXT NOT NULL,
    city_name TEXT NOT NULL,
    postal_code TEXT NOT NULL
);

-- CUSTOMER TABLE
CREATE TABLE customer (
    customer_item_id SERIAL PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    customer_name TEXT NOT NULL,
    segment VARCHAR(50) NOT NULL,
    address_id INT NOT NULL,
    CONSTRAINT fk_customer_address_id FOREIGN KEY (address_id)
        REFERENCES address (address_id)
);

-- PRODUCT TABLE
CREATE TABLE product (
    product_item_id SERIAL PRIMARY KEY,
    product_id VARCHAR(50) NOT NULL,
    product_name TEXT NOT NULL,
    sub_category_id INT NOT NULL,
    CONSTRAINT fk_product_sub_category_id FOREIGN KEY (sub_category_id)
        REFERENCES sub_category (sub_category_id)
);

-- ORDER TABLE
CREATE TABLE orders (
    order_item_id SERIAL PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL,
    order_date DATE NOT NULL,
    sales INT NOT NULL,
    product_item_id INT NOT NULL,
    customer_item_id INT NOT NULL,
    CONSTRAINT fk_order_product_item_id FOREIGN KEY (product_item_id)
        REFERENCES product (product_item_id),
    CONSTRAINT fk_order_customer_item_id FOREIGN KEY (customer_item_id)
        REFERENCES customer (customer_item_id)
);

-- DELIVERY TABLE
CREATE TABLE delivery (
    shipping_id SERIAL PRIMARY KEY,
    ship_date DATE NOT NULL,
    ship_mode TEXT NOT NULL,
    order_item_id INT NOT NULL,
    CONSTRAINT fk_delivery_order_item_id FOREIGN KEY (order_item_id)
        REFERENCES orders (order_item_id)
);


------------------------------------------------insert/ migrate values into the new  table

INSERT INTO category (category_name)
SELECT DISTINCT "Category"
FROM train;




INSERT INTO sub_category (sub_category_name, category_id)
SELECT DISTINCT t."Sub-Category", c.category_id
FROM train t
JOIN category c ON t."Category" = c.category_name;




INSERT INTO address (country_name, state_name, region, city_name, postal_code)
SELECT DISTINCT 
    "Country", 
    "State", 
    "Region", 
    "City", 
    COALESCE("Postal Code", '0')  
FROM train;




INSERT INTO customer (customer_id, customer_name, segment, address_id)
SELECT DISTINCT t."Customer ID", t."Customer Name", t."Segment", a.address_id
FROM train t
JOIN address a 
    ON t."Country" = a.country_name 
   AND t."State" = a.state_name 
   AND t."Region" = a.region 
   AND t."City" = a.city_name 
   AND t."Postal Code" = a.postal_code;




INSERT INTO product (product_id, product_name, sub_category_id)
SELECT DISTINCT t."Product ID", t."Product Name", s.sub_category_id
FROM train t
JOIN sub_category s ON t."Sub-Category" = s.sub_category_name;



INSERT INTO orders (order_id, order_date, sales, product_item_id, customer_item_id)
SELECT 
    t."Order ID",
    t."Order Date",
    CAST(t."Sales" AS INT),
    p.product_item_id,
    c.customer_item_id
FROM train t
JOIN product p ON t."Product ID" = p.product_id
JOIN customer c ON t."Customer ID" = c.customer_id;



INSERT INTO delivery (ship_date, ship_mode,  order_item_id)
SELECT DISTINCT t."Ship Date", t."Ship Mode", o."order_item_id"
FROM train t
join orders o on t."Order ID" = o.order_id;


---------------------------------------------------Creating views for data analysts 


---1.What products has each customer ordered, and how much did they spend?

create view customer_order_details AS
	select 
		o.order_id, 
		p.product_name,
		c.customer_name,
		SUM(O.sales) as total_sales,
	    o.order_date
	from product p
	join orders o on p.product_item_id  = o.product_item_id 
	join customer c on c.customer_item_id = o.customer_item_id 
	group by p.product_name, c.customer_name ,o.order_id, o.order_date
	order by c.customer_name;

---3.Which products are the top 3 sellers based on total sales?

create view top_selling_products as
select 
	p.product_id,
	p.product_name,
	SUM(O.sales) as total_sales
from product p
join orders o on p.product_item_id  = o.product_item_id 
group by p.product_name, p.product_id
order by total_sales desc;

---3. How are customers segmented by region and segment type?

create view customers_segmentation as
select 
	c.customer_name,
	c.segment,
	a.region,
	COUNT(o.order_id) as total_order
from customer c
join address a on a.address_id = c.address_id
left join orders o on o.customer_item_id = c.customer_item_id 
group by c.customer_name, c.segment,a.region
order by total_order desc;

--4. What are the delivery details (date and method) for each order?

create view order_delivery_details as
select 
	o.order_id ,
	COUNT(o.order_id) as total_order,
	SUM(o.sales) as total_sales,
	o.order_date, 
	d.ship_date,
	d.ship_mode
from orders o
join delivery d on d.order_item_id = o.order_item_id 
group by o.order_id, o.order_date , d.ship_date, d.ship_mode
order by  o.order_date ,d.ship_date desc;

---5.Which sub-category and category does each product belong to?

create view product_categories as
select 
    p.product_name, 
    s.sub_category_name, 
    c.category_name
from product p
join sub_category s ON p.sub_category_id = s.sub_category_id
join category c ON s.category_id = c.category_id;


--6.How many orders has each customer placed by date?

create view customer_orders_by_date AS
select 
    c.customer_name, 
    o.order_date, 
    COUNT(o.order_id) AS orders_count
from orders o
join customer c ON o.customer_item_id = c.customer_item_id
group by c.customer_name, o.order_date
order by o.order_date desc;

--------------------------------------------   SQL QUERIES (QUESTIONS ANSWERED)
---1.Which 5 customers have placed the most orders?

select 
 	c.customer_name,
 	COUNT(o.order_id) as top_orders
from customer c
join orders o on o.customer_item_id = c.customer_item_id 
group by c.customer_name 
order by top_orders  desc
limit 5;


--2. What products had the highest sales in the last month?

select 
	p.product_name,
	SUM(o.sales) as highest_sales
from product p 
join orders o on o.product_item_id = p.product_item_id 
where o.order_date >= (
	select MAX(order_date) - INTERVAL '30 days' FROM orders)
group by p.product_name
order by highest_sales;

--3. Which customers have not placed any orders?
select 
	c.customer_name
from customer c
left join orders o ON c.customer_item_id = o.customer_item_id
where o.order_id Is null;

--4. What is the average sales value across all orders?
select
	SUM(sales)/COUNT(order_id) as avg_sales
from orders;

---or do this 
selectT ROUND(AVG(sales),0) average_sales
from orders;


---5. Which products have never been sold?
select 
	p.product_name,
	sum(o.sales) total_sales
from product p
left join orders o on o.product_item_id =p.product_item_id 
where o.sales <= 0 or null
group by p.product_name;

----------------------- i also found category and sub category of products never sold before as bonus
select 
	p.product_id,
	p.product_name,
	sc.sub_category_name ,
	c.category_name 
from product p
left join sub_category sc on sc.sub_category_id = p.sub_category_id 
join category c on c.category_id = sc.category_id 
where product_name LIKE '%Hoover Replacement Belt for Commercial Guardsman Heavy-Duty Upright Vacuum%';

----6. What are the 5 orders with the highest sales?

select 
	order_id,
	SUM(sales) as highest_sales
from orders 
group by order_id 
order by highest_sales desc 
limit 5;

---7. What is the most expensive product purchased by each customer?
with product_purchased as (	
	select 
		SUM(o.sales) as total_sales,
		p.product_name,
		c.customer_name,
		rank() over(partition by c.customer_name
					order by SUM(o.sales)desc ) as rnk
	from orders o 
	join product p on p.product_item_id = o.product_item_id 
	join customer c on c.customer_item_id = o.customer_item_id
	group by  p.product_name, c.customer_name
)
 select 
 	product_name,
 	total_sales,
 	customer_name,
 	rnk
 from product_purchased 
 where rnk =1 
order by total_sales desc;



-- 8.What are the total sales for each product category?

select
	SUM(o.sales) as total_sales,
	c.category_name 
from orders o
join product p on p.product_item_id = o.product_item_id
join sub_category sc on sc.sub_category_id = p.sub_category_id 
join category c on c.category_id = sc.category_id
group by c.category_name;


--9.Which products have total sales below a certain threshold (e.g., 1000)?

select
	SUM(o.sales) as total_sales,
	p.product_name 
from orders o
join product p on p.product_item_id = o.product_item_id
group by p.product_name
having SUM(o.sales) <= 1000
order by total_sales desc ;



---10. How do product sales compare before and after a specific date?
select 
    p.product_name,
    SUM(CASE WHEN o.order_date < '2023-01-01' THEN o.sales ELSE 0 END) AS sales_before,
    SUM(CASE WHEN o.order_date >= '2023-01-01' THEN o.sales ELSE 0 END) AS sales_after
from orders o
join product p on o.product_item_id = p.product_item_id
group BY p.product_name;


