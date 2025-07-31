# Migration, Backup & Restore Guide

Complete guide for backing up, migrating, and restoring your Media Server Stack.

## 🛠️ Available Scripts

### Core Scripts

- **`backup.sh`** - Create comprehensive backups of your media server stack
- **`restore.sh`** - Restore from backups with guided setup
- **`migrate.sh`** - Orchestrate migrations between systems
- **`validate.sh`** - Verify system health after operations

## 📦 Backup Operations

### Basic Backup

```bash
# Standard backup (configs only)
./backup.sh

# Include media files (WARNING: Large backup size!)
./backup.sh --include-media

# Custom retention period (default: 30 days)
./backup.sh --retention 60
```

### Migration-Ready Backup

```bash
# Create migration backup with system info and secrets
./backup.sh --migration --export-secrets

# Full migration backup including media
./backup.sh --migration --export-secrets --include-media

# Anonymized backup (secrets replaced with placeholders)
./backup.sh --migration --anonymize-secrets
```

### Backup Options

| Option | Description |
|--------|-------------|
| `--include-media` | Include media files (WARNING: Very large!) |
| `--no-compress` | Skip compression (faster but larger) |
| `--retention DAYS` | Keep backups for specified days (default: 30) |
| `--migration` | Include system info for migration |
| `--export-secrets` | Export API keys and secrets |
| `--anonymize-secrets` | Replace secrets with placeholders |

### What Gets Backed Up

**Always Included:**

- All service configurations (`./config/`)
- Docker Compose files
- Environment variables (`.env`)
- Management scripts
- Service metadata and status

**Migration Mode Additions:**

- System information (OS, Docker version, network config)
- Disk space requirements
- Service health status
- Environment variables export

**Optional Additions:**

- Media files (`./data/`) - Use `--include-media`
- API keys and secrets - Use `--export-secrets`

## 🔄 Restore Operations

### Interactive Restore

```bash
# Interactive restore with prompts
./restore.sh

# Restore from specific backup
./restore.sh -b /path/to/backup.tar.gz

# Restore from backup directory
./restore.sh -b /path/to/backup/directory
```

### Automated Restore

```bash
# Non-interactive restore with defaults
./restore.sh -b backup.tar.gz --yes

# Force restore without confirmations
./restore.sh -b backup.tar.gz --yes --force
```

### Restore Process

1. **Prerequisites Check** - Verify Docker and Docker Compose
2. **Backup Validation** - Ensure backup integrity
3. **Disk Space Check** - Verify sufficient space
4. **Service Shutdown** - Stop existing services (if any)
5. **Config Backup** - Backup existing configs (optional)
6. **File Restoration** - Restore all backup files
7. **Environment Update** - Review and update settings
8. **Permissions Setup** - Set proper file ownership
9. **Service Startup** - Start restored services
10. **Validation** - Verify successful restoration

### Post-Restore Tasks

**Immediate:**

- Wait for services to initialize (2-5 minutes)
- Check service status: `docker-compose ps`
- Review logs: `docker-compose logs -f [service-name]`

**Configuration Updates:**

- Update API keys using `secrets_export.txt`
- Reconfigure service connections
- Test download client settings
- Verify media library paths

**Security:**

- Change default passwords
- Delete `secrets_export.txt` after use
- Update authentication settings

## 🚀 Migration Operations

### Migration Types

**Local Migration**

```bash
# Move to different directory on same machine
./migrate.sh -t local -d /new/media-center/path

# Interactive local migration
./migrate.sh -t local
```

**Remote Migration**

```bash
# Migrate to remote server
./migrate.sh -t remote -r user@server.com -d /opt/media-center

# Remote migration with media files
./migrate.sh -t remote -r user@server.com -d /opt/media-center --include-media
```

**Manual Migration**

```bash
# Create backup for manual transfer
./migrate.sh -t manual --include-media

# Creates backup and provides transfer instructions
```

### Migration Options

| Option | Description |
|--------|-------------|
| `-t, --type TYPE` | Migration type: local, remote, manual |
| `-s, --source PATH` | Source directory (default: current) |
| `-d, --dest PATH` | Destination directory |
| `-r, --remote HOST` | Remote host (user@hostname) |
| `-u, --user USER` | Remote user (if not in --remote) |
| `-m, --include-media` | Include media files |
| `-n, --name NAME` | Custom backup name |
| `--skip-validation` | Skip post-migration validation |

### Migration Process

1. **Prerequisites Validation** - Check Docker, SSH (for remote)
2. **Migration Planning** - Gather source/destination info
3. **Backup Creation** - Create migration-optimized backup
4. **Transfer** - Move backup to destination
5. **Restoration** - Restore on target system
6. **Validation** - Verify successful migration
7. **Report Generation** - Create migration summary

### Remote Migration Requirements

**Source System:**

- SSH client (`ssh`, `scp`)
- Migration scripts
- Network access to target

**Target System:**

- SSH server running
- Docker and Docker Compose installed
- Sufficient disk space
- Proper user permissions

## 📊 Validation & Monitoring

### Basic Validation

```bash
# Check service status
docker-compose ps

# View service logs
docker-compose logs -f [service-name]

# Test service connectivity
curl -I http://localhost:8096  # Jellyfin
curl -I http://localhost:5055  # Jellyseerr
```

### Comprehensive Validation

```bash
# Run validation script (if available)
./validate.sh

# Generate validation report
./validate.sh --report
```

## 📋 Common Scenarios

### Regular Maintenance Backup

```bash
# Weekly backup without media
./backup.sh --retention 14

# Monthly backup with media
./backup.sh --include-media --retention 90
```

### Pre-Upgrade Backup

```bash
# Before major updates
./backup.sh --migration --export-secrets
```

### System Migration

```bash
# Complete system move with media
./migrate.sh -t remote -r user@newserver.com --include-media
```

### Disaster Recovery

```bash
# Restore from emergency backup
./restore.sh -b emergency-backup.tar.gz --yes --force

# Validate after restoration
./validate.sh --report
```

### Testing/Development Setup

```bash
# Create test environment
./backup.sh --anonymize-secrets
./restore.sh -b backup.tar.gz -d /tmp/test-env
```

## 🔧 Advanced Operations

### Selective Restore

Extract specific components from backup:

```bash
# Extract backup manually
tar -xzf backup.tar.gz

# Copy only specific services
cp -r extracted/config/jellyfin ./config/
cp -r extracted/config/radarr ./config/

# Start specific services
docker-compose up -d jellyfin radarr
```

### Cross-Platform Migration

**Different OS Migration:**

1. Create migration backup with `--export-secrets`
2. Update paths in configurations
3. Adjust PUID/PGID values
4. Verify Docker image compatibility

**Architecture Changes:**

1. Check service architecture support
2. Update Docker Compose platform settings
3. Rebuild containers if needed

### Backup Automation

**Cron Job Setup:**

```bash
# Daily config backup at 2 AM
0 2 * * * /path/to/media-center/backup.sh --retention 7

# Weekly full backup at 3 AM Sunday
0 3 * * 0 /path/to/media-center/backup.sh --include-media --retention 30
```

## 🚨 Troubleshooting

### Common Issues

**Backup Failures:**

- Check disk space: `df -h`
- Verify permissions: `ls -la config data`
- Check Docker status: `docker ps`

**Restore Failures:**

- Validate backup: `tar -tzf backup.tar.gz`
- Check destination space: `df -h .`
- Verify Docker installation: `docker version`

**Migration Issues:**

- Test SSH connection: `ssh user@host echo "test"`
- Check network connectivity
- Verify target system requirements

**Permission Problems:**

```bash
# Fix ownership
chown -R 1000:1000 config data

# Fix permissions
chmod -R 755 config data
chmod 600 config/traefik/acme.json  # if exists
```

### Service-Specific Issues

**Jellyfin:**

- Clear transcoding cache: `rm -rf config/jellyfin/transcoding-temp/*`
- Reset database: Restore from known good backup
- Update library paths in admin settings

***arr Applications:**

- Reconfigure download client connections
- Update indexer settings from Prowlarr
- Verify API key configurations

**qBittorrent:**

- Reset admin password: Delete `config/qbittorrent/qBittorrent.conf`
- Check VPN connection if used
- Verify port forwarding settings

### Recovery Strategies

**Partial Corruption:**

1. Identify corrupted service
2. Stop service: `docker-compose stop [service]`
3. Restore service config from backup
4. Restart service: `docker-compose start [service]`

**Complete System Failure:**

1. Fresh Docker installation
2. Full restore from latest backup
3. Update network/system specific settings
4. Comprehensive validation

## 📚 File Locations

### Backup Contents

```
backup-YYYYMMDD_HHMMSS/
├── config/                 # Service configurations
├── data/                   # Media files (if included)
├── docker-compose.yml      # Stack definition
├── .env                    # Environment variables
├── *.sh                    # Management scripts
├── backup_info.txt         # Backup metadata
├── migration_info.txt      # System information (migration mode)
├── space_requirements.txt  # Disk space info (migration mode)
├── secrets_export.txt      # API keys/secrets (if exported)
└── RESTORE_INSTRUCTIONS.md # Detailed restore guide
```

### Important Files

- **`.env`** - Environment configuration
- **`docker-compose.yml`** - Service definitions
- **`secrets_export.txt`** - API keys and secrets (delete after use!)
- **`migration_info.txt`** - Source system information
- **`space_requirements.txt`** - Disk space requirements

## ⚠️ Security Considerations

### Backup Security

- Store backups on encrypted storage
- Restrict access to backup files: `chmod 600 backup.tar.gz`
- Use `--anonymize-secrets` for shared backups
- Regular cleanup of old backups

### Migration Security

- Delete `secrets_export.txt` after migration
- Change API keys and passwords on new system
- Update authentication configurations
- Review firewall and network settings

### Access Control

- Use dedicated backup user with minimal permissions
- Implement backup encryption for sensitive environments
- Regular security audits of backup procedures
- Monitor backup/restore operations

## 🎯 Best Practices

### Backup Strategy

1. **Regular Schedule**: Daily configs, weekly with media
2. **Multiple Locations**: Local and remote backup storage
3. **Version Control**: Keep multiple backup generations
4. **Testing**: Regularly test restore procedures
5. **Documentation**: Maintain restore procedures

### Migration Planning

1. **Pre-Migration**: Test target system compatibility
2. **Timing**: Plan for minimal service downtime
3. **Validation**: Comprehensive post-migration testing
4. **Rollback**: Keep source system available until confirmed
5. **Documentation**: Record migration process and issues

### Maintenance

1. **Cleanup**: Regular removal of old backups
2. **Monitoring**: Check backup completion and integrity
3. **Updates**: Keep scripts updated with system changes
4. **Training**: Ensure team knows procedures
5. **Testing**: Regular disaster recovery exercises

---

**Remember**: Always test restore procedures before you need them, and keep multiple backup generations for safety!
