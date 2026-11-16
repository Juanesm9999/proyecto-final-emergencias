defmodule MascotasServer do
  @moduledoc "GenServer de reportes de mascotas perdidas y encontradas."
  use GenServer

  @archivo "mascotas.csv"

  def start_link(_), do: GenServer.start_link(MascotasServer, :ok, name: MascotasServer)

  def reportar(tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas),
    do: GenServer.call(MascotasServer, {:reportar, tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas})

  def listar(), do: GenServer.call(MascotasServer, :listar)
  def buscar_coincidencias(), do: GenServer.call(MascotasServer, :buscar_coincidencias)
  def confirmar(id1, id2), do: GenServer.call(MascotasServer, {:confirmar, id1, id2})
  def reiniciar(), do: GenServer.call(MascotasServer, :reiniciar)

  def init(:ok) do
    lista = Almacen.leer_csv(@archivo, &Mascota.de_campos/1)
    mascotas = Enum.into(lista, %{}, fn m -> {m.id, m} end)
    {:ok, %{mascotas: mascotas, consecutivo: Enum.count(lista)}}
  end

  def handle_call({:reportar, tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas}, _from, estado) do
    id = Util.siguiente_id("MAS", estado.consecutivo)

    case Mascota.crear(id, tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas) do
      {:ok, m} ->
        estado = %{estado | consecutivo: estado.consecutivo + 1}
        {:reply, {:ok, m}, guardar(estado, [m])}

      error ->
        {:reply, error, estado}
    end
  end

  def handle_call(:listar, _from, estado) do
    {:reply, estado.mascotas |> Map.values() |> Enum.sort_by(fn m -> m.id end), estado}
  end

  # Calcula las coincidencias y marca los reportes involucrados como posible_coincidencia
  def handle_call(:buscar_coincidencias, _from, estado) do
    coincidencias = Algoritmos.buscar_coincidencias(Map.values(estado.mascotas))

    marcadas =
      coincidencias
      |> Enum.reduce([], fn {_puntos, p, e}, ids -> ids ++ [p.id, e.id] end)
      |> Enum.uniq()
      |> Enum.map(fn id -> Mascota.marcar_posible(estado.mascotas[id]) end)

    estado = guardar(estado, marcadas)

    actualizadas =
      Enum.map(coincidencias, fn {puntos, p, e} -> {puntos, estado.mascotas[p.id], estado.mascotas[e.id]} end)

    {:reply, actualizadas, estado}
  end

  # Dentro del GenServer: dos confirmaciones al mismo tiempo no resuelven dos veces el mismo reporte
  def handle_call({:confirmar, id1, id2}, _from, estado) do
    case {buscar(estado, id1), buscar(estado, id2)} do
      {{:ok, a}, {:ok, b}} ->
        case Mascota.confirmar_pareja(a, b) do
          {:ok, a2, b2} -> {:reply, {:ok, a2, b2}, guardar(estado, [a2, b2])}
          error -> {:reply, error, estado}
        end

      {{:error, mensaje}, _} ->
        {:reply, {:error, mensaje}, estado}

      {_, {:error, mensaje}} ->
        {:reply, {:error, mensaje}, estado}
    end
  end

  def handle_call(:reiniciar, _from, _estado), do: {:reply, :ok, %{mascotas: %{}, consecutivo: 0}}

  defp buscar(estado, id) do
    case Map.get(estado.mascotas, id) do
      nil -> {:error, "No existe el reporte #{id}"}
      m -> {:ok, m}
    end
  end

  defp guardar(estado, cambiadas) do
    mascotas = Enum.reduce(cambiadas, estado.mascotas, fn m, acumulado -> Map.put(acumulado, m.id, m) end)

    mascotas
    |> Map.values()
    |> Enum.sort_by(fn m -> m.id end)
    |> Almacen.escribir_csv(@archivo, Mascota.titulos(), &Mascota.a_campos/1)

    %{estado | mascotas: mascotas}
  end
end
