## Securing an application deployed to WildFly with OpenID Connect (OIDC)

This example demonstrates how to secure an application deployed to JBoss EAP with OpenID Connect
(OIDC) without needing to use the Keycloak client adapter.

The OIDC configuration in this example is part of the deployment itself. Alternatively,
this configuration could be specified via the `elytron-oidc-client` subsystem instead.
For more details, take a look at the [documentation](https://docs.wildfly.org/26/Admin_Guide.html#Elytron_OIDC_Client).


### Usage

#### Set up your Azure Entra ID provider

Create a file src/main/webapp/WEB-INF/oidc.json with the following contents:

```

{
    "client-id" : "<<from azure>",
    "provider-url" : "<<from azure>",
    "ssl-required" : "EXTERNAL",
    "credentials" : {
        "secret" : "<<from azure>>"
     }
}
```

In the Azure portal, goto the "All Services" page and click on "Microsoft Entra ID"

https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/Overview

In the left hand menu, click on "App registrations"

Click on "New Registration"

Enter a name e.g. "jboss"

Click on "Register"

<image>

You will be brought to the App registrations overview page for your app.

Click on "Add a Redirect URI"

Click on "Add Platform"

Select "Web"

Enter the following url:  http://localhost:8080/simple-webapp-oidc/secured

Click on "Confiure"

Go back to the Overview page

Click on "Client Credentials"

Click on "New Client secret"

Enter a description e.g. eap

Click on "Add"

Copy the Value shown on the next page

Paste the copied value into src/main/webapp/WEB-INF/oidc.json as the secret value

Return the to Overview page and click on "Endpoints"

Copy the value from "OpenID Connect metadata document" and paste this into src/main/webapp/WEB-INF/oidc.json as the provider-url.  Note: remove the text "/.well-known/openid-configuration" 

Return to the Overview page

Copy the "Application (client) ID" paste this value in src/main/webapp/WEB-INF/oidc.json  as the "client-id"


#### Deploy the app to JBoss EAP

First, we're going to start our JBoss EAP

```
./bin/standalone.sh 
```

Then, we can deploy our app:

```
mvn wildfly:deploy 
```

#### Access the app

We can access our application using http://localhost:8080/simple-webapp-oidc/.

Click on "Access Secured Servlet".

Now, you'll be redirected to Azure Entra ID to log in. Log in eith your Azure credentials

Next, you'll be redirected back to our application and you should see the "Secured Servlet" page.

We were able to successfully log in to our application via the Azure Entra provider!

