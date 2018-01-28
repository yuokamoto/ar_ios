//
//  FIlter.m
//  spheroar
//
//  Created by 岡本 悠 on 2018/01/27.
//  Copyright © 2018年 岡本 悠. All rights reserved.
//

#import "Filter.h"

@interface FirstOrderSystem ()
@property (nonatomic) float omega;
@property (nonatomic) float prev_output;
@property (nonatomic) float prev_time;
@end

@implementation FirstOrderSystem

- (id)init {
	if((self = [super init]))
	{
		_prev_time = -1;
	}
	return self;
}

- (bool) setFreq:(float) freq{
	if(freq<0 || freq<1e-6){
		return false;
	}
	_omega = 2.0*M_PI*freq;
	return true;
}
- (float) updateWithInput:(const float) input t: (const float) time{
	//initialize
	if(_prev_time<0){
		_prev_output = input;
		_prev_time = time;
		return _prev_output;
	}
	const double dt = time - _prev_time;
	//skip if duration is too short
	if(dt<1e-6){
		return _prev_output;
	}
	const double tau = 1.0/(1.0+1.0/(dt*_omega));
	const double output = tau*input + (1-tau)*_prev_output;
	_prev_output = output;
	_prev_time = time;
	return output;
}

@end
