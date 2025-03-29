# MongoDB Secure Backup

A production-ready MongoDB backup solution with advanced security features, containerization, and Kubernetes deployment options.

![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)

## Features

- **Secure Backups**: AES-256-GCM encryption for sensitive data
- **Flexible Compression**: Multiple compression options (zlib, gzip, lzma)
- **Comprehensive Exports**: Export selected databases or collections
- **Containerized**: Docker image for easy deployment
- **Kubernetes-Ready**: Helm chart for GKE and other Kubernetes environments
- **Parallel Processing**: Configurable concurrent export operations
- **Data Integrity**: HMAC verification ensures backup integrity
- **Customizable Filtering**: Include/exclude specific databases or collections

## Quick Start

### Running with Docker

```bash
docker run -v /path/to/backups:/backups \
  -e MONGO_HOST=your-mongodb-host \
  -e MONGO_USERNAME=root \
  -e MONGO_PASSWORD=yourpassword \
  -e ENCRYPTION_ENABLED=true \
  -e ENCRYPTION_PASSWORD=yourencryptionkey \
  arconixforge/mongodb-secure-backup:1.0.0 auto-backup
```

### Running with Kubernetes using Helm

1. Add the repository (once hosted)
```bash
# helm repo add arconixforge https://charts.arconixforge.com
# helm repo update
```

2. Install the chart with custom values
```bash
# Create a custom values file
cat > custom-values.yaml << EOF
connection:
  host: your-mongodb-host
  port: 27017
  username: your-mongodb-username
  password: your-mongodb-password
  useSSL: true

persistence:
  size: 50Gi  # Adjust based on your backup size requirements
  storageClass: "standard-rwo"  # Use appropriate storage class

security:
  encryptionEnabled: true
  encryptionPassword: "securepassword"  # Better to leave empty for auto-generation

schedule:
  cronExpression: "0 1 * * *"  # Daily at 1:00 AM
EOF

# Install the chart
helm install mongodb-backup ./charts/mongodb-secure-backup \
  --values custom-values.yaml \
  --namespace mongodb-backup \
  --create-namespace
```

## Backup Storage and Retrieval

The backup tool stores data in a structured format to facilitate easy management and retrieval.

### Understanding Backup Storage Structure

When deployed with Kubernetes, backups are stored on a Persistent Volume Claim (PVC) with the following directory structure:

```
/backup-data/
├── db-exports/           # Raw database exports (JSON)
├── db-info/              # Database metadata and structure
└── archives/             # Encrypted backup archives (.mdb files)
```

### Backup Files

The tool generates several types of files:

1. **JSON Exports** (.json): Direct exports from MongoDB collections
2. **Secure Archives** (.mdb): Encrypted and compressed archives of all exports
3. **Metadata Files** (.meta.json): Information about encryption parameters
4. **Database Info** (database_info.json): Overview of database structure

### Accessing Backup Data from PVC

#### Method 1: Using a Temporary Pod to Browse Backups

```bash
# Create a pod to browse the backup files
kubectl run backup-viewer --image=busybox -i --tty --rm \
  --overrides='{"spec": {"volumes": [{"name": "backup-data", "persistentVolumeClaim": {"claimName": "mongodb-backup-backup-data"}}], "containers": [{"name": "backup-viewer", "image": "busybox", "command": ["sh"], "stdin": true, "tty": true, "volumeMounts": [{"mountPath": "/backups", "name": "backup-data"}]}]}}' \
  -n mongodb-backup -- sh

# Inside the pod, list available backups
ls -la /backups/archives/
```

#### Method 2: Copying Backup Files to Local Machine

```bash
# First, create a temporary pod to access the PVC
kubectl run backup-access --image=busybox --restart=Never -n mongodb-backup \
  --overrides='{"spec": {"volumes": [{"name": "backup-data", "persistentVolumeClaim": {"claimName": "mongodb-backup-backup-data"}}], "containers": [{"name": "backup-access", "image": "busybox", "command": ["sleep", "3600"], "volumeMounts": [{"mountPath": "/backups", "name": "backup-data"}]}]}}' 

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/backup-access -n mongodb-backup

# List available backups
kubectl exec -it backup-access -n mongodb-backup -- ls -la /backups/archives/

# Copy a specific backup file to your local machine
kubectl cp mongodb-backup/backup-access:/backups/archives/mongodb_backup_20250101_010101.mdb ./local-backup.mdb
kubectl cp mongodb-backup/backup-access:/backups/archives/mongodb_backup_20250101_010101.mdb.meta.json ./local-backup.mdb.meta.json

# Clean up the temporary pod when done
kubectl delete pod backup-access -n mongodb-backup
```

### Restoring from Backups

#### Option 1: Restore Using the Backup Tool Container

```bash
# Create a restoration values file
cat > restore-values.yaml << EOF
connection:
  host: target-mongodb-host
  port: 27017
  username: target-mongodb-username
  password: target-mongodb-password
  
security:
  encryptionEnabled: true
  encryptionPassword: "same-password-used-for-backup"
  
# Disable scheduled backups for restore job
schedule:
  enabled: false
EOF

# Deploy a restore pod
kubectl run mongodb-restore --image=arconixforge/mongodb-secure-backup:1.0.0 \
  -n mongodb-backup \
  --overrides='{"spec": {"volumes": [{"name": "backup-data", "persistentVolumeClaim": {"claimName": "mongodb-backup-backup-data"}}], "containers": [{"name": "mongodb-restore", "image": "arconixforge/mongodb-secure-backup:1.0.0", "command": ["/app/entrypoint.sh"], "args": ["--restore-archive", "/backups/archives/mongodb_backup_20250101_010101.mdb", "--target-dir", "/tmp/restore"], "env": [{"name": "ENCRYPTION_PASSWORD", "value": "same-password-used-for-backup"}], "volumeMounts": [{"mountPath": "/backups", "name": "backup-data"}]}]}}' 

# Check the restoration logs
kubectl logs -f mongodb-restore -n mongodb-backup
```

#### Option 2: Manual Restore from Extracted Archives

1. Copy and extract the archive locally
2. Use MongoDB import tools on the extracted JSON files:

```bash
# For each extracted collection file
mongoimport --host target-mongodb-host \
  --port 27017 \
  --username your-username \
  --password your-password \
  --authenticationDatabase admin \
  --db database_name \
  --collection collection_name \
  --file /path/to/extracted/collection.json
```

## Troubleshooting Backup and Recovery

### Common Issues

1. **Cannot access PVC data**:
   - Ensure your pods have the correct permissions to mount the PVC
   - Check if the PVC is bound: `kubectl get pvc -n mongodb-backup`
   - Verify the PVC has sufficient space: `kubectl describe pvc mongodb-backup-backup-data -n mongodb-backup`

2. **Encryption/Decryption failures**:
   - Ensure you're using the same encryption password used during backup
   - Check if the .meta.json file is present alongside the .mdb file
   - Verify that both the archive and metadata files are complete and not corrupted

3. **MongoDB Connection Issues**:
   - Check network connectivity between backup pod and MongoDB
   - Verify authentication credentials are correct
   - Ensure the MongoDB user has appropriate backup permissions

### Viewing Backup Logs

```bash
# Get the latest backup job pod
BACKUP_POD=$(kubectl get pods -n mongodb-backup -l app.kubernetes.io/name=mongodb-backup -o name | head -1)

# View the logs
kubectl logs $BACKUP_POD -n mongodb-backup
```

## Building and Customizing

### Building the Docker Image

```bash
# Download required packages
./prepare-packages.sh

# Build the Docker image
./build-image.sh
```

### Customizing the Backup Configuration

The most important configuration parameters:

* **MongoDB Connection**: Host, port, authentication
* **Encryption**: Enable/disable, password, method
* **Compression**: Method (zlib, gzip, lzma), level
* **Filters**: Databases or collections to exclude
* **Schedule**: Cron expression for automated backups

See the `values.yaml` file in the Helm chart for the complete list of configuration options.

## Security Considerations

This tool implements several security best practices:

1. **Strong encryption** using AES-256-GCM for sensitive data
2. **Non-root execution** with minimal privileges
3. **Encrypted archives** with integrity verification
4. **Secure password handling** via Kubernetes secrets
5. **Read-only containers** when deployed via Helm chart

## License

Copyright © 2025 ArconixForge

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.