-- 회원관리하는 procedure 3가지
-- 정보처리 cursor 생성
-- 회원 탈퇴 trigger -> old_customer 테이블 생성
-- 트랜잭션 제어, 예외 관리, autonomous 
-- 가입 탈퇴 변경관련 로그 프로시저 생성 write_log, autonomous

REM  ***********************************************************************************************************
REM  SCRIPT 용도 : 
REM  작성자      : 2360340009 박준하
REM  최초작성일   : 2023-06-03, 
REM  수정사항
REM               23/06/03  1 insert, update, delete procedure 구현
REM                         2 delete procedure 내부에 trigger 구현하였다가 비효율적이라 판단하여 외부에 따로 생성
REM               23/04/16  1 age 컬럼 삭제
REM  *********************************************************************************************************** 

--------------------------------------------------------------------------------
--  고객(CUSTOMER) 관리 패키지 Header
--    body 명세
--    회원가입 insert_cust
--    회원탈퇴 delete_cust
--    회원정보 변경 update_cust
--------------------------------------------------------------------------------
create or replace package p_customer_mng
as
    -- customer 정보 insert procedure
    procedure insert_cust(
        p_id varchar2, p_pwd varchar2, p_name varchar2, p_zipcode varchar2, 
        p_address1 varchar2, p_address2 varchar2, p_mobile_no varchar2,
        p_phone_no varchar2, p_credit_limit number, p_email varchar2,
        p_account_mgr number, p_birth_dt date, p_enroll_dt date, p_gender varchar2
    );
    -- customer 삭제 procedure
    procedure delete_cust(
        p_id varchar2
    );
    -- customer update procedure
    procedure update_cust(
        p_id varchar2, p_pwd varchar2, p_name varchar2, p_zipcode varchar2 default null, 
        p_address1 varchar2 default null, p_address2 varchar2 default null, p_mobile_no varchar2 default null,
        p_phone_no varchar2 default null, p_credit_limit number default null, p_email varchar2 default null,
        p_account_mgr number default null, p_birth_dt date default null, p_enroll_dt date default null, p_gender varchar2 default null
    );
end p_customer_mng;
/


create or replace package body p_customer_mng
as
    -- insert procedure
    procedure insert_cust(
        p_id varchar2, p_pwd varchar2, p_name varchar2, p_zipcode varchar2, 
        p_address1 varchar2, p_address2 varchar2, p_mobile_no varchar2,
        p_phone_no varchar2, p_credit_limit number, p_email varchar2,
        p_account_mgr number, p_birth_dt date, p_enroll_dt date, p_gender varchar2
    )
    is
    begin
        -- insert into customer table
        insert into customer(
        id, pwd, name, zipcode, address1, address2, mobile_no,
        phone_no, credit_limit, email, account_mgr, birth_dt, enroll_dt, gender
        )
        values(
        p_id, p_pwd, p_name, p_zipcode, p_address1, p_address2, p_mobile_no,
        p_phone_no, p_credit_limit, p_email,p_account_mgr, p_birth_dt, p_enroll_dt, p_gender
        );
        -- 회원 가입 후 오류가 없으면 즉시 커밋
        commit;
    exception
        -- 중복 값에 대한 예외 핸들링
        when dup_val_on_index then
            write_log('insert_cust', 'ID 중복 발생', sqlerrm);
            raise_application_error(-20001, '고객 ID가 중복입니다');
        when others then
            write_log('insert_cust', '가입 중 오류발생', sqlerrm);
            dbms_output.put_line('회원 가입 중 오류: ' || sqlerrm);
    end insert_cust;

    procedure update_cust(
    -- not null 제약사항이 있는 id, pwd, name은 매개변수를 지정하고, 그 외의 컬럼은 default null로 하여 update가 필요한 컬럼 외에는 쓰지 않아도 됨
        p_id varchar2, p_pwd varchar2, p_name varchar2, p_zipcode varchar2 default null, 
        p_address1 varchar2 default null, p_address2 varchar2 default null, p_mobile_no varchar2 default null,
        p_phone_no varchar2 default null, p_credit_limit number default null, p_email varchar2 default null,
        p_account_mgr number default null, p_birth_dt date default null, p_enroll_dt date default null, p_gender varchar2 default null
        )
    is
        v_customer customer%rowtype;  -- private 변수 선언
        -- 업데이트를 위한 id 검색 cursor
        cursor customer_cur is
            select *
            from customer
            where id = p_id;
        
    begin
        open customer_cur;
        fetch customer_cur into v_customer;

        if customer_cur%found then
            -- 고객이 있으면 update 진행
            update customer
            set 
                id = p_id,
                pwd = p_pwd,
                name = p_name,
                zipcode = nvl(p_zipcode, v_customer.zipcode),
                address1 = nvl(p_address1, v_customer.address1),
                address2 = nvl(p_address2, v_customer.address2),
                mobile_no = nvl(p_mobile_no, v_customer.mobile_no),
                phone_no = nvl(p_phone_no, v_customer.phone_no),
                credit_limit = nvl(p_credit_limit, v_customer.credit_limit),
                email = nvl(p_email, v_customer.email),
                account_mgr = nvl(p_account_mgr, v_customer.account_mgr),
                birth_dt = nvl(p_birth_dt, v_customer.birth_dt),
                enroll_dt = nvl(p_enroll_dt, v_customer.enroll_dt),
                gender = nvl(p_gender, v_customer.gender)
            where id = p_id;
            commit;
        else
            raise_application_error(-20002, '존재하지 않는 고객 ID입니다');
        end if;
    
        close customer_cur;
    
    exception
        when others then
            write_log('update_cust', '갱신 중 오류발생', sqlerrm);
            rollback;
            raise;
    end update_cust;

    -- delete_cust 프로시저
    procedure delete_cust(p_id varchar2) 
    is
    begin
        -- CUSTOMER 테이블에서 pk인 id를 기준으로 고객 정보를 삭제
        delete from customer where id = p_id;
        
        -- SQL 선택자, 삭제하려는 id가 없으면 예외 처리
        if SQL%ROWCOUNT = 0 then
            -- raise error 보다 아래에 위치하면 log 작성 불가
            write_log('delete_cust', '[삭제] ID 존재 X', sqlerrm);
            raise_application_error(-20001, '삭제하려는 고객 ID가 존재하지 않습니다');
        end if;
        -- 
        commit;

    exception
        
        when others then
            write_log('delete_cust', '삭제 중 오류발생', sqlerrm);
            -- 예외 발생시 롤백을 수행하고, 발생한 예외를 다시 던지기
            rollback;
            raise;
    end delete_cust;    

end p_customer_mng;
/
--log 테이블 생성
drop table exception_log;
create table exception_log
(
    log_date varchar2(10) default to_char(sysdate, 'YYYY-MM-DD'), -- 로그 일자
    log_time varchar2(10) default to_char(sysdate, 'HH24-MI-SS'), -- 로그 시간
    program_name varchar2(100), -- exception 프로그램
    error_message varchar2(250), -- exception 메세지
    description varchar2(250) -- 설명
);

-- log 작성 procedure
create or replace procedure
    write_log(a_program_name in varchar2, a_error_message in varchar2, a_description in varchar2)
as  
    -- autonomous transaction 정의
    pragma autonomous_transaction;
begin
    -- exception을 log 테이블에 기록
    insert into exception_log(program_name, error_message, description)
    values(a_program_name, a_error_message, a_description);
    commit;
exception
    when others then
        dbms_output.put_line('로그 기록 오류 발생 ' || sqlerrm);
    null;
end;
/
---------------------------------------------
-- old_customer 테이블 생성
drop table old_customer;
create table old_customer
as
    select *
    from customer
    where 1 = 0;
select * from old_customer;

-- 회원탈퇴시 자동으로 trigger 사용
create or replace trigger trg_delete_cust
before delete on customer
for each row
begin
    insert into old_customer values (
        :old.id, :old.pwd, :old.name, :old.zipcode,
        :old.address1, :old.address2, :old.mobile_no,
        :old.phone_no, :old.credit_limit, :old.email,
        :old.account_mgr, :old.birth_dt, :old.enroll_dt,
        :old.gender
    );
end;
/


select * from customer where id = '11111111';
desc customer;
select * from user_constraints where table_name = 'CUSTOMER';
set serveroutput on;
-- insert update delete 확인 코드
-- 데이터 삽입
DECLARE
  p_id          customer.id%type := '11111111';
  p_pwd         customer.pwd%type := 'test_pwd';
  p_name        customer.name%type := 'test_name';
  p_zipcode     customer.zipcode%type := 'zopd';
  p_address1    customer.address1%type := 'test_addr1';
  p_address2    customer.address2%type := 'test_addr2';
  p_mobile_no   customer.mobile_no%type := '1234567890';
  p_phone_no    customer.phone_no%type := '0987654321';
  p_credit_limit customer.credit_limit%type := 4000;
  p_email       customer.email%type := 'test@test.com';
  p_account_mgr customer.account_mgr%type := 7902;
  p_birth_dt    customer.birth_dt%type := SYSDATE;
  p_enroll_dt   customer.enroll_dt%type := SYSDATE;
  p_gender      customer.gender%type := 'M';
BEGIN
  p_customer_mng.insert_cust(p_id, p_pwd, p_name, p_zipcode, p_address1, p_address2, p_mobile_no, p_phone_no, p_credit_limit, p_email, p_account_mgr, p_birth_dt, p_enroll_dt, p_gender);
  DBMS_OUTPUT.PUT_LINE('추가 완료');
--EXCEPTION
--  WHEN OTHERS THEN
--    DBMS_OUTPUT.PUT_LINE('추가 오류: ' || SQLERRM);
END;
/

select * from customer where id = '11111111';
-- 데이터 수정
DECLARE
  p_id          customer.id%type := '11111111';
  p_pwd         customer.pwd%type := 'updated_pwd';
  p_name        customer.name%type := 'updated_name';
  p_zipcode     customer.zipcode%type := 'zipzzzzzzzzzz';
BEGIN
  p_customer_mng.update_cust(p_id, p_pwd, p_name, p_zipcode);
  DBMS_OUTPUT.PUT_LINE('수정 완료');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('수정 오류: ' || SQLERRM);
END;
/

select * from customer where id = '11111111';
-- 데이터 삭제
DECLARE
  p_id          customer.id%type := '11111111';
BEGIN
  p_customer_mng.delete_cust(p_id);
  DBMS_OUTPUT.PUT_LINE('삭제 완료');
END;
/
----------------------------------------------------
select * from exception_log;