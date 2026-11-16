defmodule Zona do
  @moduledoc """
  Zonas, sectores y puntos de atención.
  Se guardan en una lista plana (cada uno conoce a su padre). El árbol
  zona -> sectores -> puntos se arma con las funciones recursivas de Algoritmos.
  """

  @niveles ["critico", "alto", "medio", "bajo"]
  @peso_nivel %{"critico" => 4, "alto" => 3, "medio" => 2, "bajo" => 1}
  @titulos "codigo,nombre,tipo,nivel,afectados,padre"

  defstruct codigo: "", nombre: "", tipo: "zona", nivel: "bajo", afectados: 0, padre: ""

  def niveles(), do: @niveles
  def titulos(), do: @titulos

  def crear(codigo, nombre, tipo, nivel, afectados, padre) do
    cond do
      codigo == "" or nombre == "" ->
        {:error, "El código y el nombre son obligatorios"}

      not Enum.member?(@niveles, nivel) ->
        {:error, "Nivel inválido. Use: #{Enum.join(@niveles, ", ")}"}

      true ->
        case Validaciones.entero_no_negativo(afectados, "personas afectadas") do
          {:ok, numero} ->
            {:ok, %Zona{codigo: codigo, nombre: nombre, tipo: tipo, nivel: nivel, afectados: numero, padre: padre}}

          error ->
            error
        end
    end
  end

  def nivel_mas_grave(a, b), do: if(@peso_nivel[a] >= @peso_nivel[b], do: a, else: b)

  def a_campos(z), do: [z.codigo, z.nombre, z.tipo, z.nivel, z.afectados, z.padre]

  def de_campos([codigo, nombre, tipo, nivel, afectados, padre]) do
    case Validaciones.convertir_entero(afectados) do
      {:ok, n} -> {:ok, %Zona{codigo: codigo, nombre: nombre, tipo: tipo, nivel: nivel, afectados: n, padre: padre}}
      :error -> :error
    end
  end

  def de_campos(_), do: :error
end
