//
//  MAThreadPool.h
//  MADispatch
//
//  Created by Michael Ash on 8/31/15.
//  Copyright © 2015 mikeash. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MAThreadPool : NSObject

- (void)addBlock: (dispatch_block_t)block;

@end
