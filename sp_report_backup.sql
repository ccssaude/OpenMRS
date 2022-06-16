
use altomae;
DELIMITER $$
-- Para casa us executar: trocar a variavel @us_name de modo a ter o nome da us
-- SELECT @total_encounter := count(*) FROM altomae.encounter ;
--  SET @us_name:= "alto_mae" ;
--  SET @table_name:= "encounter" ;
--   select @us_name, @table_name,@total_encounter;
--  
--  INSERT INTO report.daily_log(us_name,table_name,n_rows_inserted,total_last_encounter,date)
--                              VALUES (@us_name,@table_name,0, @total_encounter,now());

CREATE PROCEDURE update_backup_reports_db()
BEGIN

       DECLARE total_encounter INT DEFAULT 0;
       DECLARE total_l_encounter INT DEFAULT 0; 
	   DECLARE nome_us  varchar(30) DEFAULT 'alto_mae';
       Declare diff int default 0;
       
	SELECT   COUNT(*) INTO total_encounter FROM   encounter;
	SELECT   total_last_encounter into total_l_encounter FROM    report.daily_log
    where us_name = nome_us order by iddaily_log desc limit 1;
    
    set diff = total_encounter - total_l_encounter;
    IF diff >0  then
     INSERT INTO report.daily_log(us_name,table_name,n_rows_inserted,total_last_encounter,date)
                             VALUES (nome_us,"encounter",diff, total_encounter,now());
   END IF;
END $$
DELIMITER ;