locals {
  access_apps = {
    argocd = {
      hostname                  = "argocd"
      auto_redirect_to_identity = true
    }
    grafana = {
      hostname                  = "grafana"
      auto_redirect_to_identity = true
    }
    longhorn = {
      hostname                  = "longhorn"
      auto_redirect_to_identity = true
    }
    prometheus = {
      hostname                  = "prometheus"
      auto_redirect_to_identity = true
    }
    ssh-inspiron = {
      hostname                  = "inspiron"
      auto_redirect_to_identity = false
    }
    ssh-optiplex = {
      hostname                  = "optiplex"
      auto_redirect_to_identity = true
    }
    ssh-thinkcentre = {
      hostname                  = "thinkcentre"
      auto_redirect_to_identity = false
    }
  }

  tunnels = {
    ingress     = "homelab-k8s"
    inspiron    = "ssh-inspiron"
    optiplex    = "ssh-optiplex"
    thinkcentre = "ssh-thinkcentre"
  }

  ssh_ingress = {
    inspiron = [
      {
        hostname = "inspiron.${var.zone_name}"
        service  = "ssh://localhost"
      },
      {
        hostname       = "kube.${var.zone_name}"
        service        = "tcp://127.0.0.1:16443"
        origin_request = {}
      },
      {
        service = "http_status:404"
      }
    ]
    optiplex = [
      {
        hostname = "optiplex.${var.zone_name}"
        service  = "ssh://localhost"
      },
      {
        service = "http_status:404"
      }
    ]
    thinkcentre = [
      {
        hostname = "thinkcentre.${var.zone_name}"
        service  = "ssh://localhost"
      },
      {
        service = "http_status:404"
      }
    ]
  }

  dns_routes = {
    argocd      = "ingress"
    grafana     = "ingress"
    inspiron    = "inspiron"
    kube        = "inspiron"
    longhorn    = "ingress"
    optiplex    = "optiplex"
    prometheus  = "ingress"
    thinkcentre = "thinkcentre"
  }
}
