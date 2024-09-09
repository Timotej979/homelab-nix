# /etc/nixos/configuration.nix
{ config, pkgs, lib, ... }:

{
  # Existing auto-upgrade configuration
  system.autoUpgrade = {
    enable = true;
    small = false;
    systemdServices = {
      "nixos-upgrade" = {
        timerConfig.OnCalendar = "Sun *-*-* 02:00:00";
        timerConfig.RandomizedDelaySec = "30min";
      };
    };
  };

  services.nix-daemon.enable = true;
  nix.gc.automatic = true;

  # Install required packages
  environment.systemPackages = with pkgs; [
    git
    terraform
    proxmox-backup-client
    infisical
    (terraform.withPlugins (p: [ p.terraform-providers.proxmox ]))
  ];

  # Custom systemd service to fetch secrets from Infisical securely
  systemd.services.infisical-fetch-secrets = {
    description = "Fetch secrets from Infisical and store them in environment file";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ]; # Ensure the network is up
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "/etc/infisical-token.env"; # Load Infisical token from environment file
      ExecStart = "${pkgs.bash}/bin/bash -c '\
        # Check if the infisical machine identity token is set
        if [ -z \"$INFISICAL_TOKEN\" ]; then \
          echo \"ERROR: Infisical machine identity token is not set. Please set it as an environment variable.\"; \
          exit 1; \
        fi; \
        # CHeck if the infisical project ID is set
        if [ -z \"$INFISICAL_PROJECT_ID\" ]; then \
          echo \"ERROR: Infisical project ID is not set. Please set it as an environment variable.\"; \
          exit 1; \
        fi;
        # Create the file
        touch /etc/prod-env/infisical.env; \
        # Fetch the secrets
        infisical export --projectId $INFISICAL_PROJECT_ID --env=prod --format dotenv > /etc/prod-env/infisical.env; \
        # Secure the environment file by setting strict permissions
        chmod 600 /etc/infisical.env; \
      '";
      User = "root";
    };
  };

  # Load environment file from Infisical securely
  systemd.services."environment" = {
    description = "Load environment secrets from Infisical";
    wantedBy = [ "multi-user.target" ];
    after = [ "infisical-fetch-secrets.service" ]; # Ensure fetching secrets happens first
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'set -a; source /etc/infisical.env; set +a'";
      RemainAfterExit = true;
      User = "root";
    };
  };

  # Service to clone or pull the homelab-terraform repository
  systemd.services.homelab-terraform-clone = {
    description = "Clone or update homelab-terraform repository from GitHub";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ]; # Ensure the network is up
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.git}/bin/git -C /etc/homelab-terraform pull || ${pkgs.git}/bin/git clone https://github.com/Timotej979/homelab-terraform.git /etc/homelab-terraform";
      User = "root";
    };
  };

  # Service to apply Terraform configuration
  systemd.services.terraform-proxmox-apply = {
    description = "Apply Terraform configuration for Proxmox";
    wantedBy = [ "multi-user.target" ];
    after = [ "homelab-terraform-clone.service" ]; # Run after cloning or pulling the repo
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/etc/homelab-terraform";
      ExecStart = "${pkgs.terraform}/bin/terraform init && ${pkgs.terraform}/bin/terraform apply -auto-approve";
      User = "root";
    };
  };

  # Timer to run the Terraform apply service weekly at 4 AM on Sunday
  systemd.timers.terraform-proxmox-apply = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "Sun *-*-* 04:00:00"; # Run weekly at 4 AM after system upgrade
    service = "terraform-proxmox-apply.service";
  };






  # Enable SSH access
  services.openssh.enable = true;

  nixpkgs.config.allowUnfree = true;
}
