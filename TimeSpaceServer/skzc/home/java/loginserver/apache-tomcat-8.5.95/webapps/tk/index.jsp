<%--
  Created by IntelliJ IDEA.
  User: Lee
  Date: 2018/11/9
  Time: 11:29
  To change this template use File | Settings | File Templates.
--%>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<STYLE type="text/css">
    #login {
        width: 400px;
        height: 280px;
        position: absolute;
        left: 50%;
        top: 20%;
        margin-left: -200px;
        margin-top: -140px;
        border: 1px;
       /* background-color: #befff1;*/
        align: center;
    }

    #form {
        width: 300px;
        height: 160px;
        position: relative;
        left: 50%;
        top: 50%;
        margin-left: -150px;
        margin-top: -80px;
    }
</STYLE>

<head>
    <title>《戒灵》添加服务器</title>
</head>
<body>
<div id="login">
    <h1 style="color: #000000" onresize="50">《戒灵》添加服务器</h1>
    <div id="form">
        <form action="regist" method="post" accept-charset="UTF-8">
            <p>name: <input type="text" name="name" placeholder="请输入游戏服务器名字" required /></p>
            <p>ip: <input type="text" name="ip" pattern="(\d+)\.(\d+)\.(\d+)\.(\d+)" placeholder="请输入服务器IP地址" required /></p>
            <p>port: <input type="text" value="9000" name="port" pattern="[0-9]{0,6}" placeholder="请输入端口号" required /></p>
            <p>server_id: <input type="text" name="server_id" pattern="[0-9]{0,6}" placeholder="请输入server id" required />  </p>
            <p>channel:<select name="channel">
                <option value="pc" selected>pc</option>
                <option value="qq">qq</option>
                <option value="wx">wx</option>
            </select></p>
            <p>sub_channel: <input type="text" name="sub_channel" required /></p>
            <p>plat:<select name="plat">
                <option value="android" selected>android</option>
                <option value="ios">ios</option>
            </select></p>
            <p>state: <input type="text" value="0" name="state"  /></p>
            <p>open_time: <input type="text" value="0" name="open_time" /></p>
            <p>isnew: <input type="text" value="0" name="isnew" /></p>
            <input type="submit" value="Submit"/>
        </form>
    </div>
</div>
</body>
</html>
