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

@import Foundation;

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


@interface NSObject (RZDataBinding)

/**
 *  Register a selector to be called on a given target whenever keyPath changes on the receiver. The selector is not called immediately.
 *
 *  @param target  The object on which to call the action selector. Must be non-nil. This object is not retained.
 *  @param action  The selector to call on the target. Must not be NULL. The method must take either zero or exactly one parameter, an NSDictionary, and have a void return type. If the method has an NSDictionary parameter, the dictionary will contain values for the appropriate RZDBChangeKeys. If keys are absent, they can be assumed to be nil. Values will not be NSNull.
 *  @param keyPath The key path of the receiver for which changes should trigger an action. Must be KVC compliant.
 */
- (void)rz_addTarget:(id)target action:(SEL)action forKeyPathChange:(NSString *)keyPath;

/**
 *  Register a selector to be called on a given target whenever keyPath changes on the receiver.
 *
 *  @param target  The object on which to call the action selector. Must be non-nil. This object is not retained.
 *  @param action  The selector to call on the target. Must not be NULL. The method must take either zero or exactly one parameter, an NSDictionary, and have a void return type. If the method has an NSDictionary parameter, the dictionary will contain values for the appropriate RZDBChangeKeys. If keys are absent, they can be assumed to be nil. Values will not be NSNull.
 *  @param keyPath The key path of the receiver for which changes should trigger an action. Must be KVC compliant.
 *  @param callImmediately If YES, the action is also called immediately before this method returns. In this case the change dictionary, if present, will not contain a value for kRZDBChangeKeyOld.
 */
- (void)rz_addTarget:(id)target action:(SEL)action forKeyPathChange:(NSString *)keyPath callImmediately:(BOOL)callImmediately;

/**
 *  Removes previously registered target/action pairs so that the actions are no longer called when the receiver changes value for keyPath.
 *
 *  @param target  The target to remove. Must be non-nil.
 *  @param action  The action to remove. Pass NULL to remove all actions registered for the target.
 *  @param keyPath The key path to remove the target/action pair for.
 *
 *  @note There is obligation to call this method before either the target or receiver are deallocated.
 */
- (void)rz_removeTarget:(id)target action:(SEL)action forKeyPathChange:(NSString *)keyPath;

/**
 *  Binds the given key of the receiver to the value of a key path of another object. Before the key path of the object changes, the receiver sends a willChangeValueForKey message for the bound key. When the key path of the object changes, the receiver sets the same value for the bound key, and then sends a didChangeValueForKey message for the key. The receiver's value for the key will match the value for the object's foreign key path before this method returns.
 *
 *  @param key            The receiver's key whose value should be bound to the value of a foreign key path. Must be KVC compliant.
 *  @param foreignKeyPath A key path of another object to which the receiver's key value should be bound. Must be KVC compliant.
 *  @param object         An object with a key path that the receiver should bind to.
 */
- (void)rz_bindKey:(NSString *)key toKeyPath:(NSString *)foreignKeyPath ofObject:(id)object;

/**
 *  Unbinds the given key of the receiver from the key path of another object.
 *
 *  @param key            The key to unbind.
 *  @param foreignKeyPath The key path that the key should be unbound from.
 *  @param object         The object that the receiver should be unbound from.
 *
 *  @note There is no obligation to call this method before either the receiver or the foreign object are deallocated.
 */
- (void)rz_unbindKey:(NSString *)key fromKeyPath:(NSString *)foreignKeyPath ofObject:(id)object;

@end
