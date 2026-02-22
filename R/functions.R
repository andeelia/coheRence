library(terra)
library(osmextract)
library(sf)


path <- '/run/media/andeelia/Volume/B16_Bachelorarbeit/02_Daten/02_Bearbeitete_Daten'
  
  
#%%CLIP AND GET OSM DATA
clip_and_osm <- function(custom_path) {
  
  #store all relevant data in a list
  data_list <- list.files(
    path=custom_path,
    pattern= '\\.tif$',
    full.names=TRUE
  )

  #get meta data from a file
  dummy_raster <- rast(data_list[1])
  dummy_crs <- crs(dummy_raster)
  dummy_ext <- ext(dummy_raster)
    
}

test <- clip_and_osm(path)
