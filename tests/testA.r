# testA.r

ARGS<-commandArgs(TRUE)

if(length(ARGS)>0){
  
  ARGS_num <- as.numeric(ARGS)
  v = seq(ARGS_num[1], ARGS_num[2])
}