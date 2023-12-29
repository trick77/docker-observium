-- MariaDB dump 10.19  Distrib 10.11.4-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: db    Database: observium
-- ------------------------------------------------------
-- Server version	11.2.2-MariaDB-1:11.2.2+maria~ubu2204

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Dumping data for table `alert_tests`
--

LOCK TABLES `alert_tests` WRITE;
/*!40000 ALTER TABLE `alert_tests` DISABLE KEYS */;
INSERT INTO `alert_tests` VALUES
(1,'storage','Storage exceeds 90% of disk','','{\"condition\":\"AND\",\"rules\":[{\"id\":\"device.hostname\",\"field\":\"device.hostname\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"match\",\"value\":\"*\"}],\"valid\":true}','[{\"metric\":\"storage_perc\",\"condition\":\"ge\",\"value\":\"90\"}]',NULL,1,'crit',0,'',1,1,0,NULL),
(2,'mempool','Memory is above 97%','','{\"condition\":\"AND\",\"rules\":[{\"id\":\"device.hostname\",\"field\":\"device.hostname\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"match\",\"value\":\"*\"}],\"valid\":true}','[{\"metric\":\"mempool_perc\",\"condition\":\"ge\",\"value\":\"97\"}]',NULL,1,'warn',1,'',1,1,0,NULL),
(3,'processor','Processor is above 90%','','{\"condition\":\"AND\",\"rules\":[{\"id\":\"device.hostname\",\"field\":\"device.hostname\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"match\",\"value\":\"*\"}],\"valid\":true}','[{\"metric\":\"processor_usage\",\"condition\":\"ge\",\"value\":\"90\"}]',NULL,1,'warn',1,'',1,1,0,NULL),
(5,'port','Port traffic above 95%','','{\"condition\":\"OR\",\"rules\":[{\"id\":\"device.hostname\",\"field\":\"device.hostname\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"match\",\"value\":\"*\"}],\"valid\":true}','[{\"metric\":\"ifInOctets_perc\",\"condition\":\"ge\",\"value\":\"95\"},{\"metric\":\"ifOutOctets_perc\",\"condition\":\"ge\",\"value\":\"95\"}]',NULL,0,'warn',2,'',1,1,0,NULL),
(6,'device','Device down!','','{\"condition\":\"AND\",\"rules\":[{\"id\":\"device.hostname\",\"field\":\"device.hostname\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"match\",\"value\":\"*\"}],\"valid\":true}','[{\"metric\":\"device_status\",\"condition\":\"equals\",\"value\":\"0\"}]',NULL,1,'crit',0,'',1,1,0,NULL);
/*!40000 ALTER TABLE `alert_tests` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
