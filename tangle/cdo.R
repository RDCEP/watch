
watchVars <- c(
  precip= "pr_gpcc",
  solar=  "rsds",
  tmax=   "tasmax",
  tmin=   "tasmin")

library( stringr)
library( doMC)
registerDoMC( 4)

watchVars <- c(
  precip= "pr_gpcc",
  solar=  "rsds",
  tmax=   "tasmax",
  tmin=   "tasmin")

watchInput <-
  list.files(
    path= "data/input",
    pattern= sprintf(
      "^(%s)",
      paste( watchVars, collapse= "|")),
    full.names= TRUE)

cdoCommands <-
  sprintf(
    paste(
      "cdo -O -f nc4 -z zip splityear %s",
      "data/output/%s_watch_",
      "2>&1"),
    watchInput,
    str_match( watchInput, "data/input/([a-z]+_?[a-z]*)_watch")[,2])

annualFiles <-
  list.files(
    path= "data/output",
    pattern= "^.+_watch_[0-9]{4}.nc4$",
    full.names= TRUE)

annualFiles30min <-
  str_replace( annualFiles, "\\.nc4$", "_30min.nc4")

cdoRemapCommands <-
  paste(
    "cdo -O -f nc4 -z zip remapnn,global_30min.grid",
    annualFiles,
    annualFiles30min,
    "2>&1")

## watchVars)
## names( cdoCommands) <- watchVars

head( cdoCommands)

head( cdoRemapCommands)

cdoOutput <- 
  foreach( cdo= cdoCommands) %dopar% {
    system( cdo, intern= TRUE)
  }

cdoOutput <- 
  foreach( cdo= cdoRemapCommands) %dopar% {
    system( cdo, intern= TRUE)
  }

cdoOutput
