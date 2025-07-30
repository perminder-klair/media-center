# 🎬 Media Server Stack

A comprehensive, secure, and automated media server setup featuring Jellyfin, the complete *arr suite, VPN protection, and 2FA authentication.

## 🚀 Quick Start

```bash
# 1. Clone or download this repository
git clone <repository-url>
cd media-center

# 2. Configure environment
cp .env.example .env
nano .env  # Update your settings

# 3. Start the stack
./start.sh

# 4. Access your services
open https://media.local
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
- **[qBittorrent](https://www.qbittorrent.org/)** - Torrent client (VPN protected)
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

### 2. DNS Configuration

**Option A: Local Development (recommended for testing)**
Add to `/etc/hosts` or `C:\\Windows\\System32\\drivers\\etc\\hosts`:

```
127.0.0.1 media.local
127.0.0.1 auth.media.local
127.0.0.1 jellyfin.media.local
127.0.0.1 requests.media.local
127.0.0.1 dashboard.media.local
127.0.0.1 prowlarr.media.local
127.0.0.1 radarr.media.local
127.0.0.1 sonarr.media.local
127.0.0.1 lidarr.media.local
127.0.0.1 readarr.media.local
127.0.0.1 bazarr.media.local
127.0.0.1 qbittorrent.media.local
```

**Option B: Production Domain**
Configure your DNS provider to point your domain and subdomains to your server's IP address.

### 3. VPN Configuration

This stack routes download traffic through a VPN for privacy and security.

1. **Choose a supported VPN provider** from [Gluetun's list](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers)
2. **Update `.env` file** with your VPN credentials
3. **Download config files** (if required) to `config/gluetun/`

Popular providers:
- NordVPN, ExpressVPN, Surfshark
- Private Internet Access (PIA)
- Mullvad, ProtonVPN

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

#### 1. Authelia (Authentication)
- **URL**: `https://auth.media.local`
- **Default**: `admin` / `admin123` (⚠️ **CHANGE IMMEDIATELY**)
- Set up 2FA (TOTP recommended)

#### 2. Jellyfin (Media Server)
- **URL**: `https://jellyfin.media.local`  
- Create admin account
- Add media libraries pointing to `/media/*` folders
- Enable hardware transcoding if GPU available

#### 3. Prowlarr (Indexer Manager)
- **URL**: `https://prowlarr.media.local`
- Add indexers (torrent sites, Usenet providers)
- Configure Flaresolverr if needed for Cloudflare-protected sites

#### 4. *arr Applications
Configure each application with:
- **Root folders**: Point to appropriate `/media/*` directories
- **Download client**: qBittorrent (http://qbittorrent:8080)
- **Indexers**: Connect to Prowlarr
- **Quality profiles**: Set desired quality standards

#### 5. qBittorrent (Download Client)
- **URL**: `https://qbittorrent.media.local`
- **Default**: `admin` / `adminadmin`
- Configure download categories and paths
- Verify VPN is active (check IP address)

## 🔒 Security Features

### Authentication & Authorization
- **2FA Authentication** via Authelia (TOTP, WebAuthn, Duo)
- **Role-based access control** (admin vs. user permissions)
- **Session management** with configurable timeouts

### Network Security
- **VPN Protection** for all download traffic
- **Reverse proxy** with automatic SSL certificates
- **Network isolation** between service groups
- **Security headers** and modern TLS configuration

### Data Protection
- **Encrypted storage** for authentication data
- **Secure secrets management** via Docker secrets
- **Regular automated backups** with retention policies

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
- **Gluetun VPN**: Check IP address and connection status
- **Service status**: `docker-compose ps`
- **Resource usage**: `docker stats`

### Common Issues

**VPN Not Working**
```bash
# Check VPN status
docker exec gluetun wget -qO- ifconfig.me

# View VPN logs
docker-compose logs gluetun
```

**SSL Certificate Issues**
```bash
# Check Traefik logs
docker-compose logs traefik

# Verify domain DNS resolution
nslookup your-domain.com
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

## 🚨 Important Security Notes

1. **Change default passwords** immediately after setup
2. **Use strong, unique passwords** for all services  
3. **Keep services updated** regularly with `./update.sh`
4. **Monitor logs** for suspicious activity
5. **Backup configurations** regularly with `./backup.sh`
6. **Use VPN** for all download activities
7. **Limit external access** to trusted networks when possible

**Happy streaming! 🍿**