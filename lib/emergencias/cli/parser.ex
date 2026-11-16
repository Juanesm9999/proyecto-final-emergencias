defmodule Parser do
  @moduledoc """
  Separa una línea de comando en palabras respetando el texto entre comillas.

      Parser.tokenizar(~s(send_family_message 123 "Estoy bien, en el albergue"))
      #=> ["send_family_message", "123", "Estoy bien, en el albergue"]

  FUNCIÓN RECURSIVA: recorre los caracteres uno por uno.
  """

  def tokenizar(linea) do
    linea
    |> String.trim()
    |> String.graphemes()
    |> recorrer([], "", false)
  end

  # caso base: no quedan caracteres
  defp recorrer([], palabras, actual, _en_comillas), do: Enum.reverse(agregar(palabras, actual))

  # una comilla abre o cierra un texto
  defp recorrer(["\"" | resto], palabras, actual, en_comillas),
    do: recorrer(resto, palabras, actual, not en_comillas)

  # un espacio fuera de comillas separa palabras
  defp recorrer([" " | resto], palabras, actual, false),
    do: recorrer(resto, agregar(palabras, actual), "", false)

  # cualquier otro caracter se agrega a la palabra actual
  defp recorrer([caracter | resto], palabras, actual, en_comillas),
    do: recorrer(resto, palabras, actual <> caracter, en_comillas)

  defp agregar(palabras, ""), do: palabras
  defp agregar(palabras, palabra), do: [palabra | palabras]
end
