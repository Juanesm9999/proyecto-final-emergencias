defmodule PersonasServer do
  @moduledoc "GenServer de personas afectadas, su historial y los mensajes de familiares."
  use GenServer

  @archivo "personas.csv"
  @archivo_historial "historial_personas.csv"
  @archivo_mensajes "mensajes.csv"

  def start_link(_), do: GenServer.start_link(PersonasServer, :ok, name: PersonasServer)

  def reportar(documento, nombre, zona, estado, edad, usuario),
    do: GenServer.call(PersonasServer, {:reportar, documento, nombre, zona, estado, edad, usuario})

  def cambiar_estado(documento, estado, usuario), do: GenServer.call(PersonasServer, {:cambiar_estado, documento, estado, usuario})
  def obtener(documento), do: GenServer.call(PersonasServer, {:obtener, documento})
  def buscar(campo, valor), do: GenServer.call(PersonasServer, {:buscar, campo, valor})
  def listar(), do: GenServer.call(PersonasServer, :listar)
  def asignar_albergue(documento, albergue), do: GenServer.call(PersonasServer, {:asignar_albergue, documento, albergue})

  def enviar_mensaje(remitente, documento, contenido), do: GenServer.call(PersonasServer, {:enviar_mensaje, remitente, documento, contenido})
  def mensajes(documento), do: GenServer.call(PersonasServer, {:mensajes, documento})
  def todos_los_mensajes(), do: GenServer.call(PersonasServer, :todos_los_mensajes)
  def entregar_mensaje(id), do: GenServer.call(PersonasServer, {:entregar_mensaje, id})
  def reiniciar(), do: GenServer.call(PersonasServer, :reiniciar)

  def init(:ok) do
    historial = Almacen.leer_csv(@archivo_historial, &cambio_de_campos/1)

    personas =
      Almacen.leer_csv(@archivo, &Persona.de_campos/1)
      |> Enum.into(%{}, fn p ->
        cambios = for {documento, cambio} <- historial, documento == p.documento, do: cambio
        {p.documento, %{p | historial: cambios}}
      end)

    lista_mensajes = Almacen.leer_csv(@archivo_mensajes, &Mensaje.de_campos/1)
    mensajes = Enum.into(lista_mensajes, %{}, fn m -> {m.id, m} end)

    {:ok, %{personas: personas, mensajes: mensajes, consecutivo: Enum.count(lista_mensajes)}}
  end

  def handle_call({:reportar, documento, nombre, zona, estado_inicial, edad, usuario}, _from, estado) do
    if Map.has_key?(estado.personas, documento) do
      {:reply, {:error, "Ya existe una persona con documento #{documento}"}, estado}
    else
      case Persona.crear(documento, nombre, zona, estado_inicial, edad) do
        {:ok, p} ->
          cambio = {Util.ahora(), "nuevo", p.estado, usuario}
          p = %{p | historial: [cambio]}
          guardar_historial(documento, cambio)
          {:reply, {:ok, p}, guardar(estado, p)}

        error ->
          {:reply, error, estado}
      end
    end
  end

  def handle_call({:cambiar_estado, documento, nuevo, usuario}, _from, estado) do
    case buscar_persona(estado, documento) do
      {:ok, p} ->
        case Persona.cambiar_estado(p, nuevo, usuario) do
          {:ok, actualizada} ->
            guardar_historial(documento, Enum.at(actualizada.historial, -1))
            {:reply, {:ok, actualizada}, guardar(estado, actualizada)}

          error ->
            {:reply, error, estado}
        end

      error ->
        {:reply, error, estado}
    end
  end

  def handle_call({:obtener, documento}, _from, estado), do: {:reply, buscar_persona(estado, documento), estado}

  def handle_call({:buscar, campo, valor}, _from, estado) do
    resultado =
      estado.personas
      |> Map.values()
      |> Enum.filter(fn p -> Persona.coincide?(p, campo, valor) end)

    {:reply, resultado, estado}
  end

  def handle_call(:listar, _from, estado), do: {:reply, Map.values(estado.personas), estado}

  def handle_call({:asignar_albergue, documento, albergue}, _from, estado) do
    case buscar_persona(estado, documento) do
      {:ok, p} ->
        actualizada = %{p | albergue: albergue}
        {:reply, {:ok, actualizada}, guardar(estado, actualizada)}

      error ->
        {:reply, error, estado}
    end
  end

  def handle_call({:enviar_mensaje, remitente, documento, contenido}, _from, estado) do
    case buscar_persona(estado, documento) do
      {:ok, _p} ->
        id = Util.siguiente_id("MSG", estado.consecutivo)

        case Mensaje.crear(id, remitente, documento, contenido) do
          {:ok, m} ->
            estado = %{estado | consecutivo: estado.consecutivo + 1}
            {:reply, {:ok, m}, guardar_mensaje(estado, m)}

          error ->
            {:reply, error, estado}
        end

      error ->
        {:reply, error, estado}
    end
  end

  def handle_call({:mensajes, documento}, _from, estado) do
    lista =
      estado.mensajes
      |> Map.values()
      |> Enum.filter(fn m -> m.destinatario == documento end)
      |> Enum.sort_by(fn m -> m.id end)

    {:reply, lista, estado}
  end

  def handle_call(:todos_los_mensajes, _from, estado), do: {:reply, Map.values(estado.mensajes), estado}

  def handle_call({:entregar_mensaje, id}, _from, estado) do
    case Map.get(estado.mensajes, id) do
      nil ->
        {:reply, {:error, "No existe el mensaje #{id}"}, estado}

      m ->
        case Mensaje.entregar(m) do
          {:ok, entregado} -> {:reply, {:ok, entregado}, guardar_mensaje(estado, entregado)}
          error -> {:reply, error, estado}
        end
    end
  end

  def handle_call(:reiniciar, _from, _estado), do: {:reply, :ok, %{personas: %{}, mensajes: %{}, consecutivo: 0}}

  # ======================= funciones privadas =======================
  defp buscar_persona(estado, documento) do
    case Map.get(estado.personas, documento) do
      nil -> {:error, "No existe una persona con documento #{documento}"}
      p -> {:ok, p}
    end
  end

  defp guardar(estado, p) do
    estado = %{estado | personas: Map.put(estado.personas, p.documento, p)}
    Almacen.escribir_csv(Map.values(estado.personas), @archivo, Persona.titulos(), &Persona.a_campos/1)
    estado
  end

  defp guardar_historial(documento, {fecha, anterior, nuevo, usuario}) do
    Almacen.agregar_csv([documento, fecha, anterior, nuevo, usuario], @archivo_historial, Persona.titulos_historial())
  end

  defp cambio_de_campos([documento, fecha, anterior, nuevo, usuario]), do: {:ok, {documento, {fecha, anterior, nuevo, usuario}}}
  defp cambio_de_campos(_), do: :error

  defp guardar_mensaje(estado, m) do
    estado = %{estado | mensajes: Map.put(estado.mensajes, m.id, m)}

    estado.mensajes
    |> Map.values()
    |> Enum.sort_by(fn x -> x.id end)
    |> Almacen.escribir_csv(@archivo_mensajes, Mensaje.titulos(), &Mensaje.a_campos/1)

    estado
  end
end
