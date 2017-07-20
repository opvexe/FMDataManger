//
//  GDHomeCacheDB.m
//  GD_FMDB
//
//  Created by GDBank on 2017/7/20.
//  Copyright © 2017年 com.GDBank.Company. All rights reserved.
//

#import "GDHomeCacheDB.h"


#define TableName  @"GDHomeTable"
@interface GDHomeCacheDB ()
{
     FMDataMange *_dataManger;
}
@end

static GDHomeCacheDB *_db =nil;
@implementation GDHomeCacheDB

+(instancetype)shareDB{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        if (_db ==nil) {
            
            _db = [[GDHomeCacheDB alloc] init];
        }
        
    });
    return _db;
}

-(instancetype)init
{
    self = [super init];
    
    if (self) {
        
        _dataManger = [FMDataMange shareFMDataMange];
        
        [self creatTable];
    }
    return self;
}

/**
 *  创建表
 */
-(void)creatTable{
    [_dataManger creatDBMange:NO dbBlock:^(FMDatabase *_db) {
        
        if ([_db open] ) {
            
            NSString * sqlCreateTable = [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ \
                                         (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, \
                                         uid VARCHAR,\
                                         signature VARCHAR)",TableName];
            
            BOOL res = [_db executeUpdate:sqlCreateTable];
            if (!res) {
                NSLog(@"error when creating db table");
            } else {
                NSLog(@"success to creating db table");
            }
            
            
            [_db close];
        }
        
    }];
}

/**
 *  存储数据
 *
 *  @param model 对象
 *
 *  @return
 */
-(BOOL)saveModel:(GDHomeModel *)model {
    
    if ([self findWithID:model.ID]) {
        
        return  [self updateWithModel:model];
    }
    __block BOOL isOk = NO;
    
    [_dataManger creatDBMange:NO dbBlock:^(FMDatabase *_db) {
        
        NSMutableString * query = [NSMutableString stringWithFormat:@"INSERT INTO %@ ",TableName];
        NSMutableString * keys = [NSMutableString stringWithFormat:@" ("];
        NSMutableString * values = [NSMutableString stringWithFormat:@" ( "];
        NSMutableArray * arguments = [NSMutableArray arrayWithCapacity:30];
        [keys appendString:@"uid,"];
        [values appendString:@"?,"];
        [arguments addObject:convertToString(model.ID)];
        
        [keys appendString:@"signature,"];
        [values appendString:@"?,"];
        [arguments addObject:convertToString(model.signature)];

        
        [keys appendString:@")"];
        [values appendString:@")"];
        [query appendFormat:@" %@ VALUES%@",
         [keys stringByReplacingOccurrencesOfString:@",)" withString:@")"],
         [values stringByReplacingOccurrencesOfString:@",)" withString:@")"]];
        
        isOk = [_db executeUpdate:query withArgumentsInArray:arguments];
        
    }];
    return isOk;
    
}
/**
 *  删除数据
 *  uid
 */
-(BOOL)delModelWithUid:(NSString * )ID{
    if ( ID ==nil) {
        return NO;
    }
    __block BOOL isOk = NO;
    
    [_dataManger creatDBMange:NO dbBlock:^(FMDatabase *_db) {
        
        NSMutableString * query = [NSMutableString stringWithFormat:@"DELETE FROM %@ ",TableName];
        [query appendFormat:@" where uid = '%@'",ID];
        isOk=[_db executeUpdate:query];
        
    }];
    return isOk;
}
/**
 *  更新
 *  uid
 */
-(BOOL)updateWithModel:(GDHomeModel *)model{
    
    if (model==nil ||model.ID ==nil ) {
        return NO;
    }
    
    __block BOOL isOk = NO;
    
    [_dataManger creatDBMange:NO dbBlock:^(FMDatabase *_db) {
        
        NSMutableString * query = [NSMutableString stringWithFormat:@"UPDATE %@ SET ",TableName];
        NSMutableArray * arguments = [NSMutableArray arrayWithCapacity:5];
        
        if(model.ID!=nil){
            [query appendString:@"uid=?,"];
            [arguments addObject:model.ID];
        }
        
        if(model.signature!=nil){
            [query appendString:@"signature=?,"];
            [arguments addObject:model.signature];
        }
        
        
        [query appendString:@")"];
        
        if([query hasSuffix:@",)"]){
            [query replaceCharactersInRange:NSMakeRange(query.length-2, 2) withString:@" "];
            [query stringByReplacingOccurrencesOfString:@",)" withString:@""];
        }
        [query appendFormat:@" where uid = '%@'",model.ID];
        isOk = [_db executeUpdate:query withArgumentsInArray:arguments];
        
    }];
    return isOk;
}

/**
 *  查找数据
 *
 *  @param
 *
 *  @return
 */
-(GDHomeModel *)findWithID:(NSString * )ID{
    NSString *query = [NSString stringWithFormat:@"SELECT * FROM  %@",TableName];
    
    query = [query stringByAppendingFormat:@" where uid = '%@'",ID];
    __block GDHomeModel *model = nil;
    
    [_dataManger creatDBMange:NO dbBlock:^(FMDatabase *_db) {
        
        FMResultSet *rs = [_db executeQuery:query];
        
        if ([rs next]) {
            
            model = [self parseResultSet:rs];
            
            [rs close];
        }
        
    }];
    return model;
}

/**
 *  查找所有数据
 *
 *  @return
 */
-(NSMutableArray*)findAllModel{
    __block NSMutableArray *array = [NSMutableArray array];
    [_dataManger creatDBMange:NO dbBlock:^(FMDatabase *_db) {
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM  %@ ",TableName];
        
        FMResultSet *rs = [_db executeQuery:query];
        
        while ([rs next]) {
            
            GDHomeModel * model  = [self parseResultSet:rs];
            
            [array addObject:model];
            
        }
        [rs close];
        
    }];
    
    
    return [[[array reverseObjectEnumerator] allObjects] mutableCopy];
}

/**
 *  删除表
 *
 *  @return
 */
-(BOOL )clearTable{
    __block BOOL isOk = NO;
    [_dataManger creatDBMange:NO dbBlock:^(FMDatabase *_db) {
        NSString * sql = [NSString stringWithFormat:@"delete from %@ ;\
                          update sqlite_sequence SET seq = 0 where name = '%@'",TableName,TableName];
        
        isOk = [_db executeUpdate:sql];
    }];
    
    return isOk;
}


-(GDHomeModel *) parseResultSet:(FMResultSet *)rs{
    GDHomeModel *model=[[GDHomeModel alloc]init];
    @try {
        model.ID = convertToString([rs stringForColumn:@"uid"]);
        model.signature = convertToString([rs stringForColumn:@"signature"]);
       
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
    return model;
}



@end
