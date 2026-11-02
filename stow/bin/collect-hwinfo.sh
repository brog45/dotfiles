#!/usr/bin/bash
# Collect RAM and drive info from this machine.
# Run on the machine itself:  collect-hwinfo.sh <output-dir>
# Re-runs itself with sudo if not already root.
# Writes hwinfo.txt, storage.txt, smart.txt, dmidecode-memory.txt and
# decode-dimms.txt to output-dir, overwriting any earlier copies.
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <output-dir>" >&2
    exit 2
fi

if [ "$EUID" -ne 0 ]; then
    echo "Not running as root; re-running with sudo." >&2
    exec sudo "$0" "$@"
fi

umask 022
OUT="$(cd "$1" && pwd)" || exit 1
have() { command -v "$1" >/dev/null 2>&1; }
dmi() { cat "/sys/class/dmi/id/$1" 2>/dev/null; }

decode_dimms() {
    if ! have decode-dimms || ! have i2cdetect; then
        echo "decode-dimms/i2cdetect not installed (sudo apt install i2c-tools)"
        return
    fi
    # awk reads all its input: exiting early could kill dmidecode with SIGPIPE.
    if ! memtype=$(
        dmidecode -t 17 2>/dev/null \
            | awk -F': ' '/^[[:space:]]*Type: (LP)?DDR/ && !t {t=$2} END {print t}'
    )
    then
        echo "(dmidecode -t 17 failed detecting memory type)"
    fi
    case "$memtype" in
        DDR4)          mod=ee1004; dev=ee1004 ;;
        DDR|DDR2|DDR3) mod=at24;   dev=spd ;;
        *)
            echo "(decode-dimms can't read '${memtype:-unknown}' memory; see dmidecode-memory.txt)"
            if ! decode-dimms; then
                echo "(decode-dimms failed on unsupported memory type)"
            fi
            return
            ;;
    esac
    if ! modprobe i2c-dev 2>/dev/null; then
        echo "(could not load i2c-dev)"
    fi
    if ! modprobe "$mod" 2>/dev/null; then
        echo "(could not load $mod)"
    fi
    # Intel boards have one SMBus adapter (I801); AMD boards can have several (PIIX4).
    if ! buses=$(
        i2cdetect -l \
            | awk -F'\t' '$3 ~ /SMBus/ {sub("i2c-","",$1); print $1}'
    )
    then
        echo "(i2cdetect -l failed)"
    fi
    if [ -n "$buses" ]; then
        # Register SPD EEPROMs the kernel didn't pick up at boot (lost on reboot).
        for bus in $buses; do
            for a in 50 51 52 53 54 55 56 57; do
                [ -e "/sys/bus/i2c/devices/$bus-00$a" ] && continue
                if i2cdetect -y -r "$bus" "0x$a" "0x$a" 2>/dev/null \
                    | sed -n 's/^50://p' \
                    | grep -qw "$a"
                then
                    if ! echo "$dev 0x$a" > "/sys/bus/i2c/devices/i2c-$bus/new_device"; then
                        echo "(could not register $dev at 0x$a on i2c-$bus)"
                    fi
                fi
            done
        done
        sleep 1
    else
        echo "(no SMBus adapter found; decode-dimms may find nothing)"
    fi
    if ! decode-dimms; then
        echo "(decode-dimms failed on supported memory type $memtype)"
    fi
}

{
    printf '%-17s%s\n' "host:" "$(hostname)"
    printf '%-17s%s\n' "kernel:" "$(uname -r)"
    printf '%-17s%s\n' "sys_vendor:" "$(dmi sys_vendor)"
    printf '%-17s%s\n' "product_name:" "$(dmi product_name)"
    printf '%-17s%s\n' "product_version:" "$(dmi product_version)"
    printf '%-17s%s\n' "board_name:" "$(dmi board_name)"
    printf '%-17s%s\n' "bios_version:" "$(dmi bios_version)"
    printf '%-17s%s\n' "bios_date:" "$(dmi bios_date)"
    printf '%-17s%s\n' "cpu:" "$(awk -F': ' '/^model name/ {print $2; exit}' /proc/cpuinfo)"
    printf '%-17s%s\n' "mem_total:" "$(awk '/^MemTotal/ {print $2, $3}' /proc/meminfo)"
    printf '%-17s%s\n' "os:" "$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
    echo
    if ! udevadm info --query=property --path=/sys/devices/virtual/dmi/id 2>/dev/null \
        | grep '^MEMORY_'
    then
        echo "(udev has no MEMORY_ properties on this system; see dmidecode-memory.txt)"
    fi
} > "$OUT/hwinfo.txt"

{
    echo "== Physical disks"
    if ! lsblk -d -e 7,11 -o NAME,TYPE,TRAN,ROTA,SIZE,MODEL,SERIAL,REV 2>/dev/null \
        && ! lsblk -d -o NAME,TYPE,ROTA,SIZE,MODEL
    then
        echo "(lsblk failed listing physical disks)"
    fi
    echo
    echo "== Partitions and filesystems"
    if ! lsblk -e 7,11 -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT; then
        echo "(lsblk failed listing partitions and filesystems)"
    fi
    echo
    echo "== Usage"
    # df also fails if any one filesystem is unreadable, after listing the others.
    if ! df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs 2>/dev/null; then
        echo "(df reported an error; list may be incomplete)"
    fi
    echo
    echo "== Storage controllers"
    if have lspci; then
        if ! lspci -nn | grep -Ei 'sata|nvme|non-volatile|raid|ahci|ide'; then
            echo "(lspci listed no storage controllers)"
        fi
    else
        echo "lspci not installed"
    fi
} > "$OUT/storage.txt"

if have dmidecode; then
    if ! dmidecode -t 16 -t 17 > "$OUT/dmidecode-memory.txt" 2>&1; then
        echo "(dmidecode -t 16 -t 17 failed)" >> "$OUT/dmidecode-memory.txt"
    fi
else
    echo "dmidecode not installed (sudo apt install dmidecode)" > "$OUT/dmidecode-memory.txt"
fi

{
    if have smartctl; then
        for d in $(
            lsblk -dn -e 7,11 -o NAME,TYPE \
                | awk '$2=="disk" && $1 !~ /^zram/ {print $1}'
        ); do
            echo "==================== /dev/$d"
            # Nonzero status can just mean the drive has warnings to report; see man smartctl.
            if smartctl -i -H -A "/dev/$d"; then
                :
            else
                echo "(smartctl exited with status $? on /dev/$d)"
            fi
            echo
        done
    else
        echo "smartctl not installed (sudo apt install smartmontools)"
    fi
    if have nvme; then
        echo "==================== nvme list"
        if ! nvme list; then
            echo "(nvme list failed)"
        fi
    fi
} > "$OUT/smart.txt" 2>&1

decode_dimms > "$OUT/decode-dimms.txt" 2>&1

# Hand the files back to the user who ran sudo.
chown "${SUDO_UID:-0}:${SUDO_GID:-0}" \
    "$OUT"/{hwinfo,storage,dmidecode-memory,smart,decode-dimms}.txt

ls -l "$OUT"/{hwinfo,storage,dmidecode-memory,smart,decode-dimms}.txt
echo "Done."
