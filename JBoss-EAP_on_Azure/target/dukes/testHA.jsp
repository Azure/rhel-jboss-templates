<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
        <head>
                <title>Testing JBoss EAP on Azure</title>
                <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
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

        <body >
                <%@ page import="javax.servlet.http.*,
                 java.net.InetAddress,
                 java.util.*" %>


		<%

		 Cookie ck = new Cookie ("INGLBCK",InetAddress.getLocalHost().getHostName());
		 ck.setMaxAge(-1);
		 response.addCookie(ck);
		 
		
		%>
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
                              
                                        <font size="+1" face="Verdana, Arial, Helvetica, sans-serif">
                                                <strong>
                                                        
                                                        
                                                        <% String srv = InetAddress.getLocalHost().getHostName();%><%=srv%> ( 
                                                                <%
                                                                try {
                                                        java.net.InetAddress inetAdd =
                                                        java.net.InetAddress.getLocalHost();
                                                        out.println(inetAdd.getHostAddress());
                                                                }catch(java.net.UnknownHostException tsss){
                                                        }
                                                        %>
                                                        )
                                                </strong>      
                                        </font>
                               
                        </td>
                </tr>
                <tr>
                        <td colspan="2">
                                <font size="-1" face="Verdana, Arial, Helvetica, sans-serif">                                                        
                                        <a href="<%=request.getContextPath()%>/testHA.jsp"><B>Test your deployment by clicking on this page to refresh the page data</B></a><br>
                                </font>
                                
                        </td>
                </tr>
                <tr>
                        <td>
                                <%
                                        int cont=0;
                                        if(session.getAttribute("cont")!=null){
                                        cont = Integer.parseInt(session.getAttribute("cont").toString()) + 1;
                                        }
                                        session.removeAttribute("cont");
                                        session.setAttribute("cont",String.valueOf(cont));
                                        String ip = InetAddress.getLocalHost().getHostAddress();
                                        String host = InetAddress.getLocalHost().getHostName();
                                        String hexa = Integer.toHexString(255);
                                        StringTokenizer ipTokenizer = new StringTokenizer(ip,".");
                                        StringBuffer hexaIp = new StringBuffer();
                                        while(ipTokenizer.hasMoreTokens()){
                                        String ipToken = Integer.toHexString(Integer.parseInt(ipTokenizer.nextToken()));
                                        if(ipToken.length()==1)
                                                hexaIp.append("0");
                                        hexaIp.append(ipToken);
                                        }
                                %>
                                <font size="-1" face="Verdana, Arial, Helvetica, sans-serif">COUNT</font>
                        </td>
                        <td>
                                <font size="-1" face="Verdana, Arial, Helvetica, sans-serif">
                                        <%=cont%>
                                        <% System.out.println("\n El contador va en : " + cont);%>
                                </strong>
                                </font>
                        </td>
                </tr>
                <tr>
                        <td>
                                <font size="-1" face="Verdana, Arial, Helvetica, sans-serif">SESSION ID</font>
                        <td>
                                <font size="-1" face="Verdana, Arial, Helvetica, sans-serif"><%=session.getId()%> <% System.out.println("ID de session: " + session.getId());%></font>
                        </td>
                </tr>
                <tr>
                        <td>
                                <font size="-1" face="Verdana, Arial, Helvetica, sans-serif">CLIENT</font>
                        </td>
                        <td>
                                <font size="-1" face="Verdana, Arial, Helvetica, sans-serif"><%=request.getServerName()%></font>
                        </td>
                </tr>
                <tr>
                        <td>
                                <font size="-1" face="Verdana, Arial, Helvetica, sans-serif">SERVER</font>
                        </td>
                        <td>
                                <font size="-1" face="Verdana, Arial, Helvetica, sans-serif"><%=host%></font>
                        </td>
                </tr>
                <tr>
                        <td>
                                <font size="-1" face="Verdana, Arial, Helvetica, sans-serif">CLIENT IP</font>
                        </td>
                        <td>
                                <font size="-1" face="Verdana, Arial, Helvetica, sans-serif"><%=ip%></font>
                        </td>
                </tr>
                <tr>
                        <td>
                                <font size="-1" face="Verdana, Arial, Helvetica, sans-serif">APPLICATION PATH</font>
                        </td>
                        <td>
                                <font size="-1" face="Verdana, Arial, Helvetica, sans-serif"><%=request.getContextPath()%></font>
                        </td>
                </tr>
                <tr>
                        <td>
                                <font size="-1" face="Verdana, Arial, Helvetica, sans-serif">TIMESTAMP</font>
                        </td>
                        <td>
                                <font size="-1" face="Verdana, Arial, Helvetica, sans-serif"><script>document.write(new Date());</script></font>
                        </td>
                </tr>
                <tr>
                        <td colspan="2">
                                <font size="-1" face="Verdana, Arial, Helvetica, sans-serif">                                                        
                                        <a href="https://github.com/Azure/rhel-jboss-templates/tree/master/JBoss-EAP_on_Azure/" target="_blank"><B>Click here to access the Source Code of this application</B></a><br>
                                </font>
                        </td>
                </tr>             
        </table>
</body>
</html>
