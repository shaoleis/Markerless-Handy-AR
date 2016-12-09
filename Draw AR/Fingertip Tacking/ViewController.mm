//
//  ViewController.m
//  Fingertip Tacking
//
//  Created by Miao Liu on 12/3/16.
//  Copyright © 2016 Miao Liu. All rights reserved.
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
#include "math.h"
#endif

@interface ViewController(){
    UIImageView *imageView_; // Setup the image view
    UITextView *fpsView_; // Display the current FPS
    int64 curr_time_; // Store the current time
    cv::Mat intrinsics;
    cv::Mat distCoeffs;
    std::vector< cv::Point3f > vertices;
    std::vector< cv::Point2i> lines;
    int frame;
    int zoom;
    cv::Rect previousBox;
    cv::vector<cv::KeyPoint> template_keypoints;
    cv::Mat template_im, template_gray, template_copy;
    cv::Mat template_descriptor;

    cv::SurfFeatureDetector *detector_; // Set the SURF Detector
    cv::SurfDescriptorExtractor *extractor_; // Set the SURF Extractor
    std::vector<cv::Point2f> obj_corners;
    std::vector<cv::Point> previouspoints;
    std::vector<cv::Point> recordPts;
    std::vector<cv::Point2f> proj_origin;  
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
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480;
    
    // Finally add the FPS text to the view
    fpsView_ = [[UITextView alloc] initWithFrame:CGRectMake(0,15,view_width,std::max(offset,35))];
    [fpsView_ setOpaque:false]; // Set to be Opaque
    [fpsView_ setBackgroundColor:[UIColor clearColor]]; // Set background color to be clear
    [fpsView_ setTextColor:[UIColor redColor]]; // Set text to be RED
    [fpsView_ setFont:[UIFont systemFontOfSize:18]]; // Set the Font size
    [self.view addSubview:fpsView_];
    
    // AR
    // Intrinsic matrix and distortion coefficients
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
    
    // load obj file
    NSString *str = [[NSBundle mainBundle] pathForResource:@"bunny" ofType:@"obj"];
    const char *fileName = [str UTF8String]; // Convert to const char *
    bool res = loadOBJ(fileName, vertices, lines);

    // start camera
    [videoCamera start];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Function to run apply image on
- (void) processImage:(cv:: Mat &)image
{
    // calculate hand bounding box
    std::vector<cv::Point> validPoints;
    cv::Rect boundingBox;
    validPoints = Tracking(image, boundingBox);
    std::vector<cv::Point2f> output;

 #ifdef DEBUG   
    for (size_t i = 0; i < previouspoints.size(); i++)
    {
        cv::circle(image, previouspoints[i], 9, cv::Scalar(0, 0, 255), 2);
    }
#endif

    for (size_t i = 0; i < validPoints.size() - 2; i++)
    {
        if (previouspoints.size()>0)
        {
            if (Edist(validPoints[i].x, validPoints[i].y, previouspoints[i].x, previouspoints[i].y) <200)
            {
                validPoints[i] =previouspoints[i];
            }
        }
        #ifdef DEBUG
            cv::circle(image, validPoints[i], 9, cv::Scalar(0, 255, 0), 2);
        #endif
    }

    previouspoints = validPoints;
    previouspoints.pop_back();
    previouspoints.pop_back();
    size_t last = validPoints.size();
    int width = validPoints[last-1].x;
    int height = validPoints[last-1].y;
    double cornerX = validPoints[last-2].x;
    double cornerY = validPoints[last-2].y;
    cv::Point center;
    boundingBox.x = cornerX;
    boundingBox.y = cornerY;
    boundingBox.width = width;
    boundingBox.height = height;
    center.x = cornerX + width/2;
    center.y = cornerY + height/2;
    previousBox = boundingBox;
    
    
    // Add AR

    // draw final AR
    double scale = 0.5;
    if (validPoints.size() > 2) {
        output = draw_Pred_Coordinate(image,boundingBox,validPoints,0,zoom);
        //draw
        //[self drawCube:image:output:scale];
        [self drawBunny: image:output:scale];
        if (zoom > 20) {
            scale = 0.6;
        } else {
            scale = 0.5;
        }
    } else {
        zoom++;
    }
    if (zoom > 50) {
        zoom = 0;
    }
    //printf("zoom %d\n",zoom);
}

/*
 drawCube function:
 image: image view, draw AR on it.
 info : info[0]: x axis point; info[1]: y; info[2]:z; info[3]:center
 scale: scale to draw the object
 */
- (void) drawCube: (cv::Mat &) image: (std::vector<cv::Point2f>) info: (double) scale
{
    cv::Mat rvec, tvec; // rotation vector, translation vector
    std::vector<cv::Point3f> proj_corners(4);
    std::vector<cv::Point2f> scene_corners(4); 
    
    // used to define cube 3d positions
    float w = 60;
    
    // absolute coordinates
    proj_corners[0] = cv::Point3f(1,0,0);
    proj_corners[1] = cv::Point3f(0,1,0);
    proj_corners[2] = cv::Point3f(0,0,1);
    proj_corners[3] = cv::Point3f(0,0,0);
    
    // coordinates on the camera scene
    scene_corners = info;

    // sove for rvec and tvec
    cv::solvePnP(proj_corners, scene_corners, intrinsics, distCoeffs, rvec, tvec);

    //real cube pos in 3D
    std::vector<cv::Point3f> cube_corners(8);
    cube_corners[0] = cv::Point3f(-scale/2, -scale/2, scale/2);
    cube_corners[1] = cv::Point3f(-scale/2, -scale/2, -scale/2);
    cube_corners[2] = cv::Point3f(-scale/2, scale/2, -scale/2);
    cube_corners[3] = cv::Point3f(-scale/2, scale/2, scale/2);
    cube_corners[4] = cv::Point3f(scale/2, -scale/2, scale/2);
    cube_corners[5] = cv::Point3f(scale/2, -scale/2, -scale/2);
    cube_corners[6] = cv::Point3f(scale/2, scale/2, -scale/2);
    cube_corners[7] = cv::Point3f(scale/2, scale/2, scale/2);

    // project cube to scene
    std::vector<cv::Point2f> cube_proj_corners;
    cv::projectPoints(cube_corners, rvec, tvec, intrinsics, distCoeffs, cube_proj_corners);
       
    // patch size is the same for cube
    cv::Rect patch(0,0,w,w);
    
    // draw patch
    int seq1[] = {0,4,3,7};
    [self helperDrawCube:image :@"p1.png" :cube_proj_corners :patch: seq1];
    int seq2[] = {1,5,0,4};
    [self helperDrawCube:image :@"p2.png" :cube_proj_corners :patch: seq2];
    int seq3[] = {4,5,7,6};
    [self helperDrawCube:image :@"p3.png" :cube_proj_corners :patch: seq3];
    int seq4[] = {1,0,2,3};
    [self helperDrawCube:image :@"p4.png" :cube_proj_corners :patch: seq4];
    int seq5[] = {3,7,2,6};
    [self helperDrawCube:image :@"p5.png" :cube_proj_corners :patch: seq5];
    int seq6[] = {2,6,1,5};
    [self helperDrawCube:image :@"p6.png" :cube_proj_corners :patch: seq6];

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

// helper function to draw patch on the cube
-(void)helperDrawCube:(cv::Mat &) image: (NSString *)file: (std::vector<cv::Point2f>) cube_proj_corners:(cv::Rect) patch: (int []) seq {
    UIImage *imageToDraw = [UIImage imageNamed: file];
    cv::Mat matImageToDraw = [self cvMatFromUIImage:imageToDraw];
    cv::Mat temp, temp2;
    cv::resize(matImageToDraw, temp, cv::Size(patch.width, patch.height));

    // try to improve resolution
    for (int i=0;i<3;i++) {
        cv::GaussianBlur(temp, temp2, cv::Size(0, 0), 3);
        cv::addWeighted(temp, 1.5, temp2, -0.5, 0, temp);
    }

    // draw patch
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
    
    
    cv::cvtColor(patchToDraw, patchToDraw, CV_BGR2BGRA);
    overlay_image(image, patchToDraw, p_pts, p_proj);

}

/*
draw model from obj file, not restrict to stanford bunny
*/
- (void) drawBunny:(cv::Mat &) image: (std::vector<cv::Point2f>) info: (double) scale {
    std::vector<cv::Point2f> obj_pts;
    cv::Mat rvec, tvec; // rotation vector, translation vector
    std::vector<cv::Point3f> proj_corners(4);
    std::vector<cv::Point2f> scene_corners(4);
    
    proj_corners[0] = cv::Point3f(1,0,0);
    proj_corners[1] = cv::Point3f(0,1,0);
    proj_corners[2] = cv::Point3f(0,0,1);
    proj_corners[3] = cv::Point3f(0,0,0);
    
    scene_corners = info;
    cv::solvePnP(proj_corners, scene_corners, intrinsics, distCoeffs, rvec, tvec);
    cv::projectPoints(vertices, rvec, tvec, intrinsics, distCoeffs, obj_pts);
    
    // set color BGR
    const cv::Scalar pts_clr = cv::Scalar(0,255,0);

    // draw points
    for(int i=0; i<obj_pts.size(); i++) {
        cv::circle(image, obj_pts[i], 1, pts_clr, 0); // Draw the points
    }
    // std::cout << obj_pts.size() << std::endl;  
}

/*
helper function to load obj file.
*/
bool loadOBJ(const char * path,
             std::vector < cv::Point3f > & out_vertices,
             std::vector < cv::Point2i> & lines ){
    std::vector< unsigned int > vertexIndices, uvIndices, normalIndices;
    std::vector< cv::Point3f > temp_vertices;
    std::vector< cv::Point2f > temp_uvs;
    std::vector< cv::Point3f > temp_normals;
    
    FILE * file = std::fopen(path, "r");
    if( file == NULL ){
        printf("Cannot open the file !\n");
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
    
    // For different model, need to change scale
    for( unsigned int i=0; i<temp_vertices.size(); i++ ){
        // for bunny
        cv::Point3f vertex = temp_vertices[ i ]*8;
//        // for teapot
//        cv::Point3f vertex = temp_vertices[ i ]*0.2;
        out_vertices.push_back(vertex);
    }
    return true;
}

/*
helper function to overlay patch to cube
*/
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

@end
