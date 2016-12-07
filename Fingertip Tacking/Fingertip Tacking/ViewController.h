//
//  ViewController.h
//  Fingertip Tacking
//
//  Created by 刘淼 on 12/3/16.
//  Copyright © 2016 刘淼. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <opencv2/highgui/ios.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES1/gl.h>

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
#import "opencv2/highgui/ios.h"
#include "../include/glStateCache.h"
#endif

// Slightly changed things here to employ the CvVideoCameraDelegate
@interface ViewController : UIViewController<CvVideoCameraDelegate>
{
    CvVideoCamera *videoCamera; // OpenCV class for accessing the camera
}
// Declare internal property of videoCamera
@property (nonatomic, retain) CvVideoCamera *videoCamera;

@end


