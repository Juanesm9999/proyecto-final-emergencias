defmodule Serializador do
  @moduledoc """
  Convierte registros en líneas CSV y líneas CSV en registros.

  Cada campo se escribe entre comillas, así las comas de una descripción no
  rompen la línea. Para leer se usa el Regex.split visto en clase para
  campos con comillas.
  """

  # ["R001", "agua", 50] -> "\"R001\",\"agua\",\"50\""
  def a_linea(campos) do
    campos
    |> Enum.map(fn campo -> "\"#{Util.limpiar(campo)}\"" end)
    |> Enum.join(",")
  end

  # "\"R001\",\"agua\",\"50\"" -> ["R001", "agua", "50"]
  def de_linea(linea) do
    Regex.split(~r/,(?=(?:[^"]*"[^"]*")*[^"]*$)/, linea)
    |> Enum.map(fn campo -> campo |> String.trim() |> String.trim("\"") end)
  end

  # Todas las líneas de un archivo (sin títulos), una por registro
  def generar_mensaje_csv(datos, parser) do
    datos
    |> Enum.map(parser)
    |> Enum.map(&a_linea/1)
    |> Enum.join("\n")
  end

  # ---------- FUNCIÓN RECURSIVA: convierte las líneas, ignorando vacías o dañadas ----------
  def convertir_lineas(lineas, parser), do: convertir_lineas(lineas, parser, [])

  defp convertir_lineas([], _parser, acumulado), do: Enum.reverse(acumulado)

  defp convertir_lineas(["" | resto], parser, acumulado),
    do: convertir_lineas(resto, parser, acumulado)

  defp convertir_lineas([linea | resto], parser, acumulado) do
    case linea |> de_linea() |> parser.() do
      {:ok, registro} -> convertir_lineas(resto, parser, [registro | acumulado])
      :error -> convertir_lineas(resto, parser, acumulado)
    end
  end
end
