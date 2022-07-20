-- The MIT License (MIT)
-- SchroedingerDB
-- Copyright @ 2021 Robert Baric, ITGAIN Consulting Gesellschaft fuer IT-Beratung mbH

-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

-- Filename:    schroedingerDB.sql (Schroedingers Database)
-- Version:     20220720
    
-- Purpose:
-- Scripts to gather information about database usage to answer the questions
-- 1) is the database in use?
-- 2) when has someone changed data on a non-oracle maintained schema?
-- 3) when has someone logged in last time ?
-- 4) Does jobs and triggers exist that may change data ?
-- "Sometimes you need to see inside the database to tell if it is alive or dead"

-- Prerequisites 
-- 1. procedure hasDiagPack checks if use of Diagnostic Pack is enabled. 
--    You may disable use of Diagnostic Pack permanently if you do not have a proper licence by setting variable disableDiagPack to 1 
-- 2. Supported RDBMS Version from 12.1 on
-- 3. connect with a user with read permission on dba views and v$instance, v$database
--
--              sqlplus -S / as sysdba @schroedingerDB  [<Report Mode> [<Schema Name> [<Output-Mode>] ] ] 
--              sqlplus -S <user>/<pass>@DB @schroedingerDB [<Report Mode> [<Schema Name> [<Output-Mode>] ] ]
-- Example:     sqlplus -S <user>/<pass>@DB @schroedingerDB <-- Run with defaults "N % 1023" : Nude Mode with all User Tables 
--              sqlplus -S <user>/<pass>@DB @schroedingerDB <-- show help 
-- use pipe to export to file
-- Example:
-- sqlplus / as sysdba HR N > result.txt

COLUMN 1 new_value 1
column 2 new_value 2
column 3 new_value 3

set verify off
set feedback off
set termout off
set lin 180
select 1024 "1", '%' "2", 10 "3" from dual where rownum=0;
set serveroutput on
set termout on
set pagesize 300
column Date format a20
column Day format a5
column "01" format 9999
column "02" format 9999
column "03" format 9999
column "04" format 9999
column "05" format 9999
column "06" format 9999
column "07" format 9999
column "08" format 9999
column "09" format 9999
column "10" format 9999
column "11" format 9999
column "12" format 9999
column "13" format 9999
column "14" format 9999
column "15" format 9999
column "16" format 9999
column "17" format 9999
column "18" format 9999
column "19" format 9999
column "20" format 9999
column "21" format 9999
column "22" format 9999
column "23" format 9999

DECLARE
    disableDiagPack    constant number :=0; -- 1 to disable    
    da_format          VARCHAR2(30) := 'DD.MM.YYYY HH24:MI:SS';
    ts_format          VARCHAR2(30) := 'DD.MM.YYYY HH24:MI:SS';
    ts_length          CONSTANT NUMBER := 22;
    isparaok           NUMBER(1);
    c_sep              CONSTANT CHAR := '-';
    v_last_schema      varchar2(32) default 'initial';
    v_last_table       VARCHAR2(32) default 'init-table';
    v_last_table_time  timestamp;
    v_last_tabmod_time timestamp;
    v_last_tabmod_schema varchar2(32) default 'inital_schema';
    v_last_tabmod_table varchar2(32) default 'inital_table';
    v_testnum          NUMBER;
    p_schema           VARCHAR2(100) := nvl('&2','%') ; 
    p_mode             CHAR(1) := 'N';
    p_out              number(10,0) := nvl('&1',0);   
    
    
    c_no_debug constant number  :=0;
    v_debug number:=c_no_debug; -- default no debug output
    
    v_limit_login_days NUMBER := 32;
    v_limit_table_days NUMBER := nvl('&3',30) ; 
    
    v_min_orascn number; --Filled by later defined function -> lowest archivelog scn; 
    v_min_archTime timestamp; -- Filled by later defined function -> lowest archivelog time;
    
    c_maxTabMods constant number:=10;
    c_debug_simple constant number:=1;
    c_debug_moderate constant number:=2;
    c_debug_detailed constant number:=3;
    
    o_luser            dba_users.username%TYPE;
    o_ltime            dba_users.last_login%TYPE;
   
    c_out_help constant number :=0; -- Help Page 
    c_out_dbinfo constant number := 1 ; --DB Info
    c_out_tabmod constant number :=2; --TabMOD
    c_out_orascn constant number :=4; -- ORASCN
    c_out_orascn_F constant number :=8; -- ORASCN Fast Mode
    c_out_orascn_S constant number :=16; -- ORASCN Summary Mode
    c_out_orascn_D constant number :=32; -- ORASCN Detailed Mode
    c_out_connSessions constant number :=64; -- Connected USER Sessions
    c_out_LAST_ACTIONS constant number :=128 ; -- Last Action 
    c_out_jobs constant number := 256 ; --List Jobs (TODO)
    c_out_triggers constant number :=512; -- Triggers 
    c_out_freqMap constant number := 4096; -- Frequency Map (TODO)
    c_out_logThroug constant number := 8192; -- 256 Log Throughput (TODO)
    c_out_logfreq constant number := 16384; --Log Freq Calculation (TODO)
    
    --# Standart Output Text, otherwise
    c_out_checkMK constant number :=1024; -- CheckMK Output ONLY
    c_out_HTML  constant number :=2048; -- HTML Output (TODO)
    c_out_debug_simple constant number :=32768;
    c_out_debug_moderate constant number :=65536;
    
    starttime timestamp default current_timestamp;
    diffRun interval day to second;
    
    function isDebug(modus in number) return boolean
    is
     ret boolean default false;
    begin
     if modus>c_no_debug and modus<=v_debug then
      ret:=true;
     end if;
     return ret;
    end isDebug;

    function isDebug return boolean
    is
    begin
     return isDebug(c_debug_simple);
    end;
    
    function isBitAnd(para in number, const in number) return boolean
    is
    ret boolean default false;
    begin
     if bitand(para,const)=const then
      ret:=true;
    end if;
    return ret;
    end isBitAnd;
    
    -- Default isBitAnd p_pout
    function isOut (const in number) return boolean is
    begin
    return isBitAnd(p_out,const);
    end ;
    
    function time_to_arch_scn (ts timestamp) return number
    is
     arc_scn number;
    begin 
      begin 
       select first_change# into arc_scn From v$archived_log where ts between first_time and next_time fetch first 1 row only;
      exception
       when others then
        null;
      end; 
     return arc_scn;
   end;

function ret_last_arch_scn return number 
is 
 first_chg# number;
begin
 select min(first_change#) into first_chg# from v$archived_log;
 return first_chg#;
end;

function ret_last_arch_time return timestamp 
is 
 first_ts timestamp;
begin
 select min(first_time) into first_ts from v$archived_log;
 return first_ts;
end;
   
  function arch_scn_to_time(archscn number) return timestamp 
   is 
   ret timestamp;
  begin 
   begin
     ret:=scn_to_timestamp(archscn);
     exception when others then
      begin 
      select first_time into ret from v$archived_log where archscn between first_change# and next_change# order by first_time desc fetch first 1 row only;
      exception when others then 
       ret:=null; -- ret_last_arch_time; --current_timestamp- interval '120' hour; -- minimum arch to timestamp interval
       if isDebug(c_debug_moderate) then dbms_output.put_line('SCN to timestamp conversation failed, scn '||archscn||' out of scope'); end if;
       null;
      end;
   end;
   return ret;
  end;

    function checkparameters (
        v_user  IN VARCHAR2,
        v_para  IN CHAR,
        testnum OUT NUMBER
    ) return boolean IS
        tt  all_users.username%TYPE;
        anz NUMBER;
        err NUMBER := 0;
        c_lpad constant number :=7;
        c_rpad constant number :=48;
        ret boolean := false;
    BEGIN
        SELECT
            COUNT(*)
        INTO anz
        FROM
            dba_users
        WHERE
            username LIKE v_user
            AND oracle_maintained = 'N';

        IF anz = 0 THEN
            err := 1;
            dbms_output.put_line('-');
            dbms_output.put_line('Username(s) '
                                 || v_user
                                 || ' do(es) not exist or is oracle maintained');
            dbms_output.put_line('-');
        END IF;

        IF v_para NOT IN ( 'S', 'D', 'N', 'F' ) THEN
            err := 2;
        END IF;

        if p_out=0 or err>2 then 
            dbms_output.put_line('use sqlplus -S / as sysdba @schroedingerDB <Output Mode> [<Username> [<SCN check days back>]]');
            dbms_output.put_line('_ ');
            
            dbms_output.put_line('Output Modes:');
            dbms_output.put_line(rpad('Help',c_rpad)||lpad(c_out_help,c_lpad)  );
            dbms_output.put_line(rpad('DB Information',c_rpad)||lpad(c_out_dbinfo,c_lpad)  );
            dbms_output.put_line(rpad('TAB_MOD',c_rpad)||lpad(c_out_tabmod,c_lpad ) );
            dbms_output.put_line(rpad('RowSCN exit first changed table (days back limit)',c_rpad)||lpad(c_out_orascn,c_lpad)  );
            dbms_output.put_line(rpad('RowSCN each schema first changed table',c_rpad)||lpad(c_out_orascn_f,c_lpad)  );
            dbms_output.put_line(rpad('RowSCN each table (days back limit)',c_rpad)||lpad(c_out_orascn_s,c_lpad ) );
            dbms_output.put_line(rpad('RowSCN last change on every table (full scan)',c_rpad)||lpad(c_out_orascn_d,c_lpad) );
            dbms_output.put_line(rpad('Connected Users Sessions',c_rpad) || lpad(c_out_connSessions,c_lpad ));
            dbms_output.put_line(rpad('LAST ACTIONS',c_rpad) ||lpad(c_out_LAST_ACTIONS,c_lpad) );
            dbms_output.put_line(rpad('Jobs',c_rpad) ||lpad(c_out_jobs,c_lpad) );
            dbms_output.put_line(rpad('Triggers',c_rpad)||lpad(c_out_triggers,c_lpad) );
            dbms_output.put_line(rpad('CheckMK Output only',c_rpad)||lpad(c_out_checkMK,c_lpad) );
            dbms_output.put_line(rpad('Log Frequency Map',c_rpad)||lpad(c_out_freqMap,c_lpad) );
	    dbms_output.put_line(rpad('Debug mode',c_rpad) || lpad(c_out_debug_simple,c_lpad ));
            dbms_output.put_line('- ');
            dbms_output.put_line('Add numbers of output modes to switch on multipe outputs');
            dbms_output.put_line('Only highest RowSCN output is used');
            dbms_output.put_line('- ');

            ret:=true; 
        END IF;

        IF v_para NOT IN ( 'N', 'F' ) THEN
            testnum := 1;
        ELSE
            testnum := 0;
        END IF;

        return ret;

    END checkparameters;

    PROCEDURE printheader IS
        v_datform CONSTANT VARCHAR2(64) := 'DD.MM.YY HH24:MI:SS';
    BEGIN
        dbms_output.put_line('+---------------------------+');
        dbms_output.put_line('|  SCHROEDINGERS DATABASE   | now it is');
        dbms_output.put_line('|  Is the database in use?  | ' || to_char(sysdate, v_datform));
        dbms_output.put_line('+---------------------------+-------------------+');
    END printheader;
    
    -- (not working yet)
    procedure listJobs is
    begin
        dbms_output.put_line('.'); 
        dbms_output.put_line(' --------------------------------------------');
        dbms_output.put_line(' List Jobs for non-Oracle maintained users   ');
        dbms_output.put_line('--------------------------------------------');
        
        dbms_output.put_line('.'); 
        dbms_output.put_line(rpad('jobNr', 7)||rpad('Log User',20)||rpad('Priv User',20)||rpad('Schema',20)||rpad('Next Date',24)||rpad('Broken',8)||rpad('Total Time',24)||rpad('Last Date',24) );
        for x in (select job,j.LOG_USER,priv_user,schema_user,to_char(j.NEXT_DATE,da_format) NEXT_DATE ,j.BROKEN , j.TOTAL_TIME,to_char(j.LAST_DATE,da_format) LAST_DATE from  dba_jobs j
where schema_user  in (select username from dba_users where ORACLE_MAINTAINED='N' )
order by last_date desc nulls last  ) loop
        
        dbms_output.put_line(rpad(x.job,7)||rpad(x.log_user,20) );
         
       end loop;


        dbms_output.put_line('.'); 
        dbms_output.put_line(rpad('Enabled', 9)||rpad('Job Name',30)||rpad('Job Type',20)||rpad('Schema',20)||rpad('Next Date',24)||rpad('Broken',8)||rpad('Total Time',24)||rpad('Last Date',24) );
      for y in (  SELECT j.ENABLED,j.JOB_NAME, j.JOB_TYPE,j.RUN_COUNT,j.FAILURE_COUNT,j.MAX_RUN_DURATION,j.LAST_START_DATE
    FROM DBA_SCHEDULER_JOBS j
   WHERE owner IN (SELECT username
                     FROM dba_users
                    WHERE ORACLE_MAINTAINED = 'N') ORDER BY enabled DESC, LAST_START_DATE DESC)
    loop


        dbms_output.put_line(rpad(y.enabled,9)||rpad(y.job_name,30)||rpad(y.job_type,20)||rpad(y.run_count,14)||rpad(y.failure_count,12)||rpad(y.max_run_duration,24)||rpad(y.last_start_date,24) );
    end loop;
     end listJobs;

    PROCEDURE lastactions IS
    BEGIN
        dbms_output.put_line(' --------------------------------------------');
        dbms_output.put_line(' Last DB Actions non oracle maintained users ');
        dbms_output.put_line('--------------------------------------------');
        dbms_output.put_line(rpad('USERNAME', 25)
                             || rpad('Last Execution', ts_length)
                             || rpad('First Execution', ts_length)
                             || lpad('#', 10)
                             || '  '
                             || rpad('Object Name', 35)
                             || lpad('Object Type', 12)
                             || lpad('SQL Opname', 12));

        FOR x IN (
            SELECT
                username,
                sql_opname,
                MAX(sample_time) last_execution,
                MIN(sample_time) first_execution,
                COUNT(*)         anz,
                o.object_name,
                object_type
            FROM
                dba_hist_active_sess_history h
                LEFT OUTER JOIN dba_objects                  o ON ( h.current_obj# = o.object_id )
                JOIN (
                    SELECT
                        user_id,
                        username
                    FROM
                        dba_users
                    WHERE
                        oracle_maintained = 'N'
                )                            u ON ( u.user_id = h.user_id )
            GROUP BY
                username,
                sql_opname,
                object_name,
                object_type                
            ORDER BY
                last_execution DESC,
                username
            FETCH FIRST 20 ROWS ONLY
        ) LOOP
            dbms_output.put_line(rpad(x.username, 25)
                                 || rpad(x.last_execution, ts_length)
                                 || rpad(x.first_execution, ts_length)
                                 || lpad(x.anz, 10)
                                 || '  '
                                 || rpad(x.object_name, 35)
                                 || lpad(x.object_type, 12)
                                 || lpad(x.sql_opname, 12) );
        END LOOP;

    END lastactions;

    procedure logFreqMap(days in number) is
    cur sys_refcursor;
    begin
      dbms_output.put_line('Log Frequency Map');
      dbms_output.put_line('-----------------');
      dbms_output.put_line('.');

    
    open cur for 
 with xx as (
 SELECT trunc (first_time) "Date",
 to_char (trunc (first_time),'Dy') "Day",
 --to_char(first_time,'DD.MM.YYYY') datum,
 to_char (FIRST_TIME, 'HH24') hours,
 1 cal
 from v$log_history
 where trunc (first_time) >= (trunc(sysdate) - interval '14' day)
 )
 select *  from xx 
 pivot  (sum(cal) for hours in ('00' as "00",'01' as "01",'02' as "02",'03' as "03",'04' as "04",'05' as "05",'06' as "06",'07' as "07",'08' as "08",'09' as "09",'10' as "10",'11' as "11",'12' as "12",'13' as "13",'14' as "14",'15' as "15",'16' as "16",'17' as "17",'18' as "18",'19' as "19",'20' as "20",'21' as "21",'22' as "22",'23' as "23") ) 
 order by 1 desc;
 
 --with y as (select trim(to_char(level-1,'00'))  as lev from dual connect by level<25 ),
 --z as (select ''''||lev||''' as "'||lev||'"' tx from y)
 --select listagg(tx,',') within group (order by tx) from z 
 -- ) ;
  dbms_sql.return_result(cur);
    
end logFreqMap;

    PROCEDURE generaldbinfo IS

        i_con_id      INTEGER;
        v_db_name     VARCHAR2(64);
        v_pdb_name    VARCHAR2(64);
        v_open_mode   VARCHAR2(64);
        d_created     DATE;
        v_db_unq_name VARCHAR2(64);
        v_cdb         VARCHAR2(64);
        v_hostname    VARCHAR2(256);
        i_inst_id     INTEGER;
        v_inst_name   VARCHAR2(64);
        d_startup     DATE;
        v_status      VARCHAR2(64);
        v_logins      VARCHAR2(64);
        v_shut_pend   VARCHAR2(64);
        v_db_status   VARCHAR2(64);
        v_inst_role   VARCHAR2(64);
        v_act_state   VARCHAR2(64);
        v_blocked     VARCHAR2(64);
        v_inst_mode   VARCHAR2(64);
        v_datform     CONSTANT VARCHAR2(64) := 'DD.MM.YY HH24:MI:SS';
        v_log_mode    v$database.log_mode%TYPE;
        i             INTEGER := 0;
    BEGIN
        SELECT
            name,
            open_mode,
            created,
            db_unique_name,
            cdb,
            con_id,
            log_mode
        INTO
            v_db_name,
            v_open_mode,
            d_created,
            v_db_unq_name,
            v_cdb,
            i_con_id,
            v_log_mode
        FROM
            v$database;

        SELECT
            host_name,
            instance_number,
            instance_name,
            database_status,
            instance_role,
            active_state,
            blocked,
            instance_mode,
            startup_time,
            status,
            logins,
            shutdown_pending,
            database_status,
            instance_role,
            active_state,
            blocked,
            instance_mode
        INTO
            v_hostname,
            i_inst_id,
            v_inst_name,
            v_status,
            v_inst_role,
            v_act_state,
            v_blocked,
            v_inst_mode,
            d_startup,
            v_status,
            v_logins,
            v_shut_pend,
            v_db_status,
            v_inst_role,
            v_act_state,
            v_blocked,
            v_inst_mode
        FROM
            v$instance;

        SELECT
            COUNT(*)
        INTO i
        FROM
            v$pdbs;

        IF i = 1 THEN
            SELECT
                con_id,
                name
            INTO
                i_con_id,
                v_pdb_name
            FROM
                v$pdbs;

        ELSE
            v_pdb_name := NULL;
        END IF;

        IF v_pdb_name IS NOT NULL THEN
            dbms_output.put_line('|  PDB-Name....: '
                                 || rpad(v_pdb_name
                                         || ' ('
                                         || i_con_id
                                         || ')', 31)
                                 || '|');

            dbms_output.put_line('+-----------------------------------------------+');
        END IF;

        dbms_output.put_line('|  Hostname....: '
                             || rpad(v_hostname, 31)
                             || '|');
        dbms_output.put_line('|  DB-Name.....: '
                             || rpad(v_db_name, 31)
                             || '|');
        dbms_output.put_line('|  DB-Unq.Name.: '
                             || rpad(v_db_unq_name, 31)
                             || '|');
        dbms_output.put_line('|  Instance....: '
                             || rpad(v_inst_name
                                     || ' ('
                                     || i_inst_id
                                     || ')', 31)
                             || '|');

        dbms_output.put_line('|  Inst. Role..: '
                             || rpad(v_inst_role, 31)
                             || '|');
        dbms_output.put_line('|  Inst. Mode..: '
                             || rpad(v_inst_mode, 31)
                             || '|');
        dbms_output.put_line('|  Active state: '
                             || rpad(v_act_state, 31)
                             || '|');
        dbms_output.put_line('|  DB-Status...: '
                             || rpad(v_status, 31)
                             || '|');
        dbms_output.put_line('|  Blocked.....: '
                             || rpad(v_blocked, 31)
                             || '|');
        dbms_output.put_line('|  Open mode...: '
                             || rpad(v_open_mode, 31)
                             || '|');
        dbms_output.put_line('|  Log mode....: '
                             || rpad(v_log_mode, 31)
                             || '|');
        dbms_output.put_line('|  Creationdate: '
                             || to_char(d_created, v_datform)
                             || '              |');
        dbms_output.put_line('|  Startdate...: '
                             || to_char(d_startup, v_datform)
                             || '              |');
        dbms_output.put_line('|  Min ArchTime: '
                             || to_char(v_min_archTime , v_datform)                            
                             || '              |');
        dbms_output.put_line('|  Min Arch SCN: '
                             || rpad(v_min_orascn,31 )                            
                             || '|');                                                          
        dbms_output.put_line('+-----------------------------------------------+');
    END;

    PROCEDURE connected_sessions IS
     num_sess number default 0;
    BEGIN
        dbms_output.put_line('');
        dbms_output.put_line(' ----------------------------------------------');
        dbms_output.put_line(' User Sessions for non oracle maintained users ');
        dbms_output.put_line(' ----------------------------------------------');
        dbms_output.put_line('');
        dbms_output.put_line(lpad('Username', 20)
                             || lpad('#', 10));

        dbms_output.put_line(lpad(' ', 33, c_sep));
        FOR x IN (
            SELECT
                username,
                COUNT(*) sessions
            FROM
                v$session
            WHERE
                username IN (
                    SELECT
                        username
                    FROM
                        all_users u
                    WHERE
                        u.oracle_maintained = 'N'
                )
            GROUP BY
                username
        ) LOOP
            dbms_output.put_line(lpad(x.username, 20)
                                 || '  '
                                 || lpad(x.sessions, 10));
                                 num_sess :=num_sess+x.sessions;
        END LOOP;
        dbms_output.put_line(lpad(' ', 33, c_sep));
        dbms_output.put_line(lpad('Sum', 20)
                                 || '  '
                                 || lpad(num_sess, 10));
        
        dbms_output.put_line('');
    END connected_sessions;

    PROCEDURE list_triggers (
        v_schema IN VARCHAR2
    ) IS
    BEGIN
        dbms_output.put_line('');
        dbms_output.put_line('----------------------------------');
        dbms_output.put_line('  Trigger on Schema ' || v_schema);
        dbms_output.put_line('----------------------------------');
        dbms_output.put_line('');
        dbms_output.put_line(lpad('Trigger Type', 30)
                             || lpad('Triggering_Event', 30)
                             || '  '
                             || rpad('#', 10));

        dbms_output.put_line(lpad(' ', 64, c_sep));
        FOR x IN (
            SELECT
                trigger_type,
                triggering_event,
                COUNT(*) anz
            FROM
                dba_triggers t
            WHERE
                owner = v_schema
            GROUP BY
                trigger_type,
                triggering_event
            ORDER BY
                COUNT(*) DESC
            fetch first c_maxTabMods rows only    
        ) LOOP
            dbms_output.put_line(lpad(x.trigger_type, 30)
                                 || lpad(x.triggering_event, 30)
                                 || '  '
                                 || rpad(x.anz, 10));
        END LOOP;

    END;


   --# Check: Modification query is sensitive to changed statistics
   PROCEDURE list_tab_mod (
        v_schema IN VARCHAR2,
        daysback IN NUMBER,
        last_time in out timestamp,
        last_schema in out varchar2,
        last_table in out varchar2        
    ) IS
    anyData number:=0;
    procedure header as 
    BEGIN
        dbms_output.put_line('');
        dbms_output.put_line(' -------------------------------------------- ');
        dbms_output.put_line(' TAB_MODIFICATIONS for Schema ' || v_schema);
        dbms_output.put_line('-------------------------------------------- ');
    end;
    begin
        FOR x IN (
            SELECT
                s.table_name,
                SUM(inserts)                                   inserts,
                SUM(t.updates)                                 updates,
                SUM(t.deletes)                                 "DELETES",
                MAX(t.timestamp) ts,
                MAX(s.last_analyzed)   max_last_analyzed
            FROM
                all_tab_modifications t
                RIGHT OUTER JOIN all_tab_statistics    s ON ( s.owner = t.table_owner
                                                           AND s.table_name = t.table_name )
            WHERE
                    s.owner = v_schema
                AND ( timestamp IS NOT NULL
                      OR last_analyzed > sysdate - daysback )
            GROUP BY
                s.table_name
            ORDER BY
                MAX(t.timestamp) DESC
            fetch first c_maxTabMods rows only
        ) LOOP
        if last_time is null or x.ts<last_time then
         last_time:=x.ts;
         last_schema:=v_schema;
         last_table:=x.table_name;
        end if;
        if anyData=0 then anyData:=1; header(); end if;
            dbms_output.put_line(lpad(x.table_name, 30)
                                 || lpad(x.inserts, 14)
                                 || lpad(x.updates, 14)
                                 || lpad(x.deletes, 14)
                                 || lpad(to_char(x.ts, ts_format), 22)
                                 || lpad(to_char(x.max_last_analyzed, ts_format ), 22) );
        END LOOP;
       if anyData=0 then 
          dbms_output.put_line('No TAB_MODIFICATIONS entry for Schema ' || v_schema);
       else 
          dbms_output.put_line('---'); 
       end if;
    END;

procedure last_login ( v_luser out dba_users.username%type,  v_ltime out dba_users.last_login%type) 
is
begin
dbms_output.put_line('----------------------------------------');
dbms_output.put_line(' Last Login non oracle maintained users');
dbms_output.put_line('----------------------------------------');
dbms_output.put_line('');
dbms_output.put_line(lpad('Username',30)||lpad('Created',22)||lpad('Last Logins',22));
for x in (
select username,to_char(created,'DD.MM.YYYY HH24:MI') created,to_char(d.LAST_LOGIN,'DD.MM.YYYY HH24:MI') LAST_LOGINs
from  dba_users d
where d.ORACLE_MAINTAINED='N' and last_login is not null
order by last_login desc ) loop
 if v_luser is null then 
  v_luser:=x.username;
  v_ltime:=x.last_logins;
 end if;
 dbms_output.put_line(lpad(x.username,30)||lpad(x.created,22)||lpad(x.LAST_LOGINs,22) );
end loop;

end;

/* Converts SCN to Timestamp (scn_to_timestamp based */
function scn2TS(xscn number) return timestamp 
is
 scnts timestamp;
begin
   begin
    scnts:=SCN_TO_TIMESTAMP(xscn);
   exception when others then
    scnts:=null;
   end;
  return scnts;
end scn2TS;
 


procedure orascn(v_schema in varchar2,v_para in char, testnum in number,last_table_time in out varchar2, last_table in out varchar2, last_schema in out varchar2 ) is
type typ_rec is record (
   schema_name all_tables.owner%type,
   table_name all_tables.table_name%type,
   orascn number,
   scnts timestamp
 );

 type t_rec is table of typ_rec ;
  xx typ_rec;
  rec t_rec := t_rec();
  scnts timestamp;  
  num_tabs number;
  sum_blocks number;
  cur_tab number :=0;
  cur_block number :=0;
  start_time timestamp default current_timestamp;
  diffInterval interval day(4) to second;
  secs number;
  blk_s number;

PROCEDURE BubbleSort( coll IN OUT TYP_REC) AS
sorted number:=0;
BEGIN
 loop
  sorted:=0;
 for s in 2..rec.count loop
  if rec(s-1).orascn<rec(s).orascn then
  --# Switch Records
   sorted:=1;
   coll:=rec(s);
   rec(s):=rec(s-1);
   rec(s-1):=coll;
  end if;
  end loop;
 exit when sorted=0;
 end loop;
END;
begin
 
 if testNum=1 then
  dbms_output.put_line('--------------------------------');
  dbms_output.put_line('ORA_ROWSCN Report for schema '||v_schema);
  dbms_output.put_line('--------------------------------');
  dbms_output.put_line('.');
 end if;
 select count(*) into num_tabs from  all_tables where owner like v_schema and owner in (select username from dba_users where oracle_maintained='N');
 select sum(blocks) into sum_blocks from  all_tables where owner like v_schema and owner in (select username from dba_users where oracle_maintained='N');
 --# scan tables for convertible ora_rowscn, start with small tables
 for i in (select * from  dba_tables where owner like v_schema and owner in (select username from dba_users where oracle_maintained='N') order by blocks asc  ) loop
 xx.table_name:=i.table_name;
 xx.schema_name:=i.owner;
 cur_tab:=cur_tab+1;
 --# Calc Time to run
 diffInterval:=current_timestamp-start_time;
 if interval '5' second <diffInterval and (cur_tab>1 and cur_tab<num_tabs and cur_block>0 and sum_blocks>0) then
  diffinterval:=diffinterval/cur_block*sum_blocks;
  secs:=extract (day from diffInterval)*60*60*24+extract(hour from diffInterval)*60*60+extract(minute from diffInterval)*60+trunc(extract(second from diffInterval));
  blk_s:=round(cur_block/secs);
   dbms_application_info.set_client_info('Block '||cur_block||' of '||sum_blocks||',ETA: -'||extract(day from diffInterval)||' '||trim(to_char(extract(hour from diffInterval),'09'))||':'||trim(to_char(extract(minute from diffInterval),'09'))||':'||trim(to_char(trunc(extract(second from diffInterval)),'09'))||' blk/s: '||blk_s );
 end if;
 cur_block:=cur_block+i.blocks;
 dbms_application_info.set_Module(i.owner||'.'||i.table_name,'Blocks: '|| i.blocks||', '||cur_tab||' of '||num_tabs);
 begin
  if v_para in ('D') then 
   --execute immediate 'select max(ora_rowscn) from '||i.owner||'.'||i.table_name ||' where ora_rowscn>=:1 ' into xx.orascn using v_min_orascn ;  -- into xx.orascn;
   execute immediate 'select max(ora_rowscn) from '||i.owner||'.'||i.table_name into xx.orascn ;  
  else 
   if v_para in ('S','F','N') then
  --# Select fist match ?
   execute immediate 'select ora_rowscn from '||i.owner||'.'||i.table_name||' where ora_rowscn>=:1 fetch first 1 row only' into xx.orascn using v_min_orascn ;  
   end if;
  end if;
  xx.scnts:=arch_scn_to_time(xx.orascn);
  if isDebug() then 
   dbms_output.put_line('Tabelle '||i.owner||'.'||i.table_name||' changed at scn '||xx.orascn||' which is converts to '||nvl(xx.scnts,'unknown time') );
  end if;
  exception when others then
    --dbms_output.put_line('Error on Table '||i.table_name||' with error '||sqlerrm );
    if isDebug(1) then dbms_output.put_line('No data change on Table '||i.owner||'.'||i.table_name||' using scn '||xx.orascn||' since time conversation limit '|| v_min_archTime); end if; 
 end;

  --# Nicht nötig, wenn nicht max(orascn)
  if xx.scnts is not null then
   rec.extend;
   rec(rec.count):=xx;
  end if;
  if v_para IN ('F','N') and xx.scnts is not null then exit; end if; -- exit after first hit
 
  end loop;
 --# Simple Sort by plsql desc
 if rec.count>1 then
  BubbleSort(XX);
 end if;

 if rec.count>0 then
 --# save Var for final report
  if v_para in ('S','D' ) then
   dbms_output.put_line('There were '||rec.count||' table(s) found with changes within given time on schema '||v_schema);
  else 
   dbms_output.put_line('Last changed Table '||rec(1).table_name||' on schema '||rec(1).schema_name||' at '||rec(1).scnts);
  end if;
  --last_table:= rec(1).table_name;
  if rec(1).scnts is not null and (last_table_time is null or last_table_time<rec(1).scnts ) then
    last_table_time := rec(1).scnts; --to_char(rec(1).scnts,'DD.MM.YYYY HH24:MI:SS');
    last_table := rec(1).table_name;
    last_schema := rec(1).schema_name;
    if isDebug(c_debug_simple) Then 
      dbms_output.put_line('New Last Table: '||last_schema||'.'||last_table||' changed at '||last_table_time );
    end if;
  end if;
 else
    if isDebug(c_debug_simple) then 
      dbms_output.put_line('There were NO timestamps for tables found on schema '||v_schema);
    end if;
 end if;
 --# Output Report for Each ?
 
  --if v_para<>'N' then dbms_output.put_line('Tables with Timestamp values: '||rec.count); end if;
  if v_para in ('S','D') then
   if rec.count>0 then
    dbms_output.put_line('Last  changed Table '||rec(1).table_name||' at '||rec(1).scnts);
    dbms_output.put_line('First changed Table '||rec(rec.count).table_name||' at '||rec(rec.count).scnts);
   else
    if isDebug(c_debug_simple) then 
     dbms_output.put_line('No Tables with SCN convertible to a timestamp in schema '||v_schema);
    end if;
   end if;
  else
    if v_para='D' and rec.count>0 then
      for j in 1..rec.count loop
        dbms_output.put_line(rec(j).orascn||':: '||rec(j).table_name||' '||rec(j).scnts);
      end loop;
    end if;
  end if;
  
end orascn;


procedure final_results(v_schema in varchar2) is

cursor c_ll is select username,to_char(d.LAST_LOGIN,'DD.MM.YYYY HH24:MI') LAST_LOGINs, last_login
from  dba_users d
where d.ORACLE_MAINTAINED='N' and last_login is not null
order by last_login desc nulls last;

cursor c_tm is select table_owner,table_name,to_char(TIMESTAMP,ts_format) ts
from  DBA_TAB_MODIFICATIONS  where table_owner like v_schema and table_owner in (select username from dba_users where oracle_maintained='N') and timestamp is not null
order by timestamp desc;

v_user all_users.username%TYPE;
v_login_date dba_users.last_login%TYPE;
v_llogin varchar2(32);
v_schema1 varchar2(32);

v_table_tm DBA_tab_modifications.table_name%TYPE;
v_ts_tm varchar2(32);
v_c_tr number;
v_c_sj number;
v_c_j number;

-- based tab_modifications
begin
 dbms_output.put_line('');
 dbms_output.put_line('--------------------');
 dbms_output.put_line('FINAL RESULTS');
 dbms_output.put_line('--------------------');
 dbms_output.put_line('.');


 open c_ll;
 fetch c_ll into v_user, v_llogin,v_login_date;
 close c_ll;

 select count(*) into v_c_tr from all_triggers where owner in (select username from all_users where ORACLE_MAINTAINED='N'  and username like v_schema);
 select count(*) into v_c_j from all_jobs where schema_user  in (select username from all_users where ORACLE_MAINTAINED='N' );
 select count(*) into v_c_sj from all_scheduler_jobs where owner in (select username from all_users where ORACLE_MAINTAINED='N' );

 if v_llogin is not null then
 dbms_output.put_line('Last login was by user '||v_user||' at '||v_llogin);
 dbms_output.put_line('');
 else
  dbms_output.put_line('There was no login by non-oracle maintained users');
 end if;
 if v_login_date>sysdate-v_limit_login_days then
  dbms_output.put_line('Database IS IN USE based on login time');
 else
  dbms_output.put_line('Database _Seems_ NOT IN USE based on login time');
 end if;
 if v_last_table_time is not null and v_last_table_time>sysdate-v_limit_table_days then
  dbms_output.put_line('Database IS IN USE based orascn of a table ');
 end if;
 

 open c_tm;
 fetch c_tm into v_schema1,v_table_tm,v_ts_tm;
 close c_tm;
 
 if v_ts_tm is not null and v_ts_tm>sysdate-v_limit_table_days  then
  dbms_output.put_line('Database IS IN USE based on a tab_modification time of a table ');
 end if;


 dbms_output.put_line('.');
 -- based orascn
 --if :last_table is not null then
 -- dbms_output.put_line('Last DB write schema '||v_last_schema||' was on table '||v_last_table||' at '||v_last_table_time);
 --end if;

 --if to_timestamp(v_last_table_time,'DD.MM.YYYY HH24:MI:SS')>sysdate-v_limit_table_days then
 --if v_last_table_time>sysdate-v_limit_table_days then
 if v_last_table_time is not null then
  dbms_output.put_line('Database was changed based on row/block scn changing table '||v_last_schema||'.'||v_last_table ||' at '||v_last_table_time);
 end if;

 if v_ts_tm is not null then
  dbms_output.put_line('Database was changed based on tab_modifications changing table '||v_schema1||'.'||v_table_tm||' at '||v_ts_tm);
 end if;

dbms_output.put_line('.');

 if v_c_tr>0 then
  for ss in (select owner,count(*) from all_triggers 
 where owner in (select username 
 from all_users where ORACLE_MAINTAINED='N'  and username like v_schema )group by owner ) loop
  dbms_output.put_line('There are triggers on schema '||ss.owner||' that change tables');
end loop;
 else
  dbms_output.put_line('There are NO triggers on schema '||v_schema);
 end if;

 if v_c_j>0 then
  dbms_output.put_line('There are non-oracle maintained jobs that might change data');
 end if;
 if v_c_sj>0 then
  dbms_output.put_line('There are non-oracle maintained scheduler jobs that might change data');
 end if;

dbms_output.put_line('.');

end final_results;


function hasDiagPack return boolean is
 v_diagpack varchar2(64);
 ret boolean := false;
BEGIN
    if disableDiagPack=0 then
     SELECT
         value
     INTO v_diagpack
     FROM
         v$parameter
     WHERE
        name = 'control_management_pack_access';

     IF instr(upper(v_diagpack), 'DIAGNOSTIC') > 0 THEN
         ret := true;
     END IF;
   
   end if;

    RETURN ret;
END hasDiagPack;


procedure checkMK1 is
 ll_user dba_users.username%type;
 ll_time dba_users.last_login%type;
 ll_ts DBA_TAB_MODIFICATIONS.timestamp%type;
 ll_owner DBA_TAB_MODIFICATIONS.table_owner%type;
 ll_tname DBA_TAB_MODIFICATIONS.table_name%type;
 diff number;
 err2 number :=0;
begin
 -- Last Login
 select username,last_login into ll_user,ll_time
 from  dba_users d
 where d.ORACLE_MAINTAINED='N' and last_login is not null
 order by last_login desc nulls last fetch first 1 row only;
 
 -- Last Change Table base 
 begin 
 select table_owner,table_name,TIMESTAMP into ll_owner,ll_tname,ll_ts 
 from  DBA_TAB_MODIFICATIONS  where table_owner like p_schema and 
 table_owner in (
 select username  from  dba_users d where d.ORACLE_MAINTAINED='N' )
 and timestamp is not null
 order by timestamp desc fetch first 1 row only;
 exception when others then
   err2:=1; 
 end;
 
 --# How should we measure time? days, hours, minutes since last login? -> let's take hours
 diff:=round((current_date-cast(ll_time as date) )*24);
 dbms_output.put_line('P|Last Login|time='||diff||' '||ll_user);
 if err2=0 then 
   diff:=round((current_date-ll_ts  )*24);
 else 
   diff:=999999;
 end if;
 dbms_output.put_line('P|Last TabMod Change|time='||diff||' '||ll_owner||'.'||ll_tname);
end;

BEGIN
--dbms_application_info.set_client_info(client_info => 'SchroedingersDB Script');
DBMS_SESSION.SET_IDENTIFIER(client_id => 'SchroedingersDB Script');
    --# ORASCM Highest Mode choosen
IF isout(c_out_orascn) THEN
    p_mode := 'N';
END IF;

IF isout(c_out_orascn_f) THEN
    p_mode := 'F';
END IF;

IF isout(c_out_orascn_s) THEN
    p_mode := 'S';
END IF;

IF isout(c_out_orascn_d) THEN
    p_mode := 'D';
END IF;
    -- CheckMK Only Output
IF isout(c_out_checkmk) THEN
    checkmk1;
    RETURN;  -- End Program
END IF;

IF isout(c_out_debug_simple) THEN
    v_debug := c_debug_simple;
END IF;

IF isout(c_out_debug_moderate) THEN
    v_debug := c_debug_moderate;
END IF;

IF isdebug(c_debug_simple) THEN
    dbms_output.put_line('Parameter out: '
                         || p_out
                         || ' Mode: '
                         || p_mode
                         || ' Schema '
                         || p_schema
                         || ' Table limit:'
                         || v_limit_table_days);
END IF;

v_min_orascn := ret_last_arch_scn;

v_min_archtime := ret_last_arch_time;

IF isdebug(c_debug_simple) THEN
    dbms_output.put_line('Min Archive Log SCN: '
                         || v_min_orascn
                         || ' Time: '
                         || v_min_archtime);
END IF;

IF p_mode <> 'D' THEN
    v_min_orascn := time_to_arch_scn(sysdate - v_limit_table_days);
    v_min_archtime := arch_scn_to_time(v_min_orascn);
    IF isdebug(c_debug_simple) THEN
        dbms_output.put_line(v_limit_table_days
                             || ' Days back SCN: '
                             || v_min_orascn
                             || ' Time: '
                             || v_min_archtime);
    END IF;

END IF;
    
                             
                         
    --# Standard: scan all user maintained schemas
IF p_schema IS NULL THEN
    p_schema := '%';
END IF;

    --# Standard: Nude Mode ?
IF p_mode IS NULL THEN
    p_mode := 'N';
END IF;

EXECUTE IMMEDIATE ( 'alter session set nls_date_format =''DD.MM.YYYY HH24:MI:SS'' ' );

EXECUTE IMMEDIATE ( 'alter session set nls_timestamp_format =''DD.MM.YYYY HH24:MI:SS'' ' );
   --# General Section  
IF checkparameters(
                  p_schema,
                  p_mode,
                  v_testnum
   ) THEN
    RETURN; -- Exit Program
END IF;

    --# Set lowest Archive_log scn time




printheader();

IF isout(c_out_dbinfo) THEN
    generaldbinfo();
END IF;

IF isdebug() THEN
    dbms_output.put_line('MIN Arch SCN: '
                         || v_min_orascn
                         || ' with start time: '
                         || v_min_archtime);
END IF;
    
    --last_login(o_luser, o_ltime);
IF isout(c_out_connSessions) THEN
    connected_sessions();
END IF;

IF
    hasdiagpack()
    AND bitand(
              p_out,
              c_out_last_actions
        ) = c_out_last_actions
THEN
    lastactions();
END IF;

IF isout(c_out_jobs) THEN
    listjobs();
END IF;
   --# End General Section
   
   --# Start Schema Actions
FOR u IN (
    SELECT
        username
    FROM
        dba_users
    WHERE
        oracle_maintained = 'N'
        AND username LIKE p_schema
    ORDER BY
        username
) LOOP
    IF isout(c_out_triggers) THEN
        list_triggers(u.username);
    END IF;
    IF isout(c_out_tabmod) THEN
        list_tab_mod(
                    u.username,
                    14,
                    v_last_tabmod_time,
                    v_last_tabmod_schema,
                    v_last_tabmod_table
        );
    END IF;
        
        -- TODO Modes: Test Everything (find last action), exit on first hit, exit on first hit every user 
    IF p_mode IN ( 'F', 'S', 'D' ) THEN
        IF isout(c_out_orascn_f) OR isout(c_out_orascn_s) OR isout(c_out_orascn_d) THEN
            orascn(
                  u.username,
                  p_mode,
                  v_testnum,
                  v_last_table_time,
                  v_last_table,
                  v_last_schema
            );
            IF isdebug(1) THEN
                dbms_output.put_line('DEBUG: Schema '
                                     || u.username
                                     || ' a table was changed at '
                                     || v_last_table_time
                                     || ' on table '
                                     || v_last_schema
                                     || '.'
                                     || v_last_table);

            END IF;
         --if p_mode='F' and v_last_table_time is not null then exit; end if;
        END IF;
    END IF;

END LOOP;

IF bitand(
         p_out,
         c_out_freqmap
   ) = c_out_freqmap THEN
    logfreqmap(14);
END IF;

IF p_mode IN ( 'N' ) THEN
    orascn(
          p_schema,
          p_mode,
          v_testnum,
          v_last_table_time,
          v_last_table,
          v_last_schema
    );
END IF;
   --# End Schema Actions

final_results(p_schema);
   --ms_output.put_line('Runtime: '||sysdate-starttime );
diffrun := sysdate - starttime;

dbms_output.put_line('Runtime: ' || diffrun);

end;
/

EXIT;


