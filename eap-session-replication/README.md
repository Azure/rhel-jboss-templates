Create a clustered JBoss EAP application with session replication
===================


The source code of this application was fetched from [here](https://github.com/danieloh30/eap-session-replication). The only change we have made is in the [testHA.jsp](https://github.com/Azure/rhel-jboss-templates/blob/master/eap-session-replication/target/testHA.jsp) to add few images and provide few reference links. We have created a war file named [eap-session-replication.war](https://github.com/Azure/rhel-jboss-templates/blob/master/eap-session-replication/target/eap-session-replication.war) using these files and used this war file to deploy the sample application in the following Azure quickstart templates.

* <a href="https://github.com/Azure/azure-quickstart-templates/tree/master/jboss-eap-clustered-multivm-rhel" target="_blank"> JBoss EAP on RHEL (clustered VMs)</a>
* <a href="https://github.com/Azure/azure-quickstart-templates/tree/master/jboss-eap-clustered-vmss-rhel" target="_blank"> JBoss EAP on RHEL (clustered VMSS)</a>

Once you deploy these templates, the you can find this sample application named **eap-session-replication** deployed on JBoss EAP.

For further details on how to deploy the **eap-session-replication** application on JBoss EAP on clustered RHEL VMs refer [JBoss EAP on RHEL (clustered VMs)](https://github.com/Azure/azure-quickstart-templates/tree/master/jboss-eap-clustered-multivm-rhel).

For further details on how to deploy the **eap-session-replication** application on JBoss EAP on clustered RHEL VMSS refer [JBoss EAP on RHEL (clustered VMSS)](https://github.com/Azure/azure-quickstart-templates/tree/master/jboss-eap-clustered-vmss-rhel).

These Quickstart templates provide you all the details with solution architecture, deployment steps, validation steps and troubleshooting.