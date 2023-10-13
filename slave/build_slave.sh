#!/bin/bash

#docker-compose down
docker-compose up -d

# Sleep for a sufficient time to allow MySQL to fully start
sleep 15

# Define MySQL connection parameters for the master
MASTER_HOST='write here ip master server'
MASTER_PORT=3306
MASTER_USER='replica_usr'
MASTER_PASSWORD='ForSlaveRepPw'

# Query the MySQL master to get the MASTER_LOG_FILE and MASTER_LOG_POS
MASTER_LOG_INFO=$(docker exec mysql_slave mysql -h"$MASTER_HOST" -P"3306" -u"root" -p"password@r00t" -e "SHOW MASTER STATUS" 2>/dev/null)

# Check if the query was successful
if [ $? -eq 0 ]; then
    # Extract MASTER_LOG_FILE and MASTER_LOG_POS
    MASTER_LOG_FILE=$(echo "$MASTER_LOG_INFO" | awk 'NR==2 {print $1}')
    MASTER_LOG_POS=$(echo "$MASTER_LOG_INFO" | awk 'NR==2 {print $2}')

    echo "MASTER_LOG_FILE is $MASTER_LOG_FILE"
    echo "MASTER_LOG_POS is $MASTER_LOG_POS"
else
    echo "Error querying the master for MASTER_LOG_FILE and MASTER_LOG_POS."
fi

# Execute SQL commands in the MySQL container
docker exec mysql_slave mysql -uroot -p"KeepPasswordStrongForRoot" <<EOF
STOP SLAVE;
CHANGE MASTER TO
MASTER_HOST='$MASTER_HOST',
MASTER_PORT=$MASTER_PORT,
MASTER_USER='$MASTER_USER',
MASTER_PASSWORD='$MASTER_PASSWORD',
MASTER_LOG_FILE='$MASTER_LOG_FILE',
MASTER_LOG_POS=$MASTER_LOG_POS;
START SLAVE;
EOF

# Check if the SQL commands were executed successfully
if [ $? -eq 0 ]; then
    echo "SQL commands executed successfully."
else
    echo "Error executing SQL commands."
fi
