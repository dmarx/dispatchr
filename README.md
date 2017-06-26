# dispatchr

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

Or if you're running this through cygwin:

    $ ps -W | awk '/calc.exe/,NF=1' | xargs kill -f
    
## The problem

Sometimes loading things into the environment is expensive. If we have a large data object that we are manipulating across a series of scripts, saving the object to disk and then re-loading it in between every operation can significantly impact the overall processing time of the sequence. To get around this unnecessary overhead, it's not uncommon to wrap the entire sequence into a single script which runs the entire sequence from back to front. This is fine if all of the steps in the sequence need to be run, but if we only need to run some portion of the sequence (e.g. some data was updated or a script was changed, and we only need to refresh the objects from the middle of the sequence down) we need to add a significant amount of complexity to the pipeline script, or bite the bullet and just run the whole sequence. If we go with the latter option, we may ultimately be dealing with a longer processing time than if we had simply used something like Gnu Make to build our pipeline to begin with.

## The solution

Using **dispatchr**, you can pass the large object from step to step as though you were sourcing the scripts in an interactive R session, and only load necessary objects from disk if they weren't passed along from an earlier step in the sequence. This allows us to utilize intelligent pipelining tools like Gnu Make, while not having to worry about the additional i/o overhead that is normally associated with batch processing.

## How it works

**dispatchr** is just an extremely minimal webapp serving a REST API with a single end point. The webapp runs inside an R session. A supplementary script converts command line arguments into GET requests that hit the API. Through this API, we can issue `source()` calls into the webapp's environment, and assign positional arguments from the commandline into variables in the R environment.

### That sounds like an arbitrary code execution vulnerability

It probably is. I never said this was a good idea.

Anyway, the API is limited to two operations: issuing `source()` commands on the first argument (which is presumably the path to a file that already exists on the server), and assigning the positional arguments into a variable. I'm pretty confident there's only a vulnerability here if the malicious actor has the ability to write files to the server. If they already have that kind of access, you probably have bigger problems already.

I plan to add authentication in the near future, which should help mitigate any security issues.

## Demonstrations

### Example 1: Simple object persistence

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

### With dispatchr

If we want to run our scripts with dispatch.r, we need to re-write them to respect the `ARGS` variable, which we'll use to pass values from the command line into the environment. To be safe, we should also check to see if ARGS exists and populate it from the command line if it's not. Here's what our modified scripts look like:

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

### Example 2: a simple modeling pipeline

Consider a simple modeling pipeline in which we will get some data, add a target variable, and fit a model. Using the strategy above, for any given step in the sequence, we can check to see if the output of the previous step is in the environment already and only load if it is not:

    # read_data.r

    data(iris)

    save(iris, file='iris.rdata')

...

    # make_target.r
    
    if(!exists('iris')){
        load('iris.rdata')
    }

    iris_t=iris
    iris_t$target <- iris_t$Species == 'versicolor'
    iris_t$Species <- NULL

    save(iris_t, file='iris_t.rdata')

...

    # fit_model.r

    if(!exists('iris_t')){
        load('iris_t.rdata')
    }

    feats <- names(iris_t)
    feats <- feats[feats != 'target']

    rhs <- paste(feats, collapse=' + ')
    formula <- paste0('target ~ ', rhs)

    model <- glm(formula, family=binomial, data=iris_t)

    save(model, file='model.rdata')

A simple way to build this pipeline would be to source each script in sequence in one R script, like so:

    # ugly_pipeline.r
    
    source('read_data.r')
    source('make_target.r')
    source('fit_model.r')

### With dispatchr and Gnu Make

Now let's pretend we want to make a change to the model formula, or how the target variable is defined. If we run the full pipeline, we're going to re-run every single step of the sequence, including downloading the dataset. Instead, we could use Make to manage our pipeline and only rebuild files that are downstream of things that have changed. Furthermore, by incorporating dispatchr, we are able to use Make to manage our pipeline while also eliminating the unnecessary overhead of loading objects that are already in our environment:

    # Makefile
    
    .PHONY pipeline
    
    pipeline: model.rdata
    
    # step 3
    model.rdata: fit_model.r iris_t.rdata
        Rscript dispatch.r fit_model.r
        
    # step 2
    iris_t.rdata: make_target.r iris.rdata
        Rscript dispatch.r make_target.r
        
    # step 1
    iris.rdata: read_data.r
        Rscript dispatch.r read_data.r
        

Now, all we need to do to intelligently rebuild any objects that need to be updated is run:

    $ make pipeline