#%%SET UP THE BASICS
library(terra)
library(osmdata)
library(sf)
library(tictoc)

library(ggplot2)

 
#%%LOAD AND CLIP DATA
load_and_clip <- function(data_path, target_crs = "EPSG:4326", buildings_path, gpgk_layer, save_clips = FALSE, project_path) {
  tic('Global runtime:')
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

  
  #extract extent of raster object
  ref_ext <- ext(raster_objects[[1]])
  #define bounding box
  bbox_polygon <- st_as_sfc(st_bbox(ref_ext, crs = target_crs))
  
  #clip the building polygons with extent
  filtered_buildings <- st_filter(building_polygons, bbox_polygon) 

  #prepare terra vector
  terra_buildings <- vect(filtered_buildings)

  message('End: Prepare the building data')
  toc()


  ####clip the rast-objects with the buildings####
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

  toc()
  return(list(raster_objects = raster_objects, raster_buildings = filtered_buildings))
}



#%%COHERENCE CALC
coh_calc <- function (rast_files, buildings, target_crs, project_path) {
  tic('Global runtime:')
  ####prepare building data####
  message('Start: Prepare the building data')
  tic('Prepare the building data')

  #building_polygons <- st_read(buildings_path)

  #if (is.na(st_crs(building_polygons)) || st_crs(building_polygons) != st_crs(target_crs)) {

  #    building_polygons <- st_transform(building_polygons, st_crs(target_crs))

  #    message(paste('The CRS of all buildings was succesfully transformed to', target_crs, '!'))
  #  }

  #prepare terra vector
  terra_buildings <- vect(buildings)

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

    current_rast <- rast_files[[rast]]
    
    layer_name <- names(current_rast)[1]
    message(paste('Start analysis for', layer_name))
    
    #calculate the mean of each polygon with exact pixel fractions
    coh_stats <- extract(
      current_rast,
      single_buildings,
      #fun = function(x) c(count = length(x), mean = mean(x, na.rm = TRUE)),
      fun = mean,
      na.rm = TRUE,
      exact = TRUE
    ) 
    #remove ID column and name the column
    res_df <- data.frame(coh_stats[, -1])
    colnames(res_df) <- paste0(layer_name, '_mean') 

    #append mini DF to the list 
    results_list[[rast]] <- res_df
  }

  #combine results to original buildings
  all_stats <- do.call(cbind, results_list)
  single_buildings_coh <- cbind(single_buildings, all_stats)

  #mask and filter buildings with no entry
  building_mask <- !is.na(single_buildings_coh[[paste0(layer_name, "_mean")]])
  empty_buildings <- sum(!building_mask)
  message(paste('Number of buildings without any values:', empty_buildings))

  #overwrite single_buildings_complete
  single_buildings_coh <- single_buildings_coh[building_mask, ]

  #save results
  target_dir <- file.path(project_path, 'single_buildings_coh.gpkg')

  writeVector(
    single_buildings_coh,
    target_dir,
    overwrite = TRUE,
  )

  single_buildings_coh_df <- as.data.frame(single_buildings_coh)

  message('End: Coherence analysis per building')
  toc()
  toc()
  return (single_buildings_coh_df)
}


#%%TEST AREA

#define personal variables
path <- '/home/andeelia/Documents/GitHub/package_test/raw_data/'
my_crs <- "EPSG:32636" 
final_dir <- '/home/andeelia/Documents/GitHub/package_test/clipped_data/'
buildings <- '/home/andeelia/Documents/GitHub/package_test/raw_data/Gaza_Stripe_buildings.shp'
clipped_buildings <- test[[2]]
clipped_raster <- test[[1]]


#call function
test <- load_and_clip(data_path=path, target_crs=my_crs, buildings_path = buildings, save_clips = TRUE, project_path = final_dir)

test2 <- coh_calc(rast_files = clipped_raster, buildings = clipped_buildings, target_crs =  my_crs, project_path = final_dir)

