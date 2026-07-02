FROM mcr.microsoft.com/mssql/server:2022-latest

# Switch to root to copy files and set permissions
USER root

WORKDIR /tmp

# Copy the initialization script and SQL files into the image
COPY ./init_db.sh ./
COPY ./sql ./sql-setup/sql-scripts

RUN chmod +x ./init_db.sh

# Set the password strictly for the build process
ENV ACCEPT_EULA=Y

ARG MSSQL_SA_PASSWORD
ARG MSSQL_DB_NAME

# Run the init script to bake the database
RUN MSSQL_SA_PASSWORD="${MSSQL_SA_PASSWORD}" MSSQL_DB_NAME="${MSSQL_DB_NAME}" ./init_db.sh

# Cleanup the scripts as they are no longer needed
RUN rm -rf /tmp/sql-setup ./init_db.sh

# FIX: Give ownership of the database files back to the mssql user
RUN chown -R mssql:root /var/opt/mssql

# Switch back to the default mssql user
USER mssql

# The base image automatically starts sqlservr as the default command