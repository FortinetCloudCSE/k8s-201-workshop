---
title: "Task 1 - Setup Azure CloudShell"
weight: 2
---



#### 1. **Setup your AzureCloud Shell**

* Login to Azure Cloud Portal [https://portal.azure.com/](https://portal.azure.com/) with the provided login/password

    ![cloudshell1](../images/cloudshell-01.jpg)
    ![cloudshell2](../images/cloudshell-02.jpg)

* Click the link "Skip for now (14 days until this is required)" do not click the "Next" button

    ![cloudshell3](../images/cloudshell-03.jpg)

* Click the "Next" button

    ![cloudshell4](../images/cloudshell-04.jpg)

* Click on Cloud Shell icon on the Top Right side of the portal

    ![cloudshell5](../images/cloudshell-05.jpg)

* Select **Bash**

    ![cloudshell6](../images/cloudshell-06.png)

* Click on **Mount Storage Account**

    ![cloudshell7](../images/cloudshell-07.png)
* Select
  * Storage Account Subscription - **Internal-Training**
  * Apply


* Click **Select existing Storage account**, Click Next

    ![cloudshell8](../images/cloudshell-08.png)

* in Select Storage account Step, 

   * Subscription: **Internal-Training**
   * Resource Group: Select the Resource group from the drop down: **K8sXX-K8s101-workshop**
   * Storage Account: Use existing storage account from dropdown.
   * File share: Use **cloudshellshare**
   * Click Select

    ![cloudshell9](../images/cloudshell-09.png)

 {{< notice warning >}} Please make sure to use the existing ones. you wont be able to create any Resource Group or Storage account
  {{< /notice >}}  

* After 1-2 minutes, You should now have access to Azure Cloud Shell console

    ![cloudshell10](../images/cloudshell-10.png)