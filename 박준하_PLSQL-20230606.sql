select * from customer;

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
REM               23/04/15  1 libuser_seq의 cache 삭제. 기능 수행 때 갑자기 id가 증가하는 현상때문에
REM                         2 libuser_seq의 nocache 추가. 그냥 cache를 삭제하니 default로 20이 들어감
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
    -- customer 관리하는 직원 number 검색
    function search_mng(p_mgr_empno customer.mgr_empno%type) return number;
    -- customer 정보 insert procedure
    procedure insert_cust(
        p_id varchar2, p_pwd varchar2, p_name varchar2, p_zipcode varchar2, 
        p_address1 varchar2, p_address2 varchar2, p_mobile_no varchar2,
        p_phone_no varchar2, p_credit_limit number, p_email varchar2,
        p_mgr_empno number, p_birth_dt date, p_enroll_dt date, p_gender varchar2);
    -- customer 삭제 procedure
    procedure delete_cust(
        p_customer customer%rowtype
    );
    -- customer update procedure
    procedure update_cust(
        p_id varchar2, p_pwd varchar2, p_name varchar2, p_zipcode varchar2, 
        p_address1 varchar2, p_address2 varchar2, p_mobile_no varchar2,
        p_phone_no varchar2, p_credit_limit number, p_email varchar2,
        p_mgr_empno number, p_birth_dt date, p_enroll_dt date, p_gender varchar2
    );
end p_customer_mng;
/

create or replace package BODY p_customer_mng
as
    -- insert 프로시저
    procedure insert_cust(
        p_id varchar2, p_pwd varchar2, p_name varchar2, p_zipcode varchar2, 
        p_address1 varchar2, p_address2 varchar2, p_mobile_no varchar2,
        p_phone_no varchar2, p_credit_limit number, p_email varchar2,
        p_mgr_empno number, p_birth_dt date, p_enroll_dt date, p_gender varchar2
    )
    is
    begin
        insert into customer(
        id, pwd, name, zipcode, address1, address2, mobile_no,
        phone_no, credit_limit, email, mgr_empno, birth_dt, enroll_dt, gender
        )
        values(
        p_id, p_pwd, p_name, p_zipcode, p_address1, p_address2, p_mobile_no,
        p_phone_no, p_credit_limit, p_email,p_mgr_empno, p_birth_dt, p_enroll_dt, p_gender
        );
        commit;
    exception
        when dup_val_on_index then
        raise_application_error(-20001, '고객 ID가 중복입니다');
    end insert_cust;

    procedure update_cust(
    -- not null 제약사항이 있는 id, pwd, name은 매개변수를 지정하고, 그 외의 컬럼은 default null로 하여 update가 필요한 컬럼 외에는 쓰지 않아도 됨.
        p_id varchar2, p_pwd varchar2, p_name varchar2, p_zipcode varchar2 default null, 
        p_address1 varchar2 default null, p_address2 varchar2 default null, p_mobile_no varchar2 default null,
        p_phone_no varchar2 default null, p_credit_limit number default null, p_email varchar2 default null,
        p_mgr_empno number default null, p_birth_dt date default null, p_enroll_dt date default null, p_gender varchar2 default null
        )
    is
        v_customer customer%rowtype;  -- private 변수 선언
        cursor customer_cur is
            select *
            from customer
            where id = p_id;
        
    begin
        open customer_cur;
        fetch customer_cur into v_customer;

        if customer_cur%found then
            -- customer를 찾은 경우에만 업데이트
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
                mgr_empno = nvl(p_mgr_empno, v_customer.mgr_empno),
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
            rollback;
            raise;
    end update_cust;

    -- delete_cust 프로시저
    procedure delete_cust(p_id varchar2) 
    is
    begin
        -- CUSTOMER 테이블에서 해당 고객 정보를 삭제
        delete from customer where id = p_id;
    
        if SQL%ROWCOUNT = 0 then
            raise_application_error(-20001, '삭제하려는 고객 ID가 존재하지 않습니다');
        end if;
    
        commit;

    exception
        when others then
            -- 예외 발생시 롤백을 수행하고, 발생한 예외를 다시 던지기
            rollback;
            raise;
    end delete_cust;    

end p_customer_mng;
/


-- old_customer 테이블 생성
create table old_customer
as
    select *
    from customer;

-- 회원탈퇴시 자동으로 trigger 사용
create or replace trigger trg_delete_cust
before delete on customer
for each row
begin
    insert into old_customer values (
        :old.id, :old.pwd, :old.name, :old.zipcode,
        :old.address1, :old.address2, :old.mobile_no,
        :old.phone_no, :old.credit_limit, :old.email,
        :old.mgr_empno, :old.birth_dt, :old.enroll_dt,
        :old.gender
    );
end;
/



-- update 적용되는지 확인하는 코드
declare
    p_id customer.id%type := 'TestID1';
    p_pwd customer.pwd%type := 'TestPwd1';
    p_name customer.name%type := 'TestName1';
    p_zipcode customer.zipcode%type := '1234567';
    p_address1 customer.address1%type := 'New Address1';
begin
    p_customer_mng.update_cust(p_id, p_pwd, p_name, p_zipcode, p_address1);
end;
/

    












