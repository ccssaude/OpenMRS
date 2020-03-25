/*
SQLyog Ultimate v10.00 Beta1
MySQL - 5.6.16-1~exp1 : Database - openmrs_reports
*********************************************************************
*/

/*!40101 SET NAMES utf8 */;

/*!40101 SET SQL_MODE=''*/;

/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
/*Table structure for table `db_inhambane` */

DROP TABLE IF EXISTS `db_inhambane`;

CREATE TABLE `db_inhambane` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `dbname` varchar(60) DEFAULT NULL,
  `provincia` varchar(60) DEFAULT NULL,
  `distrito` varchar(60) DEFAULT NULL,
  `us` varchar(75) DEFAULT NULL,
  `us_id` varchar(45) DEFAULT NULL,
  `location_id` int(11) DEFAULT NULL,
  `tipous` varchar(10) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=134 DEFAULT CHARSET=utf8;

/*Data for the table `db_inhambane` */

insert  into `db_inhambane`(`id`,`dbname`,`provincia`,`distrito`,`us`,`us_id`,`location_id`,`tipous`) values (98,'openmrs_inh_urbano','Inhambane','Inhambane','Hospital de dia do C. de Saude Urbano Inhambane','1',212,'CS'),(99,'openmrs_inh_quissico','Inhambane','Zavala','HD Quissico','2',424,'CS'),(100,'openmrs_inh_maxixe','Inhambane','Maxixe','CS Maxixe','3',418,'CS'),(101,'openmrs_inh_vilanculos','Inhambane','Vilanculos','HR vilanculos','4',212,'HR'),(102,'openmrs_inh_massinga','Inhambane','Massinga','Centro de Saude da Massinga','5',212,'CS'),(103,'openmrs_inh_chicuque','Inhambane','Maxixe','Hospital de Dia de Chicuque','6',402,'CS'),(104,'openmrs_inh_homoine','Inhambane','Homoine','Centro de Saude de Homoine','7',212,'CS'),(105,'openmrs_inh_inharrime','Inhambane','Inharrime','Centro de Saude de Inharrime','8',411,'CS'),(106,'openmrs_inh_morrumbene','Inhambane','Morrumbene','Centro de Saude de Morrumbene','9',212,'CS'),(107,'openmrs_inh_agostinho_neto','Inhambane','Maxixe','CS Agostinho Neto','10',212,'CS'),(108,'openmrs_inh_chibuene','Inhambane','Vilanculos','CS Chibuene','11',208,'CS'),(109,'openmrs_inh_chongola','Inhambane','Inharrime','CS Chongola','12',211,'CS'),(110,'openmrs_inh_cumbana','Inhambane','Jangamo','CS Cumbana','13',404,'CS'),(111,'openmrs_inh_doane','Inhambane','Govuro','CS Doane','14',212,'CS'),(112,'openmrs_inh_funhalouro','Inhambane','Funhalouro','CS Funhalouro','15',410,'CS'),(114,'openmrs_inh_inhassoro','Inhambane','Inhassoro','CS Inhassoro','17',212,'CS'),(115,'openmrs_inh_jangamo','Inhambane','Jangamo','CS Jangamo','18',413,'CS'),(116,'openmrs_inh_mabil','Inhambane','Maxixe','CS Mabil','19',212,'CS'),(117,'openmrs_inh_mabote','Inhambane','Mabote','CS Mabote','20',212,'CS'),(118,'openmrs_inh_mangungumete','Inhambane','Inhassoro','CS Mangungumete','21',212,'CS'),(119,'openmrs_inh_mapinhane','Inhambane','Vilankulos','CS Mapinhane','22',212,'CS'),(120,'openmrs_inh_muele','Inhambane','Inhambane','CS Muele','23',212,'CS'),(121,'openmrs_inh_panda','Inhambane','Panda','CS Panda','24',420,'CS'),(123,'openmrs_inh_maundene','Inhambane','Zavala','Centro de Saude de Maundene','26',426,'CS'),(124,'openmrs_inh_mapinhane','Inhambane','Vilanculos','Centro de Saúde de Mapinhane','27',212,'CS'),(125,'openmrs_inh_manhala','Inhambane','Maxixe','CS Manhala','28',212,'CS'),(128,'openmrs_inh_pambara','Inhambane','Vilanculos','CS Pambara','29',212,'CS'),(129,'openmrs_inh_hpi','Inhambane','Inhambane','HPI','30',408,'CS'),(130,'openmrs_inh_bembe','Inhambane','Maxixe','CS Bembe','31',208,'CS'),(133,'openmrs_inh_salela','Inhambane','Inhambane','CS Salela','32',212,'CS');

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
