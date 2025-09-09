
# WSL2 Dual Network Setup for ROS 2 (Lab + Direct Raspberry)

Enable WSL2 Ubuntu to communicate via **UDP (ROS 2 / DDS)** in two scenarios for BlueOS ROS2:

1. **Lab network (DHCP)** → Windows + Raspberry + WSL2 get IPs in `150.162.x.x` automatically.
2. **Direct cable to Thether** → Static IPs in `192.168.2.x`.

WSL2 should automatically support both, no manual reconfiguration.

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

## 🔹 Step 3 – Networking Behavior

* **Lab (DHCP)**

  * Windows: e.g. `150.162.167.75`
  * Raspberry: e.g. `150.162.167.10`
  * WSL2: e.g. `150.162.167.80` (from DHCP)
  * All devices talk over `150.162.x.x`.

* **Direct cable**

  * Windows: `192.168.2.1` (manual)
  * Raspberry: `192.168.2.2` (manual)
  * WSL2: `192.168.2.3` (auto via script)
  * All devices talk over `192.168.2.x`.

---

⚠️

* Not officially supported by Microsoft.
* If you move between Wi-Fi/Ethernet, you may need to rebind the vSwitch.
* Windows firewall may still need UDP multicast rules open, or disable it.

---
