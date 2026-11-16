defmodule Mascota do
  @moduledoc """
  Reportes de mascotas perdidas y encontradas, y el cálculo de coincidencias.

  Puntaje de similitud (0 a 100), solo si la especie es la misma:
    especie 35 · color 20 · tamaño 15 · zona 15 · características en común hasta 10 · nombre 5
  Se considera posible coincidencia desde 60 puntos.
  """

  @umbral 60
  @tipos %{"lost" => "perdida", "found" => "encontrada", "perdida" => "perdida", "encontrada" => "encontrada"}
  @criterios [{:especie, 35}, {:color, 20}, {:tamano, 15}, {:zona, 15}, {:nombre, 5}]
  @titulos "id,tipo,especie,nombre,caracteristicas,color,tamano,zona,contacto,estado,coincidencia"

  defstruct id: "", tipo: "", especie: "", nombre: "", caracteristicas: "", color: "", tamano: "",
            zona: "", contacto: "", estado: "activa", coincidencia: ""

  def umbral(), do: @umbral
  def titulos(), do: @titulos

  def crear(id, tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas) do
    cond do
      not Map.has_key?(@tipos, tipo) ->
        {:error, "Tipo de reporte inválido. Use lost/found (perdida/encontrada)"}

      especie == "" or color == "" or tamano == "" or zona == "" or contacto == "" ->
        {:error, "Especie, color, tamaño, zona y contacto son obligatorios"}

      true ->
        {:ok,
         %Mascota{id: id, tipo: @tipos[tipo], especie: String.downcase(especie), nombre: nombre,
                  color: String.downcase(color), tamano: String.downcase(tamano), zona: zona,
                  contacto: contacto, caracteristicas: caracteristicas}}
    end
  end

  # Puntaje de similitud: la suma recursiva de criterios está en Algoritmos
  def puntaje(%Mascota{especie: e1}, %Mascota{especie: e2}) when e1 != e2, do: 0

  def puntaje(perdida, encontrada) do
    Algoritmos.sumar_criterios(@criterios, perdida, encontrada, 0) + puntaje_caracteristicas(perdida, encontrada)
  end

  # El nombre solo cuenta si ambos reportes lo conocen
  def iguales?(:nombre, a, b) do
    conocido?(a.nombre) and conocido?(b.nombre) and String.downcase(a.nombre) == String.downcase(b.nombre)
  end

  def iguales?(campo, a, b), do: Map.get(a, campo) == Map.get(b, campo)

  # 5 puntos por cada palabra en común en las características (máximo 10)
  defp puntaje_caracteristicas(a, b) do
    palabras_b = palabras(b.caracteristicas)

    comunes =
      a.caracteristicas
      |> palabras()
      |> Enum.filter(fn palabra -> Enum.member?(palabras_b, palabra) end)
      |> Enum.count()

    min(comunes * 5, 10)
  end

  defp palabras(texto) do
    texto
    |> String.downcase()
    |> String.split([" ", ","], trim: true)
    |> Enum.filter(fn palabra -> String.length(palabra) > 2 end)
    |> Enum.uniq()
  end

  def marcar_posible(%Mascota{estado: "activa"} = m), do: %{m | estado: "posible_coincidencia"}
  def marcar_posible(m), do: m

  # Cierra los dos reportes. Un reporte resuelto no se puede resolver otra vez.
  def confirmar_pareja(a, b) do
    cond do
      a.tipo == b.tipo -> {:error, "Debe confirmar un reporte de mascota perdida con uno de mascota encontrada"}
      a.especie != b.especie -> {:error, "Los reportes son de especies diferentes (#{a.especie} y #{b.especie})"}
      a.estado == "resuelta" -> {:error, "El reporte #{a.id} ya está resuelto"}
      b.estado == "resuelta" -> {:error, "El reporte #{b.id} ya está resuelto"}
      true -> {:ok, %{a | estado: "resuelta", coincidencia: b.id}, %{b | estado: "resuelta", coincidencia: a.id}}
    end
  end

  defp conocido?(nombre), do: nombre != "" and not Enum.member?(["desconocido", "-", "?"], String.downcase(nombre))

  def a_campos(m),
    do: [m.id, m.tipo, m.especie, m.nombre, m.caracteristicas, m.color, m.tamano, m.zona, m.contacto, m.estado, m.coincidencia]

  def de_campos([id, tipo, especie, nombre, caracteristicas, color, tamano, zona, contacto, estado, coincidencia]) do
    {:ok,
     %Mascota{id: id, tipo: tipo, especie: especie, nombre: nombre, caracteristicas: caracteristicas, color: color,
              tamano: tamano, zona: zona, contacto: contacto, estado: estado, coincidencia: coincidencia}}
  end

  def de_campos(_), do: :error
end
