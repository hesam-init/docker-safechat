# 🔒 docker-safechat

A self-hosted, private [Matrix](https://matrix.org) chat server running entirely on your local network — no domain required, IP-only. Built with [Synapse](https://github.com/element-hq/synapse), [Element Web](https://element.io), PostgreSQL, and a Synapse Admin panel, all orchestrated via Docker Compose.

---

## Stack

| Service | Image | Role |
|---|---|---|
| Synapse | `matrixdotorg/synapse:v1.149.0` | Matrix homeserver |
| PostgreSQL | `postgres:16` | Database |
| Element Web | `vectorim/element-web` | Web chat client |
| Synapse Admin | `awesometechnologies/synapse-admin` | Admin panel UI |
| Nginx | `nginx:alpine` | Reverse proxy |

---

## Project Structure

```
docker-safechat/
├── docker-compose.yml
├── .env                        ← secrets (gitignored)
├── .env.example                ← template, safe to commit
├── .gitignore
├── README.md
├── nginx/
│   └── nginx.conf
├── element/
│   └── config.json
├── synapse/
│   └── data/                   ← homeserver.yaml, signing key, media (gitignored)
└── postgres/
    └── data/                   ← database files (gitignored)
```

---

## Requirements

- Docker >= 24
- Docker Compose >= 2
- Open ports: `80`, `8080`, `8448`

---

## Setup

### 1. Clone & enter the project

```bash
git clone <your-repo-url> ~/DockerCompose/docker-safechat
cd ~/DockerCompose/docker-safechat
```

### 2. Create your `.env`

```bash
cp .env.example .env
nano .env
```

```env
SERVER_IP=127.0.0.1
POSTGRES_USER=synapse
POSTGRES_PASSWORD=changeme123
POSTGRES_DB=synapse
```

> Replace `SERVER_IP` with your actual server IP address.

### 3. Generate Synapse config

```bash
docker run --rm \
  -v $(pwd)/synapse/data:/data \
  -e SYNAPSE_SERVER_NAME=matrix \
  -e SYNAPSE_REPORT_STATS=no \
  matrixdotorg/synapse:latest generate
```

### 4. Fix ownership

```bash
sudo chown -R 991:991 ~/DockerCompose/docker-safechat/synapse/data
sudo chown -R 1000:1000 ~/DockerCompose/docker-safechat/postgres/data
```

### 5. Edit `synapse/data/homeserver.yaml`

Find the `database:` block and replace it:

```yaml
database:
  name: psycopg2
  args:
    user: synapse
    password: changeme123
    database: synapse
    host: postgres
    cp_min: 5
    cp_max: 10
```

Also make sure these are set:

```yaml
enable_registration: true
registration_requires_token: true
```

### 6. Start the stack

```bash
docker compose up -d
docker compose -f docker-compose.web.yml up -d

docker compose logs -f synapse
```

Wait for `Synapse now listening on port 8008` in the logs.

Forward proxy using ssh

```
sudo ssh -p 4949 root@<server-ip> -L 80:safechat-synapse:8008

sudo gost -L tcp://:80/safechat-synapse:8008 -F sshd://root:<pass>@<server-ip>:4949
```

---

## Access

| Service | URL |
|---|---|
| Element Web | `http://127.0.0.1` |
| Admin Panel | `http://127.0.0.1:8080` |
| Matrix API | `http://127.0.0.1/_matrix` |

---

## First Admin User

```bash
docker exec -it safechat-synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  -u admin \
  -p yourpassword \
  -a \
  http://localhost:8008
```

Then log into the admin panel at `http://127.0.0.1:8080` using the homeserver URL `http://127.0.0.1`.

---

## Get Admin Access Token

Required for all API management commands:

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1/_matrix/client/v3/login \
  -H "Content-Type: application/json" \
  -d '{"type":"m.login.password","user":"admin","password":"yourpassword"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
```

---

## Management

### Registration tokens

```bash
# Create token (10 uses)
curl -X POST "http://127.0.0.1/_synapse/admin/v1/registration_tokens/new" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"uses_allowed": 10}'

# Create named token
curl -X POST "http://127.0.0.1/_synapse/admin/v1/registration_tokens/new" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"token": "invite2024", "uses_allowed": 5}'

# List all tokens
curl "http://127.0.0.1/_synapse/admin/v1/registration_tokens" \
  -H "Authorization: Bearer $TOKEN"

# Delete a token
curl -X DELETE "http://127.0.0.1/_synapse/admin/v1/registration_tokens/invite2024" \
  -H "Authorization: Bearer $TOKEN"
```

### Users

```bash
# List users
curl "http://127.0.0.1/_synapse/admin/v2/users?from=0&limit=100" \
  -H "Authorization: Bearer $TOKEN"

# Reset password
curl -X POST "http://127.0.0.1/_synapse/admin/v1/reset_password/@alice:127.0.0.1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"new_password": "newpass123", "logout_devices": true}'

# Promote to admin
curl -X PUT "http://127.0.0.1/_synapse/admin/v2/users/@alice:127.0.0.1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"admin": true}'

# Deactivate user
curl -X POST "http://127.0.0.1/_synapse/admin/v1/deactivate/@alice:127.0.0.1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"erase": false}'
```

### Rooms

```bash
# List rooms
curl "http://127.0.0.1/_synapse/admin/v1/rooms" \
  -H "Authorization: Bearer $TOKEN"

# Delete a room
curl -X DELETE "http://127.0.0.1/_synapse/admin/v1/rooms/!roomid:127.0.0.1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "Removed by admin"}'
```

### Stack ops

```bash
# Restart after config changes
docker compose restart synapse

# View logs
docker compose logs -f synapse --tail=100
docker compose logs -f postgres --tail=50

# Stop everything
docker compose down

# Check postgres health
docker exec -it safechat-postgres pg_isready -U synapse

# Postgres vacuum
docker exec -it safechat-postgres psql -U synapse -d synapse -c "VACUUM ANALYZE;"
```

---

## Backup

```bash
cd ~/DockerCompose/docker-safechat

# Stop synapse only
docker compose stop synapse

# Dump database
docker exec safechat-postgres pg_dump -U synapse synapse \
  | gzip > ~/backups/safechat-db-$(date +%F).sql.gz

# Back up media
tar czf ~/backups/safechat-media-$(date +%F).tar.gz \
  ./synapse/data/media_store

# Back up config (signing key is critical — never lose it)
tar czf ~/backups/safechat-config-$(date +%F).tar.gz \
  ./synapse/data/homeserver.yaml \
  ./synapse/data/*.signing.key \
  ./element/config.json \
  ./nginx/nginx.conf \
  .env

docker compose start synapse
```

### Restore

```bash
docker compose down
gunzip -c ~/backups/safechat-db-2024-01-01.sql.gz \
  | docker exec -i safechat-postgres psql -U synapse synapse
docker compose up -d
```

---

## Git

The following are gitignored and must never be committed:

| Path | Reason |
|---|---|
| `.env` | Contains real passwords |
| `synapse/data/*.signing.key` | Server identity — losing this breaks federation |
| `synapse/data/media_store/` | User uploaded files |
| `postgres/data/` | Binary database files |
| `synapse/data/homeserver.yaml.bak` | Script backup file |

> ⚠️ Always double-check `git status` before committing. If your `homeserver.yaml` has plaintext passwords in the `database:` block, either remove them or add the file to `.gitignore`.

---

## Notes

- **Registration** is token-gated by default. Users sign up at `http://127.0.0.1` and must enter a token you generate via the admin API.
- **Signing key** is your server's cryptographic identity. Back it up. If lost, your server loses its federation history.
- **Federation** is enabled by default on port `8448`. If this is a LAN-only server, you can disable it by adding `federation_domain_whitelist: []` to `homeserver.yaml`.
- **Synapse runs as UID 991** inside its container — the `synapse/data/` folder must be owned by `991:991` on the host.
