#!/bin/bash

# Ignore TERM, HUP, and INT signals
trap '' TERM HUP INT

VERBOSE=false

log_and_print() {
    local message=$1
    logger "$message"
    if $VERBOSE; then
        echo "$message"
    fi
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -verbose) VERBOSE=true ;;
        -name)
            shift
            DESIRED_NAME=$1
            ;;
        -ip)
            shift
            DESIRED_IP=$1
            ;;
        -hostentry)
            shift
            DESIRED_HOSTNAME=$1
            shift
            DESIRED_HOSTIP=$1
            ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [[ -n "$DESIRED_NAME" ]]; then
    CURRENT_NAME=$(hostname)
    if [[ "$CURRENT_NAME" != "$DESIRED_NAME" ]]; then
        if $VERBOSE; then
            echo "Updating hostname from $CURRENT_NAME to $DESIRED_NAME"
        fi
        sudo sed -i "s/ $CURRENT_NAME$/ $DESIRED_NAME/g" /etc/hosts
        echo $DESIRED_NAME | sudo tee /etc/hostname > /dev/null
        sudo hostname $DESIRED_NAME
        log_and_print "Hostname changed from $CURRENT_NAME to $DESIRED_NAME"
    else
        if $VERBOSE; then
            echo "Hostname is already set to $DESIRED_NAME"
        fi
    fi
fi

if [[ -n "$DESIRED_IP" ]]; then
    LAN_INTERFACE=$(ip route | grep default | awk '{print $5}')
    CURRENT_IP=$(ip addr show $LAN_INTERFACE | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
    if [[ "$CURRENT_IP" != "$DESIRED_IP" ]]; then
        if $VERBOSE; then
            echo "Updating IP address from $CURRENT_IP to $DESIRED_IP"
        fi
        sudo sed -i "s/$CURRENT_IP/$DESIRED_IP/g" /etc/hosts
        sudo sed -i "s/$CURRENT_IP/$DESIRED_IP/g" /etc/netplan/*.yaml
        sudo netplan apply
        log_and_print "IP address changed from $CURRENT_IP to $DESIRED_IP"
    else
        if $VERBOSE; then
            echo "IP address is already set to $DESIRED_IP"
        fi
    fi
fi

if [[ -n "$DESIRED_HOSTNAME" && -n "$DESIRED_HOSTIP" ]]; then
    HOST_ENTRY_EXISTS=$(grep -w "$DESIRED_HOSTNAME" /etc/hosts | grep -w "$DESIRED_HOSTIP")
    if [[ -z "$HOST_ENTRY_EXISTS" ]]; then
        if $VERBOSE; then
            echo "Adding host entry for $DESIRED_HOSTNAME with IP $DESIRED_HOSTIP"
        fi
        echo "$DESIRED_HOSTIP $DESIRED_HOSTNAME" | sudo tee -a /etc/hosts > /dev/null
        log_and_print "Host entry added for $DESIRED_HOSTNAME with IP $DESIRED_HOSTIP"
    else
        if $VERBOSE; then
            echo "Host entry for $DESIRED_HOSTNAME with IP $DESIRED_HOSTIP already exists"
        fi
    fi
fi
