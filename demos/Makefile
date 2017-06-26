## Move this file to the root folder for the repository (up one level) to 
## run the demonstration.

R_INTERPRETER=Rscript ./dispatch.r

start_server:
	Rscript ./server.r ./api.r &

demo: demos/model.rdata

demos/iris.rdata: demos/read_data.r
	$(R_INTERPRETER) commands/flush.r
	$(R_INTERPRETER) $<

demos/iris_t.rdata: demos/make_target.r demos/iris.rdata
	$(R_INTERPRETER) $<

demos/model.rdata: demos/fit_model.r demos/iris_t.rdata
	$(R_INTERPRETER) $<