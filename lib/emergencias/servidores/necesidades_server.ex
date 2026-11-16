defmodule NecesidadesServer do
  @moduledoc """
  GenServer de necesidades puntuales.

  La asignación se hace dentro de handle_call: primero se valida la necesidad
  y luego se reserva en el RecursosServer. Como este GenServer atiende una solicitud
  a la vez, una necesidad no recibe recursos dos veces al mismo tiempo, y una
  necesidad atendida no vuelve a consumir recursos.
  """
  use GenServer

  @archivo "necesidades.csv"

  def start_link(_), do: GenServer.start_link(NecesidadesServer, :ok, name: NecesidadesServer)

  def registrar(tipo, cantidad, prioridad, zona, descripcion, responsable, referencia),
    do: GenServer.call(NecesidadesServer, {:registrar, tipo, cantidad, prioridad, zona, descripcion, responsable, referencia})

  def listar(), do: GenServer.call(NecesidadesServer, :listar)
  def obtener(id), do: GenServer.call(NecesidadesServer, {:obtener, id})
  def cambiar_estado(id, estado), do: GenServer.call(NecesidadesServer, {:cambiar_estado, id, estado})

  # recurso_o_categoria puede ser un código (R001) o una categoría (agua)
  def asignar(id, recurso_o_categoria, cantidad, usuario),
    do: GenServer.call(NecesidadesServer, {:asignar, id, recurso_o_categoria, cantidad, usuario})

  # Atiende las pendientes en orden de prioridad con los recursos disponibles
  def atender_pendientes(usuario), do: GenServer.call(NecesidadesServer, {:atender_pendientes, usuario})

  def reiniciar(), do: GenServer.call(NecesidadesServer, :reiniciar)

  def init(:ok) do
    lista = Almacen.leer_csv(@archivo, &Necesidad.de_campos/1)
    necesidades = Enum.into(lista, %{}, fn n -> {n.id, n} end)
    {:ok, %{necesidades: necesidades, consecutivo: Enum.count(lista)}}
  end

  def handle_call({:registrar, tipo, cantidad, prioridad, zona, descripcion, responsable, referencia}, _from, estado) do
    id = Util.siguiente_id("N", estado.consecutivo)

    case Necesidad.crear(id, tipo, cantidad, prioridad, zona, descripcion, responsable, referencia) do
      {:ok, n} ->
        estado = %{estado | consecutivo: estado.consecutivo + 1}
        {:reply, {:ok, n}, guardar(estado, n)}

      error ->
        {:reply, error, estado}
    end
  end

  def handle_call(:listar, _from, estado), do: {:reply, Map.values(estado.necesidades), estado}
  def handle_call({:obtener, id}, _from, estado), do: {:reply, buscar(estado, id), estado}

  def handle_call({:cambiar_estado, id, nuevo}, _from, estado) do
    case buscar(estado, id) do
      {:ok, n} ->
        case Necesidad.cambiar_estado(n, nuevo) do
          {:ok, actualizada} -> {:reply, {:ok, actualizada}, guardar(estado, actualizada)}
          error -> {:reply, error, estado}
        end

      error ->
        {:reply, error, estado}
    end
  end

  def handle_call({:asignar, id, recurso_o_categoria, cantidad, usuario}, _from, estado) do
    case asignar_interno(estado, id, recurso_o_categoria, cantidad, usuario) do
      {:ok, n, recurso, estado} -> {:reply, {:ok, n, recurso}, estado}
      error -> {:reply, error, estado}
    end
  end

  def handle_call({:atender_pendientes, usuario}, _from, estado) do
    pendientes =
      estado.necesidades
      |> Map.values()
      |> Enum.filter(fn n -> n.estado == "pendiente" end)
      |> Algoritmos.ordenar_por_prioridad()

    {resultados, estado} = atender(pendientes, usuario, estado, [])
    {:reply, resultados, estado}
  end

  def handle_call(:reiniciar, _from, _estado), do: {:reply, :ok, %{necesidades: %{}, consecutivo: 0}}

  # ---------- FUNCIÓN RECURSIVA: atender pendientes por prioridad ----------
  defp atender([], _usuario, estado, resultados), do: {Enum.reverse(resultados), estado}

  defp atender([n | resto], usuario, estado, resultados) do
    case asignar_interno(estado, n.id, n.tipo, Necesidad.pendiente(n), usuario) do
      {:ok, actualizada, recurso, estado} ->
        atender(resto, usuario, estado, [{:ok, actualizada, recurso} | resultados])

      {:error, mensaje} ->
        atender(resto, usuario, estado, [{:error, n, mensaje} | resultados])
    end
  end

  defp asignar_interno(estado, id, recurso_o_categoria, cantidad, usuario) do
    case buscar(estado, id) do
      {:ok, n} ->
        case Necesidad.puede_recibir(n, cantidad) do
          :ok -> reservar_y_registrar(estado, n, recurso_o_categoria, cantidad, usuario)
          error -> error
        end

      error ->
        error
    end
  end

  defp reservar_y_registrar(estado, n, recurso_o_categoria, cantidad, usuario) do
    case reservar(n, recurso_o_categoria, cantidad, "Asignado a necesidad #{n.id}", usuario) do
      {:ok, recurso} ->
        actualizada = Necesidad.registrar_asignacion(n, cantidad)
        {:ok, actualizada, recurso, guardar(estado, actualizada)}

      error ->
        error
    end
  end

  # Si el texto es un código de recurso se usa ese recurso; si no, se toma como categoría
  defp reservar(n, recurso_o_categoria, cantidad, detalle, usuario) do
    case RecursosServer.obtener(recurso_o_categoria) do
      {:ok, _recurso} ->
        RecursosServer.reservar(recurso_o_categoria, cantidad, n.tipo, detalle, usuario)

      {:error, _} ->
        if recurso_o_categoria == n.tipo do
          RecursosServer.reservar_categoria(n.tipo, cantidad, n.zona, detalle, usuario)
        else
          {:error, "La necesidad #{n.id} es de tipo #{n.tipo}, no de #{recurso_o_categoria}"}
        end
    end
  end

  defp buscar(estado, id) do
    case Map.get(estado.necesidades, id) do
      nil -> {:error, "No existe la necesidad #{id}"}
      n -> {:ok, n}
    end
  end

  defp guardar(estado, n) do
    estado = %{estado | necesidades: Map.put(estado.necesidades, n.id, n)}

    estado.necesidades
    |> Map.values()
    |> Enum.sort_by(fn x -> x.id end)
    |> Almacen.escribir_csv(@archivo, Necesidad.titulos(), &Necesidad.a_campos/1)

    estado
  end
end
