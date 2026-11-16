# Nodo cliente del sistema de emergencias (basado en nodo-cliente.exs de IPC remota).
#
# Ejecutar desde la carpeta cliente:
#   elixir --sname laura@localhost --cookie emergencias --hidden cliente.exs
# Con un archivo de comandos (para la demostración):
#   elixir --sname laura@localhost --cookie emergencias --hidden cliente.exs comandos/1_laura_coordinadora.txt

Code.require_file("../lib/util.ex")

defmodule NodoCliente do
  @nombre_servicio_local :servicio_respuesta
  # Si el servidor está en otra máquina, cambie localhost por el nombre de esa máquina
  @nodo_remoto :servidor@localhost
  @servicio_remoto {:servicio_emergencias, @nodo_remoto}
  @espera 10_000

  def main() do
    Util.mostrar_mensaje("CLIENTE - SISTEMA DE EMERGENCIAS")

    @nombre_servicio_local
    |> registrar_servicio()

    establecer_conexion(@nodo_remoto)
    |> iniciar(System.argv())
  end

  defp registrar_servicio(nombre_servicio_local),
    do: Process.register(self(), nombre_servicio_local)

  defp establecer_conexion(nodo_remoto) do
    Node.connect(nodo_remoto)
  end

  defp iniciar(false, _argumentos),
    do: Util.mostrar_error("No se pudo conectar con el nodo servidor")

  # Sin archivo: modo interactivo
  defp iniciar(true, []) do
    Util.mostrar_mensaje("Conectado. Escriba help para empezar y exit para salir.")
    ciclo()
  end

  # Con archivo: ejecuta los comandos del archivo
  defp iniciar(true, [archivo | _]) do
    archivo
    |> leer_comandos()
    |> ejecutar_lineas()
  end

  # Servicio al que el servidor envía las respuestas
  defp servicio_local(), do: {@nombre_servicio_local, node()}

  defp leer_comandos(archivo) do
    case File.read(archivo) do
      {:ok, contenido} ->
        contenido
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&linea_valida?/1)

      {:error, razon} ->
        Util.mostrar_error("No se pudo leer #{archivo} (#{razon})")
        []
    end
  end

  # Se ignoran las líneas vacías y los comentarios (#)
  defp linea_valida?(linea), do: linea != "" and String.at(linea, 0) != "#"

  # ---------- FUNCIÓN RECURSIVA: ejecuta las líneas del archivo una por una ----------
  defp ejecutar_lineas([]), do: :ok

  defp ejecutar_lineas(["pause " <> milisegundos | resto]) do
    :timer.sleep(String.to_integer(milisegundos))
    ejecutar_lineas(resto)
  end

  defp ejecutar_lineas([linea | resto]) do
    Util.mostrar_mensaje("\n[#{node()}] > #{linea}")
    enviar_mensaje(linea)
    ejecutar_lineas(resto)
  end

  # ---------- FUNCIÓN RECURSIVA: modo interactivo hasta escribir exit ----------
  defp ciclo() do
    linea = Util.ingresar("emergencias> ", :texto)

    cond do
      linea == "exit" or linea == "salir" ->
        Util.mostrar_mensaje("Adiós")

      linea == "" ->
        ciclo()

      true ->
        enviar_mensaje(linea)
        ciclo()
    end
  end

  defp enviar_mensaje(mensaje) do
    send(@servicio_remoto, {servicio_local(), mensaje})
    recibir_respuesta()
  end

  defp recibir_respuesta() do
    receive do
      respuesta -> Util.mostrar_mensaje(respuesta)
    after
      @espera -> Util.mostrar_error("Sin respuesta del servidor (tiempo de espera agotado)")
    end
  end
end

NodoCliente.main()
