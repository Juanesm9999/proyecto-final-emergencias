defmodule ActividadServer do
  @moduledoc "GenServer que registra la actividad de cada usuario (bitácora)."
  use GenServer

  @archivo "actividad.csv"
  @titulos "fecha,usuario,accion"

  def start_link(_), do: GenServer.start_link(ActividadServer, :ok, name: ActividadServer)

  # cast: registrar no debe hacer esperar al usuario que hizo la acción
  def registrar(usuario, accion), do: GenServer.cast(ActividadServer, {:registrar, usuario, accion})
  def listar(usuario), do: GenServer.call(ActividadServer, {:listar, usuario})
  def reiniciar(), do: GenServer.call(ActividadServer, :reiniciar)

  def init(:ok), do: {:ok, Almacen.leer_csv(@archivo, &de_campos/1)}

  def handle_cast({:registrar, usuario, accion}, registros) do
    fecha = Util.ahora()
    Almacen.agregar_csv([fecha, usuario, accion], @archivo, @titulos)
    {:noreply, registros ++ [{fecha, usuario, accion}]}
  end

  def handle_call({:listar, nil}, _from, registros), do: {:reply, registros, registros}

  def handle_call({:listar, usuario}, _from, registros) do
    {:reply, Enum.filter(registros, fn {_fecha, u, _accion} -> u == usuario end), registros}
  end

  def handle_call(:reiniciar, _from, _registros), do: {:reply, :ok, []}

  defp de_campos([fecha, usuario, accion]), do: {:ok, {fecha, usuario, accion}}
  defp de_campos(_), do: :error
end
