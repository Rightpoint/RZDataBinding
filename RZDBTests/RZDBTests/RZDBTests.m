//
//  RZDBTests.m
//  RZDBTests
//
//  Created by Rob Visentin on 9/18/14.
//

@import XCTest;

#import "NSObject+RZDataBinding.h"

@interface RZDBTestObject : NSObject

@property (copy, nonatomic) NSString *string;
@property (assign, nonatomic) BOOL callbackCalled;

- (void)changeCallback;
- (void)changeCallbackWithDict:(NSDictionary *)dictionary;

@end

@implementation RZDBTestObject

- (void)changeCallback
{
    self.callbackCalled = YES;
}

- (void)changeCallbackWithDict:(NSDictionary *)dictionary
{
    self.callbackCalled = YES;
    self.string = dictionary[kRZDBChangeKeyNew];
}

@end

@interface RZDBTests : XCTestCase

@end

@implementation RZDBTests

- (void)testCallback
{
    RZDBTestObject *testObj = [RZDBTestObject new];
    RZDBTestObject *observer = [RZDBTestObject new];
    
    [testObj rz_addTarget:observer action:@selector(changeCallback) forKeyPathChange:@"string" callImmediately:YES];
    XCTAssertTrue(observer.callbackCalled, @"Callback not called on initial add");
    
    observer.callbackCalled = NO;
    testObj.string = @"test";
    XCTAssertTrue(observer.callbackCalled, @"Callback not called on key path change");
    
    observer.callbackCalled = NO;
    [testObj rz_removeTarget:observer action:@selector(changeCallback) forKeyPathChange:@"string"];
    testObj.string = @"test2";
    XCTAssertFalse(observer.callbackCalled, @"Callback called even after removal");
}

- (void)testCallbackWithDict
{
    RZDBTestObject *testObj = [RZDBTestObject new];
    RZDBTestObject *observer = [RZDBTestObject new];
    
    [testObj rz_addTarget:observer action:@selector(changeCallbackWithDict:) forKeyPathChange:@"string" callImmediately:YES];
    XCTAssertTrue(observer.callbackCalled, @"Callback not called on initial add");
    
    observer.callbackCalled = NO;
    testObj.string = @"test";
    XCTAssertTrue(observer.callbackCalled, @"Callback not called on key path change");
    
    
    XCTAssertTrue([observer.string isEqualToString:testObj.string], @"Strings should be equal because the callback is setting the property to the new object");
}

- (void)testKeyBinding
{
    RZDBTestObject *testObj = [RZDBTestObject new];
    RZDBTestObject *observer = [RZDBTestObject new];
    
    testObj.string = @"test";
    
    [observer rz_bindKey:@"string" toKeyPath:@"string" ofObject:testObj];
    XCTAssertTrue([observer.string isEqualToString:@"test"], @"Bound values not equal on initial binding");
    
    testObj.string = @"test2";
    XCTAssertTrue([observer.string isEqualToString:@"test2"], @"Bound not equal when key path changed");
    
    [observer rz_unbindKey:@"string" fromKeyPath:@"string" ofObject:testObj];
    testObj.string = @"test3";
    XCTAssertTrue([observer.string isEqualToString:@"test2"], @"String shouldn't change after keys are unbound");
}

- (void)testDeallocation
{
    RZDBTestObject *testObjA = [RZDBTestObject new];
    RZDBTestObject *testObjB = [RZDBTestObject new];
    
    __weak RZDBTestObject *weakA = testObjA;
    __weak RZDBTestObject *weakB = testObjB;
    
    @autoreleasepool {
        [testObjA rz_addTarget:testObjB action:@selector(changeCallback) forKeyPathChange:@"string"];
        [testObjB rz_bindKey:@"string" toKeyPath:@"string" ofObject:testObjA];
        
        testObjA = nil;
        testObjB = nil;
    }
    
    XCTAssertNil(weakA, @"Add target prevented object deallocation.");
    XCTAssertNil(weakB, @"Bind key prevented object deallocation.");
}

- (void)testAutomaticCleanup
{
    RZDBTestObject *testObjA = [RZDBTestObject new];
    RZDBTestObject *testObjB = [RZDBTestObject new];
    
    @autoreleasepool {
        [testObjA rz_addTarget:testObjB action:@selector(changeCallback) forKeyPathChange:@"string"];
        
        testObjB = nil;
    }
    
    XCTAssertTrue([[testObjA valueForKey:@"_rz_registeredObservers"] count] == 0, @"Registered observers were not automatically cleaned up.");
}

@end
