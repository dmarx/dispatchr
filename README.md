# dipatchr

Run R scripts from the command line in a persisted environment.

## Requirements

* [plumber](https://github.com/trestletech/plumber)

## Basic usage

Start the backend server:

    $ Rscript server.r &

Run script1.r. Then run script2.r in the same environment as script1.r, and pass the script some positional arguments:

    $ Rscript dispatch.r path/to/script1.r
    $ Rscript dispatch.r path/to/script2.r arg1 arg2

Kill the server to cleanup:

    $ kill $(ps -f | grep Rscript | awk 'NR==1{print $2}')

## The problem

Sometimes loading things into the environment is expensive. If we have a large data object that we are manipulating across a series of scripts, saving the object to disk and then re-loading it in between every operation can significantly impact the overall processing time of the sequence. To get around this unnecessary overhead, it's not uncommon to wrap the entire sequence into a single script which runs the entire sequence from back to front. This is fine if all of the steps in the sequence need to be run, but if we only need to run some portion of the sequence (e.g. some data was updated or a script was changed, and we only need to refresh the objects from the middle of the sequence down) we need to add a significant amount of complexity to the pipeline script, or bite the bullet and just run the whole sequence. If we go with the latter option, we may ultimately be dealing with a longer processing time than if we had simply used something like Gnu Make to build our pipeline to begin with.

## The solution

Using `dispatchr`, you can pass the large object from step to step as though you were sourcing the scripts in an interactive R session, and only load necessary objects from disk if they weren't passed along from an earlier step in the sequence. This allows us to utilize intelligent pipelining tools like Gnu Make, while not having to worry about the additional i/o overhead that is normally associated with batch processing.

## Detailed example

### The problem

Consider the following R script, which prints out a sequence of values if a start and end for the sequence are provided via the commandline:
    
    # tests/test.r
    
    ARGS <- commandArgs(TRUE)
    if(length(ARGS)>0){
      ARGS_num <- as.numeric(ARGS)
      v <- seq(ARGS_num[1], ARGS_num[2])
      print(v)
    }

We can call the script like so, and get the expected behavior:

    $ Rscript tests/test.r 3 9
    [1] 3 4 5 6 7 8 9
    
Let's say we want to spread this operation across multiple scripts that should be run in series, such that the first script reads in the command line arguments and constructs the sequence, and the second script prints the sequence out:

    # tests/testA.r

    ARGS <- commandArgs(TRUE)

    if(length(ARGS)>0){
      
      ARGS_num <- as.numeric(ARGS)
      v <- seq(ARGS_num[1], ARGS_num[2])
    }

and then

    # tests/testB.r
    
    print(v)

If we run these two scripts one after the other, we'll get the following error:

    $ Rscript tests/testA.r 3 9
    
    $ Rscript tests/testB.r
    Error in print(v) : object 'v' not found
    Execution halted

This is because every time we run Rscript, we're running it in a new environment. When we ran testA.r, we created a variable `v`, and then when Rscript exited the environment in which that variable was defined was destroyed. testB.r was then run in a completely new environment in which `v` had not been defined. 

### The solution

**dispatchr** resolves this issue by creating a simple plumber webapp (`server.r`) which defines an API with a single end-point (`api.r`). The script `dispatch.r` takes positional arguments and passes them to the server in a GET request. The first positional argument is assumed to be the path to a script that you want to run, and all other arguments are presumed to be arguments you want to make available to the script. Then, `api.r` finds the global environment (by default plumber runs each GET request in a private environment), write a variable named "`ARGS`" into the global environment to hold the commandline parameters we want to make available to the script, and then sources the desired script into the global environment where it can access `ARGS` and anything else it might need from previous scripts that were run in a similar fashion.

Our scripts can now assume that the `ARGS` variable exists. We could alternatively check to see if ARGS exists and populate it from the commandline if we want to be defensive. Here's what our modified scripts look like:

    # tests/test1.r
    
    if(!exists(ARGS)) ARGS <- commandArgs(TRUE)

    if(length(ARGS)>0){
      ARGS <- as.numeric(ARGS)
      v <- seq(ARGS[1], ARGS[2])
    }

and 
    
    # tests/test2.r
    
    print(v)

After we kick off the server (using `&` to run it in the background), running the modified scripts will get us the desired behavior:

    $ Rscript server.r &

    $ Rscript dispatch.r tests/test1.r 3 9
    
    $ Rscript dispatch.r tests/test2.r
    [1] 3 4 5 6 7 8 9

To shutdown the backend server:

    $ kill $(ps -f | grep Rscript | awk 'NR==1{print $2}')

If you're using cygwin, do this instead:

    $ ps -W | awk '/calc.exe/,NF=1' | xargs kill -f
