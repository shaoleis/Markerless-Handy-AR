//
//  ViewController.m
//  Fingertip Tacking
//
//  Created by 刘淼 on 12/3/16.
//  Copyright © 2016 刘淼. All rights reserved.
//


#import "ViewController.h"

#ifdef __cplusplus
#include "opencv2/features2d/features2d.hpp"
#include "opencv2/nonfree/features2d.hpp"
#include <opencv2/opencv.hpp>
#include <stdlib.h>
#include <iostream>
#endif

@interface ViewController(){
    UIImageView *imageView_; // Setup the image view
    UITextView *fpsView_; // Display the current FPS
    int64 curr_time_; // Store the current time
}
@end

@implementation ViewController

// Important as when you when you override a property of a superclass, you must explicitly synthesize it
@synthesize videoCamera;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // Initialize the view
    // Hacky way to initialize the view to ensure the aspect ratio looks correct
    // across all devices. Unfortunately, setting UIViewContentModeScaleAspectFill
    // does not work with the CvCamera Delegate so we have to hard code everything....
    //
    // Assuming camera input is 352x288 (set using AVCaptureSessionPreset)
    float cam_width = 480; float cam_height = 640;
    
    // Take into account size of camera input
    int view_width = self.view.frame.size.width;
    int view_height = (int)(cam_height*self.view.frame.size.width/cam_width);
    int offset = (self.view.frame.size.height - view_height)/2;
    
    imageView_ = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, offset, view_width, view_height)];
    
    //[imageView_ setContentMode:UIViewContentModeScaleAspectFill]; (does not work)
    [self.view addSubview:imageView_]; // Add the view
    
    // Initialize the video camera
    self.videoCamera = [[CvVideoCamera alloc] initWithParentView:imageView_];
    self.videoCamera.delegate = self;
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultFPS = 30; // Set the frame rate
    self.videoCamera.grayscaleMode = NO; // Get grayscale
    self.videoCamera.rotateVideo = YES; // Rotate video so everything looks correct
    
    // Choose these depending on the camera input chosen
    //self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset352x288;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480;
    //self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset1280x720;
    
    // Finally add the FPS text to the view
    fpsView_ = [[UITextView alloc] initWithFrame:CGRectMake(0,15,view_width,std::max(offset,35))];
    [fpsView_ setOpaque:false]; // Set to be Opaque
    [fpsView_ setBackgroundColor:[UIColor clearColor]]; // Set background color to be clear
    [fpsView_ setTextColor:[UIColor redColor]]; // Set text to be RED
    [fpsView_ setFont:[UIFont systemFontOfSize:18]]; // Set the Font size
    [self.view addSubview:fpsView_];
    
    [videoCamera start];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    
    //delete brisk;
}

// Function to run apply image on
- (void) processImage:(cv:: Mat &)image
{
    
    // Now apply Brisk features on the live camera
    int minH = 70, maxH = 160, minS = 70, maxS = 200, minV = 70, maxV = 250;
    
    cv::Mat hsv;
    cv::cvtColor(image, hsv, CV_RGB2HSV);
    //coarse segmentation
    
    
    cv::inRange(hsv, cv::Scalar(minH, minS, minV), cv::Scalar(maxH, maxS, maxV), hsv);
    
    int blurSize = 5;
    int elementSize = 3;
    //process
    cv::medianBlur(hsv, hsv, blurSize);
    cv::Mat element = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(2 * elementSize + 1, 2 * elementSize + 1), cv::Point(elementSize, elementSize));
    cv::dilate(hsv, hsv, element);
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
    int t;
    cv::drawContours(image, contours, largestContour, cv::Scalar(0, 0, 255), 1);
    if (!contours.empty())
    {
        std::vector<std::vector<cv::Point> > hull(1);
        cv::convexHull(cv::Mat(contours[largestContour]), hull[0], false);
        cv::drawContours(image, hull, 0, cv::Scalar(0, 255, 0), 3);
        if (hull[0].size() > 2)
        {
            std::vector<int> hullIndexes;
            cv::convexHull(cv::Mat(contours[largestContour]), hullIndexes, true);
            std::vector<cv::Vec4i> convexityDefects;
            cv::convexityDefects(cv::Mat(contours[largestContour]), hullIndexes, convexityDefects);
            cv::Rect boundingBox = cv::boundingRect(hull[0]);
            cv::rectangle(image, boundingBox, cv::Scalar(255, 0, 0));
            cv::Point center = cv::Point(boundingBox.x + boundingBox.width / 2, boundingBox.y + boundingBox.height / 2);
            std::vector<cv::Point> validPoints;
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
            
            for (size_t i = 0; i < validPoints.size(); i++)
            {
                cv::circle(image, validPoints[i], 9, cv::Scalar(0, 255, 0), 2);
            }
        }
    }
    
    /*int blurSize = 5;
     int elementSize = 3;
     //process
     cv::medianBlur(hsv, hsv, blurSize);
     cv::Mat element = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(2 * elementSize + 1, 2 * elementSize + 1), cv::Point(elementSize, elementSize));
     cv::dilate(hsv, hsv, element);
     
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
     
     cv::drawContours(cvImage, contours, largestContour, cv::Scalar(0, 0, 255), 1);
     
     if (!contours.empty())
     {
     std::vector<std::vector<cv::Point> > hull(1);
     cv::convexHull(cv::Mat(contours[largestContour]), hull[0], false);
     cv::drawContours(cvImage, hull, 0, cv::Scalar(0, 255, 0), 3);
     if (hull[0].size() > 2)
     {
     std::vector<int> hullIndexes;
     cv::convexHull(cv::Mat(contours[largestContour]), hullIndexes, true);
     std::vector<cv::Vec4i> convexityDefects;
     cv::convexityDefects(cv::Mat(contours[largestContour]), hullIndexes, convexityDefects);
     cv::Rect boundingBox = cv::boundingRect(hull[0]);
     cv::rectangle(cvImage, boundingBox, cv::Scalar(255, 0, 0));
     cv::Point center = cv::Point(boundingBox.x + boundingBox.width / 2, boundingBox.y + boundingBox.height / 2);
     std::vector<cv::Point> validPoints;
     int thumb_flag =0;
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
     if (angle > 30 && angle < 160 && std::abs(inAngle) > 20 && std::abs(inAngle) < 120 && length > 0.1 * boundingBox.height)
     {
     validPoints.push_back(p1);
     }
     if (thumb_flag==0 && angle<30 && angle > -30)
     {
     thumb_flag ++;
     validPoints.push_back(p1);
     }
     }
     
     for (size_t i = 0; i < validPoints.size(); i++)
     {
     cv::circle(cvImage, validPoints[i], 9, cv::Scalar(0, 255, 0), 2);
     }
     }
     }*/
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
@end
