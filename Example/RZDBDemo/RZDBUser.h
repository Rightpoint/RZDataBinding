//
//  RZDBUser.h
//  RZDBDemo
//
//  Created by Rob Visentin on 12/11/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

@import UIKit;

@interface RZDBUser : NSObject

@property (copy, nonatomic, readonly) NSString *name;
@property (copy, nonatomic, readonly) NSString *favoriteColorName;
@property (assign, nonatomic, readonly) uint32_t favoriteColorHex;
@property (assign, nonatomic, readonly) NSUInteger heartbeat;

@property (assign, nonatomic, readonly) BOOL loading;

- (void)loadDataFromJSONFile:(NSString *)fileName;

@end
