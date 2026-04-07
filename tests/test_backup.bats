#!/usr/bin/env bats
# Unit tests for backup.sh

setup() {
  TEST_TMP="$(mktemp -d)"
  export TEST_TMP

  # Mock 'tee' so log_message doesn't fail trying to write /var/log/minecraft-backup.log
  tee() { cat; }

  # Mock infrastructure commands — overridden per-test as needed
  mount()  { echo ""; }
  rsync()  { return 0; }
  umount() { return 0; }

  # shellcheck source=../backup.sh
  source "${BATS_TEST_DIRNAME}/../backup.sh"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ---------------------------------------------------------------------------
# log_message
# ---------------------------------------------------------------------------

@test "log_message prints a timestamped message to stdout" {
  run log_message "hello test"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hello test"* ]]
}

# ---------------------------------------------------------------------------
# handle_error
# ---------------------------------------------------------------------------

@test "handle_error exits with the given exit code" {
  run handle_error "something broke" 42
  [ "$status" -eq 42 ]
}

@test "handle_error includes ERROR in its output" {
  run handle_error "disk full" 1
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" == *"disk full"* ]]
}

# ---------------------------------------------------------------------------
# mount_nfs_share
# ---------------------------------------------------------------------------

@test "mount_nfs_share reports already mounted when share is present" {
  mount() { echo "nfs on ${MOUNT_DIR} type nfs (rw)"; }
  run mount_nfs_share
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already mounted"* ]]
}

@test "mount_nfs_share mounts when share is absent and mount succeeds" {
  # First call (no args) → not mounted; second call (-t nfs ...) → success
  mount() {
    [[ $# -eq 0 ]] && echo "" || return 0
  }
  run mount_nfs_share
  [ "$status" -eq 0 ]
}

@test "mount_nfs_share errors when mount command fails" {
  mount() {
    [[ $# -eq 0 ]] && echo "" || return 1
  }
  run mount_nfs_share
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
}

# ---------------------------------------------------------------------------
# perform_rsync
# ---------------------------------------------------------------------------

@test "perform_rsync succeeds when rsync exits 0" {
  rsync() { return 0; }
  run perform_rsync
  [ "$status" -eq 0 ]
}

@test "perform_rsync errors when rsync exits non-zero" {
  rsync() { return 23; }
  run perform_rsync
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
}

# ---------------------------------------------------------------------------
# unmount_nfs_share
# ---------------------------------------------------------------------------

@test "unmount_nfs_share unmounts when share is mounted" {
  mount()  { echo "nfs on ${MOUNT_DIR} type nfs (rw)"; }
  umount() { return 0; }
  run unmount_nfs_share
  [ "$status" -eq 0 ]
}

@test "unmount_nfs_share skips when share is not mounted" {
  mount() { echo ""; }
  run unmount_nfs_share
  [ "$status" -eq 0 ]
}

@test "unmount_nfs_share errors when umount fails" {
  mount()  { echo "nfs on ${MOUNT_DIR} type nfs (rw)"; }
  umount() { return 1; }
  run unmount_nfs_share
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
}
