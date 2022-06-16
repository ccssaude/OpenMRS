
Select 	distinct 	visita.patient_id,
			concat(ifnull(pn.given_name,''),' ',ifnull(pn.middle_name,''),' ',ifnull(pn.family_name,'')) as 'NomeCompleto',
			pid.identifier as NID,
			p.gender,
            if( ptv.date_enrolled is null, 'Nao', 	DATE_FORMAT(ptv.date_enrolled,'%d/%m/%Y') ) as inscrito_ptv_etv,
            if( ccr.date_enrolled is null, 'Nao', 	DATE_FORMAT(ccr.date_enrolled,'%d/%m/%Y')) as inscrito_ccr,
            if(pregnancy.obs_datetime is null, 'Nao',	DATE_FORMAT(pregnancy.obs_datetime,'%d/%m/%Y') ) as gravidez,
            if(breastfeeding.obs_datetime is null, 'Nao',	DATE_FORMAT(breastfeeding.obs_datetime,'%d/%m/%Y') ) as lactacao,
            round(datediff(curdate(),p.birthdate)/365) idade_actual,
             DATE_FORMAT(iniciotarv.data_inicio,'%d/%m/%Y') as 'data_inicio',    
			DATE_FORMAT(visita.encounter_datetime,'%d/%m/%Y') as 'data_visita',
			DATE_FORMAT(visita.value_datetime,'%d/%m/%Y') as 'data_proxima',
            regimeSeguimento.ultimo_regime as regimeSeguimento,
			DATE_FORMAT(visitaFila.encounter_datetime,'%d/%m/%Y') as 'data_visitaFila',
			DATE_FORMAT(visitaFila.value_datetime,'%d/%m/%Y') as 'data_proximaFila',
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

	select p.patient_id, o.value_text  as telefone_confidente
			from	patient p
					inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on o.encounter_id=e.encounter_id
			where 	e.voided=0 and p.voided=0 and 
					o.voided=0 and o.concept_id=6224 and e.encounter_type =53  and e.voided=0
	
) tel_confidente on tel_confidente.patient_id = visita.patient_id
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
								e.encounter_datetime<=:endDate and e.location_id=:location
						group by p.patient_id
				
						union
				
						/*Patients on ART who have art start date: ART Start date*/
						Select 	p.patient_id,min(value_datetime) data_inicio
						from 	patient p
								inner join encounter e on p.patient_id=e.patient_id
								inner join obs o on e.encounter_id=o.encounter_id
						where 	p.voided=0 and e.voided=0 and o.voided=0 and e.encounter_type in (18,6,9,53) and 
								o.concept_id=1190 and o.value_datetime is not null and 
								o.value_datetime<=:endDate and e.location_id=:location
						group by p.patient_id

						union

						/*Patients enrolled in ART Program: OpenMRS Program*/
						select 	pg.patient_id,min(date_enrolled) data_inicio
						from 	patient p inner join patient_program pg on p.patient_id=pg.patient_id
						where 	pg.voided=0 and p.voided=0 and program_id=2 and date_enrolled<=:endDate and location_id=:location
						group by pg.patient_id
						
						union
						
						
						/*Patients with first drugs pick up date set in Pharmacy: First ART Start Date*/
						  SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data_inicio 
						  FROM 		patient p
									inner join encounter e on p.patient_id=e.patient_id
						  WHERE		p.voided=0 and e.encounter_type=18 AND e.voided=0 and e.encounter_datetime<=:endDate and e.location_id=:location
						  GROUP BY 	p.patient_id
					  
						
				
			) inicio
		group by patient_id	
	)iniciotarv on iniciotarv.patient_id = visita.patient_id


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
						e.encounter_datetime data_regime,
                        o.value_coded
				from 	encounter e
                inner join
                         ( select e.patient_id,max(encounter_datetime) encounter_datetime 
                         from encounter e 
                         inner join obs o on e.encounter_id=o.encounter_id
                         where 	encounter_type in (6,9) and e.voided=0 and o.voided=0 
                         group by e.patient_id
                         ) ultimolev
				on e.patient_id=ultimolev.patient_id
                inner join obs o on o.encounter_id=e.encounter_id 
				where  ultimolev.encounter_datetime = e.encounter_datetime and
                        encounter_type in (6,9) and e.voided=0 and o.voided=0 and 
						o.concept_id=1087 and e.location_id=:location
              group by patient_id
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
			e.encounter_type=18 
		) visitaFila on visitaFila.patient_id = visita.patient_id

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
						e.encounter_datetime data_regime,
                        o.value_coded
				from 	encounter e
                inner join
                         ( select e.patient_id,max(encounter_datetime) encounter_datetime 
                         from encounter e 
                         inner join obs o on e.encounter_id=o.encounter_id
                         where 	encounter_type =18 and e.voided=0 and o.voided=0 
                         group by e.patient_id
                         ) ultimofila
				on e.patient_id=ultimofila.patient_id
                inner join obs o on o.encounter_id=e.encounter_id 
				where  ultimofila.encounter_datetime = e.encounter_datetime and
                        encounter_type =18 and e.voided=0 and o.voided=0 and 
						o.concept_id=1088 and e.location_id=:location
              group by patient_id
                    
		) regimeFila on regimeFila.patient_id=visita.patient_id

           /*Patients enrolled in PTV/ETV Program: OpenMRS Program*/
        left join (


						/*Patients enrolled in PTV/ETV Program: OpenMRS Program*/
						select 	pg.patient_id,date_enrolled 
						from 	patient p inner join patient_program pg on p.patient_id=pg.patient_id
						where 	pg.voided=0 and p.voided=0 and program_id=8 and  date_enrolled  between DATE_SUB( :endDate , INTERVAL 9 MONTH ) and :endDate 
						group by pg.patient_id
        ) ptv on ptv.patient_id= visita.patient_id
     /*Patients enrolled in CCR Program: OpenMRS Program*/
     left join (
         				select 	pg.patient_id,date_enrolled
						from 	patient p inner join patient_program pg on p.patient_id=pg.patient_id
						where 	pg.voided=0 and p.voided=0 and program_id=6 and  date_enrolled  between DATE_SUB( :endDate , INTERVAL 18 MONTH ) and :endDate 
						group by pg.patient_id
       ) ccr on ccr.patient_id= visita.patient_id
       
       /*Patients  pregnancy in Ficha Clinca Form */
        left join (
	select 	p.patient_id,  max(obs_datetime) as obs_datetime
			from	patient p
					inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on o.encounter_id=e.encounter_id
			where 	e.voided=0 and p.voided=0  and 
					o.voided=0 and o.concept_id=1982 and e.encounter_type in(6,53)  
                    and o.value_coded=1065
                    and e.form_id = 163  and  obs_datetime between  DATE_SUB( :endDate , INTERVAL 9 MONTH ) and :endDate 
		 group by p.patient_id
        ) pregnancy on pregnancy.patient_id= visita.patient_id

     /*Patients breastfeeding  in Ficha clinica Form*/
             left join (
	select 	p.patient_id, max(obs_datetime) as obs_datetime
			from	patient p
					inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on o.encounter_id=e.encounter_id
			where 	e.voided=0 and p.voided=0  and 
					o.voided=0 and o.concept_id=6332 and e.encounter_type in(6,53)  
                    and o.value_coded=1065
                    and e.form_id = 163  and  obs_datetime between  DATE_SUB( :endDate , INTERVAL 9 MONTH ) and :endDate 
		group by p.patient_id
        ) breastfeeding on breastfeeding.patient_id= visita.patient_id
	left join
    person_attribute pat
    on pat.person_id=visita.patient_id
    and pat.person_attribute_type_id=9 
    and pat.value is not null and pat.value<>'' and pat.voided=0 