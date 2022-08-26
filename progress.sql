select sid,serial#,module,action,client_info,client_identifier from v$session where action like 'Block%';
