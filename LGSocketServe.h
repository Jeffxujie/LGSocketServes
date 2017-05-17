//
//  LGSocketServe.h
//  AsyncSocketDemo
//
//  Created by macxu on 15/4/3.
//  Copyright (c) 2015年 macxu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "RPC_ACK.h"
//发现本地网关的发现协议
typedef void(^findLocalRoot)(BOOL isComplate,NSDictionary *respons);

typedef enum : NSUInteger {
    SocketOfflineByServer=0,      //服务器掉线
    SocketOfflineByUser=1,        //用户断开
    SocketOfflineByWifiCut=2,     //wifi 断开
}lostConnectionType;

typedef enum : NSUInteger {
    EQUIPMENT_SUCCESS, //设备在线
    EQUIPMENT_NOT_ONLINE,//设备离线
    EQUIPMENT_ERROR,//设备异常
} EQUIPMENT;

typedef enum : NSUInteger {
    SENDMESSAGE_TIMEOUT,
    GETMESSAGE_TIMEOUT,
} MessageTimeOutType;

///协议方法 回调方法
@protocol LGSocketServeDelegate <NSObject>

/*!
 @brief 是否发送数据成功
 */
-(void)sendMessageIsComplate:(BOOL)isComplate;

/*!
 @brief 请求数据 或则 接收数据时候 超时
 */
-(void)sendDataOrGetDataTimeout:(MessageTimeOutType)MessageTimeOutType;

/*!
 @brief 请求返回的消息
 */
-(void)getMessageIsComplate:(BOOL)isComplate
      AndWithresponseObject:(Ack *)responseObject;

/*!
 @brief 断开连接的类型
 */
-(void)cutOffSocketWithType:(lostConnectionType)cutType;

/*!
 @brief 远程设备是否在线
 */
-(void)equipmentType:(EQUIPMENT)equmentType;

@optional

/*!
 @brief 是否连接成功 回调方法
 */
-(void)connectionIsComplate:(BOOL)isComplate
         AndWithFailMassega:(NSString *)message;

/*!
 @brief 判断目标设备是否和用户是否在同一个局域网中
 */
-(void)CheackLocalAreaNetwork:(BOOL)islocal
              AndWithResposed:(NSDictionary *)respons;

@end

//class
@interface LGSocketServe : NSObject
{
    Class     _orignalCls;
}
/*!
 @brief 发送数据 请求数据的超时时间 默认是10s
 */
@property (nonatomic,assign) NSTimeInterval getTimeOut;

/*!
 @brief 设置连接的超时时间 默认是10秒
 */
@property (nonatomic,assign) NSTimeInterval connnectionTimeOut;

/*!
 @brief 心跳间隔多少秒跳一次
 */
@property (nonatomic,assign) NSTimeInterval heartTime;

/*!
 @brief 协议回调
 */
@property (nonatomic,assign) id<LGSocketServeDelegate> delegate;

/*!
 @brief ip地址 例如192.168.0.1
 */
@property (nonatomic,copy) NSString * houst;

/*!
 @brief 端口 例如8080
 */
@property (nonatomic,copy) NSString * port;

/*!
 @brief 端口(这个是发现协议的端口) 例如8080
 */
@property (nonatomic,assign) NSInteger  localport;

/*!
 @brief 发送者的ID
 */

@property (nonatomic,copy) NSString * sessionID;

/*!
 @brief 接受者的ID
 */
@property (nonatomic,copy) NSString * dstSessionId;


/*!
 @brief 本地是否有网关设备
 */
@property (nonatomic,assign,readonly) BOOL isHaveFindLocalDevice;

/*!
 @brief 发现协议的block回调
 */
@property (nonatomic,copy) findLocalRoot findLocal;

/*!
 @brief 线程安全的单列
 */
+ (LGSocketServe *)sharedSocketServe;

/*!
 @brief socket连接
 */
- (void)startConnectSocket;

/*!
 @brief socket重新连接
 */
-(void)reConnection:(void(^)(BOOL isComplate))complate;

/*!
 @brief 断开socket连接
 */
-(void)cutOffSocket;

/*!
 @brief 发送消息
 */
- (void)sendMessage:(id)message;

/*!
 @brief socket是否连接
 */
-(BOOL)isConnection;

/*!
 @brief 判断网关和用户是否在同一局域网中
 */
-(void)ChaseLocalAreaNetwork;
@end
