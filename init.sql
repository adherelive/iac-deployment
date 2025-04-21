CREATE USER 'user'@'mysql' IDENTIFIED BY 'password'; -- Replace with the actual password from your secret or .env file
GRANT ALL PRIVILEGES ON adhere.* TO 'user'@'mysql'; -- Grant privileges to the 'adhere' database
FLUSH PRIVILEGES;