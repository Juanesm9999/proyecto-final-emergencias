defmodule Mensaje do
  @moduledoc "Mensajes para familiares (el destinatario es el documento de la persona)."

  @titulos "id,fecha,remitente,destinatario,contenido,estado"

  defstruct id: "", fecha: "", remitente: "", destinatario: "", contenido: "", estado: "pendiente"

  def titulos(), do: @titulos

  def crear(id, remitente, destinatario, contenido) do
    if String.trim(contenido) == "" do
      {:error, "El mensaje no puede estar vacío"}
    else
      {:ok, %Mensaje{id: id, fecha: Util.ahora(), remitente: remitente, destinatario: destinatario, contenido: contenido}}
    end
  end

  def entregar(%Mensaje{estado: "entregado"} = m), do: {:error, "El mensaje #{m.id} ya fue entregado"}
  def entregar(m), do: {:ok, %{m | estado: "entregado"}}

  def a_campos(m), do: [m.id, m.fecha, m.remitente, m.destinatario, m.contenido, m.estado]

  def de_campos([id, fecha, remitente, destinatario, contenido, estado]),
    do: {:ok, %Mensaje{id: id, fecha: fecha, remitente: remitente, destinatario: destinatario, contenido: contenido, estado: estado}}

  def de_campos(_), do: :error
end
