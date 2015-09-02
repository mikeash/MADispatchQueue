//
//  main.m
//  MADispatch
//
//  Created by Michael Ash on 8/31/15.
//  Copyright © 2015 mikeash. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MADispatchQueue.h"


int testHarness__totalFailures = 0;

#define TEST(name, code) do { \
        NSLog(@"Running test %s", #name); \
        __block int testHarness__testFailures = 0; \
        code; \
        NSLog(@"%s Done running test %s, %d failure%s", testHarness__testFailures > 0 ? "FAILURE:" : "Success!", #name, testHarness__testFailures, testHarness__testFailures == 1 ? "" : "s"); \
        testHarness__totalFailures += testHarness__testFailures; \
    } while(0)

#define FAIL(...) testHarness__testFailures++, NSLog(@"Failed: " __VA_ARGS__)

#define ASSERT(expr) do { if(!(expr)) FAIL("assertion %s", #expr); } while(0)

static void Test(void);

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Test();
        
        if(testHarness__totalFailures > 0) {
            NSLog(@"TESTS FAILED. %d total failed assertion%s", testHarness__totalFailures, testHarness__totalFailures == 1 ? "" : "s");
        } else {
            NSLog(@"Tests passed!");
        }
    }
    return 0;
}

static void AtomicMax(volatile int32_t *intPtr, int32_t new) {
    while(1) {
        int32_t current = *intPtr;
        if(current >= new) {
            return;
        }
        
        BOOL success = OSAtomicCompareAndSwap32(current, new, intPtr);
        if(success) {
            return;
        }
    }
}

static void Test(void) {
    TEST(async, {
        MADispatchQueue *queue = [[MADispatchQueue alloc] initSerial: YES];
        NSConditionLock *lock = [[NSConditionLock alloc] initWithCondition: 0];
        [queue dispatchAsync: ^{
            [lock lock];
            [lock unlockWithCondition: 1];
        }];
        BOOL success = [lock lockWhenCondition: 1 beforeDate: [NSDate dateWithTimeIntervalSinceNow: 10]];
        if (success) {
            [lock unlock];
        }
        ASSERT(success);
    });
    
    TEST(sync, {
        MADispatchQueue *queue = [[MADispatchQueue alloc] initSerial: YES];
        __block BOOL done = NO;
        [queue dispatchSync: ^{
            usleep(500000);
            done = YES;
        }];
        ASSERT(done);
    });
    
    TEST(serial, {
        MADispatchQueue *queue = [[MADispatchQueue alloc] initSerial: NO];
        [queue dispatchAsync: ^{
            usleep(500000);
        }];
        
        __block int32_t activeCount = 0;
        __block int32_t maxActiveCount = 0;
        __block int32_t totalRun = 0;
        
        for(int i = 0; i < 10000; i++) {
            [queue dispatchSync: ^{
                int32_t active = OSAtomicIncrement32(&activeCount);
                AtomicMax(&maxActiveCount, active);
                usleep(100);
                OSAtomicDecrement32(&activeCount);
                
                int32_t runSoFar = OSAtomicIncrement32(&totalRun);
                ASSERT(runSoFar == i + 1);
            }];
        }
        
        [queue dispatchSync: ^{}];
        ASSERT(maxActiveCount == 1);
        ASSERT(totalRun == 10000);
    });
    
    TEST(concurrent, {
        MADispatchQueue *queue = [[MADispatchQueue alloc] initSerial: NO];
        
        __block int32_t activeCount = 0;
        __block int32_t maxActiveCount = 0;
        __block volatile int32_t totalRun = 0;
        
        for(int i = 0; i < 10000; i++) {
            [queue dispatchAsync: ^{
                int32_t active = OSAtomicIncrement32(&activeCount);
                AtomicMax(&maxActiveCount, active);
                usleep(10000);
                OSAtomicDecrement32(&activeCount);
                
                OSAtomicIncrement32(&totalRun);
            }];
        }
        
        while(totalRun < 10000) {
            usleep(1000);
        }
        
        ASSERT(maxActiveCount > 1);
        ASSERT(totalRun == 10000);
    });
    
    TEST(global, {
        __block volatile int32_t totalRun = 0;
        
        for(int i = 0; i < 10000; i++) {
            [[MADispatchQueue globalQueue] dispatchAsync: ^{
                OSAtomicIncrement32(&totalRun);
            }];
        }
        
        while(totalRun < 10000) {
            usleep(1000);
        }
    });
}
