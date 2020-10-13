provider "google" {
  version = "3.5.0"

  credentials = file("credentials.json")

  project = "project-id"
  region  = "us-central1"
  zone    = "us-central1-c"

}

# Create a VPC
resource "google_compute_network" "dev-vpc" {
  name = "dev-vpc"
  auto_create_subnetworks = "false"
}

# Create Subnets
resource "google_compute_subnetwork" "pub-subnet" {
  count      = length(var.subnet_cidr)  
  name          = "public-subnet-${count.index+1}"
  ip_cidr_range = var.subnet_cidr[count.index]
  region        = var.region
  network       = google_compute_network.dev-vpc.id
  depends_on    = ["google_compute_network.dev-vpc"]

}

# Create a Firewall for Network
resource "google_compute_firewall" "dev-vpc-firewall" {
  name    = "dev-vpc-firewall"
  network = google_compute_network.dev-vpc.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["80", "8080", "22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Create a Instance
resource "google_compute_instance" "webserver" {
  count     = var.server_count  
  name      = "webserver-${count.index+1}"
  machine_type = "f1-micro"
  zone      = var.zones[count.index]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }
  
  metadata_startup_script = "sudo apt-get update && sudo apt-get install -y nginx"

  network_interface {
    network = google_compute_network.dev-vpc.name
    subnetwork = google_compute_subnetwork.pub-subnet[count.index].name
  }

}

# Create a Health Check
resource "google_compute_http_health_check" "nlb-hc" {
    name               = "nlb-health-checks"
    request_path       = "/"
    port               = 80
    check_interval_sec = 10
    timeout_sec        = 3
}

# Create a Load Balancer Target Group
resource "google_compute_target_pool" "nlb-target-pool" {
    #count         = var.server_count 
    name          = "nlb-target-pool"
    region        = var.region

    /*instances = [
        "${google_compute_instance.webserver.*.self_link}"
    ]*/

    instances = [
      "us-central1-a/webserver1",
      "us-central1-b/webserver2",
    ]

    health_checks = [
        google_compute_http_health_check.nlb-hc.name
    ]
}

# Create A Network Load balancer
resource "google_compute_forwarding_rule" "dev-load-balancer" {
    count         = var.server_count
    name          = "nlb-dev"
    region        = var.region
    network       = google_compute_network.dev-vpc.id
    subnetwork    = google_compute_subnetwork.pub-subnet[count.index].id
    target        = "${google_compute_target_pool.nlb-target-pool.id}"
    port_range    = "80"
    ip_protocol   = "TCP"
    load_balancing_scheme = "INTERNAL"
}