SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';

CREATE SCHEMA IF NOT EXISTS `mydb` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci ;
USE `mydb` ;

-- -----------------------------------------------------
-- Table `mydb`.`ocr`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mydb`.`ocr` (
  `idocr` INT NOT NULL,
  `imageFile` VARCHAR(4096) NOT NULL,
  `avgWordConfidence` INT NULL,
  `numWords` INT NULL,
  `startOcr` DATETIME NULL,
  `timeOcr` INT NULL,
  `ocrEngine` VARCHAR(45) NULL,
  `remarks` VARCHAR(45) NULL,
  `langParam` VARCHAR(8) NULL,
  `outputText` TEXT NULL,
  `imageFileSize` INT NULL,
  PRIMARY KEY (`idocr`, `imageFile`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
