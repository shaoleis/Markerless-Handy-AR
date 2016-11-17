//
//  ViewController.m
//  CvVideoCamera_Example
//
//  Created by Simon Lucey on 10/1/16.
//  Copyright © 2016 CMU_16623. All rights reserved.
//

#import "ViewController.h"

#ifdef __cplusplus
#include "opencv2/features2d/features2d.hpp"
#include "opencv2/nonfree/features2d.hpp"
#include <opencv2/opencv.hpp>
#include <iostream>
using namespace std;
#endif

@interface ViewController(){
    UIImageView *imageView_; // Setup the image view
    UITextView *fpsView_; // Display the current FPS
    int64 curr_time_; // Store the current time
    cv::SurfFeatureDetector *detector_; // Set the SURF Detector
    cv::SurfDescriptorExtractor *extractor_; // Set the SURF Extractor
    cv::BRISK *BRISKD_;
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
    //float cam_width = 288; float cam_height = 352;
    //float cam_width = 480; float cam_height = 640;
    float cam_width = 720; float cam_height = 1280;
    
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
    self.videoCamera.grayscaleMode = YES; // Get grayscale
    self.videoCamera.rotateVideo = YES; // Rotate video so everything looks correct
    
    // Choose these depending on the camera input chosen
    //self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset352x288;
    //self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset1280x720;
    
    // Finally add the FPS text to the view
    fpsView_ = [[UITextView alloc] initWithFrame:CGRectMake(0,15,view_width,std::max(offset,35))];
    [fpsView_ setOpaque:false]; // Set to be Opaque
    [fpsView_ setBackgroundColor:[UIColor clearColor]]; // Set background color to be clear
    [fpsView_ setTextColor:[UIColor redColor]]; // Set text to be RED
    [fpsView_ setFont:[UIFont systemFontOfSize:18]]; // Set the Font size
    [self.view addSubview:fpsView_];
    
    // Initialize the SURF Detector beforehand
    // we do not want to be doing this at run-time
    int minHessian = 400;
    detector_ = new cv::SurfFeatureDetector(minHessian); // Set the detector
    extractor_ = new cv::SurfDescriptorExtractor(); // Set the extractor
    
    // Initialize the BRISK Detector
    int Threshl=30;
    int Octaves=3; //(pyramid layer) from which the keypoint has been extracted
    float PatternScales=1.2f;
    BRISKD_ = new cv::BRISK(Threshl,Octaves,PatternScales);//initialize algoritm
    BRISKD_->create("Feature2D.BRISK");
    
    // Finally show the output
    [videoCamera start];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    // Remember to destroy SURF allocations
    delete detector_;
    delete extractor_;

    // destroy BRISK allocations
    delete BRISKD_;
}

// Function to run apply image on
- (void) processImage:(cv:: Mat &)image
{
    // Now apply Brisk features on the live camera
    using namespace cv;
    
    // Convert image to grayscale....
    //std::cout << image.channels() << std::endl;
    
    Mat gray;
    if(image.channels() == 4)
        cvtColor(image, gray, CV_RGBA2GRAY); // Convert to grayscale
    else gray = image;
    
    std::vector<KeyPoint> keypoints; // Get the keypoints
    // Resize to gray
    //resize(gray, gray, Size2f(352,288));
    //detector_->detect(gray, keypoints); // Detect the points // original code
    BRISKD_->detect(gray, keypoints);
    // Next do the descriptors
    Mat descriptors;
    //extractor_->compute(gray, keypoints, descriptors); // original code
    BRISKD_->compute(gray, keypoints, descriptors);
    // Finally estimate the frames per second (FPS)
    int64 next_time = getTickCount(); // Get the next time stamp
    float fps = (float)getTickFrequency()/(next_time - curr_time_); // Estimate the fps
    curr_time_ = next_time; // Update the time
    NSString *fps_NSStr = [NSString stringWithFormat:@"FPS = %2.2f",fps];
    
    // Have to do this so as to communicate with the main thread
    // to update the text display
    dispatch_sync(dispatch_get_main_queue(), ^{
        fpsView_.text = fps_NSStr;
    });
    
    // Draw the feature points
    drawKeypoints(gray, keypoints, image);
}


@end
