# MariaDB 10.11 with Mroonga Docker Image Usage Guide

## Overview
This Docker image provides MariaDB 10.11 server with Mroonga full-text search engine on Debian Bookworm, optimized for Japanese text processing. It includes Apache Arrow and Groonga repositories for enhanced search capabilities.

## Quick Start

### 1. Build the Image
```bash
docker build -t mariadb-mroonga:10.11 .
```

### 2. Run the Container

#### Basic Usage
```bash
docker run -d \
  --name mariadb-mroonga \
  -e MYSQL_ROOT_PASSWORD=your_password \
  -p 3306:3306 \
  mariadb-mroonga:10.11
```

#### With Persistent Data
```bash
docker run -d \
  --name mariadb-mroonga \
  -e MYSQL_ROOT_PASSWORD=your_password \
  -v $(pwd)/data:/var/lib/mysql \
  -p 3306:3306 \
  mariadb-mroonga:10.11
```

#### With Custom Configuration
```bash
docker run -d \
  --name mariadb-mroonga \
  -e MYSQL_ROOT_PASSWORD=your_password \
  -v $(pwd)/data:/var/lib/mysql \
  -v $(pwd)/my.cnf:/etc/mysql/conf.d/my.cnf:ro \
  -p 3306:3306 \
  mariadb-mroonga:10.11
```

## Environment Variables

- `MYSQL_ROOT_PASSWORD`: Required. Sets the root user password
- `MYSQL_DATABASE`: Optional. Creates a database on startup
- `MYSQL_USER`: Optional. Creates a new user
- `MYSQL_PASSWORD`: Optional. Password for the new user

## Connecting to the Database

### Using MySQL Client
```bash
docker exec -it mariadb-mroonga mysql -uroot -p
```

### From Host Machine
```bash
mysql -h 127.0.0.1 -P 3306 -u root -p
```

### From Application
```
Host: localhost or 127.0.0.1
Port: 3306
Username: root
Password: <your_password>
```

## Enabling Mroonga Plugin

### Option 1: Manual Installation (One-time)
The Mroonga plugin needs to be installed manually after the container starts:

```bash
# Connect to MySQL
docker exec -it mariadb-mroonga mysql -uroot -p

# Install Mroonga plugin
INSTALL SONAME 'ha_mroonga';

# Verify installation
SHOW ENGINES;
```

You should see Mroonga listed as:
```
Mroonga	YES	CJK-ready fulltext search, column store	NO	NO	NO
```

### Option 2: Using Entrypoint Script (Automatic)
The image includes an entrypoint script that can automatically install Mroonga on first startup. This is handled by the initialization scripts in `/docker-entrypoint-initdb.d/`.

**Note**: Due to MariaDB version compatibility, the current setup uses the stable Mroonga plugin from Debian repositories rather than the latest version from Groonga's official repository.

## Version Information

This image provides:
- **MariaDB**: 10.11.14 (from Debian Bookworm)
- **Mroonga Plugin**: Available from `mariadb-plugin-mroonga` package
- **Groonga Tokenizer**: MeCab tokenizer for Japanese text processing
- **Character Set**: UTF-8 (utf8mb4) configured by default
- **Locale**: Japanese (ja_JP.UTF-8) support

## Testing the Installation

### Quick Test
```bash
# Start container
docker run -d --name test-mroonga -e MYSQL_ROOT_PASSWORD=testpass -p 3306:3306 mariadb-mroonga:10.11

# Wait for initialization (10-15 seconds)
sleep 15

# Install and test Mroonga
docker exec -it test-mroonga mysql -uroot -ptestpass -e "
INSTALL SONAME 'ha_mroonga';
SHOW ENGINES;
SELECT VERSION();"

# Clean up
docker rm -f test-mroonga
```

### Expected Output
```
VERSION()
10.11.14-MariaDB-0+deb12u2

Engine      Support   Comment
...
Mroonga     YES       CJK-ready fulltext search, column store
...
```

## Using Mroonga for Full-Text Search

### Create a Table with Mroonga Engine
```sql
CREATE TABLE articles (
  id INT PRIMARY KEY AUTO_INCREMENT,
  title VARCHAR(255),
  content TEXT,
  FULLTEXT INDEX (title, content)
) ENGINE=Mroonga DEFAULT CHARSET=utf8mb4;
```

### Insert Sample Data
```sql
INSERT INTO articles (title, content) VALUES
  ('MariaDBの使い方', 'MariaDBは高性能なデータベースです'),
  ('Mroongaガイド', 'Mroongaは日本語全文検索エンジンです'),
  ('Docker入門', 'Dockerでコンテナを管理しましょう');
```

### Full-Text Search
```sql
-- Natural language search
SELECT * FROM articles
WHERE MATCH(title, content) AGAINST('データベース' IN NATURAL LANGUAGE MODE);

-- Boolean mode search
SELECT * FROM articles
WHERE MATCH(title, content) AGAINST('+Docker +管理' IN BOOLEAN MODE);
```

## Docker Compose Example

Create a `docker-compose.yml` file:

```yaml
version: '3.8'

services:
  mariadb:
    build: .
    container_name: mariadb-mroonga
    environment:
      MYSQL_ROOT_PASSWORD: rootpass123
      MYSQL_DATABASE: myapp
      MYSQL_USER: appuser
      MYSQL_PASSWORD: apppass123
    ports:
      - "3306:3306"
    volumes:
      - mariadb_data:/var/lib/mysql
      - ./my.cnf:/etc/mysql/conf.d/my.cnf:ro
    restart: unless-stopped

volumes:
  mariadb_data:
```

Run with Docker Compose:
```bash
docker-compose up -d
```

## Backup and Restore

### Backup Database
```bash
docker exec mariadb-mroonga mysqldump -uroot -p --all-databases > backup.sql
```

### Restore Database
```bash
docker exec -i mariadb-mroonga mysql -uroot -p < backup.sql
```

## Monitoring

### Check Container Logs
```bash
docker logs mariadb-mroonga
```

### Monitor in Real-Time
```bash
docker logs -f mariadb-mroonga
```

### Check Container Status
```bash
docker ps | grep mariadb-mroonga
```

### Resource Usage
```bash
docker stats mariadb-mroonga
```

## Troubleshooting

### Container Won't Start
1. Check logs: `docker logs mariadb-mroonga`
2. Verify port availability: `lsof -i:3306`
3. Check data directory permissions

### Connection Refused
1. Ensure container is running: `docker ps`
2. Check port mapping: `-p 3306:3306`
3. Verify firewall settings

### Mroonga Not Working
1. **Check plugin availability**: `SHOW PLUGINS;` or `SELECT * FROM information_schema.PLUGINS WHERE PLUGIN_NAME LIKE '%roonga%';`
2. **Manual installation**: `INSTALL SONAME 'ha_mroonga';`
3. **Check engines**: `SHOW ENGINES;` - Mroonga should appear with "YES" support
4. **Plugin file check**: Verify `/usr/lib/mysql/plugin/ha_mroonga.so` exists in container
5. **Restart if needed**: Sometimes requires container restart after installation

### Installation Method Notes
This image uses two repository sources:
- **Apache Arrow Repository**: For enhanced columnar processing capabilities
- **Groonga Repository**: For latest tokenizer and search features
- **Debian MariaDB**: Base MariaDB 10.11 from stable Debian Bookworm

**Why not official Mroonga packages?** The official `mariadb-10.11-mroonga` package from Groonga repository requires exact MariaDB version 10.11.11, but Debian provides 10.11.14. The Debian `mariadb-plugin-mroonga` package works reliably with the current MariaDB version.

### Character Encoding Issues
1. Check server charset: `SHOW VARIABLES LIKE 'character_set_%';`
2. Ensure UTF-8 in connection string
3. Set charset in table creation
4. Default configuration uses `utf8mb4` with `utf8mb4_unicode_ci` collation

## Performance Tuning

### my.cnf Optimizations
```ini
[mysqld]
# Basic settings
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
max_allowed_packet = 256M

# InnoDB settings
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 2
innodb_file_per_table = 1

# Query cache (if needed)
query_cache_size = 128M
query_cache_type = 1

# Connection settings
max_connections = 200
thread_cache_size = 8

# Mroonga specific
mroonga_log_level = notice
```

## Security Best Practices

1. **Use Strong Passwords**: Always set strong passwords for root and user accounts
2. **Limit Network Access**: Use firewall rules or Docker networks
3. **Regular Updates**: Keep the base image and packages updated
4. **Backup Regularly**: Implement automated backup strategies
5. **Use Secrets Management**: Consider Docker secrets for sensitive data

## Stop and Remove

### Stop Container
```bash
docker stop mariadb-mroonga
```

### Remove Container
```bash
docker rm mariadb-mroonga
```

### Remove Image
```bash
docker rmi mariadb-mroonga:10.11
```

### Clean Up Volumes
```bash
docker volume prune
```

## Additional Resources

- [MariaDB Documentation](https://mariadb.com/kb/en/documentation/)
- [Mroonga Documentation](https://mroonga.org/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [Groonga Tokenizers](https://groonga.org/docs/reference/tokenizers.html)