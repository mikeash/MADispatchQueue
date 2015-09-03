//
//  MAThreadPool.m
//  MADispatch
//
//  Created by Michael Ash on 8/31/15.
//  Copyright © 2015 mikeash. All rights reserved.
//

#import "MAThreadPool.h"


@implementation MAThreadPool {
    NSCondition *_lock;
    
    NSUInteger _threadCount;
    NSUInteger _activeThreadCount;
    NSUInteger _threadCountLimit;
    
    NSMutableArray *_blocks;
}

- (id)init {
    if((self = [super init])) {
        _lock = [[NSCondition alloc] init];
        _blocks = [[NSMutableArray alloc] init];
        _threadCountLimit = 128;
    }
    return self;
}

- (void)addBlock: (dispatch_block_t)block {
    [_lock lock];
    
    [_blocks addObject: block];
    
    NSUInteger idleThreads = _threadCount - _activeThreadCount;
    if([_blocks count] > idleThreads && _threadCount < _threadCountLimit) {
        [NSThread detachNewThreadSelector: @selector(workerThreadLoop:) toTarget: self withObject: nil];
        _threadCount++;
    }
    
    [_lock signal];
    [_lock unlock];
}

- (void)workerThreadLoop: (id)ignore {
    [_lock lock];
    while(1) {
        while([_blocks count] == 0) {
            [_lock wait];
        }
        dispatch_block_t block = [_blocks firstObject];
        [_blocks removeObjectAtIndex: 0];
        _activeThreadCount++;
        [_lock unlock];
        
        block();
        
        [_lock lock];
        _activeThreadCount--;
    }
}

@end
