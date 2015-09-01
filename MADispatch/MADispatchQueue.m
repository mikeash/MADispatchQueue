//
//  MADispatchQueue.m
//  MADispatch
//
//  Created by Michael Ash on 8/31/15.
//  Copyright © 2015 mikeash. All rights reserved.
//

#import "MADispatchQueue.h"

#import "MAThreadPool.h"


enum State {
    SerialNotRunning,
    SerialRunning,
    Concurrent
};

@implementation MADispatchQueue {
    NSLock *_lock;
    NSMutableArray *_pendingBlocks;
    enum State _state;
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
        _pendingBlocks = [NSMutableArray array];
        _state = serial ? SerialNotRunning : Concurrent;
    }
    return self;
}

- (void)dispatchAsync: (dispatch_block_t)block {
    [_lock lock];
    [_pendingBlocks addObject: block];
    
    if(_state == Concurrent) {
        [self dispatchOneBlock];
    } else if (_state == SerialNotRunning) {
        _state = SerialRunning;
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
        
        [_lock lock];
        if (_state == SerialRunning) {
            if([_pendingBlocks count] > 0) {
                [self dispatchOneBlock];
            } else {
                _state = SerialNotRunning;
            }
        }
        [_lock unlock];
    }];
}

@end
