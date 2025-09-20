The project was implemented as part of setting up a server backup system for the EdTech startup Scientific and Technical School "A5 School"

## Quick start
1. Download the project
```bash
git clone https://github.com/skewer33/local_backup_utility.git
```

2. Configure the following in the configuration file:
	- path to save backups (`BACKUP_DIR`)
	- paths to directories to be backed up (`SOURCE_DIR`)
	- database containers to be backed up (`SOURCE_DB`)
```
cd make_backup
nano backup.conf
```

3. You can configure Cron manually later, or use automatic settings. To do this, go to example_cron and enter the `path/to/the/project` directory in the `CRONDIR` variable.
```
pwd #copy
nano example_cron.txt
```

3. Apply the configuration settings, allow the current user to make backups of the selected directories
```
chmod +x setup_backup.sh
./setup_backups.sh
```
4. DONE. Now a full file backup will be created every Sunday, and incremental file backups will be created on other days of the week. Databases will be fully backed up daily.
## Structure

| File                         | Description                                                                                                                                                                                                                           |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `backup.conf`                | Configuration file. It specifies the location of the backup and which directories and databases should be backed up.                                                                                                                  |
| `make_dir_backup_locally.sh` | Makes a backup of the files specified in the `SOURCE_DIR` in the `backup.conf`. <br>A full backup is performed every Sunday, and an incremental backup is performed on other days of the week, based on the last full backup.         |
| `make_db_backup_locally.sh`  | Makes a backup of the files specified in the `SOURCE_DB` in the `backup.conf`.<br>At each startup, it makes a full backup of the databases (currently, only backups of Postgres databases running in Docker containers are supported) |
| `restore_backup_locally.sh`  | Restores backups of directories and databases to a specified date. <br>Runs as `sudo ./restore_backup_locally.sh`.                                                                                                                    |
| `cleanup_local_backups.sh`   | Deletes old backups. Keeps full backups for the last two weeks and incremental backups for the last week.                                                                                                                             |
| `setup_backup.sh`            | Automatic configuration file. Grants copy access to directories specified in `SOURCE_DIR`, makes backup scripts executable, and creates a cron schedule based on the `example_cron.txt` file.                                         |
| `example_cron.txt`           | An example of a cron schedule file. You can modify it to suit your needs and call `sudo ./setup_backup.sh`, or enter everything manually using `crontab -e`                                                                           |

## Make backup
If you used the quick start feature, your backup is already configured. You can change its schedule:
```
crontab -e
```
Or check that the backup is working by running the scripts manually:
```
./make_dir_backup_locally.sh
./make_db_backup_locally.sh
```
## Restore backup
To restore backups, enter the following command with the **checkpoint date** parameter in the `yyyy-mm-dd` format. This parameter is optional: today's date is selected by default.

The restore starts **from** the **last full backup** since the checkpoint date, overlaid with **incremental backups** created **no later** than the **checkpoint date**.
```
sudo ./restore_backup_locally.sh 2025-09-20
```

## Logs
Currently, logging occurs in the folder you specified in the backup.conf file.
## Ideas for improvement

The current implementation revealed a number of issues related to the system's monolithic nature. The system is suitable for continuous use and performs its functions. However, if a manual full backup is required outside of a scheduled time, this could be problematic. Therefore, it would be better to rethink the system's structure as follows:

- Full directory backup once a week (`make_full_file_backup_locally.sh`)
- Incremental directory backup once a day (`make_ink_file_backup_locally.sh`)
- Full database backup every 2 days (`make_full_db_backup_locally.sh`)
- Restore partial directories on sudo request (`restore_file_backup_locally.sh`)
- Restore all directories on sudo request (`restore_full_file_backup_locally.sh`)
- Restore partial database on sudo request (`restore_db_backup_locally.sh`)
- Restore all databases on sudo request (`restore_full_db_backup_locally.sh`)
- Cleanup of old backups (`cleanup_local_backups.sh`)
- Manage backup schedules and cleanup of old backups via cron
- The backup configuration is configured in the file `backup.conf`

In addition, the next step should be a remote backup system.
