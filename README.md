RZDataBinding
===========
<p align="center">
<img src="http://cl.ly/image/1r0I0x401W2m/chain.png"
alt="RZDataBinding">
</p>
## Overview
`RZDataBinding` is a framework designed to help preserve data integrity in your iOS or OSX app. It is built using the standard Key-Value Observation (KVO) framework, but is safer and provides additional functionality.

## Why not use plain KVO?
Consider the following code, which seeks to call `nameChanged` when a user's name changed, and `ageChanged` when a user's age changes:

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
               forKeyPath:@"age"
               options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
               context:MyKVOContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object change:(NSDictionary *)change
                       context:(void *)context
{
  if ( context == MyKVOContext ) {
        if ( [object isEqual:self.user] ) {
            if ( [keyPath isEqualToString:@"name"] ) {
                [self nameChanged];
            }
            else if ( [keyPath isEqualToString:@"age"] ) {
                [self ageChanged];
            }
        }
    }
}

- (void)dealloc
{
    [self.user removeObserver:self forKeyPath:@"name" context:MyKVOContext];
    [self.user removeObserver:self forKeyPath:@"age" context:MyKVOContext];
}
```

**Using RZDataBinding:**
``` obj-c
- (void)setupKVO
{
    [self.user rz_addTarget:self action:@selector(nameChanged) forKeyPathChange:@"name"];
    [self.user rz_addTarget:self action:@selector(ageChanged) forKeyPathChange:@"age"];
}
```
