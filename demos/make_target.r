if(!exists('iris')){
    load('demos/iris.rdata')
}

iris_t=iris
iris_t$target <- iris_t$Species == 'versicolor'
iris_t$Species <- NULL

save(iris_t, file='demos/iris_t.rdata')
