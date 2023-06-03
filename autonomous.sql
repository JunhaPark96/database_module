-- autonomous transaction
drop table exception_log;
create table exception_log
(
    log_date varchar2(8) default to_char(sysdate, 'YYYYMMDD'),
    log_time varchar2(6) default to_char(sysdate, 'HH24MISS'),
    program_name varchar2(100),
    error_message varchar2(250),
    description varchar2(250)
);

select * from exception_log;

--create or replace procedure
--    write_log(a_program_name in varchar2, a_error_message in varchar2, a_description in varchar2)
--as
--begin
--    insert into exception_log(program_name, error_message, description)
--    values(a_program_name, a_error_message, a_description);
--    commit;
--exception
--    when others then
--        null;
--end;
--/

REM EXCEPTION 을 기록하는 WRITE_LOG PROCEDURE 생성 AUTONOMOUS TRANSACTION

create or replace procedure
    write_log(a_program_name in varchar2, a_error_message in varchar2, a_description in varchar2)
as
    pragma autonomous_transaction;
begin
    -- exception을 log 테이블에 기록
    insert into exception_log(program_name, error_message, description)
    values(a_program_name, a_error_message, a_description);
    commit;
exception
    when others then
    null;
end;
/


-- main block
begin
    -- nested block 1
    begin
        insert into exception_log(program_name, error_message, description)
        values('TRANSACTION TEST_1', 'FIRST BLOCK INSERT 1', 'MAIN TRANSACTION');
        
        write_log('TRANSACTION TEST_1', 'FIRST BLOCK INSERT 2', 'SUB TRANSACTION');
    
        insert into exception_log(program_name, error_message, description)
        values('TRANSACTION TEST_1', 'FIRST BLOCK INSERT 3', 'MAIN TRANSACTION');
    
        commit;
    end;
    
    -- nested block 2
    begin
        insert into exception_log(program_name, error_message, description)
        values('TRANSACTION TEST_2', 'SECOND BLOCK INSERT 1', 'MAIN TRANSACTION');
        
        write_log('TRANSACTION TEST_2', 'SECOND BLOCK INSERT 2', 'SUB TRANSACTION');
        
        insert into exception_log(program_name, error_message, description)
        values('TRANSACTION TEST_2', 'SECOND BLOCK INSERT 3', 'MAIN TRANSACTION');
        
        rollback;
    end;
end;
/
select * from exception_log;

SELECT *
FROM USER_CONSTRAINTS
WHERE TABLE_NAME = 'CUSTOMER';