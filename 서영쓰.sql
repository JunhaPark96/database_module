CREATE OR REPLACE PACKAGE member_pkg IS
  -- ȸ�� ����
  PROCEDURE insert_cust (
    p_id    IN  VARCHAR2,
    p_pwd   IN  VARCHAR2,
    p_name  IN  VARCHAR2
  );
  
  -- ȸ�� Ż��
  PROCEDURE delete_cust (
    p_id IN VARCHAR2
  );
  
  -- ȸ�� ���� ����
  PROCEDURE update_cust (
    p_id    IN  VARCHAR2,
    p_pwd   IN  VARCHAR2,
    p_name  IN  VARCHAR2
  );
  
  -- �α� ���
  PROCEDURE write_log (
    p_log_message IN VARCHAR2
  );
  
END member_pkg;
/

CREATE OR REPLACE PACKAGE BODY member_pkg IS
  -- ȸ�� ����
  PROCEDURE insert_cust (
    p_id    IN  VARCHAR2,
    p_pwd   IN  VARCHAR2,
    p_name  IN  VARCHAR2
  ) IS
  BEGIN
    INSERT INTO customer (id, pwd, name)
    VALUES (p_id, p_pwd, p_name);
    
    -- ȸ�� ���� �α� ���
    write_log('ȸ�� ����: ' || p_id);
  END insert_cust;
  
  -- ȸ�� Ż��
  PROCEDURE delete_cust (
    p_id IN VARCHAR2
  ) IS
  BEGIN
    DELETE FROM customer
    WHERE id = p_id;
    
    -- ȸ�� Ż�� �α� ���
    write_log('ȸ�� Ż��: ' || p_id);
  END delete_cust;
  
  -- ȸ�� ���� ����
  PROCEDURE update_cust (
    p_id    IN  VARCHAR2,
    p_pwd   IN  VARCHAR2,
    p_name  IN  VARCHAR2
  ) IS
    CURSOR cust_cursor IS
      SELECT *
      FROM customer
      WHERE id = p_id
      FOR UPDATE;
    cust_row customer%ROWTYPE;
  BEGIN
    OPEN cust_cursor;
    FETCH cust_cursor INTO cust_row;
    
    IF cust_cursor%FOUND THEN
      cust_row.pwd := p_pwd;
      cust_row.name := p_name;
      
      UPDATE customer
      SET pwd = cust_row.pwd,
          name = cust_row.name
      WHERE CURRENT OF cust_cursor;
      
      COMMIT;
      
      -- ȸ�� ���� ���� �α� ���
      write_log('ȸ�� ���� ����: ' || p_id);
    END IF;
    
    CLOSE cust_cursor;
  END update_cust;
  
  -- �α� ���
  PROCEDURE write_log (
    p_log_message IN VARCHAR2
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO css_log (log_id, log_date, log_message)
    VALUES (log_id_seq.NEXTVAL, SYSDATE, p_log_message);
    
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      -- �α� ��� �� ������ �߻��� ���, ���� ������ ����մϴ�.
      DBMS_OUTPUT.PUT_LINE('Error occurred while writing log: ' || SQLERRM);
  END write_log;
  
END member_pkg;
/

-- Ʈ���� ����
CREATE OR REPLACE TRIGGER member_update_trigger
AFTER UPDATE ON customer
FOR EACH ROW
DECLARE
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  IF :NEW.pwd <> :OLD.pwd OR :NEW.name <> :OLD.name THEN
    member_pkg.write_log('ȸ�� ���� ����: ' || :NEW.id);
  END IF;
  
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    -- ���� �߻� �� ���� �޽����� ����մϴ�.
    DBMS_OUTPUT.PUT_LINE('Error occurred in trigger: ' || SQLERRM);
    ROLLBACK;
END;
/

select * from customer where id = 'scott';
select * from old_customer;
SELECT * FROM css_log;

drop table css_log;

desc customer;

CREATE TABLE css_log (
  log_id      NUMBER,
  log_date    DATE,
  log_message VARCHAR2(200)
);

-- log_id_seq ������ ����
CREATE SEQUENCE log_id_seq START WITH 1 INCREMENT BY 1;

-- ��� ������ �����ؾ� �ϴ�, CUSTOMER�� �Ȱ��� ����
CREATE TABLE OLD_CUSTOMER (
  ID           VARCHAR2(20) NOT NULL,
  PWD          VARCHAR2(20) NOT NULL,
  NAME         VARCHAR2(20) NOT NULL,
  ZIPCODE      VARCHAR2(7),
  ADDRESS1     VARCHAR2(100),
  ADDRESS2     VARCHAR2(100),
  MOBILE_NO    VARCHAR2(14),
  PHONE_NO     VARCHAR2(14),
  CREDIT_LIMIT NUMBER(9),
  EMAIL        VARCHAR2(30),
  MGR_EMPNO    NUMBER(4),
  BIRTH_DT     DATE,
  ENROLL_DT    DATE,
  GENDER       VARCHAR2(1),
  DELETION_DATE DATE
);

-- Ȯ���ϱ�
SELECT *
FROM user_objects
WHERE object_type IN ('PACKAGE', 'PACKAGE BODY')
  AND object_name = 'MEMBER_PKG';

-- ȸ�� ����
BEGIN
  member_pkg.insert_cust('scott', 'tiger', 'john');
  member_pkg.insert_cust('scott2', 'tiger', 'minj');
  -- �ʿ��� �Ű����� ���� �����Ͽ� ȣ���մϴ�.
END;
/

-- ȸ�� Ż��
BEGIN
  member_pkg.delete_cust('scott');
  -- �ʿ��� �Ű����� ���� �����Ͽ� ȣ���մϴ�.
END;
/

-- ȸ�� ���� ����
BEGIN
  member_pkg.update_cust('scott', 'tiger', 'seoyoung');
    -- �ʿ��� �Ű����� ���� �����Ͽ� ȣ���մϴ�.
END;
/

select * from customer;
