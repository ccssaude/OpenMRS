select *
from
(	select 	inicio_real.patient_id,
				DATE_FORMAT(inicio_real.data_inicio,'%d/%m/%Y') as data_inicio,
				pad3.county_district as 'Distrito',
				pad3.address2 as 'PAdministrativo',
				pad3.address6 as 'Localidade',
				pad3.address5 as 'Bairro',
				pad3.address1 as 'PontoReferencia',
				if(pat.value is null,' ',pat.value) as 'Contacto',
				concat(ifnull(pn.given_name,''),' ',ifnull(pn.middle_name,''),' ',ifnull(pn.family_name,'')) as 'NomeCompleto',					
				concat(pid.identifier,' ') as NID,
				if(pad3.person_address_id is null,' ',concat(' ',ifnull(pad3.address2,''),' ',ifnull(pad3.address5,''),' ',ifnull(pad3.address3,''),' ',ifnull(pad3.address1,''),' ',ifnull(pad3.address4,''),' ',ifnull(pad3.address6,''))) as endereco,
				p.gender,
				round(datediff(:endDate,p.birthdate)/365) idade_actual,
              	DATE_FORMAT(inicio_tpi.data_inicio_tpi ,'%d/%m/%Y') as data_inicio_tpi ,
                outras_prescricoes.medicamento,
                cd4.cd4 ,
                keypop.populacaochave as populacao_chave,
				numero_confidente.resultado_numero_confidente as ContactoReferencia,
				DATE_FORMAT(saida.encounter_datetime,'%d/%m/%Y') as data_saida,
				saida.estado as tipo_saida,
				DATE_FORMAT(visita.encounter_datetime,'%d/%m/%Y') as ultimo_levantamento,
				DATE_FORMAT(visita.value_datetime,'%d/%m/%Y') as proximo_marcado,
				DATE_FORMAT(seguimento.encounter_datetime,'%d/%m/%Y') as ultimo_seguimento,
				DATE_FORMAT(seguimento.value_datetime,'%d/%m/%Y') as proximo_seguimento,
				regime.ultimo_regime,
				regime.data_regime,
				if(programa.patient_id is null,'NAO','SIM') inscrito_programa,
				if(transferidode.patient_id is null,'','SIM') transde,
				if(inscrito_tb.date_enrolled is null,'NAO','SIM') inscrito_programa_tb,
				if(inscrito_smi.date_enrolled is null,'NAO','SIM') inscrito_programa_smi,
				if(inscrito_ccr.date_enrolled is null,'NAO','SIM') inscrito_programa_ccr,
				DATE_FORMAT(date_add(inicio_real.data_inicio, interval 33 day),'%d/%m/%Y') dataProvavelpara33dias,
				DATE_FORMAT(date_add(inicio_real.data_inicio, interval 61 day),'%d/%m/%Y') dataProvavelpara61dias,
				DATE_FORMAT(date_add(inicio_real.data_inicio, interval 120 day),'%d/%m/%Y') dataProvavelpara120dias,
				DATE_FORMAT(primeiravisita.encounter_datetime,'%d/%m/%Y') as primeiroLevantamento,
				DATE_FORMAT(segundavisita.encounter_datetime,'%d/%m/%Y') as segundoLevantamento,
				DATE_FORMAT(terceiravisita.encounter_datetime,'%d/%m/%Y') as terceiroLevantamento,
				DATE_FORMAT(quartavisita.encounter_datetime,'%d/%m/%Y') as quartoLevantamento,
				DATE_FORMAT(primeiro_seguimento.data_seguimento,'%d/%m/%Y') as primeiro_seguimento, 
				DATE_FORMAT(segundo_seguimento.data_seguimento,'%d/%m/%Y') as segundo_seguimento,
				DATE_FORMAT(terceiro_seguimento.data_seguimento,'%d/%m/%Y') as terceiro_seguimento,
				DATE_FORMAT(quarto_seguimento.data_seguimento,'%d/%m/%Y') as quarto_seguimento,
				DATE_FORMAT(date_add(primeiravisita.value_datetime, interval -3 day),'%d/%m/%Y') datachamada,
				if(consentimento.patient_id is null,'NAO','SIM') as consentido

		from
			(select patient_id,data_inicio
from
(	

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
					  
						union
						
						/*Patients with first drugs pick up date set: Recepcao Levantou ARV*/
						Select 	p.patient_id,min(value_datetime) data_inicio
						from 	patient p
								inner join encounter e on p.patient_id=e.patient_id
								inner join obs o on e.encounter_id=o.encounter_id
						where 	p.voided=0 and e.voided=0 and o.voided=0 and e.encounter_type=52 and 
								o.concept_id=23866 and o.value_datetime is not null and 
								o.value_datetime<=:endDate and e.location_id=:location
						group by p.patient_id		
					
				
				
			) inicio
		group by patient_id	
	)inicio1
where data_inicio between :startDate and :endDate
)inicio_real
			inner join person p on p.person_id=inicio_real.patient_id
			left join
			(
				select o.value_text,o.person_id 
				from obs o 
				where o.concept_id = 1611 
				and o.voided = 0
			)referencia on referencia.person_id = inicio_real.patient_id
				
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
			) pad3 on pad3.person_id=inicio_real.patient_id				
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
			) pn on pn.person_id=inicio_real.patient_id			
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
			) pid on pid.patient_id=inicio_real.patient_id	
			left join person_attribute pat on pat.person_id=inicio_real.patient_id 
							and pat.person_attribute_type_id=9 
							and pat.value is not null 
							and pat.value<>'' and pat.voided=0		
			left join
			(		
				select 	pg.patient_id,ps.start_date encounter_datetime,location_id,
						case ps.state
							when 7 then 'TRANSFERIDO PARA'
							when 8 then 'SUSPENSO'
							when 9 then 'ABANDONO'
							when 10 then 'OBITO'
						else 'OUTRO' end as estado
				from 	patient p 
						inner join patient_program pg on p.patient_id=pg.patient_id
						inner join patient_state ps on pg.patient_program_id=ps.patient_program_id
				where 	pg.voided=0 and ps.voided=0 and p.voided=0 and 
						pg.program_id=2 and ps.state in (7,8,9,10) and ps.end_date is null and location_id=:location	
			
			) saida on saida.patient_id=inicio_real.patient_id
   /*****************************  Outras prescricoes *********************************/
        
        LEFT JOIN(
           SELECT  patient_id, c.concept_id,cn.name as medicamento,max(data_outras_prescricoes) as data_outras_prescricoes
    				FROM (
        			    SELECT e.patient_id,
                        o.value_coded,
                        max(encounter_datetime) as data_outras_prescricoes
					FROM 	obs o
					INNER JOIN encounter e ON o.encounter_id=e.encounter_id
					WHERE 	e.encounter_type IN (6,9) AND e.voided=0 AND o.voided=0 AND o.concept_id = 1719 
					group by patient_id ) prescricao 
					INNER JOIN concept c ON c.concept_id = prescricao.value_coded
					INNER JOIN  concept_name cn on c.concept_id=cn.concept_id
					where locale ='pt'
				group by patient_id
        ) outras_prescricoes on outras_prescricoes.patient_id=inicio_real.patient_id
        
			left join 
	(Select visitainicial.patient_id,visitainicial.encounter_datetime ,o.value_datetime,e.location_id
		from

		(	select 	p.patient_id,min(encounter_datetime) as encounter_datetime
		from 	encounter e 
		inner join patient p on p.patient_id=e.patient_id 		
		where 	e.voided=0 and p.voided=0 and e.encounter_type = 18 and e.location_id=:location 
		group by p.patient_id
		) visitainicial
		inner join encounter e on e.patient_id=visitainicial.patient_id
		inner join obs o on o.encounter_id=e.encounter_id			
		where o.concept_id=5096 and o.voided=0 and e.encounter_datetime=visitainicial.encounter_datetime and 
		e.encounter_type = 18 and e.location_id=:location
	) primeiravisita on primeiravisita.patient_id=inicio_real.patient_id

	left join 
	(
	SELECT 	e.patient_id, MIN(e.encounter_datetime) AS encounter_datetime, primeiravisita.data1
	FROM 		encounter e 
	inner join
	(	select 	p.patient_id,min(encounter_datetime) as data1
		from 	encounter e 
		inner join patient p on p.patient_id=e.patient_id 		
		where 	e.voided=0 and p.voided=0 and e.encounter_type=18 and e.location_id=:location 
		group by p.patient_id
	) primeiravisita on primeiravisita.patient_id=e.patient_id
	
	WHERE e.encounter_type = 18 AND e.voided=0 and e.encounter_datetime > primeiravisita.data1 and e.location_id=:location
	group by patient_id
	) segundavisita on segundavisita.patient_id = inicio_real.patient_id
    
	left join 
	(
	SELECT 	e.patient_id, MIN(e.encounter_datetime) AS encounter_datetime
	FROM  encounter e 
	inner join 
	(
		SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data2, primeiravisita.data1
		FROM 		encounter e 
		inner join
		(	select 	p.patient_id,min(encounter_datetime) as data1
			from 	encounter e 
			inner join patient p on p.patient_id=e.patient_id 		
			where 	e.voided=0 and p.voided=0 and e.encounter_type=18 and e.location_id=:location 
			group by p.patient_id
		) primeiravisita on primeiravisita.patient_id=e.patient_id
	WHERE e.encounter_type = 18 AND e.voided=0 and e.encounter_datetime > primeiravisita.data1 and e.location_id=:location
	group by patient_id
	) segundavisita on segundavisita.patient_id = e.patient_id

	WHERE e.encounter_type = 18 AND e.voided=0 and e.encounter_datetime > segundavisita.data2 and e.location_id=:location
	group by e.patient_id
	) terceiravisita on terceiravisita.patient_id = inicio_real.patient_id 
	
	left join 
	(
	SELECT 	e.patient_id, MIN(e.encounter_datetime) AS encounter_datetime
	FROM  encounter e 
	inner join 	
		(
		SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data3, segundavisita.data2
		FROM  encounter e 
		inner join 
			(
			SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data2, primeiravisita.data1
			FROM 		encounter e 
				inner join
				(	select 	p.patient_id,min(encounter_datetime) as data1
					from 	encounter e 
					inner join patient p on p.patient_id=e.patient_id 		
					where 	e.voided=0 and p.voided=0 and e.encounter_type=18 and e.location_id=:location 
					group by p.patient_id
				) primeiravisita on primeiravisita.patient_id=e.patient_id
			WHERE e.encounter_type = 18 AND e.voided=0 and e.encounter_datetime > primeiravisita.data1 and e.location_id=:location
			group by patient_id
			) segundavisita on segundavisita.patient_id = e.patient_id

		WHERE e.encounter_type = 18 AND e.voided=0 and e.encounter_datetime > segundavisita.data2 and e.location_id=:location
		group by e.patient_id
		) terceiravisita on terceiravisita.patient_id = e.patient_id

	WHERE e.encounter_type = 18 AND e.voided=0 and e.encounter_datetime > terceiravisita.data3 and e.location_id=:location
	group by e.patient_id
	) quartavisita on quartavisita.patient_id = inicio_real.patient_id
		
	left join 
	(Select ultimavisita.patient_id,ultimavisita.encounter_datetime,o.value_datetime,e.location_id
		from

		(	select 	p.patient_id,max(encounter_datetime) as encounter_datetime
			from 	encounter e 
					inner join patient p on p.patient_id=e.patient_id 		
			where 	e.voided=0 and p.voided=0 and e.encounter_type=18 and e.location_id=:location 
			group by p.patient_id
		) ultimavisita
		inner join encounter e on e.patient_id=ultimavisita.patient_id
		inner join obs o on o.encounter_id=e.encounter_id			
		where o.concept_id=5096 and o.voided=0 and e.encounter_datetime=ultimavisita.encounter_datetime and 
		e.encounter_type=18 and e.location_id=:location
	) visita on visita.patient_id=inicio_real.patient_id
	left join
	(Select ultimoSeguimento.patient_id,ultimoSeguimento.encounter_datetime,o.value_datetime,e.location_id
	from

		(	select 	p.patient_id,max(encounter_datetime) as encounter_datetime
			from 	encounter e 
			inner join patient p on p.patient_id=e.patient_id 		
			where 	e.voided=0 and p.voided=0 and e.encounter_type in (6,9) and e.location_id=:location 
			group by p.patient_id
		) ultimoSeguimento
		inner join encounter e on e.patient_id=ultimoSeguimento.patient_id
		inner join obs o on o.encounter_id=e.encounter_id			
		where o.concept_id=1410 and o.voided=0 and e.encounter_datetime=ultimoSeguimento.encounter_datetime and 
		e.encounter_type in (6,9) and e.location_id=:location
	) seguimento on seguimento.patient_id=inicio_real.patient_id
		
	left join 
	(
	SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data_seguimento 
				  FROM 		patient p
				                inner join encounter e on p.patient_id=e.patient_id
				  WHERE		p.voided=0 and e.encounter_type in (6,9) AND e.voided=0 and e.encounter_datetime between date_add(:endDate, interval -3 month) and :endDate and e.location_id=:location
				 group by e.patient_id
	
	) primeiro_seguimento on primeiro_seguimento.patient_id = inicio_real.patient_id 
		
left join 
	(
	SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data_seguimento, seg1.data1
	FROM 		encounter e 
	inner join ( 
		SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data1
                FROM 		patient p
                inner join encounter e on p.patient_id=e.patient_id
  		WHERE		p.voided=0 and e.encounter_type in (6,9) AND e.voided=0 and e.encounter_datetime<= :endDate and e.location_id=:location
 		group by e.patient_id
  		)seg1 on seg1.patient_id = e.patient_id
	WHERE		e.encounter_type in (6,9) AND e.voided=0 and e.encounter_datetime > seg1.data1 and e.location_id=:location
	group by patient_id
	) segundo_seguimento on segundo_seguimento.patient_id = inicio_real.patient_id

left join 
	(
	SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data_seguimento
	FROM 		encounter e 
	left join 
	(
	SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data2
	FROM 		encounter e 
		inner join ( 
			SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data1
			FROM 		patient p
			inner join encounter e on p.patient_id=e.patient_id
	  		WHERE		p.voided=0 and e.encounter_type in (6,9) AND e.voided=0 and e.encounter_datetime<= :endDate and e.location_id=:location
	 		group by e.patient_id
	  )seg1 on seg1.patient_id = e.patient_id
	 WHERE		e.encounter_type in (6,9) AND e.voided=0 and e.encounter_datetime > seg1.data1 and e.location_id=:location
		group by patient_id
	) seg2 on seg2.patient_id = e.patient_id
	WHERE		e.encounter_type in (6,9) AND e.voided=0 and e.encounter_datetime > seg2.data2 and e.location_id=:location
	group by e.patient_id
	) terceiro_seguimento on terceiro_seguimento.patient_id = inicio_real.patient_id 

left join 
	(
		SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data_seguimento
		FROM 		encounter e 	
		left join 
			(
			SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data3
						  FROM 		encounter e 
						left join 
							(
							SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data2
										  FROM 		encounter e 
											inner join ( 
												SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data1
														FROM 		patient p
														inner join encounter e on p.patient_id=e.patient_id
										  		WHERE		p.voided=0 and e.encounter_type in (6,9) AND e.voided=0 and e.encounter_datetime<= :endDate and e.location_id=:location
										 		group by e.patient_id
										  )seg1 on seg1.patient_id = e.patient_id
										  WHERE		e.encounter_type in (6,9) AND e.voided=0 and e.encounter_datetime > seg1.data1 and e.location_id=:location
								group by patient_id
							) seg2 on seg2.patient_id = e.patient_id
										  WHERE		e.encounter_type in (6,9) AND e.voided=0 and e.encounter_datetime > seg2.data2 and e.location_id=:location
						  group by e.patient_id
			) seg3 on seg3.patient_id = e.patient_id 			
		WHERE	e.encounter_type in (6,9) AND e.voided=0 and e.encounter_datetime > seg3.data3 and e.location_id=:location
	    group by e.patient_id
	) quarto_seguimento on quarto_seguimento.patient_id = inicio_real.patient_id
	
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
                         ) ultimavisita
				on e.patient_id=ultimavisita.patient_id
                inner join obs o on o.encounter_id=e.encounter_id 
				where  ultimavisita.encounter_datetime = e.encounter_datetime and
                        encounter_type in (6,9) and e.voided=0 and o.voided=0 and 
						o.concept_id=1087 and o.location_id=:location
              
			) regime on regime.patient_id=inicio_real.patient_id
			left join
			(
				select 	pg.patient_id
				from 	patient p inner join patient_program pg on p.patient_id=pg.patient_id
				where 	pg.voided=0 and p.voided=0 and program_id=2 and date_enrolled<=:endDate and location_id=:location
			) programa on programa.patient_id=inicio_real.patient_id

			left join 
			(
				select 	pgg.patient_id,max(pgg.date_enrolled) as date_enrolled
				from 	patient pt inner join patient_program pgg on pt.patient_id=pgg.patient_id
				where 	pgg.voided=0 and pt.voided=0 and pgg.program_id=5 and pgg.date_completed is null and pgg.date_enrolled <=:endDate and pgg.location_id=:location
				group by pgg.patient_id
			) inscrito_tb on inscrito_tb.patient_id=inicio_real.patient_id

			left join 
			(
				select 	pgg.patient_id,max(pgg.date_enrolled) as date_enrolled
				from 	patient pt inner join patient_program pgg on pt.patient_id=pgg.patient_id
				where 	pgg.voided=0 and pt.voided=0 and pgg.program_id in (3,4,8) and pgg.date_completed is null and pgg.date_enrolled <=:endDate and pgg.location_id=:location
				group by pgg.patient_id
			) inscrito_smi on inscrito_smi.patient_id=inicio_real.patient_id

			left join 
			(
				select 	pgg.patient_id,max(pgg.date_enrolled) as date_enrolled
				from 	patient pt inner join patient_program pgg on pt.patient_id=pgg.patient_id
				where 	pgg.voided=0 and pt.voided=0 and pgg.program_id=6 and pgg.date_completed is null and pgg.date_enrolled <=:endDate and pgg.location_id=:location
				group by pgg.patient_id
			) inscrito_ccr on inscrito_ccr.patient_id=inicio_real.patient_id

			left join
			(			
				select 	pg.patient_id,pg.date_enrolled
				from 	patient p 
						inner join patient_program pg on p.patient_id=pg.patient_id
						inner join patient_state ps on pg.patient_program_id=ps.patient_program_id
				where 	pg.voided=0 and ps.voided=0 and p.voided=0 and 
						pg.program_id=2 and ps.state=29 and ps.start_date=pg.date_enrolled and 
						ps.start_date between :startDate and :endDate and location_id=:location
			)transferidode on transferidode.patient_id=inicio_real.patient_id
            
         /*******numero de confidente********/

left join 
(
select resultado_numero_confidente, nr_confidente.patient_id
			from	
				(	select 	patient_id, o.value_text as 'resultado_numero_confidente'
							
					from 	encounter e
							inner join obs o on e.encounter_id=o.encounter_id
					where 	e.encounter_type in (53,34) and e.voided=0 and
							o.voided=0 and o.concept_id in (6224,1611)and e.location_id=:location
			
				) nr_confidente
)numero_confidente on numero_confidente.patient_id = inicio_real.patient_id	   
			/** **************************************** key pop  **************************************** **/
    LEFT JOIN 
		(
			SELECT 	e.patient_id,
				CASE o.value_coded
					WHEN '1377'  THEN 'HSH'
					WHEN '20454' THEN 'PID'
					WHEN '20426' THEN 'REC'
					WHEN '1901'  THEN 'MTS'
					WHEN '23885' THEN 'Outro'
				ELSE '' END AS populacaochave,
				max(encounter_datetime) as data_keypop
			FROM 	obs o
			INNER JOIN encounter e ON e.encounter_id=o.encounter_id
			WHERE 	e.encounter_type IN (6,9,34,35) AND e.voided=0 AND o.voided=0 AND o.concept_id = 23703 AND o.location_id=:location
            group by patient_id
		) keypop ON keypop.patient_id=inicio_real.patient_id

            
            	/** **************************************** TPI  **************************************** **/
            left join
			(	select patient_id, max(data_inicio_tpi) as data_inicio_tpi
            from ( select e.patient_id,max(value_datetime) data_inicio_tpi
				from	encounter e
						inner join obs o on o.encounter_id=e.encounter_id
				where 	e.voided=0 and  o.value_datetime<=:endDate and
						o.voided=0 and o.concept_id=6128 and e.encounter_type in (6,9,53) and e.location_id=:location
				group by e.patient_id
				
				union
				
				select e.patient_id,max(e.encounter_datetime) data_inicio_tpi
				from	 encounter e 
						inner join obs o on o.encounter_id=e.encounter_id
				where 	e.voided=0 and o.obs_datetime<=:endDate and
						o.voided=0 and o.concept_id=6122 and o.value_coded=1256 and e.encounter_type in (6,9) and e.location_id=:location
				group by e.patient_id
				 ) tpi_ficha_segui_clinc
                 
			) inicio_tpi on inicio_tpi.patient_id=inicio_real.patient_id
		  /****************** ****************************  CD4   ********* *****************************************************/
        LEFT JOIN(  
        	SELECT 	e.patient_id,o.value_numeric cd4,  MAX(encounter_datetime)
			FROM encounter e 
					INNER JOIN obs o ON o.encounter_id=e.encounter_id
			WHERE 	e.voided=0  AND 
					o.voided=0 AND o.concept_id=1695 AND e.encounter_type IN (6,9,53)  
			GROUP BY e.patient_id
		) cd4 ON cd4.patient_id =  inicio_real.patient_id
   
			left join
			(	select 	p.patient_id
				from 	encounter e 
				inner join patient p on p.patient_id=e.patient_id 
				inner join obs o on o.encounter_id=e.encounter_id			
				where o.concept_id = 1738 and o.value_coded=1065 and o.voided=0 and e.voided=0 and p.voided=0 and e.encounter_type = 19 and e.location_id=:location 
				group by p.patient_id
			union
				select 	p.patient_id
				from 	encounter e 
				inner join patient p on p.patient_id=e.patient_id 
				inner join obs o on o.encounter_id=e.encounter_id			
				where o.concept_id=6306 and o.value_coded=1065 and o.voided=0 and e.voided=0 and p.voided=0 and e.encounter_type = 34 and e.location_id=:location 
				group by p.patient_id
			union
				select 	p.patient_id
				from 	encounter e 
				inner join patient p on p.patient_id=e.patient_id 			
				where e.voided=0 and p.voided=0 and e.encounter_type = 30 and e.location_id=:location 
				group by p.patient_id
			) consentimento on consentimento.patient_id=inicio_real.patient_id

			
	)inicios
group by patient_id