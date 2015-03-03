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

@implementation RZUserViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.firstNameField.text = self.user.firstName;
    self.lastNameField.text = self.user.lastName;
    
    self.ageStepper.value = self.user.age;
    [self.ageLabel rz_bindKey:RZDB_KP(UILabel *, text) toKeyPath:RZDB_KP(UIStepper *, value) ofObject:self.ageStepper withFunction:^id(id value) {
        return [value stringValue];
    }];
    
    [self.user rz_bindKey:RZDB_KP(RZUser *, age) toKeyPath:RZDB_KP(UIStepper *, value) ofObject:self.ageStepper];
    
    self.rSlider.value = ((self.user.favoriteColorHex & 0xFF0000) >> 16) / 255.0f;
    self.gSlider.value = ((self.user.favoriteColorHex & 0xFF00) >> 8) / 255.0f;
    self.bSlider.value = (self.user.favoriteColorHex & 0xFF) / 255.0f;

    [self.colorView rz_bindKey:RZDB_KP(UIView *, backgroundColor) toKeyPath:RZDB_KP(RZUser *, favoriteColorHex) ofObject:self.user withFunction:^id(id value) {
        return [UIColor rz_hexColor:(uint32_t)[value integerValue]];
    }];
    
    [self.firstNameField addTarget:self action:@selector(firstNameChanged) forControlEvents:UIControlEventEditingChanged];
    [self.lastNameField addTarget:self action:@selector(lastNameChanged) forControlEvents:UIControlEventEditingChanged];
}

- (IBAction)updateHex
{
    uint32_t r = (uint8_t)(self.rSlider.value * 255.0f) << 16;
    uint32_t g = (uint8_t)(self.gSlider.value * 255.0f) << 8;
    uint32_t b = (uint8_t)(self.bSlider.value * 255.0f);

    self.user.favoriteColorHex = (r | g | b);
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if ( textField == self.firstNameField ) {
        [self.lastNameField becomeFirstResponder];
    }
    else {
        [textField resignFirstResponder];
    }
    
    return YES;
}

- (void)firstNameChanged
{
    self.user.firstName = self.firstNameField.text;
}

- (void)lastNameChanged
{
    self.user.lastName = self.lastNameField.text;
}

@end
