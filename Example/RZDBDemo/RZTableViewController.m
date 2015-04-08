//
//  RZTableViewController.m
//  RZDBDemo
//
//  Created by Rob Visentin on 12/11/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

#import "RZTableViewController.h"
#import "RZUserViewController.h"

#import "RZDataBinding.h"
#import "UIImage+RZColor.h"
#import "UIColor+RZHexColor.h"

@interface RZTableViewController ()

@property (weak, nonatomic) IBOutlet UITableView *userTable;
@property (copy, nonatomic) NSArray *users;

@end

@implementation RZTableViewController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if ( self ) {
        NSMutableArray *users = [NSMutableArray array];
        
        for ( int i = 1; i <= 3; i++ ) {
            NSString *fileName = [NSString stringWithFormat:@"user%i", i];
            RZUser *user = [[RZUser alloc] initWithJSONFile:fileName];
            
            [users addObject:user];
        }
        
        self.users = users;
    }
    return self;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.users.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RZUserCell"];    
    RZUser *user = self.users[indexPath.row];
    
    [cell.textLabel rz_bindKey:RZDB_KP(UILabel, text) toKeyPath:RZDB_KP(RZUser, fullName) ofObject:user];
    
    [cell.imageView rz_bindKey:RZDB_KP(UIImageView, image) toKeyPath:RZDB_KP(RZUser, favoriteColorHex) ofObject:user withTransform:^id(id value) {
        UIColor *color = [UIColor rz_hexColor:(uint32_t)[value integerValue]];
        return [UIImage rz_imageWithColor:color size:CGSizeMake(35.0f, 35.0f)];
    }];
    
    [cell.detailTextLabel rz_bindKey:RZDB_KP(UILabel, text) toKeyPath:RZDB_KP(RZUser, age) ofObject:user withTransform:^id(id value) {
        return [value stringValue];
    }];
    
    return cell;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSIndexPath *indexPath = [self.userTable indexPathForCell:sender];
    
    RZUserViewController *userVC = (RZUserViewController *)segue.destinationViewController;
    userVC.user = self.users[indexPath.row];
}

@end
