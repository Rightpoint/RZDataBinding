//
//  RZUser.h
//  RZDBDemo
//
//  Created by Rob Visentin on 12/11/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

@import UIKit;

@interface RZUser : NSObject

@property (copy, nonatomic) NSString *firstName;
@property (copy, nonatomic) NSString *lastName;

@property (copy, nonatomic, readonly) NSString *fullName;

@property (assign, nonatomic) NSUInteger age;

@property (assign, nonatomic) uint32_t favoriteColorHex;

- (instancetype)initWithJSONFile:(NSString *)fileName;

@end
