//
//  RZUser.m
//  RZDBDemo
//
//  Created by Rob Visentin on 12/11/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

#import "RZUser.h"

@interface RZUser ()

@property (copy, nonatomic, readwrite) NSString *fullName;

@end

@implementation RZUser

- (instancetype)initWithJSONFile:(NSString *)fileName
{
    self = [super init];
    if ( self ) {
        NSData *data = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:fileName ofType:@"json"]];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        
        [self importValuesFromDict:dict];
    }
    
    return self;
}

- (void)setFirstName:(NSString *)firstName
{
    _firstName = [firstName copy];
    
    self.fullName = [firstName stringByAppendingFormat:@" %@", self.lastName];
}

- (void)setLastName:(NSString *)lastName
{
    _lastName = [lastName copy];
    
    self.fullName = [self.firstName stringByAppendingFormat:@" %@", lastName];
}

#pragma mark - private methods

- (void)importValuesFromDict:(NSDictionary *)dict
{
    self.firstName = dict[@"firstName"];
    self.lastName = dict[@"lastName"];
    self.age = [dict[@"age"] unsignedIntegerValue];
    self.favoriteColorHex = (uint32_t)[dict[@"color"] unsignedIntegerValue];
}

@end
