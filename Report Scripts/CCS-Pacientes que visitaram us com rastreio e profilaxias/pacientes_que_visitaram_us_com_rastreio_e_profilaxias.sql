
select 	pid.identifier identifier,
		visita.patient_id,
		 DATE_FORMAT(visita.data_visita,'%d/%m/%Y') as data_visita,
		 DATE_FORMAT(ultimo_seguimento.data_ultimo_seguimento,'%d/%m/%Y') as data_ultimo_seguimento,
		 DATE_FORMAT(rastreiotb.ultimo_rastreio_tb,'%d/%m/%Y') as ultimo_rastreio_tb,
		 DATE_FORMAT(rastreioits.ultimo_rastreio_its,'%d/%m/%Y') as ultimo_rastreio_its,
		 DATE_FORMAT(profilaxiactx.data_profilaxia_ctx,'%d/%m/%Y') as data_profilaxia_ctx,
		 DATE_FORMAT(profilaxiainh.data_profilaxia_inh,'%d/%m/%Y') as data_profilaxia_inh,
		concat(ifnull(pn.given_name,''),' ',ifnull(pn.middle_name,''),' ',ifnull(pn.family_name,'')) as NomeCompleto,
		if(elegivelctx.patient_id is not null,'SIM',null) elegivel_ctx,
		pe.gender,
		round(datediff(:endDate,pe.birthdate)/365) idade
from		

		(  select 	e.patient_id,
					max(e.encounter_datetime) data_visita
		   from 	patient p
					inner join encounter e on e.patient_id=p.patient_id
		   where 	e.encounter_datetime between :startDate and :endDate and e.voided=0 and p.voided=0 and 
					e.location_id=:location and e.encounter_type in (5,7,6,9,18,13)
		   group by e.patient_id
        ) visita
		left join 
		(  select 	e.patient_id,
					max(e.encounter_datetime) data_ultimo_seguimento
		   from 	patient p
					inner join encounter e on e.patient_id=p.patient_id
		   where 	e.encounter_datetime between :startDate and :endDate and e.voided=0 and p.voided=0 and 
					e.location_id=:location and e.encounter_type in (6,9)
		   group by e.patient_id
        ) ultimo_seguimento on visita.patient_id=ultimo_seguimento.patient_id
		left join
		(  
        
        select 	p.patient_id,max(encounter_datetime) ultimo_rastreio_tb
		from 	patient p
				inner join encounter e on p.patient_id=e.patient_id
				inner join obs o on o.encounter_id=e.encounter_id
		where 	e.encounter_type in (6,9) and e.voided=0 and o.voided=0 and p.voided=0 and
				o.concept_id=23758 and e.encounter_datetime between :startDate and :endDate and e.location_id=:location
		group by p.patient_id	
        ) rastreiotb on visita.patient_id=rastreiotb.patient_id
		left join
		(  select 	e.patient_id,
					max(e.encounter_datetime) ultimo_rastreio_its
		   from 	patient p
					inner join encounter e on e.patient_id=p.patient_id
					inner join obs o on o.encounter_id=e.encounter_id
		   where 	e.encounter_datetime between :startDate and :endDate and e.voided=0 and p.voided=0 and 					
					e.location_id=:location and e.encounter_type in (6,9) and o.concept_id=6258 and o.voided=0					
		   group by e.patient_id
        ) rastreioits on visita.patient_id=rastreioits.patient_id
		left join
		(  select 	e.patient_id,
					max(e.encounter_datetime) data_profilaxia_ctx
		   from 	patient p
					inner join encounter e on e.patient_id=p.patient_id
					inner join obs o on o.encounter_id=e.encounter_id
		   where 	e.encounter_datetime between :startDate and :endDate and e.voided=0 and p.voided=0 and 					
					e.location_id=:location and e.encounter_type in (6,9) and o.concept_id=6121 and o.value_coded in (1256,1257) and o.voided=0					
		   group by e.patient_id
        ) profilaxiactx on visita.patient_id=profilaxiactx.patient_id  
		left join
		(  select 	e.patient_id,
					max(e.encounter_datetime) data_profilaxia_inh
		   from 	patient p
					inner join encounter e on e.patient_id=p.patient_id
					inner join obs o on o.encounter_id=e.encounter_id
		   where 	e.encounter_datetime between :startDate and :endDate and e.voided=0 and p.voided=0 and 					
					e.location_id=:location and e.encounter_type in (6,9) and o.concept_id=6122 and   o.value_coded in (1256,1257)  and o.voided=0					
		   group by e.patient_id
        ) profilaxiainh on visita.patient_id=profilaxiainh.patient_id  
		
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
		select person_id,gender,birthdate from person 
		where voided=0 
		group by person_id
		
	) pe on pe.person_id = pn.person_id
		left join 		
		(	select o.person_id patient_id
			from 	obs o,				
					(	select p.patient_id,max(encounter_datetime) as encounter_datetime
						from 	patient p
								inner join encounter e on p.patient_id=e.patient_id
								inner join obs o on o.encounter_id=e.encounter_id
						where 	encounter_type=13 and e.voided=0 and
								encounter_datetime <=:endDate and e.location_id=:location
								and p.voided=0 and o.voided=0 and o.concept_id=5497
						group by patient_id
					) d
			where 	o.person_id=d.patient_id and o.obs_datetime=d.encounter_datetime and o.voided=0 and 
					o.concept_id=5497 and o.location_id=:location and o.value_numeric<=350
			union
			
			select 	o.person_id patient_id
			from 	obs o,				
					(	select 	p.patient_id,max(encounter_datetime) as encounter_datetime
						from 	patient p
								inner join encounter e on p.patient_id=e.patient_id
								inner join obs o on o.encounter_id=e.encounter_id
						where 	encounter_type in (6,9) and e.voided=0 and
								encounter_datetime<=:endDate and e.location_id=:location
								and p.voided=0 and o.voided=0 and o.concept_id=5356
						group by patient_id
					) d
			where 	o.person_id=d.patient_id and o.obs_datetime=d.encounter_datetime and o.voided=0 and 
					o.concept_id=5356 and o.location_id=:location and o.value_coded in (1206,1207)
					
					
			union
			
			select 	o.person_id patient_id
			from 	obs o,				
					(	select 	p.patient_id,max(encounter_datetime) as encounter_datetime
						from 	patient p
								inner join encounter e on p.patient_id=e.patient_id
								inner join obs o on o.encounter_id=e.encounter_id
						where 	encounter_type in (6,9) and e.voided=0 and
								encounter_datetime<=:endDate and e.location_id=:location
								and p.voided=0 and o.voided=0 and o.concept_id=5356
						group by patient_id
					) d
			where 	o.person_id=d.patient_id and o.obs_datetime=d.encounter_datetime and o.voided=0 and 
					o.concept_id=5356 and o.location_id=:location and o.value_coded=1205 and d.patient_id not in 
					(select distinct person_id from obs where concept_id=5497 and voided=0)
					
			union
			
			Select 	p.patient_id
			from 	patient p 
					inner join encounter e on p.patient_id=e.patient_id	
					inner join obs o on o.encounter_id=e.encounter_id
			where 	e.voided=0 and o.voided=0 and o.value_datetime between :startDate and :endDate and 
					o.concept_id=1113 and e.encounter_type in (6,9) and e.location_id=:location	

			union		
			
			select 	pg.patient_id
			from 	patient p inner join patient_program pg on p.patient_id=pg.patient_id
			where 	pg.voided=0 and p.voided=0 and program_id in (5,8) and date_enrolled between :startDate and :endDate and location_id=:location
			
			union
			
			select p.patient_id
			from person pe inner join patient p on p.patient_id=pe.person_id
			where pe.voided=0 and p.voided=0 and (datediff(:endDate,birthdate)/365)<5
			
		) elegivelctx on elegivelctx.patient_id=visita.patient_id
where 	rastreiotb.ultimo_rastreio_tb is not null or  rastreioits.ultimo_rastreio_its is not null or 	profilaxiactx.data_profilaxia_ctx is not null or	profilaxiainh.data_profilaxia_inh is not null
        
        