#!/bin/bash

# Constants — all overridable via environment variables
readonly LOG_FILE="${LOG_FILE:-/var/log/minecraft-backup.log}"
readonly BACKUP_DIR="${BACKUP_DIR:-/home/ubuntu/docker/minecraft/backups}"
readonly NFS_SERVER_ADDRESS="${NFS_SERVER_ADDRESS:-home}"
readonly NFS_SHARE="${NFS_SHARE:-/mnt/internal/2/nfs/backup/minecraft}"
readonly MOUNT_DIR="${MOUNT_DIR:-/mnt/backup/minecraft}"

log_message() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp: $message" | tee -a "$LOG_FILE"
}

handle_error() {
    local message="$1"
    local exit_code="$2"
    log_message "ERROR: $message"
    exit "$exit_code"
}

mount_nfs_share() {
    if mount | grep "on ${MOUNT_DIR} type nfs" > /dev/null; then
    echo "Already mounted"
    else
        mount -t nfs "${NFS_SERVER_ADDRESS}:${NFS_SHARE}" "${MOUNT_DIR}" || handle_error "Mount failed. Please check your settings." 1
    fi
}

perform_rsync() {
    rsync -az --delete "${BACKUP_DIR}/" "${MOUNT_DIR}/" || handle_error "Rsync failed. Please check your settings." 1
}

unmount_nfs_share() {
    if mount | grep "on ${MOUNT_DIR} type nfs" > /dev/null; then
        umount "$MOUNT_DIR" || handle_error "Unmount failed. Please check your settings." 1
    fi
}

main() {

    log_message "Mounting NFS share."
    mount_nfs_share
    log_message "NFS share mounted successfully."

    log_message "Performing rsync."
    perform_rsync
    log_message "Rsync performed successfully."

    log_message "Unmounting NFS share."
    unmount_nfs_share
    log_message "NFS share unmounted successfully."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi
