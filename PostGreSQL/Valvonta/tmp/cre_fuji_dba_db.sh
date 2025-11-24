#!/bin/bash

. $HOME/pg.env
#. /home/postgres/pg.env
pg_isready 1>/dev/null 2>&1
return_code=$?
if [ $return_code -ne 0 ]; then
  exit $return_code
fi

# Do not run in standby databases
IN_RECOVERY=$(psql -d postgres -v "ON_ERROR_STOP=on" -t -c 'SELECT pg_is_in_recovery()')
case ${IN_RECOVERY// /} in
( t ) exit 0 ;;
esac

# Check if database already exists
# DB_EXISTS=$(psql -d postgres -v "ON_ERROR_STOP=on" -t -c "SELECT count(*) FROM pg_database where datname = 'fuji_dba_db'")
# case ${DB_EXISTS// /} in
# ( 1 ) exit 0 ;;
# esac

psql -v "ON_ERROR_STOP=on" -U $PGUSER $PGDATABASE -w <<EOF
drop database if exists fuji_dba_db;
-- drop owned by fuji_dba;
do \$$
declare
my_count integer;
begin
select count(*) into my_count from pg_catalog.pg_user where usename = 'fuji_dba';
-- raise notice 'count: %,', my_count;
if my_count > 0 then
execute 'drop owned by fuji_dba';
end if;
end \$$;
drop user if exists fuji_dba;
create user fuji_dba with password 'BDCHYr9t1cYj4adGyvI3';
create database fuji_dba_db;
alter database fuji_dba_db owner to fuji_dba;
\c fuji_dba_db
create table fuji_check_status(id integer primary key, col1 varchar, col2 varchar);
ALTER TABLE fuji_check_status OWNER TO fuji_dba;
insert into fuji_check_status(id, col1, col2) values (1,'from_val', 'some_val');
-- Wrapper functiot:
-- WAL tiedostojen lukumaarat
create or replace function count_wal_files() 
returns bigint as \$$
declare
my_pg_version integer;
my_count integer;
begin 
SELECT current_setting('server_version_num') into my_pg_version;
if my_pg_version > 090600 then
select count(*) into my_count from pg_ls_dir('pg_wal');
else
select count(*) into my_count from pg_ls_dir('pg_xlog');
end if;
return my_count;
end;
\$$ 
language plpgsql
security definer;
REVOKE ALL ON FUNCTION count_wal_files() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION count_wal_files() to fuji_dba;

-- WAL filet valmiina arkistoitavaksi
CREATE OR REPLACE FUNCTION count_ready_files()
returns bigint as \$$
declare
my_pg_version integer;
my_count integer;
begin 
SELECT current_setting('server_version_num') into my_pg_version;
if my_pg_version > 090600 then 
select count(*) into my_count from pg_ls_dir('pg_wal/archive_status') where pg_ls_dir like '%.ready';
else
select count(*) into my_count from pg_ls_dir('pg_xlog/archive_status') where pg_ls_dir like '%.ready';
end if;
return my_count;
end;
\$$ 
LANGUAGE plpgsql
SECURITY DEFINER;
REVOKE ALL ON FUNCTION count_ready_files() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION count_ready_files() to fuji_dba;
-- Streaming replikoinnin bytes lag tutkimista varten:
create or replace function pg_stat_repl() returns setof
pg_catalog.pg_stat_replication as \$$
begin 
return query(select * from pg_catalog.pg_stat_replication); 
end\$$ 
language plpgsql 
security definer;
REVOKE ALL ON FUNCTION pg_stat_repl() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pg_stat_repl() to fuji_dba;
create or replace view public.pg_stat_repl as select * from pg_stat_repl();
grant select on public.pg_stat_repl to fuji_dba;
-- read only test for LoadBalancer (LB10) and pgpool
create or replace function is_read_only() returns integer as \$$
declare
return_code integer;
begin
update fuji_check_status set col1=col1;
return 0;
exception
when sqlstate '25006' then
return 1;
when others then
return 2;
end;
\$$ language plpgsql;
REVOKE ALL ON FUNCTION is_read_only() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION is_read_only() to fuji_dba;

\q
EOF

vacuumdb fuji_dba_db
exit 0
