# versanode-os-usermods — pi-gen stage (stage9-usermods)

This is a **drop-in pi-gen stage** that installs Cockpit (from Debian backports),
removes Podman/VM tooling, and installs the cockpit-vncp-manager plugin.

Place at:
  pi-gen/stage9-usermods/

Ensure `stage9-usermods` is the last stage in STAGE_LIST.
