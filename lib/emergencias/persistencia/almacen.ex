defmodule Almacen do
  @moduledoc """
  Persistencia en archivos CSV de texto plano (basado en el módulo CSV de clase).
  Almacen lee y escribe los archivos; Serializador convierte cada línea en campos y viceversa.

  - La primera línea de cada archivo tiene los títulos y se salta al leer.
  - Si el archivo no existe (primer arranque) se devuelve una lista vacía.
  """

  # Carpeta de los datos (en las pruebas se cambia a tmp/test_data)
  def ruta(nombre) do
    carpeta = Application.get_env(:emergencias, :carpeta_datos, "data")
    File.mkdir_p!(carpeta)
    Path.join(carpeta, nombre)
  end

  def leer_csv(nombre, parser) do
    archivo = ruta(nombre)

    if File.exists?(archivo) do
      archivo
      |> File.stream!()
      |> Stream.drop(1)
      |> Enum.map(&String.trim/1)
      |> Serializador.convertir_lineas(parser)
    else
      []
    end
  end

  # Reescribe el archivo completo con los datos actuales
  def escribir_csv(datos, nombre, titulos, parser) do
    datos
    |> Serializador.generar_mensaje_csv(parser)
    |> (&(titulos <> "\n" <> &1)).()
    |> (&File.write(ruta(nombre), &1)).()
  end

  # Agrega una línea al final (historiales y bitácora). Si el archivo es nuevo, escribe los títulos.
  def agregar_csv(campos, nombre, titulos) do
    archivo = ruta(nombre)

    if not File.exists?(archivo) do
      File.write(archivo, titulos <> "\n")
    end

    File.write(archivo, Serializador.a_linea(campos) <> "\n", [:append])
  end

  def borrar_todo() do
    carpeta = Application.get_env(:emergencias, :carpeta_datos, "data")
    File.rm_rf(carpeta)
    File.mkdir_p(carpeta)
  end
end
