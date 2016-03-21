//
//  DetailViewController.h
//  GifKeyboard
//
//  Created by LouieShum on 3/21/16.
//  Copyright © 2016 LouieShum. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController

@property (strong, nonatomic) id detailItem;
@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;

@end

