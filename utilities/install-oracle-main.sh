#!/bin/bash
set -Eeuo pipefail

# Input parameters
oracleDBPassword=$1

# Check for last created disk device that we will format for use holding Oracle datafiles
ls -alt /dev/sd*|head -1

# Create a disk label
parted /dev/sdc mklabel gpt

# Create a primary partition spanning the whole disk
parted -a optimal /dev/sdc mkpart primary 0GB 64GB

# Check the device details by printing its metadata
parted /dev/sdc print

# Create a filesystem on the device partition
mkfs -t ext4 /dev/sdc1

# Create a mount point
mkdir /u02

# Mount the disk
mount /dev/sdc1 /u02

# Change permissions on the mount point
chmod 777 /u02

# Add the mount to the /etc/fstab file
echo "/dev/sdc1               /u02                    ext4    defaults        0 0" >> /etc/fstab

# Open firewall ports
firewall-cmd --zone=public --add-port=1521/tcp --permanent
firewall-cmd --zone=public --add-port=5502/tcp --permanent
firewall-cmd --reload

# Switch to the oracle user and install the database
cp install-oracle.sh /tmp
chmod 777 /tmp/install-oracle.sh
runuser -l oracle -c "/tmp/install-oracle.sh ${oracleDBPassword}"
