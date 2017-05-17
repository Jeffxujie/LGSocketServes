# LGSocketServes
在AsyncSocket基础上又封装一层的库LGSocketServe，自己在又在此基础上重新修改了一下。主要是加入了心跳，掉线，掉线重连等一些功能
客户端的一些主要代码
一：连接服务器

-(void)startConnection{

    self.socketss= [LGSocketServesharedSocketServe];//单例

    self.socketss.houst=@"61.142.250.116";//服务端的ip

    self.socketss.delegate=self;//协议代理

    self.socketss.port=@"8866";//端口号

    self.socketss.heartTime=40;//心跳间隔时间

    self.socketss.isUseSSL=NO;//是否采用ssl加密验证

    self.socketss.sessionID=self.SrcSessionID;//发送者的id

    self.socketss.dstSessionId=self.DstSessionID;//接受者的id

    [self.socketssstartConnectSocket];//发起连接

   self.socketss.getTimeOut=10;//发送数据和接收数据的超时时间

   self.socketss.connnectionTimeOut=10;//连接超时的时间

}

二：连接成功的回调

//是否连接成功

-(void)connectionIsComplate:(BOOL)isComplate AndWithFailMassega:(NSString*)message{

     if(!isComplate){

          NSLog(@"失败:%@",message);

     }

   else{

       NSLog(@"成功%@",message);

     }

}

三：发送数据

     [self.socketsssendMessage:@"这是测试"];

四：发送数据成功的回调函数

//向服务器发送消息是否发送成功

-(void)sendMessageIsComplate:(BOOL)isComplate{

    if(isComplate==YES){

        NSLog(@"发送成功");

    }

    else{

        NSLog(@"发送失败");

    }

}

五：接收数据

//请求 返回的消息

-(void)getMessageIsComplate:(BOOL)isComplate  AndWithresponseObject:(id)responseObject{

     if(isComplate){

          NSLog(@"%@",responseObject);

    }

    else{

        NSLog(@"回去消息失败");

   }

}

六：socket断开连接的类型

//断开连接的类型可以在这里进行重连

-(void)cutOffSocketWithType:(lostConnectionType)cutType{

     switch(cutType) {

      caseSocketOfflineByServer:

               NSLog(@"服务器把你断开");

      break;

      caseSocketOfflineByUser:

             NSLog(@"你自己断开的");

      break;

      caseSocketOfflineByWifiCut:

             NSLog(@"断网了");

      break;

    default:

     break;

    }

}

