//
//  FMDataMange.m
//  GD_FMDB
//
//  Created by GDBank on 2017/7/20.
//  Copyright © 2017年 com.GDBank.Company. All rights reserved.
//


#define FileName @"DB"
#define DBNAME    @"GDBank.db"

#import "FMDataMange.h"


@implementation FMDataMange
{
    NSString *database_path;
    FMDatabase *_db;
    FMDatabaseQueue *_dbQueue;
}
+(instancetype)shareFMDataMange
{
    static FMDataMange *_mange=nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _mange = [[FMDataMange alloc] init];
    });
    return _mange;
}

-(instancetype)init{
    self= [super init];
    
    if (self) {
        
        NSString *path = getDocumentsFilePath(FileName);
        
        checkPathAndCreate(path);
        
        database_path = [NSString stringWithFormat:@"%@/%@",path,DBNAME];
        
        _db = [FMDatabase databaseWithPath:database_path];
        
        _dbQueue = [FMDatabaseQueue databaseQueueWithPath:database_path];
        
        NSLog(@"database_path:数据库地址:%@",database_path);
    }
    return self;
}


-(void)creatDBMange:(BOOL)isAsynch dbBlock:(DBMangeBlock )block
{
    
    if (isAsynch) {
        
        dispatch_queue_t q= dispatch_queue_create("CP.db", DISPATCH_QUEUE_CONCURRENT);
        
        //异步请求数据库
        
        dispatch_async(q, ^{
            
            [_dbQueue inDatabase:^(FMDatabase *db) {
                
                block(db);
            }];
        });
        
    }else {
        
        if ([_db open]) {
            
            block (_db);
            
            [_db close];
        }
        
    }
    
}


-(BOOL)savaModel:(NSString *)sql isSynch:(BOOL)isSynchronous{
    
    if (isSynchronous) {
        
        dispatch_queue_t q = dispatch_queue_create("CP.db", DISPATCH_QUEUE_CONCURRENT  );
        //异步请求数据库
        
        dispatch_async(q, ^{
            [_dbQueue inDatabase:^(FMDatabase *db) {
                
                [db executeUpdate:sql];
            }];
        });
    }
    return YES;
}

-(unsigned long long)getFileSize{
    
    return   [WithYouTools fileSizeForPath:database_path];
}
-(void)clearDB{
    NSFileManager * fileManager = [[NSFileManager alloc]init];
    [fileManager removeItemAtPath:database_path error:nil];
}


@end
