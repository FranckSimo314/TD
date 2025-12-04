# --- PARTIE 1 : LA CONFIGURATION (Question 1) ---

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = "polytech-dijon"  
  region  = "europe-west9"
  zone    = "europe-west9-a"

  credentials = file("student.json")
}

# --- PARTIE 2 : LE RÉSEAU (Question 2) ---

resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}


# --- PARTIE 3 : LA MACHINE VIRTUELLE (Question 3) ---

resource "google_compute_instance" "vm_instance" {
  count=2  #Creation de 2 VM
  name         = "my-terraform-instance-${count.index}" 
  machine_type = "e2-micro"              
  zone         = "europe-west9-a"        

  # Le disque dur avec le système d'exploitation
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  # La connexion au réseau (TRÈS IMPORTANT)
  network_interface {
    # Ici, on dit à la VM : "Connecte-toi au réseau qu'on a créé plus haut !"
    network = google_compute_network.vpc_network.name

    # Ce petit bloc vide permet d'avoir une adresse IP publique pour aller sur internet
    access_config {
    }
  }
}


# --- PARTIE 4 : LA BASE DE DONNÉES (Question 4) ---

resource "google_sql_database_instance" "db_instance" {
  name             = "my-database-instance-unique" # Change le nom si erreur (doit être unique au monde)
  database_version = "POSTGRES_14"                 # On choisit PostgreSQL
  region           = "europe-west9"                # Même région que le reste

  #  TRÈS IMPORTANT : Désactive la protection pour pouvoir supprimer l'exercice après
  deletion_protection = false 

  settings {
    # La plus petite taille possible (et la moins chère)
    tier = "db-f1-micro" 
    
    ip_configuration {
      # On active l'IP publique pour simplifier l'accès pour le TD
      ipv4_enabled = true 
    }
  }
}


# --- PARTIE 5 : LE DNS (Question 5) ---

# 1.  Création la zone DNS (Le carnet d'adresses privé)
resource "google_dns_managed_zone" "private_zone" {
  name        = "private-zone-td"
  dns_name    = "mondomaine.interne." 
  description = "Zone DNS privée pour le TD"
  
  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc_network.id
    }
  }
}

# 2. On crée l'enregistrement (La ligne dans le carnet)
resource "google_dns_record_set" "vm_record" {
  name         = "app.mondomaine.interne."
  type         = "A"                      
  ttl          = 300                       
  managed_zone = google_dns_managed_zone.private_zone.name

  
  rrdatas = [google_compute_instance.vm_instance[0].network_interface[0].network_ip]
}