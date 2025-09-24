
# WSL2 Dual Network Setup for ROS 2 (Lab + Direct Raspberry)

Enable WSL2 Ubuntu to communicate via **UDP (ROS 2 / DDS)** in two scenarios for BlueOS ROS2:

1. **Lab network (DHCP)** → Windows + Raspberry + WSL2 get IPs in `150.162.x.x` automatically.
2. **Direct cable to Thether** → Static IPs in `192.168.2.x`.

WSL2 should automatically support both, no manual reconfiguration.

### Summary

- **[Enable Hyper-V](#1-enable-hyper-v-if-not-already):** Turn on Hyper-V virtualization in Windows.
- **[Create an External vSwitch](#2-create-an-external-vswitch-in-hyper-v):** Set up a bridged network in Hyper-V Manager.
- **[Configure WSL2 Networking](#3-configure-wsl2-to-use-bridge-adapter):** Point WSL2 to use the external vSwitch for LAN connectivity.
- **[Auto-Assign Static IP Script](#4-prepare-wsl2-auto-assign-script):** Ensure WSL2 always gets the correct static IP for direct Raspberry Pi connection.
- **[Common Problems](#4-problems):** Troubleshooting tips and known limitations.
- **[Fixing DNS Issues](#1-how-to-fix-dns-issues-in-wsl2):** How to resolve DNS and network problems in WSL2.

## 1. Enable Hyper-V (if not already)

Open PowerShell **as Admin**:

```powershell
dism.exe /online /enable-feature /featurename:Microsoft-Hyper-V-All /all
```

Then reboot.

---

## 2. Create an external vSwitch in Hyper-V

1. Open **Hyper-V Manager**.
2. On the right → **Virtual Switch Manager…**.
3. Click **New virtual network switch** → choose **External**.
4. Bind it to your physical network adapter (your Wi-Fi or Ethernet).

   * Example: if your PC is on Wi-Fi, choose the Wi-Fi card.
5. Give it a name, e.g. `WSLBridge`.
6. Apply and OK.

This makes a new bridged adapter in Windows.

---

## 3. Configure WSL2 to use bridge adapter

This makes WSL2 use Hyper-V with a bridged adapter so it can get its own LAN IP.

In PowerShell (user home directory):

```powershell
notepad $env:USERPROFILE\.wslconfig
```

Add:

```ini
[wsl2]
networkingMode=bridged
vmSwitch=WSLBridge
```

👉 Replace `WSLBridge` with the name of your external Hyper-V switch that is bound to your Ethernet adapter.

Restart WSL:

```powershell
wsl --shutdown
```

---

## 4. Prepare WSL2 Auto-Assign Script

Inside Ubuntu (WSL2):

```powershell
wsl -d Ubuntu-22.04
```

1. Create script:

   ```bash
   sudo nano /etc/wsl-init.sh
   ```

   Content:

   ```bash
   #!/bin/bash
   # Auto-assign static IP for direct Raspberry connection
   if ! ip addr show eth0 | grep -q "192.168.2.3"; then
       ip addr add 192.168.2.3/24 dev eth0 2>/dev/null
   fi
   ```

2. Make it executable:

   ```bash
   sudo chmod +x /etc/wsl-init.sh
   ```

3. Hook into WSL startup by editing:

   ```bash
   sudo nano /etc/bash.bashrc
   ```

   Add at the bottom:

   ```bash
   if [ -f /etc/wsl-init.sh ]; then
       /etc/wsl-init.sh
   fi
   ```

Now, every time WSL2 starts, it ensures `192.168.2.3/24` is present.

---

## 4. Problems

* Not officially supported by Microsoft.
* If you move between Wi-Fi/Ethernet, you may need to rebind the vSwitch.
* Windows firewall may still need UDP multicast rules open, or disable it.

---

### 1. How to Fix DNS Issues in WSL2

1.  **Configure DNS in WSL2**: The most effective solution is to manually set a stable DNS server within your WSL2 instance. This bypasses the problematic automatic DNS resolution.

      * First, you need to tell WSL not to automatically generate the `resolv.conf` file, which contains the DNS settings. Open the `wsl.conf` file in a text editor:
        ```bash
        sudo nano /etc/wsl.conf
        ```
      * Add the following lines to the file:
        ```
        [network]
        generateResolvConf = false
        ```
      * Save and exit the editor.
      * Next, you'll create your own `resolv.conf` file with a reliable DNS server. Remove the old one first, then create a new one:
        ```bash
        sudo rm /etc/resolv.conf
        sudo nano /etc/resolv.conf
        ```
      * Add a public DNS server. Using Google's (`8.8.8.8`) or Cloudflare's (`1.1.1.1`) is recommended.
        ```
        nameserver 8.8.8.8
        ```
      * Save and exit. Now, shut down and restart your WSL2 environment from a PowerShell window:
        ```powershell
        wsl --shutdown
        ```
      * Restart your WSL2 terminal.

2.  **Disable Large Send Offload (LSO)**: High packet loss and network instability often stem from LSO. This can also cause DNS resolution failures. You should disable it on your `vEthernet` adapter if you haven't already. Open PowerShell as an administrator and run:

    ```powershell
    Set-NetAdapterLso -Name "vEthernet (WSL)" -IPv4Enabled $false -IPv6Enabled $false
    ```

