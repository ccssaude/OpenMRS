use xipamanine;
SET @startDate:='2020-03-21';
SET @endDate:='2020-07-20';
SET @location:=208;

select 	rastreio.patient_id,
			p.gender,
           ROUND(DATEDIFF(@endDate,p.birthdate)/365) idade_actual,
		 DATE_FORMAT(data_rastreio,'%d/%m/%Y') as data_rastreio,
		inicio_tb_ficha_cl.tipo_tratamento,
        DATE_FORMAT( inicio_tb_ficha_cl.data_tratamento,'%d/%m/%Y') as data_tratamento,
        IF(programa_tb.patient_id IS NULL,'NAO','SIM') inscrito_programa_tb,
            DATE_FORMAT(inicio_real.data_inicio,'%d/%m/%Y') as data_inicio_tarv,
           DATE_FORMAT(visita.encounter_datetime,'%d/%m/%Y') as data_ult_consulta,
		   DATE_FORMAT(visita.value_datetime,'%d/%m/%Y') as consulta_proximo_marcado,
		pid.identifier NID,
		concat(ifnull(pn.given_name,''),' ',ifnull(pn.middle_name,''),' ',ifnull(pn.family_name,'')) as 'NomeCompleto',
         pad3.county_district AS 'Distrito',
			pad3.address2 AS 'Padministrativo',
			pad3.address6 AS 'Localidade',
			pad3.address5 AS 'Bairro',
			pad3.address1 AS 'PontoReferencia'
from
	(	select 	p.patient_id,max(encounter_datetime) data_rastreio
		from 	patient p
				inner join encounter e on p.patient_id=e.patient_id
				inner join obs o on o.encounter_id=e.encounter_id
		where 	e.encounter_type in (6,9) and e.voided=0 and o.voided=0 and p.voided=0 and
				o.concept_id=23758 and o.value_coded=1065 and 
				e.encounter_datetime between @startDate and @endDate and e.location_id=@location
		group by p.patient_id
	) rastreio
    INNER JOIN person p ON p.person_id=rastreio.patient_id
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
			) pad3 ON pad3.person_id=rastreio.patient_id			
    LEFT JOIN
    /********************* Inicio TARV **********************************************/
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
					  
						UNION
						
						/*Patients with first drugs pick up date set: Recepcao Levantou ARV*/
						SELECT 	p.patient_id,MIN(value_datetime) data_inicio
						FROM 	patient p
								INNER JOIN encounter e ON p.patient_id=e.patient_id
								INNER JOIN obs o ON e.encounter_id=o.encounter_id
						WHERE 	p.voided=0 AND e.voided=0 AND o.voided=0 AND e.encounter_type=52 AND 
								o.concept_id=23866 AND o.value_datetime IS NOT NULL AND 
								o.value_datetime<=@endDate AND e.location_id=@location
						GROUP BY p.patient_id		
					
			) inicio
		GROUP BY patient_id	
	)inicio_real on inicio_real.patient_id=rastreio.patient_id

    /** **************************************** Tratamento TB Ficha Clinica  concept_id = 23739 **************************************** **/
 LEFT JOIN 
	(		   SELECT 	e.patient_id,
			    case o.value_coded
					WHEN 1256  THEN 'INICIA (I)'
					WHEN 1257 THEN 'CONTINUA (C)'
					WHEN 1267 THEN 'FIM (F)'
				ELSE '' END AS tipo_tratamento,
                max(encounter_datetime) as encounter_datetime,
                o.obs_datetime data_tratamento
			FROM 	obs o
			INNER JOIN encounter e ON o.encounter_id=e.encounter_id
			WHERE 	e.encounter_type IN (6,9) AND e.voided=0 AND o.voided=0 AND o.concept_id = 1268 AND o.location_id=@location
            and o.value_coded in (1256,1257,1267) 
            group by patient_id        
	) inicio_tb_ficha_cl on inicio_tb_ficha_cl.patient_id=rastreio.patient_id 
    /* ***************************** ultima inscritcao no progrma_tb ************************/
    LEFT JOIN
		(
			SELECT 	pg.patient_id
			FROM 	patient p INNER JOIN patient_program pg ON p.patient_id=pg.patient_id
			WHERE 	pg.voided=0 AND p.voided=0 AND program_id=5 AND date_enrolled between  @startDate and @endDate AND location_id=@location
		) programa_tb ON programa_tb.patient_id=rastreio.patient_id
        
/*  ** ******************************************  ultima visita  **** ************************************* */ 
		left JOIN		
		(	SELECT ultimavisita.patient_id,ultimavisita.encounter_datetime,o.value_datetime
			FROM
				(	SELECT 	e.patient_id,MAX(encounter_datetime) AS encounter_datetime
					FROM 	encounter e 
							INNER JOIN obs o  ON e.encounter_id=o.encounter_id 		
					WHERE 	e.voided=0 AND o.voided=0 AND e.encounter_type in (6,9) AND 
							e.location_id=@location 
					GROUP BY e.patient_id
				) ultimavisita
				INNER JOIN encounter e ON e.patient_id=ultimavisita.patient_id
				INNER JOIN obs o ON o.encounter_id=e.encounter_id
                where  o.concept_id=1410 AND e.encounter_datetime=ultimavisita.encounter_datetime and			
			  o.voided=0  AND e.voided =0 AND e.encounter_type  in (6,9)  AND e.location_id=@location
		) visita ON visita.patient_id=rastreio.patient_id 
        
	left join patient_identifier pid on pid.patient_id=rastreio.patient_id and pid.identifier_type=2 and pid.preferred=1
	left join person_name pn on pn.person_id=rastreio.patient_id and pn.preferred=1