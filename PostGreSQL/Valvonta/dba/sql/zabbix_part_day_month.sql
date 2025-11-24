/*
##      -----------------------------------------------------------------------
##
##      Alkuperaiset rutiinit kopioitu:
##      https://zabbix.org/wiki/Docs/howto/zabbix2_postgresql_autopartitioning
##      Joihin muokattu partition luontiin indekseja ja constraintteja, seka
##      varmistetaan etta luonnin aikanakin tulevat tapahtumat paatyvat kantaan
##
##      -----------------------------------------------------------------------
##      $RCSfile: zabbix_part_day_month_V1_2.sql,v $
##      $Revision: 1.2 $
##
##      -- FOR PostgreSQL --
##
##      Contents: Funktiot ja triggerit joilla partitioidaan Zabbixin
##      history- ja trend- tietojen taulut
##
##      $Author: rosenjyr $
##      $Date: 2019/1/31 16:24:14 $
##
##      $Log: zabbix_part_day_month.sql,v $
##
# Revision 1.0  2018/11/09 8:38:41 fijyrrose ()
#  Eka versio
#
# Revision 1.1  2018/12/13 14:42:53 fijyrrose ()
#  Muokattu niin että toimii myös Zabbix V3 kantarakenteilla 
# (jotka poikkeaa V2 rakenteista)
# HUOM! Tarkista toiminta Zabbix V4 vasten ennen kuin otat käyttöön	
# 
# Revision 1.2  2019/1/31 16:24:14 fijyrrose ()
#  Lisätty partitiointien poistorutiiniin lukitusten tarkistus ja timeoutin 
#  käsittely
# HUOM! Tarkista toiminta Zabbix V4 vasten ennen kuin otat käyttöön	
##      -----------------------------------------------------------------------
*/

-- Schema: partitions

DROP SCHEMA IF EXISTS partitions;

CREATE SCHEMA partitions
  AUTHORIZATION zabbix;

-- Function: trg_partition()

-- DROP FUNCTION trg_partition();

CREATE OR REPLACE FUNCTION trg_partition()
  RETURNS trigger AS
$BODY$
DECLARE
prefix text := 'partitions.';
timeformat text;
selector text;
_interval interval;
tablename text;
startdate text;
enddate text;
create_table_part text;
create_index_part text;
create_index_part_2 text;
create_pkey_const text;
BEGIN

selector = TG_ARGV[0];

IF selector = 'day' THEN
timeformat := 'YYYY_MM_DD';
ELSIF selector = 'month' THEN
timeformat := 'YYYY_MM';
END IF;

_interval := '1 ' || selector;
tablename :=  TG_TABLE_NAME || '_p' || to_char(to_timestamp(NEW.clock), timeformat);

EXECUTE 'INSERT INTO ' || prefix || quote_ident(tablename) || ' SELECT ($1).*' USING NEW;
RETURN NULL;

EXCEPTION
WHEN undefined_table THEN

startdate := extract(epoch FROM date_trunc(selector, to_timestamp(NEW.clock)));
enddate := extract(epoch FROM date_trunc(selector, to_timestamp(NEW.clock) + _interval ));


BEGIN
-- RAISE NOTICE 'Create partition: %',tablename;
EXECUTE 'CREATE TABLE ' || prefix || quote_ident(tablename) || ' (
LIKE ' || TG_TABLE_NAME || '
INCLUDING DEFAULTS
INCLUDING CONSTRAINTS
INCLUDING INDEXES);';
-- add inheritance
EXECUTE 'ALTER TABLE ' || prefix || quote_ident(tablename) || ' INHERIT ' || TG_TABLE_NAME || ';';
-- add clock column constraint
EXECUTE 'ALTER TABLE ' || prefix || quote_ident(tablename)
|| ' ADD CONSTRAINT ' 
|| quote_ident(tablename) || '_clock_check'
|| ' CHECK ( clock >= ' || quote_literal(startdate) || ' AND clock < ' || quote_literal(enddate) || ' );';
RAISE NOTICE '***** Partition created: %', tablename;

EXCEPTION WHEN duplicate_table THEN
  RAISE NOTICE '% %', SQLERRM, SQLSTATE;
  RAISE NOTICE 'Partition was already created: tablename (%)', tablename;
END;

--insert it again
EXECUTE 'INSERT INTO ' || prefix || quote_ident(tablename) || ' SELECT ($1).*' USING NEW;
RETURN NULL;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

ALTER FUNCTION trg_partition() OWNER TO postgres;

-- Jos halutaan poistaa/disabloida partitiointi ajetaan seuraavat:
DROP TRIGGER IF EXISTS partition_trg ON history;
DROP TRIGGER IF EXISTS partition_trg ON history_uint;
DROP TRIGGER IF EXISTS partition_trg ON history_str;
DROP TRIGGER IF EXISTS partition_trg ON history_text;
DROP TRIGGER IF EXISTS partition_trg ON history_log;
DROP TRIGGER IF EXISTS partition_trg ON trends;
DROP TRIGGER IF EXISTS partition_trg ON trends_uint;

-- Partitoiden luonti tulee kayttoon kun ajetaan seuraavat:
CREATE TRIGGER partition_trg BEFORE INSERT ON history           FOR EACH ROW EXECUTE PROCEDURE trg_partition('day');
CREATE TRIGGER partition_trg BEFORE INSERT ON history_uint      FOR EACH ROW EXECUTE PROCEDURE trg_partition('day');
CREATE TRIGGER partition_trg BEFORE INSERT ON history_str       FOR EACH ROW EXECUTE PROCEDURE trg_partition('day');
CREATE TRIGGER partition_trg BEFORE INSERT ON history_text      FOR EACH ROW EXECUTE PROCEDURE trg_partition('day');
CREATE TRIGGER partition_trg BEFORE INSERT ON history_log       FOR EACH ROW EXECUTE PROCEDURE trg_partition('day');
CREATE TRIGGER partition_trg BEFORE INSERT ON trends            FOR EACH ROW EXECUTE PROCEDURE trg_partition('month');
CREATE TRIGGER partition_trg BEFORE INSERT ON trends_uint       FOR EACH ROW EXECUTE PROCEDURE trg_partition('month');

-- Function: delete_partitions(interval, text)

-- DROP FUNCTION delete_partitions(interval, text);

CREATE OR REPLACE FUNCTION delete_partitions(intervaltodelete interval, tabletype text, tbl_name text)
  RETURNS text AS
$BODY$
DECLARE
result record ;
prefix text := 'partitions.';
table_timestamp timestamp;
delete_before_date date;
tablename text;
v_error_stack text;
lock_count integer;

BEGIN
    FOR result IN SELECT * FROM pg_tables WHERE schemaname = 'partitions' and pg_tables.tablename = tbl_name order by tablename LOOP

        table_timestamp := to_timestamp(substring(result.tablename from '[0-9_]*$'), 'YYYY_MM_DD');
        delete_before_date := date_trunc('day', NOW() - intervalToDelete);
        tablename := result.tablename;

        -- RAISE NOTICE 'tablename % table_timestamp % delete_before_date %', tablename, table_timestamp, delete_before_date;
    -- Was it called properly?
        IF tabletype != 'month' AND tabletype != 'day' THEN
            RAISE EXCEPTION 'Please specify "month" or "day" instead of %', tabletype;
        END IF;


    --Check whether the table name has a day (YYYY_MM_DD) or month (YYYY_MM) format
        IF length(substring(result.tablename from '[0-9_]*$')) = 10 AND tabletype = 'month' THEN
            --This is a daily partition YYYY_MM_DD
            RAISE NOTICE 'Skipping daily table % when trying to delete "%" partitions (%)', result.tablename, tabletype, length(substring(result.tablename from '[0-9_]*$'));
            CONTINUE;
        ELSIF length(substring(result.tablename from '[0-9_]*$')) = 7 AND tabletype = 'day' THEN
            --this is a monthly partition
            RAISE NOTICE 'Skipping monthly table % when trying to delete "%" partitions (%)', result.tablename, tabletype, length(substring(result.tablename from '[0-9_]*$'));
            CONTINUE;
        ELSE
            --This is the correct table type. Go ahead and check if it needs to be deleted
            --RAISE NOTICE 'Checking table %', result.tablename;
        END IF;

        IF table_timestamp <= delete_before_date THEN
          RAISE NOTICE 'Deleting table %', quote_ident(tablename);
          lock_count := 0;
	  select count(*) into lock_count from pg_locks l, pg_stat_all_tables t where t.relname= tablename and l.relation=t.relid;
          IF lock_count > 0 THEN
           RAISE NOTICE 'table % is locked. Skipping it', quote_ident(tablename);
            CONTINUE;
          END IF;
          BEGIN
                 EXECUTE 'DROP TABLE ' || prefix || quote_ident(tablename) || ';';
          EXCEPTION
            WHEN query_canceled THEN
              RAISE NOTICE 'Delete canceled and all rolled back. Timeout with partition: %', quote_ident(tablename);
              RAISE NOTICE 'ERROR: %', SQLERRM;
              GET STACKED DIAGNOSTICS v_error_stack = PG_EXCEPTION_CONTEXT;
              RAISE EXCEPTION 'Error stack: %', v_error_stack;
           WHEN others THEN
              RAISE NOTICE 'ERROR: %', SQLERRM;
              GET STACKED DIAGNOSTICS v_error_stack = PG_EXCEPTION_CONTEXT;
              RAISE EXCEPTION 'Error stack: %', v_error_stack;
           END;
        ELSE
          RAISE NOTICE 'Do not delete table % yet', quote_ident(tablename);
        END IF;
    END LOOP;
RETURN 'OK';

END;

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION delete_partitions(interval, text)
  OWNER TO postgres;

