# Guia de Rede e Otimização — BlueROV -> Notebook

Este guia resume a configuração de roteamento, de IPs estáticos e de otimização de banda para a rede local (LAN) do ROV.

## 1. Topologia da Rede

| Dispositivo | IP Estático | Gateway | DNS |
| --- | --- | --- | --- |
| **Notebook (VOR10)** | `192.168.2.1` | — (Wi-Fi) | — |
| **Raspberry Pi (BlueOS)** | `192.168.2.2` | `192.168.2.1` | `8.8.8.8` |
| **Jetson Orin Nano** | `192.168.2.15` | `192.168.2.1` | `8.8.8.8` |

---

## 2. Configuração do Notebook (Gateway)

Comandos para ativar o compartilhamento de internet da Wi-Fi (`wlo1`) para a Ethernet (`enp44s0`):

```bash
# Ativar encaminhamento no kernel
sudo sysctl -w net.ipv4.ip_forward=1

# Configurar NAT e Forwarding
sudo iptables -t nat -F
sudo iptables -t nat -A POSTROUTING -o wlo1 -j MASQUERADE
sudo iptables -A FORWARD -i enp44s0 -o wlo1 -j ACCEPT
sudo iptables -A FORWARD -i wlo1 -o enp44s0 -m state --state RELATED,ESTABLISHED -j ACCEPT

```

---

## 3. Configuração dos Clientes (LAN)

### Jetson Orin Nano

Configuração de IP fixo e rotas via NetworkManager:

```bash
sudo nmcli connection modify "Wired connection 1" \
  ipv4.addresses 192.168.2.15/24 \
  ipv4.gateway 192.168.2.1 \
  ipv4.dns "8.8.8.8" \
  ipv4.method manual
sudo nmcli connection up "Wired connection 1"

```

### Raspberry Pi (eth0)

Configuração via terminal para acesso à internet:

```bash
sudo nmcli connection modify eth0 \
  ipv4.addresses 192.168.2.2/24 \
  ipv4.gateway 192.168.2.1 \
  ipv4.dns "8.8.8.8" \
  ipv4.method manual
sudo nmcli connection up eth0

```

---

## 4. Otimização de Banda (Throughput)

### No Notebook (VOR10)

Ajuste de buffers TCP e ativação do algoritmo BBR:

```bash
sudo sysctl -w net.core.rmem_max=16777216
sudo sysctl -w net.core.wmem_max=16777216
sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
sudo sysctl -w net.ipv4.tcp_window_scaling=1
sudo sysctl -w net.core.default_qdisc=fq
sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
sudo ifconfig enp44s0 txqueuelen 10000

```

### Na Jetson Orin Nano

Ajuste de buffers (Kernel L4T não suporta BBR nativo):

```bash
sudo sysctl -w net.core.rmem_max=16777216
sudo sysctl -w net.core.wmem_max=16777216
sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
sudo sysctl -w net.ipv4.tcp_window_scaling=1
sudo ifconfig enP8p1s0 txqueuelen 10000

```

---

## 5. Ajuste de Tempo e Timezone

### Sistema Host (Jetson/RPi)

Sincronização via internet e fuso horário de Brasília:

```bash
sudo timedatectl set-timezone America/Sao_Paulo
sudo timedatectl set-ntp true

```

### Dentro de Containers Docker

Correção manual quando o `timedatectl` não está disponível:

```bash
ln -snf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
echo "America/Sao_Paulo" > /etc/timezone

```
