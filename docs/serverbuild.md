该源码是本人亲测“可用可搭建” 所有文件和教程都会打包发布，除了“某些工具或软件”。
129.226.213.65

如果你搭建不了，不好意思，源码并没有问题。站长QQ：1228689277

温馨提示：不管搭建什么之前服务器都要安装所需环境，关闭防火墙，开放所有端口。

本站教程、资源皆在单机环境进行，仅供单机研究学习使用，下载后请于24小时内删除，或购买正版。

手游源码网唯一网站：www.syymw.com 其他网站皆为搬砖 另外-请各会员或那些搬砖的做好售后工作，谢谢。

※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※

关闭服务器防火墙，开放所有端口参考：https://www.syymw.com 

安装宝塔直接运行命令即可。

centos7.x       yum install -y wget && wget -O install.sh http://download.bt.cn/install/install_6.0.sh && sh install.sh

centos6.x       yum install -y wget && wget -O install.sh http://download.bt.cn/install/install.sh && sh install.sh

centos7.x   安装宝塔面板视频教程:https://www.syymw.com/3281.html
centos6.x   安装宝塔面板视频教程:https://www.syymw.com/3232.html

------------------------------------------------------------------------------------
【时空战场免编译内购版-附带全套源码】站长推荐稀有次元卡牌回合手游-2024年7月19日最新打包Linux服务端源码视频架设教程-安卓苹果ios双端版本！
-------------------------------------------------------------------------------
mongodb://m18813294096_gmail_com:Shen_Feng_440923-1995032-95151@127.0.0.1:27017/?authSource=admin

测试系统：Centos7.6系统


安装宝塔

yum install -y wget && wget -O install.sh https://download.bt.cn/install/install_6.0.sh && sh install.sh ed8484bec

输入y回车确认安装


安装环境
Nginx-1.24
Redis-7.2.4
MongoDB-4.0


宝塔放行端口：1-65535

关闭防火墙：

systemctl stop firewalld
systemctl disable firewalld



上传服务端 skzc.zip 到服务器根目录/

解压 

cd /
unzip skzc.zip


给权限：

chmod -R 777 /home/



安装环境：

yum install -y java-1.8.0-openjdk-devel.x86_64



添加宝塔里面数据库

宝塔面板--数据库--MongoDB 

#注意:MongoDB 

#添加数据库

x1_cn_test_login

admin


#在ssh 依次复制输入命令  ：修改你的IP为服务器外网IP再输入命令

mongo
use x1_cn_test_login
db.getCollection("server_info").drop();
db.createCollection("server_info");
db.getCollection("server_info").insert([ {
    _id: NumberInt("1"),
    name: "神之伊甸园一区",
    ip: "129.226.213.65",                                          
    port: "16081",
    "server_id": "10001",
    channel: "pc",
    "sub_channel": "1",
    state: "2",
    plat: "android",
    "open_time": "1700622508",
    "open_type": "1",
    "is_new": "0",
    "is_banreg": "0",
    isWhite: "0",
    "server_version": "0",
    "gm_ip": "127.0.0.1",
    "gm_port": "7916",
    "time_zone": "UTC+8",
    currency: "$",
    exportdata: "1",
    isnew: 1
} ]);


use admin

db.createUser({
  user: "a772616239",
  pwd: "Wang177752",
  roles: [
    { role: "userAdminAnyDatabase", db: "admin" },
    { role: "dbAdminAnyDatabase", db: "admin" },
    { role: "readWriteAnyDatabase", db: "admin" }
  ]
})exit

129.226.213.65



创建网站：

IP:81

网站目录：/www/wwwroot/rg



修改服务端IP：123.207.42.5

\www\wwwroot\rg\1\Android\version.txt

\www\wwwroot\rg\1\IOS\version.txt

/home/java/gameserver/config/logicSrv.properties
/home/java/loginserver/apache-tomcat-8.5.95/config/x1/application.properties
/home/java/gameserver/conf/application-core1.properties

sed -i 's/admin:123456/a772616239:Wang177752/g' /home/java/gameserver/config/logicSrv.properties
sed -i 's/admin:123456/a772616239:Wang177752/g' /home/java/loginserver/apache-tomcat-8.5.95/config/x1/application.properties
sed -i 's/admin:123456/a772616239:Wang177752/g' /home/java/gameserver/conf/application-core1.properties

sed -i 's/a772616239:Wang177752/a772616239:Wang/g' /home/java/gameserver/config/logicSrv.properties
sed -i 's/a772616239:Wang177752/a772616239:Wang/g' /home/java/loginserver/apache-tomcat-8.5.95/config/x1/application.properties
sed -i 's/a772616239:Wang177752/a772616239:Wang/g' /home/java/gameserver/conf/application-core1.properties

tar -czvf   /home/java/  /home/java/test.tar.gz
sed -i 's/x1_cn_test_login/m5_x1_game_10001/g'  /home/java/gameserver/config/logicSrv.properties

#启动
redis-cli FLUSHDB

cd /home/java/gameserver
sudo nohup java -jar gameSrv-1.0.0.jar --spring.config.location=config/logicSrv.properties > log.file 2>&1 &


cd /home/java/chatserver
sudo nohup java -jar chatserver-1.0.0.jar > log.file 2>&1 &

#启动
cd /home/java/loginserver/apache-tomcat-8.5.95/bin
sudo ./startup.sh

cd /home/java/loginserver/apache-tomcat-8.5.95/logs

关闭

cd /home/java/loginserver/apache-tomcat-8.5.95/bin
sudo ./shutdown.sh 


修改客户端：

安卓：替换：123.207.42.5 

\assets\bin\Data\c903ed81b528e4c44b1cd995ee46aa72      类似：  123.207.42.05 十六进制修改工具修改  不够位数补0

\assets\Android\Resources\version.txt


苹果:替换： 101.35.30.218

\Payload\game.app\Data\resources.assets

\Payload\game.app\Data\Raw\IOS\Resources\version.txt

------------------------------------------------------------------------------------

本期教程到此结束。


------------------------------------------------------------------------------------
手游源码网唯一网站：www.syymw.com 
------------------------------------------------------------------------------------

------------------------------------------------------------------------------------
END
------------------------------------------------------------------------------------

如果不会搭建，可以付费联系站长搭建 站长QQ：1228689277

------------------------------------------------------------------------------------

源码来源与网络。本源码只是供大家研究学习之用。请大家不要用于商用，否者如引起一切纠纷和本人与论坛无关，后果自负，请下载后24小时内删除！！！
keytool -list -keystore /Users/wangxufeng/Documents/TimeSpace2019To2022_2/beauty.keystore