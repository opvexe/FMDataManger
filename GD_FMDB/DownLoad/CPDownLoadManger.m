//
//  CPDownLoadManger.m
//  ChargingPile
//
//  Created by SM on 16/9/5.
//  Copyright © 2016年 SM. All rights reserved.
//

#import "CPDownLoadManger.h"
#import "NSString+CPHash.h"
#import "CPDownLoadSessionManger.h"
@interface  DownLoadModel()
@property (nonatomic, assign) DownloadState state;

@property (nonatomic, strong) NSURLSessionDataTask *task;

@property (nonatomic, strong) NSOutputStream *stream;

@property (nonatomic, strong) NSString *filePath;

@property (nonatomic, strong) NSDate *downloadDate;

@property (nonatomic, strong) NSData *resumeData;

@property (nonatomic, assign) BOOL manualCancle;
@end

@interface DownloadProgress ()
// 续传大小
@property (nonatomic, assign) int64_t resumeBytesWritten;
// 这次写入的数量
@property (nonatomic, assign) int64_t bytesWritten;
// 已下载的数量
@property (nonatomic, assign) int64_t totalBytesWritten;
// 文件的总大小
@property (nonatomic, assign) int64_t totalBytesExpectedToWrite;
// 下载进度
@property (nonatomic, assign) float progress;
// 下载速度
@property (nonatomic, assign) float speed;
// 下载剩余时间
@property (nonatomic, assign) int remainingTime;

@end

@interface CPDownLoadSessionManger ()
@property (nonatomic, strong) NSFileManager *fileManager;
// 缓存文件目录
@property (nonatomic, strong) NSString *downloadDirectory;

// 下载seesion会话
@property (nonatomic, strong) NSURLSession *session;
// 下载模型字典 key = url, value = model
@property (nonatomic, strong) NSMutableDictionary *downloadingModelDic;
// 下载中的模型
@property (nonatomic, strong) NSMutableArray *waitingDownloadModels;
// 等待中的模型
@property (nonatomic, strong) NSMutableArray *downloadingModels;
// 回调代理的队列
@property (strong, nonatomic) NSOperationQueue *queue;

@end

@interface CPDownLoadManger()
@property (nonatomic, strong) NSFileManager *fileManager;
// 缓存文件目录
@property (nonatomic, strong) NSString *downloadDirectory;

// 下载seesion会话
@property (nonatomic, strong) NSURLSession *session;
// 下载模型字典 key = url, value = model
@property (nonatomic, strong) NSMutableDictionary *downloadingModelDic;
// 下载中的模型
@property (nonatomic, strong) NSMutableArray *waitingDownloadModels;
// 等待中的模型
@property (nonatomic, strong) NSMutableArray *downloadingModels;
// 回调代理的队列
@property (strong, nonatomic) NSOperationQueue *queue;
@end

@implementation CPDownLoadManger
/**
 *  单例
 */
static CPDownLoadManger *_manger ;
+(instancetype)sharedManager{

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manger = [[self alloc] init];
    });

    return  _manger;
}
+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manger = [super allocWithZone:zone];
    });
    return _manger;
}
- (id)copyWithZone:(NSZone *)zone
{
    return _manger;
}
#pragma 方法
-(DownLoadModel *)startDownloadURLString:(NSString *)URLString toDestinationPath:(NSString *)destinationPath progress:(DownloadProgressBlock)progress state:(DownloadStateBlock)state{

    if (!URLString) {
        NSLog(@"dwonloadURL can't nil");
        return nil;
    }

    DownLoadModel *model = [self downLoadingModelForURLString:URLString];

    if (!model ||[model.filePath isEqualToString:destinationPath]) {

        model = [[DownLoadModel alloc]initWithURLString:URLString filePath:destinationPath];
    }

    [self startWithDownloadModel:model progress:progress state:state];

    return model;
}

- (void)startWithDownloadModel:(DownLoadModel *)downloadModel progress:(DownloadProgressBlock)progress state:(DownloadStateBlock)state
{
    downloadModel.progressBlock = progress;
    downloadModel.stateBlock = state;

    [self startWithDownloadModel:downloadModel];
}

- (void)startWithDownloadModel:(DownLoadModel *)downloadModel{

    if (!downloadModel) {
        return;
    }

    if (downloadModel.state ==DownloadStateReadying) {

        [self downloadModel:downloadModel didChangeState:DownloadStateReadying filePath:nil error:nil];
    }


    // 验证是否已经下载文件
    if ([self isDownloadCompletedWithDownloadModel:downloadModel]) {
        downloadModel.state = DownloadStateCompleted;
        [self downloadModel:downloadModel didChangeState:DownloadStateCompleted filePath:downloadModel.filePath error:nil];
        return;
    }

    if (downloadModel.task &&downloadModel.task.state ==NSURLSessionTaskStateRunning) {

        downloadModel.state = DownloadStateRunning;

        [self downloadModel:downloadModel didChangeState:DownloadStateRunning filePath:nil error:nil];

        return ;
    }

    [self resumeWithDownloadModel:downloadModel];

}
//恢复下载
- (void)resumeWithDownloadModel:(DownLoadModel *)downloadModel{

    if (!downloadModel) {
        return;
    }

    if (![self canResumeDownlaodModel:downloadModel]) {
        return;
    }

    //任务不存在 或者 取消了
    if (!downloadModel.task ||downloadModel.task.state == NSURLSessionTaskStateCanceling) {


        NSString *URLString = downloadModel.downloadURL;

        // 创建请求
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];

        // 设置请求头
        NSString *range = [NSString stringWithFormat:@"bytes=%zd-", [self fileSizeWithDownloadModel:downloadModel]];
        [request setValue:range forHTTPHeaderField:@"Range"];

        // 创建流
        downloadModel.stream = [NSOutputStream outputStreamToFileAtPath:downloadModel.filePath append:YES];

        downloadModel.downloadDate = [NSDate date];
        self.downloadingModelDic[downloadModel.downloadURL] = downloadModel;
        // 创建一个Data任务
        downloadModel.task = [self.session dataTaskWithRequest:request];
        downloadModel.task.taskDescription = URLString;

    }

    [downloadModel.task resume];

    downloadModel.state = DownloadStateRunning ;

    [self downloadModel:downloadModel didChangeState:DownloadStateRunning filePath:nil error:nil];

}
- (BOOL)isValideResumeData:(NSData *)resumeData
{
    if (!resumeData || resumeData.length == 0) {
        return NO;
    }
    return YES;
}
// 暂停下载
- (void)suspendWithDownloadModel:(DownLoadModel *)downloadModel
{
    if (!downloadModel.manualCancle) {
        downloadModel.manualCancle = YES;
       [downloadModel.task cancel];
    }
}
// 取消下载 是否删除resumeData
- (void)cancleWithDownloadModel:(DownLoadModel *)downloadModel clearResumeData:(BOOL)clearResumeData{

    if (!downloadModel.task &&downloadModel.state ==DownloadStateReadying ) {

        [self removeDownLoadingModelForURLString:downloadModel.downloadURL];

        @synchronized (self) {

            [self.waitingDownloadModels removeObject:downloadModel];
        }

        downloadModel.state = DownloadStateNone;

        [self downloadModel:downloadModel didChangeState:DownloadStateNone filePath:nil error:nil];

        return ;
    }

    if (clearResumeData) {
        downloadModel.resumeData = nil;
        [downloadModel.task cancel];
    }else {
        [(NSURLSessionDownloadTask *)downloadModel.task cancelByProducingResumeData:^(NSData *resumeData){
        }];
    }
}
/**
 *  取消下载
 *
 *  @param downloadModel <#downloadModel description#>
 */
- (void)cancleWithDownloadModel:(DownLoadModel *)downloadModel
{
    if (!downloadModel.task && downloadModel.state == DownloadStateReadying) {
        [self removeDownLoadingModelForURLString:downloadModel.downloadURL];
        @synchronized (self) {
            [self.waitingDownloadModels removeObject:downloadModel];
        }
        downloadModel.state = DownloadStateNone;
        [self downloadModel:downloadModel didChangeState:DownloadStateNone filePath:nil error:nil];
        return;
    }
    if (downloadModel.state != DownloadStateCompleted && downloadModel.state != DownloadStateFailed){
        [downloadModel.task cancel];
    }
}
/**
 *  删除下载
 *
 *  @param downloadModel <#downloadModel description#>
 */
- (void)deleteFileWithDownloadModel:(DownLoadModel *)downloadModel{

    if (!downloadModel || !downloadModel.filePath) {
        return;
    }

    // 文件是否存在
    if ([self.fileManager fileExistsAtPath:downloadModel.filePath]) {

        // 删除任务
        downloadModel.task.taskDescription = nil;
        [downloadModel.task cancel];
        downloadModel.task = nil;

        // 删除流
        if (downloadModel.stream.streamStatus > NSStreamStatusNotOpen && downloadModel.stream.streamStatus < NSStreamStatusClosed) {
            [downloadModel.stream close];
        }
        downloadModel.stream = nil;
        // 删除沙盒中的资源
        NSError *error = nil;
        [self.fileManager removeItemAtPath:downloadModel.filePath error:&error];
        if (error) {
            NSLog(@"delete file error %@",error);
        }

        [self removeDownLoadingModelForURLString:downloadModel.downloadURL];
        // 删除资源总长度
        if ([self.fileManager fileExistsAtPath:[self fileSizePathWithDownloadModel:downloadModel]]) {
            @synchronized (self) {
                NSMutableDictionary *dict = [self fileSizePlistWithDownloadModel:downloadModel];
                [dict removeObjectForKey:downloadModel.downloadURL];
                [dict writeToFile:[self fileSizePathWithDownloadModel:downloadModel] atomically:YES];
            }
        }
    }


}

/**
 *  删除所有下载文件
 *
 *  @param downloadDirectory
 */
- (void)deleteAllFileWithDownloadDirectory:(NSString *)downloadDirectory
{
    if (!downloadDirectory) {
        downloadDirectory = self.downloadDirectory;
    }
    if ([self.fileManager fileExistsAtPath:downloadDirectory]) {

        // 删除任务
        for (DownLoadModel *downloadModel in [self.downloadingModelDic allValues]) {

            if ([downloadModel.downloadDirectory isEqualToString:downloadDirectory]) {
                // 删除任务
                downloadModel.task.taskDescription = nil;
                [downloadModel.task cancel];
                downloadModel.task = nil;

                // 删除流
                if (downloadModel.stream.streamStatus > NSStreamStatusNotOpen && downloadModel.stream.streamStatus < NSStreamStatusClosed) {
                    [downloadModel.stream close];
                }
                downloadModel.stream = nil;
            }
        }
        // 删除沙盒中所有资源
        [self.fileManager removeItemAtPath:downloadDirectory error:nil];
    }
}
//是否恢复下载
- (BOOL)canResumeDownlaodModel:(DownLoadModel *)downloadModel
{
    if (_isBatchDownload) {
        return YES;
    }

    @synchronized (self) {
        if (self.downloadingModels.count >= self.maxDownloadCount ) {
            if ([self.waitingDownloadModels indexOfObject:downloadModel] == NSNotFound) {
                [self.waitingDownloadModels addObject:downloadModel];
                self.downloadingModelDic[downloadModel.downloadURL] = downloadModel;
            }
            downloadModel.state = DownloadStateReadying;
            [self downloadModel:downloadModel didChangeState:DownloadStateReadying filePath:nil error:nil];
            return NO;
        }

        if ([self.waitingDownloadModels indexOfObject:downloadModel] != NSNotFound) {
            [self.waitingDownloadModels removeObject:downloadModel];
        }

        if ([self.downloadingModels indexOfObject:downloadModel] == NSNotFound) {
            [self.downloadingModels addObject:downloadModel];
        }
        return YES;
    }
}
/**
 *  恢复下一个任务
 *
 *  @param downloadModel <#downloadModel description#>
 */
- (void)willResumeNextWithDowloadModel:(DownLoadModel *)downloadModel
{
    if (_isBatchDownload) {
        return;
    }

    @synchronized (self) {
        [self.downloadingModels removeObject:downloadModel];
        // 还有未下载的
        if (self.waitingDownloadModels.count > 0) {
            [self resumeWithDownloadModel:self.resumeDownloadFIFO ? self.waitingDownloadModels.firstObject:self.waitingDownloadModels.lastObject];
        }
    }
}
#pragma mark - public  方法
// 获取下载模型
- (DownLoadModel *)downLoadingModelForURLString:(NSString *)URLString
{
    return [self.downloadingModelDic valueForKey:URLString];
}

// 是否已经下载
- (BOOL)isDownloadCompletedWithDownloadModel:(DownLoadModel *)downloadModel
{

    long long fileSize = [self fileSizeInCachePlistWithDownloadModel:downloadModel];
    if (fileSize > 0 && fileSize == [self fileSizeWithDownloadModel:downloadModel]) {
        return YES;
    }
    return NO;
}

// 当前下载进度
- (DownloadProgress *)progessWithDownloadModel:(DownLoadModel *)downloadModel
{
    DownloadProgress *progress = [[DownloadProgress alloc]init];
    progress.totalBytesExpectedToWrite = [self fileSizeInCachePlistWithDownloadModel:downloadModel];
    progress.totalBytesWritten = MIN([self fileSizeWithDownloadModel:downloadModel], progress.totalBytesExpectedToWrite);
    progress.progress = progress.totalBytesExpectedToWrite > 0 ? 1.0*progress.totalBytesWritten/progress.totalBytesExpectedToWrite : 0;

    return progress;
}
#pragma mark 创建缓存目录文件

- (void)createDirectory:(NSString *)directory
{
    if (![self.fileManager fileExistsAtPath:directory]) {
        [self.fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}

// 获取文件大小
- (long long)fileSizeWithDownloadModel:(DownLoadModel *)downloadModel{
    NSString *filePath = downloadModel.filePath;
    if (![self.fileManager fileExistsAtPath:filePath]) return 0;
    return [[self.fileManager attributesOfItemAtPath:filePath error:nil] fileSize];
}

// 获取plist保存文件大小
- (long long)fileSizeInCachePlistWithDownloadModel:(DownLoadModel *)downloadModel
{
    NSDictionary *downloadsFileSizePlist = [NSDictionary dictionaryWithContentsOfFile:[self fileSizePathWithDownloadModel:downloadModel]];
    return [downloadsFileSizePlist[downloadModel.downloadURL] longLongValue];
}

// 获取plist文件内容
- (NSMutableDictionary *)fileSizePlistWithDownloadModel:(DownLoadModel *)downloadModel
{
    NSMutableDictionary *downloadsFileSizePlist = [NSMutableDictionary dictionaryWithContentsOfFile:[self fileSizePathWithDownloadModel:downloadModel]];
    if (!downloadsFileSizePlist) {
        downloadsFileSizePlist = [NSMutableDictionary dictionary];
    }
    return downloadsFileSizePlist;
}


//移动缓存
- (void)moveFileAtURL:(NSURL *)srcURL toPath:(NSString *)dstPath
{
    NSError *error = nil;
    if ([self.fileManager fileExistsAtPath:dstPath] ) {
        [self.fileManager removeItemAtPath:dstPath error:&error];
        if (error) {
            NSLog(@"removeItem error %@",error);
        }
    }

    NSURL *dstURL = [NSURL fileURLWithPath:dstPath];
    [self.fileManager moveItemAtURL:srcURL toURL:dstURL error:&error];
    if (error){
        NSLog(@"moveItem error:%@",error);
    }
}
/**
 *  删除
 *
 *  @param filePath <#filePath description#>
 */
- (void)deleteFileIfExist:(NSString *)filePath
{
    if ([self.fileManager fileExistsAtPath:filePath] ) {
        NSError *error  = nil;
        [self.fileManager removeItemAtPath:filePath error:&error];
        if (error) {
            NSLog(@"emoveItem error %@",error);
        }
    }
}
#pragma mark
/**
 *  下载改变状态
 *
 *  @param downloadModel <#downloadModel description#>
 *  @param state         <#state description#>
 *  @param filePath      <#filePath description#>
 *  @param error         <#error description#>
 */
- (void)downloadModel:(DownLoadModel *)downloadModel didChangeState:(DownloadState)state filePath:(NSString *)filePath error:(NSError *)error
{

    if (self.delegate && [self.delegate respondsToSelector:@selector(downloadModel:didChangeState:filePath:error:)]) {

        [self.delegate downloadModel:downloadModel didChangeState:state filePath:filePath error:error];

    }

    downloadModel.stateBlock?downloadModel.stateBlock(state,filePath,error):nil;

}
/**
 *  下载更新状态
 *
 *  @param downloadModel <#downloadModel description#>
 *  @param progress      <#progress description#>
 */
- (void)downloadModel:(DownLoadModel *)downloadModel updateProgress:(DownloadProgress *)progress{

    if (_delegate && [_delegate respondsToSelector:@selector(downloadModel:didUpdateProgress:)]) {
        [_delegate downloadModel:downloadModel didUpdateProgress:progress];
    }

    downloadModel.progressBlock?downloadModel.progressBlock(progress,calculateFileSizeInUnit(progress.totalBytesExpectedToWrite),calculateFileSizeInUnit(progress.totalBytesWritten)):nil;
}
/**
 *  删除下载
 *
 *  @param URLString <#URLString description#>
 */
- (void)removeDownLoadingModelForURLString:(NSString *)URLString
{
    [self.downloadingModelDic removeObjectForKey:URLString];
}
// resumeData 路径
- (NSString *)resumeDataPathWithDownloadURL:(NSString *)downloadURL
{
    NSString *resumeFileName = downloadURL.md5String;
    return [self.downloadDirectory stringByAppendingPathComponent:resumeFileName];
}
#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{

    DownLoadModel *downloadModel = [self downLoadingModelForURLString:dataTask.taskDescription];
    if (!downloadModel) {
        return;
    }

    // 创建目录
    [self createDirectory:_downloadDirectory];
    [self createDirectory:downloadModel.downloadDirectory];

    // 打开流
    [downloadModel.stream open];

    // 获得服务器这次请求 返回数据的总长度
    long long totalBytesWritten =  [self fileSizeWithDownloadModel:downloadModel];
    long long totalBytesExpectedToWrite = totalBytesWritten + dataTask.countOfBytesExpectedToReceive;

    downloadModel.progress.resumeBytesWritten = totalBytesWritten;
    downloadModel.progress.totalBytesWritten = totalBytesWritten;
    downloadModel.progress.totalBytesExpectedToWrite = totalBytesExpectedToWrite;

    // 存储总长度
    @synchronized (self) {
        NSMutableDictionary *dic = [self fileSizePlistWithDownloadModel:downloadModel];
        dic[downloadModel.downloadURL] = @(totalBytesExpectedToWrite);
        [dic writeToFile:[self fileSizePathWithDownloadModel:downloadModel] atomically:YES];
    }

    // 接收这个请求，允许接收服务器的数据
    completionHandler(NSURLSessionResponseAllow);
}

/**
 * 接收到服务器返回的数据
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    DownLoadModel *downloadModel = [self downLoadingModelForURLString:dataTask.taskDescription];
    if (!downloadModel || downloadModel.state == DownloadStateSuspended) {
        return;
    }
    // 写入数据
    [downloadModel.stream write:data.bytes maxLength:data.length];

    // 下载进度
    downloadModel.progress.bytesWritten = data.length;
    downloadModel.progress.totalBytesWritten += downloadModel.progress.bytesWritten;
    downloadModel.progress.progress  = MIN(1.0, 1.0*downloadModel.progress.totalBytesWritten/downloadModel.progress.totalBytesExpectedToWrite);

    // 时间
    NSTimeInterval downloadTime = -1 * [downloadModel.downloadDate timeIntervalSinceNow];
    downloadModel.progress.speed = (downloadModel.progress.totalBytesWritten - downloadModel.progress.resumeBytesWritten) / downloadTime;

    int64_t remainingContentLength = downloadModel.progress.totalBytesExpectedToWrite - downloadModel.progress.totalBytesWritten;
    downloadModel.progress.remainingTime = ceilf(remainingContentLength / downloadModel.progress.speed);

    dispatch_async(dispatch_get_main_queue(), ^(){
        [self downloadModel:downloadModel updateProgress:downloadModel.progress];
    });
}

/**
 * 请求完毕（成功|失败）
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    DownLoadModel *downloadModel = [self downLoadingModelForURLString:task.taskDescription];

    if (!downloadModel) {
        return;
    }

    // 关闭流
    [downloadModel.stream close];
    downloadModel.stream = nil;
    downloadModel.task = nil;

    [self removeDownLoadingModelForURLString:downloadModel.downloadURL];

    if (downloadModel.manualCancle) {
        // 暂停下载
        dispatch_async(dispatch_get_main_queue(), ^(){
            downloadModel.manualCancle = NO;
            downloadModel.state = DownloadStateSuspended;
            [self downloadModel:downloadModel didChangeState:DownloadStateSuspended filePath:nil error:nil];
            [self willResumeNextWithDowloadModel:downloadModel];
        });
    }else if (error){
        // 下载失败
        dispatch_async(dispatch_get_main_queue(), ^(){
            downloadModel.state = DownloadStateFailed;
            [self downloadModel:downloadModel didChangeState:DownloadStateFailed filePath:nil error:error];
            [self willResumeNextWithDowloadModel:downloadModel];
        });
    }else if ([self isDownloadCompletedWithDownloadModel:downloadModel]) {
        // 下载完成
        dispatch_async(dispatch_get_main_queue(), ^(){
            downloadModel.state = DownloadStateCompleted;
            [self downloadModel:downloadModel didChangeState:DownloadStateCompleted filePath:downloadModel.filePath error:nil];
            [self willResumeNextWithDowloadModel:downloadModel];
        });
    }else {
        // 下载完成
        dispatch_async(dispatch_get_main_queue(), ^(){
            downloadModel.state = DownloadStateCompleted;
            [self downloadModel:downloadModel didChangeState:DownloadStateCompleted filePath:downloadModel.filePath error:nil];
            [self willResumeNextWithDowloadModel:downloadModel];
        });
    }
}
#pragma mark 懒加载
- (NSFileManager *)fileManager
{
    if (!_fileManager) {
        _fileManager = [[NSFileManager alloc]init];
    }
    return _fileManager;
}
- (NSURLSession *)session
{
    if (!_session) {
          _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:self.queue];

    }
    return _session;
}
- (NSOperationQueue *)queue
{
    if (!_queue) {
        _queue = [[NSOperationQueue alloc]init];
        _queue.maxConcurrentOperationCount = 1;
    }
    return _queue;
}

- (NSString *)downloadDirectory
{
    if (!_downloadDirectory) {
        _downloadDirectory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"DownloadCache"];
        [self createDirectory:_downloadDirectory];
    }
    return _downloadDirectory;
}
- (NSMutableArray *)downloadingModels
{
    if (!_downloadingModels) {
        _downloadingModels = [NSMutableArray arrayWithCapacity:0];
    }
    return _downloadingModels;
}
- (NSMutableDictionary *)downloadingModelDic
{
    if (!_downloadingModelDic) {
        _downloadingModelDic = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return _downloadingModelDic;
}
- (NSString *)fileSizePathWithDownloadModel:(DownLoadModel *)downloadModel
{
    return [downloadModel.downloadDirectory stringByAppendingPathComponent:@"downloadsFileSize.plist"];
}

- (NSMutableArray *)waitingDownloadModels
{
    if (!_waitingDownloadModels) {
        _waitingDownloadModels = [NSMutableArray arrayWithCapacity:0];
    }
    return _waitingDownloadModels;
}


-(NSString *)backgroundConfigure{
    
    if (!_backgroundConfigure) {
        
        return  @"SessionManager.backgroundConfigure";
    }
    return _backgroundConfigure;
}
-(NSInteger)maxDownloadCount{
    
    if (!_maxDownloadCount) {
        
        return  1;
    }
    
    return  _maxDownloadCount;
}
-(BOOL)resumeDownloadFIFO{
    
    if (!_resumeDownloadFIFO) {
        
        return  YES;
    }
    
    return  _resumeDownloadFIFO;
}
@end
