## Deployment of Sample Application named JBoss-EAP_on_Azure

The source code of this application was fetched from [here](https://github.com/MyriamFentanes/dukes). The only change we have made is in the [testHA.jsp](https://github.com/Azure/rhel-jboss-templates/blob/master/JBoss-EAP_on_Azure/target/dukes/testHA.jsp) to add few images and provide few reference links. We have created a war file named [JBoss-EAP_on_Azure.war](https://github.com/Azure/rhel-jboss-templates/blob/master/JBoss-EAP_on_Azure/target/JBoss-EAP_on_Azure.war) using these files and used this war file to deploy the sample application in the following Azure quickstart templates.

*  <a href="https://github.com/Azure/azure-quickstart-templates/tree/master/jboss-eap-standalone-rhel" target="_blank"> JBoss EAP on RHEL (stand-alone VM)</a>
*  <a href="https://github.com/Azure/azure-quickstart-templates/tree/master/wildfly-standalone-centos8" target="_blank"> WildFly 18 on CentOS 8 (stand-alone VM)</a>

This is a JWeb application to test session persistence and availability.
