
SELECT * 
FROM 
( SELECT 	inicio_real.patient_id,
			CONCAT(pid.identifier,' ') AS NID,
            CONCAT(IFNULL(pn.given_name,''),' ',IFNULL(pn.middle_name,''),' ',IFNULL(pn.family_name,'')) AS 'NomeCompleto',
			p.gender,
            ROUND(DATEDIFF(:endDate,p.birthdate)/365) idade_actual,
            DATE_FORMAT(inicio_real.data_inicio,'%d/%m/%Y') as data_inicio,
			DATE_FORMAT(inicio_tpi.data_inicio_tpi ,'%d/%m/%Y') as data_inicio_tpi ,
            DATE_FORMAT(fim_tpi.data_fim_tpi ,'%d/%m/%Y') as data_fim_tpi ,
            datediff( fim_tpi.data_fim_tpi , inicio_tpi.data_inicio_tpi ) as curso_normal_tpi_fim,
            DATE_FORMAT(ult_seguimento.encounter_datetime,'%d/%m/%Y') as data_ultima_visita,
            DATE_FORMAT(ult_seguimento.value_datetime,'%d/%m/%Y') as data_proxima_visita,
            -- ultimo_regime.regime,
            -- cv.carga_viral,
      CONCAT( if(inscrito_smi.date_enrolled is null,'','_SMI'),' ',if(inscrito_ccr.date_enrolled is null,'','_CCR')) AS proveniencia,
			telef.value AS telefone,
		    pad3.county_district AS 'Distrito',
			pad3.address2 AS 'Padministrativo',
			pad3.address6 AS 'Localidade',
			pad3.address5 AS 'Bairro',
			pad3.address1 AS 'PontoReferencia' 

            			
	FROM	
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
					  

				
			) inicio
		GROUP BY patient_id	
	) inicio_real
    INNER JOIN		
		(	SELECT ultimavisita.patient_id,ultimavisita.encounter_datetime,o.value_datetime,e.location_id
			FROM
				(	SELECT 	p.patient_id,MAX(encounter_datetime) AS encounter_datetime
					FROM 	encounter e 
							INNER JOIN patient p ON p.patient_id=e.patient_id 		
					WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type IN (6,16,9,18,53) AND 
							e.location_id=:location AND e.encounter_datetime<=:endDate
					GROUP BY p.patient_id
				) ultimavisita
				INNER JOIN encounter e ON e.patient_id=ultimavisita.patient_id
				LEFT JOIN obs o ON o.encounter_id=e.encounter_id AND (o.concept_id=5096 OR o.concept_id=1410)AND e.encounter_datetime=ultimavisita.encounter_datetime			
			WHERE  o.voided=0  AND e.voided =0 AND e.encounter_type IN (6,16,9,18,53) AND e.location_id=:location
            group by patient_id
		) ultimavisita ON ultimavisita.patient_id=inicio_real.patient_id and DATEDIFF(:endDate,ultimavisita.value_datetime) <= 28
       
	INNER JOIN person p ON p.person_id=inicio_real.patient_id
  -- Demographic data 
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
			) pad3 ON pad3.person_id=inicio_real.patient_id				
			LEFT JOIN 			
			(	SELECT pn1.*
				FROM person_name pn1
				INNER JOIN 
				(
					SELECT person_id,MIN(person_name_id) id 
					FROM person_name
					WHERE voided=0
					GROUP BY person_id
				) pn2
				WHERE pn1.person_id=pn2.person_id AND pn1.person_name_id=pn2.id
			) pn ON pn.person_id=inicio_real.patient_id			
			LEFT JOIN
			(       SELECT pid1.*
					FROM patient_identifier pid1
					INNER JOIN
					(
						SELECT patient_id,MIN(patient_identifier_id) id
						FROM patient_identifier
						WHERE voided=0
						GROUP BY patient_id
					) pid2
					WHERE pid1.patient_id=pid2.patient_id AND pid1.patient_identifier_id=pid2.id
			) pid ON pid.patient_id=inicio_real.patient_id
 -- FIM TPI  
            left join
			(	select    patient_id,  max(tpi_ficha_segui_clinc.data_inicio_tpi) as data_fim_tpi , encounter_type
                from ( select e.patient_id,max(value_datetime) data_inicio_tpi, encounter_type
				from	encounter e
						inner join obs o on o.encounter_id=e.encounter_id
				where 	e.voided=0  and
						o.voided=0 and o.concept_id = 6129 and e.encounter_type in (6,9,53) and e.location_id=:location
				group by e.patient_id
						union
				select e.patient_id,max(e.encounter_datetime) data_inicio_tpi, encounter_type
				from	 encounter e 
						inner join obs o on o.encounter_id=e.encounter_id
				where 	e.voided=0 and
						o.voided=0 and o.concept_id= 6122 and o.value_coded = 1267 and e.encounter_type in (6,9) and e.location_id=:location
				group by e.patient_id
				 ) tpi_ficha_segui_clinc   group by patient_id 
			) fim_tpi on fim_tpi.patient_id=inicio_real.patient_id 
 --  INICIO TPI  
          left  join
			(	select    patient_id,  max(tpi_ficha_segui_clinc.data_inicio_tpi) as data_inicio_tpi , encounter_type
                from ( select e.patient_id,max(value_datetime) data_inicio_tpi, encounter_type
				from	encounter e
						inner join obs o on o.encounter_id=e.encounter_id
				where 	e.voided=0  and
						o.voided=0 and o.concept_id=6128 and e.encounter_type in (6,9,53) and e.location_id=:location
				group by e.patient_id
						union
				select e.patient_id,max(e.encounter_datetime) data_inicio_tpi, encounter_type
				from	 encounter e 
						inner join obs o on o.encounter_id=e.encounter_id
				where 	e.voided=0 and
						o.voided=0 and o.concept_id=6122 and o.value_coded=1256 and e.encounter_type in (6,9) and e.location_id=:location
				group by e.patient_id
				 ) tpi_ficha_segui_clinc   group by patient_id
			) inicio_tpi on inicio_tpi.patient_id=inicio_real.patient_id  
 
			
 -- inicio Tratamento TB   
    left join 
    (	select patient_id,max(data_inicio_tb) data_inicio_tb
		from
		(	select 	p.patient_id,o.value_datetime data_inicio_tb
			from 	patient p
					inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on o.encounter_id=e.encounter_id
			where 	e.encounter_type in (6,9) and e.voided=0 and o.voided=0 and p.voided=0 and
					o.concept_id=1113 and e.location_id=:location and 
					o.value_datetime  between date_sub(:endDate, interval 7 MONTH) and :endDate
			union 
			
			select 	patient_id,date_enrolled data_inicio_tb
			from 	patient_program
			where	program_id=5 and voided=0 and
					location_id=:location
		) inicio1
		group by patient_id
	) inicio_tb  on inicio_tb.patient_id = inicio_real.patient_id
 --       EM TRATAMENTO TB    
 left join (
	Select ultimavisita.patient_id,ultimavisita.encounter_datetime as data_ult_consulta,
    case o.value_coded
    when 1256 then 'CASO NOVO'
    when 1257 then 'CONTINUA'
    WHEN 1267 THEN 'COMPLETO'
    WHEN 1066 THEN 'NAO'
    WHEN 1065 THEN 'SIM'
    else 'UNKN'  end as sintomas
		from
			(	select 	p.patient_id,max(encounter_datetime) as encounter_datetime
				from 	encounter e 
						inner join patient p on p.patient_id=e.patient_id 		
				where 	e.voided=0 and p.voided=0 and e.encounter_type in (9,6) 
				group by p.patient_id
			) ultimavisita
			inner join encounter e on e.patient_id=ultimavisita.patient_id
			inner join obs o on o.encounter_id=e.encounter_id			
			where o.concept_id = 1268 and o.voided=0 and e.voided=0 and e.encounter_datetime=ultimavisita.encounter_datetime and 
			e.encounter_type in (9,6) and e.location_id=:location 
            ) em_tratamento_tb on em_tratamento_tb.patient_id = inicio_real.patient_id

-- sintomas de TB na ultima consulta 
left join (
	Select ultimavisita.patient_id,ultimavisita.encounter_datetime as data_ult_consulta,
    case o.value_coded
    when 1065 then 'Sim'
    when 1066 then 'Nao'
    else 'Nao'  end as sintomas
		from

			(	select 	p.patient_id,max(encounter_datetime) as encounter_datetime
				from 	encounter e 
						inner join patient p on p.patient_id=e.patient_id 		
				where 	e.voided=0 and p.voided=0 and e.encounter_type in (9,6) 
				group by p.patient_id
			) ultimavisita
			inner join encounter e on e.patient_id=ultimavisita.patient_id
			inner join obs o on o.encounter_id=e.encounter_id			
			where o.concept_id=23758 and o.voided=0 and e.voided=0 and e.encounter_datetime=ultimavisita.encounter_datetime and 
			e.encounter_type in (9,6) and e.location_id=:location 
            ) sintomas_tb on sintomas_tb.patient_id = inicio_real.patient_id
			
 --  Observacao de TB 
left join (
	Select ultimavisita.patient_id,ultimavisita.encounter_datetime as data_ult_consulta,
    case o.value_coded
		when 1760  then   'TOSSE POR MAIS DE 3 SEMANAS'
		when 1762  then   'SUORES Á NOITE POR MAIS DE 3 SEMANAS'
		when 1763  then   'FEBRE POR MAIS DE 3 SEMANA' 
		when 1764  then   'PERDEU PESO - MAIS DE 3 KG.NO ULTIMO MÊS'
        when 1765  then   'ALGUEM EM CASA ESTA TRATANDO A TB'
        when 23760 then 'ASTENIA'
       end as sintomas_observacao
		from

			(	select 	p.patient_id,max(encounter_datetime) as encounter_datetime
				from 	encounter e 
						inner join patient p on p.patient_id=e.patient_id 		
				where 	e.voided=0 and p.voided=0 and e.encounter_type in (9,6) 
				group by p.patient_id
			) ultimavisita
			inner join encounter e on e.patient_id=ultimavisita.patient_id
			inner join obs o on o.encounter_id=e.encounter_id			
			where o.concept_id=1766 and o.voided=0 and e.voided=0 and e.encounter_datetime=ultimavisita.encounter_datetime and 
			e.encounter_type in (9,6) and e.location_id=:location 
            ) observacao_tb on observacao_tb.patient_id = inicio_real.patient_id
	/**  ******************************************  ultima visita  **** ************************************ **/  
           left join (
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
			where o.concept_id=1410 and o.voided=0 and e.voided=0 and e.encounter_datetime=ultimavisita.encounter_datetime and 
			e.encounter_type in (9,6) and e.location_id=:location 
            ) ult_seguimento on ult_seguimento.patient_id = inicio_real.patient_id
     /** ******************************** ultima carga viral *********** **************************** **/
      /*  LEFT JOIN(  
         SELECT ult_cv.patient_id, e.encounter_datetime , o.value_numeric as carga_viral , e.encounter_type
			FROM	
				(  SELECT   patient_id , max(data_ult_carga)  data_ult_carga , valor_cv
					FROM
                    (  
						   SELECT 	e.patient_id,
									o.value_numeric valor_cv,
									max(e.encounter_datetime)  data_ult_carga
							FROM 	encounter e
									inner join obs o on e.encounter_id=o.encounter_id
							where 	e.encounter_type in (13,6,9) and e.voided=0 and o.voided=0 and o.concept_id=856  
							group by e.patient_id 
                    
				    UNION ALL
                
							SELECT 	e.patient_id,
									o.value_numeric valor_cv,
									max(o.obs_datetime)  data_ult_carga
							FROM 	encounter e
									inner join obs o on e.encounter_id=o.encounter_id
							where 	e.encounter_type = 53 and e.voided=0 and o.voided=0 and o.concept_id=856 
							group by e.patient_id ) all_cv group by patient_id 
						
						) ult_cv
                inner join encounter e on e.patient_id=ult_cv.patient_id
				inner join obs o on o.encounter_id=e.encounter_id 
                where o.obs_datetime=ult_cv.data_ult_carga
			     AND o.concept_id=856 and o.voided=0 AND e.voided=0
			group by patient_id
		
		) cv ON cv.patient_id =  inicio_real.patient_id

-- ultimo regime

        left join ( select e.patient_id,  e.encounter_datetime as data_regime , case o.value_coded
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
						else 'OUTRO' end as regime
                        from 
                   encounter e 
                   inner join (
                   select patient_id, max(ult_reg.data_inicio_reg)  as data_inicio_reg
                   from 
								( select patient_id, min(e.encounter_datetime) as data_inicio_reg 
								from   encounter e     
                                inner join obs o on o.encounter_id =e.encounter_id
								where e.encounter_type=18 and  o.concept_id=1088  AND e.voided=0 and  o.voided=0 and 
                                 e.location_id=:location
                                group by patient_id , o.value_coded ) ult_reg
                                group by patient_id
                     
                   ) ultimo_reg on ultimo_reg.patient_id=e.patient_id
                    inner join obs o  ON o.encounter_id=e.encounter_id
				  WHERE	 e.encounter_datetime =ultimo_reg.data_inicio_reg and  e.encounter_type =18  and   o.concept_id=1088  AND e.voided=0 
                  and e.location_id=:location
                  group by patient_id order by patient_id
	) ultimo_regime on  ultimo_regime.patient_id = inicio_real.patient_id */
-- Proveniencia
  			left join 
			(
				select 	pgg.patient_id,max(pgg.date_enrolled) as date_enrolled
				from 	patient pt inner join patient_program pgg on pt.patient_id=pgg.patient_id
				where 	pgg.voided=0 and pt.voided=0 and pgg.program_id in (3,4,8) and pgg.date_completed is null 
                and pgg.date_enrolled  between date_sub(:endDate, interval 9 MONTH) and :endDate and pgg.location_id=:location
				group by pgg.patient_id
			) inscrito_smi on inscrito_smi.patient_id=inicio_real.patient_id

			left join 
			(
				select 	pgg.patient_id,max(pgg.date_enrolled) as date_enrolled
				from 	patient pt inner join patient_program pgg on pt.patient_id=pgg.patient_id
				where 	pgg.voided=0 and pt.voided=0 and pgg.program_id=6 and pgg.date_completed is null 
                and pgg.date_enrolled  between date_sub(:endDate, interval 18 MONTH) and :endDate and pgg.location_id=:location
				group by pgg.patient_id
			) inscrito_ccr on inscrito_ccr.patient_id=inicio_real.patient_id
	/** ***************************** Telefone *************************** **/
	LEFT JOIN (
		SELECT  p.person_id, p.value  
		FROM person_attribute p
        WHERE  p.person_attribute_type_id=9 
           AND p.value IS NOT NULL AND p.value<>'' AND p.voided=0 
	        ) telef  ON telef.person_id = inicio_real.patient_id	
where 
  ROUND(DATEDIFF(:endDate,p.birthdate)/365) > 1 
and 
          -- 3.Nao ter antecedente de TB Resistente
              data_inicio_tb is null  and 
          -- 4.Ter rastreio negativo para TB na ultima consulta
              sintomas_observacao is null    and
            sintomas_tb.sintomas <> 'Sim'
   and   (
               -- 1. Ter data de início e fim de TPI (de mais de 180 dias)
              ( datediff(data_fim_tpi,data_inicio_tpi ) < 180 ) 
               or
               (data_fim_tpi is null and data_inicio_tpi is null)
               or
                (data_inicio_tpi is not null and data_fim_tpi is  null)

              )

) elegiveis_tpi group by patient_id  order by curso_normal_tpi_fim desc