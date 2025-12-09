/*
 * Filename: c:\Users\joker\Documents\GitHub\coheRence\R\get_product_connection.R
 * Path: c:\Users\joker\Documents\GitHub\coheRence\R
 * Created Date: Tuesday, December 9th 2025, 11:16:52 am
 * Author: Elias
 * 
 * Copyright (c) 2025 Your Company
 */

library(openeo)

#establish a connection to the sentinel data hub
connection <- connect(host = "https://openeofed.dataspace.copernicus.eu")

#login to the copernicus system (opens browser)
login()

#store every process in variable p
p = processes()

#create a datacube with all desired images and an aoi
datacube = p$load_collection(
  id='SENTINEL1_GRD',
  spatial_extent=list(west = 16.06, south = 48.06, east = 16.65, north = 48.35),
  temporal_extent=c("2017-03-01", "2017-04-01"),
  bands=c("VV", "VH")
)

