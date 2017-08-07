//
//  DownLoadModel.h
//  ChargingPile
//
//  Created by SM on 16/9/5.
//  Copyright © 2016年 SM. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, DownloadState) {
    /**
     *  未下载
     */
    DownloadStateNone,
    /**
     *  等待下载
     */
    DownloadStateReadying,
    /**
     *  正在下载
     */
    DownloadStateRunning,
    /**
     *  下载暂停
     */
    DownloadStateSuspended,
    /*
     *  下载完成
     */
    DownloadStateCompleted,
    /**
     *  下载失败
     */
    DownloadStateFailed
};
@class DownloadProgress;
@class DownLoadModel;
// 进度更新block
typedef void (^DownloadProgressBlock)(DownloadProgress *progress,NSString *fileTotalSize,NSString *downloadedSize);
// 状态更新block
typedef void (^DownloadStateBlock)(DownloadState state,NSString *filePath, NSError *error);
@interface DownLoadModel : NSObject
// 下载地址
@property (nonatomic, strong, readonly) NSString *downloadURL;
// 文件名 默认nil 则为下载URL中的文件名
@property (nonatomic, strong, readonly) NSString *fileName;
// 缓存文件目录 默认nil 则为缓存目录
@property (nonatomic, strong, readonly) NSString *downloadDirectory;
// 下载状态
@property (nonatomic, assign, readonly) DownloadState state;
// 下载任务
@property (nonatomic, strong, readonly) NSURLSessionTask *task;
// 文件流
@property (nonatomic, strong, readonly) NSOutputStream *stream;
// 下载进度
@property (nonatomic, strong ,readonly) DownloadProgress *progress;
// 下载路径 如果设置了downloadDirectory，文件下载完成后会移动到这个目录默认cache目录里
@property (nonatomic, strong, readonly) NSString *filePath;

@property (nonatomic, copy) DownloadProgressBlock progressBlock;

@property (nonatomic, copy) DownloadStateBlock stateBlock;

- (instancetype)initWithURLString:(NSString *)URLString;
/**
 *  初始化方法
 *
 *  @param URLString 下载地址
 *  @param filePath  缓存地址 当为nil 默认缓存到cache
 */
- (instancetype)initWithURLString:(NSString *)URLString filePath:(NSString *)filePath;
@end
/**
 *  下载进度
 */
@interface DownloadProgress : NSObject
// 续传大小
@property (nonatomic, assign, readonly) int64_t resumeBytesWritten;
// 这次写入的数量
@property (nonatomic, assign, readonly) int64_t bytesWritten;
// 已下载的数量
@property (nonatomic, assign, readonly) int64_t totalBytesWritten;
// 文件的总大小
@property (nonatomic, assign, readonly) int64_t totalBytesExpectedToWrite;
// 下载进度
@property (nonatomic, assign, readonly) float progress;
// 下载速度
@property (nonatomic, assign, readonly) float speed;
// 下载剩余时间
@property (nonatomic, assign, readonly) int remainingTime;
@end
