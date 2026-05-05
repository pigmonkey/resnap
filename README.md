# resnap

Replaces [rsnapshot](https://rsnapshot.org/) with [restic](https://restic.net/)
for full-disk backups to external USB drives. Each drive gets its own restic
repository. Two scripts are provided: `resnap` for taking backups, and
`resnap-restore` for restoring files after a rebuild.

## Deployment

### 1. Install the scripts and config skeleton

```bash
sudo make install
```

This installs the scripts to `/usr/local/bin/` and copies the config templates
to `/usr/local/etc/resnap/`, skipping any files that already exist. Then
populate each file before running backups. See [Drives](#adding-or-removing-drives),
[Excludes](#modifying-excludes), and [Restore](#populating-the-restore-file) below.

### 2. Populate the password file

```bash
pwgen-passphrase -l 6 | sudo tee /usr/local/etc/resnap/password >/dev/null
```

Keep a copy of this password in a secure location independent of the machine.
Without it the drives cannot be read.

### 3. Initialize repositories

Connect the drives and run the script. It detects missing repositories and
runs `restic init` automatically before the first backup.

## Backup usage

```bash
sudo resnap [mode] [name ...]
```

Connect whichever drives are available before running. The script exits
non-zero if any drive fails. Pass one or more drive names to restrict
processing to those drives only; when names are given, absent or unknown
drives are treated as errors rather than silently skipped.

| Mode          | Backup + prune | Subset check | Full check |
|---------------|:--------------:|:------------:|:----------:|
| `default`     | yes            | yes          |            |
| `backup`      | yes            |              |            |
| `check`       |                | yes          |            |
| `full-check`  |                |              | yes        |

A subset check uses `restic check --read-data-subset=n/20` to verify one
twentieth of the repository's data. Each run advances the counter by one,
stored in `check.subset` at the root of the drive, so the full repository is
covered across 20 runs. `full-check` reads all data in a single pass and
resets the counter, since it supersedes the rolling cycle.

After each backup, the restic binary and `resnap-restore` script are copied to
a `recover/` directory at the root of the drive. On a fresh machine, these can
be used directly from the mounted drive without installing anything first.

## Restore usage

```bash
sudo resnap-restore [--bootstrap] [--uuid UUID] [drive-name [snapshot]]
```

Connect a drive and run. If only one drive is present it is selected
automatically; if multiple are connected, specify the drive name. `snapshot`
accepts a restic snapshot ID or `latest` (default).

On a fresh rebuild, config files may not yet be present:

- If the **password file** is missing or empty, the script prompts for the
  passphrase and writes it to `/usr/local/etc/resnap/password`.
- If the **drives file** is missing or empty, the script enumerates connected
  drives and exits with instructions to rerun using `--uuid <uuid>`.
- If the **restore file** is missing or empty, pass `--bootstrap` to fetch it
  from the snapshot before proceeding. If it is already present and non-empty
  locally it is used as-is regardless of `--bootstrap`.

The restore is resumable: `--overwrite if-changed` skips files whose mtime
and size already match the snapshot (fast path), and re-restores any partial
file detected via blob-level verification. Kill and restart freely.

The list of paths to restore is read from
`/usr/local/etc/resnap/restore`. Edit it to add or remove paths before
running. Paths must be absolute.

## Adding or removing drives

Edit `/usr/local/etc/resnap/drives`. Each non-comment line is two
whitespace-separated fields:

```
name  uuid
```

The name is used only for logging and check-state tracking. The UUID must
match the filesystem UUID of the drive (`lsblk -o NAME,UUID`).

## Modifying excludes

Edit `/usr/local/etc/resnap/excludes`. One pattern per line; lines
beginning with `#` are ignored. Patterns follow restic exclude syntax (same
as `--exclude`). Virtual filesystems (`/proc`, `/sys`, `/dev`, `/run`) and
other mounted filesystems (`/mnt`, `/media`) do not need to be listed here
as they are already excluded via `--one-file-system`.

## Populating the restore file

Edit `/usr/local/etc/resnap/restore`. One absolute path per line; lines
beginning with `#` are ignored. Each path is passed as an `--include`
argument to `restic restore`, so restic glob syntax is supported (e.g.
`/home/user/.config/app*`). List every path you want recovered after a
rebuild — personal config directories, dotfiles, application data, and so on.

Because this file is itself included in backups (it lives under
`/usr/local/etc/`), `resnap-restore --bootstrap` can fetch it from the
snapshot on a fresh machine before the local copy exists.
