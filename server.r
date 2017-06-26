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
