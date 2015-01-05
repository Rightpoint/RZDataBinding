RZDataBinding
===========
<p align="center">
<img src="http://cl.ly/image/1r0I0x401W2m/chain.png"
alt="RZDataBinding">
</p>
## Overview
`RZDataBinding` is a framework designed to help maintain data integrity in your iOS or OSX app. It is built using the standard Key-Value Observation (KVO) framework, but is safer and provides additional functionality. Like KVO, `RZDataBinding` helps to avoid endless delegate chains by establishing direct callbacks for when an object changes state.

##Usage
**Register a callback for when the keypath of an object changes:**
``` obj-c
// Register a selector to be called on a given target whenever keyPath changes on the receiver.
// Action must take either zero or exactly one parameter, an NSDictionary. 
// If the method has a parameter, the dictionary will contain values for the appropriate 
// RZDBChangeKeys. If keys are absent, they can be assumed to be nil. Values will not be NSNull.
- (void)rz_addTarget:(id)target
        action:(SEL)action
        forKeyPathChange:(NSString *)keyPath;
```

**Bind values of two objects together either directly or with a function:**
``` obj-c
// Binds the value of a given key of the receiver to the value of a key path of another object. 
// When the key path of the object changes, the bound key of the receiver is also changed.
- (void)rz_bindKey:(NSString *)key
        toKeyPath:(NSString *)foreignKeyPath
        ofObject:(id)object;

// Same as the above method, but the binding function is first applied 
// to the changed value before setting the value of the bound key.
// If nil, the identity function is assumed, making it identical to regular rz_bindKey.
- (void)rz_bindKey:(NSString *)key 
        toKeyPath:(NSString *)foreignKeyPath 
        ofObject:(id)object
        withFunction:(RZDBKeyBindingFunction)bindingFunction;
```
Targets can be removed and keys unbound with corresponding removal methods, but unlike with standard KVO, you are not obligated to do so. `RZDataBinding` will automatically cleanup observers before objects are deallocated. 

## Why not use plain KVO?
Consider the following code, which calls `nameChanged:` when a user object's name changes, and reload a collection view when the user's preferences change:

**Using KVO:**
``` obj-c
static void* const MyKVOContext = (void *)&MyKVOContext;

- (void)setupKVO
{
    [self.user addObserver:self
               forKeyPath:@"name"
               options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
               context:MyKVOContext]; 
                  
    [self.user addObserver:self
               forKeyPath:@"preferences"
               options:kNilOptions
               context:MyKVOContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object change:(NSDictionary *)change
                       context:(void *)context
{
  if ( context == MyKVOContext ) {
        if ( [object isEqual:self.user] ) {
            if ( [keyPath isEqualToString:@"name"] ) {
                [self nameChanged:change];
            }
            else if ( [keyPath isEqualToString:@"preferences"] ) {
                [self.collectionView reloadData];
            }
        }
    }
}

- (void)dealloc
{
    [self.user removeObserver:self forKeyPath:@"name" context:MyKVOContext];
    [self.user removeObserver:self forKeyPath:@"preferences" context:MyKVOContext];
}
```

**Using RZDataBinding:**
``` obj-c
- (void)setupKVO
{
    [self.user rz_addTarget:self 
               action:@selector(nameChanged:) 
               forKeyPathChange:@"name"];
    
    [self.user rz_addTarget:self.collectionView 
               action:@selector(reloadData) 
               forKeyPathChange:@"preferences"];
}
```
Aside from the obvious reduction in code, the `RZDataBinding` implementation demonstrates several other wins:

1. No need to manage different KVO contexts and check which object/keypath changed
2. No need to implement an instance method, meaning *any* object can be added as a target
3. No need to teardown before deallocation (standard KVO crashes if you fail to do this)

`RZDataBinding` also provides a convenience macro to create keypaths that are checked at compile time for validity (not shown in this example). No more unwieldy `NSStringFromSelector(@selector(foo:))`!
