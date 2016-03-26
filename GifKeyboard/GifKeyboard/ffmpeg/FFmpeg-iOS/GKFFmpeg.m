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

//static int open_codec_context(int *stream_idx,
//                              AVFormatContext *fmt_ctx, enum AVMediaType type)
//{
//    int ret, stream_index;
//    AVStream *st;
//    AVCodecContext *dec_ctx = NULL;
//    AVCodec *dec = NULL;
//    AVDictionary *opts = NULL;
//    
//    ret = av_find_best_stream(fmt_ctx, type, -1, -1, NULL, 0);
//    if (ret < 0) {
//        fprintf(stderr, "Could not find %s stream in input file '%s'\n",
//                av_get_media_type_string(type), "local files");
//        return ret;
//    } else {
//        stream_index = ret;
//        st = fmt_ctx->streams[stream_index];
//
//        /* find decoder for the stream */
//        dec_ctx = st->codec;
//        dec = avcodec_find_decoder(dec_ctx->codec_id);
//        if (!dec) {
//            fprintf(stderr, "Failed to find %s codec\n",
//                    av_get_media_type_string(type));
//                    return AVERROR(EINVAL);
//        }
//
//        /* Init the decoders, with or without reference counting */
//        av_dict_set(&opts, "refcounted_frames", "0", 0);
//        if ((ret = avcodec_open2(dec_ctx, dec, &opts)) < 0) {
//            fprintf(stderr, "Failed to open %s codec\n",
//                    av_get_media_type_string(type));
//            return ret;
//        }
//        *stream_idx = stream_index;
//    }
//    return 0;
//}

@interface GKFFmpeg(){
    AVFormatContext *avFormateCtx;
    AVStream *videoStream;
    AVCodecContext *videoDecCtx;
    AVCodec *avCodec;
    
    int64_t *pArrayTimeStamp;
    
    int video_stream_idx;
    
    NSInteger numberOfPackages;
    int64_t videoDuration;
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
#if 0
        for(int i=0; i<avFormateCtx->nb_streams; i++)
            if(avFormateCtx->streams[i]->codec->codec_type==AVMEDIA_TYPE_VIDEO){
                video_stream_idx=i;
                break;
            }
#else
//        open_codec_context(&video_stream_idx, avFormateCtx, AVMEDIA_TYPE_VIDEO);
        if ((video_stream_idx = av_find_best_stream(avFormateCtx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0)))
            return self;
#endif
        if (video_stream_idx < 0)
            return self;
        
        videoStream = avFormateCtx->streams[video_stream_idx];
        videoDecCtx = videoStream->codec;
        avCodec = avcodec_find_decoder(videoDecCtx->codec_id);
        if (!avCodec)
            return self;
        
        if (avcodec_open2(videoDecCtx, avCodec, NULL) < 0)
            return self;
        
        video_stream_idx = -1;
        pArrayTimeStamp = malloc(200*sizeof(int64_t));
        memset(pArrayTimeStamp, 0, sizeof(int64_t)*200);
        int length = 200;
        
        AVPacket orig_pkt;
        videoDuration = 0;
        numberOfPackages = 0;
        
        while (av_read_frame(avFormateCtx, &orig_pkt) >= 0) {
            numberOfPackages += 1;
            
            if (numberOfPackages>= length) {
                length += 200;
                pArrayTimeStamp = realloc(pArrayTimeStamp, length*sizeof(int64_t));
                memset(&pArrayTimeStamp[length-200], 0, 200*sizeof(int64_t));
            }
            
            pArrayTimeStamp[numberOfPackages] = videoDuration;
            videoDuration += orig_pkt.duration;
            
            av_packet_unref(&orig_pkt);
        }
        
        av_dump_format(avFormateCtx, 0, [path UTF8String], 0);
    }
    return self;
}
- (void)dealloc{
    if (videoDecCtx)
        avcodec_close(videoDecCtx);
    
    if (avFormateCtx)
        avformat_close_input(&avFormateCtx);

    if (pArrayTimeStamp){
        free(pArrayTimeStamp);
        pArrayTimeStamp = NULL;
    }
}
- (NSInteger)numberOfImages{
    return numberOfPackages;
}
- (UIImage *)imageAtIndex:(NSInteger)index{
    if (!videoStream || index<0 || index>numberOfPackages)
        return nil;
    
    int64_t seekTime = av_rescale_q(pArrayTimeStamp[index], AV_TIME_BASE_Q, videoStream->time_base);
    int64_t seekStreamDuration = videoStream->duration;
    int flags = AVSEEK_FLAG_BACKWARD;
    if (seekTime<0 || seekTime>=seekStreamDuration) {
        return nil;
    }
    
    int ret = av_seek_frame(avFormateCtx, video_stream_idx, seekTime, flags);
    if (ret<0)
        return nil;
    
    AVPacket pkt;
    /* initialize packet, set data to NULL, let the demuxer fill it */
    av_init_packet(&pkt);
    pkt.data = NULL;
    pkt.size = 0;
    
    if (av_read_frame(avFormateCtx, &pkt) >= 0) {
        int got_picture = 1;
        AVFrame *frame = av_frame_alloc();
        
        UIImage *imageDecode = nil;
        
        int ret = avcodec_decode_video2(videoStream->codec, frame, &got_picture, &pkt);
        if (ret > 0) {
            imageDecode = [self convertFrame:frame];
        }
        
        av_frame_free(&frame);
        av_packet_unref(&pkt);
        return imageDecode;
    }
    
    return nil;
}
- (UIImage *)convertFrame:(AVFrame *)pFrame{
    /* float with = pCodecCtx->width;
       float height = pCodecCtx->height;*/
    
//    if (pFrame->data[0]) {
//        struct SwsContext * scxt =sws_getContext(with,height,PIX_FMT_YUV420P,with,height,PIX_FMT_RGBA,SWS_POINT,NULL,NULL,NULL);
//        if (scxt == NULL) {
//            return nil;
//        }
//        
//        avpicture_alloc(&picture,PIX_FMT_RGBA, with, height);
//        sws_scale (scxt, (const uint8_t **)pFrame->data, pFrame->linesize, 0,height,picture.data, picture.linesize);
//        CGBitmapInfo bitmapInfo =kCGBitmapByteOrderDefault;
//        CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault,picture.data[0],picture.linesize[0]*height,kCFAllocatorNull);
//        CGDataProviderRef provider =CGDataProviderCreateWithCFData(data);
//        CGColorSpaceRef colorSpace =CGColorSpaceCreateDeviceRGB();
//        CGImageRef cgImage = CGImageCreate(with,height,
//                                           8,24,picture.linesize[0],
//                                           colorSpace,bitmapInfo,provider,NULL,NO,kCGRenderingIntentDefault);
//        CGColorSpaceRelease(colorSpace);
//        UIImage *image = [UIImageimageWithCGImage:cgImage];
//        CGImageRelease(cgImage);
//        CGDataProviderRelease(provider);
//        CFRelease(data);
//        return image;
//    }
//    return nil;
    
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
