print ("TEST1")

if(!exists("ARGS")) ARGS <- commandArgs(TRUE)

if(length(ARGS)>0){
  print("args detected")
  ARGS <- as.numeric(ARGS)
  v <- seq(ARGS[1], ARGS[2])
}

print ("/TEST1")
