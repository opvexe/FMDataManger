//
//  FMDataMange.h
//  GD_FMDB
//
//  Created by GDBank on 2017/7/20.
//  Copyright © 2017年 com.GDBank.Company. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSString+WY_Extension.h"
#import "WithYouTools.h"
#import <FMDB.h>

typedef void(^DBMangeBlock)(FMDatabase *_db);

@interface FMDataMange : NSObject

/**
 *  初始化
 *
 */
+(instancetype)shareFMDataMange;

/**
 *  创建数据库
 *
 *  @param isAsynch 是否异步
 */
-(void)creatDBMange:(BOOL )isAsynch dbBlock:(DBMangeBlock )block;

/**
 *  查询磁盘内存大小
 *
 */
-(unsigned long long)getFileSize;

/**
 *  清理缓存
 *
 */
-(void)clearDB;


@end
