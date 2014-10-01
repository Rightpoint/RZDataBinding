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
@property (assign, nonatomic) NSInteger callbackCalls;

- (void)changeCallback;
- (void)changeCallbackWithDict:(NSDictionary *)dictionary;

@end

@implementation RZDBTestObject

- (void)changeCallback
{
    self.callbackCalls++;
}

- (void)changeCallbackWithDict:(NSDictionary *)dictionary
{
    self.callbackCalls++;
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
    XCTAssertTrue(observer.callbackCalls != 0, @"Callback not called on initial add");
    
    observer.callbackCalls = 0;
    testObj.string = @"test";
    XCTAssertTrue(observer.callbackCalls != 0, @"Callback not called on key path change");
    
    observer.callbackCalls = 0;
    [testObj rz_removeTarget:observer action:@selector(changeCallback) forKeyPathChange:@"string"];
    testObj.string = @"test2";
    XCTAssertFalse(observer.callbackCalls != 0, @"Callback called even after removal");
}

- (void)testCallbackWithDict
{
    RZDBTestObject *testObj = [RZDBTestObject new];
    RZDBTestObject *observer = [RZDBTestObject new];
    
    [testObj rz_addTarget:observer action:@selector(changeCallbackWithDict:) forKeyPathChange:@"string" callImmediately:YES];
    XCTAssertTrue(observer.callbackCalls != 0, @"Callback not called on initial add");
    
    observer.callbackCalls = 0;
    testObj.string = @"test";
    XCTAssertTrue(observer.callbackCalls != 0, @"Callback not called on key path change");
    
    
    XCTAssertTrue([observer.string isEqualToString:testObj.string], @"Strings should be equal because the callback is setting the property to the new object");
}

- (void)testCallbackCount
{
    RZDBTestObject *obj1 = [RZDBTestObject new];
    RZDBTestObject *obj2 = [RZDBTestObject new];
    RZDBTestObject *obj3 = [RZDBTestObject new];
    
    [obj2 rz_bindKey:@"string" toKeyPath:@"string" ofObject:obj1];
    [obj2 rz_addTarget:obj3 action:@selector(changeCallback) forKeyPathChange:@"string"];
    
    obj1.string = @"string";
    
    XCTAssertTrue(obj3.callbackCalls == 1, @"Callback called incorrect number of times. Expected:1 Actual:%i", (int)obj3.callbackCalls);
}

- (void)testKeyBinding
{
    RZDBTestObject *testObj = [RZDBTestObject new];
    RZDBTestObject *observer = [RZDBTestObject new];
    
    testObj.string = @"test";
    
    [observer rz_bindKey:@"string" toKeyPath:@"string" ofObject:testObj];
    XCTAssertTrue([observer.string isEqualToString:@"test"], @"Bound values not equal on initial binding");
    
    testObj.string = @"test2";
    XCTAssertTrue([observer.string isEqualToString:testObj.string], @"Bound not equal when key path changed");
    
    [observer rz_unbindKey:@"string" fromKeyPath:@"string" ofObject:testObj];
    testObj.string = @"test3";
    XCTAssertTrue([observer.string isEqualToString:@"test2"], @"String shouldn't change after keys are unbound");
}

- (void)testBindingChains
{
    RZDBTestObject *obj1 = [RZDBTestObject new];
    RZDBTestObject *obj2 = [RZDBTestObject new];
    RZDBTestObject *obj3 = [RZDBTestObject new];
    
    [obj2 rz_bindKey:@"string" toKeyPath:@"string" ofObject:obj1];
    [obj3 rz_bindKey:@"string" toKeyPath:@"string" ofObject:obj2];
    
    obj1.string = @"test";
    
    XCTAssertTrue([obj3.string isEqualToString:obj2.string] && [obj2.string isEqualToString:obj1.string], @"Binding chain failed--values not equal");
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
