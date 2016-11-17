//
//  ViewController.m
//  Intro_iOS_Camera
//
//  Created by Simon Lucey on 9/7/15.
//  Copyright (c) 2015 CMU_16432. All rights reserved.
//

#import "ViewController.h"

// Include stdlib.h and std namespace so we can mix C++ code in here
#include <stdlib.h>
using namespace std;

@interface ViewController()
{
    UIImageView *liveView_; // Live output from the camera
    UIImageView *resultView_; // Preview view of everything...
    UIButton *takephotoButton_, *goliveButton_; // Button to initiate OpenCV processing of image
    CvPhotoCamera *photoCamera_; // OpenCV wrapper class to simplfy camera access through AVFoundation
}
@end

@implementation ViewController

int Y_MIN  = 0;
int Y_MAX  = 255;
int Cr_MIN = 40;
int Cr_MAX = 155;
int Cb_MIN = 50;
int Cb_MAX = 155;
cv::Mat imagearray[5];
//===============================================================================================
// Setup view for excuting App
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // 1. Setup the your OpenCV view, so it takes up the entire App screen......
    int view_width = self.view.frame.size.width;
    int view_height = (640*view_width)/480; // Work out the viw-height assuming 640x480 input
    int view_offset = (self.view.frame.size.height - view_height)/2;
    liveView_ = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, view_offset, view_width, view_height)];
    [self.view addSubview:liveView_]; // Important: add liveView_ as a subview
    //resultView_ = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, 960, 1280)];
    resultView_ = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, view_offset, view_width, view_height)];
    [self.view addSubview:resultView_]; // Important: add resultView_ as a subview
    resultView_.hidden = true; // Hide the view
    
    // 2. First setup a button to take a single picture
    takephotoButton_ = [self simpleButton:@"Take Photo" buttonColor:[UIColor redColor]];
    // Important part that connects the action to the member function buttonWasPressed
    [takephotoButton_ addTarget:self action:@selector(buttonWasPressed) forControlEvents:UIControlEventTouchUpInside];
    
    // 3. Setup another button to go back to live video
    goliveButton_ = [self simpleButton:@"Go Live" buttonColor:[UIColor greenColor]];
    // Important part that connects the action to the member function buttonWasPressed
    [goliveButton_ addTarget:self action:@selector(liveWasPressed) forControlEvents:UIControlEventTouchUpInside];
    [goliveButton_ setHidden:true]; // Hide the button
    
    // 4. Initialize the camera parameters and start the camera (inside the App)
    photoCamera_ = [[CvPhotoCamera alloc] initWithParentView:liveView_];
    photoCamera_.delegate = self;
    
    // This chooses whether we use the front or rear facing camera
    photoCamera_.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    
    // This is used to set the image resolution
    photoCamera_.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480;
    
    // This is used to determine the device orientation
    photoCamera_.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;

    // This starts the camera capture
    [photoCamera_ start];
    
}

//===============================================================================================
// This member function is executed when the button is pressed
- (void)buttonWasPressed {
    [photoCamera_ takePicture];
}
//===============================================================================================
// This member function is executed when the button is pressed
- (void)liveWasPressed {
    [takephotoButton_ setHidden:false]; [goliveButton_ setHidden:true]; // Switch visibility of buttons
    resultView_.hidden = true; // Hide the result view again
    [photoCamera_ start];
}
//===============================================================================================
// To be compliant with the CvPhotoCameraDelegate we need to implement these two methods
- (void)photoCamera:(CvPhotoCamera *)photoCamera capturedImage:(UIImage *)image
{
    [photoCamera_ stop];
    cv::Mat cvImage;
    cv::Mat Gray;
    
    UIImageToMat(image, cvImage);
    cv::Mat skin;
    cv::cvtColor(cvImage,Gray,cv::COLOR_BGR2GRAY);
    cv::cvtColor(cvImage,skin,cv::COLOR_BGR2YCrCb);
    cv::inRange(skin,cv::Scalar(Y_MIN,Cr_MIN,Cb_MIN),cv::Scalar(Y_MAX,Cr_MAX,Cb_MAX),skin);
    cv::Mat array[3];
    cv::split(skin,array);
    cv::Mat y = array[0];
    cv::Mat cr = array[1];
    cv::Mat cb = array[02];
    /*cv::Mat HSV;
    cv::cvtColor(cvImage, HSV, cv::COLOR_RGB2HSV);
    cv::Mat Hue;
    Hue.create( HSV.size(), HSV.depth() );
    int ch[] = { 0, 0 };
    cv::mixChannels( &HSV, 1, &Hue, 1, ch, 1 );
    cv::MatND Hist;
    int histSize = MAX( 5, 2 );
    float hue_range[] = { 0, 180 };
    const float* ranges = { hue_range };
    cv::calcHist( &Hue, 1, 0, cv::Mat(), Hist, 1, &histSize, &ranges, true, false );
    cv::normalize( Hist, Hist, 0, 255, cv::NORM_MINMAX, -1, cv::Mat() );
    
    cv::MatND backproj;
    cv::calcBackProject( &Hue, 1, 0, Hist, backproj, &ranges, 1, true );
    cv::Mat hand;
    cv::threshold(backproj, hand, 150 , 255, CV_THRESH_BINARY | CV_THRESH_OTSU);
     */
    cv::Mat temp;
    y = 255 - y;
    cv::threshold(skin, skin, 128 , 255, CV_THRESH_BINARY | CV_THRESH_OTSU);
    cv::Mat Dist;
    cv::distanceTransform(y, Dist, CV_DIST_L2, 3);
    cv::normalize(Dist, Dist, 0, 1., cv::NORM_MINMAX);
    resultView_.hidden = false; // Turn the hidden view on
    UIImage *resImage = MatToUIImage(Dist);
        
    // Special part to ensure the image is rotated properly when the image is converted back
    resultView_.image =  [UIImage imageWithCGImage:[resImage CGImage]
                                                 scale:1.0
                                           orientation: UIImageOrientationLeftMirrored];
    [takephotoButton_ setHidden:true]; [goliveButton_ setHidden:false]; // Switch visibility of buttons

    


}
- (void)photoCameraCancel:(CvPhotoCamera *)photoCamera
{
    
}
//===============================================================================================
// Simple member function to initialize buttons in the bottom of the screen so we do not have to
// bother with storyboard, and can go straight into vision on mobiles
//
- (UIButton *) simpleButton:(NSString *)buttonName buttonColor:(UIColor *)color
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom]; // Initialize the button
    // Bit of a hack, but just positions the button at the bottom of the screen
    int button_width = 200; int button_height = 50; // Set the button height and width (heuristic)
    // Botton position is adaptive as this could run on a different device (iPAD, iPhone, etc.)
    int button_x = (self.view.frame.size.width - button_width)/2; // Position of top-left of button
    int button_y = self.view.frame.size.height - 80; // Position of top-left of button
    button.frame = CGRectMake(button_x, button_y, button_width, button_height); // Position the button
    [button setTitle:buttonName forState:UIControlStateNormal]; // Set the title for the button
    [button setTitleColor:color forState:UIControlStateNormal]; // Set the color for the title
    
    [self.view addSubview:button]; // Important: add the button as a subview
    //[button setEnabled:bflag]; [button setHidden:(!bflag)]; // Set visibility of the button
    return button; // Return the button pointer
}

//===============================================================================================
// Standard memory warning component added by Xcode
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
