//
//  NSString+WY_Extension.h
//  WithYou
//
//  Created by GDBank on 2017/4/18.
//  Copyright © 2017年 捷酷科技有限公司. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface NSString (WY_Extension)
/**
 转化字符串
 */
NSString *convertToString(id object);
/**
 
 */
BOOL is_null(id object);


BOOL isEmpty(NSString* str);


/**
 *  计算日期与当前时间的差
 *
 *  @param theDate 要对比的日期
 *
 *  @return 刚刚、几分钟前、几小时前、几天前、日期
 */
NSString *intervalSinceNow(NSString *theDate);
/**
 *
 *
 *  @param font
 *  @param maxW
 *
 *  @return
 */
- (CGSize)sizeWithFont:(UIFont *)font maxW:(CGFloat)maxW;
/**
 *
 *
 *  @param font
 *
 *  @return
 */
- (CGSize)sizeWithFont:(UIFont *)font;
/**
 *
 *
 *  @param font
 *
 *  @return
 */
+(NSString *)GetCurrentTimeString;

/**
 根据文字多少计算高度
 */
+ (float)stringHeightWithString:(NSString *)string fontSize:(UIFont *)fontSize maxWidth:(CGFloat)maxWidth;


BOOL checkFileIsExsis(NSString *filePath);

NSString* getDocumentsFilePath(const NSString* fileName);

BOOL checkPathAndCreate(NSString *filePath);

NSString* md5(NSString* input);

+ (NSString *)timeFromTimestamp:(NSInteger)timestamp;

+ (NSString *)dynamicTimeFromTimestamp:(NSInteger)timestamp;
//计算大小
NSString * calculateFileSizeInUnit(unsigned long long contentLength);

+(NSString *)encodeToPercentEscapeString: (NSString *) input;

+(NSString *)decodeFromPercentEscapeString: (NSString *) input;
@end
