# versanode-os-usermods — pi-gen stage (stage9-usermods)

Installs nginx-light, Docker, Cockpit (from backports), removes Podman/VM stacks,
installs cockpit-vncp-manager, and deploys a generator script + systemd timer to
refresh nginx reverse-proxy config every 15s.

Place at: `pi-gen/stage9-usermods/` and include as the last stage before export-image.
