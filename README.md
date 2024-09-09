# Homelab-Nix

<div align="center">
  <img src="./docs/assets/nix-logo.svg">
  <img src="./docs/">
</div>

Homelab configuration for the NixOS running on bare-metal hardware. We are using proxmox on top of NixOS as a virtualization platform and [terraform](https://github.com/Timotej979/homelab-terraform) to dynamicaly provision the VMs for the kubernetes clusters. Secrets management is done using Infisical secrets storage available in the cloud so we have a completely reporoducible infrastructure.

## Requirements

Installed NixOS on the bare-metal hardware.


# Setup


Requirements:
- Installed NixOS on the bare-metal hardware
- Set up of your Infisical account and secrets storage
- Create a [Infisical Machine Identity](https://infisical.com/docs/documentation/platform/identities/machine-identities) for your machine 
- Add [Environment Viewer Access](https://infisical.com/docs/documentation/platform/identities/universal-auth) to the machine identity
- Export the `INFISICAL_TOKEN` and `INFISICAL_PROJECT_ID` environment variables for the machine identity and your project
```bash
# --plain flag will output only the token, so it can be fed to an environment variable. --silent will disable any update messages
export INFISICAL_TOKEN=$(infisical login --method=universal-auth --client-id=<identity-client-id> --client-secret=<identity-client-secret> --silent --plain) .
export INFISICAL_PROJECT_ID=<project-id>
```
- 

