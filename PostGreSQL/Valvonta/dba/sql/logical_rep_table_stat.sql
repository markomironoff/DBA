SELECT s.subname AS subscription_name,
       c.relnamespace::regnamespace::text as table_schema,
       c.relname as table_name,
       rel.srsublsn,
       case rel.srsubstate 
         when 'i' then 'initialized'
         when 'd' then 'copying'
         when 's' then 'synchronized'
         when 'r' then 'ready'
       end as state
FROM pg_catalog.pg_subscription s
  JOIN pg_catalog.pg_subscription_rel rel ON rel.srsubid = s.oid
  JOIN pg_catalog.pg_class c on c.oid = rel.srrelid;

