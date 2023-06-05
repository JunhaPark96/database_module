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
REM               23/06/04  1 write_log 작성. 각 procedure에 예외 처리
REM               23/06/04  2 trg_delete_cust procedure내의 autonomous transaction 삭제 - delete연산이 실패해도 old_customer에 데이터가 삽입될 수 있기 때문
REM               23/06/05  1 생일 쿠폰 발급 비즈니스 로직 추가
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
        -- customer 컬럼
        p_id varchar2, p_pwd varchar2, p_name varchar2, p_zipcode varchar2, 
        p_address1 varchar2, p_address2 varchar2, p_mobile_no varchar2,
        p_phone_no varchar2, p_credit_limit number, p_email varchar2,
        p_account_mgr number, p_birth_dt date, p_enroll_dt date, p_gender varchar2
    )
    is
        -- 생일 테이블에 넣을 변수 정의
        v_coupon_code varchar2(20);
        v_current_month number;
        v_birth_month number;
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
        
        -- 회원가입을 하면 생일달인 고객에게 쿠폰은 주는 이벤트를 진행.
        v_current_month := to_number(to_char(sysdate, 'MM'));
        v_birth_month := to_number(to_char(p_birth_dt, 'MM'));
        
        if v_current_month = v_birth_month then
            -- 쿠폰 코드는 'BIRTHDAY_' + 고객 ID
            v_coupon_code := 'BIRTHDAY_' || p_id;
            -- 해당 id의 고객에게 쿠폰 지급
            insert into birthday_coupons(id, coupon_code, coupon_date)
            values (p_id, v_coupon_code, sysdate);
        end if;
        /* 회원 가입 후 오류가 없으면 즉시 커밋. 
        회원가입시 DB에 바로 저장되는 것이 맞다고 생각하여 즉시 커밋*/
        commit;
    exception
         -- 중복 값에 대한 prefix 예외 핸들링
        when dup_val_on_index then
            write_log('insert_cust', 'ID 중복 발생', sqlerrm);
            -- 사용자 정의함수 -20001~-20999
            raise_application_error(-20001, '고객 ID 중복');
        -- 입력값 제약사항에 대한 예외 핸들링 추가
        when value_error then
            write_log('insert_cust', '데이터 형식 오류', sqlerrm);
            raise_application_error(-20003, '데이터 형식 오류');
        when no_data_found then
            write_log('insert_cust', '데이터 없음 오류', sqlerrm);
            raise_application_error(-20004, '데이터 없음 오류');
        when too_many_rows then
            write_log('insert_cust', '데이터 과다 오류', sqlerrm);
            raise_application_error(-20005, '데이터 과다 오류');
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
        v_cur_month number := to_number(to_char(sysdate, 'MM')); -- 기존 고객 중 생일 달인 고객
        
        -- 업데이트를 위한 id 검색 cursor
        /* insert에서는 기존 값을 참조할 필요가 없고, delete procedure에서는 
        rowcount 커서 속성을 사용하기 때문에 update procedure에서만 cursor 사용
        */
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
            
            -- 생일이 이번달인 경우, 생일 쿠폰 발행
            if (to_number(to_char(nvl(p_birth_dt, v_customer.birth_dt), 'MM')) = v_cur_month) then
                insert into birthday_coupons (id, coupon_code, coupon_date) values (p_id, 'BIRTHDAY_' || p_id, sysdate);
                commit;
            end if;
        else
            raise_application_error(-20002, '존재하지 않는 고객 ID');
        end if; 
        close customer_cur;
    
    exception
        -- 입력값 제약사항에 대한 예외 핸들링 추가
        when value_error then
            write_log('update_cust', '데이터 형식 오류', sqlerrm);
            raise_application_error(-20003, '데이터 형식 오류');
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
        -- 입력값 제약사항에 대한 예외 핸들링 추가
        when value_error then
            write_log('delete_cust', '데이터 형식 오류', sqlerrm);
            raise_application_error(-20003, '데이터 형식 오류');
        when others then
            write_log('delete_cust', '삭제 중 오류발생', sqlerrm);
            -- 예외 발생시 롤백을 수행하고, 발생한 예외를 다시 던지기
            rollback;
            raise;
    end delete_cust;    

end p_customer_mng;
/
-------------------------------------------------------
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
----------------------------------------------------
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
-----------------------------------------------
-- 회원탈퇴시 자동으로 trigger 사용
create or replace trigger trg_delete_cust
before delete on customer
-- 각 행의 삭제 이전에 old_customer 테이블에 데이터를 삽입하므로 row level 트리거 사용
for each row
--declare
--    pragma autonomous_transaction; -- 트리거 독립 트랜잭션 설정 -> 삭제
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
----------------------------------------------------------
-- insert 프로시저 비즈니스로직을 위한 쿠폰 테이블 생성
drop table birthday_coupons;
create table birthday_coupons (
  id varchar2(20) not null,
  coupon_code varchar2(20),
  coupon_date date,
  constraint pk_birthday_coupons primary key(id)
);
select * from birthday_coupons;
SELECT * FROM all_tab_columns WHERE table_name = 'BIRTHDAY_COUPONS';
--------------------------------------------------

select * from customer where id like '1111111%';
desc customer;
select * from user_constraints where table_name = 'CUSTOMER';
set serveroutput on;
-- insert update delete 확인 코드
-- 데이터 삽입
declare
  p_id          customer.id%type := '11111119';
  p_pwd         customer.pwd%type := 'test_pwd';
  p_name        customer.name%type := 'test_name';
  p_zipcode     customer.zipcode%type := 'zopdz';
  p_address1    customer.address1%type := 'test_addr1';
  p_address2    customer.address2%type := 'test_addr2';
  p_mobile_no   customer.mobile_no%type := '01011114457';
  p_phone_no    customer.phone_no%type := '0987654321';
  p_credit_limit customer.credit_limit%type := 4000;
  p_email       customer.email%type := 'test@test.com';
  p_account_mgr customer.account_mgr%type := 7902;
  p_birth_dt    customer.birth_dt%type := to_date('1996/05/05', 'yyyy/mm/dd');
  p_enroll_dt   customer.enroll_dt%type := SYSDATE;
  p_gender      customer.gender%type := 'M';
begin
  p_customer_mng.insert_cust(p_id, p_pwd, p_name, p_zipcode, p_address1, p_address2, p_mobile_no, p_phone_no, p_credit_limit, p_email, p_account_mgr, p_birth_dt, p_enroll_dt, p_gender);
  dbms_output.put_line('추가 완료');
END;
/

select * from customer where id = '11111111';
-- 데이터 수정
declare
  p_id          customer.id%type := '11111111';
  p_pwd         customer.pwd%type := 'updated_pwd';
  p_name        customer.name%type := 'updated_name';
  p_zipcode     customer.zipcode%type := 'zipzzz';
begin
  p_customer_mng.update_cust(p_id, p_pwd, p_name, p_zipcode);
  dbms_output.put_line('수정 완료');
end;
/

select * from customer where id = '11111111';
-- 데이터 삭제
declare
  p_id          customer.id%type := '11111111';
begin
  p_customer_mng.delete_cust(p_id);
  DBMS_OUTPUT.PUT_LINE('삭제 완료');
end;
/
----------------------------------------------------
select * from old_customer;
select * from exception_log order by log_date || log_time desc;


--------------------------------
-- 아래 코드는 고객의 생일이 현재 달인 경우, 생일 쿠폰을 발행하며, 그렇지 않은 경우에는 생일 쿠폰을 발행하지 않음
BEGIN
  p_customer_mng.insert_cust(
    p_id => 'test01', 
    p_pwd => 'testpwd01', 
    p_name => 'Test User', 
    p_zipcode => '1234567', 
    p_address1 => 'Test Address 1', 
    p_address2 => 'Test Address 2', 
    p_mobile_no => '010-1234-5678', 
    p_phone_no => '02-123-4567', 
    p_credit_limit => 5000, 
    p_email => 'test01@email.com', 
    p_account_mgr => 7902, 
    p_birth_dt => TO_DATE('1990-06-01', 'YYYY-MM-DD'), 
    p_enroll_dt => SYSDATE, 
    p_gender => 'M'
  );
END;
/

-- 아래 코드는 해당 고객의 정보를 업데이트하며, 만약 고객의 생일이 현재 달인 경우 생일 쿠폰을 발행
BEGIN
  p_customer_mng.update_cust(
    p_id => 'test01', 
    p_pwd => 'updatedpwd01', 
    p_name => 'Updated User', 
    p_zipcode => '7654321', 
    p_address1 => 'Updated Address 1', 
    p_address2 => 'Updated Address 2', 
    p_mobile_no => '010-8765-4321', 
    p_phone_no => '02-765-4321', 
    p_credit_limit => 4000, 
    p_email => 'updated01@email.com', 
    p_account_mgr => 7902, 
    p_birth_dt => TO_DATE('1990-07-01', 'YYYY-MM-DD'), 
    p_enroll_dt => SYSDATE, 
    p_gender => 'F'
  );
END;
/

select * from customer where id = 'test01';
select * from old_customer;
select * from exception_log order by log_date || log_time desc;
select * from birthday_coupons;
