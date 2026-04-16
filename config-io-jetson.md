## Configuração dos pinos IO da Jetson usando patch de Device Tree Overlay (DTBO) aplicado ao Kernel
### Autor: Moacir Wendhausen
### Data: 11/02/2026
### CPU: Jetson Orin Nano - 8GB
### Source: nvidia-jetpack (6.2.1)
### Projeto: Voris
   
---
Este procedimento é baseado no jetson-orin-gpio-patch disponível em:  
https://github.com/jetsonhacks/jetson-orin-gpio-patch  

Vídeo no youtub:  
https://www.youtube.com/watch?v=a8espzPAzu4&t=21s

---

<br>

### Metodologia de Configuração de Hardware:
- **Identificação do Hardware**: O procedimento foi aplicado a uma NVIDIA Jetson Orin Nano operando com o firmware L4T versão 36.4.7 (JetPack 6).

- **Pinos IO a serem alterados**:  
    - Pino 7  - GPIO09  - PAC.06 - Line 144 - soc_gpio59_pac6
    - Pino 15 - GPIO012 - PN.01  - Line 85  - soc_gpio39_PN1
    - Pino 29 - GPIO01  - PQ.05  - Line 105 - soc_gpio32_pq5
    - Pino 31 - GPIO11  - PQ.06  - Line 106 - soc_gpio33_pq6
    - Pino 32 - GPIO07  - PG.06  - Line 41  - soc_gpio19_pg6
    - Pino 33 - GPIO13  - PH.00  - Line 43  - soc_gpio21_ph0  

- **Método de Aplicação**: Utilizou-se um arquivo .dtbo (Device Tree Overlay-DTBO), que é um binário compilado a partir de um arquivo fonte .dts. Este patch é carregado pelo bootloader (UEFI) e aplicado ao Kernel durante a fase de inicialização.
<br>

Para verificar os endereços soc_... associados as respectivas linhas (pins do SoC), usar o comando:
```markdown
> sudo cat /sys/kernel/debug/pinctrl/2430000.pinmux/pins
```
---

### Verificar o Jetpack da Jetson utilizada:
```markdown 
//Execuar o comando abaixo para exibir a versão do Jetpack:
> apt show nvidia-jetpack..

// Deve retornar um conteúdo pareceido com:
Package: nvidia-jetpack
Version: 6.2.1+b38
Priority: standard
Section: metapackages
Source: nvidia-jetpack (6.2.1)
Maintainer: NVIDIA Corporation
Installed-Size: 199 kB
Depends: nvidia-jetpack-runtime (= 6.2.1+b38), nvidia-jetpack-dev (= 6.2.1+b38)
Homepage: http://developer.nvidia.com/jetson
Download-Size: 29.3 kB
APT-Sources: https://repo.download.nvidia.com/jetson/common r36.4/main arm64 Packages
Description: NVIDIA Jetpack Meta Package

```
## Passos para a cofiguração dos pinos e IO:
### 1º. Elaborar o arquivo .dts com as informações da funções dos pinos.
Criar o arquivo io_config_voris.dts e copiar o conteúdo abaixo para este arquivo

```markdown
> nano io_config_voris.dts
```
Copiar o conteúdo abaixo para dentro do arquivo e salvar:  

```markdown
/dts-v1/;
/plugin/;

/ {  
    jetson-header-name = "Jetson 40pin Header";  
    overlay-name = "Multi-Pin GPIO Bidirectional Trigger";
    compatible = "nvidia,p3768-0000+p3767-0000\0nvidia,p3768-0000+p3767-0001\0nvidia,p3768-0000+p3767-0003\0nvidia,p3768-0000+p3767-0004\0nvidia,p3768-0000+p3767-0005\0nvidia,p3768-0000+p3767-0000-super\0nvidia,p3768-0000+p3767-0001-super\0nvidia,p3768-0000+p3767-0003-super\0nvidia,p3768-0000+p3767-0004-super\0nvidia,p3768-0000+p3767-0005-super\0nvidia,p3509-0000+p3767-0000\0nvidia,p3509-0000+p3767-0001\0nvidia,p3509-0000+p3767-0003\0nvidia,p3509-0000+p3767-0004\0nvidia,p3509-0000+p3767-0005";

    fragment@0 {
        target = <&pinmux>;

        __overlay__ {
            pinctrl-names = "default";
            pinctrl-0 = <&jetson_io_pinmux>;

            jetson_io_pinmux: exp-header-pinmux {
                /* Pino 33 - PH.00 */
                hdr40-pin33 {
                    nvidia,pins = "soc_gpio21_ph0";
                    nvidia,tristate = <0x0>;
                    nvidia,enable-input = <0x1>;
                    nvidia,pull = <0x0>;
                };

                /* Pino 15 - PN.01 (Corrigido para soc_gpio31_pn1) */
                hdr40-pin15 {
                    nvidia,pins = "soc_gpio39_pn1";
                    nvidia,tristate = <0x0>;
                    nvidia,enable-input = <0x1>;
                    nvidia,pull = <0x0>;
                };

                /* Pino 7 - PAC.06 */
                hdr40-pin7 {
                    nvidia,pins = "soc_gpio59_pac6";
                    nvidia,tristate = <0x0>;
                    nvidia,enable-input = <0x1>;
                    nvidia,pull = <0x0>;
                };

                /* Pino 29 - PQ.05 */
                hdr40-pin29 {
                    nvidia,pins = "soc_gpio32_pq5";
                    nvidia,tristate = <0x0>;
                    nvidia,enable-input = <0x1>;
                    nvidia,pull = <0x0>;
                };

                /* Pino 31 - PQ.06 */
                hdr40-pin31 {
                    nvidia,pins = "soc_gpio33_pq6";
                    nvidia,tristate = <0x0>;
                    nvidia,enable-input = <0x1>;
                    nvidia,pull = <0x0>;
                };

                /* Pino 32 - PG.06 */
                hdr40-pin32 {
                    nvidia,pins = "soc_gpio19_pg6";
                    nvidia,tristate = <0x0>;
                    nvidia,enable-input = <0x1>;
                    nvidia,pull = <0x0>;
                };
            };
        };
    };
};
```

### 2º. Compilar o arquivo de patch de hardware

```markdown
> dtc -O dtb -o io_config_voris.dtbo io_config_voris.dts
```

### 3º. Copiar o arquivo compilado para a pasta /boot

```markdown
> sudo cp io_config_voris.dtbo /boot
```

### 4º. Executar o programa Jetson.GPIO
 
```markdown
> sudo /opt/nvidia/jetson-io/jetson-io.py
```
1. Na tela inicial, selecionar a opção -> "Configure Jetson 40pin Header"
2. Na segunda tela selecionar -> "Configure for compatible hardware"
3. Na terceira tela selecionar -> "Config pins IO Jetson - Voris"
4. Na quarta tela salvar a configuração escolhida -> "Save pins changes"
5. Na última tela escoler a opção -> "Save and reboot to reconfigure pins"
6. Por último pressione qualquer tecla para dar um reboot na Jetson



### 4º. Testar as novas configurações do spinos de IO

Para testar, colocar a ponteir do osciloscópio em um dos pinos de IO, e monitorar
a variação do nivel alto e baixo com os seguintes comandos no sheel:

Verificar se os pinos foram reconfigurados para output como o comando
```markdown
> gpioinfo | grep -i "PH.00"
```
Deverá retornar com "output":
```markdown
line  43:      "PH.00"       unused  output  active-high
```

Para colocar o pino escolhido em nivel "alto" usar o comando no sheel:
```markdown
// Após este comando com o osciloscópio no pino 33 deverá mostrar 3,3V
> gpioset gpiochip0 43=1
```

Para colocar o pino escolhido em nivel "baixo" usar o comando no sheel:
```markdown
// Após este comando com o osciloscópio no pino 33 deverá mostrar 0V
> gpioset gpiochip0 43=0
```

### Anexo:
O procedimentoe acima automaticamente efetua uma alterção no arquivo *extlinux.conf*, que contpem a configuração do extlinux, e atua como o menu de inicialização (bootloader) para o Kernel Linux em sistemas embarcados como a sua Jetson Orin Nano.

Após o procedimento acima, para ver o conteúdo do arquivo *extlinux.conf*, usar o comando:
```markdown
// Após este comando com o osciloscópio no pino 33 deverá mostrar 0V
> sudo nano /boot/extlinux/extlinux.conf
```
Ele deverá retonar o seguinte conteúdo:
```markdown
TIMEOUT 30
DEFAULT JetsonIO

MENU TITLE L4T boot options

LABEL primary
      MENU LABEL primary kernel
      LINUX /boot/Image
      INITRD /boot/initrd
      APPEND ${cbootargs} root=PARTUUID=fb7751d0-c3e2-4508-9688-18f67930cd7f rw rootwait rootfstype=ext4 mminit_loglevel=4 console=ttyTCU0,115200 firmware_class.path=/etc/firmware fbcon=map:0 video=efifb:off console=tty0 nv-auto-config

# When testing a custom kernel, it is recommended that you create a backup of
# the original kernel and add a new entry to this file so that the device can
# fallback to the original kernel. To do this:
#
# 1, Make a backup of the original kernel
#      sudo cp /boot/Image /boot/Image.backup
#
# 2, Copy your custom kernel into /boot/Image
#
# 3, Uncomment below menu setting lines for the original kernel
#
# 4, Reboot

# LABEL backup
#    MENU LABEL backup kernel
#    LINUX /boot/Image.backup
#    INITRD /boot/initrd
#    APPEND ${cbootargs}

LABEL JetsonIO
        MENU LABEL Custom Header Config: <HDR40 Config pins IO Jetson - Voris>
        LINUX /boot/Image
        FDT /boot/dtb/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb
        INITRD /boot/initrd
        APPEND ${cbootargs} root=PARTUUID=fb7751d0-c3e2-4508-9688-18f67930cd7f rw rootwait rootfstype=ext4 mminit_loglevel=4 console=ttyTCU0,115200 firmware_class.path=/etc/firmware fbcon=map:0 video=efifb:off console=tty0 nv-auto-config
        OVERLAYS /boot/io_config_voris.dtbo

```

Obs.: Perceber que o procedimento alterou o o boot DEFAULT para o LABEL JetsonIO, conforme a linha: **DEFAULT JetsonIO**.   
Antes era DEFAULT primary.





