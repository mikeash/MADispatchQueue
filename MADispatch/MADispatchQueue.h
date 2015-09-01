//
//  MADispatchQueue.h
//  MADispatch
//
//  Created by Michael Ash on 8/31/15.
//  Copyright © 2015 mikeash. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MADispatchQueue : NSObject

+ (MADispatchQueue *)globalQueue;

- (id)initSerial: (BOOL)serial;

- (void)dispatchAsync: (dispatch_block_t)block;
- (void)dispatchSync: (dispatch_block_t)block;

@end
