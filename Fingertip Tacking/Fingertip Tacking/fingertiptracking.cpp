//
//  fingertiptracking.cpp
//  Fingertip Tacking
//
//  Created by 刘淼 on 12/4/16.
//  Copyright © 2016 刘淼. All rights reserved.
//

#include "fingertiptracking.h"

std::vector<cv::Point> Tracking(cv::Mat &src)
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
    cv::drawContours(src, contours, largestContour, cv::Scalar(0, 0, 255), 1);
    int t;
    if (!contours.empty())
    {
        std::vector<std::vector<cv::Point> > hull(1);
        cv::convexHull(cv::Mat(contours[largestContour]), hull[0], false);
        cv::drawContours(src, hull, 0, cv::Scalar(0, 255, 0), 3);
        if (hull[0].size() > 2)
        {
            std::vector<int> hullIndexes;
            cv::convexHull(cv::Mat(contours[largestContour]), hullIndexes, true);
            std::vector<cv::Vec4i> convexityDefects;
            cv::convexityDefects(cv::Mat(contours[largestContour]), hullIndexes, convexityDefects);
            cv::Rect boundingBox = cv::boundingRect(hull[0]);
            cv::rectangle(src, boundingBox, cv::Scalar(255, 0, 0));
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


