//
//  CPDownLoadSessionManger.m
//  ChargingPile
//
//  Created by SM on 16/9/5.
//  Copyright © 2016年 SM. All rights reserved.
//

#import "CPDownLoadSessionManger.h"
#import "NSString+CPHash.h"

#define IOS8ORLATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
@interface  DownLoadModel()

@property (nonatomic, assign) DownloadState state;

@property (nonatomic, strong) NSURLSessionDownloadTask *task;

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


@implementation CPDownLoadSessionManger

static  CPDownLoadSessionManger *_manger = nil;
+(instancetype)sharedManager{

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manger = [[self alloc] init];
    });

    return _manger;
}
#pragma 方法
- (void)configureBackroundSession
{
    if (!_backgroundConfigure) {
        return;
    }
    [self session];
}

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


    if (downloadModel.task &&downloadModel.task.state ==NSURLSessionTaskStateRunning) {

        downloadModel.state = DownloadStateRunning;

        [self downloadModel:downloadModel didChangeState:DownloadStateRunning filePath:nil error:nil];

        return ;
    }

    [self configirebackgroundSessionTasksWithDownloadModel:downloadModel];

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


        NSData *resumeData = [self resumeDataFromFileWithDownloadModel:downloadModel];

        if ([self isValideResumeData:resumeData ]) {

            downloadModel.task = [self.session downloadTaskWithResumeData:resumeData];

        }else{

            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:downloadModel.downloadURL]];
            downloadModel.task = [self.session downloadTaskWithRequest:request];
        }

        downloadModel.task.taskDescription = downloadModel.downloadURL;
        downloadModel.downloadDate = [NSDate date];

    }

    if (!downloadModel.downloadDate) {
        downloadModel.downloadDate = [NSDate date];
    }

    if (![self.downloadingModelDic valueForKey:downloadModel.downloadURL]) {

        self.downloadingModelDic[downloadModel.downloadURL] = downloadModel;
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
        [self cancleWithDownloadModel:downloadModel clearResumeData:NO];
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
    if (downloadModel.state != DownloadStateCompleted && downloadModel.state != DownloadStateFailed){
        [self cancleWithDownloadModel:downloadModel clearResumeData:NO];
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

    [self cancleWithDownloadModel:downloadModel clearResumeData:YES];

    [self deleteFileIfExist:downloadModel.filePath];

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

    for (DownLoadModel *downloadModel in [self.downloadingModelDic allValues]) {

        if ([downloadModel.downloadDirectory isEqualToString:downloadDirectory]) {

            [self cancleWithDownloadModel:downloadModel clearResumeData:YES];
        }
    }
    // 删除沙盒中所有资源
    [self.fileManager removeItemAtPath:downloadDirectory error:nil];
}
/**
 *  获取恢复数据
 *
 *  @param downloadModel <#downloadModel description#>
 *
 *  @return <#return value description#>
 */
-(NSData *)resumeDataFromFileWithDownloadModel:(DownLoadModel*)downloadModel{

    if (downloadModel.resumeData) {

        return downloadModel.resumeData;
    }

    NSString *resumeFilePath = [self resumeDataPathWithDownloadURL:downloadModel.downloadURL];

    if ([_fileManager isExecutableFileAtPath:resumeFilePath]) {

        NSData *resumeData = [NSData dataWithContentsOfFile:resumeFilePath];

        return resumeData;
    }

    return nil;
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
#pragma mark - configire background task
// 配置后台后台下载session
- (void)configirebackgroundSessionTasksWithDownloadModel:(DownLoadModel *)downloadModel
{
    if (!_backgroundConfigure) {
        return ;
    }

    NSURLSessionDownloadTask *task = [self backgroundSessionTasksWithDownloadModel:downloadModel];
    if (!task) {
        return;
    }

    downloadModel.task = task;
    if (task.state == NSURLSessionTaskStateRunning) {
        [task suspend];
    }
}
- (NSURLSessionDownloadTask *)backgroundSessionTasksWithDownloadModel:(DownLoadModel *)downloadModel{

    NSArray *task = [self sessionDownloadTasks];

    for (NSURLSessionDownloadTask *downloadTask in task) {

        if (downloadTask.state ==NSURLSessionTaskStateRunning ||downloadTask.state == NSURLSessionTaskStateSuspended) {

            if ([downloadModel.downloadURL isEqualToString:downloadTask.taskDescription]) {
                return downloadTask;
            }
        }


    }

    return  nil;
}

/**
 *  获取所有后台下载任务
 *
 *  @return
 */
- (NSArray *)sessionDownloadTasks{

    __block NSArray *tasks = nil;

    dispatch_semaphore_t  semaphore = dispatch_semaphore_create(0);

    [self.session getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> * _Nonnull dataTasks, NSArray<NSURLSessionUploadTask *> * _Nonnull uploadTasks, NSArray<NSURLSessionDownloadTask *> * _Nonnull downloadTasks) {

        tasks = downloadTasks;

        dispatch_semaphore_signal(semaphore);
    }];

     dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    return tasks;

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
    return [self.fileManager fileExistsAtPath:downloadModel.filePath];
}
// 取消所有后台
- (void)cancleAllBackgroundSessionTasks
{
    if (!_backgroundConfigure) {
        return;
    }

    for (NSURLSessionDownloadTask *task in [self sessionDownloadTasks]) {
        [task cancelByProducingResumeData:^(NSData * resumeData) {
        }];
    }
}
#pragma mark 创建缓存目录文件

//创建缓存目录文件
- (void)createDirectory:(NSString *)directory
{
    if (![self.fileManager fileExistsAtPath:directory]) {
        [self.fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
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

-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes{

    DownLoadModel   *model  =[self downLoadingModelForURLString:downloadTask.taskDescription];

    if (!model || model.state == DownloadStateSuspended ) {

        return ;
    }
    model.progress.resumeBytesWritten = fileOffset;
}
/**
 *  下载进度
 *
 *  @param session                   <#session description#>
 *  @param downloadTask              <#downloadTask description#>
 *  @param bytesWritten              <#bytesWritten description#>
 *  @param totalBytesWritten         <#totalBytesWritten description#>
 *  @param totalBytesExpectedToWrite <#totalBytesExpectedToWrite description#>
 */
-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite{

    DownLoadModel *model = [self downLoadingModelForURLString:downloadTask.taskDescription];

    if (!model || model.state  == DownloadStateSuspended) {

        return ;

    }

    float progress = (double)totalBytesWritten/totalBytesExpectedToWrite;

    int64_t   resumeBytesWritten =model.progress.resumeBytesWritten ;

    NSTimeInterval downloadTime = -1 * [model.downloadDate timeIntervalSinceNow];

    float speed = (totalBytesWritten - resumeBytesWritten) / downloadTime;

    int64_t remainingContentLength = totalBytesExpectedToWrite - totalBytesWritten;

    int remainingTime = ceilf(remainingContentLength / speed);

    model.progress.bytesWritten = bytesWritten;
    model.progress.totalBytesWritten = totalBytesWritten;
    model.progress.totalBytesExpectedToWrite = totalBytesExpectedToWrite;
    model.progress.progress = progress;
    model.progress.speed = speed;
    model.progress.remainingTime = remainingTime;
    //异步线程
    dispatch_async(dispatch_get_main_queue(), ^{

        [self downloadModel:model updateProgress:model.progress];

    });

}
/**
 *  下载成功
 *
 *  @param session      <#session description#>
 *  @param downloadTask <#downloadTask description#>
 *  @param location     <#location description#>
 */
-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location{

     DownLoadModel *model = [self downLoadingModelForURLString:downloadTask.taskDescription];

    if (!model &&_backgroundSessionDownloadCompleteBlock) {

        NSString *filePath = _backgroundSessionDownloadCompleteBlock(downloadTask.taskDescription);
        // 移动文件到下载目录
        [self createDirectory:filePath.stringByDeletingLastPathComponent];
        [self moveFileAtURL:location toPath:filePath];

        return ;
    }
    if (location) {
        // 移动文件到下载目录
        [self createDirectory:model.downloadDirectory];
        [self moveFileAtURL:location toPath:model.filePath];

    }
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{

    DownLoadModel *model = [self downLoadingModelForURLString:task.taskDescription];

    if (!model) {

        NSData *resumeData =error ? [error.userInfo valueForKey:NSURLSessionDownloadTaskResumeData]:nil;

        if (resumeData) {

            [self createDirectory:self.downloadDirectory];

            [resumeData writeToFile:[self resumeDataPathWithDownloadURL:task.taskDescription] atomically:YES];
        }else{

              [self deleteFileIfExist:[self resumeDataPathWithDownloadURL:task.taskDescription]];
        }

        return ;
    }

    NSData *resumeData = nil;

    if (error) {

        resumeData = [error.userInfo valueForKey:NSURLSessionDownloadTaskResumeData];
    }
    if (resumeData) {

        model.resumeData = resumeData;

        [self createDirectory:self.downloadDirectory];

        [model.resumeData writeToFile:[self resumeDataPathWithDownloadURL:model.downloadURL] atomically:YES];
    }else{

        model.resumeData = nil;

        [self deleteFileIfExist:[self resumeDataPathWithDownloadURL:model.downloadURL]];

    }
    model.progress.resumeBytesWritten = 0;

    model.task = nil;

    if (model.manualCancle) {

        dispatch_async(dispatch_get_main_queue(), ^{

            model.manualCancle = NO;

            model.state = DownloadStateSuspended ;

            [self downloadModel:model didChangeState:DownloadStateSuspended filePath:nil error:nil];

            [self willResumeNextWithDowloadModel:model];

        });
    }else if (error){

        dispatch_async(dispatch_get_main_queue(), ^(){
            model.state = DownloadStateFailed;
            [self downloadModel:model didChangeState:DownloadStateFailed filePath:nil error:error];
            [self willResumeNextWithDowloadModel:model];
        });


    }else{

        dispatch_async(dispatch_get_main_queue(), ^(){
            model.state = DownloadStateCompleted;
            [self downloadModel:model didChangeState:DownloadStateCompleted filePath:nil error:error];
            [self willResumeNextWithDowloadModel:model];
        });

    }

}
// 后台session下载完成
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    if (self.backgroundSessionCompletionHandler) {
        self.backgroundSessionCompletionHandler();
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
        if (_backgroundConfigure) {
            if (IOS8ORLATER) {
                _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:self.backgroundConfigure]delegate:self delegateQueue:self.queue];
            }else{
                _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration backgroundSessionConfiguration:self.backgroundConfigure]delegate:self delegateQueue:self.queue];
            }
        }else {
            _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:self.queue];
        }
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
