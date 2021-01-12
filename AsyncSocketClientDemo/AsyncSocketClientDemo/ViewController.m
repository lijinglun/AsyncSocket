//
//  ViewController.m
//  AsyncSocketClientDemo
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
@property (nonatomic,strong)GCDAsyncSocket *clientSocket;
@property (nonatomic,assign)BOOL connected;
@property (nonatomic,strong)UITextField *msgTextField;
@property (nonatomic,strong)UIButton *postButton;
@property (nonatomic,strong)UIButton *connetButton;
@property (nonatomic, strong) NSTimer *connectTimer;// 计时器
@property (nonatomic,strong) UITextView *showMessageTextV;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:[self connetButton]];
    [self.view addSubview:[self msgTextField]];
    [self.view addSubview:[self postButton]];
    [self.view addSubview:[self showMessageTextV]];
    // Do any additional setup after loading the view.
}

- (void)initSocket{
    //创建socket并指定代理对象为self,代理队列必须为主队列.
    _clientSocket = [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    //连接指定主机的对应端口.
    NSError *error = nil;
    _connected = [self.clientSocket connectToHost:@"127.0.0.1" onPort:6969 viaInterface:nil withTimeout:-1 error:&error];
    if(self.connected)
    {
        [self showMessageWithStr:@"客户端尝试连接"];
    }
    else
    {
        self.connected = NO;
        [self showMessageWithStr:@"客户端未创建连接"];
    }
}
//成功连接主机对应端口号
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    [self showMessageWithStr:@"链接成功"];
    [self showMessageWithStr:[NSString stringWithFormat:@"服务器IP: %@-------端口: %d", host,port]];
    // 连接后,可读取服务端的数据
    [self addTimer];
    [self.clientSocket readDataWithTimeout:-1 tag:0];
    _connected = YES;
}
/**
 读取数据
 @param sock 客户端socket
 @param data 读取到的数据
 @param tag 当前读取的标记
 */
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    
    NSString *text = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    [self showMessageWithStr:text];
    
    // 读取到服务器数据值后,能再次读取
    [self.clientSocket readDataWithTimeout:- 1 tag:0];
}

/**
 客户端socket断开
 
 @param sock 客户端socket
 @param err 错误描述
 */
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err{
    [self showMessageWithStr:@"断开连接"];
    _clientSocket.delegate = nil;
    self.clientSocket = nil;
    _connected = NO;
}

// 添加定时器
- (void)addTimer
{
    // 长连接定时器
    self.connectTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(longConnectToSocket) userInfo:nil repeats:YES];
    // 把定时器添加到当前运行循环,并且调为通用模式
    [[NSRunLoop currentRunLoop] addTimer:self.connectTimer forMode:NSRunLoopCommonModes];
}

// 心跳连接
- (void)longConnectToSocket
{
    // 发送固定格式的数据,指令@"longConnect"
    float version = [[UIDevice currentDevice] systemVersion].floatValue;
    NSString *longConnect = [NSString stringWithFormat:@"123%f",version];
    
    NSData  *data = [longConnect dataUsingEncoding:NSUTF8StringEncoding];
    
    [self.clientSocket writeData:data withTimeout:- 1 tag:0];
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
    NSData *data = [self.msgTextField.text dataUsingEncoding:NSUTF8StringEncoding];
    // withTimeout -1 : 无穷大,一直等
    // tag : 消息标记
    [self.clientSocket writeData:data withTimeout:- 1 tag:0];
}
- (UIButton *)connetButton{
    if (!_connetButton) {
        _connetButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _connetButton.frame = CGRectMake(20, 100, 75, 50);
        [_connetButton setTitle:@"连接" forState:UIControlStateNormal];
        [_connetButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        _connetButton.titleLabel.font = [UIFont systemFontOfSize:17];
        [_connetButton addTarget:self action:@selector(connetButtonCLick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _connetButton;
}
- (void)connetButtonCLick:(UIButton *)btn{
    if (_connected) {
        [self showMessageWithStr:@"与服务器已断开连接"];
        [_clientSocket disconnect];
    }else{

        [self initSocket];
    }
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

