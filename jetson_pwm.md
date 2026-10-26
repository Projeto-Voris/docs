# Jetson Orin Nano Super: Fixing Low-Frequency PWM with `clk_32k` / `clk_m`

**Tested setup (22 October 2026)**

| Item | Value |
|---|---|
| Hardware | Jetson Orin Nano Super Developer Kit (40-pin header) |
| Jetson Linux / L4T | R36.5.2 (`nvidia-l4t-core 36.5.2-20260716114719`) |
| Kernel | `5.15.199-tegra` (variant `oot`) |
| Kernel PWM option | `CONFIG_PWM_TEGRA=m` |
| PWM output | PWM5, controller `32c0000.pwm`, physical header pin **33** |
| PWM sysfs device in this setup | `/sys/class/pwm/pwmchip2/pwm0` (re-check after updates) |
| PWM clock parent | `clk_32k`, **32768 Hz** |
| Test waveform | 100 ms requested period (10 Hz), 50 ms requested duty (50%) |
| Working boot entry | `PWMFixed`, retaining the `io_config_moa.dtbo` overlay |

> **Scope:** This is the sequence that resolved the problem on the system described above. It is not a universal patch for every JetPack/L4T version. Do not blindly replace kernel modules or boot images on a different release. The R39.2 PWM guide is a reference for the clock architecture, while the kernel sources and headers must match **R36.5.2**.

## 1. Problem and root cause

The default PWM5 clock parent was `pllp_out0` (408 MHz). The Tegra234 PWM divider cannot generate 10 Hz with that input: its minimum output is approximately 194.55 Hz. Changing the parent to `clk_32k` through the Device Tree overlay succeeded (`clk_parent=clk_32k`, `clk_rate=32768`), and sysfs accepted `period=100000000` and `duty_cycle=50000000`, but the physical signal was noisy or invalid.

The unpatched NVIDIA `drivers/pwm/pwm-tegra.c` performed the duty-width shift before promoting the operand to 64 bits. At 50 ms duty, `50,000,000 * 256 = 12,800,000,000`, too large for a 32-bit intermediate. An NVIDIA engineer proposed adding a `(u64)` cast before shifting.

**There was a second issue:** although the patched `pwm-tegra.ko` was installed on the root filesystem, early boot loaded the **original** `pwm-tegra.ko` from `/boot/initrd`. Consequently, PWM still behaved as if unpatched until a separate initramfs carrying the patched module was created and selected at boot.

Before the effective patch, register readings at `0x032c0000` for a 100 ms period were:

| Requested duty | Register observed before effective patch | Expected duty field (bits 23:16) |
|---|---|---|
| 1 ms | `0x8003000C` | `3` |
| 5 ms | `0x800D000C` | `13` |
| 10 ms | `0xC450000C` | `26` |
| 50 ms | `0xC460000C` | `128` |

The final patched configuration was reported working on the physical output. These hexadecimal values document the **previous faulty state**; they are not the final measured output.

## 2. Record the current platform and back up critical files

```bash
cat /etc/nv_tegra_release
uname -r
dpkg-query -W nvidia-l4t-core
zcat /proc/config.gz | grep CONFIG_PWM_TEGRA

sudo mkdir -p /opt/pwm-backup
sudo cp -a /boot/initrd /opt/pwm-backup/initrd.original
sudo cp -a /boot/extlinux/extlinux.conf /opt/pwm-backup/extlinux.conf.original
sudo cp -a \
  /lib/modules/$(uname -r)/kernel/drivers/pwm/pwm-tegra.ko \
  /opt/pwm-backup/pwm-tegra.ko.original
```

A **working serial console, monitor/keyboard, or recovery plan** is recommended before modifying boot entries. Keep the original `JetsonIO` boot entry intact. This installation boots from NVMe; preserving its full `APPEND` line is essential.

## 3. Configure PWM5 clock and physical pin 33 using your existing DTS overlay

The working configuration used an existing header overlay (in this case `/boot/io_config_moa.dtbo`). In the DTS, the relevant PWM5 clock-parent assignment was:

```dts
fragment@2 {
    target = <&pwm5>;
    __overlay__ {
        status = "okay";
        assigned-clocks = <&bpmp 109>;       /* TEGRA234_CLK_PWM5 */
        assigned-clock-parents = <&bpmp 289>; /* TEGRA234_CLK_CLK_32K */
    };
};
```

The pin 33 group in the existing pinmux overlay included:

```dts
hdr40-pin33 {
    nvidia,pins = "soc_gpio21_ph0";
    nvidia,function = "gp";
    nvidia,pin-group = "pwm5";
    nvidia,pull = <0x1>;
    nvidia,tristate = <0x0>;
    nvidia,enable-input = <0x0>;
};
```

These fragments are **excerpts**, not a complete standalone DTS. Keep the existing compatible string and other pin settings in the working overlay. A known compatible string for this board configuration is:

```dts
compatible = "nvidia,p3768-0000+p3767-0005-super";
```

Confirm it against your actual running DT rather than assuming every Orin Nano carrier uses the same string:

```bash
tr '\0' '\n' < /proc/device-tree/compatible
```

Compile the **complete existing** overlay source, then select it with Jetson-IO (avoid loading conflicting overlays twice):

```bash
dtc -@ -I dts -O dtb -o io_config_moa.dtbo moa_config.dts
sudo cp io_config_moa.dtbo /boot/
sudo /opt/nvidia/jetson-io/jetson-io.py
```

File names above are examples based on this setup; substitute the actual source name. Reboot if Jetson-IO changes the boot configuration. Confirm the overlay is referenced by the active boot entry:

```bash
grep -E '^DEFAULT|^[[:space:]]*(LABEL|OVERLAYS|FDT|INITRD)' \
  /boot/extlinux/extlinux.conf
sudo cat /sys/kernel/debug/clk/pwm5/clk_parent
sudo cat /sys/kernel/debug/clk/pwm5/clk_rate
```

Expected PWM5 clock values: `clk_32k`, `32768`.

> **Important:** We observed pinmux register `0x02434040 = 0x00000405` and `gpio-mode=1`. These readings alone did **not** establish the final issue; avoid writing pinmux registers blindly. The successful solution required activating the corrected PWM driver from the initramfs.

## 4. Download the matching R36.5.2 kernel sources

```bash
mkdir -p ~/jetson-kernel
cd ~/jetson-kernel

wget -O public_sources.tbz2 \
  https://developer.download.nvidia.com/embedded/L4T/r36_Release_v5.2/sources/public_sources.tbz2

tar -tjf public_sources.tbz2 | grep kernel_src.tbz2
```

Expected archive entries include `Linux_for_Tegra/source/kernel_src.tbz2` and its SHA1 checksum file.

Extract only the kernel sources:

```bash
tar -xjf public_sources.tbz2 \
  Linux_for_Tegra/source/kernel_src.tbz2 \
  Linux_for_Tegra/source/kernel_src.tbz2.sha1sum \
  --strip-components=2

tar -xjf kernel_src.tbz2
find ~/jetson-kernel -name pwm-tegra.c
```

The tested path was:

```text
~/jetson-kernel/kernel/kernel-jammy-src/drivers/pwm/pwm-tegra.c
```

Check the base kernel version and current module metadata:

```bash
cd ~/jetson-kernel/kernel/kernel-jammy-src
make -s kernelversion       # 5.15.199
uname -r                   # 5.15.199-tegra
modinfo pwm-tegra | grep -E 'filename|vermagic'
```

`make kernelversion` matching the base version is **necessary but not sufficient** for binary compatibility. For `CONFIG_MODVERSIONS`, build against compatible headers/configuration/`Module.symvers` and compare symbol CRCs.

## 5. Apply NVIDIA's one-line overflow patch

```bash
cd ~/jetson-kernel/kernel/kernel-jammy-src
cp drivers/pwm/pwm-tegra.c drivers/pwm/pwm-tegra.c.original

python3 - <<'PY'
from pathlib import Path
p = Path('drivers/pwm/pwm-tegra.c')
s = p.read_text()
old = 'duty_ns << PWM_DUTY_WIDTH'
new = '(u64)duty_ns << PWM_DUTY_WIDTH'
assert s.count(old) == 1, 'Unexpected kernel source expression: inspect manually'
p.write_text(s.replace(old, new))
PY

diff -u drivers/pwm/pwm-tegra.c.original drivers/pwm/pwm-tegra.c
```

The intended change is exactly:

```diff
- pwm_f = (u32)DIV_ROUND_CLOSEST_ULL(duty_ns << PWM_DUTY_WIDTH, period_ns);
+ pwm_f = (u32)DIV_ROUND_CLOSEST_ULL((u64)duty_ns << PWM_DUTY_WIDTH, period_ns);
```

In the tested source this expression occupied two lines; the automated replacement changes only the operand. If your source already uses 64-bit arithmetic, **do not apply the patch a second time**.

## 6. Build only `pwm-tegra.ko`

The tested kernel has `CONFIG_PWM_TEGRA=m`, so the driver can be rebuilt as a module. A matching prepared headers directory with a usable `Module.symvers` is required.

```bash
KBUILD=$(readlink -f /lib/modules/$(uname -r)/build)
echo "$KBUILD"
ls -lh "$KBUILD/Module.symvers"
```

If that file does not exist or does not match the running kernel, stop and prepare matching NVIDIA kernel build artifacts; do not install a guessed module.

Use an isolated build directory:

```bash
mkdir -p ~/jetson-kernel/pwm-patched
cp ~/jetson-kernel/kernel/kernel-jammy-src/drivers/pwm/pwm-tegra.c \
  ~/jetson-kernel/pwm-patched/

cat > ~/jetson-kernel/pwm-patched/Makefile <<'MAKEFILE'
obj-m += pwm-tegra.o
MAKEFILE

cd ~/jetson-kernel/pwm-patched
make -C /lib/modules/$(uname -r)/build M="$PWD" ARCH=arm64 modules

modinfo -F vermagic ./pwm-tegra.ko
modprobe --dump-modversions ./pwm-tegra.ko
```

Expected `vermagic` on this setup:

```text
5.15.199-tegra SMP preempt mod_unload modversions aarch64
```

Compare this to the original module's `vermagic` and imported symbol CRCs. `modinfo -F depends` being blank is normal for this driver; it does not prove compatibility.

Install as an override, **without overwriting NVIDIA's original file**:

```bash
sudo mkdir -p /lib/modules/$(uname -r)/updates/pwm-fixed
sudo install -m 644 ~/jetson-kernel/pwm-patched/pwm-tegra.ko \
  /lib/modules/$(uname -r)/updates/pwm-fixed/pwm-tegra.ko
sudo depmod -a
modprobe -D pwm-tegra
```

At this point `modprobe -D` may show the patched file, but the *already running* driver can still be the original one loaded from initramfs. Do not attempt to `insmod` a second copy over the loaded PWM module (`File exists`). Avoid `rmmod` because other PWM consumers, including the fan, may use it.

## 7. Identify the early-boot initramfs module problem

Before fixing the initramfs, the loaded and patched module Build IDs differed:

| Location | Build ID |
|---|---|
| Original NVIDIA `pwm-tegra.ko` and loaded module | `4fb7d3987605187107da913c1390e53c33adbcdb` |
| Newly built patched module | `ffc9382b644c3a806c690c0cbda41b4b8631a585` |

Inspect loaded Build ID. The sysfs note is a raw ELF note, **not** an ELF file, so `readelf -n /sys/module/...` fails. Read its 20-byte GNU Build ID after the 16-byte note prefix:

```bash
sudo od -An -tx1 -j16 -N20 \
  /sys/module/pwm_tegra/notes/.note.gnu.build-id | tr -d ' \n'
echo

readelf -n \
  /lib/modules/$(uname -r)/updates/pwm-fixed/pwm-tegra.ko \
  | grep 'Build ID:'
```

Inspect the currently used initramfs:

```bash
lsinitramfs /boot/initrd | grep 'pwm-tegra.ko'
```

On this system it contained:

```text
usr/lib/modules/5.15.199-tegra/kernel/drivers/pwm/pwm-tegra.ko
```

This old module was being loaded before the root-filesystem override. Updating only `/lib/modules/.../updates/` was not enough.

## 8. Configure `nv-update-initrd` to include the patched binary

The NVIDIA module list had a `source:destination` mapping with a **literal** `<KERNEL_VERSION>` placeholder:

```text
/etc/nv-update-initrd/list.d/modules
```

Original mapping:

```text
/lib/modules/<KERNEL_VERSION>/kernel/drivers/pwm/pwm-tegra.ko:/lib/modules/<KERNEL_VERSION>/kernel/drivers/pwm/pwm-tegra.ko
```

The failed initial `sed` used the expanded kernel version and therefore did not match that placeholder. Instead, replace only the **source** path; retain the original destination inside initramfs.

```bash
sudo cp -a /etc/nv-update-initrd/list.d/modules \
  /opt/pwm-backup/modules.original

sudo python3 - <<'PY'
from pathlib import Path
p = Path('/etc/nv-update-initrd/list.d/modules')
s = p.read_text()
old = ('/lib/modules/<KERNEL_VERSION>/kernel/drivers/pwm/pwm-tegra.ko:'
       '/lib/modules/<KERNEL_VERSION>/kernel/drivers/pwm/pwm-tegra.ko')
new = ('/lib/modules/<KERNEL_VERSION>/updates/pwm-fixed/pwm-tegra.ko:'
       '/lib/modules/<KERNEL_VERSION>/kernel/drivers/pwm/pwm-tegra.ko')
assert s.count(old) == 1, 'Unexpected module list: inspect manually'
p.write_text(s.replace(old, new))
PY

sudo grep -n 'pwm-tegra.ko' /etc/nv-update-initrd/list.d/modules
```

Expected updated mapping:

```text
/lib/modules/<KERNEL_VERSION>/updates/pwm-fixed/pwm-tegra.ko:/lib/modules/<KERNEL_VERSION>/kernel/drivers/pwm/pwm-tegra.ko
```

## 9. Create a **separate** patched initramfs and verify its contents

`nv-update-initrd` can regenerate `/boot/initrd`. The original must be backed up first (Step 2).

```bash
sudo nv-update-initrd 2>&1 | tee ~/pwm-initrd-build.log
# Inspect log, and stop if the utility failed.
grep -i -C 3 'pwm-tegra' ~/pwm-initrd-build.log

# Save the generated patched image
sudo cp -a /boot/initrd /boot/initrd-pwm-fixed

# Restore the original default image and NVIDIA module list
sudo cp -a /opt/pwm-backup/initrd.original /boot/initrd
sudo cp -a /opt/pwm-backup/modules.original \
  /etc/nv-update-initrd/list.d/modules
```

**Do not reboot yet.** Verify the actual patched binary is embedded:

```bash
mkdir -p ~/jetson-kernel/initrd-check
unmkinitramfs /boot/initrd-pwm-fixed ~/jetson-kernel/initrd-check
find ~/jetson-kernel/initrd-check -name pwm-tegra.ko \
  -exec readelf -n {} \; | grep 'Build ID:'
```

Expected **patched** Build ID:

```text
ffc9382b644c3a806c690c0cbda41b4b8631a585
```

If the embedded driver still has the original Build ID, do **not** boot the test image; fix the module-list mapping/build first.

## 10. Add a safe `PWMFixed` boot entry in `extlinux.conf`

The working extlinux configuration had `DEFAULT JetsonIO`, with the following boot entries:

- `primary`: original boot image and initramfs.
- `JetsonIO`: same kernel, board DTB and `OVERLAYS /boot/io_config_moa.dtbo`, with `/boot/initrd`.

Add **one more** entry by duplicating the **entire `JetsonIO` stanza**, preserving the original long `APPEND` line verbatim. Change only these fields:

```text
LABEL PWMFixed
    MENU LABEL Custom Header Config: PWM Patched Driver
    INITRD /boot/initrd-pwm-fixed
```

The test entry must also retain the **same** `LINUX`, `FDT`, `OVERLAYS`, and `APPEND` lines as `JetsonIO`:

```text
LABEL PWMFixed
    MENU LABEL Custom Header Config: PWM Patched Driver
    LINUX /boot/Image
    FDT /boot/dtb/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb
    INITRD /boot/initrd-pwm-fixed
    APPEND <COPY ENTIRE APPEND LINE FROM YOUR EXISTING JetsonIO ENTRY>
    OVERLAYS /boot/io_config_moa.dtbo
```

**Never leave the `<COPY ...>` placeholder in a real config.** Your real `APPEND` includes the NVMe root `PARTUUID` and other arguments.

It is safest to use the actual text of the `JetsonIO` entry rather than a manually retyped partial line. Preserve `DEFAULT JetsonIO` for the first test and select `PWMFixed` manually from the boot menu (if exposed). After confirming the test entry works and a recovery path exists, you may set `DEFAULT PWMFixed`.

If the `PWMFixed` entry already exists, **inspect it** rather than adding a duplicate:

```bash
grep -A 9 '^LABEL PWMFixed' /boot/extlinux/extlinux.conf
grep -E '^[[:space:]]*(DEFAULT|LABEL|INITRD|FDT|OVERLAYS)' \
  /boot/extlinux/extlinux.conf
```

## 11. Confirm the corrected driver actually loaded

Reboot into `PWMFixed`. Then:

```bash
LOADED=$(sudo od -An -tx1 -j16 -N20 \
  /sys/module/pwm_tegra/notes/.note.gnu.build-id | tr -d ' \n')
INSTALLED=$(readelf -n \
  /lib/modules/$(uname -r)/updates/pwm-fixed/pwm-tegra.ko \
  | awk '/Build ID:/ {print $3}')

printf 'Loaded:    %s\nInstalled: %s\n' "$LOADED" "$INSTALLED"
test "$LOADED" = "$INSTALLED" && echo 'Patched PWM driver active'
```

For this build, both should be:

```text
ffc9382b644c3a806c690c0cbda41b4b8631a585
```

Also check the clock:

```bash
sudo cat /sys/kernel/debug/clk/pwm5/clk_parent
sudo cat /sys/kernel/debug/clk/pwm5/clk_rate
```

Expected: `clk_32k` and `32768`.

## 12. Test PWM5 at 10 Hz and 50% duty cycle

First re-check that `32c0000.pwm` is `pwmchip2`, because enumeration can change:

```bash
for chip in /sys/class/pwm/pwmchip*; do
  echo "$chip -> $(readlink -f "$chip/device")"
done
```

On this machine the mapping was `pwmchip2 -> .../32c0000.pwm`.

```bash
CHIP=/sys/class/pwm/pwmchip2
if [ ! -d "$CHIP/pwm0" ]; then
  echo 0 | sudo tee "$CHIP/export"
fi
PWM="$CHIP/pwm0"

echo 0         | sudo tee "$PWM/duty_cycle"
echo 100000000 | sudo tee "$PWM/period"      # 100 ms / 10 Hz
echo 50000000  | sudo tee "$PWM/duty_cycle"  # 50 ms / 50%
echo 1         | sudo tee "$PWM/enable"

cat "$PWM"/{period,duty_cycle,enable}
sudo cat /sys/kernel/debug/pwm
sudo busybox devmem 0x032c0000 32
```

The nominal PWM5 register using the corrected duty calculation is `0x8080000C`: enabled (bit 31), duty field `0x80`, scale field `0x000C`. The corresponding frequency is approximately:

```text
32768 / [256 * (12 + 1)] = 9.8461538 Hz
```

To check duty register updates:

```bash
for duty in 1000000 5000000 10000000 25000000 50000000 75000000; do
  echo "$duty" | sudo tee "$PWM/duty_cycle" >/dev/null || break
  REG=$(sudo busybox devmem 0x032c0000 32)
  printf 'duty=%2d%% register=%s field=%d\n' \
    "$((duty/1000000))" "$REG" "$(((REG >> 16) & 255))"
done
```

Expected duty fields: **3, 13, 26, 64, 128, 192** respectively. Restore 50% afterward:

```bash
echo 50000000 | sudo tee "$PWM/duty_cycle"
```

Finally, measure **physical pin 33** relative to a header ground (e.g., pin 34), using an oscilloscope or logic analyzer. Sysfs reports a *requested* state, not a direct physical frequency measurement.

## 13. Rollback and future updates

**Safest rollback:** At boot, select the original `JetsonIO` entry, which uses the untouched `/boot/initrd`. If the patched entry was made default and the system remains accessible, restore `DEFAULT JetsonIO` in `/boot/extlinux/extlinux.conf`.

To remove the override *after switching back to the original boot entry*:

```bash
sudo rm -f /lib/modules/$(uname -r)/updates/pwm-fixed/pwm-tegra.ko
sudo depmod -a
```

Do not delete `/boot/initrd` or the original NVIDIA `pwm-tegra.ko`. Restore your backed-up initrd and extlinux config from `/opt/pwm-backup/` only when appropriate for the current boot setup. Do not unload the PWM driver live when used by the fan or other devices.

A JetPack, kernel or NVIDIA driver update may overwrite the initramfs, change the module ABI, or invalidate this patch. After an update, re-check `uname -r`, kernel sources, `CONFIG_PWM_TEGRA`, the module Build ID, clock parent and sysfs-to-controller mapping before rebuilding anything.

## 14. References

1. **NVIDIA Developer Guide — PWM Frequency Configuration (Jetson Linux R39.2)**: <https://docs.nvidia.com/jetson/archives/r39.2/DeveloperGuide/SD/Kernel/IoCustomization/pwm.html#pwm-period> — clock parents, PWM divider and Device Tree examples. **Note:** this is a newer release than the tested R36.5.2.
2. **NVIDIA Developer Forum — Jetson Orin Nano PWM frequency limit**: <https://forums.developer.nvidia.com/t/jetson-orin-nano-pwm-frequency-limit/386421> — original troubleshooting thread and NVIDIA engineer's proposed `(u64)` fix.
3. **NVIDIA Jetson Linux R36.5 Kernel Customization**: <https://docs.nvidia.com/jetson/archives/r36.5/DeveloperGuide/SD/Kernel/KernelCustomization.html> — kernel source/build background.
4. **NVIDIA Jetson Linux archive**: <https://developer.nvidia.com/embedded/jetson-linux-archive> — locate release-specific BSP sources.
5. **NVIDIA R36.5.2 `public_sources.tbz2`**: <https://developer.download.nvidia.com/embedded/L4T/r36_Release_v5.2/sources/public_sources.tbz2> — source package used for this kernel patch.
6. **Linux PWM sysfs API**: <https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-class-pwm> — meaning of `export`, `period`, `duty_cycle`, and `enable`.
7. **Linux kernel module build documentation**: <https://docs.kernel.org/kbuild/modules.html> — external module builds, `Module.symvers`, and module compatibility.

---

**Resolution summary:** The Device Tree correctly selected the lower-frequency PWM parent. The PWM signal became correct only after applying NVIDIA's 64-bit arithmetic correction **and booting an initramfs containing that patched `pwm-tegra.ko`**, rather than the original early-boot module.
