#!/bin/bash
set -Eeuo pipefail

# Input parameters
oracleDBPassword=$1

# Start the database listener
lsnrctl start

# Create a data directory for the Oracle data files
mkdir /u02/oradata

# Run the Database Creation Assistant
dbca -silent \
   -createDatabase \
   -templateName General_Purpose.dbc \
   -gdbname oratest1 \
   -sid oratest1 \
   -responseFile NO_VALUE \
   -characterSet AL32UTF8 \
   -sysPassword ${oracleDBPassword} \
   -systemPassword ${oracleDBPassword} \
   -createAsContainerDatabase false \
   -databaseType MULTIPURPOSE \
   -automaticMemoryManagement false \
   -storageType FS \
   -datafileDestination "/u02/oradata/" \
   -ignorePreReqs

# Set Oracle variables
export ORACLE_SID=oratest1
echo "export ORACLE_SID=oratest1" >> ~oracle/.bashrc

# Create test user and grant permissions
sqlplus sys/${oracleDBPassword} as sysdba <<EOF
create user testuser identified by ${oracleDBPassword};
grant sysdba to testuser;
grant create table, create view, create procedure, create sequence, create session to testuser;
grant select on pending_trans$ to testuser;
grant select on dba_2pc_pending to testuser;
grant select on dba_pending_transactions to testuser;
grant execute on dbms_xa to testuser;
alter user testuser quota unlimited on users;
EOF
