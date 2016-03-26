//
//  DetailViewController.m
//  GifKeyboard
//
//  Created by LouieShum on 3/21/16.
//  Copyright © 2016 LouieShum. All rights reserved.
//

#import "DetailViewController.h"
#import "GKFFmpeg.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVKit/AVKit.h>

@interface ViewThumbCell : UICollectionViewCell{
    UIImageView *imageView;
}
@end
@implementation ViewThumbCell
- (id)initWithFrame:(CGRect)frame{
    if ((self = [super initWithFrame:frame])) {
        imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        imageView.backgroundColor = [UIColor blackColor];
        [self addSubview:imageView];
    }
    return self;
}
- (void)prepareForReuse{
    imageView.image = nil;
}
- (void)setImage:(UIImage *)image{
    imageView.image = image;
}
@end

@interface DetailViewController ()<UICollectionViewDataSource, UICollectionViewDelegate, AVPlayerViewControllerDelegate>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) GKFFmpeg *currentVideo;

@property (nonatomic, strong) AVPlayerViewController *playerVC;
@end

@implementation DetailViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.currentVideo = [GKFFmpeg mpegWithPath:self.path];
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.itemSize = CGSizeMake(self.view.bounds.size.width/4-2, self.view.bounds.size.width/4-2);
    layout.minimumInteritemSpacing = 2;
    layout.minimumLineSpacing = 2;
    
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height-self.view.bounds.size.width-2, self.view.bounds.size.width, self.view.bounds.size.width+2) collectionViewLayout:layout];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.collectionView registerClass:[ViewThumbCell class] forCellWithReuseIdentifier:@"cell"];
    [self.view addSubview:self.collectionView];
    self.collectionView.backgroundColor = [UIColor grayColor];
    
    AVPlayerViewController *playerVC = [AVPlayerViewController new];
    [self addChildViewController:playerVC];
    playerVC.view.frame = CGRectMake(0, 64, self.view.bounds.size.width, self.collectionView.frame.origin.y-64);
    playerVC.videoGravity = AVLayerVideoGravityResizeAspect;
    playerVC.delegate = self;
    playerVC.allowsPictureInPicturePlayback = TRUE;
    playerVC.showsPlaybackControls = FALSE;
    [self.view addSubview:playerVC.view];
    
    self.playerVC = playerVC;
    self.playerVC.player = nil;
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Play" style:UIBarButtonItemStylePlain target:self action:@selector(actionPlayer:)];
}
- (void)actionPlayer:(id)sender{
    if (!self.playerVC.player) {
        AVPlayer *player = [AVPlayer playerWithURL:[[NSURL alloc] initFileURLWithPath:self.path]];
        self.playerVC.player = player;
    }
    if (self.playerVC.player.rate == 0.0){
        CMTime time = [self.playerVC.player currentTime];
        time.value = 0;
        [self.playerVC.player seekToTime:time];
        [self.playerVC.player play];
        self.navigationItem.rightBarButtonItem.title = @"Stop";
    }
    else{
        [self.playerVC.player pause];
        self.navigationItem.rightBarButtonItem.title = @"Play";
    }
}
#pragma mark - collectionview delegate
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return self.currentVideo.numberOfImages;
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    ViewThumbCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    [cell setImage:[self.currentVideo imageAtIndex:indexPath.row]];
    return cell;
}

#pragma mark - AVPlayerViewControllerDelegate
- (void)playerViewControllerWillStartPictureInPicture:(AVPlayerViewController *)playerViewController {
    NSLog(@"%s", __FUNCTION__);
}

- (void)playerViewControllerDidStartPictureInPicture:(AVPlayerViewController *)playerViewController {
    NSLog(@"%s", __FUNCTION__);
}

- (void)playerViewController:(AVPlayerViewController *)playerViewController failedToStartPictureInPictureWithError:(NSError *)error {
    NSLog(@"%s", __FUNCTION__);
}

- (void)playerViewControllerWillStopPictureInPicture:(AVPlayerViewController *)playerViewController {
    NSLog(@"%s", __FUNCTION__);
}

- (void)playerViewControllerDidStopPictureInPicture:(AVPlayerViewController *)playerViewController {
    NSLog(@"%s", __FUNCTION__);
}

- (BOOL)playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart:(AVPlayerViewController *)playerViewController {
    NSLog(@"%s", __FUNCTION__);
    return true;
}

- (void)playerViewController:(AVPlayerViewController *)playerViewController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL))completionHandler {
    NSLog(@"%s", __FUNCTION__);
}

@end
