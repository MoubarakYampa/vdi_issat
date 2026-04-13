# Serveur Ubuntu — Ressources système

## Informations système

| Paramètre | Valeur |
|---|---|
| **OS** | Ubuntu Linux |
| **Kernel** | 6.8.0-106-generic (x86_64) |
| **Compilé le** | 6 mars 2026 |
| **Architecture** | x86_64 |

## Mémoire RAM

| | Total | Utilisé | Libre | Disponible |
|---|---|---|---|---|
| **RAM** | 21 Go | 3,4 Go | 506 Mo | 17 Go |
| **Swap** | 8 Go | 669 Mo | 7,3 Go | — |

> Le serveur dispose de beaucoup de mémoire disponible (~17 Go). Chaque container Kasm est limité à 1 Go, donc le serveur peut théoriquement accueillir **~15 bureaux simultanés**.

## Stockage disque

| Partition | Taille | Utilisé | Disponible | % |
|---|---|---|---|---|
| `/` (LVM ubuntu-vg) | 95 Go | 60 Go | 31 Go | 66% |
| `/boot` | 2 Go | 200 Mo | 1,6 Go | 11% |

> Le disque principal est rempli à 66%. Avec la croissance des données étudiants (dossiers `kasm-data`), il est recommandé de surveiller l'espace disponible régulièrement.
