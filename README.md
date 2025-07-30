# 🎬 Media Server Stack

A comprehensive, secure, and automated media server setup featuring Jellyfin, the complete *arr suite, direct port access, and optional VPN protection with 2FA authentication.

## 🚀 Quick Start

```bash
# 1. Clone or download this repository
git clone <repository-url>
cd media-center

# 2. Configure environment (optional - works with defaults)
cp .env.example .env
nano .env  # Update VPN settings if needed

# 3. Start the stack
./start.sh

# 4. Access your services directly
open http://localhost:8096  # Jellyfin
open http://localhost:8080  # qBittorrent (admin/adminadmin)
```

## 📋 What's Included

### 🎥 Media Services
- **[Jellyfin](https://jellyfin.org/)** - Free media server with hardware transcoding
- **[Jellyseerr](https://github.com/Fallenbagel/jellyseerr)** - Request management for users

### 🔍 Content Management (*arr Suite)
- **[Prowlarr](https://prowlarr.com/)** - Indexer manager (replaces Jackett)
- **[Radarr](https://radarr.video/)** - Movie collection manager
- **[Sonarr](https://sonarr.tv/)** - TV show collection manager  
- **[Lidarr](https://lidarr.audio/)** - Music collection manager
- **[Readarr](https://readarr.com/)** - Book collection manager
- **[Bazarr](https://www.bazarr.media/)** - Subtitle manager

### 📥 Download & Processing
- **[qBittorrent](https://www.qbittorrent.org/)** - Torrent client (VPN optional)
- **[Unpackerr](https://github.com/Unpackerr/unpackerr)** - Automated extraction
- **[Flaresolverr](https://github.com/FlareSolverr/FlareSolverr)** - Cloudflare bypass

### 🔒 Security & Infrastructure
- **[Gluetun](https://github.com/qdm12/gluetun)** - VPN container for secure downloads
- **[Traefik](https://traefik.io/)** - Reverse proxy with automatic SSL
- **[Authelia](https://www.authelia.com/)** - 2FA authentication & authorization
- **[Heimdall](https://heimdall.site/)** - Application dashboard

## 🛠️ Prerequisites

### System Requirements
- **OS**: Linux (recommended), macOS, or Windows with WSL2
- **CPU**: Intel i5-2300 / AMD FX-8100 or better
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 100GB for system + storage for your media
- **Network**: Gigabit Ethernet recommended

### Software Requirements
- **Docker** 20.10+ and **Docker Compose** 2.0+
- **Git** (for cloning repository)
- Text editor (nano, vim, VS Code, etc.)

### GPU Requirements (Recommended for Jellyfin Transcoding)
- **Intel**: 7th gen+ processors with Quick Sync, or Arc GPUs
- **NVIDIA**: GTX 1660 / RTX 20xx series or newer
- **AMD**: Not recommended for transcoding

## 📁 Directory Structure

```
media-center/
├── config/                 # Service configurations
│   ├── jellyfin/          # Jellyfin config & metadata
│   ├── *arr/              # *arr application configs
│   ├── traefik/           # Reverse proxy config
│   └── authelia/          # Authentication config
├── data/                   # Media and downloads
│   ├── torrents/          # Download staging area
│   │   ├── movies/        # Movie downloads
│   │   ├── tv/            # TV show downloads
│   │   ├── music/         # Music downloads
│   │   └── books/         # Book downloads
│   └── media/             # Final organized media
│       ├── movies/        # Movie library
│       ├── tv/            # TV library
│       ├── music/         # Music library
│       └── books/         # Book library
├── docker-compose.yml     # Main stack definition
├── .env                   # Environment configuration
└── *.sh                   # Management scripts
```

## ⚙️ Configuration

### 1. Environment Setup

Copy the example environment file and customize:

```bash
cp .env.example .env
nano .env
```

**Critical settings to update:**

```bash
# Domain configuration
DOMAIN=your-domain.com
EMAIL=your-email@domain.com

# VPN settings (required for secure downloads)
VPN_SERVICE_PROVIDER=your-vpn-provider
OPENVPN_USER=your-vpn-username
OPENVPN_PASSWORD=your-vpn-password

# Security secrets (generate random strings)
AUTHELIA_JWT_SECRET=your-random-jwt-secret
AUTHELIA_SESSION_SECRET=your-random-session-secret
AUTHELIA_STORAGE_ENCRYPTION_KEY=your-random-encryption-key
```

### 2. Service Access

**Direct Port Access (Default)**
All services are accessible directly via localhost ports:

```
Jellyfin (Media Server):      http://localhost:8096
Jellyseerr (Requests):        http://localhost:5055
Prowlarr (Indexers):          http://localhost:9696
Radarr (Movies):              http://localhost:7878
Sonarr (TV Shows):            http://localhost:8989
Lidarr (Music):               http://localhost:8686
Bazarr (Subtitles):           http://localhost:6767
qBittorrent (Downloads):      http://localhost:8080
Authelia (Authentication):    http://localhost:9091
Traefik (Reverse Proxy):      http://localhost:8091
Traefik Dashboard:            http://localhost:8090
Heimdall (Dashboard):         http://localhost:8082
Flaresolverr (CF Bypass):     http://localhost:8191
```

**Domain Access (Advanced)**
For domain-based access, configure DNS to point your domain and subdomains to your server's IP address.

### 3. VPN Configuration (Optional)

VPN protection is available but disabled by default for easier setup.

**To Enable VPN:**
1. **Choose a supported VPN provider** from [Gluetun's list](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers)
2. **Update `.env` file**:
   ```bash
   ENABLE_VPN=true
   VPN_SERVICE_PROVIDER=your-provider
   OPENVPN_USER=your-username
   OPENVPN_PASSWORD=your-password
   ```
3. **Download config files** (if required) to `config/gluetun/`
4. **Restart services**: `./stop.sh && ./start.sh`

Popular providers: NordVPN, ExpressVPN, Surfshark, PIA, Mullvad, ProtonVPN

## 🚀 Deployment

### Phase 1: Infrastructure
```bash
# Start core services first
./start.sh
```

The startup script will:
1. ✅ Validate configuration
2. 🔧 Create directory structure  
3. 🚀 Start services in proper order
4. 🔍 Verify VPN connectivity
5. 📋 Display access URLs

### Phase 2: Initial Setup

After services start, configure each application:

#### 1. Jellyfin (Media Server)
- **URL**: http://localhost:8096
- Create admin account
- Add media libraries pointing to `/media/*` folders
- Enable hardware transcoding if GPU available

#### 2. Prowlarr (Indexer Manager)
- **URL**: http://localhost:9696
- Add indexers (torrent sites, Usenet providers)
- Configure Flaresolverr if needed for Cloudflare-protected sites

#### 3. *arr Applications
Configure each application with:
- **Radarr** (Movies): http://localhost:7878
- **Sonarr** (TV): http://localhost:8989  
- **Lidarr** (Music): http://localhost:8686
- **Bazarr** (Subtitles): http://localhost:6767
- **Readarr** (Books): Not included (architecture compatibility issues)
- **Root folders**: Point to appropriate `/media/*` directories
- **Download client**: qBittorrent (http://qbittorrent:8080)
- **Indexers**: Connect to Prowlarr
- **Quality profiles**: Set desired quality standards

#### 4. qBittorrent (Download Client)
- **URL**: http://localhost:8080
- **Default**: `admin` / `adminadmin`
- Configure download categories and paths
- ⚠️ **No VPN protection by default** - enable in `.env` if needed

#### 5. Jellyseerr (Request Management)
- **URL**: http://localhost:5055
- Connect to Jellyfin server
- Connect to Radarr and Sonarr
- Configure user permissions

## 🔒 Security Features

### Authentication & Authorization (Optional)
- **2FA Authentication** via Authelia (disabled for localhost access)
- **Direct port access** without authentication for easier setup
- **Domain-based authentication** available but not configured for localhost

### Network Security
- **Optional VPN Protection** for download traffic (disabled by default)
- **Reverse proxy** with automatic SSL certificates (Traefik)
- **Network isolation** between service groups
- **Security headers** and modern TLS configuration

### Data Protection
- **Encrypted storage** for authentication data
- **Environment-based secrets** management
- **Regular automated backups** with retention policies
- **Proper file permissions** and user isolation

## 🛠️ Management

### Daily Operations
```bash
# Check status
docker-compose ps

# View logs
docker-compose logs -f jellyfin

# Restart service
docker-compose restart radarr

# Update all services
./update.sh
```

### Backup & Restore
```bash
# Create backup (configs only)
./backup.sh

# Create full backup (includes media)
./backup.sh --include-media

# Backup with custom retention
./backup.sh --retention 60
```

### Maintenance
```bash
# Update all containers
./update.sh --restart

# Stop everything
./stop.sh

# Complete cleanup (removes all data!)
./stop.sh --full
```

## 📊 Monitoring & Troubleshooting

### Health Checks
- **Service status**: `docker-compose ps`
- **Resource usage**: `docker stats`
- **Service logs**: `docker-compose logs [service]`

### Common Issues

**Service Not Accessible**
```bash
# Check if service is running
docker-compose ps

# Check service logs
docker-compose logs [service-name]

# Restart specific service
docker-compose restart [service-name]
```

**Port Conflicts**
```bash
# Check what's using a port
ss -tlnp | grep :8096

# Change port in docker-compose.yml if needed
```

**VPN Issues (if enabled)**
```bash
# Check VPN status
docker exec gluetun wget -qO- ifconfig.me

# View VPN logs
docker-compose logs gluetun
```

**Permission Problems**
```bash
# Fix ownership
chown -R 1000:1000 config data

# Fix permissions
chmod -R 755 config data
chmod 600 config/traefik/acme.json
```

### Log Locations
- **Service logs**: `docker-compose logs [service]`
- **Application logs**: `config/[service]/logs/`
- **Traefik access logs**: `config/traefik/access.log`

## 🔧 Customization

### Adding Services
1. Add service definition to `docker-compose.yml`
2. Create configuration directory
3. Add Traefik labels for routing
4. Update firewall/security rules if needed

### Custom Domains
1. Update `DOMAIN` in `.env`
2. Update Authelia configuration
3. Update Traefik rules
4. Obtain new SSL certificates

### Performance Tuning
- **GPU Transcoding**: Configure device passthrough
- **Storage**: Use SSD for transcoding cache
- **Network**: Optimize Docker networks
- **Resources**: Set memory/CPU limits

## 🆘 Support & Contributing

### Getting Help
1. **Check logs**: `docker-compose logs [service]`
2. **Review documentation**: Each service has detailed docs
3. **Community forums**: Reddit, Discord communities
4. **GitHub issues**: For bugs and feature requests

### Contributing
1. Fork the repository
2. Create a feature branch
3. Test changes thoroughly
4. Submit pull request with description

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Jellyfin Team** - Free and open-source media server
- **Servarr Team** - The excellent *arr application suite
- **Traefik Team** - Modern reverse proxy solution
- **Authelia Team** - Comprehensive authentication solution
- **Community Contributors** - Documentation, testing, and feedback

---

## 📋 Service Status

### ✅ **Included & Working**
- **Jellyfin** - Media streaming server
- **Jellyseerr** - Request management interface  
- **Prowlarr** - Indexer manager
- **Radarr** - Movie collection manager
- **Sonarr** - TV show collection manager
- **Lidarr** - Music collection manager
- **Bazarr** - Subtitle manager
- **qBittorrent** - Download client
- **Flaresolverr** - Cloudflare bypass
- **Unpackerr** - Automated extraction
- **Authelia** - 2FA authentication (optional)
- **Traefik** - Reverse proxy
- **Heimdall** - Application dashboard

### ⚠️ **Excluded/Optional**
- **Readarr** - Excluded (architecture compatibility issues)
- **VPN Protection** - Disabled by default (enable in `.env`)
- **Domain-based access** - Available but not configured for localhost
- **Authelia** - Authentication disabled for direct port access

## 🚨 Important Security Notes

1. **Change default passwords** immediately after setup:
   - qBittorrent: `admin` / `adminadmin`
   - Other services: Setup required on first access
2. **Enable VPN** for download activities (update `.env`)
3. **Keep services updated** regularly with `./update.sh`
4. **Monitor logs** for suspicious activity
5. **Backup configurations** regularly with `./backup.sh`
6. **Limit external access** when exposing ports externally

## 📚 Additional Resources

- **Service Ports**: See `SERVICE-PORTS.md` for complete port listing
- **Implementation Plan**: See `MEDIA-SERVER-PLAN.md` for detailed planning
- **Configuration Examples**: Check `config/` directory for sample configs
- **Management Scripts**: Use `start.sh`, `stop.sh`, `update.sh`, `backup.sh`

**Happy streaming! 🍿**