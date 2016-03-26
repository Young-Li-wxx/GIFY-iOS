//
//  GKFFmpeg.h
//  GifKeyboard
//
//  Created by LouieShum on 3/22/16.
//  Copyright © 2016 LouieShum. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface GKFFmpeg : NSObject
+ (GKFFmpeg *)mpegWithPath:(NSString *)string;

- (NSInteger)numberOfImages;
- (UIImage *)imageAtIndex:(NSInteger)index;
@end
