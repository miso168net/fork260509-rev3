# deploy/secrets — Secret 管理說明

真實的 `.txt` 檔 gitignored；`.txt.example` 範本 git-tracked。  
**請勿將真實 secret 值 commit 進版本庫。**

---

## 生成方式

```bash
bash deploy/generate-secrets.sh
```

**強制覆寫**（已有舊值時）：

```bash
bash deploy/generate-secrets.sh --force
```

> ℹ️ 檔案權限：腳本對生成的 `.txt` 設 `chmod 600`。在 WSL2 掛載 Windows 磁碟（drvfs，如 `/mnt/d/...`）下 `chmod` 為 no-op，權限會顯示 `777` 屬正常；在原生 Linux 檔系統則正確生效。

> ⚠️ `--force` 風險：腳本覆寫 leaf secret 後，正在運行的 stack **必須 restart** 才能讀到新值。  
> 且絕對不可手動修改單一 leaf 檔（如 `postgres_password.txt`）而不重新生成對應的 URL secret——  
> 否則 `database_url.txt` 內嵌的密碼與 postgres 設定的密碼就會不一致（dual-write drift），導致連線失敗。

---

## Dual-write 不變式

| URL secret | 內嵌 password 來源 |
|---|---|
| `database_url.txt` | `postgres_password.txt`（byte-identical） |
| `redis_url.txt` | `redis_password.txt`（byte-identical） |

腳本自動保證此不變式；**手動操作必須同時更新 leaf 與所有引用它的 URL secret**。

---

## 6 個必要 Secret

| 名稱 | 用途 | 消費服務 / 環境變數 | 類型 |
|---|---|---|---|
| `jwt_secret` | JWT access token 簽名金鑰 | rust-api `APP_JWT_JWT_SECRET_FILE`（波 0 接而不讀，消費＝Auth 刀） | leaf |
| `refresh_token_secret` | JWT refresh token 簽名金鑰 | rust-api `APP_JWT_REFRESH_TOKEN_SECRET_FILE`（波 0 接而不讀，消費＝Auth 刀） | leaf |
| `postgres_password` | PostgreSQL 資料庫密碼 | postgres `POSTGRES_PASSWORD_FILE` | leaf |
| `redis_password` | Redis 存取密碼 | redis-stack `--requirepass`（透過 command 注入） | leaf |
| `database_url` | rust-api / migrate 主連線字串 | `APP_DATABASE_URL_FILE` | composite |
| `redis_url` | rust-api Redis 連線字串 | `APP_REDIS_URL_FILE` | composite |

---

## 手動 Fallback 命令

| Secret | 命令 | 備註 |
|---|---|---|
| `jwt_secret` | `docker run --rm alpine/openssl rand -base64 48 > deploy/secrets/jwt_secret.txt` | base64（非 URL-embedded） |
| `refresh_token_secret` | `docker run --rm alpine/openssl rand -base64 48 > deploy/secrets/refresh_token_secret.txt` | base64（非 URL-embedded） |
| `postgres_password` | `docker run --rm alpine/openssl rand -hex 24 > deploy/secrets/postgres_password.txt` | **hex**（URL-safe，嵌入連線字串） |
| `redis_password` | `docker run --rm alpine/openssl rand -hex 24 > deploy/secrets/redis_password.txt` | **hex**（URL-safe，嵌入連線字串） |
| `database_url` | `echo "postgres://soybean:$(cat deploy/secrets/postgres_password.txt)@postgres:5432/soybean_admin_rust" > deploy/secrets/database_url.txt` | 依賴 `postgres_password.txt` |
| `redis_url` | `echo "redis://:$(cat deploy/secrets/redis_password.txt)@redis-stack:6379" > deploy/secrets/redis_url.txt` | 依賴 `redis_password.txt` |
| `grafana_admin_password` | `docker run --rm alpine/openssl rand -base64 24 > deploy/secrets/grafana_admin_password.txt` | base64（非 URL，僅 grafana `GF_SECURITY_ADMIN_PASSWORD__FILE` 檔注入；018 obs U1） |

> 註：上述 `echo` / `>` 會帶尾換行，而 `generate-secrets.sh` 用 `printf '%s'` 不帶；runtime 消費端（rust-api `load_secret` 會 `.trim()`、postgres/redis 亦容忍）會忽略尾換行,行為不受影響,但 byte 內容與腳本產物略異——優先用腳本生成。

---

## ⏳ 後續波次 Secret（波 0 不建立）

| 名稱 | 用途 | 預計波次 |
|---|---|---|
| `cleanup_database_url` | ~~Cleanup job 專用連線字串~~（014 as-built：cleanup-job **復用 `database_url`**、未另建獨立 secret） | 已決：復用 |
| `acme_email` | acme.sh 申請 TLS 憑證的聯絡信箱 | acme 實際 cert acquisition 落地時 |

> `grafana_admin_password` 已於 018 obs U1 落地（移至上方 always-on 表）。

> exporter（postgres_exporter / redis_exporter）**無新 secret**：reuse 既有 leaf —— postgres_exporter 經 `DATA_SOURCE_PASS_FILE=/run/secrets/postgres_password`、redis_exporter 經 sh-wrapper（`export REDIS_PASSWORD="$(cat /run/secrets/redis_password)"`）。
