use altomae;

select c.concept_id,cn.name, cn.locale, c.uuid from concept c
inner join concept_name cn on c.concept_id=cn.concept_id
where c.uuid in ('e1de6d1e-1d5f-11e0-b929-000c29ad1d07', 
'e1de6878-1d5f-11e0-b929-000c29ad1d07','e1de6a12-1d5f-11e0-b929-000c29ad1d07','e1de66e8-1d5f-11e0-b929-000c29ad1d07',
'e1de63d2-1d5f-11e0-b929-000c29ad1d07') and locale ='pt';


select c.concept_id,cn.name from concept c
inner join concept_name cn on c.concept_id=cn.concept_id
where c.uuid in ('000800004925194510180' )
 and locale ='pt';
 

select c.concept_id, cn.name, cn.locale, c.uuid from concept c
inner join concept_name cn on c.concept_id=cn.concept_id
where c.concept_id in(1603) and locale ='pt';



select  identifier from patient_identifier where identifier_type=15 ;