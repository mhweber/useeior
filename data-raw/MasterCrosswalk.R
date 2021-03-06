# Create a function to generate the MasterCrosswalk table
extractBEAtoNAICSfromIOTable <- function (year) { # year = 2012 or 2007
  if (year == 2012) {
    # Download the IO table
    FileName <- "inst/extdata/IOUse_Before_Redefinitions_PRO_2007_2012_Detail.xlsx"
    if(!file.exists(FileName)) {
      utils::download.file("https://apps.bea.gov/industry/xls/io-annual/IOUse_Before_Redefinitions_PRO_DET.xlsx",
                    FileName, mode = "wb")
    }
    # Load desired excel file
    BEAtable <- as.data.frame(readxl::read_excel(FileName, sheet = "NAICS Codes", col_names = FALSE))
    # Split to BEA and BEAtoNAICS
    BEA <- BEAtable[-c(1:5), c(1:2, 4:5)]
    BEAtoNAICS <- BEAtable[-c(1:5), c(4:5, 7)]
  } else { #year = 2007
    BEAtable <- as.data.frame(readxl::read_excel(paste(BEApath, "2007Schema/IOUse_Before_Redefinitions_PRO_2007_Detail.xlsx", sep = ""),
                                                 sheet = "NAICS codes", col_names = FALSE))
    # Split to BEA and BEAtoNAICS
    BEA <- BEAtable[-c(1:4), 1:4]
    BEAtoNAICS <- BEAtable[-c(1:4), c(3:4, 6)]
  }
  
  # Extract BEA (Sector, Summary, Detail) Code and Name
  # BEA only
  BEA[, 1:2] <- zoo::na.locf(BEA[, 1:2])
  colnames(BEA) <- c("BEA_Sector_Code", "BEA_Summary_Code", "BEA_Detail_Code", "BEA_Detail_Name")
  BEA <- BEA[!is.na(BEA$BEA_Detail_Code) & !is.na(BEA$BEA_Detail_Name), ]
  # Merge to get BEA_Sector_Name
  BEA <- merge(BEA, BEAtable[, 1:2], by.x = "BEA_Sector_Code", by.y = "...1")
  colnames(BEA)[5] <- "BEA_Sector_Name"
  # Merge to get BEA_Summary_Name
  BEA <- merge(BEA, BEAtable[, 2:3], by.x = "BEA_Summary_Code", by.y = "...2")
  colnames(BEA)[6] <- "BEA_Summary_Name"
  # Order columns
  BEA <- BEA[,c("BEA_Sector_Code", "BEA_Sector_Name", "BEA_Summary_Code", "BEA_Summary_Name", "BEA_Detail_Code", "BEA_Detail_Name")]
  
  # Extract BEA Detail Code and Name with NAICS
  colnames(BEAtoNAICS) <- c("BEA_Detail_Code", "BEA_Detail_Name", "NAICS")
  BEAtoNAICS <- BEAtoNAICS[!is.na(BEAtoNAICS$BEA_Detail_Code) & !is.na(BEAtoNAICS$BEA_Detail_Name), ]
  # Split the NAICS column by comma (,)
  BEAtoNAICS <- cbind(BEAtoNAICS, do.call("rbind", strsplit(BEAtoNAICS$NAICS, ",")))
  BEAtoNAICS$NAICS <- NULL
  # Reshape and drop duplicats
  BEAtoNAICSlong <- reshape2::melt(BEAtoNAICS, id.vars = c("BEA_Detail_Code", "BEA_Detail_Name"))
  BEAtoNAICSlong$variable <- NULL
  BEAtoNAICSlong <- unique(BEAtoNAICSlong)
  BEAtoNAICSlong$value <- as.character(BEAtoNAICSlong$value)
  row.names(BEAtoNAICSlong) <- NULL
  # Separate the table into chunks
  # The NAICS codes with dash (-): split the NAICS column by dash (-) and recreate the correct NAICS code
  BEAtoNAICSlongDash <- BEAtoNAICSlong[rownames(BEAtoNAICSlong) %in% grep("-", BEAtoNAICSlong$value, value = FALSE), ]
  DashSplit <- do.call("rbind.data.frame", lapply(BEAtoNAICSlongDash$value, function(x) do.call("rbind", strsplit(gsub("-", paste(",", substr(x, 1, nchar(x)-3), sep = ""), x), ","))))
  DashSplit <- do.call("rbind.data.frame", apply(DashSplit, 1, function(x) seq(x[1], x[2], 1)))
  colnames(DashSplit) <- c(paste("V", 1:ncol(DashSplit), sep=""))
  BEAtoNAICSlongDash <- cbind(BEAtoNAICSlongDash[, c("BEA_Detail_Code", "BEA_Detail_Name")], DashSplit)
  BEAtoNAICSlongDash <- reshape2::melt(BEAtoNAICSlongDash, id.vars = c("BEA_Detail_Code", "BEA_Detail_Name"))
  BEAtoNAICSlongDash$variable <- NULL
  BEAtoNAICSlongDash <- unique(BEAtoNAICSlongDash)
  # The NAICS codes are "n.a."
  # The NAICS codes without dash (-)
  if (year==2012) {
    BEAtoNAICSlongNA <- BEAtoNAICSlong[BEAtoNAICSlong$value == "n.a.", ]
    BEAtoNAICSlongSubset <- BEAtoNAICSlong[!rownames(BEAtoNAICSlong) %in% grep("-", BEAtoNAICSlong$value, value = FALSE) & !BEAtoNAICSlong$value == "n.a.", ]
    BEAtoNAICSlongSubset <- do.call("cbind.data.frame", lapply(BEAtoNAICSlongSubset, gsub, pattern="*", replacement=""))
    BEAtoNAICSlongSubset$value <- gsub("[*]", "", BEAtoNAICSlongSubset$value)
  } else {
    BEAtoNAICSlongNA <- BEAtoNAICSlong[BEAtoNAICSlong$value == "n/a", ]
    BEAtoNAICSlongSubset <- BEAtoNAICSlong[!rownames(BEAtoNAICSlong) %in% grep("-", BEAtoNAICSlong$value, value = FALSE) & !BEAtoNAICSlong$value == "n/a", ]
    BEAtoNAICSlongSubset <- do.call("cbind.data.frame", lapply(BEAtoNAICSlongSubset, gsub, pattern="*", replacement=""))
  }
  
  # Assemble all chunks together
  BEAtoNAICS <- rbind(BEAtoNAICSlongDash, BEAtoNAICSlongNA, BEAtoNAICSlongSubset)
  BEAtoNAICS <- BEAtoNAICS[order(BEAtoNAICS$BEA_Detail_Code), ]
  row.names(BEAtoNAICS) <- NULL
  colnames(BEAtoNAICS)[3] <- "NAICS_Code"
  # Merge with BEA
  BEAtoNAICS <- merge(BEAtoNAICS, BEA, by = c("BEA_Detail_Code", "BEA_Detail_Name"), all.x = TRUE)
  BEAtoNAICS <- BEAtoNAICS[, c(colnames(BEA), "NAICS_Code")]
  BEAtoNAICS$NAICS_Code <- as.integer(BEAtoNAICS$NAICS_Code)
  BEAtoNAICS[BEAtoNAICS$BEA_Detail_Code=="517A00" & BEAtoNAICS$NAICS_Code=="5719", "NAICS_Code"] <- as.integer(5179)
  # Add year into column names
  colnames(BEAtoNAICS)[1:6] <- gsub("BEA_", paste("BEA_", year, "_", sep = ""), colnames(BEAtoNAICS)[1:6])
  colnames(BEAtoNAICS)[7] <- gsub("NAICS_", paste("NAICS_", year, "_", sep = ""), colnames(BEAtoNAICS)[7])
  
  return(BEAtoNAICS)
}


getBEAtoNAICS <- function (year) {
  # Define local variables
  BEAyearDetailCode <- paste("BEA_", year, "_Detail_Code", sep = "")
  NAICSyearCode <- paste("NAICS_", year, "_Code", sep = "")
  NAICSyearCode.x <- paste("NAICS_", year, "_Code.x", sep = "")
  NAICSyearCode.y <- paste("NAICS_", year, "_Code.y", sep = "")
  
  # Generate BEAtoNAICS table from IO table
  BEAtoNAICS <- extractBEAtoNAICSfromIOTable(year)
  # Load supplementary BEAtoNAICS table from SI folder
  BEAtoNAICSsupp <- utils::read.table(paste0("inst/extdata/BEAtoNAICS_", year, "_supp.csv"), sep = ",", header = TRUE, stringsAsFactors = FALSE)
  # Merg the two
  BEAtoNAICSall <- merge(BEAtoNAICS, BEAtoNAICSsupp, by = BEAyearDetailCode, all = TRUE)
  
  # Fill the n.a. in NAICS with NAICS_2012_Code
  BEAtoNAICSall[is.na(BEAtoNAICSall[, NAICSyearCode.x]), NAICSyearCode.x] <- BEAtoNAICSall[is.na(BEAtoNAICSall[, NAICSyearCode.x]), NAICSyearCode.y]
  BEAtoNAICSall[, NAICSyearCode] <- BEAtoNAICSall[, NAICSyearCode.x]
  # Drop NAICS_2012_Code column and re-order the columns
  BEAtoNAICSall <- BEAtoNAICSall[, colnames(BEAtoNAICS)]
  
  # Generate complete NAICSwide table from NAICS list from Census
  NAICSwide <- getNAICS2to6Digits(year)
  
  # Merge
  # at 6-digit NAICS
  BEAtoNAICS6 <- merge(BEAtoNAICSall, NAICSwide[!is.na(NAICSwide$NAICS_6), ], by.x = NAICSyearCode, by.y = "NAICS_6")
  BEAtoNAICS6 <- reshape2::melt(BEAtoNAICS6, id.vars = colnames(BEAtoNAICSall)[-7])[, -7]
  # at 5-digit NAICS
  BEAtoNAICS5 <- merge(BEAtoNAICSall, NAICSwide[!is.na(NAICSwide$NAICS_5), ], by.x = NAICSyearCode, by.y = "NAICS_5")
  #BEAtoNAICS5[, c("NAICS_6")] <- NULL
  BEAtoNAICS5 <- reshape2::melt(BEAtoNAICS5, id.vars = colnames(BEAtoNAICSall)[-7])[, -7]
  # at 4-digit NAICS
  BEAtoNAICS4 <- merge(BEAtoNAICSall, NAICSwide[!is.na(NAICSwide$NAICS_4), ], by.x = NAICSyearCode, by.y = "NAICS_4")
  #BEAtoNAICS4[, c("NAICS_5", "NAICS_6")] <- NULL
  BEAtoNAICS4 <- reshape2::melt(BEAtoNAICS4, id.vars = colnames(BEAtoNAICSall)[-7])[, -7]
  # at 3-digit NAICS
  BEAtoNAICS3 <- merge(BEAtoNAICSall, NAICSwide[!is.na(NAICSwide$NAICS_3), ], by.x = NAICSyearCode, by.y = "NAICS_3")
  #BEAtoNAICS3[, c("NAICS_4", "NAICS_5", "NAICS_6")] <- NULL
  BEAtoNAICS3 <- reshape2::melt(BEAtoNAICS3, id.vars = colnames(BEAtoNAICSall)[-7])[, -7]
  # at 2-digit NAICS
  BEAtoNAICS2 <- merge(BEAtoNAICSall, NAICSwide[!is.na(NAICSwide$NAICS_2), ], by.x = NAICSyearCode, by.y = "NAICS_2")
  #BEAtoNAICS2[, c("NAICS_3", "NAICS_4", "NAICS_5", "NAICS_6")] <- NULL
  BEAtoNAICS2 <- reshape2::melt(BEAtoNAICS2, id.vars = colnames(BEAtoNAICSall)[-7])[, -7]
  
  # Assemble, drop NAs in value column, and re-order columns
  BEAtoNAICSwide <- unique(rbind(BEAtoNAICS2, BEAtoNAICS3, BEAtoNAICS4, BEAtoNAICS5, BEAtoNAICS6))
  BEAtoNAICSwide <- BEAtoNAICSwide[!is.na(BEAtoNAICSwide$value), ]
  BEAtoNAICSwide[, NAICSyearCode] <- BEAtoNAICSwide$value
  BEAtoNAICSwide <- BEAtoNAICSwide[, colnames(BEAtoNAICS)]
  
  # Add the BEA sectors that do not have NAICS matches
  BEAtoNAICScomplete <- rbind(BEAtoNAICSwide, BEAtoNAICSall[is.na(BEAtoNAICSall[, NAICSyearCode]), ])
  BEAtoNAICScomplete <- BEAtoNAICScomplete[order(BEAtoNAICScomplete[, BEAyearDetailCode], BEAtoNAICScomplete[, NAICSyearCode]), ]
  
  # Assign NAICS_Name
  NAICSCodeName <- getNAICS2to6DigitsCodeName(year)
  
  BEAtoNAICScomplete <- merge(BEAtoNAICScomplete, NAICSCodeName, by = NAICSyearCode, all.x = TRUE)
  
  BEAtoNAICScomplete <- BEAtoNAICScomplete[, c(colnames(BEAtoNAICSwide), paste("NAICS_", year, "_Name", sep = ""))]
  
  return(BEAtoNAICScomplete)
}


getBEAtoUSEEIO <- function (year) {
  # Prepare a base BEAtoUSEEIO table from IO table
  BEAtoUSEEIO <- extractBEAtoNAICSfromIOTable(year)
  BEAyearDetail <- c(paste("BEA_", year, "_Detail_Code", sep = ""), paste("BEA_", year, "_Detail_Name", sep = ""))
  # Add USEEIO columns
  if (year==2007) {
    BEAtoUSEEIO[, c("USEEIO_Code", "USEEIO_Industry")] <- BEAtoUSEEIO[, BEAyearDetail]
  } else {
    BEAtoUSEEIO[, c("USEEIO_Code", "USEEIO_Industry")] <- BEAtoUSEEIO[, BEAyearDetail]
    # # Add WaterWasteBEAtoUSEEIODisaggregation table
    # WaterWaste <- utils::read.table(paste(Crosswalkpath, "WaterWasteBEAtoUSEEIODisaggregation.csv", sep = ""), sep = ",", header = TRUE, stringsAsFactors = FALSE)
    # WaterWaste[] <- lapply(WaterWaste, as.character)
    # # Merge
    # BEAtoUSEEIO <- merge(BEAtoUSEEIO, WaterWaste, by.x = BEAyearDetail[1], by.y = "BEA_Code", all = TRUE)
    # BEAtoUSEEIO[is.na(BEAtoUSEEIO$USEEIO_Code), "USEEIO_Code"] <- BEAtoUSEEIO[is.na(BEAtoUSEEIO$USEEIO_Code), BEAyearDetail[1]]
    # BEAtoUSEEIO[is.na(BEAtoUSEEIO$USEEIO_Industry), "USEEIO_Industry"] <- BEAtoUSEEIO[is.na(BEAtoUSEEIO$USEEIO_Industry), BEAyearDetail[2]]
  }
  BEAtoUSEEIO[, paste("NAICS_", year, "_Code", sep = "")] <- NULL
  
  return(BEAtoUSEEIO)
}

getMasterCrosswalk <- function (year) {
  # Generate BEAtoNAICScomplete
  BEAtoNAICScomplete <- getBEAtoNAICS(year)
  # Generate BEAtoUSEEIOcomplete
  BEAtoUSEEIOcomplete <- getBEAtoUSEEIO(year)
  # Merge
  BEAColumns <- c(paste(rep("BEA_", 6), year, rep(c("_Sector", "_Summary", "_Detail"), each = 2), rep(c("_Code", "_Name"), 3), sep = ""))
  BEAtoUSEEIOtoNAICS <- unique(merge(BEAtoUSEEIOcomplete, BEAtoNAICScomplete, by = BEAColumns))
  
  # Drop 23 and G sectors in BEAtoUSEEIOtoNAICS
  BEAyearSectorCode <- c(paste("BEA_", year, "_Sector_Code", sep = ""))
  BEAtoUSEEIOtoNAICS <- BEAtoUSEEIOtoNAICS[!BEAtoUSEEIOtoNAICS[, BEAyearSectorCode] %in% c("23", "G"), ]
  # Load pre-created tables for 23, G, F, and V sectors
  # 23
  Crosswalk23 <- utils::read.table(paste0("inst/extdata/23_BEAtoUSEEIOtoNAICS_", year, ".csv"), sep = ",", header = TRUE, stringsAsFactors = FALSE)
  # G
  CrosswalkG <- utils::read.table(paste0("inst/extdata/G_BEAtoUSEEIOtoNAICS_", year, ".csv"), sep = ",", header = TRUE, stringsAsFactors = FALSE)
  # F
  CrosswalkF <- utils::read.table(paste0("inst/extdata/F_BEAtoUSEEIOtoNAICS_", year, ".csv"), sep = ",", header = TRUE, stringsAsFactors = FALSE)
  # V
  CrosswalkV <- utils::read.table(paste0("inst/extdata/V_BEAtoUSEEIOtoNAICS_", year, ".csv"), sep = ",", header = TRUE, stringsAsFactors = FALSE)
  
  # Attach the pre-created 23, G, F, and V sectors to BEAtoUSEEIOtoNAICS
  BEAtoUSEEIOtoNAICS <- rbind(BEAtoUSEEIOtoNAICS, Crosswalk23, CrosswalkG, CrosswalkF, CrosswalkV)
  
  # Add USEEIO_Commodity columns
  SectortoCommodity <- utils::read.table(paste0("inst/extdata/DetailIndustrytoCommodityName", year, "Schema.csv"), sep = ",", header = TRUE, stringsAsFactors = FALSE, quote = "\"")
  BEAtoUSEEIOtoNAICS <- merge(BEAtoUSEEIOtoNAICS, SectortoCommodity[, -2], by = paste("BEA_", year, "_Detail_Code", sep = ""), all.x = TRUE)
  
  # Keep wanted columns
  Columns <- c(paste0(rep("BEA_", 6), year, rep(c("_Sector", "_Summary", "_Detail"), each = 2), rep(c("_Code", "_Name"), 3)),
               paste0(rep("USEEIO", 2),  c("_Code", "_Name")),
               paste0(rep("NAICS_", 2), year, c("_Code", "_Name")))
  BEAtoUSEEIOtoNAICS <- BEAtoUSEEIOtoNAICS[, Columns]
  BEAtoUSEEIOtoNAICS <- BEAtoUSEEIOtoNAICS[order(BEAtoUSEEIOtoNAICS[, paste("NAICS_", year, "_Code", sep = "")]), ]
  
  # Add NAICS 2007/2012 Code column
  # Download the 2007 and 2012 NAICS code concordances (6-digit)
  FileName <- "inst/extdata/2012_to_2007_NAICS.xls"
  if(!file.exists(FileName)) {
    utils::download.file("https://www.census.gov/eos/www/naics/concordances/2012_to_2007_NAICS.xls", FileName, mode = "wb")
  }
  NAICS2007to2012 <- as.data.frame(readxl::read_excel(FileName, sheet = 1, col_names = TRUE, skip = 2))
  NAICS2007to2012 <- as.data.frame(sapply(NAICS2007to2012[, c("2012 NAICS Code", "2007 NAICS Code")], as.factor))
  ColNames <- colnames(NAICS2007to2012) <- c("NAICS_2012_Code", "NAICS_2007_Code")
  # Generate 2007 and 2012 NAICS code concordances at 2-5 digits
  NAICS2007to2012_2digit <- unique(do.call("cbind.data.frame", lapply(NAICS2007to2012, function(x) substr(x, 1, 2))))
  NAICS2007to2012_3digit <- unique(do.call("cbind.data.frame", lapply(NAICS2007to2012, function(x) substr(x, 1, 3))))
  NAICS2007to2012_4digit <- unique(do.call("cbind.data.frame", lapply(NAICS2007to2012, function(x) substr(x, 1, 4))))
  NAICS2007to2012_5digit <- unique(do.call("cbind.data.frame", lapply(NAICS2007to2012, function(x) substr(x, 1, 5))))
  # Assemble 2007 and 2012 NAICS code concordances at 2-6 digits
  NAICS2007to2012all <- rbind(setNames(NAICS2007to2012_2digit, ColNames), setNames(NAICS2007to2012_3digit, ColNames),
                              setNames(NAICS2007to2012_4digit, ColNames), setNames(NAICS2007to2012_5digit, ColNames),
                              NAICS2007to2012)
  NAICS2007to2012all[] <- lapply(NAICS2007to2012all, as.character)
  # Merge BEAtoUSEEIOtoNAICS with NAICS2007to2012
  if (year==2007) {
    MasterCrosswalk <- merge(BEAtoUSEEIOtoNAICS, NAICS2007to2012all, by = "NAICS_2007_Code", all = TRUE)
    MasterCrosswalk <- MasterCrosswalk[, c(colnames(BEAtoUSEEIOtoNAICS), "NAICS_2012_Code")]
  } else {
    MasterCrosswalk <- merge(BEAtoUSEEIOtoNAICS, NAICS2007to2012all, by = "NAICS_2012_Code", all = TRUE)
    MasterCrosswalk <- MasterCrosswalk[, c(colnames(BEAtoUSEEIOtoNAICS), "NAICS_2007_Code")]
    # Include 7-, 8-, and 10-digit NAICS (from Census for manufacturing and mining sectors)
    CensusNAICS <- data(Census_ManufacturingMiningSectors_NAICSCodeName)
    CensusNAICS$NAICS_Code_6digit <- substr(CensusNAICS$NAICS_Code, 1, 6)
    CensusNAICS2USEEIO <- merge(MasterCrosswalk, CensusNAICS, by.x = "NAICS_2012_Code", by.y = "NAICS_Code_6digit")
    CensusNAICS2USEEIO[, c("NAICS_2012_Code", "NAICS_2012_Name")] <- CensusNAICS2USEEIO[, c("NAICS_Code", "NAICS_Name")]
    MasterCrosswalk <- unique(rbind(MasterCrosswalk, CensusNAICS2USEEIO[, colnames(MasterCrosswalk)]))
    # Replace Code and Name for BEA_2012_Sector
    BEA_Sector_CodeName_Mapping <- utils::read.table("inst/extdata/BEA_2012_Sector_CodeName_mapping.csv", sep = ",", header = TRUE, stringsAsFactors = FALSE)
    MasterCrosswalk <- merge(MasterCrosswalk, BEA_Sector_CodeName_Mapping, by = c("BEA_2012_Sector_Code", "BEA_2012_Sector_Name"), all.x = TRUE)
    MasterCrosswalk[, c("BEA_2012_Sector_Code", "BEA_2012_Sector_Name")] <- MasterCrosswalk[, c("BEA_2012_Sector_Code_agg", "BEA_2012_Sector_Name_agg")]
    MasterCrosswalk[, c("BEA_2012_Sector_Code_agg", "BEA_2012_Sector_Name_agg")] <- NULL
  }
  # Order by NAICS and USEEIO code columns
  MasterCrosswalk <- MasterCrosswalk[order(MasterCrosswalk[, paste("NAICS_", year, "_Code", sep = "")], MasterCrosswalk[, "USEEIO_Code"]), ]
  
  return(MasterCrosswalk)
}

MasterCrosswalk2012 <- getMasterCrosswalk(2012)
MasterCrosswalk2012 <- MasterCrosswalk2012[, c(paste("BEA_2012", c("Sector_Code", "Summary_Code", "Detail_Code"), sep = "_"),
                                               paste(c("NAICS_2012", "NAICS_2007"), "Code", sep = "_"))]
usethis::use_data(MasterCrosswalk2012, overwrite = T)

