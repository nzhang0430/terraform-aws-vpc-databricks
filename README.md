# Create AWS VPC; Webserver in Public subnet, database in provite Subnet
# create Databricks in provite subnet , build ALB for webaccess autoscaling and internet G/W




## Introduction

The module provisions the following resources:

•	  Create AWS VPC 

• 	Create two public subnets and two private subnets.

•	 Launch two web servers in the public subnets. 

•	 Set up an Auto Scaling group to scale up to 10 instances.

• 	Create an Application Load Balancer (ALB) for the web servers.

• 	Set up a backend PostgreSQL database in a private subnet that can connect to the web servers in the public subnet.

• 	Create an Application Load Balancer (ALB) for the web servers.

• 	First, you need to set up the required provider and resources for Databricks. Add the following configuration to your Terraform script.

# Deploying the Configuration
* terraform init
* terraform validate
* terraform apply -f main.tf
