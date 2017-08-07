//
//  CPDownLoadManger.h
//  ChargingPile
//
//  Created by SM on 16/9/5.
//  Copyright © 2016年 SM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DownLoadModel.h"

@protocol CPDownLoadMangerDelegate <NSObject>

@optional
/**
 *   更新下载进度
 *
 *  @param downloadModel <#downloadModel description#>
 *  @param progress      <#progress description#>
 */
- (void)downloadModel:(DownLoadModel *)downloadModel didUpdateProgress:(DownloadProgress *)progress;
/**
 *  更新下载状态
 *
 *  @param downloadModel <#downloadModel description#>
 *  @param state         <#state description#>
 *  @param filePath      <#filePath description#>
 *  @param error         <#error description#>
 */
- (void)downloadModel:(DownLoadModel *)downloadModel didChangeState:(DownloadState)state filePath:(NSString *)filePath error:(NSError *)error;

@end

@interface CPDownLoadManger : NSObject<NSURLSessionDownloadDelegate>
/**
 *  <#Description#>
 */
@property(nonatomic,strong,readonly)NSMutableArray *waitingDownloadModels;
/**
 *  <#Description#>
 */
@property(nonatomic,strong,readonly)NSMutableArray *downloadingModels;
/**
 *  <#Description#>
 */
@property(nonatomic,weak)id <CPDownLoadMangerDelegate>delegate;
/**
 *  最在下载数
 */
@property (nonatomic, assign) NSInteger maxDownloadCount;
/**
 *  等待下载队列 先进先出 默认YES， 当NO时，先进后出
 */
@property (nonatomic, assign) BOOL resumeDownloadFIFO;
/**
 *  全部并发 默认NO, 当YES时，忽略maxDownloadCount
 */
@property (nonatomic, assign) BOOL isBatchDownload;
/**
 *  <#Description#>
 */
@property (nonatomic, strong) NSString *backgroundConfigure;
/**
 *  <#Description#>
 */
@property (nonatomic, copy) void (^backgroundSessionCompletionHandler)();
/**
 *  后台下载完成回调
 */
@property (nonatomic, copy) NSString *(^backgroundSessionDownloadCompleteBlock)(NSString *downloadURL);
/**
 *  单例
 *
 *  @return <#return value description#>
 */
+(instancetype)sharedManager;
/**
 *  下载
 *
 *  @param URLString       <#URLString description#>
 *  @param destinationPath <#destinationPath description#>
 *  @param progress        <#progress description#>
 *  @param state           <#state description#>
 *
 *  @return <#return value description#>
 */
- (DownLoadModel *)startDownloadURLString:(NSString *)URLString toDestinationPath:(NSString *)destinationPath progress:(DownloadProgressBlock)progress state:(DownloadStateBlock)state;
/**
 *  下载
 *
 *  @param downloadModel <#downloadModel description#>
 */
- (void)startWithDownloadModel:(DownLoadModel *)downloadModel;

// 开始下载
- (void)startWithDownloadModel:(DownLoadModel *)downloadModel progress:(DownloadProgressBlock)progress state:(DownloadStateBlock)state;

/**
 *  恢复下载（除非确定对这个model进行了suspend，否则使用start）
 *
 *  @param downloadModel
 */
- (void)resumeWithDownloadModel:(DownLoadModel *)downloadModel;
/**
 *  暂停下载
 *
 *  @param downloadModel <#downloadModel description#>
 */
- (void)suspendWithDownloadModel:(DownLoadModel *)downloadModel;
/**
 *  取消下载
 *
 *  @param downloadModel <#downloadModel description#>
 */
- (void)cancleWithDownloadModel:(DownLoadModel *)downloadModel;
/**
 *   删除下载
 *
 *  @param downloadModel <#downloadModel description#>
 */
- (void)deleteFileWithDownloadModel:(DownLoadModel *)downloadModel;

/**
 *  删除所有下载
 *
 *  @param downloadDirectory <#downloadDirectory description#>
 */
- (void)deleteAllFileWithDownloadDirectory:(NSString *)downloadDirectory;
/**
 *  获取正在下载模型
 *
 *  @param URLString <#URLString description#>
 *
 *  @return <#return value description#>
 */
- (DownLoadModel *)downLoadingModelForURLString:(NSString *)URLString;
/**
 *  获取进度
 *
 *  @param downloadModel <#downloadModel description#>
 *
 *  @return <#return value description#>
 */
- (DownloadProgress *)progessWithDownloadModel:(DownLoadModel *)downloadModel;
/**
 *  是否已经下载
 *
 *  @param downloadModel <#downloadModel description#>
 *
 *  @return <#return value description#>
 */
- (BOOL)isDownloadCompletedWithDownloadModel:(DownLoadModel *)downloadModel;
@end
