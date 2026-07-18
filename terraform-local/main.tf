terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube" # Saying "We are going to be talking to a minikube cluster"
}

# This is what makes and manages our containers
resource "kubernetes_deployment_v1" "web_deployment" {
  metadata {
    name = "coolest-web-pods-ever" # making a fun name to show I can
    labels = {
      app = "static-web" # making a serious easy to query label
    }
  }

  spec {
    replicas = 2 # we want 2 copies of this running all the time

    # like a baby deers scent this tells mama deployment deer this is her own
    selector {
      match_labels = {
        app = "static-web"
      }
    }

    template {
      metadata {
        labels = {
          app = "static-web"
        }
      }

      spec {
        container {
          name  = "web-container"
          image = "static-web-app:v2"

          image_pull_policy = "Never" # this is important so we don't try to query the docker registry for image thats not there. my guess is in the future this will pull from ECR
          port {
            container_port = 80
          }

          resources {
             # A request is saying this is the bare minimum avaliable needed resources to run something on this pod 
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            # A limit is saying the max amount of resources this pod can use before it gets killed with an out of memory error
            limits = {
              cpu = "500m"
              memory = "256Mi"
            }
          }
        }
      }
    }


  }



}


# This is what makes the service so we can have an exposed port for our container. Also is our load balancer
resource "kubernetes_service_v1" "web_service_local" {
  metadata {
    name = "web-service"
  }

  spec {
    selector = {
      app = "static-web"
    }
    type = "NodePort"
    port {
      #node_port = 30201 if I don't set this will it pick a random port?
      port        = 8080 # This is fine to be whatever I wanna hit
      target_port = 80   # This has to be 80 because thats what the web server is listening on
    }
  }

}