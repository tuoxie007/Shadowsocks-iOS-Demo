//
//  ViewController.m
//  ShadowsocksDemo
//
//  Created by Jason Hsu on 15/7/2.
//  Copyright (c) 2015年 Jason Hsu. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (strong, nonatomic) UIWebView *webview;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.webview = [[UIWebView alloc] init];
    [self.view addSubview:self.webview];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.webview.frame = self.view.bounds;
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(start) userInfo:nil repeats:NO];
}

- (void)start {
    [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://twitter.com"]]];
}

@end
