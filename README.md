# master_slave_mysql

Setting up a MySQL replication where one server acts as the master and another as the slave, with both running in Docker containers on separate servers, requires a few steps. Here's a high-level overview of the process:

Assumptions:
```
    1. You have Docker installed on both servers. (You have Docker v.18 or higher installed)
    2. Installed docker-compose v1.23 or higher.
    3. You have MySQL Docker images available or can pull them from a Docker registry.
    4. You have separate servers for the master and slave.
```
MySQL replication is a special setup which involves two or more MySQL servers where one database server (known as master or source) is copied to another (known as slave or replica).
Process of replica synchronisation is done through coping and performing SQL statements from source’s binary log. MySQL configuration allows to select the whole source database or only particular tables to be copied to the replica.
By default synchronisation type for MySQL replication is asynchronous (one-way), which means “replica” does not notify it’s “source” about results of coping and processing events. Additional types of synchronisation (semi-synchronous, synchronous) may be available via plugins or in special setups (like NDB Cluster).
With MySQL replication you can make some specific configuration types: chained replication, circular (also known as master-master or ring) and combinations of these.

*** Note: The limitation is that replica can have only one source server.

You can launch the Docker Compose for the primary server by running master/build_master.sh. Then, to set up the Docker Compose for the secondary server, execute slave/build_slave.sh. Alternatively, you can utilize the following command:

1. Run docker compose for primary server
```
cd master
./build_master.sh
```
2. Check if container is created
```
sudo docker ps
```
3. If you don't run the script but proceed to execute docker-compose up -d, make sure to follow up by creating a new user for replication on the primary server with the necessary REPLICATION SLAVE permission.
Create a MySql user for replication 
```
sudo docker exec -it mysql_master -u root -p
mysql > CREATE USER 'replica_usr'@'%' IDENTIFIED WITH mysql_native_password BY 'ForSlaveRepPw';
```
Grant permissions to MySql user, granted replication privileges, and flushed the privileges to ensure they are active.
```
mysql > GRANT REPLICATION SLAVE ON *.* TO 'replica_usr'@'%';
mysql > GRANT SELECT ON *.* TO 'replica_usr'@'%'; 
mysql > FLUSH PRIVILEGES;
```
4. use the command below to verify the replication status:
```
mysql> SHOW MASTER STATUS\G;
*************************** 1. row **************************
             File: mysql-bin.000003
         Position: 157
     Binlog_Do_DB: mydatabase
 Binlog_Ignore_DB: mysql
Executed_Gtid_Set:*
```
Take note of the mysql-bin.000003 file and 157 position values from the response above. We will utilize these values in the configuration of the secondary server.

5. Run docker compose for secondary server
```
cd slave
./build_slave.sh
sudo docker ps
```
6.  If you choose not to run the script and proceed directly with docker-compose up -d, you can then utilize all the available variables to modify and execute the following command to initiate replication:
```
MYSQL > STOP SLAVE;
MYSQL > CHANGE MASTER TO
MASTER_HOST='IP Master Server',
MASTER_PORT=3306,
MASTER_USER='${DB_USERNAME}', -- e.g., replica_usr
MASTER_PASSWORD='${DB_PASSWORD}', -- e.g., ForSlaveRepPw
MASTER_LOG_FILE='mysql-bin.000003', -- Use the correct log file from the master
MASTER_LOG_POS=157; -- Use the correct log position from the
MYSQL > START SLAVE;
```
7. Check Slave Status:
You can check the status of the slave replication by running:
```
mysql> SHOW SLAVE STATUS\G;
*************************** 1. row ***************************
               Slave_IO_State: Waiting for source to send event
                  Master_Host: #show ip master server
                  Master_User: replica_usr
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000003
          Read_Master_Log_Pos: 2233
               Relay_Log_File: relay-log.000011
                Relay_Log_Pos: 720
        Relay_Master_Log_File: mysql-bin.000003
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
              Replicate_Do_DB: 
          Replicate_Ignore_DB: 
           Replicate_Do_Table: 
       Replicate_Ignore_Table: 
      Replicate_Wild_Do_Table: 
  Replicate_Wild_Ignore_Table: mysql.%
                   Last_Errno: 0
                   Last_Error: 
                 Skip_Counter: 0
          Exec_Master_Log_Pos: 157
              Relay_Log_Space: 3002
              Until_Condition: None
               Until_Log_File: 
                Until_Log_Pos: 0
           Master_SSL_Allowed: No
        Seconds_Behind_Master: 0
Master_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error: 
               Last_SQL_Errno: 0
               Last_SQL_Error: 
  Replicate_Ignore_Server_Ids: 
             Master_Server_Id: 1
                  Master_UUID: 4564f6f4-6757-11ee-a31c-0242ac170003
             Master_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
      Slave_SQL_Running_State: Replica has read all relay log; waiting for more updates
           Master_Retry_Count: 10
                  Master_Bind: 
      Last_IO_Error_Timestamp: 
     Last_SQL_Error_Timestamp: 
                Auto_Position: 0
         Replicate_Rewrite_DB: 
                 Channel_Name: 
           Master_TLS_Version: 
       Master_public_key_path: 
        Get_master_public_key: 0
            Network_Namespace: 

```
Verify that both "Slave_IO_Running" and "Slave_SQL_Running" are "Yes" to ensure successful
replication.
If all goes smoothly you will get such messages:
Waiting for mysql_master database connection…
and finally a replica (slave) status report.

8. check the synchronisation proccess 
```
$ sudo docker exec -it mysql_slave bash
mysql -h ip_master_server -u replica_usr -p
mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| performance_schema |
| tera               |
| testDB             |
+--------------------+
4 rows in set (0.00 sec)
mysql> use tera
Database changed
mysql> 
mysql> show tables;
+----------------+
| Tables_in_tera |
+----------------+
| Persons        |
+----------------+
1 row in set (0.01 sec)
``` 

