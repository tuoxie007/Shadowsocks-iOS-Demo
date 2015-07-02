//
//  HSUServerList.m
//  Tweet4China
//
//  Created by Jason Hsu on 14-2-18.
//  Copyright (c) 2014年 Jason Hsu <support@tuoxie.me>. All rights reserved.
//

#import "HSUServerList.h"

@implementation HSUServerList

- (void)updateServerList
{
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://tuoxie007.github.io/tw.ss.json"]];
    NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (json) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ShadowsocksServerListUpdatedNotification" object:json];
        }
    }];
    [task resume];
    self.task = task;
}

@end
