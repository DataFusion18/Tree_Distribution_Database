############ 4. extract species from raw data frame
########### 2.27.18 Elizabeth Tokarz
###########
###########
###########   rework this--is this step necssary?
###########


############### INPUT: raw "occur_all" data csv (a large file holding all the data we could
#               possibly need for our 28 species; including location, source, climatic variables)
#
#     package: dplyr
#
#     ############### OUTPUT: edited species-specific csv at three levels of certainty 
#                     (a smaller file containing all occurrence data necessary 
#                     for our model, having removed unreasonable occurrence 
#                     outliers)
#
#                     1. County-level
#                     2. All given and localized coordinates, including less reliable sources
#                     3. Given and localized coordinates from reliable sources


# setwd("C:/Users/Elizabeth/Desktop/2017_CTS_fellowship/compilation_eb")
# raw <- read.csv("raw_data_temp_0218.csv")

raw <- read.csv("../data/raw_data_temp_0218.csv")
#raw <- read.csv("gbif_arkansana_inopina.csv")

## a. Read in occurrence point file -IF- you've added coordinates for species with locality info but no given lat/long
occur_all <- read.csv(file='./Google Drive/Distributions_TreeSpecies/in-use_occurrence_raw/standard_col/datasets_combined/occurrence_raw_compiled_edit.csv', as.is=T)
# windows
# occur_all <- read.csv(file='G:/My Drive/Distributions_TreeSpecies/in-use_occurrence_raw/standard_col/datasets_combined/occurrence_raw_compiled_edit.csv', as.is=T)

library(dplyr)

# First we will sort through the data at the county level.
county <- filter(raw, gps_determ=="C")

#group_by(county, species_no)
# Now we will use county to get the county occurrences for each species

# First filter the county occurrences only
ark1 <- filter(county, species_no==3)
ino1 <- filter(county, species_no==15)

# Then use this function to compile a list of unique counties and the coordinates of each
extract_county_one  <- function(d.f){
    d.f_coord <- data.frame()
    sta <- unique(d.f$state)
    
    for (st in (1:length(sta))){
      cou <- unique(d.f[d.f$state==sta[st],]$county)
      
      for (co in (1:length(cou))){
      vec <- which(d.f$state==sta[st] & d.f$county==cou[co])
      
      d.f_coord <- rbind(d.f_coord, d.f[vec[1],c("state", "county", "lat", "long")])
    
      }
    }
    print(d.f_coord)
  }

ark1_coord <- extract_county_one(ark1)
write.csv(ark1_coord, "ark1_coord.csv")

ino1_coord <- extract_county_one(ino1)
write.csv(ino1_coord, "ino1_coord.csv")

#################################################################################
# Second we keep only the given and localized coordinates.
#################################################################################

# First filter the localized occurrences only
local <- filter(raw, gps_determ=="L"|gps_determ=="G")



ark2 <- filter(local, species_no==3)
ino2 <- filter(local, species_no==15)

# now write a function to do the following

extract_localized_two <- function(d.f){
  # remove unecessary columns
  d.f_holder <- select(d.f, �..dataset, species, state, county, lat, long, basis, year, locality,
                 source, gps_determ, uncertainty..m., issue)
  # filter out non-numeric coordinates
  d.f_holder$lat <- as.numeric(as.character(d.f_holder$lat))
  d.f_holder$long <- as.numeric(as.character(d.f_holder$long))
  d.f_holder <- filter(d.f_holder, lat > 0 & long < 0)
  # check for duplicates to 2 decimal places
  d.f_holder <- d.f_holder[!duplicated(round(d.f_holder[,c("lat","long")], 2)), ]
  print(d.f_holder)
}

ark2 <- extract_localized_two(ark2)
ino2 <- extract_localized_two(ino2)

# now we are ready to write the csvs with the following function
write_loc2_csv <- function(d.f, name){
  d.f.w <- select(d.f, state, county, lat, long, gps_determ)
  write.csv(d.f.w, name)
}

write_loc2_csv(ark2, "ark2_coord.csv")
write_loc2_csv(ino2, "ino2_coord.csv")


#################################################################################
# Third we look at the occurrence data from step 2 more closely and remove less reliable points
#################################################################################

# First give these objects that we will manipulate a new identity

ark3 <- ark2
ino3 <- ino2

# change data into types of information we want
str(ark3)
ark3$year <- as.numeric(ark3$year)
ark3$locality <- as.character(ark3$locality)
ark3$uncertainty..m. <- as.numeric(ark3$uncertainty..m.)

summary(ark3$species)

