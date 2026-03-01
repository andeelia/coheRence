#%%SET UP THE BASICS
library(terra)
library(sf)
library(tictoc)
library(ggplot2)
library(dplyr)
library(tidyr)
library(scales)
library(patchwork)

 
#%%LOAD AND CLIP DATA
#' Load and clip .tif files with building polygons.
#' 
#' This function takes .tif files and converts them to a specified CRS defined by the user, if necessary. The function checks for an extent as well to exclude faulty  
#' images. Buiding polygons are read in and transformed to the same CRS. The raster's extent is used to clip the extent od the buildings. After that, the polygons are used to clip
#' the raster itself. The function stores and returns the clipped .tif files, the clipped buildings and returns the number of images loaded.
#' 
#' @param data_path Path to the raw data containing coherence maps in .tif format.
#' @param target_crs User defined CRS as 'EPSG:123456'. Default is EPSG:4326.
#' @param buildings_path Path to the raw builing vector file.
#' @param save_clips Set to TRUE or FALSE, if the results should be saved. Default is TRUE.
#' @param project_path Path for saved results.
#' 
#' @return List of SpatRaster objects
#' @return DataFrame with all clipped buildings
#' @return Single numerical value representing the number of images
#' 
#' @examples
#' raw_path <- '[...]/GitHub/package_test/raw_data/'
#' gaza_crs <- 'EPSG:32636' 
#' final_dir <- '[...]/GitHub/package_test/clipped_data/'
#' gaza_buildings <- '[...]/GitHub/package_test/raw_data/Gaza_Stripe_buildings.shp'
#' 
#' clips <- load_and_clip(data_path = path, target_crs = gaza_crs, buildings_path = gaza_buildings, save_clips = TRUE, project_path = final_dir)
#' 
#'  
#' @export
load_and_clip <- function(data_path, target_crs = "EPSG:4326", buildings_path, save_clips = FALSE, project_path) {
  tic('Global runtime:')

  ####store all relevant data in a list####
  message('Start: Data acquisition and Preparation')
  tic('Data acquisition and Preparation')
  data_list <- list.files(
    path=data_path,
    pattern= '\\.tif$',
    full.names=TRUE
  )

  data_list <- sort(data_list, decreasing = FALSE)
  product_count <- length(data_list)
  
  print(paste0('File loaded:',data_list))
  message(paste0(length(data_list), ' .tif files stored!'))


  ####get meta data from files and correct CRS####
  #create new list for raster entries
  raster_objects <- vector('list', length(data_list))

  for (tif in seq_along(data_list)) {

    #convert entry into a raster object
    dummy_raster <- terra::rast(data_list[[tif]])
  
    #check for CRS compability
    if (is.na(terra::crs(dummy_raster)) || terra::crs(dummy_raster) != terra::crs(target_crs)) {

      dummy_raster <- terra::project(dummy_raster, terra::crs(target_crs))

      message(paste('The CRS of index', tif, 'was succesfully transformed to', target_crs, '!'))
    }

    #metadata validation
    ext_vec <- as.vector(terra::ext(dummy_raster))

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

  building_polygons <- sf::st_read(buildings_path)

  if (is.na(sf::st_crs(building_polygons)) || sf::st_crs(building_polygons) != sf::st_crs(target_crs)) {

      building_polygons <- sf::st_transform(building_polygons, sf::st_crs(target_crs))

      message(paste('The CRS of all buildings was succesfully transformed to', target_crs, '!'))
    }

  
  #extract extent of raster object
  ref_ext <- terra::ext(raster_objects[[1]])
  #define bounding box
  bbox_polygon <- sf::st_as_sfc(sf::st_bbox(ref_ext, crs = target_crs))
  
  #clip the building polygons with extent
  filtered_buildings <- sf::st_filter(building_polygons, bbox_polygon) 

  #prepare terra vector
  terra_buildings <- terra::vect(filtered_buildings)

  message('End: Prepare the building data')
  toc()


  ####clip the rast-objects with the buildings####
  message('Start: Clipping raster with buildings')
  tic('Clipping raster with buildings')

  for (rast in seq_along(raster_objects)) {

    #assign the image to variable
    current_rast <- raster_objects[[rast]]
    
    #crop the raster to the extent
    raster_crop <- terra::crop(current_rast, terra_buildings)

    #mask out non-relevant pixels
    final_mask <- terra::mask(raster_crop, terra_buildings)

    #replace the original raster with the copped one
    raster_objects[[rast]] <- final_mask

    #save .tif if needed
    if (save_clips == TRUE) {
      
      #extract name of the original file
      original_name <- tools::file_path_sans_ext(basename(data_list[[rast]]))

      #define target directory for storing the raster
      target_dir <- file.path(project_path, paste0(original_name, '_clipped.tif'))

      #save the files
      terra::writeRaster(
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
  return(list(raster_objects = raster_objects, raster_buildings = filtered_buildings, img_count = product_count))
}



#%%COHERENCE CALC
#' Calculate the avergae coherence value per buildings polygon.
#' 
#' This function overlays given raster objects with the building polygons and calculates an average coherence value per polygon.
#' Results are added to the building DF and saved as .gpkg.
#' 
#' 
#' 
#' @param rast_data List of SpatRaster data.
#' @param buildings Dataframe containing building geometries.
#' @param target_crs User defined CRS as 'EPSG:123456'. Default is EPSG:4326.
#' @param project_path Path for saved results.
#' 
#' @return Single DataFrame containing calculated coherence values appended to the original DF.
#' 
#' @examples
#' gaza_crs <- 'EPSG:32636' 
#' final_dir <- '[...]/GitHub/package_test/clipped_data/'
#' 
#' clipped_raster <- clips[[1]]
#' clipped_buildings <- clips[[2]]
#' 
#' coh_results <- coh_calc(rast_data = clipped_raster, buildings = clipped_buildings, target_crs = gaza_crs, project_path = final_dir)
#' 
#' @export
coh_calc <- function (rast_data, buildings, target_crs = 'EPSG:4326', project_path) {
  tic('Global runtime:')
  ####prepare building data####
  message('Start: Prepare the building data')
  tic('Prepare the building data')

  #prepare terra vector
  terra_buildings <- terra::vect(buildings)

  #convert to single polygons for analysis
  single_buildings <- terra::disagg(terra_buildings)
  print(paste("Number of single polygons:", nrow(single_buildings)))

  message('End: Prepare the building data')
  toc()

  ####pixel analysis####
  message('Start: Coherence analysis per building')
  tic('Coherence analysis per building')

  results_list <- list()

  for (rast in seq_along(rast_data)) {

    current_rast <- rast_data[[rast]]
    
    layer_name <- names(current_rast)[1]
    message(paste('Start analysis for', layer_name))
    
    #calculate the mean of each polygon with exact pixel fractions
    coh_stats <- terra::extract(
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

  ####save results####
  target_dir <- file.path(project_path, 'single_buildings_coh.gpkg')

  terra::writeVector(
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


#%%PLOTTING
#' Plot the results
#' 
#' This function takes a DataFrame containing all calculated results and removes all columns except the results. All results are classified with a given classification scheme.
#' After that, a bar plot is created, showing the structure of classified buildings in relation to 100 %. A line plot is created to show the absolute numbers of classified buildings.
#' Both plots plot the development over time as every column is plotted. The plots are saved as .png in one image.
#' 
#' @param coh_df DataFrame containing the results in the last columns.  It is expected to have as many result columns as images to analyse.
#' @param classification_list A vector of five entries defining the classification boundaries. Set the lowest boundary at first. Default is c(0.2, 0.4, 0.6, 0.8, 1).
#' @param number_of_images A numerical value representing the number of input images.
#' @param project_path Path for saved results.
#' 
#' @return //
#' 
#' @examples
#' image_count <- clips[[3]]
#' final_dir <- '[...]/GitHub/package_test/clipped_data/'
#' 
#' classified_plots(coh_df = coh_results, number_of_images = image_count, project_path = final_dir)
#' 
#' @export
classified_plots <- function (coh_df, classification_list = c(0.2, 0.4, 0.6, 0.8, 1), number_of_images, project_path){
  tic('Global runtime:')

  ####preparations####
  message('Start: Preparing the DF')
  tic('Preparing the DF')

  cols <- ncol(coh_df)
  short_df <- coh_df[, (cols-(number_of_images-1)):cols]

  classified_df <- short_df

  ####classifiying the image values####
  for (col_name in colnames(short_df)){
    classified_df[[col_name]] <- dplyr::case_when(
      short_df[[col_name]] <= classification_list[1] ~ 'Destroyed',
      short_df[[col_name]] <= classification_list[2] ~ 'Severe Damages',
      short_df[[col_name]] <= classification_list[3] ~ 'Major Damages',
      short_df[[col_name]] <= classification_list[4] ~ 'Minor Damages',
      TRUE                                           ~ 'Intact'
      )
  }

  message('End: Preparing the DF')
  toc()

  ####bar plot####
  message('Start: Plot bar chart')
  tic('Plot bar chart')

  #transform DF for plotting
  df_plot_data <- classified_df %>%
  tidyr::pivot_longer(
    cols = everything(), 
    names_to = "timestamp", 
    values_to = "damage_class"
  ) %>% dplyr::mutate(damage_class = factor(damage_class, 
                                levels = c("Destroyed", "Severe Damages", "Major Damages", "Minor Damages", "Intact")))

  
  #aggregate values to show labels
  df_plot_data_aggr <- df_plot_data %>%
  dplyr::group_by(timestamp, damage_class) %>%
  dplyr::summarise(n = n(), .groups = "drop_last") %>%
  dplyr::mutate(pct = n / sum(n))

  #create bar plot object
  bar <- ggplot(df_plot_data_aggr, aes(x = timestamp, y = pct, fill = damage_class)) +
    #geom_col to access pre calculated values from y=pct
    geom_col(position = "fill") +
    
    #create data label
    geom_text(
      aes(label = scales::label_percent(accuracy = 0.1)(pct)),
      position = position_stack(vjust = 0.5),
      size = 3.5,
      color = "black",
      fontface = "bold"
    ) +
    
    #colors and legend
    scale_fill_manual(values = c(
      "Destroyed" = "#A50026", "Severe Damages" = "#ee702cff", 
      "Major Damages" = "#dbd820ff", "Minor Damages" = "#6dca43ff", "Intact" = "#006837"
    )) +
    
    #axis and label
    scale_y_continuous(labels = label_percent()) + 
    labs(
      title = 'Relative number of affected buildings',
      y = "Percentage", 
      x = "Timestamp", 
      fill = "Damage Class"
    ) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  print(bar)

  message('End: Plot bar chart')
  toc()

  ####line plot####
  message('Start: Plot line chart')
  tic('Plot line charts')

  #aggregate data line plot
  df_counts <- df_plot_data %>%
    dplyr::group_by(timestamp, damage_class) %>%
    dplyr::summarise(count = n(), .groups = 'drop')


  line <- ggplot(df_counts, aes(x = timestamp, y = count, color = damage_class, group = damage_class)) +
    #data lines and data points
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    
    #label
    geom_text(
      aes(label = count),
      vjust = -1,            
      size = 3.5,
      show.legend = FALSE  
    ) +
    
    #colors
    scale_color_manual(values = c(
      "Destroyed" = "#A50026", "Severe Damages" = "#ee702cff", 
      "Major Damages" = "#dbd820ff", "Minor Damages" = "#6dca43ff", "Intact" = "#006837"
    )) +
    
    #axis
    expand_limits(y = max(df_counts$count) * 1.1) +
    labs(
      title = "Absolute number of affected buildings", 
      y = "Number of buildings", 
      x = "Timestamp", 
      color = "Damage Class"
    ) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  print(line)

  message('End: Plot line chart')
  toc()

  message('Start: Save plots')
  tic()

  ####save plots as one image####
  combined_plots <- bar / line

  ggsave(
    filename = paste0(project_path, '/combined_damage_analysis.png'),
    plot = combined_plots,
    width = 10,
    height = 12,
    dpi = 300,
    bg = 'white'
  )

  message('End: Save plots')
  toc()
  toc()
}
