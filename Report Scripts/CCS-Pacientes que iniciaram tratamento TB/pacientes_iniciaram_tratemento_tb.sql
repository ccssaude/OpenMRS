


select 	inicio_tb.patient_id,
		data_inicio_tb,
		data_fim_tb,
		inicio_tarv.data_inicio,
		if(inicio_tarv.data_inicio is null,datediff(:endDate,data_inicio_tb),null) dias_tb,
		pid.identifier NID,
		if(inscrito_programa.date_enrolled is null,'NAO','SIM') inscrito_programa_tb,
		if(data_fim_tb is null,round(datediff(curdate(),data_inicio_tb)/30),null) meses_tb,
		pe.address2 as 'PAdministrativo',
		pe.address6 as 'Localidade',
		pe.address5 as 'Bairro',
		pe.address1 as 'PontoReferencia',
        per.gender,
        round(datediff(:endDate,per.birthdate)/365) idade_actual,
        concat(ifnull(pn.given_name,''),' ',ifnull(pn.middle_name,''),' ',ifnull(pn.family_name,'')) as 'NomeCompleto',
        resul_tb_crag.resul_crag as 'Resultado de Crag',
        resul_tb_lam.resul_tb_lam as 'Resultado de Lam',
        resul_cultura.resul_cultura as 'Resultado de Cultura',
        resul_bk.resul_bk as 'Resultado de BK',
        gen_expert.resul_genexpert as 'Resultado de Genexpert'
        
from
	(	select patient_id,max(data_inicio_tb) data_inicio_tb
		from
		(	select 	p.patient_id,o.value_datetime data_inicio_tb
			from 	patient p
					inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on o.encounter_id=e.encounter_id
			where 	e.encounter_type in (6,9) and e.voided=0 and o.voided=0 and p.voided=0 and
					o.concept_id=1113 and e.location_id=:location and 
					o.value_datetime between :startDate and :endDate
			union
			
			select 	patient_id,date_enrolled data_inicio_tb
			from 	patient_program
			where	program_id=5 and voided=0 and date_enrolled between :startDate and :endDate and
					location_id=:location
		) inicio1
		group by patient_id
	) inicio_tb
    
    inner join person per on per.person_id=inicio_tb.patient_id and per.voided=0
        
	inner join patient_identifier pid on pid.patient_id=inicio_tb.patient_id and pid.identifier_type=2
	inner join person_address pe on pe.person_id=inicio_tb.patient_id and pe.preferred=1
	inner join person_name pn on pn.person_id=inicio_tb.patient_id and pn.preferred=1

    
     /**************resultado de gen_expert **********/
    left join (
    SELECT 	e.patient_id,
				CASE o.value_coded
					WHEN 664  THEN 'NEGATIVO'
					WHEN 703  THEN 'POSITIVO'
					 END AS resul_genexpert,
                max(e.encounter_datetime) as data_ult_res_genexpt
			FROM 	obs o
			INNER JOIN encounter e ON e.encounter_id=o.encounter_id
            AND o.concept_id = 23723 
			and	e.encounter_type IN (6,9) AND e.voided=0 AND o.voided=0
            group by patient_id 
		) gen_expert ON gen_expert.patient_id=inicio_tb.patient_id
        
        
        /**************resultado de bk **********/
        left join (
         SELECT 	e.patient_id,
				CASE o.value_coded
					WHEN 664  THEN 'NEGATIVO'
					WHEN 703  THEN 'POSITIVO'
					 END AS resul_bk,
                max(e.encounter_datetime) as data_ult_res_bk
			FROM 	obs o
			INNER JOIN encounter e ON e.encounter_id=o.encounter_id
            AND o.concept_id = 307
			and	e.encounter_type IN (6,9) AND e.voided=0 AND o.voided=0
            group by patient_id 
        )resul_bk ON resul_bk.patient_id = inicio_tb.patient_id
    
    /**************resultado de cultura **********/
    
    
      left join (
         SELECT 	e.patient_id,
				CASE o.value_coded
					WHEN 664  THEN 'NEGATIVO'
					WHEN 703  THEN 'POSITIVO'
					 END AS resul_cultura,
                max(e.encounter_datetime) as data_ult_res_cultura
			FROM 	obs o
			INNER JOIN encounter e ON e.encounter_id=o.encounter_id
            AND o.concept_id =23774
			and	e.encounter_type IN (6,9) AND e.voided=0 AND o.voided=0
            group by patient_id 
        )resul_cultura ON resul_cultura.patient_id = inicio_tb.patient_id
        
        
        /**************resultado de tb lam **********/
        
          left join (
         SELECT 	e.patient_id,
				CASE o.value_coded
					WHEN 664  THEN 'NEGATIVO'
					WHEN 703  THEN 'POSITIVO'
					 END AS resul_tb_lam,
                max(e.encounter_datetime) as data_ult_resul_tb_lam
			FROM 	obs o
			INNER JOIN encounter e ON e.encounter_id=o.encounter_id
            AND o.concept_id =23951
			and	e.encounter_type IN (6,9) AND e.voided=0 AND o.voided=0
            group by patient_id 
        )resul_tb_lam ON resul_tb_lam.patient_id = inicio_tb.patient_id
    
     /**************resultado de tb CRAG **********/
    
        left join (
         SELECT 	e.patient_id,
				CASE o.value_coded
					WHEN 664  THEN 'NEGATIVO'
					WHEN 703  THEN 'POSITIVO'
					 END AS resul_crag,
                max(e.encounter_datetime) as data_ult_resul_tb_crag
			FROM 	obs o
			INNER JOIN encounter e ON e.encounter_id=o.encounter_id
            AND o.concept_id =23952
			and	e.encounter_type IN (6,9) AND e.voided=0 AND o.voided=0
            group by patient_id 
        )resul_tb_crag ON resul_tb_crag.patient_id = inicio_tb.patient_id
    
    
    
    
	left join
	(	select patient_id,max(data_fim_tb) data_fim_tb
		from
		(	select 	p.patient_id,o.value_datetime data_fim_tb
			from 	patient p
					inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on o.encounter_id=e.encounter_id
			where 	e.encounter_type in (6,9) and e.voided=0 and o.voided=0 and p.voided=0 and
					o.concept_id=6120 and e.location_id=:location
			union
			
			select 	patient_id,date_completed data_fim_tb
			from 	patient_program
			where	program_id=5 and voided=0 and location_id=:location and date_completed is not null
		) fim1
		group by patient_id
	) fim on inicio_tb.patient_id=fim.patient_id  and data_fim_tb>data_inicio_tb
	
    left join 
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
)inicio_tarv on inicio_tarv.patient_id=inicio_tb.patient_id

    
	left join 
	(
		select 	patient_id,date_enrolled
		from 	patient_program
		where	program_id=5 and voided=0 and date_enrolled<=:endDate and
				location_id=:location
	) inscrito_programa on inscrito_programa.patient_id=inicio_tb.patient_id
