#!/bin/sh
ip addr add 10.10.10.1/23 dev eth0
#!/bin/bash

### INTERFACES (MODIFICA ESTO)
WAN_IFACE="eth1"   # interfaz que sale a Internet
LAN_IFACE="eth0"   # interfaz interna
SQUID_PORT="3128"

echo "[+] Activando IP Forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/^#net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p

echo "[+] Limpiando reglas anteriores..."
iptables -F
iptables -X
iptables -t nat -F
iptables -t mangle -F

echo "[+] Estableciendo políticas por defecto..."
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

echo "[+] Permitimos tráfico local..."
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

echo "[+] Permitimos tráfico ESTABLISHED,RELATED..."
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

echo "[+] Permitimos tráfico desde LAN hacia Squid..."
iptables -A INPUT -i $LAN_IFACE -p tcp --dport $SQUID_PORT -j ACCEPT

echo "[+] Permitimos que Squid (servidor) salga a Internet (HTTP/HTTPS)..."
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

echo "[+] Permitimos DNS (para Squid y el servidor)..."
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT

echo "[+] Permitimos que la LAN acceda a Internet (FORWARD)..."
iptables -A FORWARD -i $LAN_IFACE -o $WAN_IFACE -j ACCEPT

echo "[+] Activando NAT (MASQUERADE)..."
iptables -t nat -A POSTROUTING -o $WAN_IFACE -j MASQUERADE

echo "[+] Permitir ping opcional..."
iptables -A INPUT -p icmp -j ACCEPT

echo "[+] Bloqueo adicional de puertos peligrosos (SMB, Telnet, etc.)"
iptables -A FORWARD -p tcp --dport 23 -j DROP
iptables -A FORWARD -p tcp --dport 445 -j DROP
iptables -A FORWARD -p tcp --dport 135:139 -j DROP

echo "[+] Guardando reglas..."
iptables-save > /etc/iptables.rules

echo "[+] Creando servicio para cargar reglas al iniciar..."

cat <<EOF >/etc/network/if-pre-up.d/iptablesload
#!/bin/sh
iptables-restore < /etc/iptables.rules
EOF

chmod +x /etc/network/if-pre-up.d/iptablesload

echo "[+] Configuración finalizada."
echo "Interfaz WAN: $WAN_IFACE"
echo "Interfaz LAN: $LAN_IFACE"
echo "Squid escuchando en el puerto $SQUID_PORT"
echo "[✔] Firewall y NAT configurados correctamente."

