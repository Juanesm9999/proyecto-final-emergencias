defmodule Emergencias do
  @moduledoc """
  Sistema distribuido de coordinación y gestión de emergencias.
  Funciones de apoyo para las pruebas y la consola (iex -S mix).
  """

  @servidores [ActividadServer, UsuariosServer, ZonasServer, RecursosServer, NecesidadesServer,
               PersonasServer, MascotasServer, AlberguesServer, SesionesSupervisor]

  # Borra los datos y deja todos los procesos sin información
  def reiniciar_todo() do
    Almacen.borrar_todo()
    Enum.each(@servidores, fn servidor -> servidor.reiniciar() end)
  end

  # Ejecuta un comando como si viniera de un cliente
  def comando(linea), do: Comandos.ejecutar(self(), linea)
end
