defmodule SesionesSupervisor do
  @moduledoc """
  DynamicSupervisor de las sesiones: crea un proceso Sesion por cada usuario
  que se conecta (los hijos se crean mientras el sistema está funcionando).

  El cliente es el servicio de respuesta del nodo que se conectó,
  por ejemplo {:servicio_respuesta, :laura@localhost}.
  """
  use DynamicSupervisor

  def start_link(_), do: DynamicSupervisor.start_link(SesionesSupervisor, :ok, name: SesionesSupervisor)

  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)

  # Abre la sesión (si el cliente ya tenía una, la reemplaza)
  def iniciar(cliente, usuario) do
    cerrar(cliente)
    DynamicSupervisor.start_child(SesionesSupervisor, {Sesion, {cliente, usuario}})
  end

  # Usuario conectado desde ese cliente, o nil
  def obtener(cliente) do
    case buscar(cliente) do
      nil -> nil
      {_pid, {_cliente, usuario}} -> usuario
    end
  end

  def cerrar(cliente) do
    case buscar(cliente) do
      nil -> :ok
      {pid, _datos} -> DynamicSupervisor.terminate_child(SesionesSupervisor, pid)
    end
  end

  def conectados() do
    sesiones()
    |> Enum.map(fn {_pid, {_cliente, usuario}} -> usuario end)
  end

  def reiniciar() do
    Enum.each(pids(), fn pid -> DynamicSupervisor.terminate_child(SesionesSupervisor, pid) end)
  end

  defp buscar(cliente), do: Enum.find(sesiones(), fn {_pid, {c, _usuario}} -> c == cliente end)

  # [{pid, {cliente, usuario}}, ...] de las sesiones abiertas
  defp sesiones() do
    pids()
    |> Enum.map(fn pid -> {pid, Sesion.datos(pid)} end)
    |> Enum.filter(fn {_pid, datos} -> datos != nil end)
  end

  defp pids() do
    SesionesSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_id, pid, _tipo, _modulos} -> pid end)
  end
end
