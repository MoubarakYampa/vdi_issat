# Infrastructure réseau & pfSense

## Topologie réseau

```
WAN (Internet / réseau externe)
    │
    │  IP WAN : 192.168.11.196
    ▼
┌──────────┐
│ pfSense  │
└──────────┘
    │
    │  IP LAN : 192.168.1.1
    │  Réseau LAN : 192.168.1.0/24
    ▼
Serveur Ubuntu : 192.168.1.3
```

## Règles NAT configurées sur pfSense

Les règles de NAT (Port Forwarding) redirigent les connexions entrantes sur le WAN vers le serveur Ubuntu :

| Port(s) WAN | IP destination | Port destination | Usage |
|---|---|---|---|
| **80** | 192.168.1.3 | 80 | Nginx (Authentik + VDI) |
| **7000–8000** | 192.168.1.3 | 7000–8000 | Accès direct aux containers Kasm (à éviter en production) |

> **Note :** Les ports 7000–8000 exposent directement les containers noVNC sans authentification. En production, seul le port 80 (via Nginx qui force l'authentification) devrait être exposé.

## Réseau interne du serveur Ubuntu

| Interface | Adresse | Usage |
|---|---|---|
| `ens18` | 192.168.1.3/24 | Interface physique, réseau LAN |
| `docker0` | 172.17.0.1/16 | Réseau Docker par défaut (containers Kasm) |
| `br-8264da28702a` | 172.18.0.1/16 | Réseau Docker `ubuntu_default` (Authentik stack) |
| `lo` | 127.0.0.1 | Loopback |

## DNS local (noms d'hôtes utilisés)

| Nom | Résolution | Usage |
|---|---|---|
| `issat.local` | 192.168.1.3 | Interface Authentik (réseau interne) |
| `labo.issat.local` | 192.168.1.3 ou 192.168.11.196 | Portail VDI + accès aux bureaux |

> Ces noms doivent être configurés dans pfSense (DNS Resolver) ou dans les fichiers `/etc/hosts` des postes clients.
