/*
=========================================

Create the schemas

=========================================
Script Purpose:
    This script stets up three schemas within the database: 'bronze' , 
    'silver', and 'gold'.
    
*/


-- Change from CDB to PDB 
ALTER SESSION SET CONTAINER = XEPDB1;


-- Create the schemas
CREATE USER bronze IDENTIFIED BY your_password;
GRANT CONNECT, RESOURCE TO bronze;

CREATE USER silver IDENTIFIED BY your_password;
GRANT CONNECT, RESOURCE TO silver;

CREATE USER gold IDENTIFIED BY your_password;
GRANT CONNECT, RESOURCE TO gold;
