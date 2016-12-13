//
//  ViewController.h
//  calibration
//
//  Created by 刘淼 on 12/6/16.
//  Copyright © 2016 刘淼. All rights reserved.
//
#import <UIKit/UIKit.h>

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
#import "opencv2/highgui/ios.h"
#endif

@interface ViewController : UIViewController<CvPhotoCameraDelegate>

@end
