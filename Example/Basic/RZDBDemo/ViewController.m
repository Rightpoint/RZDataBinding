//
//  ViewController.m
//  RZDBDemo
//
//  Created by Rob Visentin on 12/11/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+RZDataBinding.h"

@interface UIColor (RZDBHexColor)

+ (UIColor *)rzdb_hexColor:(uint32_t)hex;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.user = [[RZDBUser alloc] init];
    
    [self.nameLabel rz_bindKey:RZDBKey(text) toKeyPath:RZDBKey(name) ofObject:self.user];
    [self.colorLabel rz_bindKey:RZDBKey(text) toKeyPath:RZDBKey(favoriteColorName) ofObject:self.user];
    
    [self.colorLabel rz_bindKey:RZDBKey(textColor) toKeyPathValue:RZDBKey(favoriteColorHex) ofObject:self.user withFunction:^id(NSValue *value) {
        uint32_t hex = (uint32_t)[(NSNumber *)value unsignedIntegerValue];
        return [UIColor rzdb_hexColor:hex];
    }];
    
    [self.user rz_addTarget:self action:@selector(heartbeatChanged:) forKeyPathChange:RZDBKey(heartbeat)];
    [self.user rz_addTarget:self action:@selector(loadingStatusChanged:) forKeyPathChange:RZDBKey(loading)];
}

- (IBAction)segmentControlChanged:(UISegmentedControl *)segmentControl
{
    NSString *userID = [segmentControl titleForSegmentAtIndex:segmentControl.selectedSegmentIndex];
    [self.user loadDataFromJSONFile:userID];
}

- (void)heartbeatChanged:(NSDictionary *)change
{
    NSUInteger bpm = [change[kRZDBChangeKeyNew] unsignedIntegerValue];
    
    NSTimeInterval duration = (60.0f / bpm);
    
    CABasicAnimation *heartbeat = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    heartbeat.fromValue = @(1.0f);
    heartbeat.toValue = @(1.25f);
    heartbeat.duration = duration;
    heartbeat.autoreverses = YES;
    heartbeat.repeatCount = HUGE_VALF;
    
    [self.heartView.layer addAnimation:heartbeat forKey:@"heartbeat"];
}

- (void)loadingStatusChanged:(NSDictionary *)change
{
    BOOL loading = [change[kRZDBChangeKeyNew] boolValue];
    
    self.view.userInteractionEnabled = !loading;
    
    if ( loading ) {
        [self.loadingSpinner startAnimating];
    }
    else {
        [self.loadingSpinner stopAnimating];
    }
}

@end

@implementation UIColor (RZDBHexColor)

+ (UIColor *)rzdb_hexColor:(uint32_t)hex
{
    uint32_t r = (hex & 0xFF0000) >> 16;
    uint32_t g = (hex & 0xFF00) >> 8;
    uint32_t b = hex & 0xFF;
    
    return [UIColor colorWithRed:(r / 255.0f) green:(g / 255.0f) blue:(b / 255.0f) alpha:1.0f];
}

@end
