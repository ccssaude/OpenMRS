
SELECT   pat.patient_id,pid.identifier , pe.uuid, pn.given_name,pn.middle_name,pn.family_name, estado.estado as estado_tarv ,max(estado.start_date) data_estado
  FROM  patient pat INNER JOIN  patient_identifier pid ON pat.patient_id =pid.patient_id
  INNER JOIN person pe ON pat.patient_id=pe.person_id
  INNER JOIN person_name pn ON pe.person_id=pn.person_id and    pn.voided=0 and pid.preferred=1
  LEFT JOIN
		(		
			SELECT 	pg.patient_id,ps.start_date encounter_datetime,location_id,ps.start_date,ps.end_date,
					CASE ps.state
                        WHEN 6 THEN 'ACTIVO NO PROGRAMA'
						WHEN 7 THEN 'TRANSFERIDO PARA'
						WHEN 8 THEN 'SUSPENSO'
						WHEN 9 THEN 'ABANDONO'
						WHEN 10 THEN 'OBITO'
                        WHEN 29 THEN 'TRANSFERIDO DE'
					ELSE 'OUTRO' END AS estado
			FROM 	patient p 
					INNER JOIN patient_program pg ON p.patient_id=pg.patient_id
					INNER JOIN patient_state ps ON pg.patient_program_id=ps.patient_program_id
			WHERE 	pg.voided=0 AND ps.voided=0 AND p.voided=0 AND 
					pg.program_id=2 AND ps.state IN (6,7,8,9,10,29) AND ps.end_date IS NULL 
	
		
		) estado ON estado.patient_id=pe.person_id  group by pat.patient_id   order by pat.patient_id


