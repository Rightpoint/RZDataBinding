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

@interface NSObject (RZDataBinding_Private)

- (NSMutableArray *)_rz_registeredObservers;
- (void)_rz_addTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey forKeyPath:(NSString *)keyPath withOptions:(NSKeyValueObservingOptions)options;
- (void)_rz_removeTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey forKeyPath:(NSString *)keyPath;
- (void)_rz_observeBoundKeyChange:(NSDictionary *)change;

@end

#pragma mark - RZDBObserver

@interface RZDBObserver : NSObject;

@property (assign, nonatomic) __unsafe_unretained NSObject *observedObject;
@property (copy, nonatomic) NSString *keyPath;
@property (assign, nonatomic) NSKeyValueObservingOptions observationOptions;

@property (weak, nonatomic) id target;
@property (assign, nonatomic) SEL action;
@property (copy, nonatomic) NSString *boundKey;

@property (nonatomic, readonly, getter=isValid) BOOL valid;

- (instancetype)initWithObservedObject:(NSObject *)observedObject keyPath:(NSString *)keyPath observationOptions:(NSKeyValueObservingOptions)observingOptions;

- (void)setTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey;

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

- (void)setTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey
{
    self.target = target;
    self.action = action;
    self.boundKey = boundKey;
    
    [self.observedObject addObserver:self forKeyPath:self.keyPath options:self.observationOptions context:kRZDBKVOContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ( context == kRZDBKVOContext ) {
        if ( self.isValid ) {
            NSMethodSignature *signature = [self.target methodSignatureForSelector:self.action];
            
            if ( signature.numberOfArguments > 2 ) {
                NSDictionary *changeDict = [self changeDictForKVOChange:change];
                ((void(*)(id, SEL, id))objc_msgSend)(self.target, self.action, changeDict);
            }
            else {
                ((void(*)(id, SEL))objc_msgSend)(self.target, self.action);
            }
        }
        else {
            [[self.observedObject _rz_registeredObservers] removeObject:self];
        }
    }
}

- (NSDictionary *)changeDictForKVOChange:(NSDictionary *)kvoChange
{
    NSMutableDictionary *changeDict = [NSMutableDictionary dictionary];
    
    if ( self.observedObject != nil ) {
        changeDict[kRZDBChangeKeyObject] = self.observedObject;
    }
    
    if ( kvoChange[NSKeyValueChangeOldKey] != nil && ![kvoChange[NSKeyValueChangeOldKey] isEqual:[NSNull null]] ) {
        changeDict[kRZDBChangeKeyOld] = kvoChange[NSKeyValueChangeOldKey];
    }
    
    if ( kvoChange[NSKeyValueChangeNewKey] != nil && ![kvoChange[NSKeyValueChangeNewKey] isEqual:[NSNull null]] ) {
        changeDict[kRZDBChangeKeyNew] = kvoChange[NSKeyValueChangeNewKey];
    }
    
    if ( self.keyPath != nil ) {
        changeDict[kRZDBChangeKeyKeyPath] = self.keyPath;
    }
    
    if ( kvoChange[NSKeyValueChangeNotificationIsPriorKey] != nil && ![kvoChange[NSKeyValueChangeNotificationIsPriorKey] isEqual:[NSNull null]] ) {
        changeDict[kRZDBChangeKeyIsPrior] = kvoChange[NSKeyValueChangeNotificationIsPriorKey];
    }
    
    if ( self.boundKey != nil ) {
        changeDict[kRZDBChangeKeyBoundKey] = self.boundKey;
    }
    
    return [changeDict copy];
}

- (BOOL)isValid
{
    return (self.target != nil && self.action != NULL);
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

- (void)rz_addTarget:(id)target action:(SEL)action forKeyPathChange:(NSString *)keyPath
{
    [self rz_addTarget:target action:action forKeyPathChange:keyPath callImmediately:NO];
}

- (void)rz_addTarget:(id)target action:(SEL)action forKeyPathChange:(NSString *)keyPath callImmediately:(BOOL)callImmediately
{
    NSParameterAssert(target);
    NSParameterAssert(action);
    
    NSKeyValueObservingOptions observationOptions = NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld;
    
    if ( callImmediately ) {
        observationOptions |= NSKeyValueObservingOptionInitial;
    }
    
    [self _rz_addTarget:target action:action boundKey:nil forKeyPath:keyPath withOptions:observationOptions];
}

- (void)rz_removeTarget:(id)target action:(SEL)action forKeyPathChange:(NSString *)keyPath
{
    [self _rz_removeTarget:target action:action boundKey:nil forKeyPath:keyPath];
}

- (void)rz_bindKey:(NSString *)key toKeyPath:(NSString *)foreignKeyPath ofObject:(id)object
{
    NSParameterAssert(key);
    NSParameterAssert(foreignKeyPath);
    
    if ( object != nil ) {
        [self willChangeValueForKey:key];
        
        @try {
            [self setValue:[object valueForKeyPath:foreignKeyPath] forKey:key];
        }
        @catch (NSException *exception) {
            NSLog(@"RZDataBinding failed to bind key:%@ to key path:%@ of object:%@. Reason: %@", key, foreignKeyPath, [object description], exception.reason);
            @throw exception;
        }
        
        [self didChangeValueForKey:key];
        
        [object _rz_addTarget:self action:@selector(_rz_observeBoundKeyChange:) boundKey:key forKeyPath:foreignKeyPath withOptions:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionPrior];
    }
}

- (void)rz_unbindKey:(NSString *)key fromKeyPath:(NSString *)foreignKeyPath ofObject:(id)object
{
    [object _rz_removeTarget:self action:@selector(_rz_observeBoundKeyChange:) boundKey:key forKeyPath:foreignKeyPath];
}

@end

#pragma mark - RZDataBinding_Private

@implementation NSObject (RZDataBinding_Private)

- (NSMutableArray *)_rz_registeredObservers
{
    NSMutableArray *registeredObservers = objc_getAssociatedObject(self, _cmd);
    
    if ( registeredObservers == nil ) {
        registeredObservers = [NSMutableArray array];
        objc_setAssociatedObject(self, _cmd, registeredObservers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return registeredObservers;
}

- (void)_rz_addTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey forKeyPath:(NSString *)keyPath withOptions:(NSKeyValueObservingOptions)options
{
    NSMutableArray *registeredObservers = [self _rz_registeredObservers];
    
    RZDBObserver *observer = [[RZDBObserver alloc] initWithObservedObject:self keyPath:keyPath observationOptions:options];
    [registeredObservers addObject:observer];
    
    [observer setTarget:target action:action boundKey:boundKey];
}

- (void)_rz_removeTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey forKeyPath:(NSString *)keyPath
{
    NSMutableArray *registeredObservers = [self _rz_registeredObservers];
    
    [[registeredObservers copy] enumerateObjectsUsingBlock:^(RZDBObserver *observer, NSUInteger idx, BOOL *stop) {
        BOOL targetsEqual = (target == observer.target);
        BOOL actionsEqual = (action == NULL || action == observer.action);
        BOOL boundKeysEqual = (boundKey == observer.boundKey || [boundKey isEqualToString:observer.boundKey]);
        BOOL keyPathsEqual = [keyPath isEqualToString:observer.keyPath];
        
        BOOL remove = (!observer.isValid) || (targetsEqual && actionsEqual && boundKeysEqual && keyPathsEqual);
        
        if ( remove ) {            
            [registeredObservers removeObject:observer];
        }
    }];
}

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
