<%@ page import="com.ljsd.util.BaseGlobal" %>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%
    String serverInfoList = BaseGlobal.getInstance().mongoDBPool.findList("server_info");

%>
<html>
<title>戒灵服务器列表</title>
</head>
<body>
<h1>戒灵服务器列表</h1>
<table id="table" border="1" cellspacing="0" cellpadding="15" >
    <tr>
        <th>_id</th>
        <th>name</th>
        <th>ip</th>
        <th>port</th>
        <th>server_id</th>
        <th>channel</th>
        <th>sub_channel</th>
        <th>plat</th>
        <th>state</th>
        <th>open_time</th>
    </tr>
</table>
<script>
    window.onload=function(){
        var data=<%=serverInfoList%>;


        var table=document.getElementById("table");
        for(var i=0;i<data.length;i++){
            var row=table.insertRow(table.rows.length);
            var c1=row.insertCell(0);
            c1.innerHTML=data[i]._id;
            var c2=row.insertCell(1);
            c2.innerHTML=data[i].name;
            var c3=row.insertCell(2);
            c3.innerHTML=data[i].ip;
            var c4=row.insertCell(3);
            c4.innerHTML=data[i].port;
            var c5=row.insertCell(4);
            c5.innerHTML=data[i].server_id;
            var c5=row.insertCell(5);
            c5.innerHTML=data[i].channel;
            var c5=row.insertCell(6);
            c5.innerHTML=data[i].sub_channel;
            var c5=row.insertCell(7);
            c5.innerHTML=data[i].plat;
            var c5=row.insertCell(8);
            c5.innerHTML=data[i].state;
            var c5=row.insertCell(9);
            c5.innerHTML=data[i].open_time;
        }
    }
</script>
</body>
</html>