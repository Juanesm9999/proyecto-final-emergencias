defmodule Albergue do
  @moduledoc """
  Albergues: capacidad y ocupantes.
  Los ocupantes se guardan en un MapSet (conjunto): una persona no puede quedar dos veces.
  """

  @titulos "codigo,nombre,zona,capacidad,ocupantes"

  defstruct codigo: "", nombre: "", zona: "", capacidad: 0, ocupantes: MapSet.new()

  def titulos(), do: @titulos

  def crear(codigo, nombre, zona, capacidad) do
    if codigo == "" or nombre == "" or zona == "" do
      {:error, "Código, nombre y zona son obligatorios"}
    else
      case Validaciones.entero_positivo(capacidad, "capacidad") do
        {:ok, numero} -> {:ok, %Albergue{codigo: codigo, nombre: nombre, zona: zona, capacidad: numero}}
        error -> error
      end
    end
  end

  def ocupacion(a), do: MapSet.size(a.ocupantes)
  def cupos(a), do: a.capacidad - ocupacion(a)
  def porcentaje(a), do: Float.round(ocupacion(a) * 100 / a.capacidad, 1)

  def ingresar(a, documento) do
    cond do
      MapSet.member?(a.ocupantes, documento) -> {:error, "La persona #{documento} ya está en el albergue #{a.codigo}"}
      cupos(a) <= 0 -> {:error, "El albergue #{a.codigo} está lleno (#{a.capacidad} personas)"}
      true -> {:ok, %{a | ocupantes: MapSet.put(a.ocupantes, documento)}}
    end
  end

  def retirar(a, documento) do
    if MapSet.member?(a.ocupantes, documento) do
      {:ok, %{a | ocupantes: MapSet.delete(a.ocupantes, documento)}}
    else
      {:error, "La persona #{documento} no está en el albergue #{a.codigo}"}
    end
  end

  def lista_ocupantes(a), do: a.ocupantes |> MapSet.to_list() |> Enum.sort()

  # Los ocupantes se guardan separados por ";" dentro del mismo campo
  def a_campos(a), do: [a.codigo, a.nombre, a.zona, a.capacidad, Enum.join(lista_ocupantes(a), ";")]

  def de_campos([codigo, nombre, zona, capacidad, ocupantes]) do
    case Validaciones.convertir_entero(capacidad) do
      {:ok, n} ->
        lista = String.split(ocupantes, ";", trim: true)
        {:ok, %Albergue{codigo: codigo, nombre: nombre, zona: zona, capacidad: n, ocupantes: MapSet.new(lista)}}

      :error ->
        :error
    end
  end

  def de_campos(_), do: :error
end
