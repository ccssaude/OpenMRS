use canico;
SET @startDate:='2020-03-21';
SET @endDate:='2020-04-20';
SET @location:=212;

select * 
from 
(select 	inicio_real.patient_id,
			concat(pid.identifier,' ') as NID,
            concat(ifnull(pn.given_name,''),' ',ifnull(pn.middle_name,''),' ',ifnull(pn.family_name,'')) as 'NomeCompleto',
			p.gender,
            round(datediff(@endDate,p.birthdate)/365) idade_actual,
			inicio_real.data_inicio,
            weight.peso as peso,
            height.altura ,
            hemog.hemoglobina,
            cd4.cd4,
            cv.carga_viral,
			cv_qualitativa.carga_viral_qualitativa,
			escola.nivel_escolaridade,
			telef.value as telefone,
            regime.ultimo_regime,
			regime.data_regime,
			visita.encounter_datetime as ultimo_levantamento,
			visita.value_datetime as proximo_marcado,
            3_ult_fila.encounter_datetime as data_lev_3,
            2_ult_fila.encounter_datetime as data_lev_2,
            ult_fila.encounter_datetime as data_ult_levantamento,
            3_ult_vis.encounter_datetime as data_visita_3,
            2_ult_vis.encounter_datetime as data_visita_2,
            ult_vis.encounter_datetime as data_ult_visita,
			if(programa.patient_id is null,'NAO','SIM') inscrito_programa,
			if(mastercard.patient_id is null,'NAO','SIM') temmastercard,
			if(mastercardFResumo.patient_id is null,'NAO','SIM') temmastercardFR,
			if(mastercardFClinica.patient_id is null,'NAO','SIM') temmastercardFC,
			if(mastercardFAPSS.patient_id is null,'NAO','SIM') temmastercardFA,
			if(keypop.populacaochave is null,'',keypop.populacaochave) mastercardkeypop,
			if(datediff(@endDate,visita.value_datetime)<=33,'ACTIVO EM TARV','ABANDONO NAO NOTIFICADO') estado,
			if(datediff(@endDate,visita.value_datetime)>33,DATE_FORMAT(date_add(visita.value_datetime, interval 33 day),'%d/%m/%Y'),'') dataAbandono,
			if(gaaac.member_id is null,'NÃO','SIM') emgaac,
            pad3.county_district as 'Distrito',
			pad3.address2 as 'Padministrativo',
			pad3.address6 as 'Localidade',
			pad3.address5 as 'Bairro',
			pad3.address1 as 'PontoReferencia'

			
	from	
		(	Select patient_id,min(data_inicio) data_inicio
			from
				(	Select p.patient_id,min(e.encounter_datetime) data_inicio
					from 	patient p 
							inner join encounter e on p.patient_id=e.patient_id	
							inner join obs o on o.encounter_id=e.encounter_id
					where 	e.voided=0 and o.voided=0 and p.voided=0 and 
							e.encounter_type in (18,6,9) and o.concept_id=1255 and o.value_coded=1256 and 
							e.encounter_datetime<=@endDate and e.location_id=@location
					group by p.patient_id
				
					union
				
					Select p.patient_id,min(value_datetime) data_inicio
					from 	patient p
							inner join encounter e on p.patient_id=e.patient_id
							inner join obs o on e.encounter_id=o.encounter_id
					where 	p.voided=0 and e.voided=0 and o.voided=0 and e.encounter_type in (18,6,9) and 
							o.concept_id=1190 and o.value_datetime is not null and 
							o.value_datetime<=@endDate and e.location_id=@location
					group by p.patient_id
					
					union
					
					select 	pg.patient_id,pg.date_enrolled data_inicio
					from 	patient p inner join patient_program pg on p.patient_id=pg.patient_id
					where 	pg.voided=0 and p.voided=0 and program_id=2 and date_enrolled<=@endDate and location_id=@location
					
					
				) inicio
			group by patient_id
		) inicio_real
		inner join person p on p.person_id=inicio_real.patient_id
		
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
		
		inner join		
		(	Select ultimavisita.patient_id,ultimavisita.encounter_datetime,o.value_datetime,e.location_id
			from
				(	select 	p.patient_id,max(encounter_datetime) as encounter_datetime
					from 	encounter e 
							inner join patient p on p.patient_id=e.patient_id 		
					where 	e.voided=0 and p.voided=0 and e.encounter_type in (18,9,6) and 
							e.location_id=@location and e.encounter_datetime<=@endDate
					group by p.patient_id
				) ultimavisita
				inner join encounter e on e.patient_id=ultimavisita.patient_id
				left join obs o on o.encounter_id=e.encounter_id and (o.concept_id=5096 OR o.concept_id=1410)and e.encounter_datetime=ultimavisita.encounter_datetime			
			where  o.voided=0  and e.voided =0 and e.encounter_type in (18,9,6) and e.location_id=@location
		) visita on visita.patient_id=inicio_real.patient_id
		left join 
		(
			select 	ultimo_lev.patient_id,
					case o.value_coded
						when 6103 then 'D4T+3TC+LPV/r'
							when 792 then 'D4T+3TC+NVP'
							when 1827 then 'D4T+3TC+EFV'
							when 6102 then 'D4T+3TC+ABC'
							when 6116 then 'AZT+3TC+ABC'
							when 6330 then 'AZT+3TC+RAL+DRV/r (3ª Linha)'
							when 6105 then 'ABC+3TC+NVP'
							when 6325 then 'D4T+3TC+ABC+LPV/r (2ª Linha)'
							when 6326 then 'AZT+3TC+ABC+LPV/r (2ª Linha)'
							when 6327 then 'D4T+3TC+ABC+EFV (2ª Linha)'
							when 6328 then 'AZT+3TC+ABC+EFV (2ª Linha)'
							when 6109 then 'AZT+DDI+LPV/r (2ª Linha)'
							when 6106 then 'ABC+3TC+LPV/r'
							when 1313 then 'ABC+3TC+EFV(2ª Linha)'
							when 1311 then 'ABC+3TC+LPV/r(2ª Linha)'
							when 23799 then 'TDF+3TC+DTG(2ª Linha)'
							when 23800 then 'ABC+3TC+DTG(2ª Linha)'
							when 21163 then 'AZT+3TC+LPV/r(2ª Linha)'
							when 23801 then 'AZT+3TC+RAL(2ª Linha)'
							when 23802 then 'AZT+3TC+DRV/r(2ª Linha)'
							when 23815 then 'AZT+3TC+DTG(2ª Linha)'
							when 6329 then 'TDF+3TC+RAL+DRV/r(3ª Linha)'
							when 23803 then 'AZT+3TC+RAL+DRV/r(3ª Linha)'							
							when 1703 then 'AZT+3TC+EFV'
							when 6100 then 'AZT+3TC+LPV/r'
							when 1651 then 'AZT+3TC+NVP'
							when 6324 then 'TDF+3TC+EFV'
							when 6243 then 'TDF+3TC+NVP'
							when 6104 then 'ABC+3TC+EFV'
							when 23784 then 'TDF+3TC+DTG'
							when 23786 then 'ABC+3TC+DTG'
							when 23785 then 'TDF+3TC+DTG2'
							when 1311 then 'ABC+3TC+LPV/r(2ª Linha)'
							when 6108 then 'TDF+3TC+LPV/r(2ª Linha)'
							when 1314 then 'AZT+3TC+LPV/r(2ª Linha)'
							when 23790 then 'TDF+3TC+LPV/r+RTV(2ª Linha)'
							when 23791 then 'TDF+3TC+ATV/r(2ª Linha)'
							when 23792 then 'ABC+3TC+ATV/r(2ª Linha)'
							when 23793 then 'AZT+3TC+ATV/r(2ª Linha)'
							when 23795 then 'ABC+3TC+ATV/r+RAL(2ª Linha)'
							when 23796 then 'TDF+3TC+ATV/r+RAL(2ª Linha)'
							when 6329 then 'TDF+3TC+RAL+DRV/r(3ª Linha)'
							when 23797 then 'ABC+3TC++RAL+DRV/r(3ª Linha)'
							when 23798 then '3TC+RAL+DRV/r(3ª Linha)'
					else 'OUTRO' end as ultimo_regime,
					ultimo_lev.encounter_datetime data_regime
			from 	obs o,				
					(	select p.patient_id,max(encounter_datetime) as encounter_datetime
						from 	patient p
								inner join encounter e on p.patient_id=e.patient_id								
						where 	encounter_type=18 and e.voided=0 and
								encounter_datetime <=@endDate and e.location_id=@location and p.voided=0
						group by patient_id
					) ultimo_lev
			where 	o.person_id=ultimo_lev.patient_id and o.obs_datetime=ultimo_lev.encounter_datetime and o.voided=0 and 
					o.concept_id=1088 and o.location_id=@location
		) regime on regime.patient_id=inicio_real.patient_id
		left join
		(
			select 	pg.patient_id
			from 	patient p inner join patient_program pg on p.patient_id=pg.patient_id
			where 	pg.voided=0 and p.voided=0 and program_id=2 and date_enrolled<=@endDate and location_id=@location
		) programa on programa.patient_id=inicio_real.patient_id
		left join 
		(
			select 	patient_id, max(encounter_datetime) dataRegisto
			from 	encounter 
			where 	encounter_type = 52 and voided=0
			group by patient_id
		) mastercard on mastercard.patient_id = inicio_real.patient_id
		
		left join 
		(
			select 	patient_id, max(encounter_datetime) dataRegisto
			from 	encounter 
			where 	encounter_type = 53 and form_id = 165 and voided=0
			group by patient_id
		) mastercardFResumo on mastercardFResumo.patient_id = inicio_real.patient_id
		
		left join 
		(
			select 	patient_id, max(encounter_datetime) dataRegisto
			from 	encounter 
			where 	encounter_type in (6,9) and form_id = 163 and voided=0
			group by patient_id
		) mastercardFClinica on mastercardFClinica.patient_id = inicio_real.patient_id
	
		left join 
		(
			select 	patient_id, max(encounter_datetime) dataRegisto
			from 	encounter 
			where 	encounter_type in (34,35) and form_id = 164 and voided=0
			group by patient_id
		) mastercardFAPSS on mastercardFAPSS.patient_id = inicio_real.patient_id

		left join 
		(
			select 	e.patient_id,
				case o.value_coded
					when '1377'  then 'HSH'
					when '20454' then 'PID'
					when '20426' then 'REC'
					when '1901'  then 'MTS'
					when '23885' then 'Outro'
				else '' end as populacaochave,
				o.value_text as outrokeypop
			from 	obs o
			inner join encounter e on e.patient_id=o.person_id
			where 	e.encounter_type in (6,9,34,35) and e.voided=0 and o.voided=0 and o.concept_id = 23703 and o.location_id=@location
		) keypop on keypop.patient_id=inicio_real.patient_id

		left join
		(
			select distinct member_id from gaac_member where voided=0
		) gaaac on gaaac.member_id=inicio_real.patient_id
        
        /************  Peso  *********************/
        left join(  
        	select 	p.patient_id,o.value_numeric peso,  max(obs_datetime)
			from	patient p
					inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on o.encounter_id=e.encounter_id
			where 	e.voided=0 and p.voided=0  and 
					o.voided=0 and o.concept_id=5089 and e.encounter_type in (6,9,53)  
                    and e.form_id = 163 
			group by p.patient_id
		) weight on weight.patient_id =  inicio_real.patient_id
        
               /************  Altura  *********************/
        left join(  
        	select 	p.patient_id,o.value_numeric altura,  max(obs_datetime)
			from	patient p
					inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on o.encounter_id=e.encounter_id
			where 	e.voided=0 and p.voided=0  and 
					o.voided=0 and o.concept_id=5090 and e.encounter_type in (6,9,53)  
                    and e.form_id = 163 
			group by p.patient_id
		) height on height.patient_id =  inicio_real.patient_id
        
                       /************  Hemoglobina  *********************/
        left join(  
        	select 	p.patient_id,o.value_numeric hemoglobina,  max(obs_datetime)
			from	patient p
					inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on o.encounter_id=e.encounter_id
			where 	e.voided=0 and p.voided=0  and 
					o.voided=0 and o.concept_id=1692 and e.encounter_type in (6,9,53)  
                    and e.form_id = 163 
			group by p.patient_id
		) hemog on hemog.patient_id =  inicio_real.patient_id
        
                    /************  CD4   *********************/
        left join(  
        	select 	p.patient_id,o.value_numeric cd4,  max(obs_datetime)
			from	patient p
					inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on o.encounter_id=e.encounter_id
			where 	e.voided=0 and p.voided=0  and 
					o.voided=0 and o.concept_id=1695 and e.encounter_type in (6,9,53)  
                    and e.form_id = 163 
			group by p.patient_id
		) cd4 on cd4.patient_id =  inicio_real.patient_id
        
                /************  viral load   *********************/
        left join(  
        	select 	p.patient_id,o.value_numeric carga_viral,  max(obs_datetime)
			from	patient p
					inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on o.encounter_id=e.encounter_id
			where 	e.voided=0 and p.voided=0  and 
					o.voided=0 and o.concept_id=1695 and e.encounter_type in (6,9,53)  
                    and e.form_id = 163 
			group by p.patient_id
		) cv on cv.patient_id =  inicio_real.patient_id
        
                         /************  viral load qualitativa  *********************/
        left join(  
        	        	select 	o.person_id,
					 CASE o.value_coded
                WHEN 1306  THEN  'Nivel baixo de detencao'
                WHEN 23814 THEN  'Indectetavel'
                WHEN 23905 THEN  'Menor que 10 copias/ml'
                WHEN 23906 THEN  'Menor que 20 copias/ml'
                WHEN 23907 THEN  'Menor que 40 copias/ml'
                WHEN 23908 THEN  'Menor que 400 copias/ml'
                WHEN 23904 THEN  'Menor que 839 copias/ml'
                ELSE 'OUTRO'
            END  AS carga_viral_qualitativa,
					ult_cv.encounter_datetime data_cv_qualitativa,
                    e.encounter_id
			FROM 	obs o,				
					(	SELECT p.patient_id,MAX(encounter_datetime) AS encounter_datetime
						FROM 	patient p
								INNER JOIN encounter e ON p.patient_id=e.patient_id								
						WHERE 	encounter_type in (6,9,53) AND e.voided=0 AND
								encounter_datetime <=@endDate and e.location_id=@location and p.voided=0
						GROUP BY patient_id
					) ult_cv, encounter e 
			WHERE 	o.person_id=ult_cv.patient_id AND o.obs_datetime=ult_cv.encounter_datetime AND o.voided=0 AND 
					o.concept_id=1305     and e.form_id = 163  and o.location_id=@location and e.patient_id=ult_cv.patient_id
		) cv_qualitativa on cv_qualitativa.person_id =  inicio_real.patient_id

       /*   ********************   ultimo levantamento ***************    */
		left join
		(
	
	SELECT visita2.patient_id , 
(	select	 visita.encounter_datetime
					from 
                    ( select p.patient_id,  e.encounter_datetime from  encounter e 
							inner join patient p on p.patient_id=e.patient_id 		
					where 	e.voided=0 and p.voided=0 and e.encounter_type in (18) and e.form_id =130  
							and e.encounter_datetime<=@endDate
						) visita
    WHERE visita.patient_id = visita2.patient_id
    ORDER BY encounter_datetime  desc
    LIMIT 0,1
) as encounter_datetime
FROM 	   ( select p.patient_id, e.encounter_datetime from  encounter e 
							inner join patient p on p.patient_id=e.patient_id 		
					where 	e.voided=0 and p.voided=0 and e.encounter_type in (18) and e.form_id =130  
							and e.encounter_datetime<=@endDate
				) visita2
GROUP BY visita2.patient_id  

		) ult_fila on ult_fila.patient_id = inicio_real.patient_id

  /*   ********************   penultimo  levantamento ***************    */
		left join
		(
		
		SELECT visita2.patient_id , 
(	select	 visita.encounter_datetime
					from 
                    ( select p.patient_id,  e.encounter_datetime from  encounter e 
							inner join patient p on p.patient_id=e.patient_id 		
					where 	e.voided=0 and p.voided=0 and e.encounter_type in (18) and e.form_id =130  
							and e.encounter_datetime<=@endDate
						) visita
    WHERE visita.patient_id = visita2.patient_id
    ORDER BY encounter_datetime  desc
    LIMIT 1,1
) as encounter_datetime
FROM 	   ( select p.patient_id, e.encounter_datetime from  encounter e 
							inner join patient p on p.patient_id=e.patient_id 		
					where 	e.voided=0 and p.voided=0 and e.encounter_type in (18) and e.form_id =130  
							and e.encounter_datetime<=@endDate
				) visita2
GROUP BY visita2.patient_id  

		) 2_ult_fila on 2_ult_fila.patient_id = inicio_real.patient_id

  /*   ********************   3 ultimo  levantamento ***************    */
		left join
		(
		SELECT visita2.patient_id , 
(	select	 visita.encounter_datetime
					from 
                    ( select p.patient_id,  e.encounter_datetime from  encounter e 
							inner join patient p on p.patient_id=e.patient_id 		
					where 	e.voided=0 and p.voided=0 and e.encounter_type in (18) and e.form_id =130  
							and e.encounter_datetime<=@endDate
						) visita
    WHERE visita.patient_id = visita2.patient_id
    ORDER BY encounter_datetime  desc
    LIMIT 2,1
) as encounter_datetime
FROM 	   ( select p.patient_id, e.encounter_datetime from  encounter e 
							inner join patient p on p.patient_id=e.patient_id 		
					where 	e.voided=0 and p.voided=0 and e.encounter_type in (18) and e.form_id =130  
							and e.encounter_datetime<=@endDate
				) visita2
GROUP BY visita2.patient_id  

		) 3_ult_fila on 3_ult_fila.patient_id = inicio_real.patient_id

		/*  ***********************  ultima visita  *********************/ 
		left join (


SELECT visita2.patient_id , 
(	select	 visita.encounter_datetime
					from 
                    ( select p.patient_id,  e.encounter_datetime from  encounter e 
							inner join patient p on p.patient_id=e.patient_id 		
					where 	e.voided=0 and p.voided=0 and e.encounter_type in (6,9) 
							and e.encounter_datetime<=@endDate
						) visita
    WHERE visita.patient_id = visita2.patient_id
    ORDER BY encounter_datetime  desc
    LIMIT 0,1
) as encounter_datetime
FROM 	   ( select p.patient_id, e.encounter_datetime from  encounter e 
							inner join patient p on p.patient_id=e.patient_id 		
					where 	e.voided=0 and p.voided=0 and e.encounter_type in (6,9) 
							and e.encounter_datetime<=@endDate
				) visita2
GROUP BY visita2.patient_id  
		) ult_vis on ult_vis.patient_id = inicio_real.patient_id

				/*  ***********************  penultima visita  *********************/ 
		left join (


SELECT visita2.patient_id , 
(	select	 visita.encounter_datetime
					from 
                    ( select p.patient_id,  e.encounter_datetime from  encounter e 
							inner join patient p on p.patient_id=e.patient_id 		
					where 	e.voided=0 and p.voided=0 and e.encounter_type in (6,9) 
							and e.encounter_datetime<=@endDate
						) visita
    WHERE visita.patient_id = visita2.patient_id
    ORDER BY encounter_datetime  desc
    LIMIT 1,1
) as encounter_datetime
FROM 	   ( select p.patient_id, e.encounter_datetime from  encounter e 
							inner join patient p on p.patient_id=e.patient_id 		
					where 	e.voided=0 and p.voided=0 and e.encounter_type in (6,9) 
							and e.encounter_datetime<=@endDate
				) visita2
GROUP BY visita2.patient_id  
		) 2_ult_vis on 2_ult_vis.patient_id = inicio_real.patient_id

		/*  ***********************  3 ultima  visita  *********************/ 
		left join (


SELECT visita2.patient_id , 
(	select	 visita.encounter_datetime
					from 
                    ( select p.patient_id,  e.encounter_datetime from  encounter e 
							inner join patient p on p.patient_id=e.patient_id 		
					where 	e.voided=0 and p.voided=0 and e.encounter_type in (6,9) 
							and e.encounter_datetime<=@endDate
						) visita
    WHERE visita.patient_id = visita2.patient_id
    ORDER BY encounter_datetime  desc
    LIMIT 2,1
) as encounter_datetime
FROM 	   ( select p.patient_id, e.encounter_datetime from  encounter e 
							inner join patient p on p.patient_id=e.patient_id 		
					where 	e.voided=0 and p.voided=0 and e.encounter_type in (6,9) 
							and e.encounter_datetime<=@endDate
				) visita2
GROUP BY visita2.patient_id  
		) 3_ult_vis on 3_ult_vis.patient_id = inicio_real.patient_id
            
	/* ************************ escolaridade ****************************** */

	left join (
	
        	select 	o.person_id,
	 CASE o.value_coded
                WHEN 1445  THEN  'NENHUMA EDUCAÇÃO FORMAL'
                WHEN 1446 THEN  'PRIMARIO'
               WHEN 1447 THEN  'SECONDÁRIO, NIVEL BASICO'
              WHEN 1448 THEN  ' UNIVERSITARIO'
               WHEN 6124 THEN  'TÉCNICO BÁSICO'
                WHEN 1444 THEN  'TÉCNICO MÉDIO'
               ELSE 'OUTRO'
           END  AS nivel_escolaridade
    
			FROM 	obs o, encounter e 
			WHERE 	o.person_id=e.patient_id and o.voided=0 and e.voided=0   
            and o.concept_id = 1443 
            and  e.form_id =165 
            and encounter_type=53
              
	) escola on escola.person_id = inicio_real.patient_id

	/* ******************************* Telefone **************************** */
	left join (
		select  p.person_id, p.value  
		from person_attribute p
     where  p.person_attribute_type_id=9 
    and p.value is not null and p.value<>'' and p.voided=0 
	) telef  on telef.person_id = inicio_real.patient_id

	where inicio_real.patient_id not in 
		(		
			select 	pg.patient_id					
			from 	patient p 
					inner join patient_program pg on p.patient_id=pg.patient_id
					inner join patient_state ps on pg.patient_program_id=ps.patient_program_id
			where 	pg.voided=0 and ps.voided=0 and p.voided=0 and 
					pg.program_id=2 and ps.state in (7,8,9,10) and 
					ps.end_date is null and location_id=@location and ps.start_date<=@endDate		
		)
) activos
group by patient_id