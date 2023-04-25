#!/bin/bash

# Run netstat and parse the output
NETSTAT_OUTPUT=$(netstat -tnlp)

# Extract the listening address, port, process name and pid for each connection
CONNECTION_INFO=$(echo "$NETSTAT_OUTPUT" | grep "LISTEN" | awk '{print $4,$7,$8}' | sort)

# Output the results in txt or json format
if [ "$1" = "json" ]; then
    echo "$CONNECTION_INFO" | while read ADDRESS PROCESS; do
        IP=$(echo $ADDRESS | rev | cut -d ':' -f 2- | rev)
        if [[ $IP == "::"* ]]; then
            IP="::"
        fi
        PORT=$(echo $ADDRESS | rev | cut -d ':' -f 1 | rev)
        PID=$(echo $PROCESS | cut -d / -f 1)
        NAME=$(echo $PROCESS | cut -d / -f 2-)
        echo "{\"address\": \"$IP\", \"port\": \"$PORT\", \"process_name\": \"$NAME\",\"pid\":\"$PID\"}"
    done
else
    # Output the table header
    printf "+------------------------+----------------------------------+\n"
    printf "|%23s|%34s|\n" "ADDRESS" "PROCESS"
    printf "+------------------------+----------------------------------+\n"

    # Output the table rows
    YELLOW='\033[1;33m'
    NC='\033[0m'

    echo "$CONNECTION_INFO" | while read ADDRESS PROCESS; do
        if [[ $ADDRESS == "0.0.0.0"* ]] || [[ $ADDRESS == "::"* ]]; then
            printf "${YELLOW}|%23s|%34s|${NC}\n" "$ADDRESS" "$PROCESS"
        else
            printf "|%23s|%34s|\n" "$ADDRESS" "$PROCESS"
        fi
        printf "+------------------------+----------------------------------+\n"
    done
fi
