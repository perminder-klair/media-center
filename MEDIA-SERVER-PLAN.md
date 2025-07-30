# Media Server Stack Implementation Plan (2025)

> **Project**: Self-hosted Media Center with Jellyfin and *arr Suite  
> **Date**: July 30, 2025  
> **Status**: Planning Phase  

## 🎬 Recommended Stack Components

### Core Media Services
- **Jellyfin** - Free open-source media server for streaming
  - Hardware acceleration support for transcoding
  - No subscription fees or premium features
  - Full control over your media library
- **Jellyseerr** - Request management interface (port 5055)
  - User-friendly media request system
  - Integrates with Jellyfin accounts
  - Connects to Radarr/Sonarr for automated downloads

### Content Management (*arr Suite)
- **Radarr** - Movie library manager (port 7878)
  - Automated movie downloading and organization
  - Quality profiles and release monitoring
- **Sonarr** - TV shows library manager (port 8989)
  - Episode tracking and season management
  - Supports multiple TV databases
- **Lidarr** - Music library manager (port 8686)
  - Album and artist management
  - Music quality profiles
- **Readarr** - Books/audiobooks manager (port 8787)
  - Ebook and audiobook organization
  - Author and series tracking
- **Bazarr** - Subtitle manager (port 6767)
  - Automatic subtitle downloads
  - Multiple language support
- **Prowlarr** - Indexer manager (port 9696)
  - Replaces Jackett with better integration
  - Central indexer management for all *arr apps

### Download Clients
- **qBittorrent** - Primary torrent client (recommended over Transmission)
  - Better performance and features
  - Web interface for remote management
- **SABnzbd** - Usenet downloader (optional)
  - For Usenet providers
  - Automated processing and extraction
- **Unpackerr** - Automated extraction tool
  - Handles compressed downloads automatically

### Security & Access
- **Gluetun** - VPN container (install first!)
  - Routes download traffic through VPN
  - Supports multiple VPN providers
  - Kill switch functionality
- **Traefik v3** - Reverse proxy with SSL
  - Latest version with improved features
  - Automatic Let's Encrypt certificates
  - Dynamic service discovery
- **Authelia** or **Authentik** - 2FA authentication
  - **Authelia**: Lightweight, single domain focus
  - **Authentik**: More features, web UI configuration
  - Both support hardware keys, TOTP, push notifications
- **Flaresolverr** - Cloudflare bypass
  - Handles sites with Cloudflare protection
  - Required for some indexers

### Additional Tools
- **Tdarr** - Automated media transcoding
  - Batch processing of media files
  - GPU acceleration support
- **Heimdall** - Application dashboard
  - Central hub for all services
  - Customizable interface
- **Portainer** (optional) - Container management UI
  - Note: Not recommended for initial setup
  - Better to use Docker Compose

## 💻 Hardware Requirements

### Minimum Specifications
- **CPU**: Intel Core i5-2300, AMD FX-8100 or better
  - Geekbench 6 Multicore 1500+ recommended
- **RAM**: 8GB recommended (4GB minimum for Linux server)
- **Storage**: 
  - 100GB SSD for OS, Jellyfin files, and transcoding cache
  - Additional storage for media library
- **Network**: Gigabit Ethernet (WiFi/Powerline not recommended)

### GPU Requirements for Transcoding
**CRITICAL**: Not having a GPU is NOT recommended for Jellyfin

#### Recommended GPUs (2025):
- **Intel**: Arc A series or newer (Arc B series requires ReBar)
  - 7th gen+ processors with Quick Sync
  - AV1 encoding support on newer models
- **NVIDIA**: GTX1660/RTX20xx series or newer
  - Turing+ cards for 4K HDR transcoding
  - Minimum driver version: 522.25
- **AMD**: NOT recommended for transcoding

#### 4K HDR Transcoding Requirements:
- Intel Quick Sync (7th-gen+)
- NVIDIA Turing+ cards (GTX 1660, RTX 30xx+)
- AMD RDNA2/3 GPUs (limited support)

### Performance Notes
- HDR to SDR tone-mapping requires significant processing power
- 4K 60fps Dolby Vision → 4K 60fps H264 SDR needs Ryzen 9 5950X for real-time CPU transcoding
- SSD or RamDisk recommended for transcoding cache on high-throughput scenarios

## 📁 Directory Structure

```
/home/klair/Projects/media-center/
├── docker-compose.yml          # Main stack configuration
├── .env                        # Environment variables
├── config/                     # Service configurations
│   ├── jellyfin/
│   ├── radarr/
│   ├── sonarr/
│   ├── lidarr/
│   ├── readarr/
│   ├── bazarr/
│   ├── prowlarr/
│   ├── jellyseerr/
│   ├── qbittorrent/
│   ├── traefik/
│   ├── authelia/
│   └── gluetun/
└── data/                       # Media and downloads
    ├── torrents/               # Download directory
    │   ├── movies/             # Movie downloads
    │   ├── tv/                 # TV show downloads
    │   ├── music/              # Music downloads
    │   └── books/              # Book downloads
    └── media/                  # Final media library
        ├── movies/             # Organized movies
        ├── tv/                 # Organized TV shows
        ├── music/              # Organized music
        └── books/              # Organized books
```

### Key Directory Principles
- **Single Volume**: Downloads and media on same filesystem for hardlinks
- **Consistent Paths**: Same path mapping across all containers
- **Atomic Moves**: Hardlinks enable instant moves without copying
- **Proper Permissions**: User/group consistency with umask 002

## 🔒 Security Best Practices (2025)

### 1. Network Security
- **Docker Networks**: Isolate services into separate networks
- **VPN Protection**: Route all download traffic through Gluetun
- **Firewall Rules**: Only expose necessary ports
- **TLS Configuration**: 
  - minVersion: VersionTLS12
  - sniStrict: true
  - Modern cipher suites (TLS_AES_128_GCM_SHA256, TLS_AES_256_GCM_SHA384)

### 2. Authentication & Authorization
- **Multi-Factor Authentication**: Required for internet-facing services
- **Strong Passwords**: Enforce password policies
- **Session Management**: Proper timeout and renewal
- **Role-Based Access**: Different access levels for different users

### 3. Container Security
- **Non-Root Users**: Run containers with specific UID/GID
- **Socket Proxy**: Protect Docker socket access
- **Secrets Management**: Use Docker secrets for sensitive data
- **Regular Updates**: Keep all containers updated

### 4. Remote Access Security
- **VPN First**: Most secure option for remote access
- **Reverse Proxy**: HTTPS with valid certificates
- **Rate Limiting**: Prevent brute force attacks
- **Geographic Restrictions**: Block unwanted regions

## 🚀 Implementation Phases

### Phase 1: Infrastructure Setup
1. **Environment Preparation**
   - [ ] Install Docker and Docker Compose
   - [ ] Create directory structure
   - [ ] Set up environment variables
   - [ ] Configure user permissions

2. **VPN & Networking**
   - [ ] Deploy Gluetun VPN container (FIRST!)
   - [ ] Configure VPN provider settings
   - [ ] Test VPN connectivity
   - [ ] Set up Docker networks

3. **Reverse Proxy & Security**
   - [ ] Deploy Traefik v3
   - [ ] Configure domain and SSL certificates
   - [ ] Set up Authelia or Authentik
   - [ ] Test authentication flow

### Phase 2: Core Media Services
4. **Media Server Setup**
   - [ ] Deploy Jellyfin with GPU passthrough
   - [ ] Configure hardware acceleration
   - [ ] Set up media libraries
   - [ ] Test transcoding performance

5. **Request Management**
   - [ ] Deploy Jellyseerr
   - [ ] Connect to Jellyfin
   - [ ] Configure user permissions
   - [ ] Test request workflow

### Phase 3: Content Management
6. **Indexer Management**
   - [ ] Deploy Prowlarr
   - [ ] Add torrent and Usenet indexers
   - [ ] Configure Flaresolverr if needed
   - [ ] Test indexer connectivity

7. **Library Managers**
   - [ ] Deploy Radarr (movies)
   - [ ] Deploy Sonarr (TV shows)
   - [ ] Deploy Lidarr (music)
   - [ ] Deploy Readarr (books)
   - [ ] Connect all to Prowlarr

8. **Subtitle Management**
   - [ ] Deploy Bazarr
   - [ ] Connect to Radarr and Sonarr
   - [ ] Configure subtitle providers
   - [ ] Set language preferences

### Phase 4: Download Infrastructure
9. **Download Clients**
   - [ ] Deploy qBittorrent through Gluetun
   - [ ] Configure download categories
   - [ ] Set up proper file permissions
   - [ ] Test VPN kill switch

10. **Integration & Testing**
    - [ ] Connect *arr apps to download clients
    - [ ] Configure quality profiles
    - [ ] Test complete download workflow
    - [ ] Verify hardlink functionality

### Phase 5: Optimization & Monitoring
11. **Media Processing**
    - [ ] Deploy Tdarr for transcoding
    - [ ] Configure transcoding profiles
    - [ ] Set up batch processing
    - [ ] Monitor GPU utilization

12. **Dashboard & Monitoring**
    - [ ] Deploy Heimdall dashboard
    - [ ] Set up application links
    - [ ] Configure monitoring alerts
    - [ ] Implement backup strategy

## 📋 Configuration Best Practices

### Docker Compose Considerations
- **User/Group IDs**: Consistent PUID/PGID across containers
- **Umask Setting**: Use umask 002 for proper file permissions
- **Volume Mapping**: Consistent paths between host and containers
- **Network Assignment**: Proper network isolation
- **Environment Variables**: Use .env file for sensitive data

### File Management
- **Hardlinks**: Enable atomic moves and prevent duplication
- **File Permissions**: Proper read/write access for all services
- **Storage Optimization**: Use single volume for downloads and media
- **Backup Strategy**: Regular backups of configurations and databases

### Performance Optimization
- **GPU Passthrough**: Proper device mapping for hardware acceleration
- **Network Performance**: Gigabit Ethernet for large file transfers
- **Storage Performance**: SSD for OS and transcoding cache
- **Resource Limits**: Set appropriate CPU/memory limits

## 🔧 Technical Notes

### GPU Passthrough
- **Intel/AMD**: Add `--device=/dev/dri` to containers
- **NVIDIA**: Map nvidia devices and set runtime
- **Permissions**: Add containers to `render` group
- **ReBar**: Required for Intel Arc B series cards

### Network Configuration
- **Port Mapping**: Standard ports for each service
- **Internal Communication**: Services communicate via Docker networks
- **External Access**: Only through reverse proxy
- **VPN Routing**: Download clients route through Gluetun

### Security Headers
- **HSTS**: Force HTTPS connections
- **CSP**: Content Security Policy implementation
- **CORS**: Proper cross-origin resource sharing
- **X-Frame-Options**: Prevent clickjacking attacks

## 📈 Progress Tracking

### Implementation Status
- [ ] Phase 1: Infrastructure Setup
- [ ] Phase 2: Core Media Services  
- [ ] Phase 3: Content Management
- [ ] Phase 4: Download Infrastructure
- [ ] Phase 5: Optimization & Monitoring

### Performance Metrics
- [ ] Transcoding performance benchmarks
- [ ] Download speeds and VPN overhead
- [ ] Storage utilization and hardlink effectiveness
- [ ] Authentication response times

## 🔄 Maintenance Schedule

### Daily
- Monitor download queues and failures
- Check VPN connectivity status
- Review authentication logs

### Weekly  
- Update container images
- Review storage usage
- Check backup integrity

### Monthly
- Security audit and vulnerability assessment
- Performance optimization review
- Configuration backup verification

---

**Next Steps**: Begin Phase 1 implementation starting with Docker environment setup and directory structure creation.