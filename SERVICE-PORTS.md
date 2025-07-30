# Media Server Stack - Service Ports

## 🌐 Access URLs (Direct Port Access)

All services are accessible directly via ports without domain setup:

### 🎥 **Media Services**
- **Jellyfin** (Media Server): http://localhost:8096 (klair/pinku1)
- **Jellyseerr** (Request Management): http://localhost:5055

### 🔧 **Management Applications**
- **Prowlarr** (Indexer Manager): http://localhost:9696
- **Radarr** (Movie Manager): http://localhost:7878
- **Sonarr** (TV Show Manager): http://localhost:8989
- **Lidarr** (Music Manager): http://localhost:8686
- **Bazarr** (Subtitle Manager): http://localhost:6767

### 📥 **Download & Processing**
- **qBittorrent** (Download Client): http://localhost:8080
- **Flaresolverr** (Cloudflare Bypass): http://localhost:8191

### 🔒 **Security & Infrastructure**
- **Authelia** (2FA Authentication): http://localhost:9091
- **Traefik** (Reverse Proxy): http://localhost:8091
- **Traefik Dashboard** (Admin Panel): http://localhost:8090

### 📊 **Dashboard**
- **Heimdall** (Application Dashboard): http://localhost:8082

## 🚀 **Quick Start**

1. **First-time setup**: Visit http://localhost:9091 (Authelia)
   - Default: `admin` / `admin123` ⚠️ **CHANGE IMMEDIATELY**

2. **Media setup**: Visit http://localhost:8096 (Jellyfin)
   - Create admin account
   - Add media libraries

3. **Configure indexers**: Visit http://localhost:9696 (Prowlarr)
   - Add your preferred torrent/usenet indexers

4. **Set up downloaders**: Visit http://localhost:8080 (qBittorrent)
   - Default: `admin` / `adminadmin`

5. **Request interface**: Visit http://localhost:5055 (Jellyseerr)
   - Connect to Jellyfin and *arr applications

## 🔧 **Service Configuration Order**

1. **Prowlarr** → Add indexers
2. **qBittorrent** → Configure download paths
3. **Radarr/Sonarr/Lidarr** → Add indexers from Prowlarr
4. **Bazarr** → Connect to Radarr/Sonarr
5. **Jellyfin** → Set up media libraries
6. **Jellyseerr** → Connect to Jellyfin and *arr apps

## 📋 **Default Credentials**

| Service | Username | Password |
|---------|----------|----------|
| Authelia | admin | admin123 |
| qBittorrent | admin | adminadmin |
| Others | N/A | Setup required |

⚠️ **Security Note**: Change all default passwords immediately after first login!

## 🛠️ **Management Commands**

```bash
# Check status
docker-compose ps

# View logs
docker-compose logs [service-name]

# Restart service
docker-compose restart [service-name]

# Stop all services
./stop.sh

# Start all services
./start.sh
```

## 📝 **Notes**

- **VPN**: Currently disabled (requires real VPN credentials)
- **Readarr**: Excluded due to architecture compatibility
- **SSL**: Available via Traefik but not configured for direct port access
- **Authentication**: Available via Authelia but not enforced on direct ports
