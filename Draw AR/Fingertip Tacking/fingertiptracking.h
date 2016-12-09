//
//  fingertiptracking.h
//  Fingertip Tacking
//
//  Created by Miao Liu on 12/4/16.
//  Copyright © 2016 Miao Liu. All rights reserved.
//

#ifndef fingertiptracking_h
#define fingertiptracking_h
#include <opencv2/opencv.hpp> 

cv::Mat imageprocess(cv::Mat &src);
std::vector<cv::Point> Tracking(cv::Mat &src,cv::Rect boundingBox);
float innerAngle(float px1, float py1, float px2, float py2, float cx1, float cy1);
float Edist(float px1, float py1, float px2, float py2);
std::vector<cv::Point2f> draw_Pred_Coordinate(cv::Mat &image,cv::Rect boundingBox, std::vector<cv::Point>validPoints,int flag,int zoom);
void drawCoordinate(cv::Mat &image,std::vector<cv::Point> validPoints,std::vector<cv::Point2f> proj_origin);
#endif /* fingertiptracking_h */

