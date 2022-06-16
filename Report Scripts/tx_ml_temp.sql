USE openmrs;
SET @startDate:='2015-01-21';
SET @endDate:='2021-03-20';
SET @location:=208;


SELECT *
FROM
(	SELECT 	inicio_real.patient_id,
				inicio_real.data_inicio,
				pad3.county_district AS 'Distrito' ,
				pad3.address2 AS 'PAdministrativo' ,
				pad3.address6 AS 'Localidade' ,
				pad3.address5 AS 'Bairro' ,
				pad3.address1 AS 'PontoReferencia' ,
				CONCAT(IFNULL(pn.given_name,''), ' ' , IFNULL(pn.middle_name,''),' ',IFNULL(pn.family_name,'')) AS 'NomeCompleto',					
				pid.identifier AS NID,
				p.gender,
                pat.value as telefone,
				ROUND(DATEDIFF(@endDate,p.birthdate)/365) idade_actual,
				saida.encounter_datetime AS data_saida,
				saida.estado,
                ultimo_seguimento.encounter_datetime AS ultimo_seg,
                ultimo_seguimento.value_datetime AS prox_marcad,
			IF(programa.patient_id IS NULL,'NAO','SIM') inscrito_programa
		FROM	
			(SELECT patient_id,data_inicio
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
								e.encounter_datetime<=@endDate AND e.location_id=@location
						GROUP BY p.patient_id
				
						UNION
				
						/*Patients on ART who have art start date: ART Start date*/
						SELECT 	p.patient_id,MIN(value_datetime) data_inicio
						FROM 	patient p
								INNER JOIN encounter e ON p.patient_id=e.patient_id
								INNER JOIN obs o ON e.encounter_id=o.encounter_id
						WHERE 	p.voided=0 AND e.voided=0 AND o.voided=0 AND e.encounter_type IN (18,6,9,53) AND 
								o.concept_id=1190 AND o.value_datetime IS NOT NULL AND 
								o.value_datetime<=@endDate AND e.location_id=@location
						GROUP BY p.patient_id

						UNION

						/*Patients enrolled in ART Program: OpenMRS Program*/
						SELECT 	pg.patient_id,MIN(date_enrolled) data_inicio
						FROM 	patient p INNER JOIN patient_program pg ON p.patient_id=pg.patient_id
						WHERE 	pg.voided=0 AND p.voided=0 AND program_id=2 AND date_enrolled<=@endDate AND location_id=@location
						GROUP BY pg.patient_id
						
						UNION
						
						
						/*Patients with first drugs pick up date set in Pharmacy: First ART Start Date*/
						  SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data_inicio 
						  FROM 		patient p
									INNER JOIN encounter e ON p.patient_id=e.patient_id
						  WHERE		p.voided=0 AND e.encounter_type=18 AND e.voided=0 AND e.encounter_datetime<=@endDate AND e.location_id=@location
						  GROUP BY 	p.patient_id
					  
					  /*	union
						
						Patients with first drugs pick up date set: Recepcao Levantou ARV
						Select 	p.patient_id,min(value_datetime) data_inicio
						from 	patient p
								inner join encounter e on p.patient_id=e.patient_id
								inner join obs o on e.encounter_id=o.encounter_id
						where 	p.voided=0 and e.voided=0 and o.voided=0 and e.encounter_type=52 and 
								o.concept_id=23866 and o.value_datetime is not null and 
								o.value_datetime<=@endDate and e.location_id=@location
						group by p.patient_id   */
					
				
				
			) inicio
		GROUP BY patient_id	
	)inicio1
WHERE data_inicio <=@endDate 
)inicio_real
			INNER JOIN person p ON p.person_id=inicio_real.patient_id
  
            left join person_attribute pat on pat.person_id=inicio_real.patient_id and pat.person_attribute_type_id=9 and pat.value is not null and pat.value<>'' and pat.voided=0
                    
             LEFT JOIN 
             (        
				SELECT patient_id,MAX(encounter_datetime) encounter_datetime, MAX(value_datetime) AS value_datetime --  , source
				FROM
				(
					SELECT ultimofila.patient_id,ultimofila.encounter_datetime,o.value_datetime  -- , 'Fila' as 'source' 
					FROM

					(	SELECT 	p.patient_id,MAX(encounter_datetime) AS encounter_datetime
						FROM 	encounter e 
								INNER JOIN patient p ON p.patient_id=e.patient_id 		
						WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type=18 AND e.location_id=@location AND 
								e.encounter_datetime<=@endDate
						GROUP BY p.patient_id
					) ultimofila
					INNER JOIN encounter e ON e.patient_id=ultimofila.patient_id
					INNER JOIN obs o ON o.encounter_id=e.encounter_id			
					WHERE o.concept_id=5096 AND o.voided=0 AND e.encounter_datetime=ultimofila.encounter_datetime AND 
					e.encounter_type=18 AND e.location_id=@location 
					
                    
					UNION
					
					SELECT 	p.patient_id,MAX(value_datetime) encounter_datetime,DATE_ADD(MAX(value_datetime), INTERVAL 30 DAY) AS value_datetime -- ,  'Recepcao- Levantou ARV' as 'source' 
					FROM 	patient p
							INNER JOIN encounter e ON p.patient_id=e.patient_id
							INNER JOIN obs o ON e.encounter_id=o.encounter_id
					WHERE 	p.voided=0 AND e.voided=0 AND o.voided=0 AND e.encounter_type=52 AND 
							o.concept_id=23866 AND o.value_datetime IS NOT NULL AND 
							o.value_datetime<=@endDate AND e.location_id=@location     
					GROUP BY p.patient_id                 
                    UNION 
                    
                    SELECT ultimaconsulta.patient_id,ultimaconsulta.encounter_datetime,o.value_datetime -- , 'Master Card - Ficha Clinica' as 'source' 
					FROM

					(	SELECT 	p.patient_id,MAX(encounter_datetime) AS encounter_datetime
						FROM 	encounter e 
								INNER JOIN patient p ON p.patient_id=e.patient_id 		
						WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type IN (6,9) AND e.location_id=@location AND 
								e.encounter_datetime<=@endDate
						GROUP BY p.patient_id
					) ultimaconsulta
					INNER JOIN encounter e ON e.patient_id=ultimaconsulta.patient_id
					INNER JOIN obs o ON o.encounter_id=e.encounter_id			
					WHERE o.concept_id=1410 AND o.voided=0 AND e.encounter_datetime=ultimaconsulta.encounter_datetime AND 
					e.encounter_type IN (6,9) AND e.location_id=@location 
				
                    
				) lev_consulta
				GROUP BY patient_id		
                
                ) ultimo_seguimento ON inicio_real.patient_id = ultimo_seguimento.patient_id 
                
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
			LEFT JOIN
			(		
				SELECT 	pg.patient_id,ps.start_date encounter_datetime,location_id,
						CASE ps.state
							WHEN 7 THEN 'TRANSFERIDO PARA'
							WHEN 8 THEN 'SUSPENSO'
							WHEN 9 THEN 'ABANDONO'
							WHEN 10 THEN 'OBITO'
						ELSE 'OUTRO' END AS estado
				FROM 	patient p 
						INNER JOIN patient_program pg ON p.patient_id=pg.patient_id
						INNER JOIN patient_state ps ON pg.patient_program_id=ps.patient_program_id
				WHERE 	pg.voided=0 AND ps.voided=0 AND p.voided=0 AND 
						pg.program_id=2 AND ps.state IN (7,8,9,10) AND ps.end_date IS NULL AND location_id=@location AND ps.start_date<= @endDate
			
			) saida ON saida.patient_id=inicio_real.patient_id
	
			LEFT JOIN
			(
				SELECT 	pg.patient_id
				FROM 	patient p INNER JOIN patient_program pg ON p.patient_id=pg.patient_id
				WHERE 	pg.voided=0 AND p.voided=0 AND program_id=2 AND date_enrolled<=@endDate AND location_id=@location
			) programa ON programa.patient_id=inicio_real.patient_id
	
    where   ( programa.patient_id is null AND Date(ultimo_seguimento.encounter_datetime) > '2020-09-21') 
        or  ( saida.estado in ('TRANSFERIDO PARA','SUSPENSO','ABANDONO','OBITO') 
           AND Date(ultimo_seguimento.encounter_datetime) >  Date(saida.encounter_datetime) AND Date(ultimo_seguimento.encounter_datetime) > '2020-09-21' )
    
	)inicios
			
GROUP BY patient_id