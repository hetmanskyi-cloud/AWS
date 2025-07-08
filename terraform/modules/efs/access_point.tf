# --- EFS Access Point Resource --- #
# This file defines the EFS Access Point to provide a secure, application-specific
# entry point into the EFS file system.

resource "aws_efs_access_point" "default" {

  file_system_id = aws_efs_file_system.efs.id

  posix_user {
    uid = var.efs_access_point_posix_uid
    gid = var.efs_access_point_posix_gid
  }

  root_directory {
    path = var.efs_access_point_path

    # This block ensures that the specified directory is automatically created
    # with the correct ownership and permissions on first access if it doesn't exist.
    creation_info {
      owner_uid   = var.efs_access_point_posix_uid
      owner_gid   = var.efs_access_point_posix_gid
      permissions = "755"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-efs-ap-${var.environment}"
  })
}

# --- Notes --- #
# 1. **Purpose**:
#    - The Access Point acts as a secure gateway to the EFS. Instead of mounting the entire
#      file system root, applications mount the Access Point.
#
# 2. **Security Features**:
#    - `posix_user`: Enforces that all file operations through this Access Point are performed
#      with the specified User ID (UID) and Group ID (GID). In our case, this is 'www-data' (33),
#      which prevents applications from writing files as the 'root' user.
#    - `root_directory`: Restricts the application to a specific path within the EFS,
#      providing strong logical isolation.
#
# 3. **Automatic Directory Creation**:
#    - The `creation_info` block is a key feature that simplifies setup. It automatically
#      creates the target directory (`/wordpress` by default) with the correct permissions,
#      so no manual setup is required on the file system.
