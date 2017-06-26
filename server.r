#setwd("Projects/Toy\ Projects/dispatchr")

library(plumber)

ARGS <- commandArgs(TRUE) 
if(length(ARGS)>0){
    api_fpath <- ARGS[1]
    ARGS <- NULL
} else {
    api_fpath <- "api.r"
}


r <- plumb(api_fpath)

r$run(port=8080)

## Plumber looks like it should be simple for this, but by design it
## actually runs every unique request in a private environment. 
## This is definitely a feature and not a bug, but it's not what I 
## need. Solution is to get fancy with environments in api.r