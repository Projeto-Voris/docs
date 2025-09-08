# Configure 

Configure WSL2 (Ubuntu 22.04/24.04) to get a LAN IP address via Hyper-V bridged networking, enabling ROS 2 / DDS (UDP) communication with other PCs on the network.

## 🔹 1. Enable Hyper-V (if not already)

Open PowerShell **as Admin**:

```powershell
dism.exe /online /enable-feature /featurename:Microsoft-Hyper-V-All /all
```

Then reboot.

---

## 🔹 2. Create an external vSwitch in Hyper-V

1. Open **Hyper-V Manager**.
2. On the right → **Virtual Switch Manager…**.
3. Click **New virtual network switch** → choose **External**.
4. Bind it to your physical network adapter (your Wi-Fi or Ethernet).

   * Example: if your PC is on Wi-Fi, choose the Wi-Fi card.
5. Give it a name, e.g. `WSLBridge`.
6. Apply and OK.

This makes a new bridged adapter in Windows.

---

## 3. Tell WSL2 to use the bridged adapter

Create or edit this file on Windows:

```
C:\Users\<your-user>\.wslconfig
```

Add:

```ini
[wsl2]
networkingMode=bridged
vmSwitch=WSLBridge
```

> `vmSwitch` must match the exact name of the vSwitch you created.

Save and restart WSL:

```powershell
wsl --shutdown
```

---

## 4. Start Ubuntu in WSL2 again

```powershell
wsl -d Ubuntu-22.04
```

Now check the IP inside WSL:

```bash
ip addr
```
---

## 5. Test ROS 2 communication

* On WSL2:

  ```bash
  ros2 run demo_nodes_cpp talker
  ```
* On the LAN Linux PC:

  ```bash
  ros2 run demo_nodes_cpp listener
  ```
---

⚠️ **Caveats**

* Not officially supported by Microsoft.
* If you move between Wi-Fi/Ethernet, you may need to rebind the vSwitch.
* Windows firewall may still need UDP multicast rules open, or disable it.

---
