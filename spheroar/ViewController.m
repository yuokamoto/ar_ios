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
@property (strong, nonatomic) IBOutlet UILabel *splight_title;
@property (strong, nonatomic) IBOutlet UILabel *splight_pos_title;
@property (strong, nonatomic) IBOutlet UILabel *splight_pos_x;
@property (strong, nonatomic) IBOutlet UISlider *splight_pos_x_slider;
@property (strong, nonatomic) IBOutlet UILabel *splight_pos_y;
@property (strong, nonatomic) IBOutlet UISlider *splight_pos_y_slider;
@property (strong, nonatomic) IBOutlet UILabel *splight_pos_z;
@property (strong, nonatomic) IBOutlet UISlider *splight_pos_z_slider;
@property (strong, nonatomic) IBOutlet UILabel *splight_pos_ex;
@property (strong, nonatomic) IBOutlet UISlider *splight_pos_ex_slider;
@property (strong, nonatomic) IBOutlet UILabel *splight_pos_ey;
@property (strong, nonatomic) IBOutlet UISlider *splight_pos_ey_slider;
@property (strong, nonatomic) IBOutlet UILabel *splight_pos_ez;
@property (strong, nonatomic) IBOutlet UISlider *splight_pos_ez_slider;

@property (strong, nonatomic) IBOutlet UILabel *splight_shadow_title;
@property (strong, nonatomic) IBOutlet UILabel *splight_shadow_a;
@property (strong, nonatomic) IBOutlet UISlider *splight_shadow_a_slider;
@property (strong, nonatomic) IBOutlet UILabel *splight_shadow_radius;
@property (strong, nonatomic) IBOutlet UISlider *splight_shadow_radius_slider;
@property (strong, nonatomic) IBOutlet UILabel *splight_shadow_count;
@property (strong, nonatomic) IBOutlet UISlider *splight_shadow_count_slider;

@property (strong, nonatomic) IBOutlet UILabel *amblight_title;
@property (strong, nonatomic) IBOutlet UILabel *amblight_intens;
@property (strong, nonatomic) IBOutlet UISlider *amblight_intens_slider;

@end

    
@implementation ViewController

RKDeviceSensorsAsyncData *sensorsAsyncData;
RKDeviceSensorsData *sensorsData;
RKAccelerometerData *accelerometerData;
RKAttitudeData *attitudeData;
RKQuaternionData *quaternionData;
RKLocatorData *locData;

float ball_radius = 0.0365;//0.2;
float offline_move_radius = 0.1;
float offline_move_freq = 0.3;
bool isVisible = false;

SCNScene *scene;
SCNMatrix4 plane_matrix;
SCNMatrix4 m_head_pre;
SCNMatrix4 m_ball_pre;
//SCNProgram *program;
//SCNProgram *program1;

- (void)viewDidLoad {
    [super viewDidLoad];

    // Set the view's delegate
    self.sceneView.delegate = self;

    // Show statistics such as fps and timing information
//    self.sceneView.showsStatistics = YES;
	
    // Create a new scene
	scene = [SCNScene sceneNamed:@"art.scnassets/bb-unit-obj/bb-unit-head.obj"];
	SCNScene *scene_head_vel = [SCNScene sceneNamed:@"art.scnassets/bb-unit-obj/bb-unit-head.obj"];
	[scene.rootNode addChildNode:scene_head_vel.rootNode.childNodes[0]];
	SCNScene *scene_ball = [SCNScene sceneNamed:@"art.scnassets/bb-unit-obj/bb-unit-ball.obj"];
	[scene.rootNode addChildNode:scene_ball.rootNode.childNodes[0]];
	SCNScene *scene_ball_vel = [SCNScene sceneNamed:@"art.scnassets/bb-unit-obj/bb-unit-ball.obj"];
	[scene.rootNode addChildNode:scene_ball_vel.rootNode.childNodes[0]];

	scene.rootNode.childNodes[0].name = @"head";
	scene.rootNode.childNodes[1].name = @"head_vel";
	scene.rootNode.childNodes[2].name = @"ball";
	scene.rootNode.childNodes[3].name = @"ball_vel";
//	NSLog(@"%@",(NSString *)scene.rootNode.childNodes);
	
	SCNProgram *program = [SCNProgram alloc];
	program.vertexFunctionName = @"velocity_vertex";
	program.fragmentFunctionName = @"velocity_fragment";
	SCNNode *ball_vel_node = [scene.rootNode childNodeWithName:@"ball_vel" recursively:YES];
	SCNNode *head_vel_node = [scene.rootNode childNodeWithName:@"head_vel" recursively:YES];
	head_vel_node.geometry.materials[1].program = program; //must
	head_vel_node.geometry.materials[0].program = program;
	ball_vel_node.geometry.materials[1].program = program; //must
	ball_vel_node.geometry.materials[0].program = program;
	
	// Set the scene to the view
    self.sceneView.scene = scene;
//	self.sceneView.debugOptions = ARSCNDebugOptionShowWorldOrigin;// | ARSCNDebugOptionShowFeaturePoints;
	self.sceneView.automaticallyUpdatesLighting = YES;

	plane_matrix =SCNMatrix4MakeTranslation(0,-0.5,-0.5);
	m_head_pre = SCNMatrix4Identity;
	m_ball_pre = SCNMatrix4Identity;
//	[self drawplanewithWidth:1.0 height:1.0 trans:&plane_matrix];
//	[self insertSpotLight:SCNVector3Make(0,2,0)];

	// create and add an ambient light to the scene
	SCNNode *ambientLightNode = [SCNNode node];
	ambientLightNode.light = [SCNLight light];
	ambientLightNode.name = @"amblight";
	ambientLightNode.light.type = SCNLightTypeAmbient;
	ambientLightNode.light.color = [UIColor whiteColor];
	ambientLightNode.light.intensity = 100.0;
	[scene.rootNode addChildNode:ambientLightNode];
	
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
	UILongPressGestureRecognizer *lpGesture = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(handleLongPress:)];
	[gestureRecognizers addObject:lpGesture];
	[gestureRecognizers addObjectsFromArray:_sceneView.gestureRecognizers];

	_sceneView.gestureRecognizers = gestureRecognizers;
	
	NSURL *url;
	url = [[NSBundle mainBundle] URLForResource:@"motion_blur" withExtension:@"plist"];
	NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfURL:url];
//		for (id key in [dictionary keyEnumerator]) {
//			NSLog(@"Key:%@ Value:%@", key, [dictionary valueForKey:key]);
//		}
	SCNTechnique *technique = [SCNTechnique techniqueWithDictionary:dictionary];
	
	_sceneView.technique = technique;

}

- (void)startNewSession{
	// Create a session configuration
	ARWorldTrackingConfiguration *configuration = [ARWorldTrackingConfiguration new];
	configuration.lightEstimationEnabled = YES;
	configuration.planeDetection = ARPlaneDetectionHorizontal;

	// Run the view's session
	[self.sceneView.session runWithConfiguration:configuration];
	
//	ARCamera *camera = self.sceneView.session.currentFrame.camera;
	
	
}
- (void)insertSpotLight:(SCNVector3)position {
	SCNNode *spotLightNode = [SCNNode new];
	spotLightNode.name = @"spotlight";
	spotLightNode.light = [SCNLight light];
	spotLightNode.light.type = SCNLightTypeSpot;
	spotLightNode.light.spotInnerAngle = 45;
	spotLightNode.light.spotOuterAngle = 45;
	//	spotLightNode.light.color = [UIColor colorWithWhite:1.0 alpha:0.5];
	spotLightNode.light.shadowMode = SCNShadowModeDeferred;
	spotLightNode.light.castsShadow = YES;
	spotLightNode.light.shadowBias = 1000;
	spotLightNode.light.shadowRadius = 10;
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
- (void)drawplanewithWidth:(float)w height:(float)h trans:(SCNMatrix4 *)mat {
	SCNPlane *geometry = [SCNPlane planeWithWidth:w height:h];
	SCNMaterial *material = [SCNMaterial new];
	material.diffuse.contents = [UIColor colorWithWhite:0.0 alpha:0.001];//
	//	UIImage *img = [UIImage imageNamed:@"art.scnassets/tron_grid"];
	//	material.diffuse.contents = img;
	geometry.firstMaterial = material;
	
	SCNNode *plane_node = [SCNNode nodeWithGeometry:geometry];
	plane_node.physicsBody = SCNPhysicsBody.staticBody;
	//	plane_node.position = SCNVector3Make(anchor.center.x,0,anchor.center.z);
	//	plane_node.transform = SCNMatrix4FromMat4(anchor.transform);
	plane_node.transform = SCNMatrix4Mult(SCNMatrix4MakeRotation(-M_PI/2.0, 1.0, 0.0, 0.0), *mat);
	
	
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
//	NSLog(@"slidar %f", k);
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
- (void) handleLongPress:(UIGestureRecognizer*)gestureRecognize
{
	if (gestureRecognize.state == UIGestureRecognizerStateBegan) {
//		NSLog(@"長押し開始のタイミング");
		SCNNode *splight_node = [scene.rootNode childNodeWithName:@"spotlight" recursively:YES];
//		splight_node.light.castsShadow = NO;
		
		bool visible =  !_speed_bar.isHidden;
		[_speed_bar setHidden:visible];
		[_splight_title setHidden:visible];
		[_splight_pos_title setHidden:visible];
		[_splight_pos_x setHidden:visible];
		[_splight_pos_x_slider setHidden:visible];
		[_splight_pos_y setHidden:visible];
		[_splight_pos_y_slider setHidden:visible];
		[_splight_pos_z setHidden:visible];
		[_splight_pos_z_slider setHidden:visible];
		[_splight_pos_ex setHidden:visible];
		[_splight_pos_ex_slider setHidden:visible];
		[_splight_pos_ey setHidden:visible];
		[_splight_pos_ey_slider setHidden:visible];
		[_splight_pos_ez setHidden:visible];
		[_splight_pos_ez_slider setHidden:visible];
		[_splight_shadow_title setHidden:visible];
		[_splight_shadow_a setHidden:visible];
		[_splight_shadow_a_slider setHidden:visible];
		[_splight_shadow_radius setHidden:visible];
		[_splight_shadow_radius_slider setHidden:visible];
		[_splight_shadow_count setHidden:visible];
		[_splight_shadow_count_slider setHidden:visible];
		[_amblight_title setHidden:visible];
		[_amblight_intens setHidden:visible];
		[_amblight_intens_slider setHidden:visible];
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
		//		_sceneView.scene.rootNode.simdTransform = anchor.transform;
		//		(ARPlaneAnchor *)anchor.position.x = 0;
//		[self drawplane:(ARPlaneAnchor *)anchor];
		[self drawplanewithWidth:((ARPlaneAnchor *)anchor).extent.x height:((ARPlaneAnchor *)anchor).extent.z trans:&plane_matrix];
		[self insertSpotLight:SCNVector3Make(0,2,0)];
		isVisible = true;
	}
	
}

- (void) renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time{
	SCNNode *ball_node = [scene.rootNode childNodeWithName:@"ball" recursively:YES];
	SCNNode *head_node = [scene.rootNode childNodeWithName:@"head" recursively:YES];
	SCNNode *ball_vel_node = [scene.rootNode childNodeWithName:@"ball_vel" recursively:YES];
	SCNNode *head_vel_node = [scene.rootNode childNodeWithName:@"head_vel" recursively:YES];
//	CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur" keysAndValues:@"inputRadius", @1.0f, nil];
//	NSArray *filter = [NSArray arrayWithObjects:blur];
//	[ball_node setFilters:filter];
	
	bool OFFLINE = true;//false;//
	if(OFFLINE){
		//ball matrix
		float zpos = offline_move_radius * sin(2*3.14*offline_move_freq*time);
		
		//ball matrix
		SCNMatrix4 ballMat = SCNMatrix4MakeRotation(zpos/ball_radius,1.0,0.0,0.0);
		ballMat = SCNMatrix4Translate(ballMat,0.0, ball_radius, zpos);
		
		//temp for motion blur check
//		ballMat = SCNMatrix4MakeTranslation(zpos, 0, 0);

		ball_node.transform =SCNMatrix4Mult(ballMat, plane_matrix);
		
		//head matrix
		SCNMatrix4 headMat = SCNMatrix4MakeTranslation(0.0, ball_radius, 0.0);
		headMat = SCNMatrix4Rotate(headMat, 0.25*3.14 * sin(2*3.14*offline_move_freq*time), 1.0, 0.0, 0.0);
		headMat = SCNMatrix4Translate(headMat,0.0, ball_radius, zpos);

		//temp for motion blur check
//		headMat = SCNMatrix4MakeTranslation(zpos, ball_radius*1.0, 0);

		head_node.transform = SCNMatrix4Mult(headMat, plane_matrix);

	}else{
		//        double deg2rad = 3.141592/180.0;
		double px = locData.position.x*0.01;
		double py = locData.position.y*0.01;
		SCNMatrix4 headMat = SCNMatrix4MakeTranslation(0.0, ball_radius, 0.0);
		headMat = SCNMatrix4Rotate(headMat, 2.0*acos(quaternionData.quaternions.q0),
								   -quaternionData.quaternions.q1,
								   -quaternionData.quaternions.q3,
								   quaternionData.quaternions.q2);
		headMat = SCNMatrix4Translate(headMat,-px, ball_radius, py);
		head_node.transform = SCNMatrix4Mult(headMat, plane_matrix);
		
		SCNMatrix4 ballMat = SCNMatrix4MakeRotation(py/ball_radius, 1.0, 0.0, 0.0);
		ballMat = SCNMatrix4Rotate(ballMat, px/ball_radius, 0.0, 0.0, 1.0);
		ballMat = SCNMatrix4Translate(ballMat,-px, ball_radius, py);
		ball_node.transform = SCNMatrix4Mult(ballMat, plane_matrix);
		//        ball_node.eulerAngles = SCNVector3Make(-attitudeData.pitch*deg2rad, attitudeData.yaw*deg2rad, attitudeData.roll*deg2rad);
		
	}
	
	float scale = 0.116;//0.0365/0.315; // coeffs for cg 2 real
	float scale_vel = scale*0.99;

	ball_node.scale = SCNVector3Make(scale,scale,scale);
	head_node.scale = SCNVector3Make(scale,scale,scale);
	
	//motion blur node
	head_vel_node.transform = head_node.transform;
	head_vel_node.scale =  SCNVector3Make(scale_vel,scale_vel,scale_vel);
	ball_vel_node.transform = ball_node.transform;
	ball_vel_node.scale =  SCNVector3Make(scale_vel,scale_vel,scale_vel);
	
	SCNMatrix4 m_head =  head_vel_node.transform;
	if(SCNMatrix4IsIdentity(m_head_pre)){
		m_head_pre = m_head;
	}
	NSValue *uniformdata_head = [NSValue valueWithSCNMatrix4:m_head_pre];
	[head_vel_node.geometry.materials[0] setValue:uniformdata_head forKey:@"vmvp"];
	[head_vel_node.geometry.materials[1] setValue:uniformdata_head forKey:@"vmvp"];
	
	m_head_pre = m_head;
	
	SCNMatrix4 m_ball =  ball_node.transform;
	if(SCNMatrix4IsIdentity(m_ball_pre)){
		m_ball_pre = m_ball;
	}
	NSValue *uniformdata_ball = [NSValue valueWithSCNMatrix4:m_ball_pre];
	[ball_vel_node.geometry.materials[0] setValue:uniformdata_ball forKey:@"vmvp"];
	[ball_vel_node.geometry.materials[1] setValue:uniformdata_ball forKey:@"vmvp"];

	m_ball_pre = m_ball;
	//	ARLightEstimate *estimate = _sceneView.session.currentFrame.lightEstimate;
//	if (!estimate) {
//		return;
//	}else{
//		CGFloat intensity = estimate.ambientIntensity / 1000.0;
////		NSLog(@"light %f", intensity);
////		scene.lightingEnvironment.intensity = intensity;
//	}
//	NSLog(@"light %f", scene.lightingEnvironment.intensity);
//	scene.lightingEnvironment.intensity = 1000.0;
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
			_status.text = @"Ready";
			break;
			//		if !chameleon.isVisible() {
			//			message = "Move to find a horizontal surface"
			//		}
	}
	
}
- (void)splight_pose_change{
	SCNNode *splight_node = [scene.rootNode childNodeWithName:@"spotlight" recursively:YES];
	NSLog(@"splight pos %f, %f, %f",_splight_pos_x_slider.value, _splight_pos_y_slider.value, _splight_pos_z_slider.value);
	splight_node.position = SCNVector3Make(_splight_pos_x_slider.value, _splight_pos_y_slider.value, _splight_pos_z_slider.value );
	splight_node.eulerAngles = SCNVector3Make(_splight_pos_ex_slider.value, _splight_pos_ey_slider.value, _splight_pos_ez_slider.value );

	splight_node.transform = SCNMatrix4Mult(splight_node.transform, plane_matrix);
}
- (IBAction)splight_pos_x_change:(id)sender {
	[self splight_pose_change];
}
- (IBAction)splight_pos_y_change:(id)sender {
	[self splight_pose_change];
}
- (IBAction)splight_pos_z_change:(id)sender {
	[self splight_pose_change];
}
- (IBAction)splight_pos_ex_change:(id)sender {
	[self splight_pose_change];
}
- (IBAction)splight_pos_ey_change:(id)sender {
	[self splight_pose_change];
}
- (IBAction)splight_pos_ez_change:(id)sender {
	[self splight_pose_change];
}
- (void)splight_shadow_param_change{
	SCNNode *splight_node = [scene.rootNode childNodeWithName:@"spotlight" recursively:YES];
	splight_node.light.shadowColor = [UIColor colorWithWhite:0.0 alpha:_splight_shadow_a_slider.value];
	splight_node.light.shadowRadius = (int)_splight_shadow_radius_slider.value;
	splight_node.light.shadowSampleCount = (int)_splight_shadow_count_slider.value;
}
- (IBAction)splight_shadow_a_change:(id)sender {
	[self splight_shadow_param_change];
}
- (IBAction)splight_shadow_radius_change:(id)sender {
	[self splight_shadow_param_change];
}
- (IBAction)splight_shadow_count_change:(id)sender {
	[self splight_shadow_param_change];
}
- (void)amblight_param_change{
	SCNNode *amblight_node = [scene.rootNode childNodeWithName:@"amblight" recursively:YES];
	amblight_node.light.intensity = _amblight_intens_slider.value;
}
- (IBAction)amblight_intens_change:(id)sender {
	[self amblight_param_change];
}
@end
