# Mongo-Backup-Helper

A simple Bash-based toolset to **backup** and **restore** MongoDB collections using `mongodump` and `mongorestore`, with built-in logging and an easy-to-use folder structure.

## 📁 Project Structure

```bash
Mongo-Backup-Helper
├── .env               # Your private configuration
├── .env.example       # Example configuration file
├── .gitignore         # Ignore patterns for Git
├── README.md          # This file
├── backups/           # All timestamped backups
│   └── <TIMESTAMP>/
│       └── <DB_NAME>/
│           ├── <COLL>.gz
│           └── ...
├── logs/              # All backup logs
│   └── <TIMESTAMP>.log
└── scripts/
    ├── backup_dump.sh     # Generates backups
    └── backup_restore.sh  # Restores backups
```

## ⚙️ Configuration

1. Create your .env file based on the example file.

2. Open `.env` and fill in your MongoDB connection details and desired settings:

   ```ini
   # .env

   # Backup (dump) settings\  
   MONGO_URI_DUMP="mongodb://user:pass@host:27017/mydb"  
   DB_NAME_DUMP="mydb"  

   # Restore settings\  
   MONGO_URI_RESTORE="mongodb://user:pass@host:27017/"  
   DB_NAME_RESTORE="mydb_dev"  
   WORKERS="4"  # Number of parallel insertion workers

   # Optional: custom output directory\  
   BACKUP_DIR="./backups"
   ```

3. Add `.env` to Git ignore (already included in `.gitignore`).

## 🚀 Usage

### 1. Backup collections

Run the backup script with one or more collection names:

```bash
scripts/backup_dump.sh <collection1> [collection2 ...]
```

* **What happens**:

  * Creates `backups/<TIMESTAMP>/<DB_NAME_DUMP>/` folder
  * Exports each collection to `<COLL>.gz` inside that folder
  * Logs output to `logs/<TIMESTAMP>.log`

### 2. Restore collections

Run the restore script with a timestamp and optional collection names:

```bash
source .env
scripts/backup_restore.sh <TIMESTAMP> [collection1 collection2 ...]
```

* **If no collections specified**: restores **all** dumped collections.
* **If collections listed**: restores **only** those collections.
* Maps each `origDB.coll` → `DB_NAME_RESTORE.coll` safely using `--nsFrom`/`--nsTo` flags.

## 📂 Backup Folder Layout

```bash
backups/
└─ 20250701_121212/      # TIMESTAMP
   └─ Gepe/              # DB_NAME_DUMP
      ├─ collection1.gz
      └─ collection2.gz
```

## 🔄 Restore Flow

* Scans `backups/<TIMESTAMP>/` for subfolders (source DB names).
* For each `<DB_NAME_ORIG>` and each `<COLL>.gz`, runs:

  ```bash
  mongorestore \
    --uri="$MONGO_URI_RESTORE" \
    --gzip --archive=".../<COLL>.gz" \
    --nsFrom="<DB_NAME_ORIG>.<COLL>" \
    --nsTo="$DB_NAME_RESTORE.<COLL>" \
    --numInsertionWorkersPerCollection "$WORKERS"
  ```

* Honors optional list of collections to restore only a subset.

## 📝 Logging

* All **backup** operations append both console and command output to `logs/<TIMESTAMP>.log` via `tee`.
* **Restore** script prints progress to console; customize or redirect output as needed.

## 🛠️ Requirements

* Bash (Linux, macOS, Windows via Git Bash or WSL)
* MongoDB Database Tools (`mongodump`, `mongorestore`) in your `PATH`

## 🤝 Contributing

Feel free to open issues or pull requests for feature requests, bug fixes, or improvements.

---

*Built with care to simplify MongoDB backups and restores in shell.*
