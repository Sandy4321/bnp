from __future__ import division
from __future__ import print_function

__author__ = 'michael.pearmain'

import pandas as pd
import datetime
from xgboost import XGBClassifier
from sklearn.metrics import log_loss
from bayes_opt import BayesianOptimization
import os

def xgboostcv(max_depth,
              learning_rate,
              n_estimators,
              subsample,
              colsample_bytree,
              gamma,
              min_child_weight,
              silent=True,
              nthread=-1,
              seed=1234):

    clf = XGBClassifier(max_depth=int(max_depth),
                        learning_rate=learning_rate,
                        n_estimators=int(n_estimators),
                        silent=silent,
                        nthread=nthread,
                        subsample=subsample,
                        colsample_bytree=colsample_bytree,
                        gamma=gamma,
                        min_child_weight = min_child_weight,
                        seed=seed,
                        objective="binary:logistic")

    clf.fit(x0, y0, eval_metric="logloss", eval_set=[(x1, y1)],verbose=True,early_stopping_rounds=25)
    ll = -log_loss(y1, clf.predict_proba(x1, ntree_limit = clf.best_iteration)[:,1])
    return ll

if __name__ == "__main__":

    # settings
    projPath = os.getcwd()
    dataset_version = "lvl220160317diff"
    todate = datetime.datetime.now().strftime("%Y%m%d")

    ## data
    # read the training and test sets
    xtrain = pd.read_csv('../input/xtrain_'+ dataset_version + '.csv')
    id_train = xtrain.ID
    ytrain = xtrain.target
    xtrain.drop('ID', axis = 1, inplace = True)
    xtrain.drop('target', axis = 1, inplace = True)
    xtest = pd.read_csv('../input/xtest_'+ dataset_version + '.csv')
    id_test = xtest.ID
    xtest.drop('ID', axis = 1, inplace = True)

    # folds
    xfolds = pd.read_csv('../input/xfolds.csv')
    # work with validation split
    idx0 = xfolds[xfolds.valid == 0].index
    idx1 = xfolds[xfolds.valid == 1].index
    x0 = xtrain[xtrain.index.isin(idx0)]
    x1 = xtrain[xtrain.index.isin(idx1)]
    y0 = ytrain[ytrain.index.isin(idx0)]
    y1 = ytrain[ytrain.index.isin(idx1)]

    xgboostBO = BayesianOptimization(xgboostcv,
                                     {'max_depth': (int(3), int(15)),
                                      'learning_rate': (0.0005, 0.03),
                                      'n_estimators': (int(500), int(2000)),
                                      'subsample': (0.65, 0.95),
                                      'colsample_bytree': (0.65, 0.95),
                                      'gamma': (0.000001, 0.02),
                                      'min_child_weight': (int(4), int(25))
                                     })
    xgboostBO.maximize(init_points=5, n_iter=20, acq='ei')
    print('-' * 53)

    print('Final Results')
    print('XGBOOST: %f' % xgboostBO.res['max']['max_val'])
    print('XGBOOST: %s' % xgboostBO.res['max']['max_params'])
