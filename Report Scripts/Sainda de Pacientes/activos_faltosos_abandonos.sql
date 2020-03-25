DELIMITER $$

USE `openmrs_reports`$$

DROP PROCEDURE IF EXISTS `Activos_FaltososAbandonos_saidas`$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Activos_FaltososAbandonos_saidas`()
BEGIN
	/*DECLARACAO DE VARIAVEIS*/
	DECLARE done INT DEFAULT FALSE;
        DECLARE V_dbname,V_provincia,V_distrito,V_us,V_location,V_tipous,tstring VARCHAR(100);
        DECLARE start_date,end_date VARCHAR(10);
        DECLARE lev,seg VARCHAR(15);
        DECLARE tint INT(4);
        DECLARE tdate1,tdate2 VARCHAR(45);
        DECLARE cur CURSOR FOR SELECT dbname,provincia,distrito,us,location_id,tipous FROM openmrs_reports.`db_inhambane`;
        DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
	SET start_date ='2018-09-21',end_date = '2019-09-20';
	
/*INICIALIZACAO DE TABELAS*/	
	
	DROP TABLE IF EXISTS openmrs_reports.inicio_tarv;
	CREATE TABLE openmrs_reports.`inicio_tarv` (
	`patient_id` INT(11) NOT NULL DEFAULT '0',
	`datainiciotarv` DATETIME DEFAULT NULL
		) ENGINE=INNODB DEFAULT CHARSET=utf8;
		
	DROP TABLE IF EXISTS openmrs_reports.em_tarv;
	CREATE TABLE openmrs_reports.`em_tarv` (
	`site` VARCHAR(50) NULL DEFAULT '',
	`patient_id` INT(11) NOT NULL DEFAULT '0'
		) ENGINE=INNODB DEFAULT CHARSET=utf8;		
	
	
	DROP TABLE IF EXISTS openmrs_reports.consultas_clinicas;
	CREATE TABLE openmrs_reports.`consultas_clinicas` (
	`patient_id` INT(11) NOT NULL DEFAULT '0',
	`dataconsulta` DATETIME DEFAULT NULL
	) ENGINE=INNODB DEFAULT CHARSET=utf8;
	
	DROP TABLE IF EXISTS openmrs_reports.numero_consultas_clinicas;
	CREATE TABLE openmrs_reports.`numero_consultas_clinicas` (
	`patient_id` INT(11) NOT NULL DEFAULT '0',
	`total` INT(3) NOT NULL DEFAULT '0'
	) ENGINE=INNODB DEFAULT CHARSET=utf8;
	
	DROP TABLE IF EXISTS openmrs_reports.levantamentos;
	CREATE TABLE openmrs_reports.levantamentos (
	`patient_id` INT(11) NOT NULL DEFAULT '0',
	`datalevantamento` DATETIME DEFAULT NULL,
	`dataproximolevantamento` DATETIME DEFAULT NULL
	) ENGINE=INNODB DEFAULT CHARSET=utf8;
	
	
		
	DROP TABLE IF EXISTS openmrs_reports.lista_activos;
	CREATE TABLE openmrs_reports.lista_activos (
	`site` VARCHAR(50) NOT  NULL DEFAULT '',
	`patient_id` INT(11) NOT NULL DEFAULT '0',
	`nid` VARCHAR(50) DEFAULT '',
	`name` VARCHAR(50) DEFAULT '',
	`apelido` VARCHAR(50) DEFAULT '',
	`birthdate` DATETIME DEFAULT NULL,
	`dateofinit` DATETIME DEFAULT NULL,
	`age` DECIMAL(9,0) DEFAULT NULL,
	`sex` VARCHAR(5)  DEFAULT NULL,
	 FacilityType VARCHAR(10) NOT NULL DEFAULT '',
	 `dataultimolevantamento` DATETIME DEFAULT NULL,
	 `dataultimaconsulta` DATETIME DEFAULT NULL
	 ) ENGINE=INNODB DEFAULT CHARSET=utf8;
		
	DROP TABLE IF EXISTS openmrs_reports.lista_faltososabandonos;
	CREATE TABLE openmrs_reports.lista_faltososabandonos (
	`site` VARCHAR(50) NOT  NULL DEFAULT '',
	`patient_id` INT(11) NOT NULL DEFAULT '0',
	`nid` VARCHAR(50) DEFAULT '',
	`name` VARCHAR(50) DEFAULT '',
	`apelido` VARCHAR(50) DEFAULT '',
	`birthdate` DATETIME DEFAULT NULL,
	`dateofinit` DATETIME DEFAULT NULL,
	`age` DECIMAL(9,0) DEFAULT NULL,
	`sex` VARCHAR(5)  DEFAULT NULL,
	 FacilityType VARCHAR(10) NOT NULL DEFAULT '',
	 `dataultimolevantamento` DATETIME DEFAULT NULL,
	 DiasDepoisLevantamento INT NULL DEFAULT '0',
	 DiasDepoisDataProximoLev INT NULL DEFAULT '0',
	 `dataultimaconsulta` DATETIME DEFAULT NULL,
	 Distrito VARCHAR(50) DEFAULT '',
	 PAdministrativo VARCHAR(50) DEFAULT '',
	 Localidade VARCHAR(50) DEFAULT '',
	 Bairro VARCHAR(50) DEFAULT '',
	 PontoReferencia VARCHAR(50) DEFAULT '',
	 estado VARCHAR(50) DEFAULT '',
     valor_ultima_carga  VARCHAR(50) DEFAULT ''
	 ) ENGINE=INNODB DEFAULT CHARSET=utf8;	
	 
	 /*INICIO DO CICLO*/	
		
	OPEN cur;
	
	curLoop: LOOP
         FETCH  cur INTO V_dbname,V_provincia,V_distrito,V_us,V_location,V_tipous;
	/*FETCH NEXT FROM cur INTO dbname;*/
        IF done THEN
	  SELECT 'FIM';
         LEAVE curLoop;
	  CLOSE cur;
    
	ELSE
	
	/* INICIOS DE TARV NO PERIODO DE REPORT */
		DELETE FROM openmrs_reports.inicio_tarv;
		SET @SQL := CONCAT('INSERT INTO openmrs_reports.inicio_tarv ', 
		'SELECT DISTINCT patient_id,datainiciotarv FROM
 
		(SELECT DISTINCT patient_id,MIN(datainiciotarv) datainiciotarv
		FROM
			( 
			
			SELECT    e.patient_id,MIN(e.encounter_datetime) datainiciotarv
			FROM     ',TRIM(V_dbname),'.encounter e INNER JOIN ',TRIM(V_dbname),'.obs o ON o.encounter_id=e.encounter_id
			WHERE   e.voided=0 AND o.voided=0 AND 
											e.encounter_type IN (6,9) AND o.concept_id=1255 AND o.value_coded=1256 
			GROUP BY e.patient_id
			UNION
			
			SELECT    e.patient_id,MIN(o.value_datetime) datainiciotarv
			FROM      ',TRIM(V_dbname),'.encounter e INNER JOIN ',TRIM(V_dbname),'.obs o ON e.encounter_id=o.encounter_id
			WHERE     e.voided=0 AND o.voided=0 AND e.encounter_type IN (6,9) AND 
											o.concept_id=1190
			GROUP BY e.patient_id
			UNION
			 
			SELECT    patient_id,date_enrolled datainiciotarv
			FROM      ',TRIM(V_dbname),'.patient_program
			WHERE   voided=0 AND program_id=2
						
			UNION
						
						
			SELECT        patient_id, MIN(encounter_datetime) AS datainiciotarv 
			FROM          ',TRIM(V_dbname),'.encounter 
			WHERE          encounter_type=18 AND voided=0 
			GROUP BY      patient_id
		) inicios
	GROUP BY patient_id 
    
	) iniciotarv');
		PREPARE stmt FROM @SQL;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
	/*Estado do paciente*/
DROP TABLE IF EXISTS openmrs_reports.estadopaciente;
SET @SQL := CONCAT('create table if not exists openmrs_reports.estadopaciente
     SELECT DISTINCT
	"',TRIM(V_us),'" AS site ,
	`pe`.`person_id` AS `patient_id`,
		(CASE `ps`.`state`
			WHEN 7 THEN ','"TRANSFERIDO PARA"','
			WHEN 8 THEN ','"SUSPENSO"','
			WHEN 9 THEN ','"ABANDONO"','
			WHEN 10 THEN ','"OBITO"','
			 ELSE ','"ACTIVO"',' 
			 
           
        END) AS `estado`,
	
	if(ps.state in (7,8,9,10),`ps`.`start_date`,if(pp2.date_enrolled is not null,pp2.date_enrolled,pp1.date_enrolled)) AS dataestado	
    FROM
        (((',TRIM(V_dbname),'.`person` `pe`
        
       LEFT JOIN ',TRIM(V_dbname),'.`patient_program` `pp1` ON (((`pe`.`person_id` = `pp1`.`patient_id`)
            AND (`pp1`.`voided` = 0)
            AND (`pp1`.`program_id` = 1))))
	LEFT JOIN ',TRIM(V_dbname),'.`patient_program` `pp2` ON (((`pe`.`person_id` = `pp2`.`patient_id`)
            AND (`pp2`.`program_id` = 2))))
       left JOIN ',TRIM(V_dbname),'.`patient_state` `ps` ON (((IF(`pp2`.`patient_program_id` IS NOT NULL,`pp2`.`patient_program_id`,`pp1`.`patient_program_id`) = `ps`.`patient_program_id`)
            AND (`ps`.`voided` = 0) AND (ps.end_date IS NULL))))
       ORDER BY `pe`.`person_id`');
		PREPARE stmt FROM @SQL;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
/* LIMPEZA DO ESTADO DE PACIENTE */		
DROP TABLE IF EXISTS openmrs_reports.estado_nao_activo;
CREATE TABLE IF NOT EXISTS openmrs_reports.estado_nao_activo SELECT patient_id FROM estadopaciente WHERE TRIM(estado)!='ACTIVO';		
DELETE FROM estadopaciente WHERE TRIM(estado)='ACTIVO' AND patient_id IN (SELECT patient_id FROM estado_nao_activo WHERE dataestado IS NOT NULL); 
	
		
	/* em_tarv */
	DELETE FROM openmrs_reports.em_tarv;
		SET @SQL := CONCAT('INSERT INTO openmrs_reports.em_tarv ', 
		'SELECT DISTINCT "',TRIM(V_us),'" AS site , it.patient_id FROM
openmrs_reports.inicio_tarv it
INNER JOIN 
(SELECT DISTINCT
        `e`.`patient_id`
     FROM
        ',TRIM(V_dbname),'.`encounter` `e` LEFT JOIN ',TRIM(V_dbname),'.`obs` `o` ON (`e`.`patient_id` = `o`.`person_id`)
      WHERE (`e`.`encounter_id` = `o`.`encounter_id`)
            AND (`o`.`concept_id` = 5096) 
			AND (`e`.`encounter_type` = 18)
            AND (`e`.`voided` = 0) 
			AND ((TIMESTAMPDIFF(DAY, `e`.`encounter_datetime`, "',TRIM(end_date),'")<=99) OR (TIMESTAMPDIFF(DAY, `o`.`value_datetime`, "',TRIM(end_date),'")<=59))
UNION  
# SEGUIMENTOS
SELECT DISTINCT
        `e`.`patient_id`
		
    FROM
        ',TRIM(V_dbname),'.`encounter` `e` LEFT JOIN ',TRIM(V_dbname),'.`obs` `o` ON (`e`.`patient_id` = `o`.`person_id`)
            WHERE (`e`.`encounter_id` = `o`.`encounter_id`)
            AND (`o`.`concept_id` = 1410) 
			AND (`e`.`encounter_type` in (6 , 9))
            AND (`e`.`voided` = 0) 
			AND ((TIMESTAMPDIFF(DAY, `e`.`encounter_datetime`, "',TRIM(end_date),'")<=198) OR (TIMESTAMPDIFF(DAY, `o`.`value_datetime`, "',TRIM(end_date),'")<=59))
 ) CurrentlyReceivingART
ON it.patient_id = CurrentlyReceivingART.patient_id
WHERE it.datainiciotarv <= "',TRIM(end_date),'" and it.patient_id not in (select distinct patient_id from openmrs_reports.estadopaciente WHERE estado != "ACTIVO" and dataestado <= "',TRIM(end_date),'")');
                PREPARE stmt FROM @SQL;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;	
		
	
/* CONSULTAS CLINICAS */
		DELETE FROM openmrs_reports.consultas_clinicas;
		SET @SQL := CONCAT('INSERT INTO openmrs_reports.consultas_clinicas(patient_id,dataconsulta)
SELECT DISTINCT consultas.patient_id, dataconsulta FROM
(
			 /* Data da consulta*/			
			SELECT        patient_id, encounter_datetime dataconsulta 
			FROM          ',TRIM(V_dbname),'.encounter 
			WHERE          encounter_type IN (5,6,7,9) AND voided=0 
			AND encounter_datetime <= "',TRIM(end_date),'"
   ) consultas		
INNER JOIN
openmrs_reports.inicio_tarv a
 ON (consultas.patient_id = a.patient_id)
 ORDER BY consultas.patient_id, dataconsulta');
		PREPARE stmt FROM @SQL;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
		
/* Ultima Consulta */
		DROP TABLE IF EXISTS openmrs_reports.UltimaConsulta;
		SET @SQL := CONCAT('CREATE TABLE IF NOT EXISTS openmrs_reports.UltimaConsulta
		SELECT patient_id, Max(dataconsulta) as dataconsulta FROM consultas_clinicas group by patient_id');
		PREPARE stmt FROM @SQL;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;		
/* LEVANTAMENTOS */
DELETE FROM openmrs_reports.levantamentos;
SET @SQL := CONCAT('INSERT INTO openmrs_reports.levantamentos(patient_id,datalevantamento,dataproximolevantamento)
SELECT DISTINCT 
       	`pi`.patient_id,
	 CAST(`e`.`encounter_datetime` AS DATE) AS `datalevantamento`,
         CAST(`o2`.`value_datetime` AS DATE) AS `dataproximolevantamento`
     FROM
        ((',TRIM(V_dbname),'.`patient_identifier` `pi` 
        JOIN ',TRIM(V_dbname),'.`encounter` `e` ON (((`pi`.`patient_id` = `e`.`patient_id`)
            AND (`e`.`encounter_type` = 18) AND (`pi`.`identifier_type` = 2)
            AND (`e`.`voided` = 0))))
	LEFT JOIN ',TRIM(V_dbname),'.`obs` `o2` ON (((`e`.`patient_id` = `o2`.`person_id`)
            AND (`e`.`encounter_id` = `o2`.`encounter_id`)
            AND (`o2`.`concept_id` = 5096))))
         WHERE  CAST(`e`.`encounter_datetime` AS DATE) <= "',TRIM(end_date),'"  AND o2.voided=0 
         ORDER BY `pi`.patient_id, CAST(`e`.`encounter_datetime` AS DATE)');
		PREPARE stmt FROM @SQL;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
        
	/* Ultimo Levantamento */
		DROP TABLE IF EXISTS openmrs_reports.UltimoLevantamento;
		SET @SQL := CONCAT('CREATE TABLE IF NOT EXISTS openmrs_reports.UltimoLevantamento
		select last_lev.patient_id,last_lev.datalevantamento,l.dataproximolevantamento FROM
		(SELECT patient_id, Max(datalevantamento) as datalevantamento FROM openmrs_reports.levantamentos group by patient_id) last_lev
		INNER JOIN
		openmrs_reports.levantamentos l ON last_lev.patient_id=l.patient_id
		WHERE last_lev.datalevantamento=l.datalevantamento');
		PREPARE stmt FROM @SQL;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;	
        
	/* Ultimo carga viral */
		DROP TABLE IF EXISTS openmrs_reports.carga_viral;
		SET @SQL := CONCAT('CREATE TABLE IF NOT EXISTS openmrs_reports.carga_viral
		select it.patient_id,carga2.valor_ultima_carga  from openmrs_reports.inicio_tarv it
        left join
		(	select patient_id,max(data_ultima_carga) data_ultima_carga,max(value_numeric) valor_ultima_carga
			from	
				(	select 	e.patient_id,
							max(o.obs_datetime) data_ultima_carga
					from 	 ',TRIM(V_dbname),'.encounter e
							inner join  ',TRIM(V_dbname),'.obs o on e.encounter_id=o.encounter_id
					where 	e.encounter_type in (13,6,9) and e.voided=0 and
							o.voided=0 and o.concept_id=856 and   CAST(e.encounter_datetime AS DATE) <= "',TRIM(end_date),'"
                            group by e.patient_id
				) cv
				inner join  ',TRIM(V_dbname),'.obs o on o.person_id=cv.patient_id and o.obs_datetime=cv.data_ultima_carga
			where o.concept_id=856 and o.voided=0
			group by patient_id
		) carga2 on it.patient_id=carga2.patient_id');
		PREPARE stmt FROM @SQL;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;	
																					
/*Lista de activos*/
		
		SET @SQL := CONCAT('INSERT INTO openmrs_reports.lista_activos ', 
		'select et.site,et.patient_id,pi.identifier as nid,
		pn.given_name as name,pn.family_name as apelido,
		pe.birthdate,it.datainiciotarv as dateofinit,
		TIMESTAMPDIFF(YEAR,pe.birthdate, "',TRIM(end_date),'") as age,pe.gender as sex,
		"',TRIM(V_tipous),'" as FacilityType,ul.datalevantamento as dataultimolevantamento,
		uc.dataconsulta as dataultimaconsulta
from ((((((openmrs_reports.em_tarv et INNER JOIN ',TRIM(V_dbname),'.patient_identifier pi ON pi.patient_id = et.patient_id AND pi.identifier_type=2)
	INNER JOIN ',TRIM(V_dbname),'.person pe ON pe.person_id = et.patient_id)
	inner join openmrs_reports.inicio_tarv it on (et.patient_id=it.patient_id and et.site="',TRIM(V_us),'"))
	left join ',TRIM(V_dbname),'.person_name pn on (et.patient_id=pn.person_id and et.site="',TRIM(V_us),'"))
	left join openmrs_reports.UltimoLevantamento ul on (et.patient_id=ul.patient_id and et.site="',TRIM(V_us),'"))
	left join openmrs_reports.UltimaConsulta uc on (et.patient_id=uc.patient_id and et.site="',TRIM(V_us),'"))');
		PREPARE stmt FROM @SQL;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
		
		
/*Dados Demograficos*/
		DROP TABLE IF EXISTS  openmrs_reports.Demografia;
		SET @SQL := CONCAT('create table  openmrs_reports.Demografia ', 
		'select it.patient_id ,
		                pad3.county_district  AS Distrito,
				pad3.address2 AS PAdministrativo,
				pad3.address6 AS Localidade,
				pad3.address5 AS Bairro,
				pad3.address1 AS PontoReferencia
		
from openmrs_reports.inicio_tarv it 
     LEFT JOIN 
			(	SELECT pad1.*
				FROM ',TRIM(V_dbname),'.person_address pad1
				INNER JOIN 
				(
					SELECT person_id,MIN(person_address_id) id 
					FROM ',TRIM(V_dbname),'.person_address
					WHERE voided=0
					GROUP BY person_id
				) pad2
				WHERE pad1.person_id=pad2.person_id AND pad1.person_address_id=pad2.id
			) pad3 ON pad3.person_id=it.patient_id	');
			
		PREPARE stmt FROM @SQL;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
/*Lista de faltosos e abandonos*/
		
		SET @SQL := CONCAT('INSERT INTO openmrs_reports.lista_faltososabandonos ', 
		'select DISTINCT ep.site,ep.patient_id,pi.identifier as nid,
		pn.given_name as name,pn.family_name as apelido,
		pe.birthdate,it.datainiciotarv as dateofinit,
		TIMESTAMPDIFF(YEAR,pe.birthdate, "',TRIM(end_date),'") as age,pe.gender as sex,
		"',TRIM(V_tipous),'" as FacilityType,ul.datalevantamento as dataultimolevantamento,TIMESTAMPDIFF(day,ul.datalevantamento,"',TRIM(end_date),'") as DiasDepoisLevantamento, TIMESTAMPDIFF(day,ul.dataproximolevantamento,"',TRIM(end_date),'") as DiasDepoisDataProximoLev,
		uc.dataconsulta as dataultimaconsulta,
		dem.Distrito,
		dem.PAdministrativo,
		dem.Localidade,
		dem.Bairro,
		dem.PontoReferencia,
		ep.estado,
        cv.valor_ultima_carga
		
from ((((((((openmrs_reports.estadopaciente ep INNER JOIN ',TRIM(V_dbname),'.patient_identifier pi ON pi.patient_id = ep.patient_id AND pi.identifier_type=2)
	INNER JOIN ',TRIM(V_dbname),'.person pe ON pe.person_id = ep.patient_id)
	inner join openmrs_reports.inicio_tarv it on (ep.patient_id=it.patient_id and ep.site="',TRIM(V_us),'"))
	left join ',TRIM(V_dbname),'.person_name pn on (ep.patient_id=pn.person_id and ep.site="',TRIM(V_us),'"))
	left join openmrs_reports.UltimoLevantamento ul on (ep.patient_id=ul.patient_id and ep.site="',TRIM(V_us),'"))
	left join openmrs_reports.Demografia dem on (ep.patient_id=dem.patient_id and ep.site="',TRIM(V_us),'"))
	left join openmrs_reports.UltimaConsulta uc on (ep.patient_id=uc.patient_id and ep.site="',TRIM(V_us),'"))
    left join openmrs_reports.carga_viral cv  on (ep.patient_id=cv.patient_id and ep.site="',TRIM(V_us),'"))
	WHERE ( Trim(ep.estado)  in ("ABANDONO","TRANSFERIDO PARA","OBITO") )
	OR (Trim(ep.estado)="ACTIVO" and ep.patient_id not in (select distinct patient_id from openmrs_reports.em_tarv))');
		PREPARE stmt FROM @SQL;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
			
	
	END IF;
 END LOOP;
 CLOSE cur;	
END$$

DELIMITER ;