//
//  NSString+CPHash.h
//  ChargingPile
//
//  Created by SM on 16/9/5.
//  Copyright © 2016年 SM. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (CPHash)

@property (readonly) NSString *md5String;

@property (readonly) NSString *sha1String;

@property (readonly) NSString *sha256String;

@property (readonly) NSString *sha512String;

- (NSString *)hmacSHA1StringWithKey:(NSString *)key;

- (NSString *)hmacSHA256StringWithKey:(NSString *)key;

- (NSString *)hmacSHA512StringWithKey:(NSString *)key;
@end
