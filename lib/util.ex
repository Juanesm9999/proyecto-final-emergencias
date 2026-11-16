defmodule Util do
  @moduledoc """
  Funciones reutilizables. Las primeras son las del módulo Util visto en clase;
  las de la segunda parte son propias del proyecto.
  Las validaciones de datos están en el módulo Validaciones.
  """

  # ======================= Util de clase =======================
  def mostrar_mensaje(mensaje), do: mensaje |> IO.puts()

  def mostrar_error(mensaje), do: IO.puts(:standard_error, mensaje)

  def ingresar(mensaje, :texto) do
    mensaje
    |> IO.gets()
    |> String.trim()
  end

  def ingresar(mensaje, :entero), do: ingresar(mensaje, &String.to_integer/1, :entero)
  def ingresar(mensaje, :real), do: ingresar(mensaje, &String.to_float/1, :real)

  def ingresar(mensaje, :boolean) do
    valor =
      mensaje
      |> ingresar(:texto)
      |> String.downcase()

    Enum.member?(["si", "sí", "s"], valor)
  end

  defp ingresar(mensaje, parser, tipo_dato) do
    try do
      mensaje
      |> ingresar(:texto)
      |> parser.()
    rescue
      ArgumentError ->
        "Error, se espera que ingrese un número #{tipo_dato}\n"
        |> mostrar_error()

        mensaje
        |> ingresar(parser, tipo_dato)
    end
  end

  # ======================= Propias del proyecto =======================

  # siguiente_id("N", 7) -> "N008"
  def siguiente_id(prefijo, consecutivo) do
    numero = consecutivo + 1

    cond do
      numero < 10 -> "#{prefijo}00#{numero}"
      numero < 100 -> "#{prefijo}0#{numero}"
      true -> "#{prefijo}#{numero}"
    end
  end

  # Fecha y hora actual en texto, sin microsegundos
  def ahora() do
    NaiveDateTime.local_now()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_string()
  end

  # Quita las comillas y los saltos de línea para que un texto libre no dañe el CSV
  def limpiar(texto) do
    texto
    |> to_string()
    |> String.replace("\"", "'")
    |> String.replace("\n", " ")
  end
end
