set serveroutput on;

declare
    v_sql varchar2(2000);
begin
    begin
        v_sql := 'drop table by_dynamic';
        execute immediate v_sql;
    exception
        when others then
            dbms_output.put_line('DYNAMIC SQL DROP => ' || substr(SQLERRM, 1, 50));
        end;
    
    begin
        execute immediate 'create table by_dynamic(x date)';
    exception
        when others then
            dbms_output.put_line('DYNAMIC SQL CREATE => ' || substr(SQLERRM, 1, 50));
    end;
end;
/
desc by_dynamic;

declare
    v_sql varchar2(2000);
    v_condition_flag boolean := TRUE;
    r_emp emp%rowtype;
begin
    v_condtion_flag := false;
    -- select문을 동적으로 생성
    begin
        v_sql := 'select * from emp where empno = :v_empno';
        
        if v_condtion_flag then
            v_sql := v_sql || ' AND JOB = "SALESMAN" ';
        end if;
        
        execute immediate v_sql into r_emp using 7499;
        
        dbms_output.put_line('DYNAMIC SELECT EMPNO=' || r_emp.empno || ', EANME = ' || r_emp.ename);
    exception
        when others then
            dbms_output.put_line('DYNAMIC SQL SELECT => ' || substr(sqlerrm, 1, 50));
    end;
    
    -- DDL, DML 동적으로 작성
    begin
        execute immediate 'CREATE TABLE BONUS_LIST(EMPNO NUMBER(7), AMOUNT NUMBER)';
        V_SQL := 'INSERT INTO BONUS_LIST(EMPNO, AMOUNT) VALUES(:1, :2)';
        execute immediate v_sql using 7499, 7000;
        commit;
    exception
        when others then
            dbms_output.put_line('DYNAMIC SQL DDL AND DML => ' || substr(sqlerrm, 1, 50));
        end;
end;
/

desc bonus_list;
select * from bonus_list;