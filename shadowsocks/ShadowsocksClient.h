//
//  HSUShadowsocksProxy.h
//  Test
//
//  Created by Jason Hsu on 13-9-7.
//  Copyright (c) 2013年 Jason Hsu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

@interface ShadowsocksClient : NSURLProtocol <GCDAsyncSocketDelegate>

@property (nonatomic, assign) BOOL directly;

@property (nonatomic, readonly) NSString *host;
@property (nonatomic, readonly) NSInteger port;
@property (nonatomic, readonly) NSString *method;
@property (nonatomic, readonly) NSString *password;

- (id)initWithHost:(NSString *)host port:(NSInteger)port password:(NSString *)passoword method:(NSString *)method;
- (void)updateHost:(NSString *)host port:(NSInteger)port password:(NSString *)passoword method:(NSString *)method;
- (BOOL)startWithLocalPort:(NSInteger)localPort; // auto restart
- (void)stop;
- (BOOL)isConnected;

@end
