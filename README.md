minebackup.sh
=============

Bash script to backup Minecraft servers using rdiff-backup CPU and I/O friendly.

# Commands

    minebackup backup [full]             Backup the server.
    minebackup listbackups               List current incremental backups.
    minebackup restore [<MINUTES>/now]   Restore to snapshot [MINUTES] ago. ("now" for the latest)
    minebackup crons                     List configured cronjobs.
    -debug                               Enable debug output (Must be the last argument).

# Installation

    cd /tmp
    git clone git@github.com:frdmn/minebackup.sh.git
    mv minebackup.sh/minebackup.sh /usr/bin/minebackup
    chmod +x /usr/bin/minebackup
    mkdir -p /opt/backups/minecraft
    chown -R <$user> /opt/backups

# Depencies

You need `rdiff-backup`, `nice`, `ionice` and `tar` to use all features of minebackup.sh:

    apt-get install rdiff-backup nice ionice tar