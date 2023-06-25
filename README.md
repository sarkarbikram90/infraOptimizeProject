Deployed a cluster of 3 VMs cluster on GCP using terraform.
The main.tf file includes configuration to deploy 3 VMs in us-central1-c zone with network interface, ubuntu 20.04 image.
Names 1 vm as master and the remaining 2 as worker-1 and worker-2
It includes firewall rules, ingress traffic to allow ssh, http and https
initialized terraform through terraform init
then terraform validate
then terraform plan
then terraform apply
