use xipamanine;
SET :startDate:='2019-12-21';
SET :endDate:='2020-06-20';
SET :location:=208;


SELECT * 
FROM 
( SELECT 	inicio_real.patient_id,
			CONCAT(pid.identifier,' ') AS NID,
            CONCAT(IFNULL(pn.given_name,''),' ',IFNULL(pn.middle_name,''),' ',IFNULL(pn.family_name,'')) AS 'NomeCompleto',
			p.gender,
            ROUND(DATEDIFF(:endDate,p.birthdate)/365) idade_actual,
            DATE_FORMAT(inicio_real.data_inicio,'%d/%m/%Y') as data_inicio,
			DATE_FORMAT(inicio_tpi.data_inicio_tpi ,'%d/%m/%Y') as data_inicio_tpi,
            cv.value_numeric valor_ult_cv,
            -- cv_qualitativa.carga_viral_qualitativa,
            -- cv_qualitativa.data_cv_qualitativa,
            DATE_FORMAT(cv.data_ult_cv,'%d/%m/%Y') as data_ult_cv,
            ultimo_regime.regime,
            DATE_FORMAT(ult_pedido_cv.data_ult_pedido_cv,'%d/%m/%Y') as data_ult_pedido_cv,
            DATE_FORMAT(ultimo_regime.data_regime,'%d/%m/%Y') as data_regime,
            ultima_linha.linhat ultima_linhat,
             DATE_FORMAT(ultima_linha.data_linhat,'%d/%m/%Y') as data_ult_linha,
            IF (cv.data_ult_cv is not null, DATEDIFF(:endDate,cv.data_ult_cv)/30, null) as meses_cv_maior_1000,
            DATEDIFF(:endDate, ultima_linha.data_linhat)/30  as tempo_linha,
            CONCAT( if(inscrito_tb.date_enrolled is null,'','TB '),'',if(inscrito_smi.date_enrolled is null,'','_SMI'),' ',if(inscrito_ccr.date_enrolled is null,'','_CCR')) AS proveniencia,
			telef.value AS telefone,
		    pad3.county_district AS 'Distrito',
			pad3.address2 AS 'Padministrativo',
			pad3.address6 AS 'Localidade',
			pad3.address5 AS 'Bairro',
			pad3.address1 AS 'PontoReferencia' 

			
	FROM	
	(	
    
       SELECT criterio_1.patient_id, criterio_1.data_inicio, ultimavisita.value_datetime as prox_visita
	FROM ( 
       
       select * from (
       SELECT patient_id,MIN(data_inicio) data_inicio 
		FROM
			(	
			
				/*Patients on ART who initiated the ARV DRUGS: ART Regimen Start Date*/
				
						SELECT 	p.patient_id,MIN(e.encounter_datetime) data_inicio
						FROM 	patient p 
								INNER JOIN encounter e ON p.patient_id=e.patient_id	
								INNER JOIN obs o ON o.encounter_id=e.encounter_id
						WHERE 	e.voided=0 AND o.voided=0 AND p.voided=0 AND 
								e.encounter_type IN (18,6,9) AND o.concept_id=1255 AND o.value_coded=1256 AND 
								e.encounter_datetime<=:endDate AND e.location_id=:location
						GROUP BY p.patient_id
				
						UNION
				
						/*Patients on ART who have art start date: ART Start date*/
						SELECT 	p.patient_id,MIN(value_datetime) data_inicio
						FROM 	patient p
								INNER JOIN encounter e ON p.patient_id=e.patient_id
								INNER JOIN obs o ON e.encounter_id=o.encounter_id
						WHERE 	p.voided=0 AND e.voided=0 AND o.voided=0 AND e.encounter_type IN (18,6,9,53) AND 
								o.concept_id=1190 AND o.value_datetime IS NOT NULL AND 
								o.value_datetime<=:endDate AND e.location_id=:location
						GROUP BY p.patient_id

						UNION

						/*Patients enrolled in ART Program: OpenMRS Program*/
						SELECT 	pg.patient_id,MIN(date_enrolled) data_inicio
						FROM 	patient p INNER JOIN patient_program pg ON p.patient_id=pg.patient_id
						WHERE 	pg.voided=0 AND p.voided=0 AND program_id=2 AND date_enrolled<=:endDate AND location_id=:location
						GROUP BY pg.patient_id
									
			) inicio  GROUP BY patient_id	) inicio_2
            
              /* 1. Em TARV há mais de 6 meses*/
            where DATEDIFF(:endDate,inicio_2.data_inicio)/30 >=6 and inicio_2.patient_id not in  (
           /*****************************  excluir as gravidas  ou lactante  *************************************************/
	select patient_id from ( 
				select patient_id,max(date_enrolled) as date_enrolled
					from
						(Select p.patient_id,max(obs_datetime) date_enrolled
						from 	patient p 
								inner join encounter e on p.patient_id=e.patient_id
								inner join obs o on e.encounter_id=o.encounter_id
						where 	p.voided=0 and e.voided=0 and o.voided=0 and concept_id = 1982 and value_coded = 1065 
								and e.encounter_type =6 and o.obs_datetime between date_sub(:endDate, interval 9 MONTH) and  :endDate  and 
								e.location_id=:location
						group by p.patient_id
						
						union
						
						select pp.patient_id,pp.date_enrolled as date_enrolled
						from 	patient_program pp 
						where 	pp.program_id in (3,4,8) and pp.voided=0 and  pp.date_completed is null and
								pp.date_enrolled between  date_sub(:endDate, interval 9 MONTH) and  :endDate  and pp.location_id=:location
                                
						union all 
                        
						select 	pgg.patient_id,max(pgg.date_enrolled) as date_enrolled
						from 	patient pt inner join patient_program pgg on pt.patient_id=pgg.patient_id
						where 	pgg.voided=0 and pt.voided=0 and pgg.program_id=6 and pgg.date_completed is null 
						and pgg.date_enrolled between date_sub(:endDate, interval 18 MONTH) and  :endDate  and pgg.location_id=:location
						group by pgg.patient_id
                        
						) gravida  group by patient_id
            ) gravidas
		
		group by patient_id
	
        )

	) criterio_1
         
        INNER JOIN		
		(	SELECT ultimavisita.patient_id,ultimavisita.encounter_datetime,o.value_datetime,e.location_id
			FROM
				(	SELECT 	p.patient_id,MAX(encounter_datetime) AS encounter_datetime
					FROM 	encounter e 
							INNER JOIN patient p ON p.patient_id=e.patient_id 		
					WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type IN (6,16,9,18,53) AND 
							e.location_id=:location AND e.encounter_datetime<=:endDate
					GROUP BY p.patient_id
				) ultimavisita
				INNER JOIN encounter e ON e.patient_id=ultimavisita.patient_id
				LEFT JOIN obs o ON o.encounter_id=e.encounter_id AND (o.concept_id=5096 OR o.concept_id=1410)AND e.encounter_datetime=ultimavisita.encounter_datetime			
			WHERE  o.voided=0  AND e.voided =0 AND e.encounter_type IN (6,16,9,18,53) AND e.location_id=:location
		) ultimavisita ON ultimavisita.patient_id=criterio_1.patient_id and DATEDIFF(:endDate,ultimavisita.value_datetime) <= 28
       
	)inicio_real
		INNER JOIN person p ON p.person_id=inicio_real.patient_id
          /***********************   4. ultima carga viral nos ultimos 12 meses  *********************************/
      /*******************************************************************************************************/
        LEFT JOIN
        (
        	SELECT ult_cv.patient_id, e.encounter_datetime data_ult_cv, o.value_numeric
			FROM	
				(  SELECT   patient_id , max(data_ult_carga)  data_ult_carga , valor_cv
					FROM
                    (  
						   SELECT 	e.patient_id,
									o.value_numeric valor_cv,
									max(e.encounter_datetime)  data_ult_carga
							FROM 	encounter e
									inner join obs o on e.encounter_id=o.encounter_id
							where 	e.encounter_type in (13,6,9) and e.voided=0 and encounter_datetime between date_sub(:endDate, interval 12 MONTH) and  :endDate  
									and o.voided=0 and o.concept_id=856  and 	e.location_id=:location
							group by e.patient_id 
                    
				    UNION ALL
                
							SELECT 	e.patient_id,
									o.value_numeric valor_cv,
									max(o.obs_datetime)  data_ult_carga
							FROM 	encounter e
									inner join obs o on e.encounter_id=o.encounter_id
							where 	e.encounter_type = 53 and e.voided=0 and o.voided=0 and obs_datetime between date_sub(:endDate, interval 12 MONTH) and  :endDate  
							and o.concept_id=856 and e.location_id=:location
							group by e.patient_id ) all_cv group by patient_id 
						
						) ult_cv
                inner join encounter e on e.patient_id=ult_cv.patient_id
				inner join obs o on o.encounter_id=e.encounter_id 
                where o.obs_datetime=ult_cv.data_ult_carga
			     AND o.concept_id=856 and o.voided=0 AND e.voided=0
			group by patient_id
		) cv on cv.patient_id=inicio_real.patient_id 
        /************************** CV qualitatia *******************************************************/
        left join ( SELECT 	e.patient_id,
				CASE o.value_coded
                WHEN 1306  THEN  'Nivel baixo de detencao'
                WHEN 23814 THEN  'Indectetavel'
                WHEN 23905 THEN  'Menor que 10 copias/ml'
                WHEN 23906 THEN  'Menor que 20 copias/ml'
                WHEN 23907 THEN  'Menor que 40 copias/ml'
                WHEN 23908 THEN  'Menor que 400 copias/ml'
                WHEN 23904 THEN  'Menor que 839 copias/ml'
                ELSE 'OUTRO'
                END  AS carga_viral_qualitativa,
				ult_cv.data_cv_qualitativa,
                encounter_type
                FROM  encounter e 
                inner join	(
							SELECT 	e.patient_id,max(encounter_datetime) as data_cv_qualitativa
							from encounter e inner join obs o on e.encounter_id=o.encounter_id
							where e.encounter_type IN (6,9,13) AND e.voided=0 AND o.voided=0 AND o.concept_id = 1305 
                            and encounter_datetime between date_sub(:endDate, interval 12 MONTH) and  :endDate
							group by patient_id
				) ult_cv 
                on e.patient_id=ult_cv.patient_id
				inner join obs o on o.encounter_id=e.encounter_id 
                 where e.encounter_datetime=ult_cv.data_cv_qualitativa	
				and	e.voided=0  AND e.location_id= :location AND  e.encounter_type in (6,9,13) and
				o.voided=0 AND 	o.concept_id=1305
                group by e.patient_id ) cv_qualitativa on cv_qualitativa.patient_id = inicio_real.patient_id
       /****************************** Ultima linha *****************************************************/
        LEFT JOIN
        (	
        
        SELECT e.patient_id,  
		e.encounter_datetime as data_linhat, 
		case o.value_coded
	    WHEN 21148  THEN 'SEGUNDA LINHA'
		WHEN 21149  THEN 'TERCEIRA LINHA'
		WHEN 21150  THEN 'PRIMEIRA LINHA'
		ELSE '' END AS linhat
        FROM 
        encounter e 
         INNER JOIN (
                   SELECT patient_id, MAX(ult_linha.data_inicio)  as data_inicio_linhat
                   FROM 
							( SELECT patient_id, min(e.encounter_datetime) as data_inicio
								from   encounter e     
                                inner join obs o on o.encounter_id =e.encounter_id
								where e.encounter_type IN (6,9,53) AND e.voided=0 AND o.voided=0 AND o.concept_id = 21151 
                                and e.location_id=:location
                                group by patient_id , o.value_coded ) ult_linha
                   group by patient_id
                     
                   ) ultimo_linhat on ultimo_linhat.patient_id=e.patient_id
                    inner join obs o  ON o.encounter_id=e.encounter_id
				  WHERE	 e.encounter_datetime =ultimo_linhat.data_inicio_linhat and  
                  e.encounter_type IN (6,9,53) AND e.voided=0 AND o.voided=0 AND o.concept_id = 21151 
                  group by patient_id order by patient_id
		) ultima_linha on ultima_linha.patient_id=inicio_real.patient_id 
        
	
	
		
            	/** **************************************** TPI  **************************************** **/
            left join
			(	select patient_id, max(data_inicio_tpi) as data_inicio_tpi
            from ( select e.patient_id,max(value_datetime) data_inicio_tpi
				from	encounter e
						inner join obs o on o.encounter_id=e.encounter_id
				where 	e.voided=0  and
						o.voided=0 and o.concept_id=6128 and e.encounter_type in (6,9,53) and e.location_id=:location
				group by e.patient_id
				
				union
				
				select e.patient_id,max(e.encounter_datetime) data_inicio_tpi
				from	 encounter e 
						inner join obs o on o.encounter_id=e.encounter_id
				where 	e.voided=0 and
						o.voided=0 and o.concept_id=6122 and o.value_coded=1256 and e.encounter_type in (6,9) and e.location_id=:location
				group by e.patient_id
				 ) tpi_ficha_segui_clinc group by patient_id
                 
			) inicio_tpi on inicio_tpi.patient_id=inicio_real.patient_id

                	/*********************          ultimo regime n *****************************************/
        left join ( select e.patient_id,  e.encounter_datetime as data_regime , case o.value_coded
	                    when 1703 then 'AZT+3TC+EFV'
						when 6100 then 'AZT+3TC+LPV/r'
						when 1651 then 'AZT+3TC+NVP'
						when 6324 then 'TDF+3TC+EFV'
						when 6104 then 'ABC+3TC+EFV'
						when 23784 then 'TDF+3TC+DTG'
						when 23786 then 'ABC+3TC+DTG'
						when 6116 then 'AZT+3TC+ABC'
						when 6106 then 'ABC+3TC+LPV/r'
						when 6105 then 'ABC+3TC+NVP'
						when 6108 then 'TDF+3TC+LPV/r'
						when 23790 then 'TDF+3TC+LPV/r+RTV'
						when 23791 then 'TDF+3TC+ATV/r'
						when 23792 then 'ABC+3TC+ATV/r'
						when 23793 then 'AZT+3TC+ATV/r'
						when 23795 then 'ABC+3TC+ATV/r+RAL'
						when 23796 then 'TDF+3TC+ATV/r+RAL'
						when 23801 then 'AZT+3TC+RAL'
						when 23802 then 'AZT+3TC+DRV/r'
						when 23815 then 'AZT+3TC+DTG'
						when 6329 then 'TDF+3TC+RAL+DRV/r'
						when 23797 then 'ABC+3TC+DRV/r+RAL'
						when 23798 then '3TC+RAL+DRV/r'
						when 23803 then 'AZT+3TC+RAL+DRV/r'						
						when 6243 then 'TDF+3TC+NVP'
						when 6103 then 'D4T+3TC+LPV/r'
						when 792 then 'D4T+3TC+NVP'
						when 1827 then 'D4T+3TC+EFV'
						when 6102 then 'D4T+3TC+ABC'						
						when 1311 then 'ABC+3TC+LPV/r'
						when 1312 then 'ABC+3TC+NVP'
						when 1313 then 'ABC+3TC+EFV'
						when 1314 then 'AZT+3TC+LPV/r'
						when 1315 then 'TDF+3TC+EFV'						
						when 6330 then 'AZT+3TC+RAL+DRV/r'						
						when 6102 then 'D4T+3TC+ABC'
						when 6325 then 'D4T+3TC+ABC+LPV/r'
						when 6326 then 'AZT+3TC+ABC+LPV/r'
						when 6327 then 'D4T+3TC+ABC+EFV'
						when 6328 then 'AZT+3TC+ABC+EFV'
						when 6109 then 'AZT+DDI+LPV/r'
						when 6329 then 'TDF+3TC+RAL+DRV/r'
						when 21163 then 'AZT+3TC+LPV/r'						
						when 23799 then 'TDF+3TC+DTG'
						when 23800 then 'ABC+3TC+DTG'
						else 'OUTRO' end as regime
                        from 
                   encounter e 
                   inner join (
                   select patient_id, max(ult_reg.data_inicio_reg)  as data_inicio_reg
                   from 
								( select patient_id, min(e.encounter_datetime) as data_inicio_reg 
								from   encounter e     
                                inner join obs o on o.encounter_id =e.encounter_id
								where e.encounter_type=18 and  o.concept_id=1088  AND e.voided=0 and  o.voided=0 and 
                                 e.location_id=:location
                                group by patient_id , o.value_coded ) ult_reg
                                group by patient_id
                     
                   ) ultimo_reg on ultimo_reg.patient_id=e.patient_id
                    inner join obs o  ON o.encounter_id=e.encounter_id
				  WHERE	 e.encounter_datetime =ultimo_reg.data_inicio_reg and  e.encounter_type =18  and   o.concept_id=1088  AND e.voided=0 
                  and e.location_id=:location
                  group by patient_id order by patient_id
	) ultimo_regime on  ultimo_regime.patient_id = inicio_real.patient_id 
		
        
	 /***************************          Ultimo pedido de cv na ficha clinica      ******************************************/
       left join (
       
        select patient_id, max(e.encounter_datetime) as data_ult_pedido_cv
								from   encounter e     
                                inner join obs o on o.encounter_id =e.encounter_id
								where e.encounter_type in (6,9) and  o.concept_id=23722 and o.value_coded=856  AND e.voided=0 and  o.voided=0 and 
                                 e.location_id=:location
                                group by patient_id  
                         
       ) ult_pedido_cv on ult_pedido_cv.patient_id=inicio_real.patient_id 
       
	/*************************************** Demographic data *********************************************************************/
        LEFT JOIN 
			(	SELECT pad1.*
				FROM person_address pad1
				INNER JOIN 
				(
					SELECT person_id,MIN(person_address_id) id 
					FROM person_address
					WHERE voided=0
					GROUP BY person_id
				) pad2
				WHERE pad1.person_id=pad2.person_id AND pad1.person_address_id=pad2.id
			) pad3 ON pad3.person_id=inicio_real.patient_id				
			LEFT JOIN 			
			(	SELECT pn1.*
				FROM person_name pn1
				INNER JOIN 
				(
					SELECT person_id,MIN(person_name_id) id 
					FROM person_name
					WHERE voided=0
					GROUP BY person_id
				) pn2
				WHERE pn1.person_id=pn2.person_id AND pn1.person_name_id=pn2.id
			) pn ON pn.person_id=inicio_real.patient_id			
			LEFT JOIN
			(       SELECT pid1.*
					FROM patient_identifier pid1
					INNER JOIN
					(
						SELECT patient_id,MIN(patient_identifier_id) id
						FROM patient_identifier
						WHERE voided=0
						GROUP BY patient_id
					) pid2
					WHERE pid1.patient_id=pid2.patient_id AND pid1.patient_identifier_id=pid2.id
			) pid ON pid.patient_id=inicio_real.patient_id
		

	/* ******************************* Telefone **************************** */
	LEFT JOIN (
		SELECT  p.person_id, p.value  
		FROM person_attribute p
        WHERE  p.person_attribute_type_id=9 
           AND p.value IS NOT NULL AND p.value<>'' AND p.voided=0 
	        ) telef  ON telef.person_id = inicio_real.patient_id
/**************************  Proveniencia ***************************************************/

	left join 
			(
				select 	pgg.patient_id,max(pgg.date_enrolled) as date_enrolled
				from 	patient pt inner join patient_program pgg on pt.patient_id=pgg.patient_id
				where 	pgg.voided=0 and pt.voided=0 and pgg.program_id=5 and pgg.date_completed is null 
                and pgg.date_enrolled between date_sub(:endDate, interval 6  MONTH)  and pgg.location_id=:location
				group by pgg.patient_id
			) inscrito_tb on inscrito_tb.patient_id=inicio_real.patient_id

			left join 
			(
				select 	pgg.patient_id,max(pgg.date_enrolled) as date_enrolled
				from 	patient pt inner join patient_program pgg on pt.patient_id=pgg.patient_id
				where 	pgg.voided=0 and pt.voided=0 and pgg.program_id in (3,4,8) and pgg.date_completed is null 
                and pgg.date_enrolled  between date_sub(:endDate, interval 9  MONTH) and  :endDate and pgg.location_id=:location
				group by pgg.patient_id
			) inscrito_smi on inscrito_smi.patient_id=inicio_real.patient_id

			left join 
			(
				select 	pgg.patient_id,max(pgg.date_enrolled) as date_enrolled
						from 	patient pt inner join patient_program pgg on pt.patient_id=pgg.patient_id
						where 	pgg.voided=0 and pt.voided=0 and pgg.program_id=6 and pgg.date_completed is null 
						and pgg.date_enrolled between date_sub(:endDate, interval 18 MONTH) and  :endDate  and pgg.location_id=:location
						group by pgg.patient_id
			) inscrito_ccr on inscrito_ccr.patient_id=inicio_real.patient_id
/****************************************************************************/
	WHERE
        
           /* 3. Não ter resultados de CV nos ultimos 12 meses*/
          cv_qualitativa.carga_viral_qualitativa is null and (
          cv.patient_id is null or
          /*   4. Resultado de CV>1000copias/ml  há mais de 3 meses */
           (cv.value_numeric > 1000 and DATEDIFF(:endDate,cv.data_ult_cv)/30 >3 ) 
           )
                
) activos  where tempo_linha > 6
GROUP BY patient_id