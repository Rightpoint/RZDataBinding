//
//  UIColor+RZHexColor.m
//  RZDBDemo
//
//  Created by Rob Visentin on 1/6/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import "UIColor+RZHexColor.h"

@implementation UIColor (RZHexColor)

+ (UIColor *)rz_hexColor:(uint32_t)hex
{
    uint32_t r = (hex & 0xFF0000) >> 16;
    uint32_t g = (hex & 0xFF00) >> 8;
    uint32_t b = hex & 0xFF;
    
    return [UIColor colorWithRed:(r / 255.0f) green:(g / 255.0f) blue:(b / 255.0f) alpha:1.0f];
}

@end
