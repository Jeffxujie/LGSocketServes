//
//  LGSocketServe.m
//  AsyncSocketDemo
//
//  Created by macxu on 15/4/3.
//  Copyright (c) 2015年 macxu. All rights reserved.
//

#import "LGSocketServe.h"
#import "GPBProtocolBuffers.h"
#import "Qmessage.pbobjc.h"
#import "Qmessage.pbobjc.h"
#import "AsyncSocket.h"
#import "GCDAsyncUdpSocket.h"

//自己设定
//#define HOST @"192.168.1.1"
//#define PORT 8080
#import "GPBCodedOutputStream_PackagePrivate.h"
//每次最多读取多少
#define MAX_BUFFER 1024*1024
//连接回调
typedef void(^reConnection)(BOOL isComplate);

@interface LGSocketServe()<AsyncSocketDelegate,GCDAsyncUdpSocketDelegate>
{
    id<LGSocketServeDelegate> newDelegate;
}
@property (nonatomic, strong) AsyncSocket * socket;

//判断是否已经连接
@property (nonatomic,assign) BOOL isStartConnect;

//整个完整数据的长度
@property (nonatomic,assign) NSInteger dataLength;

///用来判断调用接口的时候 是否收到返回的数据
@property (nonatomic,assign) BOOL isGetSucccess;

///这是用来判断接收消息是否超时的定时器
@property (nonatomic,strong) NSTimer * getmessageTimer;

/// 心跳计时器
@property (nonatomic, retain) NSTimer * heartTimer;

///这是发现协议的定时器
@property (nonatomic,strong) NSTimer * getLoccalAp;

///是否收到了本地的ap的返回消息
@property (nonatomic,assign) BOOL isFind;

///发现协议的sockt
@property (nonatomic,strong) GCDAsyncUdpSocket * findSocket;

///本地是否有网关设备
@property (nonatomic,assign) BOOL isHaveLocal;

///回调
@property (nonatomic,copy) reConnection reconnection;

@end

@implementation LGSocketServe

static LGSocketServe *socketServe = nil;


#pragma mark public static methods

+ (LGSocketServe *)sharedSocketServe {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        socketServe = [[LGSocketServe alloc] init];
    });
    
    return socketServe;
}

+(id)allocWithZone:(NSZone *)zone
{
    @synchronized(self)
    {
        if (socketServe == nil)
        {
            socketServe = [super allocWithZone:zone];
            return socketServe;
        }
    }
    return nil;
}


- (void)startConnectSocket
{
    //已经连接 不允许在连接
    if([self isConnection]) return;
    if([[self removeEmptWithString:self.houst] isEqualToString:@""] || [[self removeEmptWithString:self.port] isEqualToString:@""])
    {
        //连接失败
        if(_orignalCls==[self getdelegateClass])
        if([newDelegate respondsToSelector:@selector(connectionIsComplate:AndWithFailMassega:)])
        {
            [newDelegate connectionIsComplate:NO AndWithFailMassega:@"Parameter error"];
        }
        return;
    }
    socketServe.isStartConnect=YES;
    self.socket = [[AsyncSocket alloc] initWithDelegate:self];
    [self.socket setRunLoopModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
    [self SocketOpen:self.houst port:[self.port integerValue]];
}

//进行重连
-(void)reConnection:(void (^)(BOOL))complate
{
    self.reconnection=complate;
    if(![self isConnection])
    {
        if(self.houst&&self.port)
        {
            //开始重连
            [self SocketOpen:self.houst port:[self.port integerValue]];
        }
        //重连失败
        else
        {
            self.reconnection(NO);
            self.reconnection=nil;
        }
    }
    else
    {
        self.reconnection(NO);
        self.reconnection=nil;
        //已经连接 不需要再连接
//        NSLog(@"socket已经连接，不允许再进行连接");
    }
}

- (NSInteger)SocketOpen:(NSString*)addr port:(NSInteger)port
{
    
    if (![self.socket isConnected])
    {
        NSError *error = nil;
        NSTimeInterval time = self.connnectionTimeOut <=0 ? 10 : self.connnectionTimeOut;
        
        if(![self.socket connectToHost:addr onPort:port withTimeout:time error:&error])
        {
            if(self.reconnection)
            {
                self.reconnection(NO);
                
                self.reconnection=nil;
//                NSLog(@"连接失败!");
            }
            //连接失败
            else if(_orignalCls==[self getdelegateClass])
            {
                if([newDelegate respondsToSelector:@selector(connectionIsComplate:AndWithFailMassega:)])
                {
                    [newDelegate connectionIsComplate:NO AndWithFailMassega:error.description];
                }
            }
        }
    }
    
    return 0;
}

//手动断开连接
-(void)cutOffSocket
{
    self.socket.userData = SocketOfflineByUser;
    [self.socket disconnect];
    //停止心跳
    [self stopHeabet];
}

//发送消息
- (void)sendMessage:(id)message
{
    if(self.socket)
    {
        self.isGetSucccess=NO;
        //像服务器发送数据
        NSData *cmdData = [message isKindOfClass:[NSData class]]==YES ? message :[message dataUsingEncoding:NSUTF8StringEncoding];
//        NSTimeInterval time = self.getTimeOut<=0 ? -1 :self.getTimeOut;
        [self.socket writeData:cmdData withTimeout:-1 tag:0];
        if(![self.socket isConnected])
        {
            if(_orignalCls==[self getdelegateClass])
            if([newDelegate respondsToSelector:@selector(sendMessageIsComplate:)])
            {
                [newDelegate sendMessageIsComplate:NO];
            }
        }
    }
    else
    {
        if(_orignalCls==[self getdelegateClass])
        if([newDelegate respondsToSelector:@selector(sendMessageIsComplate:)])
        {
            [newDelegate sendMessageIsComplate:NO];
        }
    }
}


#pragma mark - Delegate
//断开连接
- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
    lostConnectionType lostType=0;
    
    if (sock.userData == SocketOfflineByServer) {
        lostType = SocketOfflineByServer;
    }
    else if (sock.userData == SocketOfflineByUser) {
        lostType=SocketOfflineByUser;
    }else if (sock.userData == SocketOfflineByWifiCut) {
        
        lostType=SocketOfflineByWifiCut;
    }
    [self lostConnection:lostType];
    
    [self stopHeabet];
}

-(void)stopHeabet
{
    if(self.heartTimer)
    {
        [self.heartTimer invalidate];
        self.heartTimer=nil;
    }
}

//断开连接协议回调 通知客户端
-(void)lostConnection:(lostConnectionType)type
{
    if(_orignalCls==[self getdelegateClass])
    if([newDelegate respondsToSelector:@selector(cutOffSocketWithType:)])
    {
        [newDelegate cutOffSocketWithType:type];
    }
}

//出错 也要去跑一次关于失败的方法
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
    NSData * unreadData = [sock unreadData]; // ** This gets the current buffer
    if(unreadData.length > 0) {
        [self onSocket:sock didReadData:unreadData withTag:0]; // ** Return as much data that could be collected
    } else {
        [self stopHeabet];
        
        if (err.code == 57) {
            self.socket.userData = SocketOfflineByWifiCut;
        }
        else if (err.code==65)
        {
            if(self.reconnection)
            {
                self.reconnection(NO);
                self.reconnection=nil;
//                NSLog(@"重连失败!");
            }
            else if(_orignalCls==[self getdelegateClass])
            {
                if([newDelegate respondsToSelector:@selector(connectionIsComplate:AndWithFailMassega:)])
                {
                    [newDelegate connectionIsComplate:NO AndWithFailMassega:@"请检查你的网络连接"];
                }
            }
        }
        else if(err.code==1)
        {
            if (self.reconnection)
            {
                self.reconnection(NO);
                self.reconnection=nil;
//                NSLog(@"重连失败!");
            }
        }
        else if (err.code==2)
        {
            if (self.reconnection)
            {
                self.reconnection(NO);
                self.reconnection=nil;
//                NSLog(@"重连失败!");
            }
        }
    }
}

//用户发起新的连接
- (void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket
{
    NSLog(@"didAcceptNewSocket");
}

//连接成功
- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    [self.socket readDataWithTimeout:-1 tag:0];

    if (self.reconnection)
    {
        self.reconnection(YES);
        self.reconnection=nil;
//        NSLog(@"重连成功!");
    }
    //连接成功
    else if(_orignalCls==[self getdelegateClass])
    {
        if([newDelegate respondsToSelector:@selector(connectionIsComplate:AndWithFailMassega:)])
        {
            [newDelegate connectionIsComplate:YES AndWithFailMassega:@"success"];
        }
    }
    [self performSelector:@selector(startHeartBeatTimer) withObject:nil afterDelay:self.heartTime inModes:@[NSRunLoopCommonModes]];
    
}

-(void)startHeartBeatTimer
{
    if([self.socket isConnected])
    {
        //通过定时器不断发送消息，来检测长连接
        self.heartTimer = [NSTimer scheduledTimerWithTimeInterval:self.heartTime target:self selector:@selector(checkLongConnectByServe) userInfo:nil repeats:YES];
        [self.heartTimer fire];
        [[NSRunLoop currentRunLoop] addTimer:self.heartTimer forMode:NSRunLoopCommonModes];
    }
}

//连接失败
-(void)onSocketDidConnectFail
{
    if(self.reconnection)
    {
        self.reconnection(NO);
        self.reconnection=nil;
//        NSLog(@"重连失败!");
    }
    else if (_orignalCls==[self getdelegateClass])
    {
        if([newDelegate respondsToSelector:@selector(connectionIsComplate:AndWithFailMassega:)])
        {
            [newDelegate connectionIsComplate:NO AndWithFailMassega:@"timeout"];
        }
    }
}

//接受消息成功之后回调
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    BOOL isSuccess=NO;
    NSData * newData=nil;
    int length =(int)[self getProtoBUfLenght:data];
    
    newData= [data subdataWithRange:NSMakeRange(data.length-length, length)];
    
    QPack * pack = [QPack parseFromData:newData error:nil];
    //心跳返回的数据
    if(pack.packetType==PackType_HeartbeatAck)
    {
        NSLog(@"Heart Boom");
    }
    //是否发送成功 设备是否在线0成功 1不在线 2设备异常
    else if (pack.packetType==PackType_RpcAck)
    {
        int status = pack.rpcAck.status;
        EQUIPMENT equipment=0;
        if(status==0)
        {
            equipment=EQUIPMENT_SUCCESS;

        }
        else if (status==1)
        {
            equipment=EQUIPMENT_NOT_ONLINE;
//            self.isGetSucccess=YES;
            [self checkGetmessage:self.getmessageTimer];
        }
        else if (status==2)
        {
            equipment=EQUIPMENT_ERROR;
//            self.isGetSucccess=YES;
            [self checkGetmessage:self.getmessageTimer];
        }
        //设备是否在线
        if(_orignalCls==[self getdelegateClass])
        if([newDelegate respondsToSelector:@selector(equipmentType:)])
        {
            [newDelegate equipmentType:equipment];
        }
    }
    //返回的查询消息
    else if (pack.packetType==PackType_RpcMessage)
    {
        self.isGetSucccess=YES;
        [self checkGetmessage:self.getmessageTimer];
        
        RPC_ACK * ack = [[RPC_ACK alloc] init];
        ack.data = pack;
        Ack * message  = [ack getAckFromQpack];
        if(message)
        {
            isSuccess=YES;
        }
        //消息的回调
        if(_orignalCls==[self getdelegateClass])
        if([newDelegate respondsToSelector:@selector(getMessageIsComplate:AndWithresponseObject:)])
        {
            [newDelegate getMessageIsComplate:isSuccess AndWithresponseObject:message];
        }
    }
    [self.socket readDataWithTimeout:-1 buffer:nil bufferOffset:0 maxLength:MAX_BUFFER tag:0];
}

-(NSInteger)getProtoBUfLenght:(NSData *)data
{
    int32_t lenth=0;
    
    GPBCodedInputStream * input = [[GPBCodedInputStream alloc] initWithData:data];
     lenth = (int32_t)[input readInt64];
     
    return lenth;
}

//连接成功 返回yes表示继续操作  no表示不继续
- (BOOL)onSocketWillConnect:(AsyncSocket *)sock
{
    return YES;
}

//发送消息成功之后回调
- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    //用来判断到底是不是心跳数据 如果是 那么不会开启超时处理
    if(tag!=100)
    {
        NSTimeInterval timer = self.getTimeOut<=0 ? 10 :self.getTimeOut;
        
        self.isGetSucccess=NO;
        self.getmessageTimer = [NSTimer scheduledTimerWithTimeInterval:timer target:self selector:@selector(checkGetmessage:) userInfo:nil repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:self.getmessageTimer forMode:NSRunLoopCommonModes];
        
        //读取消息
        [self.socket readDataWithTimeout:-1 buffer:nil bufferOffset:0 maxLength:MAX_BUFFER tag:0];
        if(_orignalCls==[self getdelegateClass])
        if([newDelegate respondsToSelector:@selector(sendMessageIsComplate:)])
        {
            [newDelegate sendMessageIsComplate:YES];
        }
    }
}

//判断是否读取消息失败
-(void)checkGetmessage:(NSTimer *)timer
{
    if(self.getmessageTimer)
    {
        [self.getmessageTimer invalidate];
        self.getmessageTimer=nil;
    }
    
    if(!self.isGetSucccess)
    {
        if(_orignalCls==[self getdelegateClass])
        if([newDelegate respondsToSelector:@selector(sendDataOrGetDataTimeout:)])
        {
            [newDelegate sendDataOrGetDataTimeout:GETMESSAGE_TIMEOUT];
        }
    }
}

//是否已经连接
-(BOOL)isConnection
{
    return [self.socket isConnected];
}

// 心跳连接
-(void)checkLongConnectByServe{
    // 向服务器发送固定格式的消息，来检测长连接
    QPack * pack = [self sendPacket];
    [self.socket writeData:[self qpackBase128:pack] withTimeout:-1 tag:100];
}

//心跳包
-(QPack *)sendPacket
{
    QPack * qpack = [[QPack alloc] init];
    qpack.packetType=PackType_HeartbeatReq;
    qpack.packetVersion=0;
    //心跳
    qpack.heartbeatReq = [[HeartbeatReq alloc] init];
    
    if(![[self cheackString:self.sessionID] isEqualToString:@"nil"])
    qpack.heartbeatReq.sessionId =self.sessionID;
    //base128编码
    return qpack;
}

#pragma base128编码
-(NSMutableData *)qpackBase128:(QPack *)pack
{
    int bodyLen = (int)pack.serializedSize;

    NSMutableData * data = [self dataWithRawVarint32:bodyLen];
    Byte * byt = (Byte *)[pack.data bytes];
    [data appendBytes:byt length:pack.data.length];
    
    return data;
}

-(NSMutableData *)dataWithRawVarint32:(int64_t)value
{
    NSMutableData *valData = [[NSMutableData alloc] init];
    while (true) {
        if ((value & ~0x7F) == 0) {//如果最高位是0，只要一个字节表示
            [valData appendBytes:&value length:1];
            break;
        } else {
            int valChar = (value & 0x7F) | 0x80;//先写入低7位，最高位置1
            [valData appendBytes:&valChar length:1];
            value = value >> 7;//再写高7位
        }
    }
    return valData;
}

-(NSString *)cheackString:(NSString *)str
{
    if(str==nil||[self removeEmptWithString:str].length<=0)
    {
        return @"nil";
    }
    return [self removeEmptWithString:str];
}

-(NSString *)removeEmptWithString:(NSString *)str
{
    if(str==nil||str.length<=0) return @"";
    
    NSMutableString * newStr = [[NSMutableString alloc] init];
    NSMutableString * oldStr = [[NSMutableString alloc] initWithString:str];
    for (int i=0; i<oldStr.length; i++)
    {
        if([[oldStr substringWithRange:NSMakeRange(i, 1)] isEqualToString:@" "])
        {
            continue;
        }
        [newStr appendString:[oldStr substringWithRange:NSMakeRange(i, 1)]];
    }
    return newStr;
}

///////////这个是关于发现协议的方法////////////
//发现是否在同一个局域网 如果是 那么走局域网  不是 那就走外网+转发服务器 udp广播
-(void)ChaseLocalAreaNetwork
{
    self.isFind=NO;
//    NSLog(@"开始运行");
    GCDAsyncUdpSocket *  asyncSocket = self.findSocket;
    
    [asyncSocket sendData:[@"MKAP" dataUsingEncoding:NSUTF8StringEncoding] toHost:@"255.255.255.255" port:self.localport withTimeout:-1
                      tag:1];
    
    self.getLoccalAp =[NSTimer scheduledTimerWithTimeInterval:0.5f target:self selector:@selector(findLocalAp) userInfo:nil repeats:NO];
    
    [[NSRunLoop currentRunLoop] addTimer:self.getLoccalAp forMode:NSRunLoopCommonModes];
}

//判断是否发现协议调用超时
-(void)findLocalAp
{
//    NSLog(@"发现协议超时");
    if(self.getLoccalAp)
    {
        [self.getLoccalAp invalidate];
        self.getLoccalAp=nil;
    }
    if(!self.isFind)
    {
//        NSLog(@"2发现协议超时");
        if(_orignalCls==[self getdelegateClass])
        {
            if([newDelegate respondsToSelector:@selector(CheackLocalAreaNetwork: AndWithResposed:)])
            {
//                NSLog(@"3发现协议超时");
                [newDelegate CheackLocalAreaNetwork:NO AndWithResposed:[NSDictionary new]];
            }
            else
            {
                if(self.findSocket)
                {
                    self.findLocal(YES,[NSDictionary new]);
                }
            }
        }
        else
        {
            if(self.findLocal)
            {
                self.findLocal(NO,[NSDictionary new]);
            }
        }
        self.isHaveLocal=NO;
        [self.findSocket close];
        _findSocket=nil;
    }
}

-(GCDAsyncUdpSocket *)findSocket
{
    if(!_findSocket)
    {
        _findSocket =[[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        
        NSError * error = nil;
        
        if(![_findSocket enableBroadcast:YES error:&error])
        {
            NSLog(@"%@",error.description);
        }
        if(![_findSocket bindToPort:9090 error:&error])
        {
            NSLog(@"%@",error.description);
        }
        self.localport = self.localport<=0 ? 10096 : self.localport;
        
        if(![_findSocket beginReceiving:&error])
        {
            NSLog(@"%@",error.description);
        }
        
        if(![_findSocket receiveOnce:&error])
        {
            NSLog(@"%@",error.description);
        }
    }
    return _findSocket;
}

//收到服务器的返回消息 证明在同一局域网
- (void)udpSocket:(GCDAsyncUdpSocket *)sock
   didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext
{
    NSError * error =nil;
//    NSLog(@"收到发现协议");
    NSDictionary * dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    if(error==nil&&dic!=nil)
    {
        self.isFind=YES;
        [self.getLoccalAp invalidate];
        self.getLoccalAp=nil;
        self.isHaveLocal=YES;
//        NSLog(@"这是将要执行发现协议");
        if(_orignalCls==[self getdelegateClass])
        {
//            NSLog(@"这是正在执行");
            if([newDelegate respondsToSelector:@selector(CheackLocalAreaNetwork: AndWithResposed:)])
            {
//                NSLog(@"hahah");
                
                [newDelegate CheackLocalAreaNetwork:YES AndWithResposed:dic];
            }
            else
            {
                if(self.findSocket)
                {
                    self.findLocal(YES,dic);
                }
            }
        }
        else
        {
            if(self.findSocket)
            {
                self.findLocal(YES,dic);
            }
        }
    }
    [sock close];
    _findSocket=nil;
}

//发送失败  证明也不再同一局域网中
-(void)udpSocket:(GCDAsyncUdpSocket *)sock
didNotSendDataWithTag:(long)tag
      dueToError:(NSError *)error
{
    self.isHaveLocal=NO;
    self.isFind=NO;
    [self.getLoccalAp invalidate];
    self.getLoccalAp=nil;
    self.isHaveLocal=NO;
//    NSLog(@"发现协议失败");
    if(_orignalCls==[self getdelegateClass])
    {
        if([newDelegate respondsToSelector:@selector(CheackLocalAreaNetwork: AndWithResposed:)])
        {
            [newDelegate CheackLocalAreaNetwork:NO AndWithResposed:[NSDictionary new]];
        }
        else
        {
            if(self.findSocket)
            {
                self.findLocal(YES,[NSDictionary new]);
            }
        }
    }
    else
    {
        if(self.findSocket)
        {
            self.findLocal(NO,[NSDictionary new]);
        }
    }
    [sock close];
    _findSocket=nil;
}

//是否发现了本地设备
-(BOOL)isHaveFindLocalDevice
{
    return self.isHaveLocal;
}

//设置局部变量 deled=gate
-(void)setDelegate:(id<LGSocketServeDelegate>)delegate
{
    newDelegate=delegate;
    _orignalCls = object_getClass(newDelegate);/**这是关键*/
//    NSLog(@"设置:%s",object_getClassName(_orignalCls));
}
//用来判断delegate是否是以前的delagate 判断一下是不是同一个delagate
-(Class)getdelegateClass
{
//    NSLog(@"1:获得：%s",object_getClassName(object_getClass(newDelegate)));
    return  object_getClass(newDelegate);
}

@end
