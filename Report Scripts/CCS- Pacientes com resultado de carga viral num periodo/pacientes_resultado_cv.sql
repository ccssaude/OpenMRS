
select 	pid.identifier as NID,
		concat(ifnull(pn.given_name,''),' ',ifnull(pn.middle_name,''),' ',ifnull(pn.family_name,'')) as 'NomeCompleto',
		inicio_real.data_inicio,
		seguimento.data_seguimento,
		carga2.data_primeiro_carga,
		carga2.valor_primeira_carga,
        carga2.Origem_Resultado origem_primeiro,
		if(carga2.data_primeiro_carga<>carga1.data_ultima_carga,carga1.data_ultima_carga,'') as data_ultima_carga,
		if(carga2.data_primeiro_carga<>carga1.data_ultima_carga,carga1.valor_ultima_carga,'') as valor_ultima_carga,	
        carga1.Origem_Resultado origem_ultimo,
		pe.gender,
		round(datediff(:endDate,pe.birthdate)/365) idade_actual,
        regime_primeiro.ultimo_regime,
regime_segunda_linha.data_regime,
        telef.value AS telefone
		
from		
		
	(	select ultima_carga.patient_id,max(data_ultima_carga) data_ultima_carga,max(value_numeric) valor_ultima_carga, ultima_carga.form_id, fr.name as Origem_Resultado
			from	
				(	select 	e.patient_id,
							max(e.encounter_datetime) data_ultima_carga, form_id
					from 	encounter e
							inner join obs o on e.encounter_id=o.encounter_id
					where 	e.encounter_type in (13,6,9) and e.voided=0 and
							o.voided=0 and o.concept_id=856 and e.encounter_datetime between :startDate and :endDate and 	e.location_id=:location
					group by e.patient_id
                    
				union
                
					select 	e.patient_id,
							max(o.obs_datetime) data_ultima_carga, form_id
					from 	encounter e
							inner join obs o on e.encounter_id=o.encounter_id
					where 	e.encounter_type = 53 and e.voided=0 and 
							o.voided=0 and o.concept_id=856 and e.encounter_datetime between :startDate and :endDate and e.location_id=:location
					group by e.patient_id
                
				) ultima_carga
				inner join obs o on o.person_id=ultima_carga.patient_id and o.obs_datetime=ultima_carga.data_ultima_carga
                inner join encounter e on e.patient_id = ultima_carga.patient_id and e.form_id = ultima_carga.form_id
                left join form fr on fr.form_id = ultima_carga.form_id
			where o.concept_id=856 and o.voided=0 and e.voided=0
			group by patient_id
			
		) carga1 
        
		

		inner  join person pe on pe.person_id=carga1.patient_id and pe.voided=0
/* ******************************* Telefone **************************** */
	LEFT JOIN (
		SELECT  p.person_id, p.value  
		FROM person_attribute p
     WHERE  p.person_attribute_type_id=9 
    AND p.value IS NOT NULL AND p.value<>'' AND p.voided=0 
	) telef  ON telef.person_id = carga1.patient_id


left join

(	select primeiro_carga.patient_id,min(data_primeiro_carga) data_primeiro_carga,max(value_numeric) valor_primeira_carga, fr.name as Origem_Resultado
			from	
				(	select 	e.patient_id,
							min(o.obs_datetime) data_primeiro_carga, form_id
					from 	encounter e
							inner join obs o on e.encounter_id=o.encounter_id
					where 	e.encounter_type in (13,6,9) and e.voided=0 and
							o.voided=0 and o.concept_id=856 and e.location_id=:location
					group by e.patient_id
			
				) primeiro_carga
				inner join encounter e on e.patient_id = primeiro_carga.patient_id and e.form_id = primeiro_carga.form_id
                left join form fr on fr.form_id = primeiro_carga.form_id
				inner join obs o on o.person_id=primeiro_carga.patient_id and o.obs_datetime=primeiro_carga.data_primeiro_carga
			where o.concept_id=856 and o.voided=0 and e.voided=0
			group by patient_id
		) carga2 on carga2.patient_id = carga1.patient_id
	

		inner join person_name pn on pn.person_id=carga2.patient_id and pn.preferred=1 and pn.voided=0
		inner join patient_identifier pid on pid.patient_id=carga2.patient_id and pid.identifier_type=2 and pid.voided=0
		
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
	)inicio_real on inicio_real.patient_id=carga1.patient_id
		        
		left JOIN		
		(	SELECT ultimavisita.patient_id,max(ultimavisita.encounter_datetime) data_seguimento ,o.value_datetime
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
              group by ultimavisita.patient_id
		) seguimento ON seguimento .patient_id=carga1.patient_id 
	
        
	       
        left join(
        
       
				select 	ultimo_lev.patient_id,
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
						max(ultimo_lev.encounter_datetime) data_regime
				from 	obs o,				
						(	select p.patient_id,max(encounter_datetime) as encounter_datetime
							from 	patient p
									inner join encounter e on p.patient_id=e.patient_id								
							where 	encounter_type in (6,9) and e.voided=0 and
									encounter_datetime <=:endDate and e.location_id=:location and p.voided=0
							group by patient_id
						) ultimo_lev
				where 	o.person_id=ultimo_lev.patient_id and o.obs_datetime=ultimo_lev.encounter_datetime and o.voided=0 and 
						o.concept_id=1087 and o.location_id=:location
                        group by ultimo_lev.patient_id 
			) regime_primeiro on regime_primeiro.patient_id=carga1.patient_id
			
        
        	left join 
		(
			select 	ultimo_lev.patient_id,
					case o.value_coded						
						when 6108 then 'TDF+3TC+LPV/r(2ª Linha)'
						when 6100 then 'AZT+3TC+LPV/r(2ª Linha)'						
						when 6325 then 'D4T+3TC+ABC+LPV/r (2ª Linha)'
						when 6326 then 'AZT+3TC+ABC+LPV/r (2ª Linha)'
						when 6327 then 'D4T+3TC+ABC+EFV (2ª Linha)'
						when 6328 then 'AZT+3TC+ABC+EFV (2ª Linha)'
						when 6109 then 'AZT+DDI+LPV/r (2ª Linha)'						
					else 'OUTRO' end as ultimo_regime,
					min(ultimo_lev.encounter_datetime) data_regime
			from 	obs o,				
					(	select p.patient_id,min(encounter_datetime) as encounter_datetime
						from 	patient p
								inner join encounter e on p.patient_id=e.patient_id	
								inner join obs o on o.encounter_id=e.encounter_id
						where 	encounter_type=18 and e.voided=0 and o.concept_id=1088 and o.value_coded in (6108,6100,6325,6326,6327,6328,6109) and 
								encounter_datetime <=:endDate and e.location_id=:location and p.voided=0
						group by patient_id
					) ultimo_lev
			where 	o.person_id=ultimo_lev.patient_id and o.obs_datetime=ultimo_lev.encounter_datetime and o.voided=0 and 
					o.concept_id=1088 and o.location_id=:location and o.value_coded in (6108,6100,6325,6326,6327,6328,6109)
                    	group by patient_id
		) regime_segunda_linha on regime_segunda_linha.patient_id=carga1.patient_id
        
        
        
        