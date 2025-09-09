# ROS2 Auto-Launch com systemd em Jetson

Este repositório fornece um exemplo simples de como configurar um serviço systemd para iniciar automaticamente um launch do ROS2 ao ligar a Jetson.

## Conteúdo

* `remote_jetson.sh`: Script responsável por rodar o launch em ROS2
* `ros2_launch.service`: Serviço systemd que chama o script no boot

## Definições

* ROS 2 (Humble ou equivalente)

De acordo com o launch em cada Jetson (editável no `remote_jetson.sh`):

* Launch funcional: `ros2 launch voris_bringup active_system.launch.py` ou `ros2 launch voris_bringup passive_system.launch.py`

## Instalação

### 1. Instalação (se necessário)

Criar arquivo de serviço com nome `ros2_launch.service`:

```bash
sudo nano /etc/systemd/system/ros2_launch.service
```

Código base do serviço `ros2_launch.service`:

```ini
[Unit]
Description=Auto-start ROS2 launch
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=jetson
ExecStart=/home/jetson/ros2_ws/src/remote_jetson.sh
Restart=on-failure
Environment=DISPLAY=:0

[Install]
WantedBy=multi-user.target
```

### 2. Testar o serviço manualmente

Iniciar:

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

### 3. Desabilitar e remover serviço

Desabilitar:

```bash
sudo systemctl disable ros2_launch.service
```

Remover:

```bash
sudo rm /etc/systemd/system/ros2_launch.service
sudo systemctl daemon-reload
```

### 4. Editar configurações do serviço

Se desejar alterar o comportamento do serviço (como o script executado, usuário ou variáveis de ambiente), edite o arquivo:

```bash
sudo nano /etc/systemd/system/ros2_launch.service
```

Exemplos de ajustes:

* Alterar o caminho do script:

  ```ini
  ExecStart=/home/jetson/meu_novo_script.sh
  ```
* Mudar o usuário:

  ```ini
  User=usuario_diferente
  ```
* Adicionar novas variáveis de ambiente:

  ```ini
  Environment=VAR1=valor1
  Environment=VAR2=valor2
  ```

Após qualquer edição, recarregue o systemd:

```bash
sudo systemctl daemon-reexec
```

E reinicie o serviço para aplicar:

```bash
sudo systemctl restart ros2_launch.service
```

## Observações

* O script deve conter todas as exports necessárias (Spinnaker, ROS, etc)
* O serviço assume que o script está em local fixo (ajuste se preciso)
* A rede deve estar pronta no momento do launch (usar `After=network-online.target`)
