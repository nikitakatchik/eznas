# EZNAS

EZNAS is a lightweight, Docker-based home NAS that exposes attached USB drives over SMB and MiniDLNA.

Prerequisites
- Docker (required)
- Avahi for mDNS/hostname discovery (recommended). Avahi is installed by default on many distributions, including Raspberry Pi OS Lite.

Quick start
1. Run the environment setup script and follow the prompts to create the required environment variables:

```
./envsetup
```

2. Start the services:

```
docker compose up -d
```

Once the services are running, attached USB devices should auto-mount and be available via SMB and DLNA.
