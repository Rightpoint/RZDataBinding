//
//  NSObject+RZDataBinding.h
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

#import <Foundation/Foundation.h>
#import "RZDBMacros.h"

#pragma mark - Constants and Definitions

/**
 *  The value for this key is the object that changed. This key is always present.
 */
OBJC_EXTERN NSString* const kRZDBChangeKeyObject;

/**
 *  If present, the value for this key is the previous value on a key path change.
 */
OBJC_EXTERN NSString* const kRZDBChangeKeyOld;

/**
 *  If present, the value for this key is the new value on a key path change, or the exisiting value for the key path for the initial call.
 */
OBJC_EXTERN NSString* const kRZDBChangeKeyNew;

/**
 *  The value for this key is the key path that changed value. This key is always present.
 */
OBJC_EXTERN NSString* const kRZDBChangeKeyKeyPath;

/**
 *  A function that takes a value as a parameter and returns an object.
 *
 *  @param value The value that just changed on a foreign object for a bound key path.
 *
 *  @return The value to set for the bound key. Ideally the returned value should depend solely on the input value.
 */
typedef id (^RZDBKeyBindingFunction)(id value);

/**
 *  Set this to 1 (recommended) to enable automatic cleanup of observers on object deallocation.
 *  If enabled, it is safe to observe or bind to weak references, and there is need to call rz_removeTarget
 *  or rz_unbindKey before targets or observed objects are deallocated. To achieve automatic cleanup,
 *  RZDB swizzles the dealloc method to ensure observers are properly invalidated. There are other ways of implementing similar
 *  behavior, but we found this to be both the safest and most reliable in production.
 *
 *  If set to 0 (not recommended), objects MUST remove themselves as targets and unbind their keys from any observed objects before being deallocated.
 *  Failure to do so will result in crashes (just like standard KVO). Additionally, you should not add a target to or bind keys to 
 *  objects without first establishing a strong reference. Otherwise, the foreign object might be deallocated before the observer, causing in a crash.
 *  If you choose to disable global automatic cleanup by setting this to 0, you may still use the RZDBObservableObject as a base class to enable
 *  class-specific automatic cleanup.
 */
#ifndef RZDB_AUTOMATIC_CLEANUP
#define RZDB_AUTOMATIC_CLEANUP 1
#endif

#pragma mark - NSObject+RZDataBinding interface

@interface NSObject (RZDataBinding)

/**
 *  Register a selector to be called on a given target whenever keyPath changes on the receiver. The selector is not called immediately.
 *
 *  @param target  The object on which to call the action selector. Must be non-nil. This object is not retained.
 *  @param action  The selector to call on the target. Must not be NULL. The method must take either zero or exactly one parameter, an NSDictionary, and have a void return type. If the method has an NSDictionary parameter, the dictionary will contain values for the appropriate RZDBChangeKeys. If keys are absent, they can be assumed to be nil. Values will not be NSNull.
 *  @param keyPath The key path of the receiver for which changes should trigger an action. Must be KVC compliant.
 *
 *  @see RZDB_KP macro for creating keypaths.
 */
- (void)rz_addTarget:(id)target action:(SEL)action forKeyPathChange:(NSString *)keyPath;

/**
 *  Register a selector to be called on a given target whenever keyPath changes on the receiver.
 *
 *  @param target  The object on which to call the action selector. Must be non-nil. This object is not retained.
 *  @param action  The selector to call on the target. Must not be NULL. The method must take either zero or exactly one parameter, an NSDictionary, and have a void return type. If the method has an NSDictionary parameter, the dictionary will contain values for the appropriate RZDBChangeKeys. If keys are absent, they can be assumed to be nil. Values will not be NSNull.
 *  @param keyPath The key path of the receiver for which changes should trigger an action. Must be KVC compliant.
 *  @param callImmediately If YES, the action is also called immediately before this method returns. In this case the change dictionary, if present, will not contain a value for kRZDBChangeKeyOld.
 *
 *  @see RZDB_KP macro for creating keypaths.
 */
- (void)rz_addTarget:(id)target action:(SEL)action forKeyPathChange:(NSString *)keyPath callImmediately:(BOOL)callImmediately;

/**
 *  Register a selector to be called on a given target whenever keyPath changes on the receiver.
 *
 *  @param target  The object on which to call the action selector. Must be non-nil. This object is not retained.
 *  @param action  The selector to call on the target. Must not be NULL. The method must take either zero or exactly one parameter, an NSDictionary, and have a void return type. If the method has an NSDictionary parameter, the dictionary will contain values for the appropriate RZDBChangeKeys. If keys are absent, they can be assumed to be nil. Values will not be NSNull.
 *  @param keyPath The key path of the receiver for which changes should trigger an action. Must be KVC compliant.
 *  @param callImmediately If YES, the action is dispatched asychronously on the callback queue. If callback queue is nil, the action is called immediately on the current queue before this method returns. In this case the change dictionary, if present, will not contain a value for kRZDBChangeKeyOld.
 *  @param callbackQueue The queue on which actions should be called. If non-nil, actions are dispatched asynchronously on the callback queue. If nil, actions are sent immediately on whatever queue the change occurs.
 *
 *  @see RZDB_KP macro for creating keypaths.
 */
- (void)rz_addTarget:(id)target action:(SEL)action forKeyPathChange:(NSString *)keyPath callImmediately:(BOOL)callImmediately callbackQueue:(dispatch_queue_t)callbackQueue;

/**
 *  A convenience method that calls rz_addTarget:action:forKeyPathChange: for each keyPath in the keyPaths array.
 *
 *  @param target   The object on which to call the action selector. Must be non-nil. This object is not retained.
 *  @param action   The selector to call on the target. Must not be NULL. See rz_addTarget documentation for more details.
 *  @param keyPaths An array of key paths that should trigger an action. Each key path must be KVC compliant.
 *
 *  @note The action is not called immediately.
 *
 *  @see RZDB_KP macro for creating keypaths.
 */
- (void)rz_addTarget:(id)target action:(SEL)action forKeyPathChanges:(NSArray *)keyPaths;

/**
 *  A convenience method that calls rz_addTarget:action:forKeyPathChange: for each keyPath in the keyPaths array.
 *
 *  @param target   The object on which to call the action selector. Must be non-nil. This object is not retained.
 *  @param action   The selector to call on the target. Must not be NULL. See rz_addTarget documentation for more details.
 *  @param keyPaths An array of key paths that should trigger an action. Each key path must be KVC compliant.
 *  @param callbackQueue The queue on which actions should be called. If non-nil, actions are dispatched asynchronously on the callback queue. If nil, actions are sent immediately on whatever queue the change occurs.
 *
 *  @note The action is not called immediately.
 *
 *  @see RZDB_KP macro for creating keypaths.
 */
- (void)rz_addTarget:(id)target action:(SEL)action forKeyPathChanges:(NSArray *)keyPaths callbackQueue:(dispatch_queue_t)callbackQueue;

/**
 *  Removes previously registered target/action pairs so that the actions are no longer called when the receiver changes value for keyPath.
 *
 *  @param target  The target to remove. Must be non-nil.
 *  @param action  The action to remove. Pass NULL to remove all actions registered for the target.
 *  @param keyPath The key path to remove the target/action pair for.
 *
 *  @note If RZDB_AUTOMATIC_CLEANUP is enabled, then there is obligation to call this method before either the target or receiver are deallocated.
 *
 *  @see RZDB_KP macro for creating keypaths.
 */
- (void)rz_removeTarget:(id)target action:(SEL)action forKeyPathChange:(NSString *)keyPath;

/**
 *  Binds the value of a given key of the receiver to the value of a key path of another object. When the key path of the object changes, the bound key of the receiver is set to the same value. The receiver's value for the key will match the value for the object's foreign key path before this method returns.
 *
 *  @param key            The receiver's key whose value should be bound to the value of a foreign key path. Must be KVC compliant.
 *  @param foreignKeyPath A key path of another object to which the receiver's key value should be bound. Must be KVC compliant.
 *  @param object         An object with a key path that the receiver should bind to.
 *
 *  @see RZDB_KP macro for creating keypaths.
 */
- (void)rz_bindKey:(NSString *)key toKeyPath:(NSString *)foreignKeyPath ofObject:(id)object;

/**
 *  Binds the value of a given key of the receiver to the value of a key path of another object. When the key path of the object changes, the binding function is invoked and the bound key of the receiver is set to the function's return value. The receiver's value for the key will be set before this method returns.
 *
 *  @param key            The receiver's key whose value should be bound to the value of a foreign key path. Must be KVC compliant.
 *  @param foreignKeyPath A key path of another object to which the receiver's key value should be bound. Must be KVC compliant.
 *  @param object         An object with a key path that the receiver should bind to.
 *  @param bindingFunction The function to apply to changed values before setting the value of the bound key. If nil, the identity function is assumed, making this method identical to regular rz_bindKey.
 *
 *  @see RZDB_KP macro for creating keypaths.
 */
- (void)rz_bindKey:(NSString *)key toKeyPath:(NSString *)foreignKeyPath ofObject:(id)object withFunction:(RZDBKeyBindingFunction)bindingFunction;

/**
 *  Unbinds the given key of the receiver from the key path of another object.
 *
 *  @param key            The key to unbind.
 *  @param foreignKeyPath The key path that the key should be unbound from.
 *  @param object         The object that the receiver should be unbound from.
 *
 *  @note If RZDB_AUTOMATIC_CLEANUP is enabled, then there is no obligation to call this method before either the receiver or the foreign object are deallocated.
 *
 *  @see RZDB_KP macro for creating keypaths.
 */
- (void)rz_unbindKey:(NSString *)key fromKeyPath:(NSString *)foreignKeyPath ofObject:(id)object;

@end

#pragma mark - RZDBTransacton interface

/**
 *  Transactions define a chunk of work that should be completed "atomically" with respect to RZDataBinding.
 *  That is, actions registered using the rz_addTarget:action: methods will be fired once, when the work is completed.
 *
 *  Transactions are are advanced feature that should generally only be used if you encounter a performance issue,
 *  or find some other requirement for event coalescing.
 */
@interface RZDBTransaction : NSObject

/**
 *  Begin a new transaction for the current thread.
 *  Changes that occur during the transaction that would trigger actions registered with the 
 *  rz_addTarget:action: methods are instead coalesced and executed once when the transaction ends.
 *
 *  Every call to +begin MUST be balanced by a call to +commit on the same thread.
 *  It is fine to begin a transaction while already inside a transaction--
 *  the transaction will simply not end until both matching commits are hit.
 *
 *  @note Bindings that occur during a transaction still occur immediately, and are not coalesced.
 */
+ (void)begin;

/**
 *  Commit the current transaction, sending all change callbacks that coalesced during the transaction.
 *  If this commit closes a nested transaction, callbacks are not sent until the outermost transaction is committed.
 *
 *  Calling this method from outside a transaction has no effect.
 */
+ (void)commit;

/**
 *  Convenience method that first calls +begin, then executes the block, then calls +commit.
 *  You should prefer this method where possible to avoid programmer error (i.e. forgetting to call +commit).
 *
 *  @param transactionBlock The block to execute inside a transaction. Must be non-nil.
 */
+ (void)transactionWithBlock:(void (^)())transactionBlock;

- (instancetype)init __attribute__((unavailable("Cannot instantiate RZDBTransaction directly. Use the class methods to control transactions.")));

@end

#pragma mark - RZDBObservableObject interface

/**
 *  A base class that automatically cleans up the appropriate observers before being deallocated, replicating the behavior of RZDB_AUTOMATIC_CLEANUP.
 *  When adding targets or binding to RZDBObservableObject instances, it is not necessary to call rz_removeTarget or rz_unbindKey before
 *  either the target or observable object are deallocated.
 *
 *  @note If RZDB_AUTOMATIC_CLEANUP is enabled, there is no need to use this base class. Use of this base class is intended for users who wish to disable
 *  global automatic cleanup, but easily enable it for certain classes.
 *
 *  @see RZDB_AUTOMATIC_CLEANUP
 */
@interface RZDBObservableObject : NSObject
@end
