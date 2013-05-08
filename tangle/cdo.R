
watchVars <- c(
  precip= "pr_gpcc",
  solar=  "rsds",
  tmax=   "tasmax",
  tmin=   "tasmin")

library( doMC)
registerDoMC( 4)

watchVars <- c(
  precip= "pr_gpcc",
  solar=  "rsds",
  tmax=   "tasmax",
  tmin=   "tasmin")

cdoCommands <-
  sprintf(
    paste(
      "cdo -O -f nc4 -z zip mergetime",
      "data/input/%1$s_watch_*",
      "data/output/%1$s_watch_1958-2001.nc4 &&",
      "cdo -O -f nc4 -z zip remapnn,global_30min.grid",
      "data/output/%1$s_watch_1958-2001.nc4",
      "data/output/%1$s_watch_1958-2001_30min.nc4",
      "2>&1"),
    watchVars)
names( cdoCommands) <- watchVars

cdoCommands

cdoOutput <- 
  foreach( cdo= cdoCommands) %dopar% {
    system( cdo, intern= TRUE)
  }
names( cdoOutput) <- watchVars

cdoOutput
