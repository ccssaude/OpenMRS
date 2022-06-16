use jmcs;
SELECT cn.name , c.uuid ,c.concept_id from concept c inner join concept_name cn
on c.concept_id =cn.concept_id where c.uuid ='e1db0bf6-1d5f-11e0-b929-000c29ad1d07' ;


/* 
"e1da2812-1d5f-11e0-b929-000c29ad1d07, 1306  Nivel baixo de detencao
cc8ef88c-6ab6-4404-a036-d415bc42cc1c,  23814  Indectetavel
78a76661-50c0-41cf-b566-de275f17b648,  23905 Menor que 10 copias/ml
ae6c048f-8b04-46cb-903e-51d5670db525,  23906 Menor que 20 copias/ml
 1321eeac-5832-4076-88e9-b1f2cd351ada, 23907  Menor que 40 copias/ml
 d6eb4797-2c01-4b6e-b43f-be15cd2fdcc2, 23908 Menor que 400 copias/ml
 7c8e0a9b-3606-4a72-b8cc-89566521fac2, 23904 Menor que 839 copias/ml


*/

/*  NIVEL DE ESCOLARIDADE  1443 , 
"e1db08fe-1d5f-11e0-b929-000c29ad1d07, NENHUMA EDUCAÇÃO FORMAL 1445
, e1db09f8-1d5f-11e0-b929-000c29ad1d07,   PRIMARIO 1446,
e1db0af2-1d5f-11e0-b929-000c29ad1d07,     SECONDÁRIO, NIVEL BASICO 1447 
 e1db0bf6-1d5f-11e0-b929-000c29ad1d07,    UNIVERSITARIO 1448  , />  */