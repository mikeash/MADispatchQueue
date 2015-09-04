//
//  MADispatchQueue.m
//  MADispatch
//
//  Created by Michael Ash on 8/31/15.
//  Copyright © 2015 mikeash. All rights reserved.
//

#import "MADispatchQueue.h"

#import "MAThreadPool.h"


@implementation MADispatchQueue {
    NSLock *_lock;
    NSMutableArray *_pendingBlocks;
    BOOL _serial;
    BOOL _serialRunning;
}

static MADispatchQueue *gGlobalQueue;
static MAThreadPool *gThreadPool;

+ (void)initialize {
    if(self == [MADispatchQueue class]) {
        gGlobalQueue = [[MADispatchQueue alloc] initSerial: NO];
        gThreadPool = [[MAThreadPool alloc] init];
    }
}

+ (MADispatchQueue *)globalQueue {
    return gGlobalQueue;
}

- (id)initSerial: (BOOL)serial {
    if ((self = [super init])) {
        _lock = [[NSLock alloc] init];
        _pendingBlocks = [[NSMutableArray alloc] init];
        _serial = serial;
    }
    return self;
}

- (void)dispatchAsync: (dispatch_block_t)block {
    [_lock lock];
    [_pendingBlocks addObject: block];
    
    if(_serial && !_serialRunning) {
        _serialRunning = YES;
        [self dispatchOneBlock];
    } else if (!_serial) {
        [self dispatchOneBlock];
    }
    
    [_lock unlock];
}

- (void)dispatchSync: (dispatch_block_t)block {
    NSCondition *condition = [[NSCondition alloc] init];
    __block BOOL done = NO;
    [self dispatchAsync: ^{
        block();
        [condition lock];
        done = YES;
        [condition signal];
        [condition unlock];
    }];
    [condition lock];
    while (!done) {
        [condition wait];
    }
    [condition unlock];
}

- (void)dispatchOneBlock {
    [gThreadPool addBlock: ^{
        [_lock lock];
        dispatch_block_t block = [_pendingBlocks firstObject];
        [_pendingBlocks removeObjectAtIndex: 0];
        [_lock unlock];
        
        block();
        
        if(_serial) {
            [_lock lock];
            if([_pendingBlocks count] > 0) {
                [self dispatchOneBlock];
            } else {
                _serialRunning = NO;
            }
            [_lock unlock];
        }
    }];
}

@end
