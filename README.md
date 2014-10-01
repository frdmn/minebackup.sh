minebackup.sh
=============

Bash script to backup Minecraft servers using `rdiff-backup` CPU and I/O friendly.

# Commands

    minebackup backup [full]             Backup the server.
    minebackup listbackups               List current incremental backups.
    minebackup restore [<MINUTES>/now]   Restore to snapshot [MINUTES] ago. ("now" for the latest)
    minebackup crons                     List configured cronjobs.
    -debug                               Enable debug output (Must be the last argument).

# Configuration

As you might see, this script creates a configration file in your `$HOME folder.  

Make sure you made all adjustments as your needs for the following variables:

* `SCREENNAME`
* `SERVERNAME`
* `SERVERDIR`
* `BACKUPDIR`
* `FULLBACKUP`
* `BACKUP_QUOTA_MiB`

You can also override:

* `RUNBACKUP_NICE` (`${BIN_NICE} -n19` by default)
* `RUNBACKUP_IONICE` (`${BIN_IONICE} -c 3` by default)
* `SAY_BACKUP_START` (`Backup started...` by default)
* `SAY_BACKUP_FINISHED` (`Backup successfully finished.` by default)

# Installation

## Bash script

    cd /usr/local/src
    git clone https://github.com/frdmn/minebackup.sh.git
    ln -s /usr/local/src/minebackup.sh/minebackup.sh /usr/bin/minebackup
    mkdir -p /opt/backups/minecraft
    chown -R ${USER} /opt/backups

## Cron job examples

To open the crontab in your default editor:

    crontab -e

---

Differential backup every 15 minutes, fullbackup every day at 0:00 am:

    */15 * * * * /usr/bin/minebackup backup
    0 0 * * * /usr/bin/minebackup backup full

Differential backup every 5 minutes, fullbackup 2 days at 5:30 am:

    */5 * * * * /usr/bin/minebackup backup
    30 5 */2 * * /usr/bin/minebackup backup full

Differential backup every 30 minutes, fullbackup every 7 days at 6:45 pm:

    */30 * * * * /usr/bin/minebackup backup
    45 18 */7 * * /usr/bin/minebackup backup full

# Dependencies

You need `rdiff-backup`, `nice`, `ionice` and `tar` to use all features of minebackup.sh:

    apt-get install rdiff-backup nice ionice tar
