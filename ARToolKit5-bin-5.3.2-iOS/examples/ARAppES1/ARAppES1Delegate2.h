@class BaseViewController;

@interface ARAppES1Delegate2 : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    BaseViewController *baseviewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet BaseViewController *baseviewController;

@end