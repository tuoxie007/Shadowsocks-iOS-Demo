//
//  SSProxy.m
//  Test
//
//  Created by Jason Hsu on 13-9-7.
//  Copyright (c) 2013年 Jason Hsu. All rights reserved.
//

#import "ShadowsocksClient.h"
#include "encrypt.h"
#include "socks5.h"
#include <arpa/inet.h>
#import <UIKit/UIKit.h>

#define ADDR_STR_LEN 512

@interface SSPipeline : NSObject
{
@public
    struct encryption_ctx sendEncryptionContext;
    struct encryption_ctx recvEncryptionContext;
}

@property (nonatomic, strong) GCDAsyncSocket *localSocket;
@property (nonatomic, strong) GCDAsyncSocket *remoteSocket;
@property (nonatomic, assign) int stage;
@property (nonatomic, strong) NSData *addrData;

- (void)disconnect;

@end

@implementation SSPipeline

- (void)disconnect
{
    [self.localSocket disconnectAfterReadingAndWriting];
    [self.remoteSocket disconnectAfterReadingAndWriting];
}

@end

@implementation ShadowsocksClient
{
    dispatch_queue_t _socketQueue;
    GCDAsyncSocket *_serverSocket;
    NSMutableArray *_pipelines;
    NSString *_host;
    NSInteger _port;
    NSString *_method;
    NSString *_passoword;
}

@synthesize host = _host;
@synthesize port = _port;
@synthesize method = _method;
@synthesize password = _passoword;

- (SSPipeline *)pipelineOfLocalSocket:(GCDAsyncSocket *)localSocket
{
    __block SSPipeline *ret;
    [_pipelines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SSPipeline *pipeline = obj;
        if (pipeline.localSocket == localSocket) {
            ret = pipeline;
        }
    }];
    return ret;
}

- (SSPipeline *)pipelineOfRemoteSocket:(GCDAsyncSocket *)remoteSocket
{
    __block SSPipeline *ret;
    [_pipelines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SSPipeline *pipeline = obj;
        if (pipeline.remoteSocket == remoteSocket) {
            ret = pipeline;
        }
    }];
    return ret;
}

- (void)dealloc
{
    _serverSocket = nil;
    _pipelines = nil;
    _host = nil;
}

- (void)updateHost:(NSString *)host port:(NSInteger)port password:(NSString *)passoword method:(NSString *)method
{
    _host = [host copy];
    _port = port;
    _passoword = [passoword copy];
    config_encryption([passoword cStringUsingEncoding:NSASCIIStringEncoding],
                      [method cStringUsingEncoding:NSASCIIStringEncoding]);
    _method = [method copy];
}

- (id)initWithHost:(NSString *)host port:(NSInteger)port password:(NSString *)passoword method:(NSString *)method
{
    self = [super init];
    if (self) {
#ifdef DEBUG
        NSLog(@"SS: %@", host);
#endif
        _host = [host copy];
        _port = port;
        _passoword = [passoword copy];
        config_encryption([passoword cStringUsingEncoding:NSASCIIStringEncoding],
                          [method cStringUsingEncoding:NSASCIIStringEncoding]);
        _method = [method copy];
    }
    return self;
}

- (BOOL)startWithLocalPort:(NSInteger)localPort
{
    if (_serverSocket) {
        [self stop];
        //        [NSThread sleepForTimeInterval:3];
        return [self _doStartWithLocalPort:localPort];
    } else {
        [self stop];
        return [self _doStartWithLocalPort:localPort];
    }
}

- (BOOL)_doStartWithLocalPort:(NSInteger)localPort
{
    _socketQueue = dispatch_queue_create("me.tuoxie.shadowsocks", NULL);
    _serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_socketQueue];
    NSError *error;
    [_serverSocket acceptOnPort:localPort error:&error];
    if (error) {
        NSLog(@"bind failed, %@", error);
        return NO;
    }
    _pipelines = [[NSMutableArray alloc] init];
    return YES;
}

- (BOOL)isConnected
{
    return _serverSocket.isConnected;
}

- (void)stop
{
    [_serverSocket disconnect];
    NSArray *ps = [NSArray arrayWithArray:_pipelines];
    [ps enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SSPipeline *pipeline = obj;
        [pipeline.localSocket disconnect];
        [pipeline.remoteSocket disconnect];
    }];
    _serverSocket = nil;
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
#ifdef DEBUG
    //    NSLog(@"didAcceptNewSocket");
#endif
    SSPipeline *pipeline = [[SSPipeline alloc] init];
    pipeline.localSocket = newSocket;
    [_pipelines addObject:pipeline];
    
    [pipeline.localSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    SSPipeline *pipeline = [self pipelineOfRemoteSocket:sock];
    //    [pipeline.localSocket readDataWithTimeout:-1 tag:0];
    
    //    NSLog(@"remote did connect to host");
    [pipeline.remoteSocket
     writeData:pipeline.addrData
     withTimeout:-1
     tag:2];
    
    // Fake reply
    struct socks5_response response;
    response.ver = SOCKS_VERSION;
    response.rep = 0;
    response.rsv = 0;
    response.atyp = SOCKS_IPV4;
    
    struct in_addr sin_addr;
    inet_aton("0.0.0.0", &sin_addr);
    
    int reply_size = 4 + sizeof(struct in_addr) + sizeof(unsigned short);
    char *replayBytes = (char *)malloc(reply_size);
    
    memcpy(replayBytes, &response, 4);
    memcpy(replayBytes + 4, &sin_addr, sizeof(struct in_addr));
    *((unsigned short *)(replayBytes + 4 + sizeof(struct in_addr)))
    = (unsigned short) htons(atoi("22"));
    
    [pipeline.localSocket
     writeData:[NSData dataWithBytes:replayBytes length:reply_size]
     withTimeout:-1
     tag:3];
    free(replayBytes);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    //    NSLog(@"socket did read data %d tag %ld", data.length, tag);
    SSPipeline *pipeline =
    [self pipelineOfLocalSocket:sock] ?: [self pipelineOfRemoteSocket:sock];
    if (!pipeline) {
        return;
    }
    int len = (int)data.length;
    if (tag == 0) {
        // write version + method
        [pipeline.localSocket
         writeData:[NSData dataWithBytes:"\x05\x00" length:2]
         withTimeout:-1
         tag:0];
    } else if (tag == 1) {
        struct socks5_request *request = (struct socks5_request *)data.bytes;
        if (request->cmd != SOCKS_CMD_CONNECT) {
            NSLog(@"unsupported cmd: %d", request->cmd);
            struct socks5_response response;
            response.ver = SOCKS_VERSION;
            response.rep = SOCKS_CMD_NOT_SUPPORTED;
            response.rsv = 0;
            response.atyp = SOCKS_IPV4;
            char *send_buf = (char *)&response;
            [pipeline.localSocket writeData:[NSData dataWithBytes:send_buf length:4] withTimeout:-1 tag:1];
            [pipeline disconnect];
            return;
        }
        
        char addr_to_send[ADDR_STR_LEN];
        int addr_len = 0;
        addr_to_send[addr_len++] = request->atyp;
        
        char addr_str[ADDR_STR_LEN];
        // get remote addr and port
        if (request->atyp == SOCKS_IPV4) {
            // IP V4
            size_t in_addr_len = sizeof(struct in_addr);
            memcpy(addr_to_send + addr_len, data.bytes + 4, in_addr_len + 2);
            addr_len += in_addr_len + 2;
            
            // now get it back and print it
            inet_ntop(AF_INET, data.bytes + 4, addr_str, ADDR_STR_LEN);
        } else if (request->atyp == SOCKS_DOMAIN) {
            // Domain name
            unsigned char name_len = *(unsigned char *)(data.bytes + 4);
            addr_to_send[addr_len++] = name_len;
            memcpy(addr_to_send + addr_len, data.bytes + 4 + 1, name_len);
            memcpy(addr_str, data.bytes + 4 + 1, name_len);
            addr_str[name_len] = '\0';
            addr_len += name_len;
            
            // get port
            unsigned char v1 = *(unsigned char *)(data.bytes + 4 + 1 + name_len);
            unsigned char v2 = *(unsigned char *)(data.bytes + 4 + 1 + name_len + 1);
            addr_to_send[addr_len++] = v1;
            addr_to_send[addr_len++] = v2;
        } else {
            NSLog(@"unsupported addrtype: %d", request->atyp);
            [pipeline disconnect];
            return;
        }
        
        GCDAsyncSocket *remoteSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_socketQueue];
        pipeline.remoteSocket = remoteSocket;
        [remoteSocket connectToHost:_host onPort:_port error:nil];
        init_encryption(&(pipeline->sendEncryptionContext));
        init_encryption(&(pipeline->recvEncryptionContext));
        encrypt_buf(&(pipeline->sendEncryptionContext), addr_to_send, &addr_len);
        pipeline.addrData = [NSData dataWithBytes:addr_to_send length:addr_len];
        
    } else if (tag == 2) { // read data from local, send to remote
        if (![_method isEqualToString:@"table"]) {
            char *buf = (char *)malloc(data.length + EVP_MAX_IV_LENGTH + EVP_MAX_BLOCK_LENGTH);
            memcpy(buf, data.bytes, data.length);
            encrypt_buf(&(pipeline->sendEncryptionContext), buf, &len);
            NSData *encodedData = [NSData dataWithBytesNoCopy:buf length:len];
            [pipeline.remoteSocket writeData:encodedData withTimeout:-1 tag:4];
        } else {
            encrypt_buf(&(pipeline->sendEncryptionContext), (char *)data.bytes, &len);
            [pipeline.remoteSocket writeData:data withTimeout:-1 tag:4];
        }
    } else if (tag == 3) { // read data from remote, send to local
        if (![_method isEqualToString:@"table"]) {
            char *buf = (char *)malloc(data.length + EVP_MAX_IV_LENGTH + EVP_MAX_BLOCK_LENGTH);
            memcpy(buf, data.bytes, data.length);
            decrypt_buf(&(pipeline->recvEncryptionContext), buf, &len);
            NSData *encodedData = [NSData dataWithBytesNoCopy:buf length:len];
            [pipeline.localSocket writeData:encodedData withTimeout:-1 tag:3];
        } else {
            decrypt_buf(&(pipeline->recvEncryptionContext), (char *)data.bytes, &len);
            [pipeline.localSocket writeData:data withTimeout:-1 tag:3];
        }
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    //    NSLog(@"socket did write tag %ld", tag);
    SSPipeline *pipeline =
    [self pipelineOfLocalSocket:sock] ?: [self pipelineOfRemoteSocket:sock];
    
    if (tag == 0) {
        [pipeline.localSocket readDataWithTimeout:-1 tag:1];
    } else if (tag == 1) {
        
    } else if (tag == 2) {
        
    } else if (tag == 3) { // write data to local
        [pipeline.remoteSocket readDataWithTimeout:-1 buffer:nil bufferOffset:0 maxLength:4096 tag:3];
        [pipeline.localSocket readDataWithTimeout:-1 buffer:nil bufferOffset:0 maxLength:4096 tag:2];
    } else if (tag == 4) { // write data to remote
        [pipeline.remoteSocket readDataWithTimeout:-1 buffer:nil bufferOffset:0 maxLength:4096 tag:3];
        [pipeline.localSocket readDataWithTimeout:-1 buffer:nil bufferOffset:0 maxLength:4096 tag:2];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    SSPipeline *pipeline;
    
    pipeline = [self pipelineOfRemoteSocket:sock];
    if (pipeline) { // disconnect remote
        if (pipeline.localSocket.isDisconnected) {
            [_pipelines removeObject:pipeline];
            // encrypt code
            cleanup_encryption(&(pipeline->sendEncryptionContext));
            cleanup_encryption(&(pipeline->recvEncryptionContext));
        } else {
            [pipeline.localSocket disconnectAfterReadingAndWriting];
        }
        return;
    }
    
    pipeline = [self pipelineOfLocalSocket:sock];
    if (pipeline) { // disconnect local
        if (pipeline.remoteSocket.isDisconnected) {
            [_pipelines removeObject:pipeline];
            // encrypt code
            cleanup_encryption(&(pipeline->sendEncryptionContext));
            cleanup_encryption(&(pipeline->recvEncryptionContext));
        } else {
            [pipeline.remoteSocket disconnectAfterReadingAndWriting];
        }
        return;
    }
}

@end
