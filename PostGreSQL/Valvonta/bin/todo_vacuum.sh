#! /bin/bash
psql -d mds -U postgres -f /home/postgres/from_solita/sql/vacuum_db.sql

# Jossa:
# VACUUM ANALYZE;

