# proxmox-scripts - what's this?
Scripts that setup various LXCs. For proxmox, for learning, for fun.

## Whoogle
[Whoogle Search](https://github.com/benbusby/whoogle-search) is a privacy-oriented search engine. Shows Google search results, but without any ads, javascript, AMP links, cookies, or IP address tracking.

This setup only uses 1.5 MiB RAM and 115 MiB on disk. No root password, syslog is disabled.
#### Installation instructions
Look at the code first, don't execute random scripts on your machines.  
Open a shell on your PVE host and run the command below.  
`bash -c "$(wget -qLO - https://raw.githubusercontent.com/jniggemann/proxmox-scripts/main/alpine-whoogle.bash)"`
