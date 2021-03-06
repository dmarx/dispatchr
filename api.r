#* @get /source_file
source_file <- function(fpath, ...){
  p = parent.env(environment())
  assign("ARGS", c(), envir=p)
  n = length(list(...))
  if(n>2) {
    assign("ARGS", list(...)[3:n], envir=p)
  }
  source(fpath, local=p)
}
