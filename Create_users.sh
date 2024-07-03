#!/bin/bash

# Define Input, log and password files
LOGFILE="/var/log/user_management.log"
PASSFILE="/var/secure/user_passwords.txt"
INPUTFILE="$1"

# Function to generate random password
generate_password() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c 12 ; echo ''
}

# Function to Log messages
log_action() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a $LOG_FILE < /dev/null
}

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" | tee -a $LOGFILE
   exit 1
fi

# Ensure input file is provided
if [ -z "$INPUTFILE" ]; then
    echo "Usage: $0 <input_file>" | tee -a $LOGFILE
    exit 1
fi

# Ensure log directory exists
mkdir -p /var/log
touch $LOGFILE
chmod 600 $LOGFILE

# Ensure password directory exists and is secure
mkdir -p /var/secure
touch $PASSFILE
chmod 600 $PASSFILE

# Read the input file
while IFS=";" read -r username groups; do
    username=$(echo "$username" | xargs) # trim whitespace
    groups=$(echo "$groups" | xargs) # trim whitespace

    # Create user already and personal groups
    if id -u "$username" >/dev/null 2>&1; then
        echo "User $username already exists. Skipping." | tee -a $LOGFILE
        continue
    fi

    # Create groups if they do not exist
    IFS=',' read -r -a group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        if ! getent group "$group" >/dev/null 2>&1; then
            sudo groupadd "$group"
            echo "Group $group created." | tee -a $LOGFILE
        fi
    done

    # Create the user with the specified groups
    useradd -m -G "$groups" "$username"
    if [ $? -eq 0 ]; then
        echo "User $username created and added to groups: $groups" | tee -a $LOGFILE
    else
        echo "Failed to create user $username." | tee -a $LOGFILE
        continue
    fi

    # Set up the home directory permissions
    chmod 700 /home/"$username"
    chown "$username":"$username" /home/"$username"

    # Generate a random password and set it for the user
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    if [ $? -eq 0 ]; then
        echo "Password set for user $username." | tee -a $LOGFILE
    else
        echo "Failed to set password for user $username." | tee -a $LOGFILE
        continue
    fi

    # Store the generated password securely
    echo "$username:$password" >> $PASSFILE
    chmod 600 $PASSFILE
done < "$INPUTFILE"

echo "User creation process completed." | tee -a $LOGFILE
exit 0
