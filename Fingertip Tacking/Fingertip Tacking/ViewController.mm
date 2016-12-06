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
#include "fingertiptracking.h"
#endif

@interface ViewController(){
    UIImageView *imageView_; // Setup the image view
    cv::vector<cv::KeyPoint> template_keypoints;
    cv::Mat template_im, template_gray, template_copy;
    cv::Mat template_descriptor;
    //cv::Ptr<cv::BFMatcher> matcher;
    cv::SurfFeatureDetector *detector_; // Set the SURF Detector
    cv::SurfDescriptorExtractor *extractor_; // Set the SURF Extractor
    std::vector<cv::Point2f> obj_corners;
    std::vector<cv::Point> previouspoints;
    std::vector<cv::Point2f> proj_origin;
    UITextView *fpsView_; // Display the current FPS
    int64 curr_time_; // Store the current time
    cv::Mat intrinsics;
    cv::Mat distCoeffs;
    bool first;
}
@end

@implementation ViewController

// Important as when you when you override a property of a superclass, you must explicitly synthesize it
@synthesize videoCamera;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    //UIImage *template_image = [UIImage imageNamed:@"template.JPG"];
    UIImage *template_image = [UIImage imageNamed:@"template.JPG"];
    template_im = [self cvMatFromUIImage:template_image];
    resize(template_im, template_im, cv::Size2f(480,640));
    std::cout << "vDSP took " << template_im.cols<< " seconds." << std::endl;
    std::cout << "vDSP took " << template_im.rows<< " seconds." << std::endl;
    int minHessian = 400;
    detector_ = new cv::SurfFeatureDetector(minHessian); // Set the detector
    extractor_ = new cv::SurfDescriptorExtractor(); // Set the extractor

    cv::cvtColor(template_im, template_gray, CV_RGBA2GRAY);
    
    
    detector_->detect(template_gray, template_keypoints);
    
    extractor_->compute(template_gray, template_keypoints, template_descriptor);
    
    cv::BFMatcher matcher(cv::NORM_L2,true);
    cv::Mat img_matches;
    std::vector< cv::DMatch > matches;
    
    obj_corners = std::vector<cv::Point2f> (4);
    obj_corners[0] = cvPoint(0,0);
    obj_corners[1] = cvPoint( template_im.cols, 0 );
    obj_corners[2] = cvPoint( template_im.cols, template_im.rows );
    obj_corners[3] = cvPoint( 0, template_im.rows );
    float cam_width = 480; float cam_height = 640;

    int view_width = self.view.frame.size.width;
    int view_height = (int)(cam_height*self.view.frame.size.width/cam_width);
    int offset = (self.view.frame.size.height - view_height)/2;
    
    imageView_ = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, offset, view_width, view_height)];
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
    
    
    // For AR
    intrinsics = cv::Mat::zeros(3,3,CV_64F);
    intrinsics.at<double>(0,0) = 2871.8995;
    intrinsics.at<double>(1,1) = 2871.8995;
    intrinsics.at<double>(2,2) = 1;
    intrinsics.at<double>(0,2) = 1631.5;
    intrinsics.at<double>(1,2) = 1223.5;
    distCoeffs = cv::Mat(5,1,cv::DataType<double>::type);
    distCoeffs.at<double>(0) = 0;
    distCoeffs.at<double>(1) = 0;
    distCoeffs.at<double>(2) = 0;
    distCoeffs.at<double>(3) = 0;
    distCoeffs.at<double>(4) = 0;
    first = true;

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
    /*cv::Mat image_gray;
    cv::Mat image_descriptor;
    cv::Mat hsv = imageprocess(image);
//    std::vector<cv::Point> validPoints;
//    validPoints = Tracking(image);
//    for (size_t i = 0; i < validPoints.size(); i++)
//    {
//        cv::circle(image, validPoints[i], 9, cv::Scalar(0, 255, 0), 2);
//    }
    
    // Add AR
    cv::Mat image_copy;
    cvtColor(image, image_copy, CV_BGRA2BGR);
    
    cv::Mat rvec, tvec;
    std::vector<cv::Point3f> proj_corners(4);
    std::vector<cv::Point2f> scene_proj_corners(4);
    std::vector<cv::Point2f> scene_corners(4);
    
    float x = 120;
    float y = 385;
    float w = 188;
    float h = -200;
    
    proj_corners[0] = cv::Point3f(0, 0, 0);
    proj_corners[1] = cv::Point3f(182, 0,0);
    proj_corners[2] = cv::Point3f( 182, 260, 0 );
    proj_corners[3] = cv::Point3f( 0, 260, 0 );
    
    scene_corners[0] = cv::Point2f(0,0);
    scene_corners[1] = cv::Point2f(182,0);
    scene_corners[2] = cv::Point2f(182,260);
    scene_corners[3] = cv::Point2f(0,260);
    
    
    //either solve with scene_corners or estPts
    cv::solvePnP(proj_corners, scene_corners, intrinsics, distCoeffs, rvec, tvec);
    
    std::vector<cv::Point3f> cube_corners(8);
    //left face
    cube_corners[0] = cv::Point3f(x + w, y, h);
    cube_corners[1] = cv::Point3f(x + w, y, h-w );
    cube_corners[2] = cv::Point3f(x + w, y + w, h-w );
    cube_corners[3] = cv::Point3f(x + w, y + w, h );
    cube_corners[4] = cv::Point3f(x + w + w, y, h);
    cube_corners[5] = cv::Point3f(x + w + w, y, h-w );
    cube_corners[6] = cv::Point3f(x + w + w, y + w, h-w );
    cube_corners[7] = cv::Point3f(x + w + w, y + w, h );
    
    std::vector<cv::Point2f> cube_proj_corners;
    
    cv::projectPoints(cube_corners, rvec, tvec, intrinsics, distCoeffs, cube_proj_corners);
    cv::projectPoints(proj_corners, rvec, tvec, intrinsics, distCoeffs, scene_proj_corners);
    
//    cv::line( image, scene_proj_corners[0], scene_proj_corners[1], cv::Scalar(255, 0, 255), 1 );
//    cv::line( image, scene_proj_corners[1], scene_proj_corners[2], cv::Scalar(255, 0, 255), 1 );
//    cv::line( image, scene_proj_corners[2], scene_proj_corners[3], cv::Scalar(255, 0, 255), 1 );
//    cv::line( image, scene_proj_corners[3], scene_proj_corners[0], cv::Scalar(255, 0, 255), 1 );
    
    for (int i = 0; i < 8; i++) {
        std::cout<<cube_proj_corners[i]<<std::endl;
        cv::circle(image, cube_proj_corners[i], 10, cv::Scalar(255, 0, 255));
    }
    for (int i=0; i<5; i+=4) {
    cv::line(image, cube_proj_corners[0+i], cube_proj_corners[1+i], cv::Scalar(0, 0, 255), 1);
    cv::line(image, cube_proj_corners[1+i], cube_proj_corners[2+i], cv::Scalar(0, 0, 255), 1);
    cv::line(image, cube_proj_corners[2+i], cube_proj_corners[3+i], cv::Scalar(0, 0, 255), 1);
    cv::line(image, cube_proj_corners[3+i], cube_proj_corners[0+i], cv::Scalar(0, 0, 255), 1);
    }
    
    cv::line(image, cube_proj_corners[0], cube_proj_corners[4], cv::Scalar(0, 0, 255), 1);
    cv::line(image, cube_proj_corners[1], cube_proj_corners[5], cv::Scalar(0, 0, 255), 1);
    cv::line(image, cube_proj_corners[2], cube_proj_corners[6], cv::Scalar(0, 0, 255), 1);
    cv::line(image, cube_proj_corners[3], cube_proj_corners[7], cv::Scalar(0, 0, 255), 1);
    if(first){
        first = false;
    }
    
    
    
    // Now apply Brisk features on the live camera
    /*int minH = 70, maxH = 160, minS = 70, maxS = 200, minV = 70, maxV = 250;
    
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
>>>>>>> origin/master
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
    cv::drawContours(image, contours, largestContour, cv::Scalar(0, 0, 255), 1);
    
    cv::BFMatcher matcher(cv::NORM_L2,true);
    std::vector<cv::DMatch> matches;
    
    cvtColor(image, image_gray, CV_BGR2GRAY);
    
    cv::vector<cv::KeyPoint> image_keypoints;
    detector_->detect(image_gray, image_keypoints);
    extractor_->compute(image_gray, image_keypoints, image_descriptor);
    if(image_descriptor.cols == template_descriptor.cols)
    {
        matcher.match(template_descriptor, image_descriptor, matches);
    
        
        double max_dist = 0; double min_dist = 3000;
    //-- Quick calculation of max and min distances between keypoints
        for( int i = 0; i < matches.size(); i++ )
        {
            double dist = matches[i].distance;
            if( dist < min_dist ) min_dist = dist;
            if( dist > max_dist ) max_dist = dist;
        }
        
        std::vector< cv::DMatch > good_matches;
        for( int i = 0; i < matches.size(); i++ )
        {
        
            if( cv::pointPolygonTest(contours[largestContour],  image_keypoints[matches[i].trainIdx].pt , false)==1 && matches[i].distance < 4*min_dist  )
            {
                good_matches.push_back( matches[i]);
            }
        }

        std::cout << "vDSP took " << good_matches.size()<< " seconds." << std::endl;
        cv::vector<cv::Point3f> source;
        cv::vector<cv::Point2f> source2;
        cv::vector<cv::Point2f> dest;
        for(int i = 0; i < good_matches.size(); i++)
        {
            source.push_back(cv::Point3f(template_keypoints[good_matches[i].queryIdx].pt.x,
                                     template_keypoints[good_matches[i].queryIdx].pt.y,
                                     0));
            source2.push_back(template_keypoints[good_matches[i].queryIdx].pt);
            dest.push_back(image_keypoints[good_matches[i].trainIdx].pt);
        }
        cv::Mat inliers_mask;
        cv::Mat H = cv::findHomography(source2, dest, CV_RANSAC, 5, inliers_mask);
        std::vector<cv::Point2f> scene_corners(4);
        
        cv::perspectiveTransform( obj_corners, scene_corners, H);
        
        for (size_t i = 0; i < scene_corners.size(); i++)
        {
            cv::circle(image, scene_corners[i], 9, cv::Scalar(0, 255, 0), 2);
            cv::circle(image, obj_corners[i], 9, cv::Scalar(0, 0, 255), 2);
        }
        
       
    }*/
        
    std::vector<cv::Point> validPoints;
    //std::vector<cv::Point2f> proj_origin;
    validPoints = Tracking(image);
    for (size_t i = 0; i < previouspoints.size(); i++)
    {
        
        cv::circle(image, previouspoints[i], 9, cv::Scalar(0, 0, 255), 2);
        
    }

    
    for (size_t i = 0; i < validPoints.size(); i++)
    {
        if (previouspoints.size()>0)
        {
            if (Edist(validPoints[i].x, validPoints[i].y, previouspoints[i].x, previouspoints[i].y) <1000)
            {
                validPoints[i] =previouspoints[i];
            }
        }
        cv::circle(image, validPoints[i], 9, cv::Scalar(0, 255, 0), 2);

    }
    previouspoints = validPoints;
    drawCoordinate(image,validPoints,proj_origin);

    //image = imageprocess(image);

}

void drawCoordinate(cv::Mat &image,std::vector<cv::Point> validPoints,std::vector<cv::Point2f> proj_origin) {
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


- (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}


-(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}


float Edist(float px1, float py1, float px2, float py2)
{
    float dist1;
    
    dist1 = (px1-px2)*(px1-px2) + (py1-py2)*(py1-py2);
    
    return dist1;
}

@end
