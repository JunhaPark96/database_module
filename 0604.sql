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
REM               23/06/04  1 write_log �ۼ�. �� procedure�� ���� ó��
REM               23/06/04  2 trg_delete_cust procedure���� autonomous transaction ���� - delete������ �����ص� old_customer�� �����Ͱ� ���Ե� �� �ֱ� ����
REM               23/06/05  1 ���� ���� �߱� ����Ͻ� ���� �߰�
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
        -- customer �÷�
        p_id varchar2, p_pwd varchar2, p_name varchar2, p_zipcode varchar2, 
        p_address1 varchar2, p_address2 varchar2, p_mobile_no varchar2,
        p_phone_no varchar2, p_credit_limit number, p_email varchar2,
        p_account_mgr number, p_birth_dt date, p_enroll_dt date, p_gender varchar2
    )
    is
        -- ���� ���̺� ���� ���� ����
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
        
        -- ȸ�������� �ϸ� ���ϴ��� ������ ������ �ִ� �̺�Ʈ�� ����.
        v_current_month := to_number(to_char(sysdate, 'MM'));
        v_birth_month := to_number(to_char(p_birth_dt, 'MM'));
        
        if v_current_month = v_birth_month then
            -- ���� �ڵ�� 'BIRTHDAY_' + �� ID
            v_coupon_code := 'BIRTHDAY_' || p_id;
            -- �ش� id�� ������ ���� ����
            insert into birthday_coupons(id, coupon_code, coupon_date)
            values (p_id, v_coupon_code, sysdate);
        end if;
        /* ȸ�� ���� �� ������ ������ ��� Ŀ��. 
        ȸ�����Խ� DB�� �ٷ� ����Ǵ� ���� �´ٰ� �����Ͽ� ��� Ŀ��*/
        commit;
    exception
         -- �ߺ� ���� ���� prefix ���� �ڵ鸵
        when dup_val_on_index then
            write_log('insert_cust', 'ID �ߺ� �߻�', sqlerrm);
            -- ����� �����Լ� -20001~-20999
            raise_application_error(-20001, '�� ID �ߺ�');
        -- �Է°� ������׿� ���� ���� �ڵ鸵 �߰�
        when value_error then
            write_log('insert_cust', '������ ���� ����', sqlerrm);
            raise_application_error(-20003, '������ ���� ����');
        when no_data_found then
            write_log('insert_cust', '������ ���� ����', sqlerrm);
            raise_application_error(-20004, '������ ���� ����');
        when too_many_rows then
            write_log('insert_cust', '������ ���� ����', sqlerrm);
            raise_application_error(-20005, '������ ���� ����');
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
        v_cur_month number := to_number(to_char(sysdate, 'MM')); -- ���� �� �� ���� ���� ��
        
        -- ������Ʈ�� ���� id �˻� cursor
        /* insert������ ���� ���� ������ �ʿ䰡 ����, delete procedure������ 
        rowcount Ŀ�� �Ӽ��� ����ϱ� ������ update procedure������ cursor ���
        */
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
            
            -- ������ �̹����� ���, ���� ���� ����
            if (to_number(to_char(nvl(p_birth_dt, v_customer.birth_dt), 'MM')) = v_cur_month) then
                insert into birthday_coupons (id, coupon_code, coupon_date) values (p_id, 'BIRTHDAY_' || p_id, sysdate);
                commit;
            end if;
        else
            raise_application_error(-20002, '�������� �ʴ� �� ID');
        end if; 
        close customer_cur;
    
    exception
        -- �Է°� ������׿� ���� ���� �ڵ鸵 �߰�
        when value_error then
            write_log('update_cust', '������ ���� ����', sqlerrm);
            raise_application_error(-20003, '������ ���� ����');
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
        -- �Է°� ������׿� ���� ���� �ڵ鸵 �߰�
        when value_error then
            write_log('delete_cust', '������ ���� ����', sqlerrm);
            raise_application_error(-20003, '������ ���� ����');
        when others then
            write_log('delete_cust', '���� �� �����߻�', sqlerrm);
            -- ���� �߻��� �ѹ��� �����ϰ�, �߻��� ���ܸ� �ٽ� ������
            rollback;
            raise;
    end delete_cust;    

end p_customer_mng;
/
-------------------------------------------------------
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
----------------------------------------------------
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
-----------------------------------------------
-- ȸ��Ż��� �ڵ����� trigger ���
create or replace trigger trg_delete_cust
before delete on customer
-- �� ���� ���� ������ old_customer ���̺� �����͸� �����ϹǷ� row level Ʈ���� ���
for each row
--declare
--    pragma autonomous_transaction; -- Ʈ���� ���� Ʈ����� ���� -> ����
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
-- insert ���ν��� ����Ͻ������� ���� ���� ���̺� ����
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
-- insert update delete Ȯ�� �ڵ�
-- ������ ����
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
  dbms_output.put_line('�߰� �Ϸ�');
END;
/

select * from customer where id = '11111111';
-- ������ ����
declare
  p_id          customer.id%type := '11111111';
  p_pwd         customer.pwd%type := 'updated_pwd';
  p_name        customer.name%type := 'updated_name';
  p_zipcode     customer.zipcode%type := 'zipzzz';
begin
  p_customer_mng.update_cust(p_id, p_pwd, p_name, p_zipcode);
  dbms_output.put_line('���� �Ϸ�');
end;
/

select * from customer where id = '11111111';
-- ������ ����
declare
  p_id          customer.id%type := '11111111';
begin
  p_customer_mng.delete_cust(p_id);
  DBMS_OUTPUT.PUT_LINE('���� �Ϸ�');
end;
/
----------------------------------------------------
select * from old_customer;
select * from exception_log order by log_date || log_time desc;


--------------------------------
-- �Ʒ� �ڵ�� ���� ������ ���� ���� ���, ���� ������ �����ϸ�, �׷��� ���� ��쿡�� ���� ������ �������� ����
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

-- �Ʒ� �ڵ�� �ش� ���� ������ ������Ʈ�ϸ�, ���� ���� ������ ���� ���� ��� ���� ������ ����
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
