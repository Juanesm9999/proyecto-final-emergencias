defmodule Sesion do
  @moduledoc """
  GenServer de la sesión de un usuario conectado.
  Guarda {cliente, usuario}. Lo crea SesionesSupervisor (DynamicSupervisor)
  cuando el usuario hace connect y lo termina cuando hace disconnect.
  """
  use GenServer, restart: :temporary

  def start_link({cliente, usuario}), do: GenServer.start_link(Sesion, {cliente, usuario})

  # Devuelve {cliente, usuario}, o nil si la sesión ya se cerró
  def datos(pid) do
    try do
      GenServer.call(pid, :datos)
    catch
      :exit, _razon -> nil
    end
  end

  def init({cliente, usuario}), do: {:ok, {cliente, usuario}}

  def handle_call(:datos, _from, estado), do: {:reply, estado, estado}
end
