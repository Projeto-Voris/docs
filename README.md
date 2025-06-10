# ROS2 Auto-Launch com systemd em Jetson

Este repositório fornece um exemplo simples de como configurar um serviço systemd para iniciar automaticamente um launch do ROS2 ao ligar a Jetson.

## Conteúdo

* `ros2_launch_start.sh`: Script com export das variáveis e execução do launch
* `ros2_launch.service`: Serviço systemd que chama o script no boot

## Requisitos

* ROS 2 (Humble ou equivalente)
* Spinnaker SDK instalado
* Launch funcional: `ros2 launch voris_bringup sm3.launch.py`

## Instalação

### 1. Copiar os arquivos para a Jetson

```bash
chmod +x ros2_launch_start.sh
sudo cp ros2_launch.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable ros2_launch.service
```

### 2. Testar o serviço manualmente

```bash
sudo systemctl start ros2_launch.service
```

Verificar status:

```bash
sudo systemctl status ros2_launch.service
```

Logs:

```bash
journalctl -u ros2_launch.service -b
```

## Remoção

```bash
sudo systemctl disable ros2_launch.service
sudo rm /etc/systemd/system/ros2_launch.service
sudo systemctl daemon-reload
```

## Observações

* O script deve conter todas as exports necessárias (Spinnaker, ROS, etc)
* O serviço assume que o script está em local fixo (ajuste se preciso)
* A rede deve estar pronta no momento do launch (usar `After=network-online.target`)

---

MIT License
