provider "google" {
  project     = "projet1-241907"
  credentials = "${file("projet1-241907-ed1b75888995.json")}"
  region      = "us-central1"
  zone        = "us-central1-c"
}

resource "google_compute_network" "network" {
  name                    = "vnet"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet1" {
  name          = "subnet1"
  ip_cidr_range = "10.0.0.0/16"
  region        = "us-central1"
  network       = "${google_compute_network.network.name}"
}

resource "google_compute_subnetwork" "subnet2" {
  name          = "subnet-nods"
  ip_cidr_range = "172.20.0.0/16"
  region        = "us-central1"
  network       = "${google_compute_network.network.name}"

  secondary_ip_range {
    range_name    = "range-pods"
    ip_cidr_range = "10.200.0.0/16"
  }

  secondary_ip_range {
    range_name    = "range-services"
    ip_cidr_range = "192.168.10.0/27"
  }
}

resource "google_compute_firewall" "firewall" {
  name    = "firewall"
  network = "${google_compute_network.network.name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["foo"]
}

resource "google_compute_firewall" "firewall1" {
  name    = "firewall1"
  network = "${google_compute_network.network.name}"

  // subnetwork = "subnet-nods"
  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["too"]
}

resource "google_compute_instance" "instance" {
  name         = "machine"
  machine_type = "n1-standard-1"
  zone         = "us-central1-a"
  tags         = ["foo"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1604-lts"
      size  = "30"
      type  = "pd-standard"
    }

    auto_delete = true
  }

  network_interface {
    network       = "${google_compute_network.network.name}"
    subnetwork    = "${google_compute_subnetwork.subnet1.name}"
    access_config = {}
  }

  metadata {
    ssh-keys = "root:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "google_container_cluster" "primary" {
  name     = "tf-gke-helm"
  location = "us-central1-a"

  remove_default_node_pool = true
  initial_node_count       = 1

  // min_master_version = "${data.google_container_engine_versions.default.latest_master_version}"
  network = "${google_compute_network.network.name}"

  subnetwork = "${google_compute_subnetwork.subnet2.name}"

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "10.0.0.0/16"
      display_name = "net1"
    }
  }

  // subnetwork = "subnet-nods"

  ip_allocation_policy {
    cluster_secondary_range_name  = "range-pods"
    services_secondary_range_name = "range-services"
  }
  private_cluster_config {
    enable_private_endpoint = true
    enable_private_nodes    = true
    master_ipv4_cidr_block  = "192.168.128.0/28"
  }
}

resource "google_container_node_pool" "primary_pool" {
  name       = "primary-pool"
  location   = "us-central1-a"
  cluster    = "${google_container_cluster.primary.name}"
  node_count = "2"

  // subnetwork     = "${google_compute_subnetwork.subnet2.name}"
  node_config {
    machine_type = "n1-standard-1"
  }
}
