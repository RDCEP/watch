#!/home/nbest/local/bin/r

## --interactive

stripe <- as.integer( argv[ 1])
years <- 1958:2001

library( ncdf4)
library( raster)
library( abind)
library( ascii)
options( asciiType= "org")

library( doMC)  
registerDoMC( multicore:::detectCores())

## options( error= recover)

watchVars <- c(
  precip= "pr_gpcc",
  solar=  "rsds",
  tmax=   "tasmax",
  tmin=   "tasmin")
## watchVars[ "precip"] <- "pr" 
ascii( as.list( watchVars), list.type= "label")

## function getNcByVarYear( var, year)
## computes file name of input netCDF file by variable name and year
## and opens it

## getNcByVarYear <- function( var, year) {
##   ncFn <- sprintf( "data/nc/%1$s/%1$s_%2$d.nc", var, year)
##   list( nc_open( ncFn))
## }

watchMask <- setMinMax(
  raster( "data/output/watchMask30min.tif"))
  
watchAnchorPoints <- {
  watchRes <- res( watchMask)[ 1]
  cbind(
    lon= seq(
      from= xmin( watchMask) + watchRes / 2,
      to= xmax( watchMask) - watchRes / 2,
      by= 3), 
    lat= ymax( watchMask))
}

readWatchValues <- function(  xy, var= "tmin", year= 1958, n= 6) {
  ncFn <- sprintf( "data/output/%s_watch_%s_30min.nc4", watchVars[ var], year)
  nc <- nc_open( ncFn)
  ## r <- raster( ncFn, band= 1)
  ## r <- raster( watchMask)
  column <-
    rowColFromCell(
      watchMask, cellFromXY(
        watchMask, xy= xy))[ 2]
  m <-
    ncvar_get(
      nc,
      varid= names( nc$var),
      start= c( column, 1, 1),
      count= c( n, -1, -1),             # collapse_degen seems to have
      collapse_degen= FALSE)            # no effect
  watchDays <-
    ncvar_get(
      nc,
      varid= "time",
      start= 1,
      count= -1)
  dn <- list(
    longitude= nc$dim$lon$vals[ column:(column +n -1)],
    latitude=  nc$dim$lat$vals[],
    time= watchDays)
  if( length( dim( m)) == 2)
    dim(m) <- c( 1, dim(m))             # to compensate for apparent
  dimnames( m) <- dn                    # collapse_degen bug
  m
}

## cat( sprintf( "Time to load data for stripe %d:", stripe))

## system.time( {

watchValues <-
  foreach(
    var= names( watchVars)) %:%
  ## var= "tmin",
  ## .inorder= TRUE) %:%
  foreach(
    year= years,
    .combine= abind,
    .multicombine= TRUE ) %dopar% {
      readWatchValues( watchAnchorPoints[ stripe,], var= var, year= year)
    }
names( watchValues) <- names( watchVars)
for( var in names( watchVars))
  names( dimnames( watchValues[[ var]])) <-
  c( "longitude", "latitude", "time")

## })

ncDimsFunc <- function(
  xy, ncDays,
  ncTimeName= "narr/time",
  ncTimeUnits= "days since 1978-12-31 00:00:00") {
  list(
    ncdim_def(
      name= "longitude",
      units= "degrees_east",
      vals= xy[[ "lon"]]),
    ncdim_def(
      name= "latitude",
      units= "degrees_north",
      vals= xy[[ "lat"]]),
    ncdim_def(
      name= ncTimeName,
      units= ncTimeUnits,
      vals= ncDays,
      unlim= TRUE))
}

ncVarsFunc <- function(
  xy, ncDays,
  ncGroupName= "narr",
  ncTimeUnits= "days since 1978-12-31 00:00:00",
  compression= 5) {
  list(
    ncvar_def(
      name= sprintf( "%s/tmin", ncGroupName),
      units= "C",
      longname= "daily minimum temperature",
      dim= ncDimsFunc( xy, ncDays,
        ncTimeUnits,
        ncTimeName= sprintf( "%s/time", ncGroupName)),
      compression= compression),
    ncvar_def(
      name= sprintf( "%s/tmax", ncGroupName),
      units= "C",
      longname= "daily maximum temperature",
      dim= ncDimsFunc( xy, ncDays,
        ncTimeUnits,
        ncTimeName= sprintf( "%s/time", ncGroupName)),
      compression= compression),
    ncvar_def(
      name= sprintf( "%s/precip", ncGroupName),
      units= "mm",
      longname= "daily total precipitation",
      dim= ncDimsFunc( xy, ncDays,
        ncTimeUnits,
        ncTimeName= sprintf( "%s/time", ncGroupName)),
      compression= compression),
    ncvar_def(
      name= sprintf( "%s/solar", ncGroupName),
      units= "MJ/m^2/day",
      longname= "daily average downward short-wave radiation flux",
      dim= ncDimsFunc( xy, ncDays,
        ncTimeUnits,
        ncTimeName= sprintf( "%s/time", ncGroupName)),            
      compression= compression))
}

psimsNcFromXY <- function(
  xy, ncDays,
  resWorld= 0.5,
  ncTimeUnits= "days since 1860-01-01 00:00:00") {
  if( xy[[ "lon"]] > 180) {
    xy[[ "lon"]] <- xy[[ "lon"]] - 360
  }
  world <- raster()
  res( world) <- resWorld
  rowCol <- as.list( rowColFromCell( world, cellFromXY( world, xy))[1,])
  ncFile <- sprintf( "data/psims/%1$03d/%2$03d/%1$03d_%2$03d.psims.nc4", rowCol$row, rowCol$col)
  if( !file.exists( dirname( ncFile))) {
    dir.create( path= dirname( ncFile), recursive= TRUE)
  }
  if( file.exists( ncFile)) file.remove( ncFile)
  nc_create(
    filename= ncFile,
    vars= ncVarsFunc( xy, ncDays, 
      ncGroupName= "watch",
      ncTimeUnits= ncTimeUnits),
    force_v4= TRUE,
    verbose= FALSE)
}

writePsimsNc <- function( watchValues, col, row) {
  xy <- c(
    lon= as.numeric( dimnames( watchValues[[ "tmin"]])$longitude[ col]),
    lat= as.numeric( dimnames( watchValues[[ "tmin"]])$latitude[  row]))
  if( is.na( extract( watchMask, rbind( xy)))) return( NA)
  psimsNc <- psimsNcFromXY(
    xy, ncDays= as.integer( dimnames( watchValues[[ "tmin"]])$time))
  for( var in names( watchValues)) {
    vals <- watchValues[[ var]][ col, row,]
    vals <- switch( var,
        solar= vals *86400 /1000000, # Change units to MJ /m^2 /day
        tmin= vals -273.15,          # change K to C
        tmax= vals -273.15,
        precip= vals *3600 *24)      # Change mm/s to mm/day
    ## browser()
    ncvar_put(
      nc= psimsNc,
      varid= sprintf( "watch/%s", var),
      vals= vals,
      count= c( 1, 1, -1))
  }
  nc_close( psimsNc)
  psimsNc$filename
}

## time <-
##   system.time(

psimsNcFile <-
  foreach( col= 1:6, .combine= c) %:%
  foreach( row= 1:254, .combine= c) %dopar% {
    writePsimsNc( watchValues, col, row)
  }

##   )

cat(
  psimsNcFile,
  ## sprintf( "\n\nTime to write %d files:", length( psimsNcFile)),
  sep= "\n")

## print( time)
