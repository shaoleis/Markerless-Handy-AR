//
//  fingertiptracking.h
//  Fingertip Tacking
//
//  Created by 刘淼 on 12/4/16.
//  Copyright © 2016 刘淼. All rights reserved.
//

#ifndef fingertiptracking_h
#define fingertiptracking_h
#include <opencv2/opencv.hpp> 
std::vector<cv::Point> Tracking(cv::Mat &src);
float innerAngle(float px1, float py1, float px2, float py2, float cx1, float cy1);
float Edist(float px1, float py1, float px2, float py2);

#endif /* fingertiptracking_h */

