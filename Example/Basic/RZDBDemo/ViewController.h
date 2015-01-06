//
//  ViewController.h
//  RZDBDemo
//
//  Created by Rob Visentin on 12/11/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

@import UIKit;

#import "RZDBUser.h"

@interface ViewController : UIViewController

@property (strong, nonatomic) RZDBUser *user;

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *colorLabel;

@property (weak, nonatomic) IBOutlet UIImageView *heartView;

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadingSpinner;

@end

