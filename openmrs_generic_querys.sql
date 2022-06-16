
SELECT  pid.identifier , pe.uuid, pn.given_name,pn.middle_name,pn.family_name
  FROM  patient pat INNER JOIN  openmrs.patient_identifier pid ON pat.patient_id =pid.patient_id
  INNER JOIN person pe ON pat.patient_id=pe.person_id
  INNER JOIN person_name pn ON pe.person_id=pn.person_id
WHERE pe.uuid='9486fb4b-2ced-4e9e-bf1b-9195b230a1b4'


SELECT ps.state,ps.start_date,ps.end_date, pg.patient_id,program_id,pg.date_enrolled FROM
 patient_program pg, patient_state ps
 where pg.patient_program_id=ps.patient_program_id and program_id=2
 order by patient_id;

select * from patient where patientid ='0108010601/2013/00167';
select * from patientidentifier where patient_id =807291;


select * from patientidentifier where value='08010601/14/158';
 where patient_id=900859;

update patientidentifier
set value ='00108010601/2018/00127'
where patient_id=642321; 


update patient 
set patientid ='2018/01278T' ,
uuidopenmrs = ''
where id =822529;


update patientidentifier
set value ='2018/01278T'
where patient_id=822529; 


SELECT  pid.identifier , pe.uuid, pn.given_name,pn.middle_name,pn.family_name, pat.voided
  FROM  patient pat INNER JOIN  openmrs.patient_identifier pid ON pat.patient_id =pid.patient_id
  INNER JOIN person pe ON pat.patient_id=pe.person_id
  INNER JOIN person_name pn ON pe.person_id=pn.person_id
  LEFT JOIN  nid_update_log	nul ON nul.`patient_id` =pat.`patient_id`
WHERE nul.`patient_id` IS NULL AND pat.voided = 




