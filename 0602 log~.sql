-- log
CREATE TABLE EXCEPTION_LOG
( LOG_DATE VARCHAR2(8) DEFAULT TO_CHAR(SYSDATE,'YYYYMMDD'), --로그 기록 일자 YYYYMMDD
LOG_TIME VARCHAR2(6) DEFAULT TO_CHAR(SYSDATE,'HH24MISS'), --로그 기록 시간 HH24MISS
PROGRAM_NAME VARCHAR2(100), --EXCEPTION 발생 프로그램
ERROR_MESSAGE VARCHAR2(250), --EXCEPTION MESSAGE
DESCRIPTION VARCHAR2(250) --비고 사항
);

create or replace procedure change_salary(a_empno in number, a_salary number default 2000)
as
    v_error_message exeption_log.error_message%type;
begin
    update emp set sal = a_salary where empno = a_empno;
    commit;
exception
    when others then
        rollback;
        begin
            v_error_message := sqlerrm;
            insert into exception_log(program_name, error_message, description)
            values ('change_salary', v_error_message, 'values : [1] => ' || a_empno || '[2] => ' || a_salary);
            commit; --1
        exception
            when others then
            null; --2
        end;
end change_salary;
/
execute change_salary(a_empno => 7369, a_salary => 1234567); -- 3
select * from exception_log;

create or replace procedure
    write_log(a_program_name in varchar2, a_error_message in varchar2, a_description in varchar2)
as
    begin
        insert into exception_log(program_name, error_message, description)
        values (a_program_name, a_error_message, a_description);
        commit; --1
    exception
        when others then
        null; --2
end;
/

create or replace procedure change_salary(a_empno in number, a_salary number default 2000)
as
    v_error_message exception_log.error_message%type;
begin
    update emp set sal = a_salary where empno = a_empno;
    commit;
exception
    when others then
        rollback;
        write_log('change_salary', sqlerrm, 'values : [1] => ' || a_empno || ' [2] => ' || a_salary);
end change_salary;
/
execute change_salary(a_empno => 7369, a_salary => 1234567);
select * from exception_log;


-- package 실습1
create or replace package p_global_var
as
    -- header에서 선언하는 경우 public 접근지정자
    last_change_date date;
    max_value number(4);
end;
/
desc p_global_var;
set serveroutput on;

begin -- 첫번째 block에서 변수값 초기화
    p_global_var.max_value := 3000;
    p_global_var.last_change_date := sysdate;
    dbms_output.put_line('block1 p_global_var.max_value = ' || p_global_var.max_value);
end;
/

begin -- 서로 다른 독립적인 block간에 데이터 공유
    p_global_var.max_value := p_global_var.max_value + 3000;
    dbms_output.put_line('block2 p_global_var.max_value = ' || p_global_var.max_value);
    dbms_output.put_line('block2 p_global_var.last_change_date = ' || to_char(p_global_var.last_change_date, 'YYYY-MM-DD'));
end;
/
-- 패키지 실습2
create or replace package p_employee
as
    procedure delete_emp(p_empno emp.empno%type);
    procedure insert_emp(p_empno number, p_ename varchar2, p_job varchar2, p_sal number, p_deptno number);
    function search_mng(p_empno emp.empno%type) return varchar2;
    gv_rows number(6);
end p_employee;
/

desc p_employee;
exec p_employee.gv_rows := 999;
exec dbms_output.put_line(p_employee.gv_rows);


create or replace package BODY p_employee
as
    v_ename emp.ename%type;
    v_rows number(6);
    
    -- delete 프로시저에서 사용할 function 정의
    function prvt_func(p_num in number) return number is
    begin
        v_rows := round(dbms_random.value(1,20), 0);
        return v_rows - p_num;
    end prvt_func;
    
    -- insert 프로시저
    procedure insert_emp(p_empno number, p_ename varchar2, p_job varchar2, p_sal number, p_deptno number)
    is
    begin
        insert into emp(empno, ename, job, sal, deptno) values(p_empno, p_ename, p_job, p_sal, p_deptno);
        commit;
    end insert_emp;
    
    -- delete 프로시저
    procedure delete_emp(p_empno emp.empno%type) is
    begin
        delete from emp where empno = p_empno;
        --commit; --1번위치에 commit을 두면 커서 속성자를 사용 불가능. ⇒ 2번 위치에 둬야함
        gv_rows := gv_rows + sql%rowcount;
        commit;
        v_rows := prvt_func(gv_rows);
    exception
        when others then
            rollback;
            write_log('p_employee.delete', sqlerrm, 'values : [empno] => ' || p_empno);
    end delete_emp;
    
    --search function
    function search_mng(p_empno emp.empno%type) return varchar2
    is
        v_ename emp.ename%type;
    begin
        -- 실행부에서 select를 쓰면 항상 into 삽입
        select ename into v_ename from emp
        where empno = (select mgr from emp where empno = p_empno);
        return v_ename;
    exception
        when no_data_found then
            v_ename := 'NO_DATA';
            return v_ename;
        when others then
            v_ename := substr(sqlerrm, 1, 12);
            return v_ename;
    end search_mng;
    
    begin
        gv_rows := 0;
end p_employee;
/

desc p_employee

begin
    p_employee.gv_rows := 100; -- pulbic 변수 직접 참조 가능
--    p_employee.v_rows := 100; -- private 변수 직접 참조 불가능
end;
/

begin
    p_employee.insert_emp(1111, 'PACKAGE', 'CIO', 9999, 10);
    p_employee.insert_emp(1112, 'PACKAGE', 'CIO', 9999, 20);
--    p_employee.insert_emp(1112);
    dbms_output.put_line('deleted rows => ' || p_employee.gv_rows);
end;
/
select * from emp;

variable h_ename varchar2(10)

declare
    v_ename emp.ename%type;
begin
    v_ename := p_employee.search_mng(1111);
    dbms_output.put_line('MANAGER NAME => ' || v_ename);
    
    v_ename := p_employee.search_mng(7788);
    dbms_output.put_line('MANAGER NAME => ' || v_ename);
    
    :h_ename := p_employee.search_mng(7369);
end;
/
print h_ename;

--trigger
create or replace trigger t_change_sal
before update of sal on emp
for each row
begin
    if (:new.sal > 9000) then
        :new.sal := 9000;
    end if;
end;
/

-- 아래 update 문을 동작 시에 trigger 동작
update emp set sal = 9500 where empno in (7839, 7844);
select empno, sal, job from emp where empno in (7839, 7844);

rollback;
select empno, sal, job from emp where empno in (7839, 7844);

-- trigger2
create or replace trigger t_change_sal
before update of sal on emp
for each row
begin
    if (:new.sal > 9000 and :old.job != 'PRESIDENT') then
        :new.sal := 9000;
        write_log('UPDATE', 'Business rule: sal > 9000', 'empno : ' || :old.empno || ', sal from ' || :old.sal || 'to ' || :new.sal);
    end if;
end;
/

-- 아래 update 문을 동작 시에 trigger 동작
update emp set sal = 9500 where empno in (7839, 7844);
select empno, sal, job from emp where empno in (7839, 7844);

rollback; -- transaction의 범위는 어디까지 인가?
-- transaction의 개념에서 transaction level에서 write_log 프로시저의 transaction또한 취소되는 것이 맞다
select empno, sal, job from emp where empno in (7839, 7844);


--trigger 3
create or replace trigger t_emp_change
before insert or delete or update of sal on emp
for each row
declare
begin
    if inserting and :new.job in ('CLERK', 'SALESMAN') then
        insert into labor_union(empno, ename, job, enroll_date)
    values(:new.empno, :new.ename, :new.job, sysdate);
    elsif deleting then -- nested block 실행
        begin
            insert into retired_emp (empno, ename, job, retired_date)
            values(:old.empno, :old.ename, :old.job, sysdate);
            
            delete from labor_union where empno = :old.empno;
        exception
            when others then
                null;
        end;
    elsif updating then
        if :new.sal < 0 then
            :new.sal := :old.sal;
        end if;
    end if;
end;
/

BEGIN
P_EMPLOYEE.DELETE_EMP(7369);
P_EMPLOYEE.INSERT_EMP(2025,'JJANG','PRESIDENT',8888,10);
P_EMPLOYEE.INSERT_EMP(10,'K', 'SALESMAN', 5555,10);
END;
/
UPDATE EMP SET SAL = 1000 WHERE EMPNO = 7900;
SELECT * FROM RETIRED_EMP WHERE EMPNO = 7369;
SELECT * FROM LABOR_UNION WHERE EMPNO IN (2025,10);
SELECT EMPNO,SAL FROM EMP WHERE EMPNO = 7900;

select * from user_source where name like 'T%';
select * from user_triggers;
select * from user_objects where object_name like 'T%';
