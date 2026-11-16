# Las pruebas usan su propia carpeta de datos para no borrar los datos reales
Application.put_env(:emergencias, :carpeta_datos, "tmp/test_data")

ExUnit.start()

defmodule Ayuda do
  # Ejecuta un comando como si viniera del cliente dado
  def como(cliente, linea), do: Comandos.ejecutar(cliente, linea)

  # Cada "cliente" de prueba es un servicio de respuesta distinto, como en un nodo real
  def nuevo_cliente(), do: {:servicio_respuesta, :"cliente#{:rand.uniform(1_000_000)}@localhost"}
end
