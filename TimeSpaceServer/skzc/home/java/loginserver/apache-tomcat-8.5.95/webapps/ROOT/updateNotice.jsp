
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<STYLE type="text/css">
    #publish {
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
    <title>《戒灵》发布公告</title>
</head>
<body>
<div id="publish">
    <h1 style="color: #000000" onresize="50">《戒灵》发布公告</h1>
    <div id="form">
        <form action="publishNotice" method="post" accept-charset="UTF-8">
            <p>name: <input type="text" name="title" placeholder="游戏公告标题" required /></p>
            <p>name: <input type="text" name="content" placeholder="游戏公告内容" required /></p>
            <input type="submit" value="Submit"/>
        </form>
    </div>
</div>
</body>
</html>
