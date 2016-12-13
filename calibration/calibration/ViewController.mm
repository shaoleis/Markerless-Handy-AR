//
//  ViewController.m
//  calibration
//
//  Created by 刘淼 on 12/6/16.
//  Copyright © 2016 刘淼. All rights reserved.
//

#import "ViewController.h"

// Include stdlib.h and std namespace so we can mix C++ code in here
#include <stdlib.h>
//using namespace std;

@interface ViewController()
{
    UIImageView *imageView_;
    UIImageView *liveView_; // Live output from the camera
    UIImageView *resultView_; // Preview view of everything...
    UIButton *takephotoButton_, *goliveButton_; // Button to initiate OpenCV processing of image
    CvPhotoCamera *photoCamera_; // OpenCV wrapper class to simplfy camera access through AVFoundation
}
@end

@implementation ViewController
int count =0;
#define NUM_CHESS_POINT 48
#define NUM_CHESS_ROW   6
#define NUM_CHESS_COL   8
#define CHESS_CORNER_SIZE_MM    28.8
#define MAX_CALIBRATION_POINT   1000
float   camera_intrinsic[3][3];
float   camera_distortion[4];
cv::Mat imagearray[5];
int     calib_frame_count = 0;

std::vector<cv::Point2f> chess_pt(NUM_CHESS_POINT);
std::vector<std::vector<cv::Point2f>> calib_img_pt;
std::vector<std::vector<cv::Point3f>> calib_obj_pt;
//===============================================================================================
// Setup view for excuting App
- (void)viewDidLoad {
    [super viewDidLoad];
    /*UIImage *image = [UIImage imageNamed:@"chessboardpattern.jpg"];
    // 1. Setup the your OpenCV view, so it takes up the entire App screen......
    
    imageView_ = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width, self.view.frame.size.width * (image.size.height / image.size.width))];
    cv::Mat cvImage;
    UIImageToMat(image, cvImage);
    cv::findChessboardCorners(cvImage, cvSize(NUM_CHESS_COL, NUM_CHESS_ROW), chess_pt);
    std::cout << "estPts estPts " << chess_pt.size()<< " seconds." << std::endl;
    for (size_t i = 0; i < chess_pt.size(); i++)
    {
        cv::circle(cvImage, chess_pt[i], 3, cv::Scalar(0, 255, 0), 2);
    }
    // 2. Important: add OpenCV_View as a subview
    
    [self.view addSubview:imageView_];
    
    // 3.Read in the image (of the famous Lena)
    
    if(image != nil) imageView_.image = MatToUIImage(cvImage); // Display the image if it is there....
    */
    
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

    std::cout << "estPts estPts " << count<< " seconds." << std::endl;
    cv::Mat cvImage;
    UIImageToMat(image, cvImage);
    cv::Mat gray;
    cv::cvtColor(cvImage, gray, CV_BGR2GRAY);
    cv::findChessboardCorners(gray, cvSize(NUM_CHESS_COL, NUM_CHESS_ROW), chess_pt);
    for (size_t i = 0; i < chess_pt.size(); i++)
    {
        cv::circle(cvImage, chess_pt[i], 9, cv::Scalar(255, 0, 0), 2);
        cv::circle(cvImage, chess_pt[i], 9, cv::Scalar(0, 0, 255), 2);
        cv::circle(cvImage, chess_pt[i], 9, cv::Scalar(0, 255, 0), 2);
    }
    cv::circle(cvImage, cv::Point2f(0,640), 9, cv::Scalar(0, 0, 255), 2);
    int k = NUM_CHESS_POINT * count;
    
    for ( int i = 0 ; i < NUM_CHESS_ROW ; i ++ )
    {
        for ( int j = 0 ; j < NUM_CHESS_COL ; j ++ )
        {
            // object coordinates
            /*calib_obj_pt[k].x = (float)CHESS_CORNER_SIZE_MM * j;
            calib_obj_pt[k].y = (float)CHESS_CORNER_SIZE_MM * i;
            calib_obj_pt[k].z = 1;
            
            // image coordinates
            calib_img_pt[k].x = chess_pt[NUM_CHESS_COL * i + j].x;
            calib_img_pt[k].y = chess_pt[NUM_CHESS_COL * i + j].y;*/
            
            k ++;
        }
    }
    std::vector<cv::Point3f> obj;
    for(int i=0;i<NUM_CHESS_POINT;i++)
    {
        //calib_img_pt.push_back(chess_pt);
        obj.push_back(cv::Point3f(CHESS_CORNER_SIZE_MM * (i/NUM_CHESS_COL),CHESS_CORNER_SIZE_MM * (i%NUM_CHESS_COL),1));
        std::cout << "vDSP took " << i<< " seconds." << std::endl;
        std::cout << "vDSP took " << obj.at(i).x<< " seconds." << std::endl;
        std::cout << "vDSP took " << obj.at(i).y<< " seconds." << std::endl;
        std::cout << "vDSP took " << obj.at(i).z<< " seconds." << std::endl;
        std::cout << "vDSP took " << chess_pt.at(i).x<< " seconds." << std::endl;
        std::cout << "vDSP took " << chess_pt.at(i).y<< " seconds." << std::endl;

    }
    for(int i=0;i<NUM_CHESS_POINT;i++)
    {
        calib_obj_pt.push_back(obj);
        calib_img_pt.push_back(chess_pt);
    }
    count++;
    if (count>3)
    {
        int minH = 70, maxH = 160, minS = 70, maxS = 200, minV = 70, maxV = 250;
        
        cv::Mat hsv;
        cv::cvtColor(cvImage, hsv, CV_BGR2HSV);
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
        
        cv::drawContours(cvImage, contours, largestContour, cv::Scalar(0, 0, 255), 1);
         int t;
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
                cv::Point2f center = cv::Point(boundingBox.x + boundingBox.width / 2, boundingBox.y + boundingBox.height / 2);
                std::vector<cv::Point> validPoints;
                int thumb_flag =0;
                for (size_t i = 0; i < convexityDefects.size(); i++)
                {
                    
                    cv::Point p1 = contours[largestContour][convexityDefects[i][0]];
                    cv::Point p2 = contours[largestContour][convexityDefects[i][1]];
                    cv::Point p3 = contours[largestContour][convexityDefects[i][2]];
                    double angle = std::atan2(p1.y-center.y, p1.x-center.x )* 180 / CV_PI;
                    double inAngle = innerAngle(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);
                    double length = std::sqrt(std::pow(p1.x - p3.x, 2) + std::pow(p1.y - p3.y, 2));
                    if (angle < 179 && std::abs(inAngle) > 20 && std::abs(inAngle) < 80 && length > 0.1 * boundingBox.height)
                    {
                        t = validPoints.size();
                        
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
                std::cout << "vDSP took " << validPoints.size()<< " seconds." << std::endl;
                for (size_t i = 0; i < validPoints.size(); i++)
                {
                    cv::circle(cvImage, validPoints[i], 5, cv::Scalar(0, 255, 0), 2);
                }
                std::vector<cv::Point2f> proj_origin;
                cvImage = drawCoordinate(cvImage,validPoints);
            }
        }
        

    }

    resultView_.hidden = false; // Turn the hidden view on
    UIImage *resImage = MatToUIImage(cvImage);

    
    // Special part to ensure the image is rotated properly when the image is converted back
    resultView_.image =  [UIImage imageWithCGImage:[resImage CGImage]
                                             scale:1.0
                                       orientation: UIImageOrientationRight];
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
cv::Mat drawCoordinate(cv::Mat &image,std::vector<cv::Point> validPoints) {
    if (validPoints.size() >= 4) {
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
        //objpts[4] = cv::Point3f(0,12,1);
        imgpts[0] = cv::Point2f(validPoints.at(0).x,validPoints.at(0).y);
        imgpts[1] = cv::Point2f(validPoints.at(1).x,validPoints.at(1).y);
        imgpts[2] = cv::Point2f(validPoints.at(2).x,validPoints.at(2).y);
        imgpts[3] = cv::Point2f(validPoints.at(3).x,validPoints.at(3).y);
        //imgpts[4] = cv::Point2f(validPoints.at(4).x,validPoints.at(4).y);
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
    return image;
}
@end

