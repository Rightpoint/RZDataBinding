//
//  RZDBUser.m
//  RZDBDemo
//
//  Created by Rob Visentin on 12/11/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

#import "RZDBUser.h"

@interface RZDBUser ()

@property (copy, nonatomic, readwrite) NSString *name;
@property (copy, nonatomic, readwrite) NSString *favoriteColorName;
@property (assign, nonatomic, readwrite) uint32_t favoriteColorHex;
@property (assign, nonatomic, readwrite) NSUInteger heartbeat;

@property (assign, nonatomic, readwrite) BOOL loading;

@end

@implementation RZDBUser

- (instancetype)init
{
    self = [super init];
    if ( self ) {
        self.name = @"Grim";
        self.favoriteColorName = @"Black";
        self.favoriteColorHex = 0x0;
        self.heartbeat = 0;
    }
    
    return self;
}

- (void)loadDataFromJSONFile:(NSString *)fileName
{
    self.loading = YES;
    
    // artificially cause a load time 2 - 4 sec
    __weak __typeof(self)wself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((2 + arc4random_uniform(3)) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong __typeof(wself)sself = wself;
        
        // no error handling because yolo
        NSData *data = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:fileName ofType:@"json"]];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        
        [sself importValuesFromDict:dict];
        
        sself.loading = NO;
    });
}

#pragma mark - private methods

- (void)importValuesFromDict:(NSDictionary *)dict
{
    self.name = dict[@"name"];
    self.favoriteColorName = dict[@"colorName"];
    self.favoriteColorHex = (uint32_t)[dict[@"color"] unsignedIntegerValue];
    self.heartbeat = [dict[@"heartbeat"] unsignedIntegerValue];
}

@end
