defmodule Movimiento do
  @moduledoc "Historial de movimientos de inventario (entrada, salida, asignacion, transferencia)."

  @titulos "fecha,recurso,tipo,cantidad,detalle,usuario"

  defstruct fecha: "", recurso: "", tipo: "", cantidad: 0, detalle: "", usuario: ""

  def titulos(), do: @titulos

  def crear(recurso, tipo, cantidad, detalle, usuario) do
    %Movimiento{fecha: Util.ahora(), recurso: recurso, tipo: tipo, cantidad: cantidad, detalle: detalle, usuario: usuario}
  end

  def a_campos(m), do: [m.fecha, m.recurso, m.tipo, m.cantidad, m.detalle, m.usuario]

  def de_campos([fecha, recurso, tipo, cantidad, detalle, usuario]) do
    case Validaciones.convertir_entero(cantidad) do
      {:ok, n} -> {:ok, %Movimiento{fecha: fecha, recurso: recurso, tipo: tipo, cantidad: n, detalle: detalle, usuario: usuario}}
      :error -> :error
    end
  end

  def de_campos(_), do: :error
end
