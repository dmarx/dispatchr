if(!exists('iris_t')){
    load('demo/iris_t.rdata')
}

feats <- names(iris_t)
feats <- feats[feats != 'target']

rhs <- paste(feats, collapse=' + ')
formula <- paste0('target ~ ', rhs)

model <- glm(formula, family=binomial, data=iris_t)

save(model, file='demos/model.rdata')
