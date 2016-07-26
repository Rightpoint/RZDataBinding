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

#import <objc/runtime.h>
#import <objc/message.h>

#import "NSObject+RZDataBinding.h"
#import "RZDBMacros.h"

@class RZDBObserver;
@class RZDBObserverContainer;

// public change keys
NSString* const kRZDBChangeKeyObject  = @"RZDBChangeObject";
NSString* const kRZDBChangeKeyOld     = @"RZDBChangeOld";
NSString* const kRZDBChangeKeyNew     = @"RZDBChangeNew";
NSString* const kRZDBChangeKeyKeyPath = @"RZDBChangeKeyPath";

// private change keys
static NSString* const kRZDBChangeKeyBoundKey            = @"_RZDBChangeBoundKey";
static NSString* const kRZDBChangeKeyBindingTransformKey = @"_RZDBChangeBindingTransform";

static void* const kRZDBSwizzledDeallocKey = (void *)&kRZDBSwizzledDeallocKey;

static void* const kRZDBKVOContext = (void *)&kRZDBKVOContext;

static void* const kRZDBRegisteredObserversKey = (void *)&kRZDBRegisteredObserversKey;
static void* const kRZDBDependentObserversKey = (void *)&kRZDBDependentObserversKey;

#define RZDBNotNull(obj) ((obj) != nil && ![(obj) isEqual:[NSNull null]])

#define rz_registeredObservers(obj) objc_getAssociatedObject(obj, kRZDBRegisteredObserversKey)
#define rz_setRegisteredObservers(obj, observers) objc_setAssociatedObject(obj, kRZDBRegisteredObserversKey, observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

#define rz_dependentObservers(obj) objc_getAssociatedObject(obj, kRZDBDependentObserversKey)
#define rz_setDependentObservers(obj, observers) objc_setAssociatedObject(obj, kRZDBDependentObserversKey, observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

#pragma mark - RZDataBinding_Private interface

// methods used to implement RZDB_AUTOMATIC_CLEANUP
BOOL rz_requiresDeallocSwizzle(Class class);
void rz_swizzleDeallocIfNeeded(Class class);

@interface NSObject (RZDataBinding_Private)

- (void)rz_addTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey bindingTransform:(RZDBKeyBindingTransform)bindingTransform forKeyPath:(NSString *)keyPath withOptions:(NSKeyValueObservingOptions)options;
- (void)rz_removeTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey forKeyPath:(NSString *)keyPath;
- (void)rz_observeBoundKeyChange:(NSDictionary *)change;
- (void)rz_setBoundKey:(NSString *)key withValue:(id)value transform:(RZDBKeyBindingTransform)transform;

@end

#pragma mark - RZDBObserver interface

@interface RZDBObserver : NSObject;

@property (assign, nonatomic) __unsafe_unretained NSObject *observedObject;
@property (copy, nonatomic) NSString *keyPath;
@property (copy, nonatomic) NSString *boundKey;
@property (assign, nonatomic) NSKeyValueObservingOptions observationOptions;

@property (assign, nonatomic) __unsafe_unretained id target;
@property (assign, nonatomic) SEL action;
@property (strong, nonatomic) NSMethodSignature *methodSignature;

@property (copy, nonatomic) RZDBKeyBindingTransform bindingTransform;

- (instancetype)initWithObservedObject:(NSObject *)observedObject keyPath:(NSString *)keyPath observationOptions:(NSKeyValueObservingOptions)observingOptions;

- (void)setTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey bindingTransform:(RZDBKeyBindingTransform)bindingTransform;

- (void)invalidate;

@end

#pragma mark - RZDBObserverContainer interface

@interface RZDBObserverContainer : NSObject

+ (instancetype)strongContainer;
+ (instancetype)weakContainer;

- (void)addObserver:(RZDBObserver *)observer;
- (void)removeObserver:(RZDBObserver *)observer;

- (void)enumerateObserversUsingBlock:(void (^)(RZDBObserver *observer, BOOL *stop))block;

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

    NSKeyValueObservingOptions observationOptions = kNilOptions;

    if ( [target methodSignatureForSelector:action].numberOfArguments > 2 ) {
        observationOptions |= NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld;
    }

    if ( callImmediately ) {
        observationOptions |= NSKeyValueObservingOptionInitial;
    }

    [self rz_addTarget:target action:action boundKey:nil bindingTransform:nil forKeyPath:keyPath withOptions:observationOptions];
}

- (void)rz_addTarget:(id)target action:(SEL)action forKeyPathChanges:(NSArray *)keyPaths
{
    [self rz_addTarget:target action:action forKeyPathChanges:keyPaths callImmediately:NO];
}

- (void)rz_addTarget:(id)target action:(SEL)action forKeyPathChanges:(NSArray *)keyPaths callImmediately:(BOOL)callImmediately
{
    BOOL callMultiple = NO;

    if ( callImmediately ) {
        callMultiple = [target methodSignatureForSelector:action].numberOfArguments > 2;
    }

    [keyPaths enumerateObjectsUsingBlock:^(NSString *keyPath, NSUInteger idx, BOOL *stop) {
        [self rz_addTarget:target action:action forKeyPathChange:keyPath callImmediately:callMultiple];
    }];

    if ( callImmediately && !callMultiple ) {
        ((void(*)(id, SEL))objc_msgSend)(target, action);
    }
}

- (void)rz_removeTarget:(id)target action:(SEL)action forKeyPathChange:(NSString *)keyPath
{
    [self rz_removeTarget:target action:action boundKey:nil forKeyPath:keyPath];
}

- (void)rz_bindKey:(NSString *)key toKeyPath:(NSString *)foreignKeyPath ofObject:(id)object
{
    [self rz_bindKey:key toKeyPath:foreignKeyPath ofObject:object withTransform:nil];
}

- (void)rz_bindKey:(NSString *)key toKeyPath:(NSString *)foreignKeyPath ofObject:(id)object withTransform:(RZDBKeyBindingTransform)bindingTransform
{
    NSParameterAssert(key);
    NSParameterAssert(foreignKeyPath);
    
    if ( object != nil ) {
        @try {
            id val = [object valueForKeyPath:foreignKeyPath];

            [self rz_setBoundKey:key withValue:val transform:bindingTransform];
        }
        @catch (NSException *exception) {
            [NSException raise:NSInvalidArgumentException format:@"RZDataBinding cannot bind key:%@ to key path:%@ of object:%@. Reason: %@", key, foreignKeyPath, [object description], exception.reason];
        }
        
        [object rz_addTarget:self action:@selector(rz_observeBoundKeyChange:) boundKey:key bindingTransform:bindingTransform forKeyPath:foreignKeyPath withOptions:NSKeyValueObservingOptionNew];
    }
}

- (void)rz_unbindKey:(NSString *)key fromKeyPath:(NSString *)foreignKeyPath ofObject:(id)object
{
    [object rz_removeTarget:self action:@selector(rz_observeBoundKeyChange:) boundKey:key forKeyPath:foreignKeyPath];
}

@end

#pragma mark - RZDataBinding_Private implementation

@implementation NSObject (RZDataBinding_Private)

- (void)rz_addTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey bindingTransform:(RZDBKeyBindingTransform)bindingTransform forKeyPath:(NSString *)keyPath withOptions:(NSKeyValueObservingOptions)options
{
    RZDBObserverContainer *registeredObservers = nil;
    RZDBObserverContainer *dependentObservers = nil;

    RZDBObserver *observer = [[RZDBObserver alloc] initWithObservedObject:self keyPath:keyPath observationOptions:options];

    [observer setTarget:target action:action boundKey:boundKey bindingTransform:bindingTransform];

    @synchronized (self) {
        registeredObservers = rz_registeredObservers(self);

        if ( registeredObservers == nil ) {
            registeredObservers = [RZDBObserverContainer strongContainer];
            rz_setRegisteredObservers(self, registeredObservers);
        }
    }

    [registeredObservers addObserver:observer];

    @synchronized (target) {
        dependentObservers = rz_dependentObservers(target);

        if ( dependentObservers == nil ) {
            dependentObservers = [RZDBObserverContainer weakContainer];
            rz_setDependentObservers(target, dependentObservers);
        }
    }

    [dependentObservers addObserver:observer];

#if RZDB_AUTOMATIC_CLEANUP
    rz_swizzleDeallocIfNeeded([self class]);
    rz_swizzleDeallocIfNeeded([target class]);
#endif
}

- (void)rz_removeTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey forKeyPath:(NSString *)keyPath
{
    [rz_registeredObservers(self) enumerateObserversUsingBlock:^(RZDBObserver *observer, BOOL *stop) {
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

- (void)rz_observeBoundKeyChange:(NSDictionary *)change
{
    NSString *boundKey = change[kRZDBChangeKeyBoundKey];
    
    if ( boundKey != nil ) {
        id value = change[kRZDBChangeKeyNew];

        [self rz_setBoundKey:boundKey withValue:value transform:change[kRZDBChangeKeyBindingTransformKey]];
    }
}

- (void)rz_setBoundKey:(NSString *)key withValue:(id)value transform:(RZDBKeyBindingTransform)transform
{
    id currentValue = [self valueForKey:key];

    if ( transform != nil ) {
        value = transform(value);
    }

    if ( currentValue != value && ![currentValue isEqual:value] ) {
        [self setValue:value forKey:key];
    }
}

- (void)rz_cleanupObservers
{
    [rz_registeredObservers(self) enumerateObserversUsingBlock:^(RZDBObserver *obs, BOOL *stop) {
        [obs invalidate];
    }];

    [rz_dependentObservers(self) enumerateObserversUsingBlock:^(RZDBObserver *obs, BOOL *stop) {
        [obs invalidate];
    }];
}

@end

#pragma mark - RZDBObserver implementation

@implementation RZDBObserver

- (instancetype)initWithObservedObject:(NSObject *)observedObject keyPath:(NSString *)keyPath observationOptions:(NSKeyValueObservingOptions)observingOptions
{
    self = [super init];
    if ( self != nil ) {
        _observedObject = observedObject;
        _keyPath = keyPath;
        _observationOptions = observingOptions;
    }
    
    return self;
}

- (void)setTarget:(id)target action:(SEL)action boundKey:(NSString *)boundKey bindingTransform:(RZDBKeyBindingTransform)bindingTransform
{
    self.target = target;
    self.action = action;
    self.methodSignature = [target methodSignatureForSelector:action];

    self.boundKey = boundKey;
    self.bindingTransform = bindingTransform;

    [self.observedObject addObserver:self forKeyPath:self.keyPath options:self.observationOptions context:kRZDBKVOContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ( context == kRZDBKVOContext ) {
        id target = nil;
        SEL action = NULL;
        NSDictionary *changeDict = nil;

        @synchronized (self) {
            target = self.target;
            action = self.action;

            if ( self.methodSignature.numberOfArguments > 2 ) {
                changeDict = [self changeDictForKVOChange:change];
            }
        }

        if ( changeDict != nil ) {
            ((void(*)(id, SEL, NSDictionary *))objc_msgSend)(target, action, changeDict);
        }
        else {
            ((void(*)(id, SEL))objc_msgSend)(target, action);
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
    
    if ( self.bindingTransform != nil ) {
        changeDict[kRZDBChangeKeyBindingTransformKey] = self.bindingTransform;
    }
    
    return [changeDict copy];
}

- (void)invalidate
{
    id observedObject = self.observedObject;

    [rz_dependentObservers(self.target) removeObserver:self];
    [rz_registeredObservers(observedObject) removeObserver:self];

    // KVO throws an exception when removing an observer that was never added.
    // This should never be a problem given how things are setup, but make sure to avoid a crash.
    @try {
        [observedObject removeObserver:self forKeyPath:self.keyPath context:kRZDBKVOContext];
    }
    @catch (__unused NSException *exception) {
        RZDBLog(@"RZDataBinding attempted to remove an observer from object:%@, but the observer was never added. This shouldn't have happened, but won't affect anything going forward.", observedObject);
    }

    @synchronized (self) {
        self.observedObject = nil;
        self.target = nil;
        self.action = NULL;
        self.methodSignature = nil;
    }
}

@end

#pragma mark - RZDBObserverContainer implementation

@implementation RZDBObserverContainer {
    NSHashTable *_observers;
}

+ (instancetype)strongContainer
{
    return [[self alloc] initWithBackingStore:[NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality]];
}

+ (instancetype)weakContainer
{
    return [[self alloc] initWithBackingStore:[NSHashTable weakObjectsHashTable]];
}

- (instancetype)initWithBackingStore:(NSHashTable *)backingStore
{
    self = [super init];
    if ( self != nil ) {
        _observers = backingStore;
    }
    return self;
}

- (void)addObserver:(RZDBObserver *)observer
{
    @synchronized (self) {
        [_observers addObject:observer];
    }
}

- (void)removeObserver:(RZDBObserver *)observer
{
    @synchronized (self) {
        [_observers removeObject:observer];
    }
}

- (void)enumerateObserversUsingBlock:(void (^)(RZDBObserver *, BOOL *))block
{
    @synchronized (self) {
        NSHashTable *observers = ^{
            @synchronized (_observers) {
                return [_observers copy];
            }
        }();

        BOOL stop = NO;
        for ( RZDBObserver *observer in observers ) {
            if ( observer != nil ) {
                block(observer, &stop);
            }

            if ( stop ) {
                break;
            }
        }
    }
}

@end

// a class doesn't need dealloc swizzled if it or a superclass has been swizzled already
BOOL rz_requiresDeallocSwizzle(Class class)
{
    BOOL swizzled = NO;

    for ( Class currentClass = class; !swizzled && currentClass != nil; currentClass = class_getSuperclass(currentClass) ) {
        swizzled = [objc_getAssociatedObject(currentClass, kRZDBSwizzledDeallocKey) boolValue];
    }

    return !swizzled;
}

// In order for automatic cleanup to work, observers must be removed before deallocation.
// This method ensures that rz_cleanupObservers is called in the dealloc of classes of objects
// that are used in RZDataBinding.
void rz_swizzleDeallocIfNeeded(Class class)
{
    static SEL deallocSEL = NULL;
    static SEL cleanupSEL = NULL;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        deallocSEL = sel_getUid("dealloc");
        cleanupSEL = sel_getUid("rz_cleanupObservers");
    });

    @synchronized (class) {
        if ( !rz_requiresDeallocSwizzle(class) ) {
            // dealloc swizzling already resolved
            return;
        }

        objc_setAssociatedObject(class, kRZDBSwizzledDeallocKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    Method dealloc = NULL;

    // search instance methods of the class (does not search superclass methods)
    unsigned int n;
    Method *methods = class_copyMethodList(class, &n);

    for ( unsigned int i = 0; i < n; i++ ) {
        if ( method_getName(methods[i]) == deallocSEL ) {
            dealloc = methods[i];
            break;
        }
    }

    free(methods);

    if ( dealloc == NULL ) {
        Class superclass = class_getSuperclass(class);

        // class does not implement dealloc, so implement it directly
        class_addMethod(class, deallocSEL, imp_implementationWithBlock(^(__unsafe_unretained id self) {

            // cleanup RZDB observers
            ((void(*)(id, SEL))objc_msgSend)(self, cleanupSEL);

            // ARC automatically calls super when dealloc is implemented in code,
            // but when provided our own dealloc IMP we have to call through to super manually
            struct objc_super superStruct = (struct objc_super){ self, superclass };
            ((void (*)(struct objc_super*, SEL))objc_msgSendSuper)(&superStruct, deallocSEL);

        }), method_getTypeEncoding(dealloc));
    }
    else {
        // class implements dealloc, so extend the existing implementation
        __block IMP deallocIMP = method_setImplementation(dealloc, imp_implementationWithBlock(^(__unsafe_unretained id self) {
            // cleanup RZDB observers
            ((void(*)(id, SEL))objc_msgSend)(self, cleanupSEL);

            // invoke the original dealloc IMP
            ((void(*)(id, SEL))deallocIMP)(self, deallocSEL);
        }));
    }
}
