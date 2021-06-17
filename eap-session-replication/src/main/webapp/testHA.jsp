<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<%@page import="java.util.Date"%>
<%@page import="java.io.File,java.io.BufferedReader,java.io.FileReader" %>

<html>
<head>
<title>Testing JBoss EAP Session Replication</title>

<style type="text/css">
body {
	color: #333;
	font-family: Helvetica, Arial, sans-serif;
}

table {
	color: #333;
	font-family: Helvetica, Arial, sans-serif;
	width: 640px;
	border-collapse: collapse;
	border-spacing: 0;
}

td,th {
	border: 1px solid #CCC;
	height: 30px;
}

th {
	background: #F3F3F3;
	font-weight: bold;
}

td {
	background: #FAFAFA;
	text-align: center;
}
</style>
<style>
    .container {
      position: relative;
      width: 550;
    }
    
    .container img {
      width: 640;
      height: auto;
    }
    
    .container .btn1 {
      position: absolute;
      top: 80%;
      left: 37%;
      -ms-transform: translate(-50%, -50%);
      background-color: rgb(128, 34, 34);
      color: white;
      font-size: 11px;
      padding: 5px 12px;
      border: none;
      cursor: pointer;
      text-align: center;
    }
    .container .btn {
      position: absolute;
      top: 80%;
      left: 37%;
      -ms-transform: translate(-50%, -50%);
      background-color: #555;
      color: white;
      font-size: 11px;
      padding: 5px 12px;
      border: none;
      cursor: pointer;
      text-align: center;
    }
    
    .container .btn:hover {
      background-color: black;
    }
    .container .btn1:hover {
      background-color: black;
    }
</style>
<style>
    .container-eap {
      position: relative;
      width: 637;
    }
    
    .container-eap img {
      width: 640;
      height: 230;
    }
    
    .container-eap .btn1 {
      position: absolute;
      top: 80%;
      left: 45%;
      -ms-transform: translate(-50%, -50%);
      background-color: rgb(85, 140, 230);;
      color: white;
      font-size: 11px;
      padding: 5px 12px;
      border: none;
      cursor: pointer;
      text-align: center;
    }
    .container-eap .btn2 {
      position: absolute;
      top: 80%;
      left: 58%;
      -ms-transform: translate(-50%, -50%);
      background-color: rgb(85, 140, 230);;
      color: white;
      font-size: 11px;
      padding: 5px 12px;
      border: none;
      cursor: pointer;
      text-align: center;
    }
    .container-eap .btn3 {
      position: absolute;
      top: 80%;
      left: 71%;
      background-color: rgb(85, 140, 230);;
      color: white;
      font-size: 11px;
      padding: 5px 10px;
      border: none;
      cursor: pointer;
      text-align: center;
    }
    
    .container-eap .btn1:hover {
      background-color: black;
    }
    .container-eap .btn2:hover {
      background-color: black;
    }
    .container-eap .btn3:hover {
      background-color: black;
    }                        
</style>
</head>

<body>

    <%
        java.net.InetAddress inetAdd = java.net.InetAddress.getLocalHost();
        String hostname = inetAdd.getHostAddress();
    
        // get counter
        Integer counter = (Integer) session.getAttribute("demo.counter");
        if (counter == null) {
            counter = 0;
            session.setAttribute("demo.counter", counter);
        }

        // check for increment action
        String action = request.getParameter("action");

        if (action != null && action.equals("increment")) {
            // increment number
            counter = counter.intValue() + 1;

            // update session
            session.setAttribute("demo.counter", counter);
            session.setAttribute("demo.timestamp", new Date());
        }
    %>
    <h3>Testing JBoss EAP Session Replication</h3>
    <hr>

    <br> <b>Session Data</b>

    <br>
    <br>

    Session ID: <%=session.getId()%>

    <br>
    <br>

    <table>
        <tr>
            <th>Description</th>
            <th>Attribute Name</th>
            <th>Attribute Value</th>
        </tr>

        <tr>
            <td>Session counter</td>
            <td>demo.counter</td>
            <td><%= session.getAttribute("demo.counter") %></td>
        </tr>

        <tr>
            <td>Timestamp of last increment</td>
            <td>demo.timestamp</td>
            <td><script>document.write(new Date());</script></td>
        </tr>
    </table>

    <br>
    <br> Page served by VM: <%= hostname %> at <script>document.write(new Date());</script>

    <br>
    <br>

    <a href="testHA.jsp?action=increment">Increment Counter</a> |
    <a href="testHA.jsp">Refresh</a>

    <br>
    <br>

    <table width="600" border="1" align="left" cellpadding="0" cellspacing="0">
        <tr>
                <td colspan="2">
                        <div class="container">        
                                <img src="https://raw.githubusercontent.com/Azure/rhel-jboss-templates/master/images/redhat-logo1.png" width="640">
                                <a href="mailto:appdevonazure@redhat.com" target="_blank"><button class="btn1">CONTACT US TO SCHEDULE A WORKSHOP</button> </a>
                        </div>
                </td>
                
        <tr>
                <td colspan="2">
                        <div class="container">        
                                <img src="https://raw.githubusercontent.com/Azure/rhel-jboss-templates/master/images/redhat-logo2.png" width="640">
                                <a href="https://azure.microsoft.com/en-us/services/openshift/" target="_blank"><button class="btn">GET STARTED WITH AZURE RED HAT OPENSHIFT</button> </a>
                        </div>
                </td>
                
        <tr>
                <td colspan="2">
                        <div class="container-eap">        
                                <img src="https://raw.githubusercontent.com/Azure/rhel-jboss-templates/master/images/redhat-logo3.png" width="640">
                                <a href="https://developers.redhat.com/products/eap/download/" target="_blank"><button class="btn1">TRY IT</button></a>
                                <a href="https://www.redhat.com/en/store" target="_blank"><button class="btn2">BUY IT</button></a>
                                <a href="https://www.redhat.com/en/contact" target="_blank"><button class="btn3">TALK TO A RED HATTER</button></a>
                        </div>
                </td>
                
        <tr>
                <td colspan="2">
                        <font size="-1" face="Verdana, Arial, Helvetica, sans-serif">                                                        
                                <a href="https://github.com/Azure/rhel-jboss-templates/tree/master/eap-session-replication" target="_blank"><B>Click here to access the Source Code of this application</B></a><br>
                        </font>
                </td>
        </tr>
    </table>

</body>
</html>