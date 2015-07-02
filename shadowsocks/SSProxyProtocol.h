//
//  SSProxyProtocol.h
//  Tweet4China
//
//  Created by Jason Hsu on 8/26/14.
//  Copyright (c) 2014 Jason Hsu <support@tuoxie.me>. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSInteger ssLocalPort;

@interface SSProxyProtocol : NSURLProtocol

+ (void)setLocalPort:(NSInteger)localPort;

@end
