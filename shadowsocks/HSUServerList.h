//
//  HSUServerList.h
//  Tweet4China
//
//  Created by Jason Hsu on 14-2-18.
//  Copyright (c) 2014年 Jason Hsu <support@tuoxie.me>. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

@interface HSUServerList : NSObject

@property (nonatomic, strong) NSURLSessionTask *task;

- (void)updateServerList;

@end
