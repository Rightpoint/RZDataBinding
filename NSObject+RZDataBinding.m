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

@class RZDBObserver;
@class RZDBObserverContainer;

RZDBKeyBindingFunction const kRZDBKeyBindingFunctionIdentity = ^NSValue* (NSValue *value) {
    return value;
};

// public change keys
NSString* const kRZDBChangeKeyObject  = @"RZDBChangeObject";
NSString* const kRZDBChangeKeyOld     = @"RZDBChangeOld";
NSString* const kRZDBChangeKeyNew     = @"RZDBChangeNew";
NSString* const kRZDBChangeKeyKeyPath = @"RZDBChangeKeyPath";

// private change keys
static NSString* const kRZDBChangeKeyBoundKey           = @"_RZDBChangeBoundKey";
static NSString* const kRZDBChangeKeyBindingFunctionKey = @"_RZDBChangeBindingFunction";

static NSString* const kRZDBDefaultSelectorPrefix = @"_rz_default_";

static NSString* const kRZDBKeyBindingExceptionFormat = @"RZDataBinding failed to bind key:%@ to key path:%@ of object:%@. Reason: %@";

static void* const kRZDBKVOContext = (void *)&kRZDBKVOContext;

#define RZDBNotNull(obj) ((obj) != nil && ![(obj) isEqual:[NSNull null]])

#pragma mark - RZDataBinding_Private interface

@interface NSObject (RZDataBinding_Private)

- (NSMutableArray *)_rz_registeredObservers;
- (void)_rz_setRegisteredObservers:(NSMutableArray *)registeredObservers;

- (RZDBObserverContainer *)_rz_dependentObservers;
- (void)_rz_setDependentObservers:(RZDBObserverContainer *)dependentObservers;

- (void)_rz_addTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey bindingFunction:(RZDBKeyBindingFunction)bindingFunction forKeyPath:(NSString *)keyPath withOptions:(NSKeyValueObservingOptions)options;
- (void)_rz_removeTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey forKeyPath:(NSString *)keyPath;
- (void)_rz_observeBoundKeyChange:(NSDictionary *)change;
- (void)_rz_cleanupObservers;

@end

#pragma mark - RZDBObserver interface

@interface RZDBObserver : NSObject;

@property (assign, nonatomic) __unsafe_unretained NSObject *observedObject;
@property (copy, nonatomic) NSString *keyPath;
@property (assign, nonatomic) NSKeyValueObservingOptions observationOptions;

@property (assign, nonatomic) __unsafe_unretained id target;
@property (assign, nonatomic) SEL action;
@property (copy, nonatomic) NSString *boundKey;

@property (copy, nonatomic) RZDBKeyBindingFunction bindingFunction;

- (instancetype)initWithObservedObject:(NSObject *)observedObject keyPath:(NSString *)keyPath observationOptions:(NSKeyValueObservingOptions)observingOptions;

- (void)setTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey bindingFunction:(RZDBKeyBindingFunction)bindingFunction;

- (void)invalidate;

@end

#pragma mark - RZDBObserverContainer interface

@interface RZDBObserverContainer : NSObject

@property (strong, nonatomic) NSPointerArray *observers;

- (void)addObserver:(RZDBObserver *)observer;
- (void)removeObserver:(RZDBObserver *)observer;

@end

#pragma mark - RZDataBinding implementation

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
    
    [self _rz_addTarget:target action:action boundKey:nil bindingFunction:nil forKeyPath:keyPath withOptions:observationOptions];
}

- (void)rz_addTarget:(id)target action:(SEL)action forKeyPathChanges:(NSArray *)keyPaths
{
    [keyPaths enumerateObjectsUsingBlock:^(NSString *keyPath, NSUInteger idx, BOOL *stop) {
        [self rz_addTarget:target action:action forKeyPathChange:keyPath];
    }];
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
        @try {
            [self setValue:[object valueForKeyPath:foreignKeyPath] forKey:key];
        }
        @catch (NSException *exception) {
            @throw [NSString stringWithFormat:kRZDBKeyBindingExceptionFormat, key, foreignKeyPath, [object description], exception.reason];
        }
        
        [object _rz_addTarget:self action:@selector(_rz_observeBoundKeyChange:) boundKey:key bindingFunction:nil forKeyPath:foreignKeyPath withOptions:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld];
    }
}

- (void)rz_bindKeyValue:(NSString *)key toKeyPathValue:(NSString *)foreignKeyPath ofObject:(id)object withFunction:(RZDBKeyBindingFunction)bindingFunction
{
    NSParameterAssert(key);
    NSParameterAssert(foreignKeyPath);
    
    if ( object != nil ) {
        bindingFunction = bindingFunction ?: kRZDBKeyBindingFunctionIdentity;
        
        @try {
            if ( ![[self valueForKey:key] isKindOfClass:[NSValue class]] || ![[object valueForKeyPath:foreignKeyPath] isKindOfClass:[NSValue class]] ) {
                @throw [NSException exceptionWithName:nil reason:[NSString stringWithFormat:@"Data types of key and key path must be primitive types or NSValue subclasses when using %@.", NSStringFromSelector(_cmd)] userInfo:nil];
            }
            
            [self setValue:bindingFunction([object valueForKeyPath:foreignKeyPath]) forKey:key];
        }
        @catch (NSException *exception) {
            @throw [NSString stringWithFormat:kRZDBKeyBindingExceptionFormat, key, foreignKeyPath, [object description], exception.reason];
        }
    
        [object _rz_addTarget:self action:@selector(_rz_observeBoundKeyChange:) boundKey:key bindingFunction:bindingFunction forKeyPath:foreignKeyPath withOptions:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld];
    }
}

- (void)rz_unbindKey:(NSString *)key fromKeyPath:(NSString *)foreignKeyPath ofObject:(id)object
{
    [object _rz_removeTarget:self action:@selector(_rz_observeBoundKeyChange:) boundKey:key forKeyPath:foreignKeyPath];
}

@end

#pragma mark - RZDBObservableObject implementation

@implementation RZDBObservableObject

- (void)dealloc
{
    [self _rz_cleanupObservers];
}

@end

#pragma mark - RZDataBinding_Private implementation

@implementation NSObject (RZDataBinding_Private)

- (NSMutableArray *)_rz_registeredObservers
{
    return objc_getAssociatedObject(self, @selector(_rz_registeredObservers));
}

- (void)_rz_setRegisteredObservers:(NSMutableArray *)registeredObservers
{
    objc_setAssociatedObject(self, @selector(_rz_registeredObservers), registeredObservers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (RZDBObserverContainer *)_rz_dependentObservers
{
    return objc_getAssociatedObject(self, @selector(_rz_dependentObservers));
}

- (void)_rz_setDependentObservers:(RZDBObserverContainer *)dependentObservers
{
    objc_setAssociatedObject(self, @selector(_rz_dependentObservers), dependentObservers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)_rz_addTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey bindingFunction:(RZDBKeyBindingFunction)bindingFunction forKeyPath:(NSString *)keyPath withOptions:(NSKeyValueObservingOptions)options
{
    NSMutableArray *registeredObservers = [self _rz_registeredObservers];
    
    if ( registeredObservers == nil ) {
        registeredObservers = [NSMutableArray array];
        [self _rz_setRegisteredObservers:registeredObservers];
    }
    
    RZDBObserver *observer = [[RZDBObserver alloc] initWithObservedObject:self keyPath:keyPath observationOptions:options];
    
    RZDBObserverContainer *dependentObservers = [target _rz_dependentObservers];
    
    if ( dependentObservers == nil ) {
        dependentObservers = [[RZDBObserverContainer alloc] init];
        [target _rz_setDependentObservers:dependentObservers];
    }
    
    [registeredObservers addObject:observer];
    [[target _rz_dependentObservers] addObserver:observer];
    
    [observer setTarget:target action:action boundKey:boundKey bindingFunction:bindingFunction];
}

- (void)_rz_removeTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey forKeyPath:(NSString *)keyPath
{
    NSMutableArray *registeredObservers = [self _rz_registeredObservers];
    
    [[registeredObservers copy] enumerateObjectsUsingBlock:^(RZDBObserver *observer, NSUInteger idx, BOOL *stop) {
        BOOL targetsEqual   = (target == observer.target);
        BOOL actionsEqual   = (action == NULL || action == observer.action);
        BOOL boundKeysEqual = (boundKey == observer.boundKey || [boundKey isEqualToString:observer.boundKey]);
        BOOL keyPathsEqual  = [keyPath isEqualToString:observer.keyPath];
        
        BOOL allEqual = (targetsEqual && actionsEqual && boundKeysEqual && keyPathsEqual);
        
        if ( allEqual ) {
            [observer invalidate];
        }
    }];
}

- (void)_rz_observeBoundKeyChange:(NSDictionary *)change
{
    NSString *boundKey = change[kRZDBChangeKeyBoundKey];
    
    if ( boundKey != nil ) {
        RZDBKeyBindingFunction bindingFunction = change[kRZDBChangeKeyBindingFunctionKey];
        
        id value = (bindingFunction != nil) ? bindingFunction(change[kRZDBChangeKeyNew]) : change[kRZDBChangeKeyNew];
        
        [self setValue:value forKey:boundKey];
    }
}

- (void)_rz_cleanupObservers
{
    NSMutableArray *registeredObservers = [self _rz_registeredObservers];
    RZDBObserverContainer *dependentObservers = [self _rz_dependentObservers];
    
    [[registeredObservers copy] enumerateObjectsUsingBlock:^(RZDBObserver *obs, NSUInteger idx, BOOL *stop) {
        [obs invalidate];
    }];
    
    [dependentObservers.observers compact];
    [[dependentObservers.observers allObjects] enumerateObjectsUsingBlock:^(RZDBObserver *obs, NSUInteger idx, BOOL *stop) {
        [obs invalidate];
    }];
}

#if RZDB_AUTOMATIC_CLEANUP
+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @autoreleasepool {
            SEL selector = NSSelectorFromString(@"dealloc");
            SEL replacementSelector = @selector(_rz_dealloc);
            
            Method originalMethod = class_getInstanceMethod(self, selector);
            Method replacementMethod = class_getInstanceMethod(self, replacementSelector);
            
            SEL defaultSelector = NSSelectorFromString([NSString stringWithFormat:@"%@%@", kRZDBDefaultSelectorPrefix, NSStringFromSelector(selector)]);
            
            class_addMethod(self, defaultSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
            class_replaceMethod(self, selector, method_getImplementation(replacementMethod), method_getTypeEncoding(replacementMethod));
        }
    });
}

- (void)_rz_dealloc
{
    [self _rz_cleanupObservers];
    
    ((void(*)(id, SEL))objc_msgSend)(self, NSSelectorFromString([NSString stringWithFormat:@"%@%@", kRZDBDefaultSelectorPrefix, @"dealloc"]));
}
#endif

@end

#pragma mark - RZDBObserver implementation

@implementation RZDBObserver

- (instancetype)initWithObservedObject:(NSObject *)observedObject keyPath:(NSString *)keyPath observationOptions:(NSKeyValueObservingOptions)observingOptions
{
    self = [super init];
    if ( self != nil ) {
        self.observedObject = observedObject;
        self.keyPath = keyPath;
        self.observationOptions = observingOptions;
    }
    
    return self;
}

- (void)setTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey bindingFunction:(RZDBKeyBindingFunction)bindingFunction
{
    self.target = target;
    self.action = action;
    self.boundKey = boundKey;
    self.bindingFunction = bindingFunction;
    
    [self.observedObject addObserver:self forKeyPath:self.keyPath options:self.observationOptions context:kRZDBKVOContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ( context == kRZDBKVOContext ) {
        NSMethodSignature *signature = [self.target methodSignatureForSelector:self.action];
        
        if ( signature.numberOfArguments > 2 ) {
            NSDictionary *changeDict = [self changeDictForKVOChange:change];
            ((void(*)(id, SEL, id))objc_msgSend)(self.target, self.action, changeDict);
        }
        else {
            ((void(*)(id, SEL))objc_msgSend)(self.target, self.action);
        }
    }
}

- (NSDictionary *)changeDictForKVOChange:(NSDictionary *)kvoChange
{
    NSMutableDictionary *changeDict = [NSMutableDictionary dictionary];
    
    if ( self.observedObject != nil ) {
        changeDict[kRZDBChangeKeyObject] = self.observedObject;
    }
    
    if ( RZDBNotNull(kvoChange[NSKeyValueChangeOldKey]) ) {
        changeDict[kRZDBChangeKeyOld] = kvoChange[NSKeyValueChangeOldKey];
    }
    
    if ( RZDBNotNull(kvoChange[NSKeyValueChangeNewKey]) ) {
        changeDict[kRZDBChangeKeyNew] = kvoChange[NSKeyValueChangeNewKey];
    }
    
    if ( self.keyPath != nil ) {
        changeDict[kRZDBChangeKeyKeyPath] = self.keyPath;
    }
    
    if ( self.boundKey != nil ) {
        changeDict[kRZDBChangeKeyBoundKey] = self.boundKey;
    }
    
    if ( self.bindingFunction != nil ) {
        changeDict[kRZDBChangeKeyBindingFunctionKey] = self.bindingFunction;
    }
    
    return [changeDict copy];
}

- (void)invalidate
{
    [[self.target _rz_dependentObservers] removeObserver:self];
    [[self.observedObject _rz_registeredObservers] removeObject:self];
    
    @try {
        [self.observedObject removeObserver:self forKeyPath:self.keyPath context:kRZDBKVOContext];
    }
    @catch (NSException *exception) {}
    
    self.observedObject = nil;
    self.target = nil;
}

@end

#pragma mark - RZDBObserverContainer implementation

@implementation RZDBObserverContainer

- (instancetype)init
{
    self = [super init];
    if ( self != nil ) {
        self.observers = [NSPointerArray pointerArrayWithOptions:(NSPointerFunctionsWeakMemory | NSPointerFunctionsOpaquePersonality)];
    }
    return self;
}

- (void)addObserver:(RZDBObserver *)observer
{
    [self.observers addPointer:(__bridge void *)(observer)];
}

- (void)removeObserver:(RZDBObserver *)observer
{
    __block NSUInteger observerIndex = NSNotFound;
    [[self.observers allObjects] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ( obj == observer ) {
            observerIndex = idx;
            *stop = YES;
        }
    }];
    
    if ( observerIndex != NSNotFound ) {
        [self.observers removePointerAtIndex:observerIndex];
    }
}

@end
