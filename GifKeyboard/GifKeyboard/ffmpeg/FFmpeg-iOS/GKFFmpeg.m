//
//  GKFFmpeg.m
//  GifKeyboard
//
//  Created by LouieShum on 3/22/16.
//  Copyright © 2016 LouieShum. All rights reserved.
//

#import "GKFFmpeg.h"

#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavutil/avutil.h"
#include "libavutil/frame.h"
#include "libswscale/swscale.h"

@interface GKFFmpeg(){
    AVFormatContext *avFormateCtx;
    AVStream *videoStream;
    AVCodecContext *videoDecCtx;
    AVCodec *avCodec;
    
    int video_stream_idx;
}
@property (nonatomic, strong) NSString *path;
@end

@implementation GKFFmpeg
+ (GKFFmpeg *)mpegWithPath:(NSString *)string{
    if ([[NSFileManager defaultManager] fileExistsAtPath:string isDirectory:NULL]) {
        GKFFmpeg *mpeg = [[GKFFmpeg alloc] initWith:string];
        return mpeg;
    }
    return nil;
}
- (id)initWith:(NSString *)path{
    if ((self = [super init])) {
        self.path = path;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            /* register all formats and codecs */
            avcodec_register_all();
            av_register_all();
        });
        
        /* open input file, and allocate format context */
        int ret = avformat_open_input(&avFormateCtx, [path UTF8String], NULL, NULL);
        if (ret < 0){
            printf("ERROR : %d, open error %s", ret, [path UTF8String]);
            return self;
        }
        
        /* retrieve stream information */
        ret = avformat_find_stream_info(avFormateCtx, NULL);
        if (ret < 0){
            printf("ERROR : %d, avformat_find_stream_info %s", ret, [path UTF8String]);
            return  self;
        }
        
        video_stream_idx = -1;

        if ((video_stream_idx = av_find_best_stream(avFormateCtx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0)))
            return self;

        if (video_stream_idx < 0)
            return self;
        
        videoStream = avFormateCtx->streams[video_stream_idx];
        videoDecCtx = videoStream->codec;
        avCodec = avcodec_find_decoder(videoDecCtx->codec_id);
        if (!avCodec)
            return self;
        
        if (avcodec_open2(videoDecCtx, avCodec, NULL) < 0)
            return self;
        
        av_dump_format(avFormateCtx, 0, [path UTF8String], 0);
    }
    return self;
}
- (void)dealloc{
    if (videoDecCtx)
        avcodec_close(videoDecCtx);
    
    if (avFormateCtx)
        avformat_close_input(&avFormateCtx);
}
- (CGFloat)duration{
    return videoStream->duration * videoStream->time_base.num / videoStream->time_base.den;
}
- (NSInteger)numberOfImages{
    return [self duration] * 10;
//    return videoStream->nb_frames;
//    return numberOfPackages;
}
- (UIImage *)imageAtIndex:(NSInteger)index{
    if (!videoStream || index<0 || index>[self numberOfImages])
        return nil;
    
    if (![self seekToTime:index/10.0])
        return nil;
    
    UIImage *imageDecode = nil;
    AVFrame *frame = av_frame_alloc();
    AVPacket pkt;
    if([self stepFrame:frame withPacket:&pkt])
        imageDecode = [self convertFrame:frame];
    
    av_frame_free(&frame);
    av_packet_unref(&pkt);
    return imageDecode;
}

- (BOOL)seekToFrame:(int64_t)targetFrame{
    int ret = avformat_seek_file(avFormateCtx, video_stream_idx, targetFrame, targetFrame, targetFrame, AVSEEK_FLAG_FRAME);
    if (ret<0)
        return NO;
    avcodec_flush_buffers(videoDecCtx);
    return YES;
}
- (BOOL)seekToTime:(double)seconds{
    AVRational timeBase = videoStream->time_base;
    int64_t targetFrame = (int64_t)((double)timeBase.den / timeBase.num * seconds);
    
    int ret = avformat_seek_file(avFormateCtx, video_stream_idx, targetFrame, targetFrame, targetFrame, AVSEEK_FLAG_FRAME);
    if (ret<0)
        return NO;
    avcodec_flush_buffers(videoDecCtx);
    return YES;
}
- (BOOL)stepFrame:(AVFrame *)frame withPacket:(AVPacket *)pkt{
    int frameFinished=0;
    if (!frame)
        return NO;
    
    /* initialize packet, set data to NULL, let the demuxer fill it */
    av_init_packet(pkt);
    pkt->data = NULL;
    pkt->size = 0;
    
    while(!frameFinished && av_read_frame(avFormateCtx, pkt)>=0) {
        // Is this a packet from the video stream?
        if(pkt->stream_index==video_stream_idx) {
            // Decode video frame
            avcodec_decode_video2(videoStream->codec, frame, &frameFinished, pkt);
        }
    }
    return frameFinished!=0;
}
- (UIImage *)convertFrame:(AVFrame *)pFrame{
    float width = videoDecCtx->width;
    float height = videoDecCtx->height;
    
    if (!pFrame || !pFrame->data[0] || !width || !width)
        return nil;
    
    // Setup scaler
    struct AVPicture picture;
    avpicture_alloc(&picture, AV_PIX_FMT_RGB24, videoDecCtx->width, videoDecCtx->height);
    
    static int sws_flags =  SWS_FAST_BILINEAR;
    struct SwsContext *img_convert_ctx = sws_getContext(videoDecCtx->width,
                                                        videoDecCtx->height,
                                                        videoDecCtx->pix_fmt,
                                                        width,
                                                        height,
                                                        AV_PIX_FMT_RGB24,
                                                        sws_flags, NULL, NULL, NULL);
    sws_scale (img_convert_ctx,
               pFrame->data,
               pFrame->linesize,
               0,
               videoDecCtx->height,
               picture.data,
               picture.linesize);
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, picture.data[0], picture.linesize[0]*height,kCFAllocatorNull);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGImageRef cgImage = CGImageCreate(width,
                                       height,
                                       8,
                                       24,
                                       picture.linesize[0],
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    UIImage* image = [[UIImage alloc] initWithCGImage:cgImage];   //crespo modify 20111020
    
    UIGraphicsBeginImageContextWithOptions(image.size, NO, 1.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor redColor].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, image.size.width, image.size.height));
    
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    image =  UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    
    sws_freeContext(img_convert_ctx);
    avpicture_free(&picture);

    return image;
}
@end
