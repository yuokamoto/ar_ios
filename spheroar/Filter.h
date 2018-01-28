//
//  Filter.h
//  spheroar
//
//  Created by 岡本 悠 on 2018/01/27.
//  Copyright © 2018年 岡本 悠. All rights reserved.
//

#ifndef Filter_h
#define Filter_h
#import <Foundation/Foundation.h>
@interface FirstOrderSystem : NSObject
- (bool) setFreq:(float) freq;
- (float) updateWithInput:(const float) input t: (const float) time;
@end


#endif /* Filter_h */
