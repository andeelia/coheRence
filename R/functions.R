#%%SET UP THE BASICS
library(terra)
library(osmdata)
library(sf)
library(tictoc)

library(ggplot2)

 
#%%LOAD AND CLIP DATA
load_and_clip <- function(data_path, target_crs = "EPSG:4326", buildings_path, gpgk_layer, save_clips = FALSE, project_path) {
  
  ####store all relevant data in a list####
  message('Start: Data acquisition and Preparation')
  tic('Data acquisition and Preparation')
  data_list <- list.files(
    path=data_path,
    pattern= '\\.tif$',
    full.names=TRUE
  )
  print(paste0('File loaded:',data_list))
  message(paste0(length(data_list), ' .tif files stored!'))



  ####get meta data from files and correct CRS####
  #create new list for raster entries
  raster_objects <- vector('list', length(data_list))

  for (tif in seq_along(data_list)) {

    #convert entry into a raster object
    dummy_raster <- rast(data_list[[tif]])
  
    #check for CRS compability
    if (is.na(crs(dummy_raster)) || crs(dummy_raster) != crs(target_crs)) {

      dummy_raster <- project(dummy_raster, crs(target_crs))

      message(paste('The CRS of index', tif, 'was succesfully transformed to', target_crs, '!'))
    }

    #metadata validation
    ext_vec <- as.vector(ext(dummy_raster))

    if (any(is.na(ext_vec)) || any(!is.finite(ext_vec))) {

      stop(paste('Missing critical metadata in:', data_files[tif]))
    }

    #write object into new list
    raster_objects[[tif]] <- dummy_raster

    #clear storage for furter processing
    gc()
  }

  message('Data successfully loaded and transformed')
  message('End: Data acquisition and Preparation')
  toc()

  ####prepare building data####
  message('Start: Prepare the building data')
  tic('Prepare the building data')

  building_polygons <- st_read(buildings_path)

  if (is.na(crs(building_polygons)) || crs(building_polygons) != crs(target_crs)) {

      building_polygons <- st_transform(building_polygons, crs(target_crs))

      message(paste('The CRS of all buildings was succesfully transformed to', target_crs, '!'))
    }

  #prepare terra vector
  terra_buildings <- vect(building_polygons)

  message('End: Prepare the building data')
  toc()


  ####clip the rast-objects with the borders and buildings####
  message('Start: Clipping raster with buildings')
  tic('Clipping raster with buildings')

  for (rast in seq_along(raster_objects)) {

    #assign the image to variable
    current_rast <- raster_objects[[rast]]
    
    #crop the raster to the extent
    raster_crop <- crop(current_rast, terra_buildings)

    #mask out non-relevant pixels
    final_mask <- mask(raster_crop, terra_buildings)

    #replace the original raster with the copped one
    raster_objects[[rast]] <- final_mask

    #save .tif if needed
    if (save_clips == TRUE) {
      
      #extract name of the original file
      original_name <- tools::file_path_sans_ext(basename(data_list[[rast]]))

      #define target directory for storing the raster
      target_dir <- file.path(project_path, paste0(original_name, '_clipped.tif'))

      #save the files
      writeRaster(
        final_mask,
        filename = target_dir,
        overwrite=TRUE
      )
      message(paste('Saved at', target_dir))
    } 

    message(paste('Finished clipping index', original_name))
  }
  message('End: Clipping raster with buildings')
  toc()

  return(raster_objects)
}

#%%COHERENCE CALC
coh_calc <- function (rast_files, buildings_path, target_crs) {
  
  ####prepare building data####
  message('Start: Prepare the building data')
  tic('Prepare the building data')

  building_polygons <- st_read(buildings_path)

  if (is.na(crs(building_polygons)) || crs(building_polygons) != crs(target_crs)) {

      building_polygons <- st_transform(building_polygons, crs(target_crs))

      message(paste('The CRS of all buildings was succesfully transformed to', target_crs, '!'))
    }

  #prepare terra vector
  terra_buildings <- vect(building_polygons)

  #convert to single polygons for analysis
  single_buildings <- disagg(terra_buildings)
  print(paste("Number of single polygons:", nrow(single_buildings)))

  message('End: Prepare the building data')
  toc()

  ####pixel analysis####
  message('Start: Coherence analysis per building')
  tic('Coherence analysis per building')

  results_list <- list()

  for (rast in seq_along(rast_files)) {
  
    current_rast <- rast(rast_files[rast])
    
    layer_name <- tools::file_path_sans_ext(basename(rast_files[rast]))
    
    #calculate the mean of each polygon with exact pixel fractions
    coh_stats <- extract(
      current_rast,
      single_buildings,
      fun = function(x) c(count = length(x), mean = mean(x, na.rm = TRUE)),
      exact = TRUE
    ) 
    #remove ID column and name the column
    res_df <- data.frame(stats[, -1])
    colnames(res_df) <- paste0(layer_name, '_mean') 

    #append mini DF to the list 
    results_list[[rast]] <- res_df
  }

  #combine results to original buildings
  all_stats <- do.call(cbind, results_list)
  single_buildings_complete <- cbind(single_buildings, all_stats)

  #mask and filter buildings with no entry
  building_mask <- !is.na(single_buildings_complete[[paste0(layer_name, "_mean")]])
  empty_buildings <- sum(!building_mask)
  message(paste('Number of buildings without any values:', empty_buildings))
  #overwrite single_buildings_complete
  single_buildings_complete <- single_buildings_complete[building_mask, ]

  message('End: Prepare the building data')
  toc()
}


#%%TEST AREA

#define personal variables
path <- '/run/media/andeelia/Volume/B16_Bachelorarbeit/02_Daten/02_Bearbeitete_Daten'
my_crs <- "EPSG:32636" 
region <- 'Gaza'
final_dir <- '/home/andeelia/Documents/GitHub/package_test/'
buildings <- '/run/media/andeelia/Volume/B16_Bachelorarbeit/02_Daten/02_Bearbeitete_Daten/Gaza_Stripe_buildings.shp'

#call function
test <- load_and_clip(data_path=path, target_crs=my_crs, buildings_path = buildings, save_clips = TRUE, project_path = final_dir)

test2 <- coh_calc(rast_files = test, buildings_path = buildings, target_crs =  my_crs)
#%%TRASH 
"""
####get building data####
  message('Start: Get OSM building and data')
  tic('Get OSM building data')
  
  #create BoundingBox based on the reference raster
  ref_raster <- raster_objects[[1]]
  bbox_sf <- st_as_sfc(st_bbox(ref_raster))
  
  #transform BoundingBox to 4326 for OSM-API
  bbox_osm <- st_bbox(st_transform(bbox_sf, 'EPSG:4326'))

  #create query for every building inside the bb
  q_buildings <- opq(bbox_osm, timeout=300) %>%
    add_osm_feature(key = 'building')

  #download data and convert them into sf-objects
  osm_data_buildings <- osmdata_sf(q_buildings)

  if (is.null(osm_data_buildings$osm_polygons)) {
    stop('No building polygons found for this AOI.')
  }

  #create a DF out of them and reproject
  buildings <- osm_data_buildings$osm_polygons
  buildings_utm <- st_transform(buildings, target_crs)

  #convert to a terra vector
  terra_buildings <- vect(buildings_utm)

  #short inspection
  message(paste(nrow(buildings_utm), 'buildings downloaded!'))

  if (save_buildings == TRUE){

    gpkg_path <- file.path(project_path, 'osm_buildings.gpkg')

    writeVector(
      terra_buildings,
      filename = gpkg_path,
      overwrite = TRUE)
    
    message(paste('Builing polygons have been saved at:', gpkg_path))
  }
  
  ##border
#  q_border <- opq(AOI) %>%
#    add_osm_feature(key = 'admin_level', value = '2') #nation borders
#
#  osm_data_border <- osmdata_sf(q_border)
#
#  borders <- osm_data_border$osm_polygons
#  borders_utm <- st_transform(borders, target_crs)

#  message(paste(nrow(borders_utm), 'borders downloaded!'))
#  print(head(borders_utm))

  message('End: Get building data')
  toc()
  """