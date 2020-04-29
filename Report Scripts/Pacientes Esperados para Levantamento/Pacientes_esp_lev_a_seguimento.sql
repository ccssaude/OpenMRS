use reports;
SET @startDate:='2020-01-25';
SET @endDate:='2020-01-30';
SET @location:=208;

Select 	distinct 	
			concat(ifnull(pn.given_name,''),' ',ifnull(pn.middle_name,''),' ',ifnull(pn.family_name,'')) as 'NomeCompleto',
			pid.identifier as NID,
			p.gender,
            round(datediff(curdate(),p.birthdate)/365) idade_actual,
           DATE_FORMAT(iniciotarv.data_inicio,'%d/%m/%Y'),    
			DATE_FORMAT(visita.encounter_datetime,'%d/%m/%Y') as 'data_visita',
			DATE_FORMAT(visita.value_datetime,'%d/%m/%Y')  as 'data_proxima',
            regimeFila.ultimo_regime as regimeFila,
			pe.county_district as 'Distrito',
			pe.address2 as 'PAdministrativo',
			pe.address6 as 'Localidade',
			pe.address5 as 'Bairro',
			pe.address1 as 'PontoReferencia',
			pat.value as Telefone	,
            tel_confidente.telefone_confidente  as telefone_confidente
	from
		(
		Select ult_levantamento.patient_id,ult_levantamento.encounter_datetime,o.value_datetime,e.location_id,e.encounter_id
		from

			(	select 	p.patient_id,max(encounter_datetime) as encounter_datetime
				from 	encounter e 
						inner join patient p on p.patient_id=e.patient_id 		
				where 	e.voided=0 and p.voided=0 and e.encounter_type=18 
				group by p.patient_id
			) ult_levantamento
			inner join encounter e on e.patient_id=ult_levantamento.patient_id
			inner join obs o on o.encounter_id=e.encounter_id			
			where o.concept_id=5096 and o.voided=0 and e.encounter_datetime=ult_levantamento.encounter_datetime and 
			e.encounter_type =18 and o.value_datetime between @startDate and @endDate and e.location_id=@location 
		) visita 
		inner join person p on p.person_id=visita.patient_id
		left join 
			(	select pad1.*
				from person_address pad1
				inner join 
				(
					select person_id,min(person_address_id) id 
					from person_address
					where voided=0
					group by person_id
				) pad2
				where pad1.person_id=pad2.person_id and pad1.person_address_id=pad2.id
			) pe on pe.person_id=visita.patient_id
	   left join
(	

	select p.patient_id, o.value_text  as telefone_confidente
			from	patient p
					inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on o.encounter_id=e.encounter_id
			where 	e.voided=0 and p.voided=0 and 
					o.voided=0 and o.concept_id=6224 and e.encounter_type =53  and e.voided=0
	
) tel_confidente on tel_confidente.patient_id = visita.patient_id
		left join 			
			(	select pn1.*
				from person_name pn1
				inner join 
				(
					select person_id,min(person_name_id) id 
					from person_name
					where voided=0
					group by person_id
				) pn2
				where pn1.person_id=pn2.person_id and pn1.person_name_id=pn2.id
			) pn on pn.person_id=visita.patient_id		
			left join
			(       select pid1.*
					from patient_identifier pid1
					inner join
					(
						select patient_id,min(patient_identifier_id) id
						from patient_identifier
						where voided=0
						group by patient_id
					) pid2
					where pid1.patient_id=pid2.patient_id and pid1.patient_identifier_id=pid2.id
			) pid on pid.patient_id=visita.patient_id
        
		left join 
		(
			select 	o.person_id,
					 CASE o.value_coded
                WHEN 1651 THEN 'AZT+3TC+NVP'
                WHEN 6324 THEN 'TDF+3TC+EFV'
                WHEN 1703 THEN 'AZT+3TC+EFV'
                WHEN 6243 THEN 'TDF+3TC+NVP'
                WHEN 6104 THEN 'ABC+3TC+EFV'
                WHEN 23784 THEN 'TDF+3TC+DTG'
                WHEN 21163 THEN 'AZT+3TC+LPV/r (2ª Linha)'
                WHEN 23786 THEN 'ABC+3TC+DTG'
                WHEN 1311 THEN 'ABC+3TC+LPV/r (2ª Linha)'
                WHEN 6234 THEN 'ABC+TDF+LPV/r'
                WHEN 1314 THEN 'AZT+3TC+LPV/r (2ª Linha)'
                WHEN 6103 THEN 'D4T+3TC+LPV/r'
                WHEN 23790 THEN 'TDF+3TC+LPV/r+RTV'
                WHEN 6107 THEN 'TDF+AZT+3TC+LPV/r'
                WHEN 23791 THEN 'TDF+3TC+ATV/r'
                WHEN 23792 THEN 'ABC+3TC+ATV/r'
                WHEN 23793 THEN 'AZT+3TC+ATV/r'
                WHEN 23797 THEN 'ABC+3TC+DRV/r+RAL'
                WHEN 6329 THEN 'TDF+3TC+RAL+DRV/r'
                WHEN 23815 THEN 'AZT+3TC+DTG'
                WHEN 23803 THEN 'AZT+3TC+RAL+DRV/r'
                WHEN 23802 THEN 'AZT+3TC+DRV/r'
                WHEN 6329 THEN 'TDF+3TC+RAL+DRV/r'
                WHEN 23801 THEN 'AZT+3TC+RAL'
                WHEN 23798 THEN '3TC+RAL+DRV/r'
                WHEN 1313 THEN 'ABC+3TC+EFV (2ª Linha)'
                WHEN 23799 THEN 'TDF+3TC+DTG (2ª Linha)'
                WHEN 23800 THEN 'ABC+3TC+DTG (2ª Linha)'
                WHEN 792 THEN 'D4T+3TC+NVP'
                WHEN 1827 THEN 'D4T+3TC+EFV'
                WHEN 6102 THEN 'D4T+3TC+ABC'
                WHEN 6116 THEN 'AZT+3TC+ABC'
                WHEN 6108 THEN 'TDF+3TC+LPV/r(2ª Linha)'
                WHEN 6100 THEN 'AZT+3TC+LPV/r'
                WHEN 6106 THEN 'ABC+3TC+LPV'
                WHEN 6330 THEN 'AZT+3TC+RAL+DRV/r (3ª Linha)'
                WHEN 6105 THEN 'ABC+3TC+NVP'
                WHEN 6102 THEN 'D4T+3TC+ABC'
                WHEN 6325 THEN 'D4T+3TC+ABC+LPV/r (2ª Linha)'
                WHEN 6326 THEN 'AZT+3TC+ABC+LPV/r (2ª Linha)'
                WHEN 6327 THEN 'D4T+3TC+ABC+EFV (2ª Linha)'
                WHEN 6328 THEN 'AZT+3TC+ABC+EFV (2ª Linha)'
                WHEN 6109 THEN 'AZT+DDI+LPV/r (2ª Linha)'
                ELSE 'OUTRO'
            END  AS ultimo_regime,
					ultimo_lev.encounter_datetime data_regime,
                    e.encounter_id
			FROM 	obs o,				
					(	SELECT p.patient_id,MAX(encounter_datetime) AS encounter_datetime
						FROM 	patient p
								INNER JOIN encounter e ON p.patient_id=e.patient_id								
						WHERE 	encounter_type=18 AND e.voided=0 AND
								e.location_id=@location and p.voided=0
						GROUP BY patient_id
					) ultimo_lev, encounter e 
			WHERE 	o.person_id=ultimo_lev.patient_id AND o.obs_datetime=ultimo_lev.encounter_datetime AND o.voided=0 AND 
					o.concept_id=1088 and o.location_id=@location and e.patient_id=ultimo_lev.patient_id
                    
		) regimeFila on regimeFila.encounter_id=visita.encounter_id and regimeFila.person_id=visita.patient_id
        
        left join ( 
        
        Select patient_id,min(data_inicio) data_inicio
		from
			(	
			
				/*Patients on ART who initiated the ARV DRUGS: ART Regimen Start Date*/
				
						Select 	p.patient_id,min(e.encounter_datetime) data_inicio
						from 	patient p 
								inner join encounter e on p.patient_id=e.patient_id	
								inner join obs o on o.encounter_id=e.encounter_id
						where 	e.voided=0 and o.voided=0 and p.voided=0 and 
								e.encounter_type in (18,6,9) and o.concept_id=1255 and o.value_coded=1256 and 
								e.encounter_datetime<=@endDate and e.location_id=@location
						group by p.patient_id
				
						union
				
						/*Patients on ART who have art start date: ART Start date*/
						Select 	p.patient_id,min(value_datetime) data_inicio
						from 	patient p
								inner join encounter e on p.patient_id=e.patient_id
								inner join obs o on e.encounter_id=o.encounter_id
						where 	p.voided=0 and e.voided=0 and o.voided=0 and e.encounter_type in (18,6,9,53) and 
								o.concept_id=1190 and o.value_datetime is not null and 
								o.value_datetime<=@endDate and e.location_id=@location
						group by p.patient_id

						union

						/*Patients enrolled in ART Program: OpenMRS Program*/
						select 	pg.patient_id,min(date_enrolled) data_inicio
						from 	patient p inner join patient_program pg on p.patient_id=pg.patient_id
						where 	pg.voided=0 and p.voided=0 and program_id=2 and date_enrolled<=@endDate and location_id=@location
						group by pg.patient_id
						
						union
						
						
						/*Patients with first drugs pick up date set in Pharmacy: First ART Start Date*/
						  SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data_inicio 
						  FROM 		patient p
									inner join encounter e on p.patient_id=e.patient_id
						  WHERE		p.voided=0 and e.encounter_type=18 AND e.voided=0 and e.encounter_datetime<=@endDate and e.location_id=@location
						  GROUP BY 	p.patient_id
					  
						union
						
						/*Patients with first drugs pick up date set: Recepcao Levantou ARV*/
						Select 	p.patient_id,min(value_datetime) data_inicio
						from 	patient p
								inner join encounter e on p.patient_id=e.patient_id
								inner join obs o on e.encounter_id=o.encounter_id
						where 	p.voided=0 and e.voided=0 and o.voided=0 and e.encounter_type=52 and 
								o.concept_id=23866 and o.value_datetime is not null and 
								o.value_datetime<=@endDate and e.location_id=@location
						group by p.patient_id		
					
				
				
			) inicio
		group by patient_id	
	)iniciotarv on iniciotarv.patient_id = visita.patient_id
	left join
    person_attribute pat
    on pat.person_id=visita.patient_id
    and pat.person_attribute_type_id=9 
    and pat.value is not null and pat.value<>'' and pat.voided=0 ;