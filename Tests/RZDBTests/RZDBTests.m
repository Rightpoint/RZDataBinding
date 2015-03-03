//
//  RZDBTests.m
//  RZDBTests
//
//  Created by Rob Visentin on 9/18/14.
//

@import XCTest;

#import "NSObject+RZDataBinding.h"

/**
 *  Change the base class to RZDBObservableObject to run tests with RZDB_AUTOMATIC_CLEANUP disabled
 */
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
    
    [testObj rz_addTarget:observer action:@selector(changeCallback) forKeyPathChange:RZDB_KP_OBJ(testObj, string) callImmediately:YES];
    XCTAssertTrue(observer.callbackCalls != 0, @"Callback not called on initial add");
    
    observer.callbackCalls = 0;
    testObj.string = @"test";
    XCTAssertTrue(observer.callbackCalls != 0, @"Callback not called on key path change");
    
    observer.callbackCalls = 0;
    [testObj rz_removeTarget:observer action:@selector(changeCallback) forKeyPathChange:RZDB_KP_OBJ(testObj, string)];
    testObj.string = @"test2";
    XCTAssertFalse(observer.callbackCalls != 0, @"Callback called even after removal");
}

- (void)testCallbackWithDict
{
    RZDBTestObject *testObj = [RZDBTestObject new];
    RZDBTestObject *observer = [RZDBTestObject new];
    
    [testObj rz_addTarget:observer action:@selector(changeCallbackWithDict:) forKeyPathChange:RZDB_KP_OBJ(RZDBTestObject *, string) callImmediately:YES];
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
    
    [obj2 rz_bindKey:RZDB_KP_OBJ(obj2, string) toKeyPath:RZDB_KP_OBJ(obj1, string) ofObject:obj1];
    [obj2 rz_addTarget:obj3 action:@selector(changeCallback) forKeyPathChange:RZDB_KP_OBJ(obj2, string)];
    
    obj1.string = @"string";
    
    XCTAssertTrue(obj3.callbackCalls == 1, @"Callback called incorrect number of times. Expected:1 Actual:%i", (int)obj3.callbackCalls);
}

- (void)testMultiRegistration
{
    RZDBTestObject *testObj = [RZDBTestObject new];
    RZDBTestObject *observer = [RZDBTestObject new];
    
    [testObj rz_addTarget:observer action:@selector(changeCallback) forKeyPathChanges:@[RZDB_KP_OBJ(testObj, string), RZDB_KP_OBJ(testObj, callbackCalls)]];
    
    testObj.string = @"test";
    testObj.callbackCalls = 0;
    
    XCTAssertTrue(observer.callbackCalls == 2, @"Callback called incorrect number of times. Expected:2 Actual:%i", (int)observer.callbackCalls);
}

- (void)testKeyBinding
{
    RZDBTestObject *testObj = [RZDBTestObject new];
    RZDBTestObject *observer = [RZDBTestObject new];
    
    testObj.string = @"test";
    
    [observer rz_bindKey:RZDB_KP_OBJ(observer, string) toKeyPath:RZDB_KP_OBJ(testObj, string) ofObject:testObj];
    XCTAssertTrue([observer.string isEqualToString:@"test"], @"Bound keys not equal on initial binding");
    
    testObj.string = @"test2";
    XCTAssertTrue([observer.string isEqualToString:testObj.string], @"Bound key not equal when key path changed");
    
    [observer rz_unbindKey:RZDB_KP_OBJ(observer, string) fromKeyPath:RZDB_KP_OBJ(testObj, string) ofObject:testObj];
    testObj.string = @"test3";
    XCTAssertTrue([observer.string isEqualToString:@"test2"], @"String shouldn't change after keys are unbound");
}

- (void)testKeyBindingWithFunction
{
    RZDBTestObject *testObj = [RZDBTestObject new];
    RZDBTestObject *observer = [RZDBTestObject new];
    
    testObj.callbackCalls = 5;
    
    [observer rz_bindKey:RZDB_KP_OBJ(observer, callbackCalls) toKeyPath:RZDB_KP_OBJ(testObj, callbackCalls) ofObject:testObj withFunction:^id (id value) {
        return @([(NSNumber *)value integerValue] + 100);
    }];
    
    XCTAssertTrue(observer.callbackCalls == 105, @"Key binding function was not properly applied before setting value for key when key path changed.");
    
    [observer rz_unbindKey:RZDB_KP_OBJ(observer, callbackCalls) fromKeyPath:RZDB_KP_OBJ(testObj, callbackCalls) ofObject:testObj];
    testObj.callbackCalls = 100;
    XCTAssertTrue(observer.callbackCalls == 105, @"Value shouldn't change after keys are unbound.");
}

- (void)testBindingChains
{
    RZDBTestObject *obj1 = [RZDBTestObject new];
    RZDBTestObject *obj2 = [RZDBTestObject new];
    RZDBTestObject *obj3 = [RZDBTestObject new];
    
    [obj2 rz_bindKey:RZDB_KP_OBJ(obj2, string) toKeyPath:RZDB_KP_OBJ(obj1, string) ofObject:obj1];
    [obj3 rz_bindKey:RZDB_KP_OBJ(obj3, string) toKeyPath:RZDB_KP_OBJ(obj2, string) ofObject:obj2];
    
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
        [testObjA rz_addTarget:testObjB action:@selector(changeCallback) forKeyPathChange:RZDB_KP_OBJ(testObjA, string)];
        [testObjB rz_bindKey:RZDB_KP_OBJ(testObjB, string) toKeyPath:RZDB_KP_OBJ(testObjA, string) ofObject:testObjA];
        
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
        [testObjA rz_addTarget:testObjB action:@selector(changeCallback) forKeyPathChange:RZDB_KP_OBJ(testObjA, string)];
        
        testObjB = nil;
    }
    
    XCTAssertTrue([[testObjA valueForKey:RZDB_KP_OBJ(testObjA, string)] count] == 0, @"Registered observers were not automatically cleaned up.");
}

@end
