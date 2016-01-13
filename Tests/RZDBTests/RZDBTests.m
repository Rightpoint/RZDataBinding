//
//  RZDBTests.m
//  RZDBTests
//
//  Created by Rob Visentin on 9/18/14.
//

@import XCTest;
@import CoreGraphics.CGGeometry;

#import "RZDataBinding.h"

@protocol TestProtocol <NSObject>

- (NSString *)helloString;

@end

@interface RZDBTestObject : NSObject <TestProtocol>

@property (copy, nonatomic) NSString *string;
@property (assign, nonatomic) NSInteger callbackCalls;
@property (assign, nonatomic) NSInteger setStringCalls;

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

- (void)setString:(NSString *)string
{
    _string = [string copy];
    self.setStringCalls++;
}

- (NSString *)helloString
{
    return @"Hello";
}

#if !RZDB_AUTOMATIC_CLEANUP
- (void)dealloc
{
    [self rz_cleanupObservers];
}
#endif

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
    
    [testObj rz_addTarget:observer action:@selector(changeCallback) forKeyPathChanges:@[RZDB_KP_OBJ(testObj, string), RZDB_KP_OBJ(testObj, callbackCalls)] callImmediately:YES];
    
    testObj.string = @"test";
    testObj.callbackCalls = 0;
    
    XCTAssertTrue(observer.callbackCalls == 3, @"Callback called incorrect number of times. Expected:2 Actual:%i", (int)observer.callbackCalls);

    observer.callbackCalls = 0;
    [testObj rz_addTarget:observer action:@selector(changeCallbackWithDict:) forKeyPathChanges:@[RZDB_KP_OBJ(testObj, string), RZDB_KP_OBJ(testObj, callbackCalls)] callImmediately:YES];

    XCTAssertTrue(observer.callbackCalls == 2, @"Callback called incorrect number of times. Expected:2 Actual:%i", (int)observer.callbackCalls);
}

- (void)testAsynchronousRegistration
{
    RZDBTestObject *testObj = [RZDBTestObject new];
    RZDBTestObject *observer = [RZDBTestObject new];

    for ( NSUInteger i = 0; i < 500000; i++ ) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @autoreleasepool {
                if ( arc4random() % 2 == 0 ) {
                    [testObj rz_addTarget:observer action:@selector(testCallback) forKeyPathChange:RZDB_KP_OBJ(testObj, string)];
                }
                else {
                    [testObj rz_removeTarget:observer action:@selector(testCallback) forKeyPathChange:RZDB_KP_OBJ(testObj, string)];
                }
            }
        });
    }
}

- (void)testSimpleCoalesce
{
    RZDBTestObject *testObj = [RZDBTestObject new];
    RZDBTestObject *observer = [RZDBTestObject new];

    [testObj rz_addTarget:[observer rz_coalesceProxy] action:@selector(changeCallback) forKeyPathChanges:@[RZDB_KP_OBJ(testObj, string), RZDB_KP_OBJ(testObj, callbackCalls)]];

    [RZDBCoalesce coalesceBlock:^{
        testObj.string = @"test";
        testObj.callbackCalls = 0;
    }];

    XCTAssertTrue(observer.callbackCalls == 1, @"Callback called incorrect number of times. Expected:1 Actual:%i", (int)observer.callbackCalls);

    XCTAssertNoThrow([RZDBCoalesce commit], @"Calling +commit outside a coalesce shouldn't cause an exception.");
}

- (void)testCoalesceWithCallbackDict
{
    RZDBTestObject *testObj = [RZDBTestObject new];
    RZDBTestObject *observer = [RZDBTestObject new];

    [testObj rz_addTarget:[observer rz_coalesceProxy] action:@selector(changeCallbackWithDict:) forKeyPathChanges:@[RZDB_KP_OBJ(testObj, string), RZDB_KP_OBJ(testObj, callbackCalls)]];

    [RZDBCoalesce coalesceBlock:^{
        testObj.string = @"test";
        testObj.string = @"test2";
    }];

    XCTAssertTrue(observer.callbackCalls == 1, @"Callback called incorrect number of times. Expected:1 Actual:%i", (int)observer.callbackCalls);

    XCTAssertTrue([observer.string isEqualToString:@"test2"], @"Coalesced callback called with incorrect final value.");
}

- (void)testNestedCoalesce
{
    RZDBTestObject *testObj = [RZDBTestObject new];
    RZDBTestObject *observer = [RZDBTestObject new];

    [testObj rz_addTarget:[observer rz_coalesceProxy] action:@selector(changeCallback) forKeyPathChanges:@[RZDB_KP_OBJ(testObj, string), RZDB_KP_OBJ(testObj, callbackCalls)]];

    [RZDBCoalesce begin];

    testObj.string = @"test";

    [RZDBCoalesce begin];
    testObj.callbackCalls = 0;
    [RZDBCoalesce commit];

    XCTAssertTrue(observer.callbackCalls == 0, @"Coalesce should not have ended. Expected:0 callbacks Actual:%i", (int)observer.callbackCalls);

    [RZDBCoalesce commit];

    XCTAssertTrue(observer.callbackCalls == 1, @"Callback called incorrect number of times. Expected:1 Actual:%i", (int)observer.callbackCalls);
}

- (void)testBackgroundCoalesce
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Done"];
    NSArray *testObjects = @[[RZDBTestObject new],
                             [RZDBTestObject new],
                             [RZDBTestObject new],
                             [RZDBTestObject new],
                             [RZDBTestObject new]];

    RZDBTestObject *observer = [RZDBTestObject new];

    // Create 500 addTarget actions
    for ( NSUInteger i = 0; i < 500; i++ ) {
        RZDBTestObject *t = [testObjects objectAtIndex:i % testObjects.count];

        [t rz_addTarget:[observer rz_coalesceProxy] action:@selector(changeCallback) forKeyPathChanges:@[RZDB_KP_OBJ(t, string)]];

    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [RZDBCoalesce begin];
        for ( NSUInteger i = 0; i < 5000; i++ ) {
            @autoreleasepool {
                RZDBTestObject *t = [testObjects objectAtIndex:arc4random() % testObjects.count];
                t.string = @"New Value";
            }

        }
        [RZDBCoalesce commit];

        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:50 handler:^(NSError *error) {
        XCTAssertTrue(observer.callbackCalls == 1, @"Callback called incorrect number of times. Expected:1 Actual:%i", (int)observer.callbackCalls);
    }];
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

- (void)testBindingEqualityCheck
{
    RZDBTestObject *testObj = [RZDBTestObject new];
    RZDBTestObject *observer = [RZDBTestObject new];

    observer.string = @"temp";
    observer.setStringCalls = 0;

    [observer rz_bindKey:RZDB_KP_OBJ(observer, string) toKeyPath:RZDB_KP_OBJ(testObj, string) ofObject:testObj];

    for ( int i = 0; i < 100; i++ ) {
        testObj.string = @"string";
    }

    // should be called once initially, and once when the keypath changes
    XCTAssertTrue(observer.setStringCalls == 2, @"Binding triggered incorrect number of times. Expected:2 Actual:%i", (int)observer.setStringCalls);
}

- (void)testKeyBindingWithTransform
{
    RZDBTestObject *testObj = [RZDBTestObject new];
    RZDBTestObject *observer = [RZDBTestObject new];
    
    testObj.callbackCalls = 5;
    
    [observer rz_bindKey:RZDB_KP_OBJ(observer, callbackCalls) toKeyPath:RZDB_KP_OBJ(testObj, callbackCalls) ofObject:testObj withTransform:^id (id value) {
        return @([(NSNumber *)value integerValue] + 100);
    }];
    
    XCTAssertTrue(observer.callbackCalls == 105, @"Key binding transform was not properly applied before setting value for key when key path changed.");
    
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

- (void)testTransformConstants
{
    id value = nil;

    value = kRZDBNilToZeroTransform(value);
    XCTAssertTrue([value isEqual:@(0)]);

    value = nil;
    value = kRZDBNilToOneTransform(value);
    XCTAssertTrue([value isEqual:@(1)]);

    value = nil;
    value = kRZDBNilToCGSizeZeroTransform(value);
    CGSize size = CGSizeMake(1.0f, 1.0f);
    [value getValue:&size];
    XCTAssertTrue(CGSizeEqualToSize(size, CGSizeZero));

    value = nil;
    value = kRZDBNilToCGRectZeroTransform(value);
    CGRect rect = CGRectMake(1.0f, 1.0f, 1.0f, 1.0f);
    [value getValue:&rect];
    XCTAssertTrue(CGRectEqualToRect(rect, CGRectZero));

    value = nil;
    value = kRZDBNilToCGRectNullTransform(value);
    rect = CGRectMake(1.0f, 1.0f, 1.0f, 1.0f);
    [value getValue:&rect];
    XCTAssertTrue(CGRectIsNull(rect));

    value = @(NO);
    value = kRZDBLogicalNegateTransform(value);
    XCTAssertTrue([value boolValue]);

    value = @(0.25);
    value = kRZDBOneMinusTransform(value);
    XCTAssertTrue([value doubleValue] == 0.75);

    value = @(0x1337);
    value = kRZDBBitwiseComplementTransform(value);
    XCTAssertTrue([value longLongValue] == ~0x1337);
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

- (void)testProtocolKeypathHelper
{
    RZDBTestObject *testObject = [RZDBTestObject new];

    // The test itself is trivial - the real test is whether or not this line compiles
    NSString *keyPath = RZDB_KP_PROTOCOL(TestProtocol, helloString.mutableCopy);

    id resultObject = [testObject valueForKeyPath:keyPath];

    BOOL isMutableString = [resultObject isKindOfClass:[NSMutableString class]];
    XCTAssertTrue(isMutableString);
}

@end
