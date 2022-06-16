SELECT * 
FROM 
(SELECT 	inicio_real.patient_id,
			CONCAT(pid.identifier,' ') AS NID,
            CONCAT(IFNULL(pn.given_name,''),' ',IFNULL(pn.middle_name,''),' ',IFNULL(pn.family_name,'')) AS 'NomeCompleto',
			p.gender,
            ROUND(DATEDIFF(:endDate,p.birthdate)/365) idade_actual,
            DATE_FORMAT(inicio_real.data_inicio,'%d/%m/%Y') as data_inicio,
            cd4.cd4,
            cv.carga_viral,
            keypop.populacaochave,
            keypop.data_keypop,
            linha_terapeutica.linhat as linhaterapeutica,
            tipo_dispensa.tipodispensa,
			telef.value AS telefone,
            regime.ultimo_regime,
			DATE_FORMAT(visita.encounter_datetime,'%d/%m/%Y') as data_ult_consulta,
            DATE_FORMAT(visita.value_datetime,'%d/%m/%Y') as consulta_proximo_marcado,
            DATE_FORMAT(fila.encounter_datetime,'%d/%m/%Y') as data_ult_levantamento,
            DATE_FORMAT(fila.value_datetime,'%d/%m/%Y') as fila_proximo_marcado,
			IF(programa.patient_id IS NULL,'NAO','SIM') inscrito_programa,
			IF(DATEDIFF(:endDate,ultimavisita.value_datetime)<=28,'ACTIVO EM TARV','ABANDONO NAO NOTIFICADO') estado,
			IF(DATEDIFF(:endDate,ultimavisita.value_datetime)>28,DATE_FORMAT(DATE_ADD(ultimavisita.value_datetime, INTERVAL 28 DAY),'%d/%m/%Y'),'') dataAbandono,
		    pad3.county_district AS 'Distrito',
			pad3.address2 AS 'Padministrativo',
			pad3.address6 AS 'Localidade',
			pad3.address5 AS 'Bairro',
			pad3.address1 AS 'PontoReferencia'

			
	FROM	
	(	SELECT patient_id,MIN(data_inicio) data_inicio
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
						
						UNION
						
						
						/*Patients with first drugs pick up date set in Pharmacy: First ART Start Date*/
						  SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data_inicio 
						  FROM 		patient p
									INNER JOIN encounter e ON p.patient_id=e.patient_id
						  WHERE		p.voided=0 AND e.encounter_type=18 AND e.voided=0 AND e.encounter_datetime<=:endDate AND e.location_id=:location
						  GROUP BY 	p.patient_id
					  
						UNION
						
						/*Patients with first drugs pick up date set: Recepcao Levantou ARV*/
						SELECT 	p.patient_id,MIN(value_datetime) data_inicio
						FROM 	patient p
								INNER JOIN encounter e ON p.patient_id=e.patient_id
								INNER JOIN obs o ON e.encounter_id=o.encounter_id
						WHERE 	p.voided=0 AND e.voided=0 AND o.voided=0 AND e.encounter_type=52 AND 
								o.concept_id=23866 AND o.value_datetime IS NOT NULL AND 
								o.value_datetime<=:endDate AND e.location_id=:location
						GROUP BY p.patient_id		
					
				
				
			) inicio
		GROUP BY patient_id	
	)inicio_real
		INNER JOIN person p ON p.person_id=inicio_real.patient_id
		  /************************** keypop concept_id = 23703 ****************************/
		INNER JOIN 
		(
			SELECT 	e.patient_id,
				CASE o.value_coded
					WHEN '1377'  THEN 'HSH'
					WHEN '20454' THEN 'PID'
					WHEN '20426' THEN 'REC'
					WHEN '1901'  THEN 'MTS'
					WHEN '23885' THEN 'Outro'
				ELSE '' END AS populacaochave,
				max(encounter_datetime) as data_keypop
			FROM 	obs o
			INNER JOIN encounter e ON e.encounter_id=o.encounter_id
			WHERE 	e.encounter_type IN (6,9,34,35) AND e.voided=0 AND o.voided=0 AND o.concept_id = 23703 AND o.location_id=:location
            group by patient_id
		) keypop ON keypop.patient_id=inicio_real.patient_id and keypop.data_keypop is not null and keypop.data_keypop between :startDate and :endDate
		
        left JOIN		
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
		) ultimavisita ON ultimavisita.patient_id=inicio_real.patient_id
	               
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
		
		left join 
			(
				select 	e.patient_id,
						case o.value_coded
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
						else 'OUTRO' end as ultimo_regime,
						max(e.encounter_datetime)  data_regime
				from encounter e
                   inner join obs o on e.encounter_id= o.encounter_id			
				where 	encounter_type =18 and  o.voided=0 and  e.voided=0 and
						o.concept_id=1088 and o.location_id=:location 
                        group by e.patient_id
			) regime on regime.patient_id=inicio_real.patient_id

		LEFT JOIN
		(
			SELECT 	pg.patient_id
			FROM 	patient p INNER JOIN patient_program pg ON p.patient_id=pg.patient_id
			WHERE 	pg.voided=0 AND p.voided=0 AND program_id=2 AND date_enrolled<=:endDate AND location_id=:location
		) programa ON programa.patient_id=inicio_real.patient_id

     
			/** **************************************** Tipo dispensa  concept_id = 23739 **************************************** **/
    LEFT JOIN 
		(SELECT 	e.patient_id,
				CASE o.value_coded
					WHEN 23888  THEN 'DISPENSA SEMESTRAL'
					WHEN 1098 THEN 'DISPENSA MENSAL'
					WHEN 23720 THEN 'DISPENSA TRIMESTRAL'
				ELSE '' END AS tipodispensa,
                max(encounter_datetime) as data_tipo_dispensa
			FROM 	obs o
			INNER JOIN encounter e ON o.encounter_id=e.encounter_id
			WHERE 	e.encounter_type IN (6,9,53) AND e.voided=0 AND o.voided=0 AND o.concept_id = 23739 AND o.location_id=:location
            group by patient_id
		) tipo_dispensa ON tipo_dispensa.patient_id=inicio_real.patient_id
        
        /** ************************** LinhaTerapeutica concept_id = 21151  * ********************************************** **/
        LEFT JOIN 
		(SELECT 	e.patient_id,
				CASE o.value_coded
					WHEN 21148  THEN 'SEGUNDA LINHA'
					WHEN 21149  THEN 'TERCEIRA LINHA'
					WHEN 21150  THEN 'PRIMEIRA LINHA'
				ELSE '' END AS linhat,
                max(encounter_datetime) as data_ult_linha
			FROM 	obs o
			INNER JOIN encounter e ON o.encounter_id=e.encounter_id
			WHERE 	e.encounter_type IN (6,9,53) AND e.voided=0 AND o.voided=0 AND o.concept_id = 21151 
            group by patient_id
		) linha_terapeutica ON linha_terapeutica.patient_id=inicio_real.patient_id
        
        /****************** ****************************  CD4   ********* *****************************************************/
        LEFT JOIN(  
        	SELECT 	e.patient_id,o.value_numeric cd4,  MAX(encounter_datetime)
			FROM encounter e 
					INNER JOIN obs o ON o.encounter_id=e.encounter_id
			WHERE 	e.voided=0  AND 
					o.voided=0 AND o.concept_id=1695 AND e.encounter_type IN (6,9,53)  
			GROUP BY e.patient_id
		) cd4 ON cd4.patient_id =  inicio_real.patient_id
     

          /* ******************************** ultima carga viral *********** ******************************/
        LEFT JOIN(  
          
          SELECT 	e.patient_id, MAX(encounter_datetime) as encounter_datetime , o.value_numeric as carga_viral  
			FROM	encounter e
					INNER JOIN obs o ON o.encounter_id=e.encounter_id
			WHERE 	e.voided=0   AND e.location_id=:location  AND 
					o.voided=0 AND o.concept_id=856 AND e.encounter_type IN (6,9,53)  
                    		group by e.patient_id
                            
		) cv ON cv.patient_id =  inicio_real.patient_id
	          /* ******************************** ultima levantamento *********** ******************************/
 		left JOIN		
		(	SELECT ultimavisita.patient_id,ultimavisita.encounter_datetime,o.value_datetime
			FROM
				(	SELECT 	e.patient_id,MAX(encounter_datetime) AS encounter_datetime
					FROM 	encounter e 
							INNER JOIN obs o  ON e.encounter_id=o.encounter_id 		
					WHERE 	e.voided=0 AND o.voided=0 AND e.encounter_type =18 AND 
							e.location_id=:location 
					GROUP BY e.patient_id
				) ultimavisita
				INNER JOIN encounter e ON e.patient_id=ultimavisita.patient_id
				INNER JOIN obs o ON o.encounter_id=e.encounter_id
                where  o.concept_id=5096 AND e.encounter_datetime=ultimavisita.encounter_datetime and			
			  o.voided=0  AND e.voided =0 AND e.encounter_type =18  AND e.location_id=:location
		) fila ON fila.patient_id=inicio_real.patient_id 
 

	/*  ** ******************************************  ultima visita  **** ************************************* */ 
		left JOIN		
		(	SELECT ultimavisita.patient_id,ultimavisita.encounter_datetime,o.value_datetime
			FROM
				(	SELECT 	e.patient_id,MAX(encounter_datetime) AS encounter_datetime
					FROM 	encounter e 
							INNER JOIN obs o  ON e.encounter_id=o.encounter_id 		
					WHERE 	e.voided=0 AND o.voided=0 AND e.encounter_type in (6,9) AND 
							e.location_id=:location 
					GROUP BY e.patient_id
				) ultimavisita
				INNER JOIN encounter e ON e.patient_id=ultimavisita.patient_id
				INNER JOIN obs o ON o.encounter_id=e.encounter_id
                where  o.concept_id=1410 AND e.encounter_datetime=ultimavisita.encounter_datetime and			
			  o.voided=0  AND e.voided =0 AND e.encounter_type  in (6,9)  AND e.location_id=:location
		) visita ON visita.patient_id=inicio_real.patient_id 
	
	/* ******************************* Telefone **************************** */
	LEFT JOIN (
		SELECT  p.person_id, p.value  
		FROM person_attribute p
     WHERE  p.person_attribute_type_id=9 
    AND p.value IS NOT NULL AND p.value<>'' AND p.voided=0 
	) telef  ON telef.person_id = inicio_real.patient_id

	WHERE inicio_real.patient_id NOT IN  -- Pacientes que sairam do programa TARV
		(		
			SELECT 	pg.patient_id					
			FROM 	patient p 
					INNER JOIN patient_program pg ON p.patient_id=pg.patient_id
					INNER JOIN patient_state ps ON pg.patient_program_id=ps.patient_program_id
			WHERE 	pg.voided=0 AND ps.voided=0 AND p.voided=0 AND 
					pg.program_id=2 AND ps.state IN (7,8,9,10) AND 
					ps.end_date IS NULL AND location_id=:location AND ps.start_date<=:endDate		
		) and DATEDIFF(:endDate,ultimavisita.value_datetime) <= 28 
) activos
GROUP BY patient_id