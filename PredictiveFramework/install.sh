#/bin/bash

DIR=$(pwd)

cd $DIR/PredictiveAPI/
sudo make install

cd $DIR/predictive_solver_advisor/
sudo make install

cd $DIR/TimeSeries/Arima/
sudo make install

cd $DIR/MachineLearning/LinearRegression/
sudo make install


