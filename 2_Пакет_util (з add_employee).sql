CREATE OR REPLACE PACKAGE util AS

    gc_min_salary CONSTANT NUMBER := 2000;
    TYPE rec_value_list IS RECORD (value_list VARCHAR2(100));
    TYPE tab_value_list IS TABLE OF rec_value_list;
    TYPE rec_exchange IS RECORD (r030         NUMBER,
                                 txt          VARCHAR2(100),
                                 rate         NUMBER,
                                 cur          VARCHAR2(100),
                                 exchangedate DATE );
    TYPE tab_exchange IS TABLE OF rec_exchange;

    TYPE rec_region IS RECORD (region_name   VARCHAR2(100),
                               cnt_employees NUMBER);
    TYPE tab_region IS TABLE OF rec_region;

    FUNCTION get_region_cnt_emp (p_department_id IN NUMBER default null) RETURN tab_region PIPELINED;

    FUNCTION get_currency(p_currency IN VARCHAR2 DEFAULT 'USD',
                          p_exchangedate IN DATE DEFAULT SYSDATE) RETURN tab_exchange PIPELINED;

    FUNCTION table_from_list(p_list_val IN VARCHAR2,
                             p_separator IN VARCHAR2 DEFAULT ',') RETURN tab_value_list PIPELINED;

    FUNCTION get_job_title (p_employee_id IN NUMBER) RETURN VARCHAR2;

    FUNCTION get_dep_name(p_employee_id IN NUMBER) RETURN VARCHAR2;

    FUNCTION add_years (p_date IN DATE DEFAULT SYSDATE,
                        p_year IN NUMBER) RETURN DATE;

    FUNCTION get_sum_price_sales (p_table IN VARCHAR2) RETURN NUMBER;

    PROCEDURE del_jobs (p_job_id  IN VARCHAR2,
                        po_result OUT VARCHAR2);

    PROCEDURE add_new_jobs(p_job_id     IN VARCHAR2, 
                           p_job_title  IN VARCHAR2, 
                           p_min_salary IN NUMBER, 
                           p_max_salary IN NUMBER DEFAULT NULL,
                           po_err       OUT VARCHAR2);

    PROCEDURE update_balance (p_employee_id IN NUMBER,
                              p_balance     IN NUMBER);
    PROCEDURE not_work_time;
                              
    PROCEDURE add_employee(p_first_name     IN VARCHAR2,
                           p_last_name      IN VARCHAR2,
                           p_email          IN VARCHAR2,
                           p_phone_number   IN VARCHAR2,
                           p_hire_date      IN DATE DEFAULT trunc(sysdate, 'dd'),
                           p_job_id         IN VARCHAR2,
                           p_salary         IN NUMBER,
                           p_commission_pct IN VARCHAR2 DEFAULT NULL,
                           p_manager_id     IN NUMBER DEFAULT 100,
                           p_department_id  IN NUMBER );

    PROCEDURE fire_an_employee (p_employee_id IN NUMBER);

    PROCEDURE change_attribute_employee (p_employee_id    IN NUMBER,
                                         p_first_name     IN VARCHAR2 DEFAULT NULL,
                                         p_last_name      IN VARCHAR2 DEFAULT NULL,
                                         p_email          IN VARCHAR2 DEFAULT NULL,
                                         p_phone_number   IN VARCHAR2 DEFAULT NULL,
                                         p_job_id         IN VARCHAR2 DEFAULT NULL,
                                         p_salary         IN NUMBER   DEFAULT NULL,
                                         p_commission_pct IN NUMBER   DEFAULT NULL,
                                         p_manager_id     IN NUMBER   DEFAULT NULL,
                                         p_department_id  IN NUMBER   DEFAULT NULL);

END util;
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE body util AS

    c_percent_of_min_salary CONSTANT NUMBER := 1.5;

--функція get_region_cnt_emp----------------------------------------------------

    FUNCTION get_region_cnt_emp (p_department_id IN NUMBER default null) RETURN tab_region PIPELINED IS

        out_rec tab_region := tab_region ();
        l_cur SYS_REFCURSOR;
        BEGIN
            OPEN l_cur FOR
                       SELECT nvl(re.region_name,'Not found') AS region_name
                             ,COUNT(em.employee_id) AS cnt_employees
                       FROM hr.employees em
                              LEFT JOIN hr.departments dp ON em.department_id = dp.department_id
                              LEFT JOIN hr.locations lo ON dp.location_id = lo.location_id
                              LEFT JOIN hr.countries co ON lo.country_id = co.country_id
                              LEFT JOIN hr.regions re ON co.region_id = re.region_id
                       WHERE (em.department_id = p_department_id OR p_department_id IS NULL)
                       GROUP BY re.region_name;
            BEGIN
              LOOP
                EXIT WHEN l_cur%NOTFOUND;
                FETCH l_cur BULK COLLECT
                  INTO out_rec;
                FOR i IN 1 .. out_rec.count LOOP
                  PIPE ROW(out_rec(i));
                END LOOP;
              END LOOP;
              CLOSE l_cur;
            EXCEPTION
              WHEN OTHERS THEN
                IF (l_cur%ISOPEN) THEN
                  CLOSE l_cur;
                  RAISE;
                ELSE
                  RAISE;
                END IF;
            END;
    END get_region_cnt_emp;

--функція get_currency----------------------------------------------------------

    FUNCTION get_currency(p_currency IN VARCHAR2 DEFAULT 'USD',
    p_exchangedate IN DATE DEFAULT SYSDATE) RETURN tab_exchange PIPELINED IS
    out_rec tab_exchange := tab_exchange();
    l_cur SYS_REFCURSOR;
    BEGIN
        OPEN l_cur FOR
            SELECT tt.r030, tt.txt, tt.rate, tt.cur, TO_DATE(tt.exchangedate, 'dd.mm.yyyy') AS exchangedate
            FROM (SELECT get_needed_curr(p_valcode => p_currency,p_date => p_exchangedate) AS json_value FROM dual)
            CROSS JOIN json_table
            (
            json_value, '$[*]'
            COLUMNS
            (
            r030 NUMBER PATH '$.r030',
            txt VARCHAR2(100) PATH '$.txt',
            rate NUMBER PATH '$.rate',
            cur VARCHAR2(100) PATH '$.cc',
            exchangedate VARCHAR2(100) PATH '$.exchangedate'
            )
            ) TT;
                BEGIN
                    LOOP
                    EXIT WHEN l_cur%NOTFOUND;
                    FETCH l_cur BULK COLLECT
                    INTO out_rec;
                    FOR i IN 1 .. out_rec.count LOOP
                    PIPE ROW(out_rec(i));
                    END LOOP;
                END LOOP;
        CLOSE l_cur;
        EXCEPTION
            WHEN OTHERS THEN
            IF (l_cur%ISOPEN) THEN
            CLOSE l_cur;
            RAISE;
            ELSE
            RAISE;
            END IF;
        END;
    END get_currency;

--функція table_from_list-------------------------------------------------------

    FUNCTION table_from_list(p_list_val IN VARCHAR2,
                             p_separator IN VARCHAR2 DEFAULT ',') RETURN tab_value_list PIPELINED IS
        out_rec tab_value_list := tab_value_list();
        l_cur SYS_REFCURSOR;
    BEGIN

        OPEN l_cur FOR
        SELECT TRIM(REGEXP_SUBSTR(p_list_val, '[^'||p_separator||']+', 1, LEVEL)) AS cur_value FROM dual
        CONNECT BY LEVEL <= REGEXP_COUNT(p_list_val, p_separator) + 1;

        BEGIN
            LOOP
            EXIT WHEN l_cur%NOTFOUND;
            FETCH l_cur BULK COLLECT
            INTO out_rec;
            FOR i IN 1 .. out_rec.count LOOP
            PIPE ROW(out_rec(i));
            END LOOP;
            END LOOP;
            CLOSE l_cur;
        EXCEPTION
            WHEN OTHERS THEN
            IF (l_cur%ISOPEN) THEN
            CLOSE l_cur;
            RAISE;
            ELSE
            RAISE;
            END IF;
        END;

    END table_from_list;

--Функція get_job_title---------------------------------------------------------  

    FUNCTION get_job_title (p_employee_id IN NUMBER) RETURN VARCHAR2 IS
        v_job_title jobs.job_title%TYPE;
    BEGIN

        SELECT j.job_title
        INTO v_job_title
        FROM irina.employees em
        INNER JOIN irina.jobs j
        ON em.job_id =j.job_id
        WHERE em.employee_id = p_employee_id;

        RETURN v_job_title;

    END get_job_title;

--Функція get_dep_name----------------------------------------------------------

    FUNCTION get_dep_name(p_employee_id IN NUMBER) RETURN VARCHAR2 IS
        v_department_name irina.departments.department_name%TYPE;  
    BEGIN

        SELECT d.department_name
        INTO v_department_name
        FROM irina.employees em
        INNER JOIN irina.departments d
        ON em.department_id = d.department_id
        WHERE em.employee_id = p_employee_id; 

        RETURN v_department_name;

    END get_dep_name;

--Функція add_years-------------------------------------------------------------

    FUNCTION add_years (p_date IN DATE DEFAULT SYSDATE,
                        p_year IN NUMBER) RETURN DATE IS
        v_date DATE;
        v_year NUMBER := p_year * 12;

    BEGIN

        SELECT add_months(p_date, v_year)
        INTO v_date
        FROM dual;

        RETURN v_date;

    END add_years;

--Процедура check_work_time-----------------------------------------------------

    PROCEDURE check_work_time IS
    BEGIN

        IF TO_CHAR(SYSDATE, 'DY', 'NLS_DATE_LANGUAGE = AMERICAN') IN ('SAT', 'SUN') THEN
        raise_application_error(-20205,'Ви можете вносити зміни лише у робочі дні');
        END IF;

    END check_work_time;

--Функція get_sum_price_sales---------------------------------------------------

    FUNCTION get_sum_price_sales (p_table IN VARCHAR2) RETURN NUMBER IS
        v_sum NUMBER;
        v_dynamic_sql VARCHAR2(500);
    BEGIN

        IF p_table NOT IN ('products','products_old') THEN
            to_log(p_appl_proc => 'util.get_sum_price_sales', p_message => 'Неприпустиме значення! Очікується products або products_old.');
            raise_application_error(-20001, 'Неприпустиме значення! Очікується products або products_old.'); 
        ELSE
            v_dynamic_sql := 'SELECT SUM(p.price_sales) FROM hr. '||p_table||' p';
        EXECUTE IMMEDIATE v_dynamic_sql INTO v_sum;
        END IF;

        RETURN v_sum;

    END get_sum_price_sales;

--Процедура del_jobs------------------------------------------------------------

    PROCEDURE del_jobs (p_job_id  IN VARCHAR2,
                        po_result OUT VARCHAR2) IS
        v_delete_no_data_found EXCEPTION;
    BEGIN

        check_work_time;

        BEGIN

            DELETE FROM irina.jobs 
            WHERE job_id = p_job_id;      

            IF SQL%ROWCOUNT = 0 THEN
                raise v_delete_no_data_found;
            END IF;

            COMMIT; 
            po_result := 'Посада ' || p_job_id || ' успішно видалена';

            EXCEPTION
            WHEN v_delete_no_data_found THEN
                raise_application_error(-20004, 'Посада ' || p_job_id || ' не існує');  

        END;   

    END del_jobs;

--Процедура add_new_jobs--------------------------------------------------------

    PROCEDURE add_new_jobs(p_job_id     IN VARCHAR2, 
                           p_job_title  IN VARCHAR2, 
                           p_min_salary IN NUMBER, 
                           p_max_salary IN NUMBER DEFAULT NULL,
                           po_err       OUT VARCHAR2) IS
        v_max_salary   irina.jobs.max_salary%TYPE;
        salary_err     EXCEPTION;
    BEGIN

        check_work_time;

        IF p_max_salary IS NULL THEN
            v_max_salary := p_min_salary * c_percent_of_min_salary;
        ELSE 
            v_max_salary := p_max_salary;
        END IF;

        BEGIN

            IF (p_min_salary < gc_min_salary OR p_max_salary < gc_min_salary) THEN
                raise salary_err;
            ELSE 
                INSERT INTO irina.jobs (job_id, job_title, min_salary, max_salary)
                VALUES (p_job_id, p_job_title, p_min_salary, v_max_salary);
                COMMIT;
                po_err := 'Посада ' || p_job_id || ' успішно додана';
            END IF;
            EXCEPTION 
                WHEN salary_err THEN
                    raise_application_error(-20001,'Передана зарплата менша 2000');
                WHEN dup_val_on_index THEN
                    raise_application_error(-20002,'Посада ' || p_job_id || ' вже існує');
                WHEN OTHERS THEN
                    raise_application_error(-20003,'Невідома помилка при додаванні нової посади. ' || SQLERRM);

        END;

        --COMMIT;

    END add_new_jobs;

--Процедура update_balance------------------------------------------------------

    PROCEDURE update_balance (p_employee_id IN NUMBER,
                              p_balance     IN NUMBER) IS
        v_balance_new balance.balance%TYPE;
        v_balance_old balance.balance%TYPE;
        v_message     logs.message%TYPE;
    BEGIN

        SELECT balance
        INTO v_balance_old
        FROM balance b
        WHERE b.employee_id = p_employee_id
        FOR UPDATE; --Блокуємо рядок оновлення

        IF v_balance_old >= p_balance THEN
            UPDATE balance b
            SET b.balance = v_balance_old - p_balance
            WHERE employee_id = p_employee_id
            RETURNING b.balance INTO v_balance_new; --щоб не робити SELECT INTO
        ELSE
            v_message := 'Employee_id = '||p_employee_id||'. Недостатньо коштів на рахунку. Поточний баланс '||v_balance_old||', спроба зняття '||p_balance||'';
            raise_application_error(-20001, v_message);
        END IF;

            v_message := 'Employee_id = '||p_employee_id||'. Кошти успішно зняті з рахунку. Було '||v_balance_old||', стало '||v_balance_new||'';
            dbms_output.put_line(v_message);
            to_log(p_appl_proc => 'util.update_balance', p_message => v_message);

        IF 1=0 THEN -- зімітуємо непередбачену помилку
            v_message := 'Непередбачена помилка';
            raise_application_error(-20001, v_message);

        END IF;
        COMMIT; -- зберігаємо новий баланс та знімаємо блокування в поточній транзакції
        EXCEPTION
            WHEN OTHERS THEN
                to_log(p_appl_proc => 'util.update_balance', p_message => NVL(v_message, 'Employee_id = '||p_employee_id||'. ' ||SQLERRM));
            ROLLBACK; -- Відміняємо транзакцію у разі виникнення помилки
            raise_application_error(-20001, NVL(v_message, 'Не відома помилка'));

    END update_balance;

--Процедура not_work_time--------------------------------------------------------------------

    PROCEDURE not_work_time IS

    BEGIN
         IF TO_CHAR(sysdate, 'DY', 'NLS_DATE_LANGUAGE = AMERICAN') IN ('SAT', 'SUN') OR sysdate < (trunc(sysdate, 'dd') + 8/24) AND sysdate > (trunc(sysdate, 'dd') + 18/24)
         THEN
         raise_application_error(-20001, 'Ви можете вносити зміни лише в робочий час');
         END IF;
    END not_work_time;

--Процедура add_employee---------------------------------------------------------------------

    PROCEDURE add_employee( p_first_name     IN VARCHAR2,
                           p_last_name      IN VARCHAR2,
                           p_email          IN VARCHAR2,
                           p_phone_number   IN VARCHAR2,
                           p_hire_date      IN DATE DEFAULT trunc(sysdate, 'dd'),
                           p_job_id         IN VARCHAR2,
                           p_salary         IN NUMBER,
                           p_commission_pct IN VARCHAR2 DEFAULT NULL,
                           p_manager_id     IN NUMBER DEFAULT 100,
                           p_department_id  IN NUMBER ) IS
    v_is_exist_job_id NUMBER;
    v_is_exist_department_id NUMBER;
    v_is_exist_salary NUMBER;
    v_employee_id NUMBER;

    FUNCTION get_max_employee_id RETURN NUMBER IS
    v_employee_id NUMBER;
    BEGIN
      SELECT NVL(MAX(employee_id),0)+1
      INTO v_employee_id
      FROM employees;
      RETURN v_employee_id;
    END get_max_employee_id;

    BEGIN

        log_util.log_start (p_proc_name => 'add_employee');
        
        SELECT COUNT(*)
        INTO v_is_exist_job_id
        FROM jobs j
        WHERE j.job_id = p_job_id;

        IF v_is_exist_job_id=0 THEN
        raise_application_error(-20001,'Введено неіснуючий код посади');
        END IF;

        SELECT COUNT(*)
        INTO v_is_exist_department_id
        FROM departments d
        WHERE d.department_id = p_department_id;

        IF v_is_exist_department_id=0 THEN
        raise_application_error(-20001,'Введено неіснуючий ідентифікатор відділу');
        END IF;

        SELECT COUNT(*)
        INTO v_is_exist_salary
        FROM jobs j
        WHERE j.job_id = p_job_id AND p_salary BETWEEN j.min_salary AND j.max_salary;

        IF v_is_exist_salary=0 THEN
        raise_application_error(-20001,'Введено неприпустиму заробітну плату для даного коду посади');
        END IF;

        not_work_time; --замінила кусок коду на процедуру

          <<insert_empl>>
           BEGIN
             v_employee_id := get_max_employee_id();
             INSERT INTO employees (employee_id, first_name, last_name,email, phone_number, hire_date, job_id, salary, commission_pct, manager_id, department_id)
             VALUES (v_employee_id, p_first_name, p_last_name, p_email, p_phone_number, p_hire_date, p_job_id, p_salary, p_commission_pct, p_manager_id, p_department_id);

             COMMIT;

             dbms_output.put_line('Співробітника ' || p_first_name || ' ' || p_last_name || ', КОД ПОСАДИ = ' || p_job_id || ', ІД ДЕПАРТАМЕНТУ = ' || p_department_id || ' успішно додано до системи');

             EXCEPTION
             WHEN OTHERS THEN
             log_util.log_error(p_proc_name => 'add_employee',
                                p_sqlerrm   => SQLERRM);
                                
             dbms_output.put_line('Співробітника не додано: непередбачувана помилка ' ||SQLERRM);

           END insert_empl;

      log_util.log_finish(p_proc_name => 'add_employee');

    END add_employee;

--Процедура fire_an_employee-------------------------------------------------------------------------

PROCEDURE fire_an_employee (p_employee_id IN NUMBER) IS
     
    v_is_exist_employee_id NUMBER;
    v_first_name VARCHAR2(50);
    v_last_name VARCHAR2(50);
    v_email varchar2(25); 
    v_phone_number varchar2(20); 
    v_hire_date date; 
    v_job_id varchar2(10);
    v_salary number(8,2); 
    v_commission_pct number(2,2); 
    v_manager_id number(6); 
    v_department_id number(4); 
    
    BEGIN
      
        log_util.log_start (p_proc_name => 'fire_an_employee');
    
        SELECT COUNT(*)
        INTO v_is_exist_employee_id
        FROM employees em
        WHERE em.employee_id = p_employee_id;
        
        IF v_is_exist_employee_id=0 THEN
        raise_application_error(-20001,'Переданий співробітник не існує');
        END IF;
             
        not_work_time;
        
        SELECT em.first_name, em.last_name, em.email, em.phone_number, em.hire_date, em.job_id, em.salary, em.commission_pct, em.manager_id, em.department_id
        INTO v_first_name, v_last_name, v_email, v_phone_number, v_hire_date, v_job_id, v_salary, v_commission_pct, v_manager_id, v_department_id
        FROM employees em
        WHERE em.employee_id = p_employee_id;
        
          <<fire_empl>>
           BEGIN
               DELETE FROM employees em
               WHERE em.employee_id=p_employee_id;
               
               INSERT INTO employees_history(employee_id, first_name, last_name, email, phone_number, hire_date, job_id, salary, commission_pct, manager_id, department_id, fire_date) 
               VALUES (p_employee_id, v_first_name, v_last_name, v_email, v_phone_number, v_hire_date, v_job_id, v_salary, v_commission_pct, v_manager_id, v_department_id, sysdate);
                        
               COMMIT;
               
               dbms_output.put_line('Співробітник ' || v_first_name || ' ' || v_last_name || ', КОД ПОСАДИ = ' || v_job_id || ', ІД ДЕПАРТАМЕНТУ = ' || v_department_id || ' успішно звільнений');
               
               EXCEPTION
               WHEN OTHERS THEN
               log_util.log_error(p_proc_name => 'fire_an_employee',
                                  p_sqlerrm   => SQLERRM);  
               dbms_output.put_line('Співробітника не видалено: непередбачувана помилка ' ||SQLERRM); 
                         
           END fire_empl; 
           
      log_util.log_finish(p_proc_name => 'fire_an_employee');
        
    END fire_an_employee;

--Процедура change_attribute_employee------------------------------------------------------

   PROCEDURE change_attribute_employee (p_employee_id    IN NUMBER,
                                        p_first_name     IN VARCHAR2 DEFAULT NULL,
                                        p_last_name      IN VARCHAR2 DEFAULT NULL,
                                        p_email          IN VARCHAR2 DEFAULT NULL,
                                        p_phone_number   IN VARCHAR2 DEFAULT NULL,
                                        p_job_id         IN VARCHAR2 DEFAULT NULL,
                                        p_salary         IN NUMBER   DEFAULT NULL,
                                        p_commission_pct IN NUMBER   DEFAULT NULL,
                                        p_manager_id     IN NUMBER   DEFAULT NULL,
                                        p_department_id  IN NUMBER   DEFAULT NULL) IS
   v_is_exist_employee_id NUMBER;                                 
   v_first_name     VARCHAR2(20);
   v_last_name      VARCHAR2(25);
   v_email          VARCHAR2(25);
   v_phone_number   VARCHAR2(20);
   v_job_id         VARCHAR2(10);
   v_salary         NUMBER(8,2);  
   v_commission_pct NUMBER(2,2); 
   v_manager_id     NUMBER (6);   
   v_department_id  NUMBER (4);    
        
    BEGIN
      
        log_util.log_start (p_proc_name => 'change_attribute_employee');
        
        SELECT COUNT(*)
        INTO v_is_exist_employee_id
        FROM employees em
        WHERE em.employee_id = p_employee_id;
        
        IF v_is_exist_employee_id=0 THEN
        log_util.log_finish(p_proc_name => 'change_attribute_employee', p_text => 'Завершення логування процесу change_attribute_employee: атрибути не оновлено');
        raise_application_error(-20001,'Переданий співробітник не існує');
        END IF;       
        
        IF p_first_name IS NOT NULL 
            OR p_last_name IS NOT NULL 
            OR p_email IS NOT NULL 
            OR p_phone_number IS NOT NULL 
            OR p_job_id IS NOT NULL 
            OR p_salary IS NOT NULL 
            OR p_commission_pct IS NOT NULL 
            OR p_manager_id IS NOT NULL 
            OR p_department_id IS NOT NULL 
            
        THEN
        
        SELECT em.first_name, em.last_name, em.email, em.phone_number, em.job_id, em.salary, em.commission_pct, em.manager_id, em.department_id
        INTO   v_first_name,  v_last_name,  v_email,  v_phone_number,  v_job_id,  v_salary,  v_commission_pct,  v_manager_id,  v_department_id
        FROM employees em
        WHERE em.employee_id = p_employee_id;      
              
         <<update_empl>>
        BEGIN
        
            UPDATE employees
            SET first_name = NVL(p_first_name, v_first_name), 
                last_name = NVL(p_last_name, v_last_name), 
                email = NVL(p_email, v_email), 
                phone_number = NVL(p_phone_number, v_phone_number), 
                job_id = NVL(p_job_id, v_job_id), 
                salary = NVL(p_salary, v_salary), 
                commission_pct = NVL(p_commission_pct, v_commission_pct), 
                manager_id = NVL(p_manager_id, v_manager_id), 
                department_id = NVL(p_department_id, v_department_id)
            WHERE employee_id = p_employee_id;
            COMMIT;
            dbms_output.put_line('У співробітника ' || p_employee_id || ' успішно оновлені атрибути');
            log_util.log_finish(p_proc_name => 'change_attribute_employee', p_text => 'Завершення логування процесу change_attribute_employee: атрибути оновлено');
            
            EXCEPTION
               WHEN OTHERS THEN
               log_util.log_error(p_proc_name => 'change_attribute_employee',
                                  p_sqlerrm   => SQLERRM);  
               dbms_output.put_line('Атрибути не оновлено: непередбачувана помилка ' ||SQLERRM);
               
        END update_empl;  
        
        ELSE
            log_util.log_finish(p_proc_name => 'change_attribute_employee', p_text => 'Завершення логування процесу change_attribute_employee: атрибути не змінено, не вказано дані для оновлення');
            raise_application_error(-20001,'Не вказано дані для оновлення');
        END IF;  
        
    END change_attribute_employee;
    
------------------------------------------------------------------------------------------------------------  
                             
END util;
