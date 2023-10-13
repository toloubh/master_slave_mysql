#!/bin/bash

# Stop and remove containers, including volumes (data)
#docker-compose down -v

# Clean up the data directory (optional, use with caution)
rm -rf ./data/*

# Build and start containers
docker-compose build
docker-compose up -d

# Sleep for a sufficient time to allow MySQL to fully start
until docker exec mysql_master bash -c 'export MYSQL_PWD=password@r00t; mysql -u root -e ";"'
do
    echo "Waiting for mysql_master database connection..."
    sleep 15
done

# Execute the command to show the master status
MS_STATUS=$(docker exec mysql_master mysql -hlocalhost -uroot -p'password@r00t' -e "SHOW MASTER STATUS" 2>/dev/null)

# Check if MySQL returned an error
if [ $? -ne 0 ]; then
    echo "Error executing 'SHOW MASTER STATUS' in MySQL."
    exit 1
fi

# Extract values from the result and remove the leading "=" sign
CURRENT_LOG=$(echo "$MS_STATUS" | awk 'NR==2 {sub(/^=/, "", $1); print $1}')
CURRENT_POS=$(echo "$MS_STATUS" | awk 'NR==2 {sub(/^=/, "", $2); print $2}')

# Display the extracted values
echo "The CURRENT_LOG is $CURRENT_LOG"
echo "The CURRENT_POS is $CURRENT_POS"

# Perform MySQL tasks
replica_stmt="CREATE USER 'replica_usr'@'%' IDENTIFIED WITH 'mysql_native_password' BY 'ForSlaveRepPw'; GRANT REPLICATION SLAVE ON *.* TO 'replica_usr'@'%'; GRANT SELECT ON *.* TO 'replica_usr'@'%'; FLUSH PRIVILEGES;"

# Execute MySQL commands to create the user and grant privileges
docker exec mysql_master mysql -hlocalhost -uroot -p'password@r00t' -e "$replica_stmt"

# Check if the 'replica_usr' user exists
result=$(docker exec mysql_master mysql -hlocalhost -uroot -p'password@r00t' -e "SELECT user FROM mysql.user WHERE user='replica_usr';" 2>/dev/null)

# Check if MySQL returned an error
if [ $? -ne 0 ]; then
    echo "Error executing MySQL commands to create the 'replica_usr' user."
    exit 1
fi

# Check if the 'replica_usr' user exists in the result
if [[ $result == *"replica_usr"* ]]; then
    echo "The 'replica_usr' user exists."
else
    echo "The 'replica_usr' user created."
fi
# Check if the SQL commands were executed successfully
if [ $? -eq 0 ]; then
    echo "SQL commands executed successfully."
else
    echo "Error executing SQL commands."
fi
