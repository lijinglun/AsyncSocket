//
//  ViewController.m
//  AsyncSocketServerDemo
//
//  Created by lijinglun on 2019/7/17.
//  Copyright © 2019 lijinglun. All rights reserved.
//

#import "ViewController.h"
// When using iOS 8+ frameworks
@import CocoaAsyncSocket;

// OR when not using frameworks, targeting iOS 7 or below
#import "GCDAsyncSocket.h" // for TCP
#import "GCDAsyncUdpSocket.h" // for UDP

@interface ViewController ()<GCDAsyncSocketDelegate>
@property (nonatomic,strong)GCDAsyncSocket *serverSocket;
// 保存客户端socket
@property (nonatomic, copy) NSMutableArray *clientSockets;
// 客户端标识和心跳接收时间的字典
@property (nonatomic, copy) NSMutableDictionary *clientPhoneTimeDicts;
// 检测心跳计时器
@property (nonatomic, strong) NSTimer *checkTimer;
@property (nonatomic,strong)UITextField *msgTextField;
@property (nonatomic,strong)UIButton *postButton;
@property (nonatomic,strong) UITextView *showMessageTextV;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _clientSockets = [NSMutableArray array];
    _clientPhoneTimeDicts = [NSMutableDictionary dictionary];
    [self.view addSubview:[self msgTextField]];
    [self.view addSubview:[self postButton]];
    [self.view addSubview:[self showMessageTextV]];
    [self initSocket];
    // Do any additional setup after loading the view.
}
- (void)initSocket{
    // 初始化服务端socket
    _serverSocket = [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    //开放服务端的指定端口
    NSError *error = nil;
    BOOL result = [self.serverSocket acceptOnPort:6969 error:&error];
    if (result && error == nil) {
        // 开放成功
        [self showMessageWithStr:@"开放成功"];
    }
    else
    {
        [self showMessageWithStr:@"已经开放"];
    }
}
// 连接上新的客户端socket
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(nonnull GCDAsyncSocket *)newSocket
{
    // 保存客户端的socket
    [self.clientSockets addObject: newSocket];
    // 添加定时器
    [self addTimer];
    [self showMessageWithStr:@"链接成功"];
    [self showMessageWithStr:[NSString stringWithFormat:@"客户端的地址: %@ -------端口: %d", newSocket.connectedHost, newSocket.connectedPort]];
    [newSocket readDataWithTimeout:- 1 tag:0];
}
/**
 读取客户端的数据
 @param sock 客户端的Socket
 @param data 客户端发送的数据
 @param tag 当前读取的标记
 */
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSString *text = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    [self showMessageWithStr:text];
    
    // 第一次读取到的数据直接添加
    if (self.clientPhoneTimeDicts.count == 0)
    {
        [self.clientPhoneTimeDicts setObject:[self getCurrentTime] forKey:text];
    }
    else
    {
        [self.clientPhoneTimeDicts enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [self.clientPhoneTimeDicts setObject:[self getCurrentTime] forKey:text];
        }];
    }
    
    [sock readDataWithTimeout:- 1 tag:0];
}
// 添加计时器
- (void)addTimer
{
    // 长连接定时器
    self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(checkLongConnect) userInfo:nil repeats:YES];
    // 把定时器添加到当前运行循环,并且调为通用模式
    [[NSRunLoop currentRunLoop] addTimer:self.checkTimer forMode:NSRunLoopCommonModes];
}

// 检测心跳
- (void)checkLongConnect
{
    [self.clientPhoneTimeDicts enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        // 获取当前时间
        NSString *currentTimeStr = [self getCurrentTime];
        // 延迟超过10秒判断断开
        if (([currentTimeStr doubleValue] - [obj doubleValue]) > 10.0)
        {
            [self showMessageWithStr:[NSString stringWithFormat:@"%@已经断开,连接时差%f",key,[currentTimeStr doubleValue] - [obj doubleValue]]];
            [self showMessageWithStr:[NSString stringWithFormat:@"移除%@",key]];
            [self.clientPhoneTimeDicts removeObjectForKey:key];
        }
        else
        {
             [self showMessageWithStr:[NSString stringWithFormat:@"%@处于连接状态,连接时差%f",key,[currentTimeStr doubleValue] - [obj doubleValue]]];
        }
    }];
}
- (NSString *)getCurrentTime
{
    NSDate* date = [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval currentTime = [date timeIntervalSince1970];
    NSString *currentTimeStr = [NSString stringWithFormat:@"%.0f", currentTime];
    return currentTimeStr;
}

- (UITextField *)msgTextField{
    if (!_msgTextField) {
        _msgTextField = [[UITextField alloc]initWithFrame:CGRectMake(20, 170, 250, 50)];
        _msgTextField.layer.borderColor = [UIColor lightGrayColor].CGColor;
        _msgTextField.layer.borderWidth = 1;
        _msgTextField.layer.cornerRadius = 5;
    }
    return _msgTextField;
}
- (UIButton *)postButton{
    if (!_postButton) {
        _postButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _postButton.frame = CGRectMake(280, 170, 75, 50);
        [_postButton setTitle:@"发送" forState:UIControlStateNormal];
        [_postButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        _postButton.titleLabel.font = [UIFont systemFontOfSize:17];
        [_postButton addTarget:self action:@selector(postButtonCLick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _postButton;
}
//发送数据给服务端
- (void)postButtonCLick:(UIButton *)btn{
    if(self.clientSockets == nil) return;
    NSData *data = [self.msgTextField.text dataUsingEncoding:NSUTF8StringEncoding];
    // withTimeout -1 : 无穷大,一直等
    // tag : 消息标记
    [self.clientSockets enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj writeData:data withTimeout:-1 tag:0];
    }];
}
- (UITextView *)showMessageTextV{
    if (!_showMessageTextV) {
        _showMessageTextV = [[UITextView alloc]initWithFrame:CGRectMake(20, 230, 300, 400)];
    }
    return _showMessageTextV;
}
// 信息展示
- (void)showMessageWithStr:(NSString *)str
{
    self.showMessageTextV.text = [self.showMessageTextV.text stringByAppendingFormat:@"%@\n", str];
}
@end
