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

double ball_radius = 0.0365;//0.2;
double offline_move_radius = 0.1;
double offline_move_freq = 0.3;
bool isVisible = false;

SCNNode *head_node;
SCNNode *ball_node;
SCNMatrix4 plane_matrix;

- (void)viewDidLoad {
    [super viewDidLoad];

    // Set the view's delegate
    self.sceneView.delegate = self;
    
    // Show statistics such as fps and timing information
    self.sceneView.showsStatistics = YES;
    
    // Create a new scene
	SCNScene *scene = [SCNScene sceneNamed:@"art.scnassets/bb-unit-obj/bb-unit-head.obj"];
	SCNScene *scene_ball = [SCNScene sceneNamed:@"art.scnassets/bb-unit-obj/bb-unit-ball.obj"];
	[scene.rootNode addChildNode:scene_ball.rootNode.childNodes[0]];
	
	scene.rootNode.childNodes[0].name = @"head";
	scene.rootNode.childNodes[1].name = @"ball";
	
	// retrieve the bb8 node
	head_node = [scene.rootNode childNodeWithName:@"head" recursively:YES];
	ball_node = [scene.rootNode childNodeWithName:@"ball" recursively:YES];

    // Set the scene to the view
    self.sceneView.scene = scene;
	self.sceneView.debugOptions = ARSCNDebugOptionShowWorldOrigin;// | ARSCNDebugOptionShowFeaturePoints;
	self.sceneView.automaticallyUpdatesLighting = YES;

	plane_matrix =SCNMatrix4MakeTranslation(0,-0.5,-0.5);

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

- (void)startNewSession{
	// Create a session configuration
	ARWorldTrackingConfiguration *configuration = [ARWorldTrackingConfiguration new];
	configuration.lightEstimationEnabled = YES;
	configuration.planeDetection = ARPlaneDetectionHorizontal;
	
	// Run the view's session
	[self.sceneView.session runWithConfiguration:configuration];
}
- (void)insertSpotLight:(SCNVector3)position {
	SCNNode *spotLightNode = [SCNNode new];
	spotLightNode.light = [SCNLight light];
	spotLightNode.light.type = SCNLightTypeSpot;
	spotLightNode.light.spotInnerAngle = 45;
	spotLightNode.light.spotOuterAngle = 45;
	//	spotLightNode.light.color = [UIColor colorWithWhite:1.0 alpha:0.5];
	spotLightNode.light.shadowMode = SCNShadowModeDeferred;
	spotLightNode.light.castsShadow = YES;
	spotLightNode.light.shadowBias = 1000;
	spotLightNode.light.shadowRadius = 100;
	spotLightNode.light.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.8];
	spotLightNode.light.shadowMapSize = CGSizeMake(4000, 4000);
	spotLightNode.light.shadowSampleCount = 1;
	spotLightNode.position = position;
	
	// By default the stop light points directly down the negative
	// z-axis, we want to shine it down so rotate 90deg around the
	// x-axis to point it down
	
	spotLightNode.eulerAngles = SCNVector3Make(-M_PI / 2, 0, 0);
	[_sceneView.scene.rootNode addChildNode: spotLightNode];
}
- (void)drawplane:(ARPlaneAnchor *)anchor {
	SCNPlane *geometry = [SCNPlane planeWithWidth:anchor.extent.x height:anchor.extent.z];
	SCNMaterial *material = [SCNMaterial new];
	material.diffuse.contents = [UIColor colorWithWhite:0.0 alpha:0.001];//
	//	UIImage *img = [UIImage imageNamed:@"art.scnassets/tron_grid"];
	//	material.diffuse.contents = img;
	geometry.firstMaterial = material;
	
	SCNNode *plane_node = [SCNNode nodeWithGeometry:geometry];
	plane_node.physicsBody = SCNPhysicsBody.staticBody;
	//	plane_node.position = SCNVector3Make(anchor.center.x,0,anchor.center.z);
	//	plane_node.transform = SCNMatrix4FromMat4(anchor.transform);
	plane_node.transform = SCNMatrix4Mult(SCNMatrix4MakeRotation(-M_PI/2.0, 1.0, 0.0, 0.0), SCNMatrix4FromMat4(anchor.transform));
	
	[_sceneView.scene.rootNode addChildNode:plane_node];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self startNewSession];
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

//// Override to create and configure nodes for anchors added to the view's session.
- (void)renderer:(id<SCNSceneRenderer>)renderer
	  didAddNode:(SCNNode *)node
	   forAnchor:(ARAnchor *)anchor {
	if(isVisible){
		return;
	}
	NSLog(@"%@", NSStringFromClass([anchor class]));
	if ([anchor isKindOfClass:[ARPlaneAnchor class]]){
		//		NSLog(@"%@", NSStringFromClass([anchor class]));
		plane_matrix = SCNMatrix4FromMat4(anchor.transform);
		//		head_node.transform = SCNMatrix4FromMat4(anchor.transform);
		//		NSLog(@"%f %f %f %f", head_node.transform.m11,head_node.transform.m12,
		//			  head_node.transform.m13,head_node.transform.m14);
		//		_sceneView.scene.rootNode.simdTransform = anchor.transform;
		//		(ARPlaneAnchor *)anchor.position.x = 0;
		[self drawplane:(ARPlaneAnchor *)anchor];
		[self insertSpotLight:SCNVector3Make(0,10,0)];
		isVisible = true;
	}
	
}

- (void) renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time{
	float scale = 0.116;//0.0365/0.315;
	float zpos = offline_move_radius * sin(2*3.14*offline_move_freq*time);
	
	//ball matrix
	SCNMatrix4 ballMat = SCNMatrix4MakeRotation(zpos/ball_radius,1.0,0.0,0.0);
	ballMat = SCNMatrix4Translate(ballMat,0.0, ball_radius, zpos);
	ball_node.transform = SCNMatrix4Mult(ballMat, plane_matrix);
	ball_node.scale = SCNVector3Make(scale,scale,scale);
	
	//head matrix
	SCNMatrix4 headMat = SCNMatrix4MakeTranslation(0.0, ball_radius, 0.0);
	headMat = SCNMatrix4Rotate(headMat, 0.25*3.14 * sin(2*3.14*offline_move_freq*time), 1.0, 0.0, 0.0);
	headMat = SCNMatrix4Translate(headMat,0.0, ball_radius, zpos);
	head_node.transform = SCNMatrix4Mult(headMat, plane_matrix);
	head_node.scale = SCNVector3Make(scale,scale,scale);
	
	ARLightEstimate *estimate = _sceneView.session.currentFrame.lightEstimate;
	if (!estimate) {
		return;
	}
	// TODO: Put this on the screen
	//	NSLog(@"light estimate: %f", estimate.ambientIntensity);
}

- (void) renderer:(id<SCNSceneRenderer>)renderer didApplyConstraintsAtTime:(NSTimeInterval) time{
}

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
	// Present an error message to the user
	
}

- (void)sessionWasInterrupted:(ARSession *)session {
	// Inform the user that the session has been interrupted, for example, by presenting an overlay
	_status.text = @"Session was interrupted";
	
}

- (void)sessionInterruptionEnded:(ARSession *)session {
	// Reset tracking and/or remove existing anchors if consistent tracking is required
	[self startNewSession];
	
}
- (void) session: (ARSession *)session cameraDidChangeTrackingState:(ARCamera *)camera {
	
	switch(camera.trackingState) {
		case ARTrackingStateNotAvailable:
			_status.text = @"Tracking not available";
			break;
		case ARTrackingStateLimited:
			switch(camera.trackingStateReason){
				case ARTrackingStateReasonInitializing:
					_status.text = @"Initializing AR session";
					break;
				case ARTrackingStateReasonExcessiveMotion:
					_status.text = @"Too much motion";
					break;
				case ARTrackingStateReasonInsufficientFeatures:
					_status.text = @"Not enough surface details";
					break;
				case ARTrackingStateReasonNone:
					_status.text = @"Limited by None";
					break;
				default:
					break;
			}
			break;
		case ARTrackingStateNormal:
			_status.text = @"";
			break;
			//		if !chameleon.isVisible() {
			//			message = "Move to find a horizontal surface"
			//		}
	}
	
}

@end
