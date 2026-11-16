defmodule Servidor do
  @moduledoc """
  Nodo servidor: recibe los mensajes de los nodos cliente.

  Igual que en IPC remota, cada cliente envía {productor, mensaje} y recibe
  la respuesta con send(productor, respuesta). Cada solicitud se atiende en
  un proceso aparte (spawn) para que varios usuarios trabajen al mismo tiempo.
  """
  use GenServer

  @nombre_servicio_local :servicio_emergencias

  def start_link(_), do: GenServer.start_link(Servidor, 0, name: @nombre_servicio_local)

  def init(atendidas), do: {:ok, atendidas}

  def handle_info({productor, mensaje}, atendidas) when is_binary(mensaje) do
    spawn(fn -> procesar_mensaje(productor, mensaje) end)
    {:noreply, atendidas + 1}
  end

  def handle_info(_mensaje_desconocido, atendidas), do: {:noreply, atendidas}

  defp procesar_mensaje(productor, mensaje) do
    respuesta = Comandos.ejecutar(productor, mensaje)
    send(productor, respuesta)
  end
end
