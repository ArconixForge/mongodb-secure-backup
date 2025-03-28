# MongoDB Backup Helm Chart

A production-ready Helm chart for deploying a MongoDB backup solution on GKE with focus on security, reliability, and ease of use.

## Overview

This Helm chart deploys a secure MongoDB backup tool that provides scheduled backups of your MongoDB databases with encryption, compression, and configurable retention. The chart is optimized for Google Kubernetes Engine (GKE) deployments.

## Features

- Scheduled backups using Kubernetes CronJobs
- Strong encryption using AES-256-GCM
- Multiple compression options (zlib, gzip, lzma)
- Selective database and collection backup
- Advanced filtering capabilities
- Secure storage with GKE persistent volumes
- Comprehensive RBAC configuration
- Deployment optimized for GKE

## Prerequisites

- Kubernetes 1.19+ (GKE 1.19+)
- Helm 3.2.0+
- PV provisioner support in GKE
- Access to a MongoDB instance

## Installation

### Creating custom values file

Create a `custom-values.yaml` file to override default values:

```yaml
connection:
  host: your-mongodb-host
  port: 27017
  username: your-mongodb-username
  password: your-mongodb-password
  useSSL: true

persistence:
  size: 50Gi  # Adjust based on your backup size requirements
  storageClass: "standard-rwo"  # GKE standard storage class

security:
  encryptionEnabled: true
  # Leave password empty for auto-generation or set a secure password

schedule:
  cronExpression: "0 1 * * *"  # Daily at 1:00 AM
```

### Installing the chart

```bash
# Add the repository (if hosted in a repository)
# helm repo add myrepo https://example.com/charts
# helm repo update

# Install from local directory
helm install mongodb-backup ./charts/mongodb-backup \
  --values custom-values.yaml \
  --namespace mongodb-backup \
  --create-namespace
```

### Verifying the installation

```bash
# Check the status of the release
helm status mongodb-backup -n mongodb-backup

# Check if the CronJob was created
kubectl get cronjobs -n mongodb-backup

# Check if the PVC was created
kubectl get pvc -n mongodb-backup
```

## Uninstalling the Chart

To uninstall/delete the `mongodb-backup` deployment:

```bash
helm uninstall mongodb-backup -n mongodb-backup
```

Note: This will not delete the PVC with the backup data. If you want to delete the backup data as well:

```bash
kubectl delete pvc mongodb-backup-backup-data -n mongodb-backup
```

## Configuration

### Critical Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `connection.host` | MongoDB host | `127.0.0.1` |
| `connection.port` | MongoDB port | `27017` |
| `connection.username` | MongoDB username | `""` |
| `connection.password` | MongoDB password | `""` |
| `persistence.size` | Size of the backup PVC | `20Gi` |
| `security.encryptionEnabled` | Enable encryption | `true` |
| `security.encryptionPassword` | Password for encryption | `""` (auto-generated if empty) |
| `schedule.cronExpression` | Schedule for backups | `"0 1 * * *"` (daily at 1:00 AM) |

### MongoDB Connection Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `connection.authDb` | Authentication database | `admin` |
| `connection.useSSL` | Use SSL for MongoDB connection | `false` |
| `connection.sslCAFile` | SSL CA file path | `""` |
| `connection.connectionTimeoutMs` | Connection timeout in milliseconds | `30000` |

### Backup Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `export.prettyJson` | Use pretty formatting for JSON exports | `true` |
| `export.maxConcurrentExports` | Maximum concurrent export operations | `3` |
| `export.retryAttempts` | Number of retry attempts for failed exports | `3` |
| `export.retryDelaySeconds` | Delay between retry attempts | `2` |
| `export.chunkSize` | Chunk size for large collections | `1000` |

### Filters and Exclusions

| Parameter | Description | Default |
|-----------|-------------|---------|
| `filters.excludeDbs` | Comma-separated list of databases to exclude | `"admin,local,config"` |
| `filters.excludeCollections` | Comma-separated list or patterns of collections to exclude | `"system.*"` |

### Security Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `security.compressionMethod` | Compression method (none, zlib, gzip, lzma) | `lzma` |
| `security.compressionLevel` | Compression level (1-9) | `9` |

### Schedule Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `schedule.enabled` | Enable scheduled backups | `true` |
| `schedule.successfulJobsHistoryLimit` | Number of successful jobs to keep | `3` |
| `schedule.failedJobsHistoryLimit` | Number of failed jobs to keep | `3` |
| `schedule.concurrencyPolicy` | How to handle concurrent executions | `Forbid` |
| `schedule.backoffLimit` | Number of retries before considering a Job as failed | `3` |
| `schedule.activeDeadlineSeconds` | Timeout for backup jobs | `3600` (1 hour) |

### GKE Specific Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.storageClass` | Storage class for the PVC | `"standard-rwo"` |
| `persistence.accessMode` | Access mode for the PVC | `ReadWriteOnce` |
| `nodeSelector` | Node selector for pod assignment | `{}` |
| `tolerations` | Tolerations for pod assignment | `[]` |
| `affinity` | Affinity for pod assignment | `{}` |

## Usage

### Manual Backups

To trigger a manual backup outside of the schedule:

```bash
kubectl create job --from=cronjob/mongodb-backup manual-backup-$(date +%s) -n mongodb-backup
```

### Viewing Backup Status

To check the status of a running backup job:

```bash
kubectl get jobs -n mongodb-backup
```

To view the logs of a backup job:

```bash
kubectl get pods -n mongodb-backup -l job-name -o name | grep -v completed | head -1 | xargs kubectl logs -n mongodb-backup
```

### Accessing Backup Data

The backup data is stored in the Persistent Volume Claim. To access it, you can create a temporary pod:

```bash
kubectl run backup-viewer --image=busybox -i --tty --rm \
  --overrides='{"spec": {"volumes": [{"name": "backup-data", "persistentVolumeClaim": {"claimName": "mongodb-backup-backup-data"}}], "containers": [{"name": "backup-viewer", "image": "busybox", "command": ["sh"], "stdin": true, "tty": true, "volumeMounts": [{"mountPath": "/backups", "name": "backup-data"}]}]}}' \
  -n mongodb-backup -- sh
```

## Security Considerations

This chart implements several security best practices:

1. Runs as a non-root user with the least privileges necessary
2. Uses a read-only root filesystem
3. Drops all container capabilities
4. Prevents privilege escalation
5. Sets proper RBAC permissions
6. Encrypts sensitive backup data

## Backup Encryption

When `security.encryptionEnabled` is set to `true`, all backups are encrypted using AES-256-GCM. The encryption password is either provided in `security.encryptionPassword` or automatically generated and stored in a Kubernetes Secret.

Ensure you securely store the encryption password, as it will be needed to restore from these backups.

## GKE-specific Optimizations

This chart is optimized for running on Google Kubernetes Engine with:

1. Compatible storage classes for GKE
2. Resource requests and limits suited for GKE environments
3. Security settings that comply with GKE security best practices



# MongoDB Secure Backup Features

## Advanced Backup Capabilities

This Helm chart integrates with a specialized MongoDB backup tool that provides:

- **Flexible Export Options**: Export selected databases or collections as JSON
- **Industry-standard Encryption**: AES-256-GCM encryption for sensitive data
- **Multiple Compression Options**: zlib, gzip, or lzma compression with configurable levels
- **Secure Archive Creation**: Combines all exports into a single encrypted and compressed archive
- **Data Integrity Verification**: HMAC verification ensures backup integrity
- **Error Handling**: Automatic retry mechanism with configurable attempts and delay
- **Parallel Processing**: Configurable concurrent export operations for performance
- **Progress Tracking**: Detailed reporting and monitoring

## Backup Tool Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `backupTool.createArchive` | Create a single encrypted archive of all exports | `true` |
| `backupTool.deleteOriginal` | Delete original files after archive creation | `true` |
| `backupTool.saveDbInfo` | Save database metadata as JSON | `true` |

## Recovering from Backups

### Method 1: Using the Backup Browser

For simple recovery or to verify backups:

```bash
# Create a pod to browse the backup files
kubectl run backup-viewer --image=busybox -i --tty --rm \
  --overrides='{"spec": {"volumes": [{"name": "backup-data", "persistentVolumeClaim": {"claimName": "mongodb-backup-backup-data"}}], "containers": [{"name": "backup-viewer", "image": "busybox", "command": ["sh"], "stdin": true, "tty": true, "volumeMounts": [{"mountPath": "/backups", "name": "backup-data"}]}]}}' \
  -n mongodb-backup -- sh

# Inside the pod, list available backups
ls -la /backups
```

### Method 2: Copy Backups Locally

To copy backup files for external processing:

```bash
# First, identify the backup files
kubectl run backup-lister --image=busybox --restart=Never -n mongodb-backup \
  --overrides='{"spec": {"volumes": [{"name": "backup-data", "persistentVolumeClaim": {"claimName": "mongodb-backup-backup-data"}}], "containers": [{"name": "backup-lister", "image": "busybox", "command": ["ls", "-la", "/backups"], "volumeMounts": [{"mountPath": "/backups", "name": "backup-data"}]}]}}' 

# Check the output
kubectl logs backup-lister -n mongodb-backup

# Then copy a specific backup file to your local machine
kubectl cp mongodb-backup/backup-viewer:/backups/mongodb_backup_20250101_010101.mdb ./local-backup.mdb
kubectl cp mongodb-backup/backup-viewer:/backups/mongodb_backup_20250101_010101.mdb.meta.json ./local-backup.mdb.meta.json

# Clean up the temporary pod
kubectl delete pod backup-lister -n mongodb-backup
```

### Method 3: Restore Using the Backup Tool Container

For full restoration using the backup tool:

```bash
# 1. Create a restoration values file
cat > restore-values.yaml << EOF
connection:
  host: target-mongodb-host
  port: 27017
  username: target-mongodb-username
  password: target-mongodb-password
  
# Disable scheduled backups for restore job
schedule:
  enabled: false
EOF

# 2. Deploy a restore pod
kubectl run mongodb-restore --image={{ .Values.image.repository }}:{{ .Values.image.tag }} \
  -n mongodb-backup \
  --overrides='{"spec": {"volumes": [{"name": "backup-data", "persistentVolumeClaim": {"claimName": "mongodb-backup-backup-data"}}], "containers": [{"name": "mongodb-restore", "image": "{{ .Values.image.repository }}:{{ .Values.image.tag }}", "command": ["/app/entrypoint.sh"], "args": ["--restore-archive", "/backups/mongodb_backup_20250101_010101.mdb", "--target-dir", "/tmp/restore"], "env": [{"name": "ENCRYPTION_PASSWORD", "valueFrom": {"secretKeyRef": {"name": "mongodb-backup-secret", "key": "ENCRYPTION_PASSWORD"}}}], "volumeMounts": [{"mountPath": "/backups", "name": "backup-data"}]}]}}' 

# 3. Check the restoration logs
kubectl logs -f mongodb-restore -n mongodb-backup
```

## Understanding Backup File Types

The backup tool creates several types of files:

1. **JSON Exports** (.json): Direct exports from MongoDB collections
2. **Secure Archives** (.mdb): Encrypted and compressed archives of all exports
3. **Metadata Files** (.meta.json): Information about the backup including encryption parameters
4. **Database Info** (database_info.json): Overview of database structure and statistics
5. **Export Reports** (export_report.json): Detailed report of the export process

When `backupTool.createArchive` is enabled, individual JSON files are combined into a single .mdb archive file for easier management.


## Troubleshooting

### Common Issues

1. **MongoDB Connection Issues**: 
   - Ensure the MongoDB credentials are correct
   - Check network connectivity between the backup pod and MongoDB
   - Verify SSL settings if SSL is enabled

2. **Permission Issues**:
   - Make sure the MongoDB user has appropriate permissions for database backup
   - Check if the Kubernetes service account has the necessary permissions

3. **Storage Issues**:
   - Verify that the PVC is correctly bound and has sufficient space
   - Check if the storage class exists and is compatible with GKE

### Debugging Tips

To check the logs of the last backup job:

```bash
kubectl get pods -n mongodb-backup | grep mongodb-backup | head -1 | awk '{print $1}' | xargs kubectl logs -n mongodb-backup
```

To check the configuration used for backups:

```bash
kubectl get configmap mongodb-backup-config -n mongodb-backup -o yaml
```

## License

Copyright &copy; 2025 YourName

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.