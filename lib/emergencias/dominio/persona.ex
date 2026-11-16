defmodule Persona do
  @moduledoc "Personas afectadas, sus estados y su historial de cambios."

  @estados ["sin_informacion", "reportada", "localizada", "trasladada", "en_albergue", "reunificada"]
  @titulos "documento,nombre,edad,zona,estado,albergue"
  @titulos_historial "documento,fecha,anterior,nuevo,usuario"

  # Una persona reunificada ya no cambia de estado
  @transiciones %{
    "sin_informacion" => ["reportada", "localizada"],
    "reportada" => ["localizada", "trasladada", "en_albergue"],
    "localizada" => ["trasladada", "en_albergue", "reunificada"],
    "trasladada" => ["localizada", "en_albergue", "reunificada"],
    "en_albergue" => ["trasladada", "reunificada"],
    "reunificada" => []
  }

  defstruct documento: "", nombre: "", edad: 0, zona: "", estado: "sin_informacion", albergue: "", historial: []

  def estados(), do: @estados
  def titulos(), do: @titulos
  def titulos_historial(), do: @titulos_historial

  def crear(documento, nombre, zona, estado, edad) do
    cond do
      documento == "" or nombre == "" ->
        {:error, "El documento y el nombre son obligatorios"}

      zona == "" ->
        {:error, "La zona es obligatoria"}

      not Enum.member?(@estados, estado) ->
        {:error, "Estado inválido. Use: #{Enum.join(@estados, ", ")}"}

      true ->
        case Validaciones.entero_no_negativo(edad, "edad") do
          {:ok, numero} -> {:ok, %Persona{documento: documento, nombre: nombre, zona: zona, estado: estado, edad: numero}}
          error -> error
        end
    end
  end

  # Devuelve la persona con el nuevo estado y el cambio agregado al historial
  def cambiar_estado(p, nuevo, usuario) do
    cond do
      not Enum.member?(@estados, nuevo) ->
        {:error, "Estado inválido. Use: #{Enum.join(@estados, ", ")}"}

      p.estado == nuevo ->
        {:error, "#{p.nombre} ya está en estado #{nuevo}"}

      Enum.member?(Map.get(@transiciones, p.estado, []), nuevo) ->
        cambio = {Util.ahora(), p.estado, nuevo, usuario}
        {:ok, %{p | estado: nuevo, historial: p.historial ++ [cambio]}}

      true ->
        {:error, "Transición no válida: #{p.estado} -> #{nuevo}"}
    end
  end

  def coincide?(p, campo, valor) do
    case campo do
      "documento" -> p.documento == valor
      "nombre" -> String.contains?(String.downcase(p.nombre), String.downcase(valor))
      "zona" -> p.zona == valor
      "estado" -> p.estado == valor
      _ -> false
    end
  end

  # La persona se guarda en una línea; su historial va en otro archivo
  def a_campos(p), do: [p.documento, p.nombre, p.edad, p.zona, p.estado, p.albergue]

  def de_campos([documento, nombre, edad, zona, estado, albergue]) do
    case Validaciones.convertir_entero(edad) do
      {:ok, n} -> {:ok, %Persona{documento: documento, nombre: nombre, edad: n, zona: zona, estado: estado, albergue: albergue}}
      :error -> :error
    end
  end

  def de_campos(_), do: :error
end
