//
//  GDHomeCacheDB.h
//  GD_FMDB
//
//  Created by GDBank on 2017/7/20.
//  Copyright © 2017年 com.GDBank.Company. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDataMange.h"
#import "GDHomeModel.h"

@interface GDHomeCacheDB : NSObject

+(instancetype)shareDB;
/**
 *  存储数据
 *
 *  @param model 对象
 */
-(BOOL)saveModel:(GDHomeModel *)model;
/**
 *  删除数据
 *
 *   uid
 */
-(BOOL)delModelWithUid:(NSString * )ID;

/**
 *  查找数据
 *
 */
-(GDHomeModel *)findWithID:(NSString * )ID;


-(NSMutableArray*)findAllModel;
/**
 *  删除表
 *
 */
-(BOOL )clearTable;

@end
