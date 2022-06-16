use xipamanine;
SET @startDate:='2020-03-21';
SET @endDate:='2020-04-20';
SET @location:=208;
SELECT * 
FROM 
(SELECT 	
            inicio_real.patient_id,
			CONCAT(pid.identifier,' ') AS NID,
            CONCAT(IFNULL(pn.given_name,''),' ',IFNULL(pn.middle_name,''),' ',IFNULL(pn.family_name,'')) AS 'NomeCompleto',
			p.gender,
            ROUND(DATEDIFF(@endDate,p.birthdate)/365) idade_actual,
            DATE_FORMAT(inicio_real.data_inicio,'%d/%m/%Y') as data_inicio,
            weight.peso AS peso,
            height.altura ,
            hemog.hemoglobina,
            cd4.value_numeric as cd4,
            cv.carga_viral,
            case cv.encounter_type
            when 6 then 'Ficha Clinica'
            when 9 then 'Ficha Clinica'
            when 13 then 'Ficha de Lab'
            when 53 then 'Ficha Resumo'
            end as origem_cv,
            DATE_FORMAT(cv.data_ult_carga,'%d/%m/%Y') as data_ult_carga_v ,
            keypop.populacaochave,
            linha_terapeutica.linhat as linhaterapeutica,
            tipo_dispensa.tipodispensa,
             DATE_FORMAT(ccu_rastreio.dataRegisto,'%d/%m/%Y') as rastreio_ccu ,
			cv_qualitativa.carga_viral_qualitativa,
            DATE_FORMAT(ult_mestr.value_datetime,'%d/%m/%Y')   data_ult_mestruacao,
			if( ptv.date_enrolled is null, 'Nao', 	DATE_FORMAT(ptv.date_enrolled,'%d/%m/%Y') ) as inscrito_ptv_etv,
			escola.nivel_escolaridade,
			telef.value AS telefone,
            regime.ultimo_regime,
            DATE_FORMAT(regime.data_regime,'%d/%m/%Y') as data_regime,
            -- DATE_FORMAT(3_ult_fila.encounter_datetime,'%d/%m/%Y') as data_lev_3,
            -- DATE_FORMAT(2_ult_fila.encounter_datetime,'%d/%m/%Y') as data_lev_2,
            DATE_FORMAT(ult_fila.encounter_datetime,'%d/%m/%Y') as data_ult_levantamento,
			DATE_FORMAT(ultimoFila.value_datetime,'%d/%m/%Y')   as proximo_marcado,
            -- DATE_FORMAT(3_ult_vis.encounter_datetime,'%d/%m/%Y') as data_visita_3,
            -- DATE_FORMAT(2_ult_vis.encounter_datetime,'%d/%m/%Y') as data_visita_2,
            DATE_FORMAT(ult_vis.encounter_datetime,'%d/%m/%Y') as data_ult_visita,
            DATE_FORMAT(ult_seguimento.value_datetime,'%d/%m/%Y') as data_proxima_visita,
            risco_adesao.factor_risco as factor_risco_adesao,
			IF(programa.patient_id IS NULL,'NAO','SIM') inscrito_programa,
			IF(mastercard.patient_id IS NULL,'NAO','SIM') temmastercard,
			IF(mastercardFResumo.patient_id IS NULL,'NAO','SIM') temmastercardFR,
			IF(mastercardFClinica.patient_id IS NULL,'NAO','SIM') temmastercardFC,
			IF(mastercardFAPSS.patient_id IS NULL,'NAO','SIM') temmastercardFA,
            DATE_FORMAT(mastercardFAPSS.dataRegisto,'%d/%m/%Y') as  data_ult_vis_apss,
            DATE_FORMAT(mastercardFAPSS.value_datetime,'%d/%m/%Y')  as  data_prox_apss,
			IF(DATEDIFF( @endDate,visita.value_datetime)<=28,'ACTIVO EM TARV','ABANDONO NAO NOTIFICADO') estado,
			IF(DATEDIFF( @endDate,visita.value_datetime)>28,DATE_FORMAT(DATE_ADD(visita.value_datetime, INTERVAL 28 DAY),'%d/%m/%Y'),'') dataAbandono,
			DATE_FORMAT( ult_levant_master_card.data_ult_lev_master_card,'%d/%m/%Y')  as data_ult_lev_master_card ,
            conset.consentimento,
			IF(gaaac.member_id IS NULL,'NÃO','SIM') emgaac,
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
								e.encounter_datetime<= @endDate AND e.location_id= @location
						GROUP BY p.patient_id
				
						UNION
				
						/*Patients on ART who have art start date: ART Start date*/
						SELECT 	p.patient_id,MIN(value_datetime) data_inicio
						FROM 	patient p
								INNER JOIN encounter e ON p.patient_id=e.patient_id
								INNER JOIN obs o ON e.encounter_id=o.encounter_id
						WHERE 	p.voided=0 AND e.voided=0 AND o.voided=0 AND e.encounter_type IN (18,6,9,53) AND 
								o.concept_id=1190 AND o.value_datetime IS NOT NULL AND 
								o.value_datetime<= @endDate AND e.location_id= @location
						GROUP BY p.patient_id

						UNION

						/*Patients enrolled in ART Program: OpenMRS Program*/
						SELECT 	pg.patient_id,MIN(date_enrolled) data_inicio
						FROM 	patient p INNER JOIN patient_program pg ON p.patient_id=pg.patient_id
						WHERE 	pg.voided=0 AND p.voided=0 AND program_id=2 AND date_enrolled<= @endDate AND location_id= @location
						GROUP BY pg.patient_id
						
						UNION
						
						
						/*Patients with first drugs pick up date set in Pharmacy: First ART Start Date*/
						  SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data_inicio 
						  FROM 		patient p
									INNER JOIN encounter e ON p.patient_id=e.patient_id
						  WHERE		p.voided=0 AND e.encounter_type=18 AND e.voided=0 AND e.encounter_datetime<= @endDate AND e.location_id= @location
						  GROUP BY 	p.patient_id
					  

				
				
			) inicio
		GROUP BY patient_id	
	)inicio_real
		INNER JOIN person p ON p.person_id=inicio_real.patient_id
		
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
		
		INNER JOIN		
		(	SELECT ultimavisita.patient_id,ultimavisita.encounter_datetime,o.value_datetime,e.location_id
			FROM
				(	SELECT 	p.patient_id,MAX(encounter_datetime) AS encounter_datetime
					FROM 	encounter e 
							INNER JOIN patient p ON p.patient_id=e.patient_id 		
					WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type IN (6,35,9,18,53) AND 
							e.location_id= @location AND e.encounter_datetime<= @endDate
					GROUP BY p.patient_id
				) ultimavisita
				INNER JOIN encounter e ON e.patient_id=ultimavisita.patient_id
				LEFT JOIN obs o ON o.encounter_id=e.encounter_id AND (o.concept_id=5096 OR o.concept_id=1410) AND e.encounter_datetime=ultimavisita.encounter_datetime			
			WHERE  o.voided=0  AND e.voided =0 AND e.encounter_type IN (6,35,9,18,53) AND e.location_id= @location
		) visita ON visita.patient_id=inicio_real.patient_id
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
						o.concept_id=1088 and e.location_id=@location
              
			) regime on regime.patient_id=inicio_real.patient_id
            
            
		left join 
		(Select ultimavisita.patient_id,ultimavisita.encounter_datetime,o.value_datetime,e.location_id
			from

			(	select 	p.patient_id,max(encounter_datetime) as encounter_datetime
				from 	encounter e 
						inner join patient p on p.patient_id=e.patient_id 		
				where 	e.voided=0 and p.voided=0 and e.encounter_type=18 and e.location_id=@location 
				group by p.patient_id
			) ultimavisita
			inner join encounter e on e.patient_id=ultimavisita.patient_id
			inner join obs o on o.encounter_id=e.encounter_id			
			where o.concept_id=5096 and o.voided=0 and e.encounter_datetime=ultimavisita.encounter_datetime and 
			e.encounter_type=18 and e.location_id=@location 
		) ultimoFila on ultimoFila.patient_id=inicio_real.patient_id
        
		LEFT JOIN
		(
			SELECT 	pg.patient_id
			FROM 	patient p INNER JOIN patient_program pg ON p.patient_id=pg.patient_id
			WHERE 	pg.voided=0 AND p.voided=0 AND program_id=2 AND date_enrolled<= @endDate AND location_id= @location
		) programa ON programa.patient_id=inicio_real.patient_id
		LEFT JOIN 
		(
			SELECT 	patient_id, MAX(encounter_datetime) dataRegisto
			FROM 	encounter 
			WHERE 	encounter_type = 52 AND voided=0
			GROUP BY patient_id
		) mastercard ON mastercard.patient_id = inicio_real.patient_id
        /** **********************   CCU Rastreio  ********************************** **/
	     LEFT JOIN 
		(
			SELECT 	patient_id, MAX(encounter_datetime) dataRegisto
			FROM 	encounter 
			WHERE 	encounter_type = 28 AND form_id = 122 AND voided = 0
			GROUP BY patient_id
		) ccu_rastreio ON ccu_rastreio.patient_id = inicio_real.patient_id
		
		LEFT JOIN 
		(
			SELECT 	patient_id, MAX(encounter_datetime) dataRegisto
			FROM 	encounter 
			WHERE 	encounter_type = 53 AND form_id = 165 AND voided=0
			GROUP BY patient_id
		) mastercardFResumo ON mastercardFResumo.patient_id = inicio_real.patient_id
		
		LEFT JOIN 
		(
			SELECT 	patient_id, MAX(encounter_datetime) dataRegisto
			FROM 	encounter 
			WHERE 	encounter_type IN (6,9) AND form_id = 163 AND voided=0
			GROUP BY patient_id
		) mastercardFClinica ON mastercardFClinica.patient_id = inicio_real.patient_id
	
		LEFT JOIN 
		(  
             select e.patient_id, ult_apss.dataRegisto,o.value_datetime
			  FROM    encounter e  INNER JOIN 
              (
				SELECT 	patient_id, MAX(encounter_datetime) dataRegisto
						FROM 	encounter 
						WHERE 	encounter_type IN (34,35) AND form_id = 164 AND voided=0
						GROUP BY patient_id 
               ) ult_apss
			ON e.patient_id = ult_apss.patient_id
            inner join obs o on o.encounter_id =e.encounter_id
            where e.encounter_type IN (34,35)
             and ult_apss.dataRegisto = e.encounter_datetime 
             AND o.voided=0 AND o.concept_id = 6310
             group by patient_id
		) mastercardFAPSS ON mastercardFAPSS.patient_id = inicio_real.patient_id
       /************************** keypop concept_id = 23703 ****************************/
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
			WHERE 	e.encounter_type IN (6,9,34,35) AND e.voided=0 AND o.voided=0 AND o.concept_id = 23703 AND o.location_id= @location
            group by patient_id
		) keypop ON keypop.patient_id=inicio_real.patient_id

		LEFT JOIN
		(
			SELECT DISTINCT member_id FROM gaac_member WHERE voided=0
		) gaaac ON gaaac.member_id=inicio_real.patient_id
        
        /************  Peso  *********************/
        LEFT JOIN(  
        	SELECT 	e.patient_id,o.value_numeric peso,  MAX(encounter_datetime)
			FROM	 encounter e 
					INNER JOIN obs o ON o.encounter_id=e.encounter_id
			WHERE 	e.voided=0 AND o.voided=0 AND o.concept_id=5089 AND e.encounter_type IN (6,9,53)  
			GROUP BY e.patient_id
		) weight ON weight.patient_id =  inicio_real.patient_id
        
               /************  Altura  *********************/
        LEFT JOIN(  
        	SELECT 	e.patient_id,o.value_numeric altura,  MAX(encounter_datetime)
			FROM	 encounter e
					INNER JOIN obs o ON o.encounter_id=e.encounter_id
			WHERE 	e.voided=0   AND 
					o.voided=0 AND o.concept_id=5090 AND e.encounter_type IN (6,9,53)  
                    AND e.form_id = 163 
			GROUP BY e.patient_id
		) height ON height.patient_id =  inicio_real.patient_id
        
                       /************  Hemoglobina  *********************/
        LEFT JOIN(  
        	SELECT 	e.patient_id,o.value_numeric hemoglobina,  MAX(encounter_datetime)
			FROM	 encounter e 
					INNER JOIN obs o ON o.encounter_id=e.encounter_id
			WHERE 	e.voided=0  AND 
					o.voided=0 AND o.concept_id=1692 AND e.encounter_type IN (6,9,53)  
                    AND e.form_id = 163 
			GROUP BY e.patient_id
		) hemog ON hemog.patient_id =  inicio_real.patient_id
               
			/** **************************************** Tipo dispensa  concept_id = 23739 **************************************** **/
    LEFT JOIN 
		( SELECT 	e.patient_id,
				CASE o.value_coded
					WHEN 23888  THEN 'DISPENSA SEMESTRAL'
					WHEN 1098 THEN 'DISPENSA MENSAL'
					WHEN 23720 THEN 'DISPENSA TRIMESTRAL'
				ELSE '' END AS tipodispensa,
                e.encounter_datetime
                from encounter e inner join
                ( select e.patient_id, max(encounter_datetime) as data_ult_tipo_dis
					FROM 	obs o
					INNER JOIN encounter e ON o.encounter_id=e.encounter_id
					WHERE 	e.encounter_type IN (6,9,53) AND e.voided=0 AND o.voided=0 AND o.concept_id = 23739 AND o.location_id= @location
					group by patient_id ) ult_dispensa
					on e.patient_id =ult_dispensa.patient_id
            INNER JOIN obs o ON o.encounter_id=e.encounter_id
			WHERE 	e.encounter_type IN (6,9,53)
             and ult_dispensa.data_ult_tipo_dis = e.encounter_datetime 
             AND o.voided=0 AND o.concept_id = 23739
             group by patient_id
		) tipo_dispensa ON tipo_dispensa.patient_id=inicio_real.patient_id
        
        /** ************************** LinhaTerapeutica concept_id = 21151  * ********************************************** **/
        LEFT JOIN 
		(
SELECT 	e.patient_id,
				CASE o.value_coded
					WHEN 21148  THEN 'SEGUNDA LINHA'
					WHEN 21149  THEN 'TERCEIRA LINHA'
					WHEN 21150  THEN 'PRIMEIRA LINHA'
				ELSE '' END AS linhat,
                encounter_datetime as data_ult_linha
				FROM 	(
							SELECT 	e.patient_id,max(encounter_datetime) as data_ult_linhat
							from encounter e inner join obs o on e.encounter_id=o.encounter_id
							where e.encounter_type IN (6,9,53) AND e.voided=0 AND o.voided=0 AND o.concept_id = 21151 
							group by patient_id
				) ult_linhat
			INNER JOIN encounter e on e.patient_id=ult_linhat.patient_id
            INNER JOIN obs o ON o.encounter_id=e.encounter_id
			WHERE 	e.encounter_type IN (6,9,53) AND ult_linhat.data_ult_linhat =e.encounter_datetime and e.voided=0 AND o.voided=0 AND o.concept_id = 21151 
            group by patient_id
		) linha_terapeutica ON linha_terapeutica.patient_id=inicio_real.patient_id
        
        /****************** ****************************  CD4   ********* *****************************************************/
        LEFT JOIN(  
            select e.patient_id, o.value_numeric,e.encounter_datetime
            from encounter e inner join 
		    (            
            SELECT 	cd4_max.patient_id, MAX(cd4_max.encounter_datetime) as encounter_datetime
            FROM ( select e.patient_id, o.value_numeric , encounter_datetime
					FROM encounter e 
							INNER JOIN obs o ON o.encounter_id=e.encounter_id
					WHERE 	e.voided=0  AND e.location_id=@location  and
							o.voided=0 AND o.concept_id=1695 AND e.encounter_type IN (6,9,53)  
			
					UNION ALL
					SELECT 	 e.patient_id, o.value_numeric , encounter_datetime
					FROM encounter e 
							INNER JOIN obs o ON o.encounter_id=e.encounter_id
					WHERE 	e.voided=0  AND  e.location_id=@location  and
							o.voided=0 AND o.concept_id=5497 AND e.encounter_type =13 ) cd4_max
			GROUP BY patient_id ) cd4_temp 
            ON e.patient_id = cd4_temp.patient_id
            inner join obs o on o.encounter_id=e.encounter_id 
            where e.encounter_datetime=cd4_temp.encounter_datetime and
			e.voided=0  AND  e.location_id=@location  and
            o.voided=0 AND o.concept_id in (1695,5497) AND e.encounter_type in (6,9,13,53)   
			GROUP BY patient_id   
            
		) cd4 ON cd4.patient_id =  inicio_real.patient_id
       	/**  ******************************************  Levantamento de ARV Master Card  **** ************************************ **/  
            left join (
	Select ult_lev_master_card.patient_id,o.value_datetime as data_ult_lev_master_card
		from

			(	select 	e.patient_id,max(o.value_datetime) as value_datetime
				from 	encounter e inner join obs o on e.encounter_id=o.encounter_id
				where 	e.voided=0 and o.voided=0 and e.encounter_type =52 and o.concept_id=23866 
				group by patient_id
			) ult_lev_master_card
			inner join encounter e on e.patient_id=ult_lev_master_card.patient_id
			inner join obs o on o.encounter_id=e.encounter_id			
			where o.concept_id=23866 and o.voided=0 and e.voided=0 and o.value_datetime=ult_lev_master_card.value_datetime and 
			e.encounter_type =52  
           group by patient_id
            ) ult_levant_master_card on ult_levant_master_card.patient_id = inicio_real.patient_id
	    /* ************ ******************************  Ultima mestruacao    ******************** ******************************/
        LEFT JOIN(  
        	SELECT 	e.patient_id,o.value_datetime ,  MAX(encounter_datetime)
			FROM	encounter e 
					INNER JOIN obs o ON o.encounter_id=e.encounter_id
			WHERE 	e.voided=0 AND 
					o.voided=0 AND o.concept_id=1465 AND e.encounter_type IN (6,9,53) 
                    AND e.form_id = 163 
			GROUP BY e.patient_id
		) ult_mestr ON ult_mestr.patient_id =  inicio_real.patient_id
          /***********************   Factores de risco de adesao *****************************************************/
          left join (select 
						e.patient_id, 
						o.value_coded,
						case  o.value_coded
						when 6436  then   'Estigma/Preocupado com a privacidade'
						when 23769 then  'ASPECTOS CULTURAIS OU TRADICIONAIS (P)'
						when 23768 then  'PERDEU / ESQUECEU / PARTILHOU COMPRIMIDOS (L)'
						when 6303  then   'VIOLENCIA BASEADA NO GENERO'
						when 23767 then 'SENTE-SE MELHOR (E)'
						when 18698 then  'FALTA DE ALIMENTO'
						when 207   then 'DEPRESSÃO'
						when 820   then 'PROBLEMAS DE TRANSPORTE'
						when 1936  then 'UTENTE SETENTE-SE DOENTE'
						when 1956  then 'NÃO ACREDITO NO REULTADO'
						when 2015  then 'EFEITOS SECUNDARIOS ARV'
						when 2153  then  'FALTA DE APOIO'
						when 2155  then 'NÃO REVELOU SEU DIAGNOSTICO'
						when 6186  then 'NAO ACREDITA NO TRATAMENTO'
						when 23766 then 'SÃO MUITOS COMPRIMIDOS (D)'
						when 2017  then 'OUTRO MOTIVO DE FALTA'
						when 1603  then  'ABUSO DE ALCOOL'
						end as factor_risco,
                        ult_risco_adesao.data_ult_risco_adesao 
						from encounter e inner join
										(   select e.patient_id, max(encounter_datetime) as data_ult_risco_adesao
											FROM 	obs o
											INNER JOIN encounter e ON o.encounter_id=e.encounter_id
											WHERE 	e.encounter_type IN (6,9,18,35) AND e.voided=0 AND o.voided=0 AND o.concept_id = 6193 AND o.location_id= @location
											group by patient_id ) ult_risco_adesao
						on ult_risco_adesao.patient_id=e.patient_id
						inner join obs o on o.encounter_id=e.encounter_id
						where e.encounter_datetime = ult_risco_adesao.data_ult_risco_adesao and 
						e.voided=0 AND o.voided=0 AND o.concept_id = 6193 AND o.location_id= @location
						and e.encounter_type IN (6,9,18,35)
						group by patient_id ) risco_adesao on risco_adesao.patient_id =  inicio_real.patient_id and DATEDIFF( @endDate,risco_adesao.data_ult_risco_adesao)/30 <= 3 

		 /***************** Patients enrolled in PTV/ETV Program: OpenMRS Program ************************************/
        left join (

						/*Patients enrolled in PTV/ETV Program: OpenMRS Program*/
						select 	pg.patient_id,date_enrolled 
						from 	patient p inner join patient_program pg on p.patient_id=pg.patient_id
						where 	pg.voided=0 and p.voided=0 and program_id=8 and  date_enrolled  between DATE_SUB( @endDate , INTERVAL 9 MONTH ) and @endDate 
						group by pg.patient_id
        ) ptv on ptv.patient_id= inicio_real.patient_id

          /* ******************************** ultima carga viral *********** ******************************/
        LEFT JOIN(  
         SELECT ult_cv.patient_id, e.encounter_datetime , o.value_numeric as carga_viral , e.encounter_type, ult_cv.data_ult_carga
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
	
        /****** ***************************  viral load qualitativa  * *****************************************/
        LEFT JOIN(  
        	    SELECT 	e.patient_id,
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
				ult_cv.data_cv_qualitativa
                FROM  encounter e 
                inner join	(
							SELECT 	e.patient_id,max(encounter_datetime) as data_cv_qualitativa
							from encounter e inner join obs o on e.encounter_id=o.encounter_id
							where e.encounter_type IN (6,9) AND e.voided=0 AND o.voided=0 AND o.concept_id = 1305 
							group by patient_id
				) ult_cv 
                on e.patient_id=ult_cv.patient_id
				inner join obs o on o.encounter_id=e.encounter_id 
                 where e.encounter_datetime=ult_cv.data_cv_qualitativa	
				and	e.voided=0  AND e.location_id= @location  AND e.encounter_type in (6,9) and
				o.voided=0 AND 	o.concept_id=1305
                group by e.patient_id
		) cv_qualitativa ON cv_qualitativa.patient_id =  inicio_real.patient_id

       /*****************************   ultimo levantamento ************** **********************/
		LEFT JOIN
		(
	
	SELECT visita2.patient_id , 
(	SELECT	 visita.encounter_datetime
					FROM 
                    ( SELECT p.patient_id,  e.encounter_datetime FROM  encounter e 
							INNER JOIN patient p ON p.patient_id=e.patient_id 		
					WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type IN (18) AND e.form_id =130  
							AND e.encounter_datetime<= @endDate
						) visita
    WHERE visita.patient_id = visita2.patient_id
    ORDER BY encounter_datetime  DESC
    LIMIT 0,1
) AS encounter_datetime
FROM 	   ( SELECT p.patient_id, e.encounter_datetime FROM  encounter e 
							INNER JOIN patient p ON p.patient_id=e.patient_id 		
					WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type IN (18) AND e.form_id =130  
							AND e.encounter_datetime<= @endDate
				) visita2
GROUP BY visita2.patient_id  

		) ult_fila ON ult_fila.patient_id = inicio_real.patient_id

  /*  ************************************   penultimo  levantamento ***** *******************************    
		LEFT JOIN
		(
		
		SELECT visita2.patient_id , 
(	SELECT	 visita.encounter_datetime
					FROM 
                    ( SELECT p.patient_id,  e.encounter_datetime FROM  encounter e 
							INNER JOIN patient p ON p.patient_id=e.patient_id 		
					WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type IN (18) AND e.form_id =130  
							AND e.encounter_datetime<= @endDate
						) visita
    WHERE visita.patient_id = visita2.patient_id
    ORDER BY encounter_datetime  DESC
    LIMIT 1,1
) AS encounter_datetime
FROM 	   ( SELECT p.patient_id, e.encounter_datetime FROM  encounter e 
							INNER JOIN patient p ON p.patient_id=e.patient_id 		
					WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type IN (18) AND e.form_id =130  
							AND e.encounter_datetime<= @endDate
				) visita2
GROUP BY visita2.patient_id  

		) 2_ult_fila ON 2_ult_fila.patient_id = inicio_real.patient_id

  /* ********* ********************************   3 ultimo  levantamento ******* *****************************   
		LEFT JOIN
		(
		SELECT visita2.patient_id , 
(	SELECT	 visita.encounter_datetime
					FROM 
                    ( SELECT p.patient_id,  e.encounter_datetime FROM  encounter e 
							INNER JOIN patient p ON p.patient_id=e.patient_id 		
					WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type IN (18) AND e.form_id =130  
							AND e.encounter_datetime<= @endDate
						) visita
    WHERE visita.patient_id = visita2.patient_id
    ORDER BY encounter_datetime  DESC
    LIMIT 2,1
) AS encounter_datetime
FROM 	   ( SELECT p.patient_id, e.encounter_datetime FROM  encounter e 
							INNER JOIN patient p ON p.patient_id=e.patient_id 		
					WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type IN (18) AND e.form_id =130  
							AND e.encounter_datetime<= @endDate
				) visita2
GROUP BY visita2.patient_id  

		) 3_ult_fila ON 3_ult_fila.patient_id = inicio_real.patient_id
****************************************************************************************************************** */ 
	/*  ** ******************************************  ultima visita  **** ************************************* */ 
		LEFT JOIN (


SELECT visita2.patient_id , 
(	SELECT	 visita.encounter_datetime
					FROM 
                    ( SELECT p.patient_id,  e.encounter_datetime FROM  encounter e 
							INNER JOIN patient p ON p.patient_id=e.patient_id 		
					WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type IN (6,9) 
							AND e.encounter_datetime<= @endDate
						) visita
    WHERE visita.patient_id = visita2.patient_id
    ORDER BY encounter_datetime  DESC
    LIMIT 0,1
) AS encounter_datetime
FROM 	   ( SELECT p.patient_id, e.encounter_datetime FROM  encounter e 
							INNER JOIN patient p ON p.patient_id=e.patient_id 		
					WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type IN (6,9) 
							AND e.encounter_datetime<= @endDate
				) visita2
GROUP BY visita2.patient_id  
		) ult_vis ON ult_vis.patient_id = inicio_real.patient_id

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
			e.encounter_type in (9,6) and e.location_id=@location 
            ) ult_seguimento on ult_seguimento.patient_id = inicio_real.patient_id
	/*  * *******************************************  penultima visita  *** ************************************** 
		LEFT JOIN (


SELECT visita2.patient_id , 
(	SELECT	 visita.encounter_datetime
					FROM 
                    ( SELECT p.patient_id,  e.encounter_datetime FROM  encounter e 
							INNER JOIN patient p ON p.patient_id=e.patient_id 		
					WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type IN (6,9) 
							AND e.encounter_datetime<= @endDate
						) visita
    WHERE visita.patient_id = visita2.patient_id
    ORDER BY encounter_datetime  DESC
    LIMIT 1,1
) AS encounter_datetime
FROM 	   ( SELECT p.patient_id, e.encounter_datetime FROM  encounter e 
							INNER JOIN patient p ON p.patient_id=e.patient_id 		
					WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type IN (6,9) 
							AND e.encounter_datetime<= @endDate
				) visita2
GROUP BY visita2.patient_id  
		) 2_ult_vis ON 2_ult_vis.patient_id = inicio_real.patient_id

	/*   ********************************************  3 ultima  visita  *** ***************************************
		LEFT JOIN (


SELECT visita2.patient_id , 
(	SELECT	 visita.encounter_datetime
					FROM 
                    ( SELECT p.patient_id,  e.encounter_datetime FROM  encounter e 
							INNER JOIN patient p ON p.patient_id=e.patient_id 		
					WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type IN (6,9) 
							AND e.encounter_datetime<= @endDate
						) visita
    WHERE visita.patient_id = visita2.patient_id
    ORDER BY encounter_datetime  DESC
    LIMIT 2,1
) AS encounter_datetime
FROM 	   ( SELECT p.patient_id, e.encounter_datetime FROM  encounter e 
							INNER JOIN patient p ON p.patient_id=e.patient_id 		
					WHERE 	e.voided=0 AND p.voided=0 AND e.encounter_type IN (6,9) 
							AND e.encounter_datetime<= @endDate
				) visita2
GROUP BY visita2.patient_id  
		) 3_ult_vis ON 3_ult_vis.patient_id = inicio_real.patient_id
       */     
	/* * **************************** Escolaridade **** ********************************************** */ 

	LEFT JOIN (
	
        	SELECT 	e.patient_id,
	     CASE o.value_coded
                WHEN 1445  THEN  'NENHUMA EDUCAÇÃO FORMAL'
                WHEN 1446 THEN  'PRIMARIO'
               WHEN 1447 THEN  'SECONDÁRIO, NIVEL BASICO'
              WHEN 1448 THEN  ' UNIVERSITARIO'
               WHEN 6124 THEN  'TÉCNICO BÁSICO'
                WHEN 1444 THEN  'TÉCNICO MÉDIO'
               ELSE 'OUTRO'
           END  AS nivel_escolaridade,
     max(encounter_datetime)  as data_ult_esc
		from  obs o 	inner join  encounter e 
			on o.encounter_id=e.encounter_id 
            where  o.voided=0 AND e.voided=0   
            AND  o.concept_id = 1443 
            AND  encounter_type=53
			group by e.patient_id
	) escola ON escola.patient_id = inicio_real.patient_id

/* ******************************* Telefone **************************** */
	LEFT JOIN (
		SELECT  p.person_id, p.value  
		FROM person_attribute p
     WHERE  p.person_attribute_type_id=9 
    AND p.value IS NOT NULL AND p.value<>'' AND p.voided=0 
	) telef  ON telef.person_id = inicio_real.patient_id

/* ********************************* Consentimento **********************************/

   left join (
		Select ultapss.patient_id,ultapss.encounter_datetime,case o.value_coded when 1065 then 'Sim' when 1066 then 'Nao' end as consentimento
					from

					(	select 	p.patient_id,max(encounter_datetime) as encounter_datetime
						from 	encounter e 
								inner join patient p on p.patient_id=e.patient_id 		
						where 	e.voided=0 and p.voided=0 and e.encounter_type=35 and e.location_id=@location 
                        and 	e.encounter_datetime<=@endDate
						group by p.patient_id ) ultapss
                      	INNER JOIN encounter e ON e.patient_id=ultapss.patient_id
					INNER JOIN obs o ON o.encounter_id=e.encounter_id			
					WHERE o.concept_id=6306 AND o.voided=0 AND e.encounter_datetime=ultapss.encounter_datetime AND 
					e.encounter_type =35 AND e.location_id=@location 
                    ) conset on conset.patient_id = inicio_real.patient_id
	WHERE inicio_real.patient_id NOT IN  -- Pacientes que sairam do programa TARV
		(		
			SELECT 	pg.patient_id					
			FROM 	patient p 
					INNER JOIN patient_program pg ON p.patient_id=pg.patient_id
					INNER JOIN patient_state ps ON pg.patient_program_id=ps.patient_program_id
			WHERE 	pg.voided=0 AND ps.voided=0 AND p.voided=0 AND 
					pg.program_id=2 AND ps.state IN (7,8,9,10) AND 
					ps.end_date IS NULL AND location_id= @location AND ps.start_date<= @endDate		
		) and DATEDIFF( @endDate,visita.value_datetime)<= 28 -- De 33 para 28 Solicitacao do Mauricio 27/07/2020
) activos
GROUP BY patient_id
   
 --   28 janeiro
   
 --   20 fevereiro
