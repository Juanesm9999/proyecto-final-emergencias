defmodule Recurso do
  @moduledoc "Recursos del inventario (agua, alimentos, medicamentos...)."

  @titulos "codigo,nombre,categoria,cantidad,unidad,ubicacion,zona"

  defstruct codigo: "", nombre: "", categoria: "", cantidad: 0, unidad: "", ubicacion: "", zona: ""

  def titulos(), do: @titulos

  def crear(codigo, categoria, cantidad, unidad, ubicacion, zona, nombre) do
    cond do
      codigo == "" or categoria == "" ->
        {:error, "El código y la categoría son obligatorios"}

      unidad == "" or ubicacion == "" ->
        {:error, "La unidad y la ubicación son obligatorias"}

      true ->
        case Validaciones.entero_no_negativo(cantidad, "cantidad") do
          {:ok, numero} ->
            nombre_final = if nombre == "", do: categoria, else: nombre

            {:ok,
             %Recurso{codigo: codigo, categoria: categoria, cantidad: numero, unidad: unidad,
                      ubicacion: ubicacion, zona: zona, nombre: nombre_final}}

          error ->
            error
        end
    end
  end

  def entrada(r, cantidad) when cantidad > 0, do: {:ok, %{r | cantidad: r.cantidad + cantidad}}
  def entrada(_r, _cantidad), do: {:error, "La cantidad debe ser mayor que cero"}

  # Nunca deja el inventario en negativo
  def salida(_r, cantidad) when cantidad <= 0, do: {:error, "La cantidad debe ser mayor que cero"}

  def salida(r, cantidad) when cantidad > r.cantidad,
    do: {:error, "Inventario insuficiente en #{r.codigo}: hay #{r.cantidad} #{r.unidad} y se pidieron #{cantidad}"}

  def salida(r, cantidad), do: {:ok, %{r | cantidad: r.cantidad - cantidad}}

  def a_campos(r), do: [r.codigo, r.nombre, r.categoria, r.cantidad, r.unidad, r.ubicacion, r.zona]

  def de_campos([codigo, nombre, categoria, cantidad, unidad, ubicacion, zona]) do
    case Validaciones.convertir_entero(cantidad) do
      {:ok, n} ->
        {:ok, %Recurso{codigo: codigo, nombre: nombre, categoria: categoria, cantidad: n, unidad: unidad,
                       ubicacion: ubicacion, zona: zona}}

      :error ->
        :error
    end
  end

  def de_campos(_), do: :error
end
