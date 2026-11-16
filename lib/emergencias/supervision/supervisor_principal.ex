defmodule SupervisorPrincipal do
  @moduledoc """
  Supervisor principal (estrategia one_for_one): si un proceso falla,
  solo se reinicia ese proceso y vuelve a leer sus datos del archivo CSV.

  SupervisorPrincipal
  ├── ActividadServer      (GenServer)
  ├── UsuariosServer       (GenServer)
  ├── ZonasServer          (GenServer)
  ├── RecursosServer       (GenServer)
  ├── NecesidadesServer    (GenServer)
  ├── PersonasServer       (GenServer)
  ├── MascotasServer       (GenServer)
  ├── AlberguesServer      (GenServer)
  ├── SesionesSupervisor   (DynamicSupervisor) -> un Sesion por usuario conectado
  └── Servidor             (GenServer :servicio_emergencias) -> un spawn por solicitud
  """
  use Supervisor

  def start_link(_), do: Supervisor.start_link(SupervisorPrincipal, :ok, name: SupervisorPrincipal)

  def init(:ok) do
    hijos = [
      ActividadServer,
      UsuariosServer,
      ZonasServer,
      RecursosServer,
      NecesidadesServer,
      PersonasServer,
      MascotasServer,
      AlberguesServer,
      SesionesSupervisor,
      Servidor
    ]

    Supervisor.init(hijos, strategy: :one_for_one)
  end
end
