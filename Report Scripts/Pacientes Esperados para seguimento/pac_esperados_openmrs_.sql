Select 	distinct 	visita.patient_id,
			concat(ifnull(pn.given_name,''),' ',ifnull(pn.middle_name,''),' ',ifnull(pn.family_name,'')) as 'NomeCompleto',
			pid.identifier as NID,
			p.gender,
            round(datediff(curdate(),p.birthdate)/365) idade_actual,
			visita.encounter_datetime as 'data_visita',
			visita.value_datetime as 'data_proxima',
            regimeSeguimento.ultimo_regime as regimeSeguimento,
			visitaFila.encounter_datetime as 'data_visitaFila',
			visitaFila.value_datetime as 'data_proximaFila',
            regimeFila.ultimo_regime as regimeFila,
			pe.county_district as 'Distrito',
			pe.address2 as 'PAdministrativo',
			pe.address6 as 'Localidade',
			pe.address5 as 'Bairro',
			pe.address1 as 'PontoReferencia',
			pat.value as Telefone	
	from
		(
		Select ultimavisita.patient_id,ultimavisita.encounter_datetime,o.value_datetime,e.location_id,e.encounter_id
		from

			(	select 	p.patient_id,max(encounter_datetime) as encounter_datetime
				from 	encounter e 
						inner join patient p on p.patient_id=e.patient_id 		
				where 	e.voided=0 and p.voided=0 and e.encounter_type in (9,6) 
				group by p.patient_id
			) ultimavisita
			inner join encounter e on e.patient_id=ultimavisita.patient_id
			inner join obs o on o.encounter_id=e.encounter_id			
			where o.concept_id=1410 and o.voided=0 and e.encounter_datetime=ultimavisita.encounter_datetime and 
			e.encounter_type in (9,6) and o.value_datetime between :startDate and :endDate and e.location_id=:location 
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
					ultimo_lev.encounter_datetime data_regime
			from 	obs o,				
					(	select p.patient_id,max(encounter_datetime) as encounter_datetime
						from 	patient p
								inner join encounter e on p.patient_id=e.patient_id								
						where 	encounter_type=6 and e.voided=0 and
								encounter_datetime <=:endDate and e.location_id=:location and p.voided=0
						group by patient_id
					) ultimo_lev
			where 	o.person_id=ultimo_lev.patient_id and 
					o.obs_datetime=ultimo_lev.encounter_datetime and o.voided=0 and 
					o.concept_id=1087 and o.location_id=:location 
		) regimeSeguimento on regimeSeguimento.patient_id=visita.patient_id  
		left join 
		(
			Select ultimavisita.patient_id,ultimavisita.encounter_datetime,o.value_datetime,e.location_id,e.encounter_id
			from

			(	select 	p.patient_id,max(encounter_datetime) as encounter_datetime
				from 	encounter e 
						inner join patient p on p.patient_id=e.patient_id 		
				where 	e.voided=0 and p.voided=0 and e.encounter_type=18 
				group by p.patient_id
			) ultimavisita
			inner join encounter e on e.patient_id=ultimavisita.patient_id
			inner join obs o on o.encounter_id=e.encounter_id			
			where o.concept_id=5096 and o.voided=0 and e.encounter_datetime=ultimavisita.encounter_datetime and 
			e.encounter_type=18 and o.value_datetime 
		) visitaFila on visitaFila.patient_id = visita.patient_id
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
								encounter_datetime <=:endDate and e.location_id=:location and p.voided=0
						GROUP BY patient_id
					) ultimo_lev, encounter e 
			WHERE 	o.person_id=ultimo_lev.patient_id AND o.obs_datetime=ultimo_lev.encounter_datetime AND o.voided=0 AND 
					o.concept_id=1088 and o.location_id=:location and e.patient_id=ultimo_lev.patient_id
                    
		) regimeFila on regimeFila.encounter_id=visitaFila.encounter_id
	left join
    person_attribute pat
    on pat.person_id=visita.patient_id
    and pat.person_attribute_type_id=9 
    and pat.value is not null and pat.value<>'' and pat.voided=0 ;Select 	distinct 	visita.patient_id,
			concat(ifnull(pn.given_name,''),' ',ifnull(pn.middle_name,''),' ',ifnull(pn.family_name,'')) as 'NomeCompleto',
			pid.identifier as NID,
			p.gender,
            round(datediff(curdate(),p.birthdate)/365) idade_actual,
			visita.encounter_datetime as 'data_visita',
			visita.value_datetime as 'data_proxima',
            regimeSeguimento.ultimo_regime as regimeSeguimento,
			visitaFila.encounter_datetime as 'data_visitaFila',
			visitaFila.value_datetime as 'data_proximaFila',
            regimeFila.ultimo_regime as regimeFila,
			pe.county_district as 'Distrito',
			pe.address2 as 'PAdministrativo',
			pe.address6 as 'Localidade',
			pe.address5 as 'Bairro',
			pe.address1 as 'PontoReferencia',
			pat.value as Telefone	
	from
		(
		Select ultimavisita.patient_id,ultimavisita.encounter_datetime,o.value_datetime,e.location_id,e.encounter_id
		from

			(	select 	p.patient_id,max(encounter_datetime) as encounter_datetime
				from 	encounter e 
						inner join patient p on p.patient_id=e.patient_id 		
				where 	e.voided=0 and p.voided=0 and e.encounter_type in (9,6) 
				group by p.patient_id
			) ultimavisita
			inner join encounter e on e.patient_id=ultimavisita.patient_id
			inner join obs o on o.encounter_id=e.encounter_id			
			where o.concept_id=1410 and o.voided=0 and e.encounter_datetime=ultimavisita.encounter_datetime and 
			e.encounter_type in (9,6) and o.value_datetime between :startDate and :endDate and e.location_id=:location 
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
					ultimo_lev.encounter_datetime data_regime
			from 	obs o,				
					(	select p.patient_id,max(encounter_datetime) as encounter_datetime
						from 	patient p
								inner join encounter e on p.patient_id=e.patient_id								
						where 	encounter_type=6 and e.voided=0 and
								encounter_datetime <=:endDate and e.location_id=:location and p.voided=0
						group by patient_id
					) ultimo_lev
			where 	o.person_id=ultimo_lev.patient_id and 
					o.obs_datetime=ultimo_lev.encounter_datetime and o.voided=0 and 
					o.concept_id=1087 and o.location_id=:location 
		) regimeSeguimento on regimeSeguimento.patient_id=visita.patient_id  
		left join 
		(
			Select ultimavisita.patient_id,ultimavisita.encounter_datetime,o.value_datetime,e.location_id,e.encounter_id
			from

			(	select 	p.patient_id,max(encounter_datetime) as encounter_datetime
				from 	encounter e 
						inner join patient p on p.patient_id=e.patient_id 		
				where 	e.voided=0 and p.voided=0 and e.encounter_type=18 
				group by p.patient_id
			) ultimavisita
			inner join encounter e on e.patient_id=ultimavisita.patient_id
			inner join obs o on o.encounter_id=e.encounter_id			
			where o.concept_id=5096 and o.voided=0 and e.encounter_datetime=ultimavisita.encounter_datetime and 
			e.encounter_type=18 and o.value_datetime 
		) visitaFila on visitaFila.patient_id = visita.patient_id
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
								encounter_datetime <=:endDate and e.location_id=:location and p.voided=0
						GROUP BY patient_id
					) ultimo_lev, encounter e 
			WHERE 	o.person_id=ultimo_lev.patient_id AND o.obs_datetime=ultimo_lev.encounter_datetime AND o.voided=0 AND 
					o.concept_id=1088 and o.location_id=:location and e.patient_id=ultimo_lev.patient_id
                    
		) regimeFila on regimeFila.encounter_id=visitaFila.encounter_id
	left join
    person_attribute pat
    on pat.person_id=visita.patient_id
    and pat.person_attribute_type_id=9 
    and pat.value is not null and pat.value<>'' and pat.voided=0 ;