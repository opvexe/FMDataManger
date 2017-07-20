//
//  ViewController.m
//  GD_FMDB
//
//  Created by GDBank on 2017/7/20.
//  Copyright © 2017年 com.GDBank.Company. All rights reserved.
//

#import "ViewController.h"
#import "GDHomeModel.h"
#import "GDHomeCacheDB.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    GDHomeModel *model  = [[GDHomeModel alloc]init];
    model.ID   =@"100";
    model.signature = @"i cando it ";
    
    [[GDHomeCacheDB shareDB]saveModel:model];
    
    
    GDHomeModel *GDModel = [[GDHomeCacheDB shareDB]findWithID:model.ID];
    NSLog(@"%@",GDModel.signature);
}


@end
