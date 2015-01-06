//
//  RZUserViewController.m
//  RZDBDemo
//
//  Created by Rob Visentin on 1/6/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import "RZUserViewController.h"

#import "NSObject+RZDataBinding.h"
#import "UIColor+RZHexColor.h"

@interface RZUserViewController ()

@property (assign, nonatomic) uint32_t currentHex;

@end

@implementation RZUserViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.firstNameField.text = self.user.firstName;
    self.lastNameField.text = self.user.lastName;
    
    self.ageStepper.value = self.user.age;
    [self.ageLabel rz_bindKey:RZDB_KP(UILabel, text) toKeyPath:RZDB_KP(UIStepper, value) ofObject:self.ageStepper withFunction:^id(id value) {
        return [value stringValue];
    }];
    
    self.rSlider.value = ((self.user.favoriteColorHex & 0xFF0000) >> 16) / 255.0f;
    self.gSlider.value = ((self.user.favoriteColorHex & 0xFF00) >> 8) / 255.0f;
    self.bSlider.value = (self.user.favoriteColorHex & 0xFF) / 255.0f;
    
    [self updateHex];

    [self.colorView rz_bindKey:RZDB_KP(UIView, backgroundColor) toKeyPath:RZDB_KP(RZUserViewController, currentHex) ofObject:self withFunction:^id(id value) {
        return [UIColor rz_hexColor:(uint32_t)[value integerValue]];
    }];
}

- (IBAction)updateHex
{
    uint32_t r = (uint8_t)(self.rSlider.value * 255.0f) << 16;
    uint32_t g = (uint8_t)(self.gSlider.value * 255.0f) << 8;
    uint32_t b = (uint8_t)(self.bSlider.value * 255.0f);

    self.currentHex = (r | g | b);
}

- (IBAction)donePressed
{
    self.user.firstName = self.firstNameField.text;
    self.user.lastName = self.lastNameField.text;
    
    self.user.age = self.ageStepper.value;
    
    self.user.favoriteColorHex = self.currentHex;
    
    [self.navigationController popViewControllerAnimated:YES];
}

@end
