############ 1.2
########### 3.22.18 Emily Beckman
############# compile all occurrence point data into one standardized dataframe

## Be sure to run "set_workingdirectory.R" before running this script

############### INPUT: several csv files of raw oak occurrence data:
#                     gbif_DarwinCore_edit.csv
#                     consortium_raw.csv
#                     idigbio_raw.csv
#                     exsitu_survey_raw.csv
#                     fia_tree_raw.csv
#                     fia_plot_raw.csv*
#                     fia_species_raw.csv*
#                     fia_county_raw.csv*
#                     target_species_list.csv
#
# * marks files from fia_translation_data_raw folder
# All other files from in-use_occurrence_raw folder

############### OUTPUT: raw_occurrence_compiled.csv
#                 (compilation of all occurrence data to be used in the model)
#                 (plus below fully compiled datasets right before they are merged)
#                 standardized_col_compiled.csv
#                 gbif_compiled.csv
#                 consortium_compiled.csv
#                 idigbio_compiled.csv
#                 exsitu_compiled.csv
#                 fia_compiled.csv
#                 fia_absence_compiled.csv (absence data)


##############
### Functions
##############

## Subset data and (optionally) write a CSV
gen_subset <- function(orig_data, action, export_name){
  selected_rows <- (action)
  new <- orig_data[selected_rows,]
  if (missing(export_name)){
    return(data.frame(new))
  } else {
    write.csv(new, file = export_name)
    return(data.frame(new))
  }
}

## Match up column headers, keeping all columns, not just matching ones [stacking] (fills added columns with NAs)
# SOURCE: https://amywhiteheadresearch.wordpress.com/2013/05/13/combining-dataframes-when-the-columns-dont-match/
rbind.all.columns <- function(x, y) {
  x.diff <- setdiff(colnames(x), colnames(y))
  y.diff <- setdiff(colnames(y), colnames(x))
  x[, c(as.character(y.diff))] <- NA
  y[, c(as.character(x.diff))] <- NA
  return(rbind(x, y))
}
## Example use of rbind.all.columns function:
# Create a list of all dataframes you want to stack
# 'Reduce' iterates through list and merges with previous dataframe in the list
#all_data <- Reduce(rbind.all.columns, file_dfs_list)

###########################
### 1. Target Species List
###########################

# read in list of target species
sp_list <- read.csv(file=paste0(one_up, '/target_species_list.csv'), header = T)

###########################################
### 2. Unify Already-Standardized Datasets
###########################################

# read in standardized occurrence point datasets (exactly the same column headers in each file)
file_list <- list.files(path = "standard_col", pattern = ".csv", full.names = T)
file_dfs <- lapply(file_list, read.csv, header = TRUE, fileEncoding="latin1", strip.white = TRUE, colClasses = "character")
length(file_dfs) #6

# stack standardized datasets to create one dataframe
df <- data.frame()
for(file in seq_along(file_dfs)){
  df <- rbind(df, file_dfs[[file]])
}
str(df); nrow(df) #93171
df$gps_determ <- ifelse(df$gps_determ=="", "NA", df$gps_determ)
# rename columns to match Darwin Core Archive format
setnames(df,
         old=c("source","basis","lat", "long", "uncert_m", "state","status"),
         new=c("institutionCode","basisOfRecord","decimalLatitude", "decimalLongitude",
               "coordinateUncertaintyInMeters", "stateProvince","occurrenceRemarks"))
# add species ID columns from target species list
df <- join(df, sp_list, by = "species", type="left"); str(df)
# remove rows with no species name match (i.e. keep records for target species only)
df <- df[!(is.na(df$speciesKey)),]
nrow(df) #37303

# though we will use this object at the end of the script to build the master
# dataset, we will also save the modified data frame up to this point. We will do the
# same in the following steps.
write.csv(df, file=paste0(one_up, "/in-use_occurrence_compiled/standardized_col_compiled.csv"))

############################
### 3. Standardize GBIF Data
############################

# read in raw occurrence points from the GBIF post_GeoLocate revision
gbif <- read.csv(file='gbif_raw_DarwinCore_edit.csv', as.is=T, na.strings=c("","NA")) # replace any empty or "NA" cells with NA so the rest of the script works smoothly
nrow(gbif) #12195
# keep only the pertinent columns
gbif <- subset(gbif, select = c(order,family,genus,specificEpithet,infraspecificEpithet,scientificName,
                                institutionCode,collectionCode,datasetName,basisOfRecord,catalogNumber,
                                recordNumber,decimalLatitude,decimalLongitude,coordinateUncertaintyInMeters,
                                georeferenceSources,year,individualCount,countryCode,stateProvince,county,
                                municipality,locality,locationRemarks,verbatimLocality,occurrenceRemarks,
                                habitat,fieldNotes,issue,species,speciesKey))
# make sure species is a factor
gbif$species <- as.factor(gbif$species)
# recognize that scientificName refers to something different in sp_list

# the rows will duplicate if their species key duplicates. ex. five lobata lines
# in sp-list, so each lobata occurrence will spring four duplicates here,
# unless we add the first match argument.
# also, the order will not be changed when using the join function
gbif <- join(gbif, sp_list, by = c("speciesKey"), type = "full", match = "first")
# add and fill dataset name column
gbif$dataset <- "gbif"
gbif$fia_codes <- as.factor(gbif$fia_codes)
gbif$gps_determ <- "NA"
# fill in gps_determ col
for(row in 1:nrow(gbif)){
  if(!is.na(gbif$decimalLatitude[row]) && !is.na(gbif$decimalLongitude[row])){
    gbif$gps_determ[row] <- "G"
  }
  else{
    gbif$gps_determ[row] <- "NA"
  }
}
table(gbif$gps_determ)
# G    NA
# 7027 5168
#str(gbif)
nrow(gbif) #12195

write.csv(gbif, file=paste0(one_up, "/in-use_occurrence_compiled/gbif_compiled.csv"))

###########################################
### 4. Standardize Herbaria Consortium Data (SERNEC, SEINet, etc.)
###########################################

# read in raw occurrence points
consortium <- read.csv(file='consortium_raw.csv', as.is=T, na.strings=c("","NA")) # replace any empty or "NA" cells with NA so the rest of the script works smoothly
nrow(consortium) #98500
# keep only the pertinent columns
consortium <- subset(consortium, select = c(order,family,genus,specificEpithet,infraspecificEpithet,
                                            scientificName,scientificNameAuthorship,institutionCode,collectionCode,
                                            basisOfRecord,catalogNumber,recordNumber,decimalLatitude,decimalLongitude,
                                            geodeticDatum,coordinateUncertaintyInMeters,georeferenceSources,year,
                                            individualCount,country,stateProvince,county,municipality,locality,
                                            locationRemarks,occurrenceRemarks,habitat))
# add and fill dataset name column
consortium$dataset <- "consortium"
consortium$synonyms <- consortium$scientificName
# add species ID columns from target species list
consortium <- join(consortium, sp_list, by = "synonyms", type="left", match = "first"); str(consortium)
# remove rows with no species name match (i.e. keep records for target species only)
consortium <- consortium[!(is.na(consortium$species)),]
# fill in gps_determ col
for(row in 1:nrow(consortium)){
  if(!is.na(consortium$decimalLatitude[row]) && !is.na(consortium$decimalLongitude[row])){
    consortium$gps_determ[row] <- "G"
  }
  else{
    consortium$gps_determ[row] <- "NA"
  }
}
table(consortium$gps_determ)
# G    NA
# 1583 3485
nrow(consortium) #5068

write.csv(consortium, file=paste0(one_up, "/in-use_occurrence_compiled/consortium_compiled.csv"))

###############################
### 5. Standardize iDigBio Data
###############################

# read in raw occurrence points
idigbio <- read.csv(file='idigbio_raw.csv', as.is=T, na.strings=c("","NA")) # replace any empty or "NA" cells with NA so the rest of the script works smoothly)
nrow(idigbio) #196485

# remove duplicate column
idigbio <- subset(idigbio, select = -(dwc.eventDate))
# remove the "dwc." and ".idigbio" preceeding each column name
names(idigbio) = gsub(pattern = "dwc.", replacement = "", x = names(idigbio))
names(idigbio) = gsub(pattern = "idigbio.", replacement = "", x = names(idigbio))
names(idigbio)[names(idigbio) == 'isoCountryCode'] <- 'countryCode'
str(idigbio)
# separate single iDigBio lat/long column into lat and long
idigbio <- idigbio %>% separate("geoPoint", c("decimalLatitude", "decimalLongitude"), sep=",", fill="right", extra="merge")
# reassign the empty coord values to NA to avoid confusion
idigbio$decimalLatitude[which(idigbio$decimalLatitude==unique(idigbio$decimalLatitude)[1] )] <- NA
idigbio$decimalLongitude[which(idigbio$decimalLongitude==unique(idigbio$decimalLongitude)[1] )] <- NA
# remove the extra symbols in lat column and change to a numeric variable
# when using gsub, be sure to include fixed=T to avoid confusion of symbols like "
idigbio$decimalLatitude <- as.numeric(gsub("{\"lat\": ","",idigbio$decimalLatitude, fixed = T))
# repeat for longitude ("long" column)
# first remove the bracket at the end
idigbio$decimalLongitude <- gsub("}", "", idigbio$decimalLongitude)
# then remove the extra symbols and change to numeric
idigbio$decimalLongitude <- as.numeric(gsub(" \"lon\": ","",idigbio$decimalLongitude, fixed = T))

# standardize the eventDate column
# first we have to remove the characters that are not the year, month or day
idigbio <- idigbio %>% separate("eventDate", c("year", "delete"), sep="-", fill="right", extra="merge")
# remove unwanted "delete" column
idigbio <- subset(idigbio, select = -(delete))
# keep only the pertinent columns
idigbio <- subset(idigbio, select = c(order,family,genus,specificEpithet,infraspecificEpithet,
                                      scientificName,institutionCode,collectionCode,basisOfRecord,
                                      catalogNumber,recordNumber,decimalLatitude,decimalLongitude,
                                      coordinateUncertaintyInMeters,year,individualCount,countryCode,
                                      stateProvince,county,municipality,locality,dataQualityScore))
# add and fill dataset name column
idigbio$dataset <- "idigbio"
# capitalize first letter of genus
idigbio$genus <- str_to_title(idigbio$genus, locale = "en")
# create synonyms column to match with sp_list
idigbio$synonyms <- as.factor(paste(idigbio$genus,idigbio$specificEpithet))
# add standard species ID columns
idigbio <- join(idigbio, sp_list, by = "synonyms", type="left"); str(idigbio)
# remove rows with no species name match (i.e. keep records for target species only)
idigbio <- idigbio[!(is.na(idigbio$speciesKey)),]
# fill in gps_determ col
for(row in 1:nrow(idigbio)){
  if(!is.na(idigbio$decimalLatitude[row]) && !is.na(idigbio$decimalLongitude[row])){
    idigbio$gps_determ[row] <- "G"
  }
  else{
    idigbio$gps_determ[row] <- "NA"
  }
}
table(idigbio$gps_determ)
# G    NA
# 6065 5668
nrow(idigbio) # 11733 (ELT)

write.csv(idigbio, file=paste0(one_up, "/in-use_occurrence_compiled/idigbio_compiled.csv"))

#########################################
### 6. Standardize Exsitu Wild Prov. Data
#########################################

exsitu <- read.csv(file='exsitu_survey_raw.csv', as.is=T, na.strings=c("","NA")) # replace any empty or "NA" cells with NA so the rest of the script works smoothly)
nrow(exsitu) #1640

# keep only the pertinent columns
exsitu <- subset(exsitu, select = c(institution,species,prov_type,all_locality_orig,lat_dd,long_dd,
                                    county,state,gps_determination,sum.no_alive.))
# rename columns to match Darwin Core Archive format
setnames(exsitu,
         old=c("species","institution","prov_type","lat_dd","long_dd","sum.no_alive.",
                "state","all_locality_orig","gps_determination"),
         new=c("specificEpithet","institutionCode","basisOfRecord","decimalLatitude",
                "decimalLongitude","individualCount","stateProvince","locality","gps_determ"))
# add genus column
exsitu$genus <- "Quercus"
# create species column to match with sp_list
exsitu$species <- as.factor(paste(exsitu$genus,exsitu$specificEpithet))
# add species ID columns from target species list
exsitu <- join(exsitu, sp_list, by = "species",type="left",match="first"); str(exsitu)
# add and fill dataset name column
exsitu$dataset <- "exsitu"
# remove rows with no species name match (i.e. keep records for target species only)
exsitu <- exsitu[!(is.na(exsitu$speciesKey)),]
exsitu$gps_determ <- ifelse(is.na(exsitu$gps_determ), "NA", exsitu$gps_determ)
nrow(exsitu) # 1545

write.csv(exsitu, file=paste0(one_up, "/in-use_occurrence_compiled/exsitu_compiled.csv"))

#####################################
### 7. Standardize FIA Presence Data
#####################################

# read in FIA files
fia <- read.csv(file='fia_tree_raw.csv', as.is=T)   # where species information is stored
plot <- read.csv(file=paste0(translate_fia, '/fia_plot_raw.csv'), as.is=T)   # where coordinates are stored
# remove unnecessary columns from plot
plot <- plot[, c("INVYR", "STATECD", "UNITCD", "COUNTYCD", "PLOT", "LAT", "LON")]
# Match the location IDs and merge the species and plot data frames
fia_coord <- merge(fia, plot, by.y = c("INVYR", "STATECD", "UNITCD", "COUNTYCD", "PLOT"), all = F)
# Add in density here. First make a dataframe with all unique plots and number them.
u <- unique(fia_coord[,c('SPCD', 'INVYR','STATECD','UNITCD', 'COUNTYCD', 'PLOT', 'LAT', 'LON')])
ID <- seq(from = 1, to = length(u$INVYR), by = 1)
u_plot <- data.frame(u, ID)
# using ID as a label that marks unique plots, see how many individual trees of a species are found in each.
density_test <- merge(u_plot, fia_coord, by = c("SPCD", "INVYR", "UNITCD", "COUNTYCD", "PLOT", "STATECD"), all = T)
t <- as.numeric(table(density_test$ID))
# The results of the table show the number of individuals per plot
u_plot$density <- t
# manipulate u_plot further to add onto raw data block; rename as fia
fia <- u_plot
rm(density_test, u, ID)
# Match up SPCD using
fia_sp <- read.csv(file=paste0(translate_fia, '/fia_species_raw.csv'), as.is=T)
fia <- merge(fia, fia_sp, by = "SPCD", all = F)
fia <- fia[, 1:16]
# count individuals per species
unique(fia$SPECIES) # see order of species for below counts
sum(fia[fia$SPECIES==unique(fia$SPECIES)[9], "density"]) # count number of individual trees reported per species
table(fia$SPECIES) # count how many plots with unique coordinates contain the above individual trees
# combine columns into single species name
fia$scientificName <- paste(fia$GENUS, fia$SPECIES, fia$VARIETY, fia$SUBSPECIES)
fia$species <- paste(fia$GENUS, fia$SPECIES)
fia$order <- "Fagales"
fia$family <- "Fagaceae"
fia$institutionCode <- "USFS"
fia$country <- "US"
# Match up STATECD and COUNTYCD using
fia_cou <- read.csv(file=paste0(translate_fia, '/fia_county_raw.csv'), as.is=T)
fia <- merge(fia, fia_cou, by = c("STATECD", "COUNTYCD"), all = F)
# keep only the pertinent columns
fia <- subset(fia, select = c(order,family,GENUS,SPECIES,scientificName,institutionCode,
                              LAT,LON,INVYR,density,country,STATENM,COUNTYNM,species,SPCD))
# rename remaining columns to match other data sets
setnames(fia,
         old=c("LAT","LON", "INVYR", "STATENM", "COUNTYNM", "SPCD", "GENUS","SPECIES", "density", "country"),
         new=c("decimalLatitude","decimalLongitude", "year", "stateProvince", "county", "fia_codes", "genus","specificEpithet", "individualCount", "countryCode"))
fia$dataset <- "fia"
fia$basisOfRecord <- "observation"
fia$gps_determ <- "G"
# add standard species ID columns
fia <- join(fia, sp_list, by = c("fia_codes", "species"), type="left", match = "first"); str(fia)

write.csv(fia, file=paste0(one_up, "/in-use_occurrence_compiled/fia_compiled.csv"))

##########################
### 8. Stack All Datasets
##########################

# Create a list of all dataframes you want to stack
datasets <- list(df,gbif,consortium,idigbio,exsitu,fia)
# 'Reduce' iterates through list and merges with previous dataframe in the list
all_data <- Reduce(rbind.all.columns, datasets)
  nrow(all_data) #68237
  #str(all_data)
  unique(all_data$gps_determ)
  test <- all_data[which(all_data$gps_determ == "NA" & !is.na(all_data$decimalLatitude)),]
    unique(test$dataset)
  #all_data$gps_determ <- ifelse(is.na(all_data$gps_determ),"NA",all_data$gps_determ)
  table(all_data$gps_determ)
  # C     G      L    NA
  # 3691  37178  280  27088

# write final file
write.csv(all_data, file="raw_occurrence_compiled.csv")

################################
### 9. Compile FIA Absence Data
################################

# note that this absence data will only be for the 13 species that FIA included in its inventory
rare_oak <- c(6768, 8429, 811, 6782, 851, 6785, 8514, 821, 844, 8492, 836, 8455, 8457)

# name new absence file
fia_absence_joint <- plot
# remove most rows from exisiting fia dataset
fia_pres <- subset(fia, select = c(decimalLatitude, decimalLongitude,
                              species,fia_codes, year))
# change the names from DarwinCore to fia standards
setnames(fia_pres,
         old=c("decimalLatitude","decimalLongitude", "year", "fia_codes"),
          new=c("LAT","LON", "INVYR", "SPCD"))
#subset by species
presence <- fia_pres[fia_pres$SPCD==rare_oak[1],]
nrow(presence)
fia_absence_joint$arkansana <- 0

presence <- fia_pres[fia_pres$SPCD==rare_oak[2],]
nrow(presence)
fia_absence_joint$austrina <- 0

# this species is different because some occurrences were reported by FIA
presence <- fia_pres[fia_pres$SPCD==rare_oak[3],]
nrow(presence)
presence$dumosa <- 1
fia_absence_joint <- join(fia_absence_joint, presence, by = c("LAT", "LON", "INVYR"), type = "left")
# remove extra columns
fia_absence_joint <- subset(fia_absence_joint, select = -c(species, SPCD))
#lastly change NAs to 0s
fia_absence_joint[which(is.na(fia_absence_joint$dumosa)), "dumosa"] <- 0

presence <- fia_pres[fia_pres$SPCD==rare_oak[4],]
fia_absence_joint$georgiana <- 0

presence <- fia_pres[fia_pres$SPCD==rare_oak[5],]
presence$graciliformis <- 1
fia_absence_joint <- join(fia_absence_joint, presence, by = c("LAT", "LON", "INVYR"), type = "left")
fia_absence_joint <- subset(fia_absence_joint, select = -c(species, SPCD))
fia_absence_joint[which(is.na(fia_absence_joint$graciliformis)), "graciliformis"] <- 0

presence <- fia_pres[fia_pres$SPCD==rare_oak[6],]
fia_absence_joint$havardii <- 0

presence <- fia_pres[fia_pres$SPCD==rare_oak[7],]
presence$laceyi <- 1
fia_absence_joint <- join(fia_absence_joint, presence, by = c("LAT", "LON", "INVYR"), type = "left")
fia_absence_joint <- subset(fia_absence_joint, select = -c(species, SPCD))
fia_absence_joint[which(is.na(fia_absence_joint$laceyi)), "laceyi"] <- 0

presence <- fia_pres[fia_pres$SPCD==rare_oak[8],]
presence$lobata <- 1
fia_absence_joint <- join(fia_absence_joint, presence, by = c("LAT", "LON", "INVYR"), type = "left")
fia_absence_joint <- subset(fia_absence_joint, select = -c(species, SPCD))
fia_absence_joint[which(is.na(fia_absence_joint$lobata)), "lobata"] <- 0

presence <- fia_pres[fia_pres$SPCD==rare_oak[9],]
presence$oglethorpensis <- 1
fia_absence_joint <- join(fia_absence_joint, presence, by = c("LAT", "LON", "INVYR"), type = "left")
fia_absence_joint <- subset(fia_absence_joint, select = -c(species, SPCD))
fia_absence_joint[which(is.na(fia_absence_joint$oglethorpensis)), "oglethorpensis"] <- 0

presence <- fia_pres[fia_pres$SPCD==rare_oak[10],]
fia_absence_joint$robusta <- 0

presence <- fia_pres[fia_pres$SPCD==rare_oak[11],]
presence$similis <- 1
fia_absence_joint <- join(fia_absence_joint, presence, by = c("LAT", "LON", "INVYR"), type = "left")
fia_absence_joint <- subset(fia_absence_joint, select = -c(species, SPCD))
fia_absence_joint[which(is.na(fia_absence_joint$similis)), "similis"] <- 0

presence <- fia_pres[fia_pres$SPCD==rare_oak[12],]
fia_absence_joint$tardifolia <- 0

presence <- fia_pres[fia_pres$SPCD==rare_oak[13],]
fia_absence_joint$toumeyi <- 0

# Now make a new dataframe with this augmented PLOT file with its 13 new columns
write.csv(fia_absence_joint, file=paste0(one_up, "/in-use_occurrence_compiled/fia_absence_compiled.csv"))
