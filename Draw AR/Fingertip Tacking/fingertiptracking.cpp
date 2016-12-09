//
//  fingertiptracking.cpp
//  Fingertip Tacking
//
//  Created by Miao Liu on 12/4/16.
//  Copyright © 2016 Miao Liu. All rights reserved.
//

#include "fingertiptracking.h"

std::vector<cv::Point> Tracking(cv::Mat &src,cv::Rect boundingBox)
{
    std::vector<cv::Point> validPoints;
    cv::Mat hsv;
    hsv = imageprocess(src);
    
    std::vector<std::vector<cv::Point> > contours;
    std::vector<cv::Vec4i> hierarchy;
    //find countour
    cv::findContours(hsv, contours, hierarchy, CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE, cv::Point(0, 0));
    size_t largestContour = 0;
    //find hand contour
    for (size_t i = 1; i < contours.size(); i++)
    {
        if (cv::contourArea(contours[i]) > cv::contourArea(contours[largestContour]))
            largestContour = i;
    }
    //cv::drawContours(src, contours, largestContour, cv::Scalar(0, 0, 255), 1);
    int t;
    if (!contours.empty())
    {
        std::vector<std::vector<cv::Point> > hull(1);
        cv::convexHull(cv::Mat(contours[largestContour]), hull[0], false);
        //cv::drawContours(src, hull, 0, cv::Scalar(0, 255, 0), 3);
        if (hull[0].size() > 2)
        {
            std::vector<int> hullIndexes;
            cv::convexHull(cv::Mat(contours[largestContour]), hullIndexes, true);
            std::vector<cv::Vec4i> convexityDefects;
            cv::convexityDefects(cv::Mat(contours[largestContour]), hullIndexes, convexityDefects);
            boundingBox = cv::boundingRect(hull[0]);
           // cv::rectangle(src, boundingBox, cv::Scalar(255, 0, 0));
            cv::Point center = cv::Point(boundingBox.x + boundingBox.width / 2, boundingBox.y + boundingBox.height / 2);
            for (size_t i = 0; i < convexityDefects.size(); i++)
            {
                
                cv::Point p1 = contours[largestContour][convexityDefects[i][0]];
                cv::Point p2 = contours[largestContour][convexityDefects[i][1]];
                cv::Point p3 = contours[largestContour][convexityDefects[i][2]];
                //cv::line(cvImage, p1, p3, cv::Scalar(0, 0, 255), 2);
                //cv::line(cvImage, p3, p2, cv::Scalar(0, 0, 255), 2);
                
                double angle = std::atan2(center.y - p1.y, center.x - p1.x) * 180 / CV_PI;
                double inAngle = innerAngle(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);
                double length = std::sqrt(std::pow(p1.x - p3.x, 2) + std::pow(p1.y - p3.y, 2));
                t = validPoints.size();
                
                if (angle > 0 && angle < 179 && std::abs(inAngle) > 20 && std::abs(inAngle) < 80 && length > 0.1 * boundingBox.height)
                {
                    
                    if (t>0)
                    {
                        if(Edist(validPoints.at(t-1).x,validPoints.at(t-1).y,p1.x,p1.y)>1000)
                        {
                            validPoints.push_back(p1);
                        }
                    }
                    else
                    {
                        validPoints.push_back(p1);
                    }
                }
                if (angle <30 && std::abs(inAngle) <30 && angle >-30)
                {
                    
                    if (t>0)
                    {
                        if(Edist(validPoints.at(t-1).x,validPoints.at(t-1).y,p1.x,p1.y)>1000)
                        {
                            validPoints.push_back(p1);
                        }
                    }
                }
            }
            
        }
    }
    cv::Point bounding;
    cv::Point wh;
    bounding.x = boundingBox.x;
    bounding.y = boundingBox.y;
    wh.x = boundingBox.width;
    wh.y = boundingBox.height;
    validPoints.push_back(bounding);
    validPoints.push_back(wh);
    return validPoints;
    
}

cv::Mat imageprocess(cv::Mat &src)
{
    int minH = 100, maxH = 120, minS = 70, maxS = 150, minV = 70, maxV = 250;
    cv::Mat hsv;
    cv::cvtColor(src, hsv, CV_RGB2HSV);
    //coarse segmentation
    
    cv::inRange(hsv, cv::Scalar(minH, minS, minV), cv::Scalar(maxH, maxS, maxV), hsv);
    
    int blurSize = 5;
    int elementSize = 4;
    //process
    cv::medianBlur(hsv, hsv, blurSize);
    cv::Mat element = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(2 * elementSize + 1, 2 * elementSize + 1), cv::Point(elementSize, elementSize));
    cv::dilate(hsv, hsv, element);
    return hsv;
}

float innerAngle(float px1, float py1, float px2, float py2, float cx1, float cy1)
{
    
    float dist1 = std::sqrt(  (px1-cx1)*(px1-cx1) + (py1-cy1)*(py1-cy1) );
    float dist2 = std::sqrt(  (px2-cx1)*(px2-cx1) + (py2-cy1)*(py2-cy1) );
    
    float Ax, Ay;
    float Bx, By;
    float Cx, Cy;
    
    //find closest point to C
    //printf("dist = %lf %lf\n", dist1, dist2);
    
    Cx = cx1;
    Cy = cy1;
    if(dist1 < dist2)
    {
        Bx = px1;
        By = py1;
        Ax = px2;
        Ay = py2;
        
        
    }else{
        Bx = px2;
        By = py2;
        Ax = px1;
        Ay = py1;
    }
    
    
    float Q1 = Cx - Ax;
    float Q2 = Cy - Ay;
    float P1 = Bx - Ax;
    float P2 = By - Ay;
    
    
    float A = std::acos( (P1*Q1 + P2*Q2) / ( std::sqrt(P1*P1+P2*P2) * std::sqrt(Q1*Q1+Q2*Q2) ) );
    
    A = A*180/CV_PI;
    
    return A;
}

float Edist(float px1, float py1, float px2, float py2)
{
    float dist1;
    
    dist1 = (px1-px2)*(px1-px2) + (py1-py2)*(py1-py2);
    
    return dist1;
}

std::vector<cv::Point2f> draw_Pred_Coordinate(cv::Mat &image,cv::Rect boundingBox, std::vector<cv::Point>validPoints,int flag,int zoom) {
    std::vector<cv::Point2f>output(4);
    std::vector<cv::Point2f> origin(3);
    double s = 1;
    if (zoom > 20) {
        s = 2;
    }
    cv::Point center = cv::Point(boundingBox.x + boundingBox.width / 2, boundingBox.y + boundingBox.height / 2);
    float dis;
    float x,y;
    double angle = 0;
    if(flag == 0) {
    dis = sqrt(Edist(validPoints[0].x, validPoints[0].y, center.x, center.y));
    x = validPoints[0].x - center.x;
    y = validPoints[0].y - center.y;
    angle = -asin(y/abs(dis));
    origin[0] = cv::Point2f(center.x + x * 100/sqrt(2)/s/dis * cos(CV_PI/4 - angle ) + 100/sqrt(2)/s/dis * y * sin(CV_PI/4 -angle), center.y - 100/sqrt(2)/s/dis * x * sin(CV_PI/4 - angle) + 100/sqrt(2)/s/dis * y * cos(CV_PI/4 -angle));
    origin[1] = cv::Point2f(center.x + x * 100/s/dis * cos(CV_PI/2) + 100 /s/dis * y * sin(CV_PI/2), center.y - 100/s/dis * x * sin(CV_PI/2) + 100/s/dis * y * cos(CV_PI/2));
    origin[2] = cv::Point2f(100 /s/ dis * x + center.x, center.y + 100/s/ dis * y);
//    cv::arrowedLine(image, center,origin[0],cv::Scalar(255,0,0),10);
//    cv::arrowedLine(image, center, origin[1], cv::Scalar(0,255,0),10);
//    cv::arrowedLine(image, center, origin[2], cv::Scalar(0,0,255),10);
    }
    if (flag == 1) {
        dis = sqrt(Edist(validPoints[0].x, validPoints[0].y, center.x, center.y));
        x = validPoints[0].x - center.x;
        y = validPoints[0].y - center.y;
        angle = -asin(y/abs(dis));
        origin[0] = cv::Point2f(center.x + x * 100/sqrt(2)/s/dis * cos(CV_PI/4) + 100/sqrt(2)/s/dis * y * sin(CV_PI/4), center.y - 100/sqrt(2)/s/dis * x * sin(CV_PI/4) + 100/sqrt(2)/s/dis * y * cos(CV_PI/4));
        origin[1] = cv::Point2f(center.x + x * 100/s/dis * cos(CV_PI/2 - angle) + 100 /s/dis * y * sin(CV_PI/2 - angle), center.y - 100/s/dis * x * sin(CV_PI/2 - angle) + 100/s/dis * y * cos(CV_PI/2 - angle));
        origin[2] = cv::Point2f(100 /s/ dis * x + center.x, center.y + 100/s/ dis * y);
//        cv::arrowedLine(image, center,origin[0],cv::Scalar(255,0,0),10);
//        cv::arrowedLine(image, center, origin[1], cv::Scalar(0,255,0),10);
//        cv::arrowedLine(image, center, origin[2], cv::Scalar(0,0,255),10);
    }
    output[0].x = origin[2].x;
    output[0].y = origin[2].y;
    output[1].x = origin[1].x;
    output[1].y = origin[1].y;
    output[2].x = origin[0].x;
    output[2].y = origin[0].y;
    output[3].x = center.x;
    origin[3].y = center.y;
    return output;
}
void drawCoordinate(cv::Mat &image,std::vector<cv::Point> validPoints,std::vector<cv::Point2f> proj_origin) {
    if (validPoints.size() == 4) {
        cv::Mat intrinsics;
        cv::Mat distCoeffs;
        cv::Mat rvec,tvec;
        std::vector<cv::Point3f> origin(4);
        origin[0] = cv::Point3f(7,7,1);
        origin[1] = cv::Point3f(15,7,1);
        origin[2] = cv::Point3f(7,15,1);
        origin[3] = cv::Point3f(7,7,8);
        std::vector<cv::Point3f> objpts(4);
        std::vector<cv::Point2f> imgpts(4);
        std::vector<cv::Point2f> proj_origin;
        objpts[0] = cv::Point3f(15.2,7.0,1);
        objpts[1] = cv::Point3f(12.1,14.7,1);
        objpts[2] = cv::Point3f(7.5,16.5,1);
        objpts[3] = cv::Point3f(4.1,15.8,1);
        imgpts[0] = cv::Point2f(validPoints.at(0).x,validPoints.at(0).y);
        imgpts[1] = cv::Point2f(validPoints.at(1).x,validPoints.at(1).y);
        imgpts[2] = cv::Point2f(validPoints.at(2).x,validPoints.at(2).y);
        imgpts[3] = cv::Point2f(validPoints.at(3).x,validPoints.at(3).y);
        intrinsics = cv::Mat::zeros(3,3,CV_64F);
        intrinsics.at<double>(0,0) = 2871.8995;
        intrinsics.at<double>(1,1) = 2871.8995;
        intrinsics.at<double>(2,2) = 1;
        intrinsics.at<double>(0,2) = 1631.5;
        intrinsics.at<double>(1,2) = 1223.5;
        distCoeffs = cv::Mat(5,1,cv::DataType<double>::type);
        distCoeffs.at<double>(0) = -.0008211;
        distCoeffs.at<double>(1) = 0.640757;
        distCoeffs.at<double>(2) = 0;
        distCoeffs.at<double>(3) = 0;
        distCoeffs.at<double>(4) = -1.7248;
        cv::solvePnP(objpts, imgpts, intrinsics,distCoeffs,rvec,tvec);
        cv::projectPoints(origin, rvec, tvec, intrinsics, distCoeffs,proj_origin);
        cv::arrowedLine(image, proj_origin[0], proj_origin[1], cv::Scalar(255, 0, 255), 1);
        cv::arrowedLine(image, proj_origin[0], proj_origin[2], cv::Scalar(0, 0, 255), 1);
        cv::arrowedLine(image, proj_origin[0], proj_origin[3], cv::Scalar(0, 255, 0), 1);
        cv::circle(image,proj_origin[0],9, cv::Scalar(255, 0, 0), 2);
        
    }
    if (validPoints.size() == 5) {
        cv::Mat intrinsics;
        cv::Mat distCoeffs;
        cv::Mat rvec,tvec;
        std::vector<cv::Point3f> origin(4);
        origin[0] = cv::Point3f(7,7,1);
        origin[1] = cv::Point3f(15,7,1);
        origin[2] = cv::Point3f(7,15,1);
        origin[3] = cv::Point3f(7,7,8);
        std::vector<cv::Point3f> objpts(5);
        std::vector<cv::Point2f> imgpts(5);
        std::vector<cv::Point2f> proj_origin;
        objpts[0] = cv::Point3f(15.2,7.0,1);
        objpts[1] = cv::Point3f(12.1,14.7,1);
        objpts[2] = cv::Point3f(7.5,16.5,1);
        objpts[3] = cv::Point3f(4.1,15.8,1);
        objpts[4] = cv::Point3f(0,12,1);
        imgpts[0] = cv::Point2f(validPoints.at(0).x,validPoints.at(0).y);
        imgpts[1] = cv::Point2f(validPoints.at(1).x,validPoints.at(1).y);
        imgpts[2] = cv::Point2f(validPoints.at(2).x,validPoints.at(2).y);
        imgpts[3] = cv::Point2f(validPoints.at(3).x,validPoints.at(3).y);
        imgpts[4] = cv::Point2f(validPoints.at(4).x,validPoints.at(4).y);
        intrinsics = cv::Mat::zeros(3,3,CV_64F);
        intrinsics.at<double>(0,0) = 2871.8995;
        intrinsics.at<double>(1,1) = 2871.8995;
        intrinsics.at<double>(2,2) = 1;
        intrinsics.at<double>(0,2) = 1631.5;
        intrinsics.at<double>(1,2) = 1223.5;
        distCoeffs = cv::Mat(5,1,cv::DataType<double>::type);
        distCoeffs.at<double>(0) = -.0008211;
        distCoeffs.at<double>(1) = 0.640757;
        distCoeffs.at<double>(2) = 0;
        distCoeffs.at<double>(3) = 0;
        distCoeffs.at<double>(4) = -1.7248;
        cv::solvePnP(objpts, imgpts, intrinsics,distCoeffs,rvec,tvec);
        cv::projectPoints(origin, rvec, tvec, intrinsics, distCoeffs,proj_origin);
        cv::arrowedLine(image, proj_origin[0], proj_origin[1], cv::Scalar(255, 0, 255), 1);
        cv::arrowedLine(image, proj_origin[0], proj_origin[2], cv::Scalar(0, 0, 255), 1);
        cv::arrowedLine(image, proj_origin[0], proj_origin[3], cv::Scalar(0, 255, 0), 1);
        cv::circle(image,proj_origin[0],9, cv::Scalar(255, 0, 0), 2);
        
    }
    
}
