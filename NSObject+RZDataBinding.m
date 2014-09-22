//
//  NSObject+RZDataBinding.m
//
//  Created by Rob Visentin on 9/17/14.

// Copyright 2014 Raizlabs and other contributors
// http://raizlabs.com/
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

@import ObjectiveC.runtime;
@import ObjectiveC.message;

#import "NSObject+RZDataBinding.h"

// public change keys
NSString* const kRZDBChangeKeyObject  = @"RZDBChangeObject";
NSString* const kRZDBChangeKeyOld     = @"RZDBChangeOld";
NSString* const kRZDBChangeKeyNew     = @"RZDBChangeNew";
NSString* const kRZDBChangeKeyKeyPath = @"RZDBChangeKeyPath";

// private change keys
static NSString* const kRZDBChangeKeyIsPrior  = @"RZDBChangeIsPrior";
static NSString* const kRZDBChangeKeyBoundKey = @"RZDBChangeBoundKey";

static void* const kRZDBKVOContext = (void *)&kRZDBKVOContext;

#pragma mark - RZDBTargetActionPair

@interface RZDBTargetActionPair : NSObject

@property (weak, nonatomic) id target;
@property (assign, nonatomic) SEL action;
@property (copy, nonatomic) NSString *boundKey;

- (instancetype)initWithTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey;

@end

@implementation RZDBTargetActionPair

- (instancetype)initWithTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey
{
    self = [super init];
    if ( self ) {
        self.target = target;
        self.action = action;
        self.boundKey = boundKey;
    }

    return self;
}

@end

#pragma mark - RZDBObserver

@interface RZDBObserver : NSObject;

@property (assign, nonatomic) __unsafe_unretained NSObject *observedObject;
@property (copy, nonatomic) NSString *keyPath;
@property (assign, nonatomic) NSKeyValueObservingOptions observationOptions;

@property (strong, nonatomic) NSMutableArray *targetActionPairs;

- (instancetype)initWithObservedObject:(NSObject *)observedObject keyPath:(NSString *)keyPath observationOptions:(NSKeyValueObservingOptions)observingOptions;

- (void)addTargetActionPair:(RZDBTargetActionPair *)pair;
- (void)removeTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey;

@end

@implementation RZDBObserver

- (instancetype)initWithObservedObject:(NSObject *)observedObject keyPath:(NSString *)keyPath observationOptions:(NSKeyValueObservingOptions)observingOptions
{
    self = [super init];
    if ( self ) {
        self.observedObject = observedObject;
        self.keyPath = keyPath;
        self.observationOptions = observingOptions;
    }
    
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ( context == kRZDBKVOContext ) {
        [[self.targetActionPairs copy] enumerateObjectsUsingBlock:^(RZDBTargetActionPair *pair, NSUInteger idx, BOOL *stop) {
            if ( pair.target != nil && pair.action != NULL ) {
                NSMethodSignature *signature = [pair.target methodSignatureForSelector:pair.action];
                
                if ( signature.numberOfArguments > 2 ) {
                    NSDictionary *changeDict = [self changeDictWithTargetActionPair:pair keyPath:keyPath kvoChange:change];
                    ((void(*)(id, SEL, id))objc_msgSend)(pair.target, pair.action, changeDict);
                }
                else {
                    ((void(*)(id, SEL))objc_msgSend)(pair.target, pair.action);
                }
            }
            else {
                [self.targetActionPairs removeObject:pair];
            }
        }];
    }
}

- (void)addTargetActionPair:(RZDBTargetActionPair *)pair
{
    if ( [self.targetActionPairs count] == 0 ) {
        // NOTE: Do NOT use arrayWithObject here. It inexplicably prevents the object from being released properly.
        self.targetActionPairs = [NSMutableArray array];
        [self.targetActionPairs addObject:pair];
        
        [self.observedObject addObserver:self forKeyPath:self.keyPath options:self.observationOptions context:kRZDBKVOContext];
    }
    else {
        [self.targetActionPairs addObject:pair];
    }
}

- (void)removeTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey
{
    [[self.targetActionPairs copy] enumerateObjectsUsingBlock:^(RZDBTargetActionPair *pair, NSUInteger idx, BOOL *stop) {
        BOOL targetsEqual = (target == pair.target);
        BOOL actionsEqual = (action == NULL || action == pair.action);
        BOOL boundKeysEqual = (boundKey == pair.boundKey || [boundKey isEqualToString:pair.boundKey]);
        
        BOOL remove = (pair.target == nil || pair.action == NULL) || (targetsEqual && actionsEqual && boundKeysEqual);
        
        if ( remove ) {
            [self.targetActionPairs removeObject:pair];
        }
    }];
}

- (NSDictionary *)changeDictWithTargetActionPair:(RZDBTargetActionPair *)pair keyPath:(NSString *)keyPath kvoChange:(NSDictionary *)kvoChange
{
    NSMutableDictionary *changeDict = [NSMutableDictionary dictionary];
    
    if ( pair.target != nil && ![pair.target isEqual:[NSNull null]] ) {
        changeDict[kRZDBChangeKeyObject] = pair.target;
    }
    
    if ( kvoChange[NSKeyValueChangeOldKey] != nil && ![kvoChange[NSKeyValueChangeOldKey] isEqual:[NSNull null]] ) {
        changeDict[kRZDBChangeKeyOld] = kvoChange[NSKeyValueChangeOldKey];
    }
    
    if ( kvoChange[NSKeyValueChangeNewKey] != nil && ![kvoChange[NSKeyValueChangeNewKey] isEqual:[NSNull null]] ) {
        changeDict[kRZDBChangeKeyNew] = kvoChange[NSKeyValueChangeNewKey];
    }
    
    if ( keyPath != nil && ![keyPath isEqual:[NSNull null]] ) {
        changeDict[kRZDBChangeKeyKeyPath] = keyPath;
    }
    
    if ( kvoChange[NSKeyValueChangeNotificationIsPriorKey] != nil && ![kvoChange[NSKeyValueChangeNotificationIsPriorKey] isEqual:[NSNull null]] ) {
        changeDict[kRZDBChangeKeyIsPrior] = kvoChange[NSKeyValueChangeNotificationIsPriorKey];
    }
    
    if ( pair.boundKey != nil && ![pair.boundKey isEqual:[NSNull null]] ) {
        changeDict[kRZDBChangeKeyBoundKey] = pair.boundKey;
    }
    
    return [changeDict copy];
}

- (void)dealloc
{
    @try {
        [self.observedObject removeObserver:self forKeyPath:self.keyPath context:kRZDBKVOContext];
    }
    @catch (NSException *exception) {}
}

@end

#pragma mark - RZDataBinding

@implementation NSObject (RZDataBinding)

#pragma mark - public methods

- (void)rz_addTarget:(id)target action:(SEL)action forKeyPathChange:(NSString *)keyPath
{
    NSParameterAssert(target);
    NSParameterAssert(action);
    
    RZDBTargetActionPair *pair = [[RZDBTargetActionPair alloc] initWithTarget:target action:action boundKey:nil];
    
    [self _rz_addTargetActionPair:pair forKeyPath:keyPath withOptions:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionInitial];
}

- (void)rz_removeTarget:(id)target action:(SEL)action forKeyPathChange:(NSString *)keyPath
{
    if ( [self _rz_isObservingKeyPath:keyPath] ) {
        [self _rz_removeTarget:target action:action boundKey:nil forKeyPath:keyPath];
    }
}

- (void)rz_bindKey:(NSString *)key toKeyPath:(NSString *)foreignKeyPath ofObject:(id)object
{
    NSParameterAssert(key);
    NSParameterAssert(foreignKeyPath);
    NSParameterAssert(object);
    
    RZDBTargetActionPair *pair = [[RZDBTargetActionPair alloc] initWithTarget:self action:@selector(_rz_observeBoundKeyChange:) boundKey:key];
    
    [object _rz_addTargetActionPair:pair forKeyPath:foreignKeyPath withOptions:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionPrior];
    
    [self willChangeValueForKey:key];
    
    @try {
        [self setValue:[object valueForKeyPath:foreignKeyPath] forKey:key];
    }
    @catch (NSException *exception) {
        NSLog(@"RZDataBinding failed to bind key:%@ to key path:%@ of object:%@. Reason: %@", key, foreignKeyPath, [object description], exception.reason);
        @throw exception;
    }
    
    [self didChangeValueForKey:key];
}

- (void)rz_unbindKey:(NSString *)key fromKeyPath:(NSString *)foreignKeyPath ofObject:(id)object
{
    if ( [object _rz_isObservingKeyPath:foreignKeyPath] ) {
        [object _rz_removeTarget:self action:@selector(_rz_observeBoundKeyChange:) boundKey:key forKeyPath:foreignKeyPath];
    }
}

#pragma mark - private helper methods

- (BOOL)_rz_isObservingKeyPath:(NSString *)keyPath
{
    return ([self _rz_registeredObservers][keyPath] != nil);
}

- (NSMutableDictionary *)_rz_registeredObservers
{
    NSMutableDictionary *registeredObservers = objc_getAssociatedObject(self, _cmd);
    
    if ( registeredObservers == nil ) {
        registeredObservers = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, _cmd, registeredObservers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return registeredObservers;
}

- (void)_rz_addTargetActionPair:(RZDBTargetActionPair *)pair forKeyPath:(NSString *)keyPath withOptions:(NSKeyValueObservingOptions)options
{
    NSMutableDictionary *registeredObservers = [self _rz_registeredObservers];
    RZDBObserver *observer = registeredObservers[keyPath];
    
    if ( observer == nil ) {
        observer = [[RZDBObserver alloc] initWithObservedObject:self keyPath:keyPath observationOptions:options];

        registeredObservers[keyPath] = observer;
    }
    
    [observer addTargetActionPair:pair];
}

- (void)_rz_removeTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey forKeyPath:(NSString *)keyPath
{
    NSMutableDictionary *registeredObservers = [self _rz_registeredObservers];
    RZDBObserver *observer = registeredObservers[keyPath];
    
    if ( observer != nil ) {
        [observer removeTarget:target action:action boundKey:boundKey];
        
        if ( [observer.targetActionPairs count] == 0 ) {
            [registeredObservers removeObjectForKey:keyPath];
        }
    }
}

#pragma mark - private KVO helpers

- (void)_rz_observeBoundKeyChange:(NSDictionary *)change
{
    NSString *boundKey = change[kRZDBChangeKeyBoundKey];
    
    if ( boundKey != nil ) {
        if ( [change[kRZDBChangeKeyIsPrior] boolValue] ) {
            [self willChangeValueForKey:boundKey];
        }
        else {
            [self setValue:change[kRZDBChangeKeyNew] forKey:boundKey];
            [self didChangeValueForKey:boundKey];
        }
    }
}

@end
