# moxie: the Proxmox host

Decisions for reinstalling jeeves's hardware as moxie, a Proxmox VE host,
with jeeves rebuilt as a VM on it (`docs/jeeves-restore.md` has the backup
and restore). Written down before the old jeeves was backed up for the last
time, so that they can be read from another machine while moxie is installed.

## The hardware

- Lenovo ThinkCentre M910q Tiny: 4 cores (no hyperthreading), 32 GB of RAM,
  which is believed to be its maximum (unverified).
- **NVMe:** Samsung MZVLW256HEHP, 256 GB (238.5 GiB), PCIe 3.0 x4. It holds
  the old jeeves (Pop!_OS) until moxie is installed on it.
- **SATA SSD:** Inland SATA SSD, 1 TB (953.9 GiB), new, unpartitioned. Its
  SMART status was healthy when installed (2026-11-15): no bad sectors, no
  failing attributes, 40 °C.
- **Backup drive:** Seagate Portable, 1 TB, NTFS, USB ID `0bc2:2344`.

Facts about the old jeeves, kept for after it is gone:

- Its network card's MAC address is `00:23:24:f2:4b:39`, and its LAN address
  was 192.168.86.30. moxie keeps that card, so it keeps that MAC address.
- Its SSH host key fingerprints, which the jeeves VM should show once
  `setup` has restored them (`ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`
  on it, or the fingerprint ssh shows when a machine connects):
  - ED25519 `SHA256:Ot1u2z+jO+reM/7iZYpl5b/OBxs0Te4iNdhSKZjLBis`
  - ECDSA `SHA256:iAkxbQOHvq2MNawZfQ2mmLu0XDxuNi7zgfkpGofHu8k`
  - RSA `SHA256:jOX7Zpie9rlpLi+W2VnTNwCuTc60HpXLnwpd0M4uA8M`

## Decisions

- **The two internal disks are repaved:** the NVMe (the old jeeves) and the
  SATA SSD (new and empty). Nothing of the old jeeves is kept on them.
- **The Seagate USB drive is not:** it holds the backups that the jeeves VM is
  restored from, and stays NTFS and mounted at `/mnt/backups` in the VM.
- **One VM is jeeves,** with everything the old jeeves ran (Immich,
  Syncthing, Postfix and Dovecot, the Claude Code environments), so that
  `hosts/jeeves` still applies. Services may be split into their own guests
  later. moxie itself stays bare: Proxmox only, with nothing of jeeves's on
  it, so that it is easy to upgrade or reinstall.
- **The Kubernetes lab** gets VMs of its own, on the NVMe. Kubernetes keeps
  its state in etcd, which waits for every write to reach the disk, so the
  faster disk suits it best. A few lab VMs of 30 to 40 GB fit in what the
  NVMe has left after moxie's root, and keeping them off the SATA SSD keeps
  their disk traffic away from jeeves's.
- **ext4 on LVM-thin, not ZFS.** ZFS was considered. Proxmox's installer
  caps its cache at 10 % of RAM (about 3.2 GB here), which is about what
  Proxmox's rule of thumb asks for this storage, so RAM alone did not rule
  it out. But the disks differ in size, so they cannot be mirrored, and
  striping them would lose everything with either disk. ZFS also writes
  more, which wears consumer SSDs faster (from Proxmox forum experience; its
  documentation does not say). Its checksums, compression and replication
  did not outweigh that.
- **Proxmox goes on the NVMe,** the faster disk, with a small root, so that
  most of the NVMe is left for fast VM storage. The SATA SSD becomes the
  large pool, for jeeves's disk.

## Installing moxie

Only after the final backup (`./backup-host --final`) has passed its check
and the old jeeves is powered off: installing on the NVMe destroys it.

**Unplug the Seagate first,** and keep it unplugged until moxie is installed
and the SATA SSD's storage pool exists. Both it and the SATA SSD are 1 TB,
and the Seagate is the one with partitions, so a disk chosen by size or by
having partitions could be the drive holding every backup. Plugged in, it
would likely be `/dev/sda` in the installer, perhaps its default target
(unverified). Pick disks by model only: the NVMe is the Samsung
`MZVLW256HEHP`, the SATA SSD the `Inland SATA SSD`, and the Seagate shows as
`Portable`. Under `/dev/disk/by-id/` their names carry the model too.

1. In the installer:
   - **Target disk:** the NVMe, the Samsung `MZVLW256HEHP`. Filesystem
     **ext4**. Under the disk's advanced options, set a small root size
     (`maxroot`), for example 32 GB, so that most of the NVMe goes to
     `local-lvm`. What the installer would otherwise choose is unverified.
   - **Hostname:** `moxie.lan` (the installer wants a full name).
   - **Network:** the installer gives moxie a static address. Use one the
     router will not hand to anything else (reserve it, or take one outside
     its DHCP range). The web UI is at `https://<that address>:8006`.
   - **Email:** for Proxmox's alerts. `brogers@jeeves` works once
     ssh-fetch-mail is set up again on jeeves; until then, any address.
2. After the install:
   - Switch from the enterprise repository, which needs a subscription, to
     the no-subscription one, and update. The "no valid subscription" notice
     at login is harmless. In the web UI, under moxie, Updates, Repositories:
     1. Select the `pve-enterprise` repository and click **Disable**. Do the
        same for the Ceph enterprise one, if it is listed. moxie does not use
        Ceph, but an enabled enterprise repository makes every `apt update`
        fail.
     2. Click **Add**, choose **No-Subscription**, and click Add. Click OK on
        the warning that it is not for production.
     3. Under Updates, click **Refresh** (which runs `apt update`), then
        **Upgrade**, which opens a shell running the upgrade. Reboot if it
        installs a new kernel.

     Once that is done, the Repositories page should show no errors.
   - Make the SATA SSD, the `Inland SATA SSD`, a second LVM-Thin storage
     (moxie, Disks, LVM-Thin, Create). It is new and has no partitions, so
     it needs no wiping; a disk there that does have partitions is not it.
   - Only then plug the Seagate back in, to pass it through to the jeeves
     VM.
   - Optional, undecided: Tailscale on moxie, to reach its web UI away from
     home.

## The jeeves VM

- **OS:** Debian trixie (13), as a server, with no desktop: in the
  installer's software selection, only "SSH server" and "standard system
  utilities". Hostname `jeeves`; first user `brogers`, who gets UID 1000, as
  on the old jeeves, which the backups rely on (they keep numeric owners).
- **Disk:** 200 GB on the SATA SSD's LVM-thin pool. The old jeeves used about
  90 GB (61 GB of home directory, 29 GB of `/srv/immich`); thin provisioning
  takes only what is used. VirtIO SCSI, with Discard and SSD emulation on, so
  that space freed in the guest goes back to the pool.
- **CPU:** type `host`, 4 cores; trim it once the lab's VMs exist.
- **Memory:** 12 to 16 GB to start. Immich's machine learning uses the most.
- **QEMU Guest Agent:** turn it on in the VM's options, and install
  `qemu-guest-agent` in Debian, so that Proxmox can shut it down cleanly and
  show its address.
- **The Seagate:** pass it through to the VM by its USB ID, `0bc2:2344`, not
  by port, so that it follows the drive to any port. That needs no IOMMU.
  The `install-etc` step mounts it at `/mnt/backups`, before anything is
  restored.
- **LAN address:** the VM's network card has a new MAC address. If
  `jeeves.lan` does not follow it, see step 5 of the move in
  `docs/jeeves-restore.md`; its first fix gives the VM the old card's MAC
  address above, and moxie's bridge another one.

Then, in the VM: install `git`, clone this repo, and run `./setup`, as
`docs/jeeves-restore.md` describes.

## Later

- **Backing up the VMs:** Proxmox's own backups (`vzdump`) need a storage
  target. The Seagate might be repurposed for that, or something else, once
  jeeves is back and running; to be decided then. As it is, it cannot be:
  it is passed through to jeeves, and it is NTFS.
