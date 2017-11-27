//
//  ViewController.m
//  spheroar
//
//  Created by 岡本 悠 on 2017/11/27.
//  Copyright © 2017年 岡本 悠. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <ARSCNViewDelegate>

@property (strong, nonatomic) IBOutlet ARSCNView *sceneView;

@property (strong, atomic) RKConvenienceRobot* robot;
@property (strong, nonatomic) IBOutlet UILabel *robotStatus;
@property (strong, nonatomic) IBOutlet UILabel *status;
@property (strong, nonatomic) IBOutlet UISlider *speed_bar;

@end

    
@implementation ViewController

RKDeviceSensorsAsyncData *sensorsAsyncData;
RKDeviceSensorsData *sensorsData;
RKAccelerometerData *accelerometerData;
RKAttitudeData *attitudeData;
RKQuaternionData *quaternionData;
RKLocatorData *locData;

- (void)viewDidLoad {
    [super viewDidLoad];

    // Set the view's delegate
    self.sceneView.delegate = self;
    
    // Show statistics such as fps and timing information
    self.sceneView.showsStatistics = YES;
    
    // Create a new scene
    SCNScene *scene = [SCNScene sceneNamed:@"art.scnassets/ship.scn"];
    
    // Set the scene to the view
    self.sceneView.scene = scene;
	
	//sphero
	[[RKRobotDiscoveryAgent sharedAgent] addNotificationObserver:self selector:@selector(handleRobotStateChangeNotification:)];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(appWillResignActive:)
												 name:UIApplicationWillResignActiveNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(appDidBecomeActive:)
												 name:UIApplicationDidBecomeActiveNotification
											   object:nil];
	// add a tap gesture recognizer
	UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
	NSMutableArray *gestureRecognizers = [NSMutableArray array];
	[gestureRecognizers addObject:tapGesture];
	[gestureRecognizers addObjectsFromArray:_sceneView.gestureRecognizers];
	_sceneView.gestureRecognizers = gestureRecognizers;

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Create a session configuration
    ARWorldTrackingConfiguration *configuration = [ARWorldTrackingConfiguration new];

    // Run the view's session
    [self.sceneView.session runWithConfiguration:configuration];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // Pause the view's session
    [self.sceneView.session pause];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

# pragma Sphero
- (void)appDidBecomeActive:(NSNotification*)n {
	[self startDiscovery];
}
- (void)sendSetDataStreamingCommand {
	// Requesting the Accelerometer X, Y, and Z filtered (in Gs)
	//            the IMU Angles roll, pitch, and yaw (in degrees)
	//            the Quaternion data q0, q1, q2, and q3 (in 1/10000) of a Q
	RKDataStreamingMask mask =  RKDataStreamingMaskAccelerometerFilteredAll |
	RKDataStreamingMaskIMUAnglesFilteredAll   |
	RKDataStreamingMaskQuaternionAll |
	RKDataStreamingMaskLocatorAll;
	[_robot enableSensors:mask atStreamingRate:10];
}
- (void)handleAsyncMessage:(RKAsyncMessage *)message forRobot:(id<RKRobotBase>)robot {
	// Need to check which type of async data is received as this method will be called for
	// data streaming packets and sleep notification packets. We are going to ingnore the sleep
	// notifications.
	if ([message isKindOfClass:[RKDeviceSensorsAsyncData class]]) {
		
		// Received sensor data, so display it to the user.
		sensorsAsyncData = (RKDeviceSensorsAsyncData *)message;
		sensorsData = [sensorsAsyncData.dataFrames lastObject];
		accelerometerData = sensorsData.accelerometerData;
		attitudeData = sensorsData.attitudeData;
		quaternionData = sensorsData.quaternionData;
		locData = sensorsData.locatorData;
//		NSLog(@"x:%f, y:%f", locData.position.x, locData.position.y);
		
	}
}
- (void)appWillResignActive:(NSNotification*)n {
	[RKRobotDiscoveryAgent stopDiscovery];
	[RKRobotDiscoveryAgent disconnectAll];
}

- (void)startDiscovery {
	[RKRobotDiscoveryAgent startDiscovery];
	NSLog(@"startDiscovery");
}
- (void)handleRobotStateChangeNotification:(RKRobotChangedStateNotification*)n {
	switch(n.type) {
		case RKRobotConnecting:
			_robotStatus.text = @"Connecting...";
			[self handleConnecting];
			break;
		case RKRobotOnline: {
			_robotStatus.text = @"Online";
			// Do not allow the robot to connect if the application is not running
			RKConvenienceRobot *convenience = [RKConvenienceRobot convenienceWithRobot:n.robot];
			if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
				[convenience disconnect];
				return;
			}
			self.robot = convenience;
			[self handleConnected];
			break;
		}
		case RKRobotDisconnected:
			_robotStatus.text = @"Disconnected";
			[self handleDisconnected];
			self.robot = nil;
			[RKRobotDiscoveryAgent startDiscovery];
			break;
		default:
			break;
	}
}

- (void)handleConnecting {
	// Handle robot connecting here
}

- (void)handleConnected {
	[_robot enableStabilization:NO];
	[_robot addResponseObserver:self];
	[self sendSetDataStreamingCommand];
}

- (void)handleDisconnected {
	// Handle robot disconnected here
}
- (void) handleTap:(UIGestureRecognizer*)gestureRecognize
{
	// retrieve the SCNView
	//    SCNView *scnView = (SCNView *)self.view;
	
	// check what nodes are tapped
	CGPoint p = [gestureRecognize locationInView:_sceneView];
	NSArray *hitResults = [_sceneView hitTest:p options:nil];
	
	double x_max = 315;
	double y_max = 530;
	// normalize
	double vx = p.x/(x_max/2.0) - 1.0;
	double vy = p.y/(y_max/2.0) - 1.0;
	double k = _speed_bar.value;//0.75*0.001;
	NSLog(@"slidar %f", k);
	double heading = atan2(vx,-vy)*180.0/3.141592;
	if(heading<0){
		heading += 360;
	}
	double vel = k*sqrt(vx*vx+vy*vy);
	[_robot driveWithHeading:heading andVelocity:vel];
	//    NSLog(@"tapped %f, %f, %f, %f",p.x,p.y,heading,vel);
	
	// check that we clicked on at least one object
	if([hitResults count] > 0){
		// retrieved the first clicked object
		SCNHitTestResult *result = [hitResults objectAtIndex:0];
		
		// get its material
		SCNMaterial *material = result.node.geometry.firstMaterial;
		
		// highlight it
		[SCNTransaction begin];
		[SCNTransaction setAnimationDuration:0.5];
		
		// on completion - unhighlight
		[SCNTransaction setCompletionBlock:^{
			[SCNTransaction begin];
			[SCNTransaction setAnimationDuration:0.5];
			
			material.emission.contents = [UIColor blackColor];
			
			[SCNTransaction commit];
		}];
		
		material.emission.contents = [UIColor redColor];
		
		[SCNTransaction commit];
	}
}


#pragma mark - ARSCNViewDelegate

/*
// Override to create and configure nodes for anchors added to the view's session.
- (SCNNode *)renderer:(id<SCNSceneRenderer>)renderer nodeForAnchor:(ARAnchor *)anchor {
    SCNNode *node = [SCNNode new];
 
    // Add geometry to the node...
 
    return node;
}
*/

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
    // Present an error message to the user
    
}

- (void)sessionWasInterrupted:(ARSession *)session {
    // Inform the user that the session has been interrupted, for example, by presenting an overlay
    
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    // Reset tracking and/or remove existing anchors if consistent tracking is required
    
}

@end
