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

### 📊 **Dashboard**
- **Heimdall** (Application Dashboard): http://localhost:8082

## 🚀 **Quick Start**

1. **Media setup**: Visit http://localhost:8096 (Jellyfin)
   - Create admin account
   - Add media libraries

2. **Configure indexers**: Visit http://localhost:9696 (Prowlarr)
   - Add your preferred torrent/usenet indexers

3. **Set up downloaders**: Visit http://localhost:8080 (qBittorrent)
   - Default: `admin` / `adminadmin`

4. **Request interface**: Visit http://localhost:5055 (Jellyseerr)
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

- **Readarr**: Excluded due to architecture compatibility
- **VPN Gateway**: Removed (manage externally if needed)
- **Reverse Proxy**: Removed for simplified deployment
- **SSL/TLS**: Not configured for direct port access
- **Authentication**: Authelia available but optional for localhost access
- **Security**: Services accessible directly via ports for easier setup
