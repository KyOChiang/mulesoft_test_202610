-- MySQL dump 10.13  Distrib 8.0.46, for Linux (x86_64)
--
-- Host: localhost    Database: mulesoft_training_dev
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Current Database: `mulesoft_training_dev`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `mulesoft_training_dev` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;

USE `mulesoft_training_dev`;

--
-- Table structure for table `customer_info`
--

DROP TABLE IF EXISTS `customer_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `customer_info` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `first_name` varchar(100) NOT NULL,
  `last_name` varchar(100) NOT NULL,
  `salary` decimal(12,2) NOT NULL,
  `full_name` varchar(200) DEFAULT NULL,
  `tier` varchar(50) DEFAULT NULL,
  `tax` decimal(5,4) DEFAULT NULL,
  `total_tax` decimal(12,4) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `customer_info`
--

LOCK TABLES `customer_info` WRITE;
/*!40000 ALTER TABLE `customer_info` DISABLE KEYS */;
INSERT INTO `customer_info` VALUES (1,1,'Will','Smith',2000.00,'WILL SILVER SMITH','SILVER',0.2000,4.0000,'2026-10-18 16:27:00','2026-10-18 17:21:02'),(2,4,'Mickey','Mouse',120000.00,'MICKEY PREMIUM MOUSE','PREMIUM',0.8000,960.0000,'2026-10-18 16:27:00','2026-10-18 17:21:02'),(3,6,'Jill','Snith',3500.00,'JILL BRONZE SNITH','BRONZE',0.4000,14.0000,'2026-10-18 16:27:00','2026-10-18 17:21:02'),(4,2,'Jane','Smith',12000.00,'JANE PREMIUM SMITH','PREMIUM',0.8000,96.0000,'2026-10-18 16:27:00','2026-10-18 17:21:02'),(5,7,'Sane','Snith',-12000.00,'SANE NONE SNITH','NONE',0.0000,0.0000,'2026-10-18 16:27:00','2026-10-18 17:21:04'),(6,9,'Lickey','Pouse',120344.00,'LICKEY PREMIUM POUSE','PREMIUM',0.8000,962.7520,'2026-10-18 16:27:00','2026-10-18 17:21:04');
/*!40000 ALTER TABLE `customer_info` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `customer_orders`
--

DROP TABLE IF EXISTS `customer_orders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `customer_orders` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` varchar(20) NOT NULL,
  `order_timestamp` datetime NOT NULL,
  `order_status` varchar(20) NOT NULL,
  `order_total` decimal(10,2) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3168 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `customer_orders`
--

LOCK TABLES `customer_orders` WRITE;
/*!40000 ALTER TABLE `customer_orders` DISABLE KEYS */;
INSERT INTO `customer_orders` VALUES (3138,'AES45678','2021-12-02 23:02:00','Confirmed',1200.00,'2026-10-19 07:38:02'),(3139,'AES4 5679','2021-12-02 09:11:00','Cancelled',2500.00,'2026-10-19 07:38:02'),(3140,'AES45680','2021-12-02 18:02:00','Confirmed',5100.00,'2026-10-19 07:38:02'),(3141,'BAT00001','2021-12-02 23:02:00','Confirmed',100.00,'2026-10-19 07:41:16'),(3142,'BAT00002','2021-12-02 23:02:00','Confirmed',200.00,'2026-10-19 07:41:16'),(3143,'BAT00003','2021-12-02 23:02:00','Confirmed',300.00,'2026-10-19 07:41:17'),(3144,'BAT00004','2021-12-02 23:02:00','Confirmed',400.00,'2026-10-19 07:41:17'),(3145,'BAT00005','2021-12-02 23:02:00','Confirmed',500.00,'2026-10-19 07:41:17'),(3146,'BAT00006','2021-12-02 23:02:00','Confirmed',600.00,'2026-10-19 07:41:17'),(3147,'BAT00007','2021-12-02 23:02:00','Confirmed',700.00,'2026-10-19 07:41:17'),(3148,'BAT00008','2021-12-02 23:02:00','Confirmed',800.00,'2026-10-19 07:41:17'),(3149,'BAT00009','2021-12-02 23:02:00','Confirmed',900.00,'2026-10-19 07:41:17'),(3150,'BAT00010','2021-12-02 23:02:00','Confirmed',1000.00,'2026-10-19 07:41:17'),(3151,'BAT00011','2021-12-02 23:02:00','Confirmed',1100.00,'2026-10-19 07:41:17'),(3152,'BAT00012','2021-12-02 23:02:00','Confirmed',1200.00,'2026-10-19 07:41:17'),(3153,'BAT00013','2021-12-02 23:02:00','Confirmed',1300.00,'2026-10-19 07:41:17'),(3154,'BAT00014','2021-12-02 23:02:00','Confirmed',1400.00,'2026-10-19 07:41:17'),(3155,'BAT00015','2021-12-02 23:02:00','Confirmed',1500.00,'2026-10-19 07:41:17'),(3156,'BAT00016','2021-12-02 23:02:00','Confirmed',1600.00,'2026-10-19 07:41:17'),(3157,'BAT00017','2021-12-02 23:02:00','Confirmed',1700.00,'2026-10-19 07:41:17'),(3158,'BAT00018','2021-12-02 23:02:00','Confirmed',1800.00,'2026-10-19 07:41:17'),(3159,'BAT00019','2021-12-02 23:02:00','Confirmed',1900.00,'2026-10-19 07:41:17'),(3160,'BAT00020','2021-12-02 23:02:00','Confirmed',2000.00,'2026-10-19 07:41:17'),(3161,'BAT00021','2021-12-02 23:02:00','Confirmed',2100.00,'2026-10-19 07:41:17'),(3162,'BAT00022','2021-12-02 23:02:00','Confirmed',2200.00,'2026-10-19 07:41:18'),(3163,'BAT00023','2021-12-02 23:02:00','Confirmed',2300.00,'2026-10-19 07:41:18'),(3164,'BAT00024','2021-12-02 23:02:00','Confirmed',2400.00,'2026-10-19 07:41:18'),(3165,'BAT00025','2021-12-02 23:02:00','Confirmed',2500.00,'2026-10-19 07:41:18'),(3166,'BAD00001','2021-12-02 23:02:00','Confirmed',100.00,'2026-10-19 07:49:51'),(3167,'BAD00003','2021-12-02 18:02:00','Confirmed',1250.50,'2026-10-19 07:49:51');
/*!40000 ALTER TABLE `customer_orders` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `file_audit_log`
--

DROP TABLE IF EXISTS `file_audit_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `file_audit_log` (
  `id` int NOT NULL AUTO_INCREMENT,
  `file_name` varchar(255) NOT NULL,
  `status` varchar(10) NOT NULL COMMENT 'SUCCESS or FAILED',
  `reason` text,
  `timestamp` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=66 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `file_audit_log`
--

LOCK TABLES `file_audit_log` WRITE;
/*!40000 ALTER TABLE `file_audit_log` DISABLE KEYS */;
INSERT INTO `file_audit_log` VALUES (58,'ord*****sv','SUCCESS','{\n  \"fileName\": \"ord*****sv\",\n  \"totalRecords\": 3,\n  \"successCount\": 3,\n  \"failedCount\": 0,\n  \"processingTimeMs\": 351\n}','2026-10-19 15:38:03'),(59,'ord********sv','SUCCESS','{\n  \"fileName\": \"ord********sv\",\n  \"totalRecords\": 25,\n  \"successCount\": 25,\n  \"failedCount\": 0,\n  \"processingTimeMs\": 1368\n}','2026-10-19 15:41:18'),(60,'ord********sv','SUCCESS','{\n  \"fileName\": \"ord********sv\",\n  \"totalRecords\": 25,\n  \"successCount\": 25,\n  \"failedCount\": 0,\n  \"processingTimeMs\": 649\n}','2026-10-19 15:45:28'),(61,'ord*********sv','FAILED','{\n  \"fileName\": \"ord*********sv\",\n  \"totalRecords\": 3,\n  \"successCount\": 2,\n  \"failedCount\": 1,\n  \"processingTimeMs\": 273\n}','2026-10-19 15:49:52'),(62,'emp****sv','FAILED','File is empty','2026-10-19 15:56:33'),(63,'big**sv','FAILED','File size exceeds 5 MB','2026-10-19 15:56:36'),(64,'ord*****sv','SUCCESS','{\n  \"fileName\": \"ord*****sv\",\n  \"totalRecords\": 3,\n  \"successCount\": 3,\n  \"failedCount\": 0,\n  \"processingTimeMs\": 242\n}','2026-10-19 16:01:57'),(65,'ord*****sv','SUCCESS','{\n  \"fileName\": \"ord*****sv\",\n  \"totalRecords\": 3,\n  \"successCount\": 3,\n  \"failedCount\": 0,\n  \"processingTimeMs\": 221\n}','2026-10-19 16:03:02');
/*!40000 ALTER TABLE `file_audit_log` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `order_errors`
--

DROP TABLE IF EXISTS `order_errors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `order_errors` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` varchar(20) DEFAULT NULL,
  `error_message` text,
  `timestamp` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `order_errors`
--

LOCK TABLES `order_errors` WRITE;
/*!40000 ALTER TABLE `order_errors` DISABLE KEYS */;
INSERT INTO `order_errors` VALUES (15,'BAD***02','Record failed in batch step','2026-10-19 15:49:52');
/*!40000 ALTER TABLE `order_errors` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-10-20  1:47:51
