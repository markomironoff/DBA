SET LINESIZE 200
COL DESCRIPTION FORMAT A60
COL VERSION FORMAT A15
COL COMP_NAME FORMAT A40
SELECT TO_CHAR(action_time,'YYYY-MM-DD') AS action_time,action,status,description,patch_id FROM dba_registry_sqlpatch ORDER BY action_time DESC;
SELECT comp_id,comp_name,version,status FROM dba_registry;
SELECT owner,object_type,object_name,status FROM dba_objects WHERE status = 'INVALID' ORDER BY owner,object_type,object_name;

/*

Backup $ORACLE_HOME:
tar -pcvf /home/oracle/backup/oracle_home_bck.tar $ORACLE_HOME

Restore $ORACLE_HOME:
tar -pxvf /home/oracle/backup/oracle_home_bck.tar

Backup also the Central Inventory:
how to locate? cat /etc/oraInst.loc

ACTION_TIM ACTION          STATUS                    DESCRIPTION                                                    PATCH_ID
---------- --------------- ------------------------- ------------------------------------------------------------ ----------
2025-10-07 APPLY           SUCCESS                   Database Release Update : 19.28.0.0.250715 (37960098)          37960098
2025-10-06 APPLY           SUCCESS                   Database Release Update : 19.3.0.0.190416 (29517242)           29517242

COMP_ID                        COMP_NAME                                VERSION         STATUS
------------------------------ ---------------------------------------- --------------- --------------------------------------------
CATALOG                        Oracle Database Catalog Views            19.0.0.0.0      VALID
CATPROC                        Oracle Database Packages and Types       19.0.0.0.0      VALID
RAC                            Oracle Real Application Clusters         19.0.0.0.0      OPTION OFF
JAVAVM                         JServer JAVA Virtual Machine             19.0.0.0.0      VALID
XML                            Oracle XDK                               19.0.0.0.0      VALID
CATJAVA                        Oracle Database Java Packages            19.0.0.0.0      VALID
APS                            OLAP Analytic Workspace                  19.0.0.0.0      VALID
XDB                            Oracle XML Database                      19.0.0.0.0      VALID
OWM                            Oracle Workspace Manager                 19.0.0.0.0      VALID
CONTEXT                        Oracle Text                              19.0.0.0.0      VALID
ORDIM                          Oracle Multimedia                        19.0.0.0.0      VALID

COMP_ID                        COMP_NAME                                VERSION         STATUS
------------------------------ ---------------------------------------- --------------- --------------------------------------------
SDO                            Spatial                                  19.0.0.0.0      VALID
XOQ                            Oracle OLAP API                          19.0.0.0.0      VALID
OLS                            Oracle Label Security                    19.0.0.0.0      VALID
DV                             Oracle Database Vault                    19.0.0.0.0      VALID

*/