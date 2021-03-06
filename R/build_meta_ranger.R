## wd etc ####
require(readr)
require(ranger)
require(caret)
require(stringr)

dataset_version <- "lvl220160331combo"
seed_value <- 43
model_type <- "ranger"
todate <- str_replace_all(Sys.Date(), "-","")

## functions ####

msg <- function(mmm,...)
{
  cat(sprintf(paste0("[%s] ",mmm),Sys.time(),...)); cat("\n")
}

# wrapper around logloss preventing Inf/-Inf for 1/0 values
log_loss <- function(actual, predicted, cutoff = 1e-15)
{
  predicted <- pmax(predicted, cutoff)
  predicted <- pmin(predicted, 1- cutoff)
  return(logLoss(actual,predicted))
}

## data ####
# read actual data
xtrain <- read_csv(paste("../input2/xtrain_",dataset_version,".csv", sep = ""))
xtest <- read_csv(paste("../input2/xtest_",dataset_version,".csv", sep = ""))
y <- xtrain$target; xtrain$target <- NULL
id_train <- xtrain$ID
id_test <- xtest$ID
xtrain$ID <- xtest$ID <- NULL

# division into folds: 5-fold
xfolds <- read_csv("../input/xfolds.csv"); xfolds$fold_index <- xfolds$fold5
xfolds <- xfolds[,c("ID", "fold_index")]
nfolds <- length(unique(xfolds$fold_index))

## fit models ####
# parameter grid
param_grid <- expand.grid(ntree = c(500, 1000),
                          mtry = c(15, 30, 50),
                          nsize = c(1, 10,25))

# storage structures 
mtrain <- array(0, c(nrow(xtrain), nrow(param_grid)))
mtest <- array(0, c(nrow(xtest), nrow(param_grid)))

# loop over parameters
for (ii in 1:nrow(param_grid))
{
 
  # loop over folds 
  for (jj in 1:nfolds)
  {
    isTrain <- which(xfolds$fold_index != jj)
    isValid <- which(xfolds$fold_index == jj)
    x0 <- xtrain[isTrain,]; x1 <- xtrain[isValid,]
    y0 <- factor(y)[isTrain]; y1 <- factor(y)[isValid]
    
    ranger.model <- ranger(y0 ~ ., 
                           data = x0, 
                           mtry = param_grid$mtry[ii],
                           num.trees = param_grid$ntree[ii],
                           write.forest = T,
                           probability = T,
                           min.node.size = param_grid$nsize[ii],
                           seed = seed_value
                           )
    
    
    pred_valid <- predict(ranger.model, x1)$predictions[,2]
    mtrain[isValid,ii] <- pred_valid
  }
  
  # full version 
  ranger.model <- ranger(factor(y) ~ ., data = xtrain, 
                         mtry = param_grid$mtry[ii],
                         num.trees = param_grid$ntree[ii],
                         write.forest = T,
                         probability = T,
                         min.node.size = param_grid$nsize[ii],
                         seed = seed_value
  )
  
  pred_full <- predict(ranger.model, xtest)$predictions[,2]
  mtest[,ii] <- pred_full
  msg(ii)
}

## store complete versions ####
mtrain <- data.frame(mtrain)
mtest <- data.frame(mtest)
colnames(mtrain) <- colnames(mtest) <- paste(model_type, 1:ncol(mtrain), sep = "")
mtrain$ID <- id_train
mtest$ID <- id_test
mtrain$target <- y


# Remove any linear combos.
# trim linearly dependent ones 
print(paste("Pre linear combo trim size ", dim(mtrain)[2]))
flc <- findLinearCombos(mtrain)
if (length(flc$remove))
{
  mtrain <- mtrain[,-flc$remove]
  mtest <- mtest[,-flc$remove]
}

print(paste(" Number of cols after linear combo extraction:", dim(mtrain)[2]))
# store the metas
write_csv(mtrain, path = paste("../metafeatures2/prval_",model_type,"_", todate, "_data", dataset_version, "_seed", seed_value, ".csv",sep = "" ))
write_csv(mtest, path = paste("../metafeatures2/prfull_",model_type,"_", todate, "_data", dataset_version, "_seed", seed_value, ".csv",sep = "" ))

# store the parameters
write_csv(param_grid, path = paste("../meta_parameters2/params_",model_type,"_", todate, "_data", dataset_version, "_seed", seed_value, ".csv",sep = "" ))

