--СПЕЦИФІКАЦІЯ log_util---------------------------------------------------------
--------------------------------------------------------------------------------
create or replace PACKAGE log_util AS

    PROCEDURE log_start (p_proc_name IN VARCHAR2,
                         p_text      IN VARCHAR2 DEFAULT NULL);

    PROCEDURE log_finish (p_proc_name IN VARCHAR2,
                          p_text      IN VARCHAR2 DEFAULT NULL);
                          
    PROCEDURE log_error (p_proc_name IN VARCHAR2,
                         p_sqlerrm   IN VARCHAR2,
                         p_text      IN VARCHAR2 DEFAULT NULL);
                              
END log_util;
/
--------------------------------------------------------------------------------
--log_util BODY-----------------------------------------------------------------
--------------------------------------------------------------------------------

create or replace PACKAGE body log_util AS

--Процедура log_start-----------------------------------------------------------

    PROCEDURE log_start (p_proc_name IN VARCHAR2,
                         p_text      IN VARCHAR2 DEFAULT NULL) IS
       v_text VARCHAR2(1000);
       
    BEGIN

       IF p_text IS NULL THEN 
       v_text:= 'Старт логування, назва процесу = ' ||p_proc_name;
       ELSE 
       v_text:= p_text;
       END IF;
       
       to_log(p_appl_proc => p_proc_name, 
              p_message   => v_text);
       
    END log_start;

--Процедура log_finish----------------------------------------------------------

    PROCEDURE log_finish (p_proc_name IN VARCHAR2,
                          p_text      IN VARCHAR2 DEFAULT NULL) IS                                   
       v_text VARCHAR2(1000);
       
    BEGIN
      
       IF p_text IS NULL THEN 
       v_text:= 'Завершення логування, назва процесу = ' ||p_proc_name;
       ELSE 
       v_text:= p_text;
       END IF;
       
       to_log(p_appl_proc => p_proc_name, 
              p_message   => v_text);
       
    END log_finish;

--Процедура log_error----------------------------------------------------------

    PROCEDURE log_error (p_proc_name IN VARCHAR2,
                         p_sqlerrm   IN VARCHAR2,
                         p_text      IN VARCHAR2 DEFAULT NULL) IS
       v_text VARCHAR2(1000);
       
    BEGIN
      
       IF p_text IS NULL THEN 
       v_text:= 'В процедурі ' || p_proc_name || ' сталася помилка. ' || p_sqlerrm;
       ELSE 
       v_text:= p_text;
       END IF;
       
       to_log(p_appl_proc => p_proc_name, 
              p_message   => v_text);
       
    END log_error;

--------------------------------------------------------------------------------
END log_util;
/
