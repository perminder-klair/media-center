# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### Stack Management

- **Start stack**: `./start.sh` - Starts all services in phases (infrastructure → media → management → downloads → dashboard)
- **Stop stack**: `./stop.sh` - Stops all services gracefully
- **Update stack**: `./update.sh` - Updates all container images and restarts services
- **Backup configs**: `./backup.sh` - Creates backup of configuration files only
- **Full backup**: `./backup.sh --include-media` - Backs up configs and media files

### Development & Debugging

- **View all services**: `docker-compose ps`
- **View service logs**: `docker-compose logs -f [service-name]`
- **Restart single service**: `docker-compose restart [service-name]`
- **Fix permissions**: `chown -R 1000:1000 config data && chmod -R 755 config data`

### Configuration

- **Environment setup**: Copy `.env.example` to `.env` and configure
- **Service access**: All services available via direct ports (see SERVICE-PORTS.md)

## Architecture Overview

### Docker Compose Structure

- **Networks**: Segregated networks (media_network) for service communication
- **Services**: 13 containerized services with dependency management and health checks
- **Volumes**: Persistent storage for configs (`./config/`) and media data (`./data/`)

### Service Categories

1. **Infrastructure**: Authelia (2FA auth)
2. **Media Core**: Jellyfin (streaming server), Jellyseerr (request management)
3. **Content Management**: Prowlarr, Radarr, Sonarr, Lidarr, Readarr, Bazarr (*arr suite)
4. **Downloads**: qBittorrent (torrent client), Flaresolverr (Cloudflare bypass), Unpackerr (extraction)
5. **Dashboard**: Heimdall (application launcher)

### Key Technical Details

- **User/Group IDs**: Uses PUID/PGID (1000:1000) for consistent file permissions
- **Authentication**: Authelia provides 2FA for enhanced security
- **Data Flow**: Downloads → Processing → Organization → Streaming

### Configuration Files

- **Main**: `docker-compose.yml` (service definitions), `.env` (environment variables)
- **Service configs**: Individual service configurations in `./config/[service]/`
- **Traefik**: Dynamic routing rules in `./config/traefik/dynamic/`
- **Authelia**: Authentication settings in `./config/authelia/configuration.yml`

### Directory Structure

```
./config/           # Service configurations & databases
./data/
├── torrents/       # Download staging (movies, tv, music, books)
└── media/          # Final organized media library
```

### Port Mappings

- **Media Services**: Jellyfin (8096), Jellyseerr (5055)
- **Content Management**: Prowlarr (9696), Radarr (7878), Sonarr (8989), Lidarr (8686), Bazarr (6767)
- **Download & Utilities**: qBittorrent (8080), Flaresolverr (8191)
- **Dashboard & Auth**: Heimdall (8082), Authelia (9091)

### Security Features

- Network segmentation for service isolation
- 2FA authentication via Authelia
- Environment-based secrets management
- Direct port access with configurable authentication

## Development Notes

- Services start in dependency order managed by the start script
- Health checks ensure service availability before marking as ready
- Log aggregation available through Docker Compose logs
- Permission management critical for media file access across containers
