set @startDate := '2018-11-21 00:00:00';
set @endDate := '2019-03-20 00:00:00';
set @location := 418;



select gravidas_lactantes.*,
	location.description as unidade_sanitaria,
	-- if(inscrito_tb.date_enrolled is null,'N','Y') inscrito_programa_tb,
	-- datediff(visita_volta.encounter_datetime,o.value_datetime) as diasFalta,
       DATE_FORMAT(max_frida.encounter_datetime,'%d/%m/%Y') as dataUltimoLevantamento,
       ptv_saida.data_ptv,
       if(gestante.patient_id is null, null,'S'),
        datediff(@endDate,dpp) tempo_gestacao

       -- DATE_FORMAT(o.value_datetime,'%d/%m/%Y') as dataPrevistaLevantamento,
       -- if(visita_volta.encounter_datetime is null,'N','Y') as returnVisit,
      --  DATE_FORMAT(visita_volta.encounter_daatetime,'%d/%m/%Y') as dateReturn,
       -- aconselhamento.sessoes as sessoesAconselhamento
from
(	select  gravida_lactante_real.patient_id,
		concat(ifnull(pn.given_name,''),' ',ifnull(pn.middle_name,''),' ',ifnull(pn.family_name,'')) as 'NomeCompleto',
		pid.identifier as NID,
		p.gender,
		round(datediff(@endDate,p.birthdate)/365) idade_actual,
		if(data_gravida is null,'N','Y') as data_gravida,
		DATE_FORMAT(data_gravida,'%d/%m/%Y') as dataDaGravidez,
		gravida_lactante_real.gravida as gravida,
		-- DATE_FORMAT(gravida_lactante_real.dpp,'%d/%m/%Y') as dpp,
    gravida_lactante_real.dpp as dpp,
		DATE_FORMAT(inicio_real.data_inicio,'%d/%m/%Y') as data_inicio,
		(CASE
			WHEN (pat.value is not null and person_address_id is not null) THEN '1'
			WHEN (pat.value is null and pad3.person_address_id is not null) THEN '2'
			WHEN (pat.value is not null and pad3.person_address_id is null) THEN '3'
            		ELSE 4
			END
        	) as phone_address,
	if(pat.value is null,' ',pat.value) as phone,
	if(pad3.person_address_id is null,' ',concat(ifnull(pad3.address2,''),' ',ifnull(pad3.address1,''))) as address
	from
		(
		select gravida_lactante.patient_id,data_gravida as data_gravida, gravida_lactante.gravida as gravida,gravida_dpp.dpp as dpp
			from
				(	Select p.patient_id,max(o.obs_datetime) data_gravida, 'Y' as gravida
					from    patient p
							inner join encounter e on p.patient_id=e.patient_id
							inner join obs o on e.encounter_id=o.encounter_id
					where   p.voided=0 and e.voided=0 and o.voided=0 and
							((o.concept_id=1982 and o.value_coded=44) or o.concept_id=1279 or o.concept_id=1600) and
							e.encounter_type in (5,6) and o.obs_datetime <= @endDate and
							e.location_id=@location and p.patient_id not in (select pp.patient_id from patient_program pp where pp.date_completed is not null)
					group by p.patient_id

					union

					select 	pp.patient_id,pp.date_enrolled as data_gravida, 'Y' as gravida
					from    patient_program pp
					where   pp.program_id=8 and pp.voided=0 and pp.date_completed is null and
							pp.date_enrolled <= @endDate and pp.location_id=@location
/*
				  union

					Select p.patient_id,max(obs_datetime) data_gravida, 'N' as gravida
					from    patient p
							inner join encounter e on p.patient_id=e.patient_id
							inner join obs o on e.encounter_id=o.encounter_id
					where   p.voided=0 and e.voided=0 and o.voided=0 and
							(concept_id=6332 and value_coded=1065 or concept_id=1600) and
							e.encounter_type in (5,6) and o.obs_datetime between date_add(@endDate, interval -2 year) and date_add(@endDate, interval -1 day) and
							e.location_id=@location
					group by p.patient_id
        /
					union

					select 	pg.patient_id,ps.start_date as data_gravida, 'N' as gravida
					from 	patient p
					inner join patient_program pg on p.patient_id=pg.patient_id
					inner join patient_state ps on pg.patient_program_id=ps.patient_program_id
					where 	pg.voided=0 and ps.voided=0 and p.voided=0 and
						pg.program_id=8 and ps.state=27 and ps.end_date is null and
						ps.start_date between date_add(@endDate, interval -2 year) and date_add(@endDate, interval -1 day) and location_id=@location */

				)gravida_lactante
				left join (
					Select 	p.patient_id,max(o.value_datetime) dpp
					from 	patient p
					inner join encounter e on p.patient_id=e.patient_id
			 		inner join obs o on e.encounter_id=o.encounter_id
					where 	p.voided=0 and e.voided=0 and o.voided=0 and concept_id=1600 and  -- data da gravidez
						e.encounter_type in (5,6) and e.encounter_datetime <= @endDate and e.location_id=@location
					group by p.patient_id
			)gravida_dpp on gravida_dpp.patient_id = gravida_lactante.patient_id

            group by gravida_lactante.patient_id

		) gravida_lactante_real
		inner join person p on p.person_id=gravida_lactante_real.patient_id and p.gender='F'
        inner join
        (	select patient_id,data_inicio
			from
				(	Select inicio.patient_id,min(data_inicio) data_inicio
					from
						(	Select 	p.patient_id,min(e.encounter_datetime) data_inicio
							from 	patient p
									inner join encounter e on p.patient_id=e.patient_id
									inner join obs o on o.encounter_id=e.encounter_id
							where 	e.voided=0 and o.voided=0 and p.voided=0 and
									e.encounter_type in (18,6,9) and o.concept_id=1255 and o.value_coded=1256 and
									e.encounter_datetime<=@endDate and e.location_id=@location
							group by p.patient_id

							union

							Select 	p.patient_id,min(value_datetime) data_inicio
							from 	patient p
									inner join encounter e on p.patient_id=e.patient_id
									inner join obs o on e.encounter_id=o.encounter_id
							where 	p.voided=0 and e.voided=0 and o.voided=0 and e.encounter_type in (18,6,9) and
									o.concept_id=1190 and o.value_datetime is not null and
									o.value_datetime<=@endDate and e.location_id=@location
							group by p.patient_id

							union

							select 	pg.patient_id,date_enrolled data_inicio
							from 	patient p inner join patient_program pg on p.patient_id=pg.patient_id
							where 	pg.voided=0 and p.voided=0 and program_id=2 and date_enrolled<=@endDate and location_id=@location

							union


						  SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data_inicio
						  FROM 		patient p
									inner join encounter e on p.patient_id=e.patient_id
						  WHERE		p.voided=0 and e.encounter_type=18 AND e.voided=0 and e.encounter_datetime<=@endDate and e.location_id=@location
						  GROUP BY 	p.patient_id

						) inicio
					group by inicio.patient_id
				)inicio1
				where data_inicio <= @endDate
		) inicio_real on inicio_real.patient_id=gravida_lactante_real.patient_id

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
		) pn on pn.person_id=gravida_lactante_real.patient_id
		left join
		(   select pid1.*
			from patient_identifier pid1
			inner join
			(
				select patient_id,min(patient_identifier_id) id
				from patient_identifier
				where voided=0
				group by patient_id
			) pid2
			where pid1.patient_id=pid2.patient_id and pid1.patient_identifier_id=pid2.id
		) pid on pid.patient_id=gravida_lactante_real.patient_id
		left join person_attribute pat on pat.person_id=gravida_lactante_real.patient_id
					        and pat.person_attribute_type_id=9
						and pat.value is not null
						and pat.value<>'' and pat.voided=0
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
		) pad3 on pad3.person_id=gravida_lactante_real.patient_id

) gravidas_lactantes
inner join
(	Select 	p.patient_id,max(encounter_datetime) encounter_datetime
			from 	patient p
					inner join encounter e on e.patient_id=p.patient_id
			where 	p.voided=0 and e.voided=0 and e.encounter_type=18 and
					e.location_id=@location and e.encounter_datetime<=@endDate
			group by p.patient_id
		) max_frida on max_frida.patient_id = gravidas_lactantes.patient_id
inner join obs o on o.person_id=max_frida.patient_id
inner join location on location.location_id = o.location_id

  and gravida='Y'
 --  and  datediff(@endDate,dpp)> 365
left join
( select 	pg.patient_id,ps.start_date as data_ptv
					from 	patient p
					inner join patient_program pg on p.patient_id=pg.patient_id
					inner join patient_state ps on pg.patient_program_id=ps.patient_program_id
					where 	pg.voided=0 and ps.voided=0 and p.voided=0 and
						pg.program_id=8 and ps.state=27 and ps.end_date is null and
					/*	ps.start_date between date_add(@endDate, interval -2 year) and date_add(@endDate, interval -1 day)  and */ location_id=@location
  )	ptv_saida on ptv_saida.patient_id=gravidas_lactantes.patient_id



  left join (
    	Select p.patient_id,max(obs_datetime) data_gravida, 'S' as gestante
					from    patient p
							inner join encounter e on p.patient_id=e.patient_id
							inner join obs o on e.encounter_id=o.encounter_id
					where   p.voided=0 and e.voided=0 and o.voided=0 and
							(concept_id=6332 and value_coded=1065 or concept_id=1600) and
							e.encounter_type in (5,6) and o.obs_datetime between date_add(@endDate, interval -3 year) and date_add(@endDate, interval -1 day) and
							e.location_id=@location
	) gestante on gestante.patient_id=gravidas_lactantes.patient_id

/*left join (
Select 	p.patient_id,e.encounter_datetime,count(encounter_datetime) as sessoes
			from 	patient p
					inner join encounter e on e.patient_id=p.patient_id
			where 	p.voided=0 and e.voided=0 and (e.encounter_type in (19,24) or e.encounter_type in (34,35)) and
					e.location_id=@location and e.encounter_datetime<=@endDate
			group by p.patient_id
)aconselhamento on aconselhamento.patient_id = max_frida.patient_id and aconselhamento.encounter_datetime between date_add(max_frida.encounter_datetime, interval -6 month) and max_frida.encounter_datetime
left join (
Select 	p.patient_id,min(e.encounter_datetime) encounter_datetime
			from 	patient p
					inner join encounter e on e.patient_id=p.patient_id
			where 	p.voided=0 and e.voided=0 and e.encounter_type in (6,9,18) and
					e.location_id=@location and e.encounter_datetime > @endDate
			group by p.patient_id
)visita_volta on visita_volta.patient_id = max_frida.patient_id
*/

/*left join
	(
		select 	pgg.patient_id,pgg.date_enrolled
		from 	patient pt inner join patient_program pgg on pt.patient_id=pgg.patient_id
		where 	pgg.voided=0 and pt.voided=0 and pgg.program_id=5 and pgg.date_completed is not null and pgg.date_enrolled <=@endDate and pgg.location_id=@location
	) inscrito_tb on inscrito_tb.patient_id=max_frida.patient_id

where max_frida.encounter_datetime=o.obs_datetime and o.voided=0 and o.concept_id=5096 and o.location_id=@location and
gravidas_lactantes.patient_id not in
(
	select 	pg.patient_id
	from 	patient p
			inner join patient_program pg on p.patient_id=pg.patient_id
			inner join patient_state ps on pg.patient_program_id=ps.patient_program_id
	where 	pg.voided=0 and ps.voided=0 and p.voided=0 and
			pg.program_id=2 and ps.state=7 and ps.end_date is null and
			ps.start_date <= @endDate and location_id=@location
) and o.value_datetime between @startDate and @endDate and (datediff(visita_volta.encounter_datetime,o.value_datetime) >= 7 OR datediff(visita_volta.encounter_datetime,o.value_datetime) IS NULL)*/
 group by gravidas_lactantes.patient_id 