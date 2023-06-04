-- ȸ�������ϴ� procedure 3����
-- ����ó�� cursor ����
-- ȸ�� Ż�� trigger -> old_customer ���̺� ����
-- Ʈ����� ����, ���� ����, autonomous 
-- ���� Ż�� ������� �α� ���ν��� ���� write_log, autonomous

REM  ***********************************************************************************************************
REM  SCRIPT �뵵 : 
REM  �ۼ���      : 2360340009 ������
REM  �����ۼ���   : 2023-06-03, 
REM  ��������
REM               23/06/03  1 insert, update, delete procedure ����
REM                         2 delete procedure ���ο� trigger �����Ͽ��ٰ� ��ȿ�����̶� �Ǵ��Ͽ� �ܺο� ���� ����
REM               23/04/16  1 age �÷� ����
REM  *********************************************************************************************************** 

--------------------------------------------------------------------------------
--  ��(CUSTOMER) ���� ��Ű�� Header
--    body ��
--    ȸ������ insert_cust
--    ȸ��Ż�� delete_cust
--    ȸ������ ���� update_cust
--------------------------------------------------------------------------------
create or replace package p_customer_mng
as
    -- customer ���� insert procedure
    procedure insert_cust(
        p_id varchar2, p_pwd varchar2, p_name varchar2, p_zipcode varchar2, 
        p_address1 varchar2, p_address2 varchar2, p_mobile_no varchar2,
        p_phone_no varchar2, p_credit_limit number, p_email varchar2,
        p_account_mgr number, p_birth_dt date, p_enroll_dt date, p_gender varchar2
    );
    -- customer ���� procedure
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
        -- ȸ�� ���� �� ������ ������ ��� Ŀ��
        commit;
    exception
        -- �ߺ� ���� ���� ���� �ڵ鸵
        when dup_val_on_index then
            write_log('insert_cust', 'ID �ߺ� �߻�', sqlerrm);
            raise_application_error(-20001, '�� ID�� �ߺ��Դϴ�');
        when others then
            write_log('insert_cust', '���� �� �����߻�', sqlerrm);
            dbms_output.put_line('ȸ�� ���� �� ����: ' || sqlerrm);
    end insert_cust;

    procedure update_cust(
    -- not null ��������� �ִ� id, pwd, name�� �Ű������� �����ϰ�, �� ���� �÷��� default null�� �Ͽ� update�� �ʿ��� �÷� �ܿ��� ���� �ʾƵ� ��
        p_id varchar2, p_pwd varchar2, p_name varchar2, p_zipcode varchar2 default null, 
        p_address1 varchar2 default null, p_address2 varchar2 default null, p_mobile_no varchar2 default null,
        p_phone_no varchar2 default null, p_credit_limit number default null, p_email varchar2 default null,
        p_account_mgr number default null, p_birth_dt date default null, p_enroll_dt date default null, p_gender varchar2 default null
        )
    is
        v_customer customer%rowtype;  -- private ���� ����
        -- ������Ʈ�� ���� id �˻� cursor
        cursor customer_cur is
            select *
            from customer
            where id = p_id;
        
    begin
        open customer_cur;
        fetch customer_cur into v_customer;

        if customer_cur%found then
            -- ���� ������ update ����
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
            raise_application_error(-20002, '�������� �ʴ� �� ID�Դϴ�');
        end if;
    
        close customer_cur;
    
    exception
        when others then
            write_log('update_cust', '���� �� �����߻�', sqlerrm);
            rollback;
            raise;
    end update_cust;

    -- delete_cust ���ν���
    procedure delete_cust(p_id varchar2) 
    is
    begin
        -- CUSTOMER ���̺��� pk�� id�� �������� �� ������ ����
        delete from customer where id = p_id;
        
        -- SQL ������, �����Ϸ��� id�� ������ ���� ó��
        if SQL%ROWCOUNT = 0 then
            -- raise error ���� �Ʒ��� ��ġ�ϸ� log �ۼ� �Ұ�
            write_log('delete_cust', '[����] ID ���� X', sqlerrm);
            raise_application_error(-20001, '�����Ϸ��� �� ID�� �������� �ʽ��ϴ�');
        end if;
        -- 
        commit;

    exception
        
        when others then
            write_log('delete_cust', '���� �� �����߻�', sqlerrm);
            -- ���� �߻��� �ѹ��� �����ϰ�, �߻��� ���ܸ� �ٽ� ������
            rollback;
            raise;
    end delete_cust;    

end p_customer_mng;
/
--log ���̺� ����
drop table exception_log;
create table exception_log
(
    log_date varchar2(10) default to_char(sysdate, 'YYYY-MM-DD'), -- �α� ����
    log_time varchar2(10) default to_char(sysdate, 'HH24-MI-SS'), -- �α� �ð�
    program_name varchar2(100), -- exception ���α׷�
    error_message varchar2(250), -- exception �޼���
    description varchar2(250) -- ����
);

-- log �ۼ� procedure
create or replace procedure
    write_log(a_program_name in varchar2, a_error_message in varchar2, a_description in varchar2)
as  
    -- autonomous transaction ����
    pragma autonomous_transaction;
begin
    -- exception�� log ���̺� ���
    insert into exception_log(program_name, error_message, description)
    values(a_program_name, a_error_message, a_description);
    commit;
exception
    when others then
        dbms_output.put_line('�α� ��� ���� �߻� ' || sqlerrm);
    null;
end;
/
---------------------------------------------
-- old_customer ���̺� ����
drop table old_customer;
create table old_customer
as
    select *
    from customer
    where 1 = 0;
select * from old_customer;

-- ȸ��Ż��� �ڵ����� trigger ���
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
-- insert update delete Ȯ�� �ڵ�
-- ������ ����
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
  DBMS_OUTPUT.PUT_LINE('�߰� �Ϸ�');
--EXCEPTION
--  WHEN OTHERS THEN
--    DBMS_OUTPUT.PUT_LINE('�߰� ����: ' || SQLERRM);
END;
/

select * from customer where id = '11111111';
-- ������ ����
DECLARE
  p_id          customer.id%type := '11111111';
  p_pwd         customer.pwd%type := 'updated_pwd';
  p_name        customer.name%type := 'updated_name';
  p_zipcode     customer.zipcode%type := 'zipzzzzzzzzzz';
BEGIN
  p_customer_mng.update_cust(p_id, p_pwd, p_name, p_zipcode);
  DBMS_OUTPUT.PUT_LINE('���� �Ϸ�');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('���� ����: ' || SQLERRM);
END;
/

select * from customer where id = '11111111';
-- ������ ����
DECLARE
  p_id          customer.id%type := '11111111';
BEGIN
  p_customer_mng.delete_cust(p_id);
  DBMS_OUTPUT.PUT_LINE('���� �Ϸ�');
END;
/
----------------------------------------------------
select * from exception_log;