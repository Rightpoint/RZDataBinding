//
//  RZUser.m
//  RZDBDemo
//
//  Created by Rob Visentin on 12/11/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

#import "RZUser.h"

#import "RZDataBinding.h"

@interface RZUser ()

@property (copy, nonatomic, readwrite) NSString *fullName;

@end

@implementation RZUser

- (instancetype)initWithJSONFile:(NSString *)fileName
{
    self = [super init];
    if ( self ) {
        [self rz_addTarget:self action:@selector(updateFullName) forKeyPathChanges:@[RZDB_KP_SELF(firstName), RZDB_KP_SELF(lastName)]];
        
        NSData *data = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:fileName ofType:@"json"]];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        
        [self importValuesFromDict:dict];
    }
    
    return self;
}

#pragma mark - private methods

- (void)updateFullName
{
    self.fullName = [self.firstName stringByAppendingFormat:@" %@", self.lastName];
}

- (void)importValuesFromDict:(NSDictionary *)dict
{
    self.firstName = dict[@"firstName"];
    self.lastName = dict[@"lastName"];
    self.age = [dict[@"age"] unsignedIntegerValue];
    self.favoriteColorHex = (uint32_t)[dict[@"color"] unsignedIntegerValue];
}

@end
