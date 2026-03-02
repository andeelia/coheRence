
<!-- README.md is generated from README.Rmd. Please edit that file -->

# coheRence

<!-- badges: start -->

<!-- badges: end -->

The goal of coheRence is to calcuate average coherence values for single
in a region of your choice. It takes pre-made coherence maps and
building polygons, clips the images and calculates an avergae coherence
value per building polygon in order to determine its status. During the
workflow, a classification scheme can be implemented. Also, this package
saves calculated results for the input buildings as .gpkg and plots
colored graphs of the results, in order to get a better overview of the
data provided. The idea behind this kind of analysis is to provide a
fast way to combine coherence loss estimation with build-up areas. It is
especially useful for areas of armed conflicts or after natural
desasters. The saved files from this package can be used for further
spatial analysis regarding damage patterns at one specific time or as a
time series. This package is not capable of downloading data or
processing SAR-scenes!

## Installation

You can install the development version of coheRence from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("andeelia/coheRence")
```

## Workflow

The complete workflow is shown here:

### Load And Clip

The first function takes .tif files from a set path, converts them to a
pre-defined CRS and clips them with building polygons.

``` r
library(coheRence)
library(terra)
library(sf)
library(tictoc)

#define personal variables
path <- '/home/andeelia/Documents/GitHub/package_test/raw_data/'
gaza_crs <- "EPSG:32636" 
final_dir <- '/home/andeelia/Documents/GitHub/package_test/clipped_data/'
buildings <- '/home/andeelia/Documents/GitHub/package_test/raw_data/Gaza_Stripe_buildings.shp'

#call first function to prepare further processing steps
clips <- load_and_clip(data_path = path, target_crs = gaza_crs, buildings_path = buildings, save_clips = TRUE, project_path = final_dir)
#> [1] "File loaded:/home/andeelia/Documents/GitHub/package_test/raw_data//20230930_20231105.tif"
#> [2] "File loaded:/home/andeelia/Documents/GitHub/package_test/raw_data//20230930_20250522.tif"
#> Data acquisition and Preparation: 0.248 sec elapsed
#> Reading layer `Gaza_Stripe_buildings' from data source 
#>   `/home/andeelia/Documents/GitHub/package_test/raw_data/Gaza_Stripe_buildings.shp' 
#>   using driver `ESRI Shapefile'
#> Simple feature collection with 329401 features and 13 fields
#> Geometry type: MULTIPOLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 34.22009 ymin: 31.22144 xmax: 34.56517 ymax: 31.58946
#> Geodetic CRS:  WGS 84
#> Prepare the building data: 18.92 sec elapsed
#> Clipping raster with buildings: 0.415 sec elapsed
#> Global runtime:: 19.583 sec elapsed
```

The result of this function is a list consisting of three things.

- A list of SpatRaster objects, clipped to the building outlines

``` r
plot(clips[[1]][[1]])
```

<img src="man/figures/README-clips1-1.png" alt="" width="100%" />

- A spatial DataFrame including the buildings clipped to the extent of
  the input images

``` r
head(clips[[2]])
#> Simple feature collection with 6 features and 13 fields
#> Geometry type: MULTIPOLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 639270.6 ymin: 3488704 xmax: 641066 ymax: 3490583
#> Projected CRS: WGS 84 / UTM zone 36N
#>     osm_id code   fclass                            name   type
#> 1 41243116 1500 building             Khaled Ben Alwaleed   <NA>
#> 2 41243192 1500 building                    مسجد الزهراء   <NA>
#> 3 41243835 1500 building                Nama Club Sports   <NA>
#> 4 41244014 1500 building             Palestinian Telecom public
#> 5 41244046 1500 building         Jabbalia Sewerage plant   <NA>
#> 6 41244173 1500 building Youth House for Culture and Art public
#>                    ADM0_EN ADM0_PCODE       date    validOn validTo Shape_Leng
#> 1 State of Palestine (the)         PS 2021-03-18 2023-10-19    <NA>   6.006026
#> 2 State of Palestine (the)         PS 2021-03-18 2023-10-19    <NA>   6.006026
#> 3 State of Palestine (the)         PS 2021-03-18 2023-10-19    <NA>   6.006026
#> 4 State of Palestine (the)         PS 2021-03-18 2023-10-19    <NA>   6.006026
#> 5 State of Palestine (the)         PS 2021-03-18 2023-10-19    <NA>   6.006026
#> 6 State of Palestine (the)         PS 2021-03-18 2023-10-19    <NA>   6.006026
#>   Shape_Area AREA_SQKM                       geometry
#> 1   0.574021   6019.62 MULTIPOLYGON (((640506.1 34...
#> 2   0.574021   6019.62 MULTIPOLYGON (((640978 3490...
#> 3   0.574021   6019.62 MULTIPOLYGON (((641032.8 34...
#> 4   0.574021   6019.62 MULTIPOLYGON (((639280.2 34...
#> 5   0.574021   6019.62 MULTIPOLYGON (((640903.9 34...
#> 6   0.574021   6019.62 MULTIPOLYGON (((640905.2 34...
```

- A numerical value, representing the number of input images

``` r
print(clips[[3]])
#> [1] 2
```

### Coherence Calculation

By assigning the results from `load_and_clip()` to variables, they can
be used in the following function:

``` r
library(coheRence)
library(terra)
library(sf)
library(tictoc)

#assign results from load_andclip
clipped_raster <- clips[[1]]
clipped_buildings <- clips[[2]]

#call second function to analyse your dataset
coh_results <- coh_calc(rast_data = clipped_raster, buildings = clipped_buildings, target_crs =  gaza_crs, project_path = final_dir)
#> Prepare the building data: 0.781 sec elapsed
#> Coherence analysis per building: 72.746 sec elapsed
#> Global runtime:: 73.528 sec elapsed
```

The result of this function looks like this:

``` r
head(coh_results)
#>     osm_id code   fclass                            name   type
#> 1 41243116 1500 building             Khaled Ben Alwaleed   <NA>
#> 2 41243192 1500 building                    مسجد الزهراء   <NA>
#> 3 41243835 1500 building                Nama Club Sports   <NA>
#> 4 41244014 1500 building             Palestinian Telecom public
#> 5 41244046 1500 building         Jabbalia Sewerage plant   <NA>
#> 6 41244173 1500 building Youth House for Culture and Art public
#>                    ADM0_EN ADM0_PCODE       date    validOn validTo Shape_Leng
#> 1 State of Palestine (the)         PS 2021-03-18 2023-10-19    <NA>   6.006026
#> 2 State of Palestine (the)         PS 2021-03-18 2023-10-19    <NA>   6.006026
#> 3 State of Palestine (the)         PS 2021-03-18 2023-10-19    <NA>   6.006026
#> 4 State of Palestine (the)         PS 2021-03-18 2023-10-19    <NA>   6.006026
#> 5 State of Palestine (the)         PS 2021-03-18 2023-10-19    <NA>   6.006026
#> 6 State of Palestine (the)         PS 2021-03-18 2023-10-19    <NA>   6.006026
#>   Shape_Area AREA_SQKM 20230930_20231105_mean 20230930_20250522_mean
#> 1   0.574021   6019.62              0.7367099              0.2239051
#> 2   0.574021   6019.62              0.2626309              0.1523930
#> 3   0.574021   6019.62              0.4664691              0.5022483
#> 4   0.574021   6019.62              0.3970907              0.4064044
#> 5   0.574021   6019.62              0.4689693              0.4139251
#> 6   0.574021   6019.62              0.5520670              0.2226530
```

### Classified Plots

As you can see, the calculated results are added to the end of the DF.
Finally, two plots will be created by calling classified plots:

``` r
library(coheRence)
library(tictoc)
library(ggplot2)
library(dplyr)
library(tidyr)
library(scales)
library(patchwork)

#assign result from load_and_clip
image_count <- clips[[3]]

#call function to plot graphs
classified_plots(coh_df = coh_results, number_of_images = image_count, project_path = final_dir)
#> Preparing the DF: 0.003 sec elapsed
#> Plot bar chart: 0.376 sec elapsed
#> Plot line charts: 0.388 sec elapsed
#> Global runtime:: 0.699 sec elapsed
#> 1.468 sec elapsed
```

<img src="man/figures/README-plots-1.png" alt="" width="100%" /><img src="man/figures/README-plots-2.png" alt="" width="100%" />
