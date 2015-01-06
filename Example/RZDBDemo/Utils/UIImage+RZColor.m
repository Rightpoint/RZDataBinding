//
//  UIImage+RZColor.m
//  RZDBDemo
//
//  Created by Rob Visentin on 1/6/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import "UIImage+RZColor.h"

@implementation UIImage (RZColor)

+ (UIImage *)rz_imageWithColor:(UIColor *)color size:(CGSize)size
{
    UIGraphicsBeginImageContext(size);
    [color setFill];
    UIRectFill((CGRect){CGPointZero, size});
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return image;
}

@end
