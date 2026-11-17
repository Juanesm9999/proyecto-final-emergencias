# Emergencias

# Sistema Distribuido de Coordinación y Gestión de Emergencias (Elixir)

Proyecto final de Programación III – Universidad del Quindío.

Plataforma multiusuario para coordinar la atención después de un terremoto: usuarios, zonas, necesidades, recursos, comunicación entre familiares, mascotas y albergues. Un nodo servidor mantiene el estado con GenServer bajo un árbol de supervisión, y cada usuario se conecta desde su propio nodo cliente.

## Equipo

| Nombre completo | Código | Correo |
|---|---|---|
|Luisa María Gómez Gómez | 1092456120 | luisam.gomezg@uqvirtual.edu.co |
|Juan Esteban Mejía | 1095551978 | juane.mejiat@uqvirtual.edu.co |
| Juan Camilo Gordillo | 1193032120 | juanc.gordilloh@uqvirtual.edu.co |

## Requisitos

- Elixir 1.17 o superior.
- No usa dependencias externas.

## Instalación

```
git clone https://github.com/Juanesm9999/proyecto-final-emergencias.git
cd proyecto-final-emergencias
mix compile
```

## Ejecución

**1. Servidor** (terminal 1, en la carpeta del proyecto):

```
elixir --sname servidor@localhost --cookie emergencias -S mix run --no-halt
```

**2. Clientes** (una terminal por usuario, en la carpeta `cliente`):

```
cd cliente
elixir --sname laura@localhost --cookie emergencias --hidden cliente.exs
```

Cada usuario usa un `--sname` distinto (`laura`, `pedro`, `ana`…) y la misma cookie que el servidor. Se escribe un comando por línea y `exit` para salir.

**3. Flujo de ejemplo** con archivos de comandos (lanzar los cuatro casi al mismo tiempo, cada uno en su terminal dentro de `cliente`):

```
elixir --sname laura@localhost  --cookie emergencias --hidden cliente.exs comandos/1_laura_coordinadora.txt
elixir --sname pedro@localhost  --cookie emergencias --hidden cliente.exs comandos/2_pedro_coordinador.txt
elixir --sname ana@localhost    --cookie emergencias --hidden cliente.exs comandos/3_ana_ciudadana.txt
elixir --sname carlos@localhost --cookie emergencias --hidden cliente.exs comandos/4_carlos_voluntario.txt
elixir --sname laura2@localhost --cookie emergencias --hidden cliente.exs comandos/5_laura_resumen.txt
```

Los datos se guardan en archivos `.csv` dentro de la carpeta `data/`. Para empezar sin datos, detenga el servidor y borre esa carpeta.

## Ejemplo de uso

```
connect laura 1234 coordinador centro
register_need agua 30 critica centro "Punto de atención sector 3"
register_resource R001 agua 50 litros centro_acopio_1
assign_resource N001 agua 30
summary
```

## Comandos

Primero hay que conectarse; si el usuario no existe se registra automáticamente. `help` muestra los comandos permitidos para el rol del usuario. Todos los comandos también se pueden escribir en español (`ayuda`, `conectar`, `registrar_necesidad`, `asignar_recurso`, `resumen`…).

| Área | Comandos |
|---|---|
| Usuarios | `connect`, `disconnect`, `help`, `whoami`, `users`, `activity` |
| Zonas | `register_zone`, `register_sector`, `register_point`, `list_zones`, `zone_status` |
| Necesidades | `register_need`, `list_needs`, `pending_needs`, `update_need`, `assign_resource`, `attend_pending` |
| Recursos | `register_resource`, `resource_in`, `resource_out`, `list_resources`, `resource_history`, `transfer_resource`, `critical_resources` |
| Familiares | `report_person`, `update_person`, `find_person`, `person_history`, `send_family_message`, `list_family_messages`, `deliver_message` |
| Mascotas | `report_pet`, `list_pets`, `match_pets`, `confirm_match` |
| Albergues | `register_shelter`, `list_shelters`, `check_shelter`, `register_entry`, `register_exit`, `shelters_report` |
| Resumen | `summary` |

Roles: `ciudadano` ⊂ `voluntario` ⊂ `coordinador` ⊂ `administrador` (cada rol incluye los comandos del anterior).

## Pruebas

```
mix test
mix run scripts/demo_concurrencia.exs
```

`mix test` ejecuta 29 pruebas; el script muestra el conflicto concurrente del enunciado (dos usuarios piden agua al mismo tiempo y solo una asignación se confirma).
