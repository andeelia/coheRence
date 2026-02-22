#%%SET UP THE BASICS
library(terra)
library(osmextract)
library(sf)

#define personal variables
path <- '/run/media/andeelia/Volume/B16_Bachelorarbeit/02_Daten/02_Bearbeitete_Daten'
my_crs <- "EPSG:32636" 
  

#%%CLIP AND GET OSM DATA
clip_and_osm <- function(data_path, project_path, target_crs = "EPSG:4326", save_clips = TRUE) {
  
  ####store all relevant data in a list####
  data_list <- list.files(
    path=data_path,
    pattern= '\\.tif$',
    full.names=TRUE
  )
  message('All .tif files stored!')



  ####get meta data from files and correct CRS####
  raster_objects <- vector('list', length(data_list))
  for (tif in seq_along(data_list)) {

    #convert entry into a raster object
    dummy_raster <- rast(data_list[[tif]])
  
    #check for CRS compability
    if (is.na(crs(dummy_raster)) || crs(dummy_raster) != crs(target_crs)) {

      dummy_raster <- project(dummy_raster, crs(target_crs))

      message(paste('The CRS of index', tif, 'was succesfully transformed to', target_crs, '!'))
    }

    #write object into new list
    raster_objects[[tif]] <- dummy_raster

    #clear storage for furter processing
    gc()

    message(paste('Index', tif, 'successfully converted into a raster object!'))
    

  #feedback
  #check for valid crs
  dummy_crs <- crs(dummy_raster)
  has_crs <- !is.na(dummy_crs) && nchar(dummy_crs) > 0
  
  #check for extent
  dummy_ext <- ext(dummy_raster)
  ext_vec <- as.vector(dummy_ext)
  has_ext <- all(!is.na(ext_vec)) && all(is.finite(ext_vec))

  if (!has_crs) {
    warning('CRS is missing or invalid!')
  } 
  
  if (!has_ext) {
    warning('Spatial extent contains NA or non-finite values!')
  }

  if (has_crs && has_ext) {
    message('Metadata successfully extracted!')
    
    #crs details for the user
    crs_info <- crs(dummy_raster, describe = TRUE)
    cat("  - CRS Name:", crs_info$name, "\n")
    cat("  - EPSG:", crs_info$code, "\n")

    #extent details for the user
    cat("  - Extent (xmin, xmax, ymin, ymax):", paste(round(ext_vec, 2), collapse = ", "), "\n")
  } else {
    stop('Critical metadata missing. Function stopped!')
  }
  }


  ####get building and border data####


  ####clip the .tif with the borders and buildings####
}

#%%TEST AREA
test <- clip_and_osm(data_path=path, target_crs=my_crs)
