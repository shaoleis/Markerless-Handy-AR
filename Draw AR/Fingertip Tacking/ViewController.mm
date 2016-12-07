//
//  ViewController.m
//  Fingertip Tacking
//
//  Created by 刘淼 on 12/3/16.
//  Copyright © 2016 刘淼. All rights reserved.
//


#import "ViewController.h"
#import <GLKit/GLKit.h>

#ifdef __cplusplus
#include "opencv2/features2d/features2d.hpp"
#include "opencv2/nonfree/features2d.hpp"
#include <opencv2/opencv.hpp>
#include <stdlib.h>
#include <iostream>
#include <fstream>
#include "fingertiptracking.h"
#include <cstdio>
#include <cstdlib>
#include <sys/stat.h>
#include <unistd.h>
#include <string>
#endif

@interface ViewController(){
    UIImageView *imageView_; // Setup the image view
    UITextView *fpsView_; // Display the current FPS
    int64 curr_time_; // Store the current time
    cv::Mat intrinsics;
    cv::Mat distCoeffs;
    std::vector< cv::Point3f > vertices;
    std::vector< cv::Point2i> lines;
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
    
    // Initial view
//    UIImage *imageFromFile = [UIImage imageNamed: @"Iris.png"];
//    UIImage *imageToDraw = [ViewController imageWithImage:imageFromFile scaledToSize:CGSizeMake(view_width, view_height)];
//    imageView_ = [[UIImageView alloc] initWithImage:imageToDraw];
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
    
    // load file
    NSString *str = [[NSBundle mainBundle] pathForResource:@"bunny" ofType:@"obj"];
    const char *fileName = [str UTF8String]; // Convert to const char *
    bool res = loadOBJ(fileName, vertices, lines);

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
    std::vector<cv::Point3f> proj_corners(4); // realPos with z=0
    std::vector<cv::Point2f> scene_proj_corners(4);
    std::vector<cv::Point2f> scene_corners(4); // calculated from realPos, using Homography
    
    // template_im i.e. real object positions, assume now,
    // replace with hand bounding box later
    std::vector<cv::Point> realPos(4);
    realPos[0] = cvPoint( 0,  0);
    realPos[1] = cvPoint(200,  0);
    realPos[2] = cvPoint(200, 100);
    realPos[3] = cvPoint( 0, 100);
    

    
    float x = 12.0*3;
    float y = 38.5*3;
    float w = 20*3;
    float h = -20.0*3;
    
    for (int i = 0; i < 4; i++) {
        proj_corners[i] = cv::Point3f(realPos[i].x, realPos[i].y, 0);
    }
    
    // calculated from realPos, using Homography
    scene_corners[0] = cv::Point2f(43,360);
    scene_corners[1] = cv::Point2f(353,419);
    scene_corners[2] = cv::Point2f(371,291);
    scene_corners[3] = cv::Point2f(137,262);
    
    
    //either solve with scene_corners or estPts
    cv::solvePnP(proj_corners, scene_corners, intrinsics, distCoeffs, rvec, tvec);
    
    std::vector<cv::Point3f> cube_corners(8);
    //real cube pos in 3D
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
    
    // Draw lines of projected realPos
    cv::line( image, scene_proj_corners[0], scene_proj_corners[1], cv::Scalar(255, 0, 0), 1 );
    cv::line( image, scene_proj_corners[1], scene_proj_corners[2], cv::Scalar(255, 0, 255), 1 );
    cv::line( image, scene_proj_corners[2], scene_proj_corners[3], cv::Scalar(255, 0, 0), 1 );
    cv::line( image, scene_proj_corners[3], scene_proj_corners[0], cv::Scalar(255, 0, 255), 1 );
    
    // patch size is the same for cube
    cv::Rect patch(0,0,w,w);
    [self drawCube:image:cube_proj_corners:patch];
    [self drawBunny: image: rvec: tvec];
    
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

- (void) drawCube: (cv::Mat &) image: (std::vector<cv::Point2f>) cube_proj_corners: (cv::Rect) patch
{
    int seq1[] = {0,4,3,7};
    [self helperDrawCube:image :@"p1.png" :cube_proj_corners :patch: seq1];
    int seq2[] = {1,5,0,4};
    [self helperDrawCube:image :@"p2.png" :cube_proj_corners :patch: seq2];
    int seq3[] = {4,5,7,6};
    [self helperDrawCube:image :@"p3.png" :cube_proj_corners :patch: seq3];
    

#ifdef DEBUG
    for (int i = 0; i < 8; i++) {
        std::cout<<cube_proj_corners[i]<<std::endl;
        cv::circle(image, cube_proj_corners[i], 10, cv::Scalar(255, 0, 255));
    }

    // draw wireframe
    for (int i=0; i<5; i+=4) {
        
        cv::line(image, cube_proj_corners[0+i], cube_proj_corners[1+i], cv::Scalar(255, 0, 255), 1);
        cv::line(image, cube_proj_corners[1+i], cube_proj_corners[2+i], cv::Scalar(0, 0, 255), 1);
        cv::line(image, cube_proj_corners[2+i], cube_proj_corners[3+i], cv::Scalar(0, 0, 255), 1);
        cv::line(image, cube_proj_corners[3+i], cube_proj_corners[0+i], cv::Scalar(0, 0, 255), 1);
    }
    
    cv::line(image, cube_proj_corners[0], cube_proj_corners[4], cv::Scalar(0, 0, 255), 1);
    cv::line(image, cube_proj_corners[1], cube_proj_corners[5], cv::Scalar(0, 0, 255), 1);
    cv::line(image, cube_proj_corners[2], cube_proj_corners[6], cv::Scalar(0, 0, 255), 1);
    cv::line(image, cube_proj_corners[3], cube_proj_corners[7], cv::Scalar(0, 0, 255), 1);
#endif
    
}

-(void)helperDrawCube:(cv::Mat &) image: (NSString *)file: (std::vector<cv::Point2f>) cube_proj_corners:(cv::Rect) patch: (int []) seq {
    UIImage *imageToDraw = [UIImage imageNamed: file];
    cv::Mat matImageToDraw = [self cvMatFromUIImage:imageToDraw];
    cv::Mat temp, temp2;
    cv::resize(matImageToDraw, temp, cv::Size(patch.width, patch.height));
    for (int i=0;i<3;i++) {
        cv::GaussianBlur(temp, temp2, cv::Size(0, 0), 3);
        cv::addWeighted(temp, 1.5, temp2, -0.5, 0, temp);
    }
    cv::Mat patchToDraw = cv::Mat(temp, patch).clone();
    std::vector<cv::Point2f> p_proj(4);
    std::vector<cv::Point2f> p_pts(4);
    p_proj[0] =  cube_proj_corners[seq[0]];
    p_pts[0] = cv::Point2f(0,0);
    p_proj[1] = cube_proj_corners[seq[1]];
    p_pts[1] = cv::Point2f(patchToDraw.cols, 0);
    p_proj[2] = cube_proj_corners[seq[2]];
    p_pts[2] = cv::Point2f(0, patchToDraw.rows);
    p_proj[3] = cube_proj_corners[seq[3]];
    p_pts[3] = cv::Point2f(patchToDraw.cols, patchToDraw.rows);
    
    // draw patch
    cv::cvtColor(patchToDraw, patchToDraw, CV_BGR2BGRA);
    overlay_image(image, patchToDraw, p_pts, p_proj);

}


- (void) drawBunny: (cv::Mat &) image: (cv::Mat)rvec: (cv::Mat)tvec {
        std::vector<cv::Point2f> obj_pts;
        cv::projectPoints(vertices, rvec, tvec, intrinsics, distCoeffs, obj_pts);
    
        // set color BGR
        const cv::Scalar pts_clr = cv::Scalar(255,0,0);
    
        // draw points
        for(int i=0; i<obj_pts.size(); i++) {
            cv::circle(image, obj_pts[i], 0.5, pts_clr, 0); // Draw the points
        }
        std::cout << obj_pts.size() << std::endl;
    
//        // draw lines
//        for (int i=0; i<lines.size(); i++) {
//            cv::line(image, obj_pts[lines[i].x], obj_pts[lines[i].y], pts_clr);
//        }
}



bool loadOBJ(
             const char * path,
             std::vector < cv::Point3f > & out_vertices,
             std::vector < cv::Point2i> & lines
             ){
    std::vector< unsigned int > vertexIndices, uvIndices, normalIndices;
    std::vector< cv::Point3f > temp_vertices;
    std::vector< cv::Point2f > temp_uvs;
    std::vector< cv::Point3f > temp_normals;
    
    FILE * file = std::fopen(path, "r");
    if( file == NULL ){
        printf("Impossible to open the file !\n");
        return false;
    }
    
    while( 1 ){
        
        char lineHeader[128];
        // read the first word of the line
        int res = fscanf(file, "%s", lineHeader);
        if (res == EOF)
            break; // EOF = End Of File. Quit the loop.
        
        // else : parse lineHeader
        if ( strcmp( lineHeader, "v" ) == 0 ){
            cv::Point3f vertex;
            fscanf(file, "%f %f %f\n", &vertex.x, &vertex.y, &vertex.z );
            temp_vertices.push_back(vertex);
        }else if ( strcmp( lineHeader, "f" ) == 0 ){
            std::string vertex1, vertex2, vertex3;
            unsigned int vertexIndex[3];
            int matches = fscanf(file, "%d %d %d\n", &vertexIndex[0], &vertexIndex[1], &vertexIndex[2] );
            lines.push_back(cv::Point2i(vertexIndex[0], vertexIndex[1]));
            lines.push_back(cv::Point2i(vertexIndex[1], vertexIndex[2]));
            lines.push_back(cv::Point2i(vertexIndex[2], vertexIndex[0]));
        }
    }
    
    // For each vertex of each triangle
    for( unsigned int i=0; i<temp_vertices.size(); i++ ){
        cv::Point3f vertex = (temp_vertices[ i ] + cv::Point3f(0.1,0.1,0.1))*500;
        out_vertices.push_back(vertex);
    }
    return true;
}

void overlay_image(cv::Mat image, cv::Mat square, std::vector<cv::Point2f> sq_pts, std::vector<cv::Point2f> sq_proj){
    cv::Point2f x = sq_proj[1] - sq_proj[0];
    cv::Point2f y = sq_proj[2] - sq_proj[0];
    if(x.x*y.y - x.y*y.x < 0){
        cv::Mat H = cv::findHomography(sq_pts, sq_proj);
        cv::warpPerspective(square, square, H, image.size());
        cv::Mat square_gray, mask, mask_inv, roi, mask_fg, mask_bg;
        image.copyTo(roi);
        
        //Now create a mask of logo and create its inverse mask also
        cv::cvtColor(square, square_gray, CV_BGR2GRAY);
        cv::threshold(square_gray, mask, 1, 255, cv::THRESH_BINARY);
        cv::bitwise_not(mask, mask_inv);
        
        //Now black-out the area of logo in ROI
        cv::bitwise_and(roi,roi, mask_bg, mask_inv);
        
        //Take only region of logo from logo image.
        cv::bitwise_and(square, square, mask_fg, mask);
        
        //Put logo in ROI and modify the main image
        cv::add(mask_bg, mask_fg, image);
    }
}


// Member functions for converting from cvMat to UIImage
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

+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    //UIGraphicsBeginImageContext(newSize);
    // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
    // Pass 1.0 to force exact pixel size.
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

@end
