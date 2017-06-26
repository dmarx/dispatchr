
# Theoretically I should be able to just do this with curl, but I'm having issues
# getting curl to work properly in cygwin, so let's just use R instead.

suppressWarnings(library(httr))

ARGS <- commandArgs(TRUE) 

n = length(ARGS)
payload = lapply(ARGS, c)
names(payload)[1] = "fpath"
if(n>1) names(payload)[2:n] = "arg"

outv = GET("http://127.0.0.1:8080/source_file",
    query = payload
    )
