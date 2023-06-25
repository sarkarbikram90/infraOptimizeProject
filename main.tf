## Define provider configuration
provider "google" {
  credentials = file("C:\\Users\\bikrams\\SA\\infraproject-390421-255caa8a89e4.json") ## Service Account key path
  project     = "infraproject-390421"
  region      = "us-central1"
}

## Create static IPs for VM instances
resource "google_compute_address" "static_ips" {
  count  = 3
  name   = "static-ip-${count.index}"
  region = "us-central1"
}

## 1 master and 2 workers node

locals {
  instance_names = [
    "master",
    "worker-1",
    "worker-2"
  ]
}

## Create three VM instances
resource "google_compute_instance" "vms" {
  count        = 3
  name         = local.instance_names[count.index] 
  machine_type = "n2-standard-2" ## Machine type
  zone         = "us-central1-c" ## Deployment zone

  

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  ## Define startup script in the metadata block
  metadata = {
    startup-script = <<-EOF
      sudo apt-get update
      ## Install Docker
      sudo wget https://raw.githubusercontent.com/lerndevops/labs/master/scripts/installDocker.sh -P /tmp
      sudo chmod 755 /tmp/installDocker.sh
      sudo bash /tmp/installDocker.sh
      sudo systemctl restart docker.service

      ## Install CRI-Docker
      sudo wget https://raw.githubusercontent.com/lerndevops/labs/master/scripts/installCRIDockerd.sh -P /tmp
      sudo chmod 755 /tmp/installCRIDockerd.sh
      sudo bash /tmp/installCRIDockerd.sh
      sudo systemctl restart cri-docker.service

      ## Install kubeadm, kubelet, kubectl
      sudo wget https://raw.githubusercontent.com/lerndevops/labs/master/scripts/installK8S.sh -P /tmp
      sudo chmod 755 /tmp/installK8S.sh
      sudo bash /tmp/installK8S.sh
    EOF
  }

  ## Define network interface for static IPs
  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.static_ips[count.index].address
    }
  }
}

## Create firewall rules to allow SSH, HTTP, and HTTPS traffic
resource "google_compute_firewall" "ssh" {
  name        = "allow-ssh"
  network     = "default"
  direction   = "INGRESS"
  target_tags = ["allow-ssh"]

  source_tags = ["allow-ssh"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "http" {
  name        = "allow-http"
  network     = "default"
  direction   = "INGRESS"
  target_tags = ["allow-http"]

  source_tags = ["allow-http"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "https" {
  name        = "allow-https"
  network     = "default"
  direction   = "INGRESS"
  target_tags = ["allow-https"]

  source_tags = ["allow-https"]

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

## Define the health check
resource "google_compute_http_health_check" "health_check" {
  name               = "my-health-check"
  check_interval_sec = 5
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 2
  request_path       = "/"
}


## Define the backend service
resource "google_compute_backend_service" "backend_service" {
  name       = "my-backend-service"
  port_name  = "http"
  protocol   = "HTTP"
  
  backend {
    group   = google_compute_instance_group.vm_group.self_link
    balancing_mode = "UTILIZATION" # This line to set the balancing mode
  }

  health_checks = [
    google_compute_http_health_check.health_check.self_link
  ]
     
}

## Define the instance group
resource "google_compute_instance_group" "vm_group" {
  name      = "my-vm-group"
  zone      = "us-central1-c"
  instances = google_compute_instance.vms.*.self_link
}

## Define the URL map
resource "google_compute_url_map" "url_map" {
  name            = "my-url-map"
  default_service = google_compute_backend_service.backend_service.self_link
}

## Define the target HTTP proxy
resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "my-http-proxy"
  url_map = google_compute_url_map.url_map.self_link
}

## Define the global forwarding rule
resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name       = "my-forwarding-rule"
  target     = google_compute_target_http_proxy.http_proxy.self_link
  port_range = "80"
}