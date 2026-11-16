defmodule RecursosServer do
  @moduledoc """
  GenServer del inventario de recursos.

  REGLA DE CONCURRENCIA: todo lo que cambia cantidades pasa por handle_call,
  y un GenServer atiende un mensaje a la vez. Por eso "verificar si alcanza"
  y "descontar" ocurren juntos, sin que otra solicitud se meta en medio:
  nunca se asigna más de lo que hay.
  """
  use GenServer

  @archivo "recursos.csv"
  @archivo_movimientos "movimientos.csv"

  def start_link(_), do: GenServer.start_link(RecursosServer, :ok, name: RecursosServer)

  def registrar(recurso, usuario), do: GenServer.call(RecursosServer, {:registrar, recurso, usuario})
  def entrada(codigo, cantidad, usuario), do: GenServer.call(RecursosServer, {:entrada, codigo, cantidad, usuario})

  def salida(codigo, cantidad, usuario),
    do: GenServer.call(RecursosServer, {:salida, codigo, cantidad, "salida", "Salida manual", usuario})

  # Reserva de un recurso concreto (verifica y descuenta en el mismo mensaje)
  def reservar(codigo, cantidad, categoria, detalle, usuario),
    do: GenServer.call(RecursosServer, {:reservar, codigo, cantidad, categoria, detalle, usuario})

  # Reserva del primer recurso de la categoría que alcance (prefiere los de la misma zona)
  def reservar_categoria(categoria, cantidad, zona, detalle, usuario),
    do: GenServer.call(RecursosServer, {:reservar_categoria, categoria, cantidad, zona, detalle, usuario})

  def transferir(codigo, origen, destino, cantidad, usuario),
    do: GenServer.call(RecursosServer, {:transferir, codigo, origen, destino, cantidad, usuario})

  def listar(), do: GenServer.call(RecursosServer, :listar)
  def obtener(codigo), do: GenServer.call(RecursosServer, {:obtener, codigo})
  def historial(codigo), do: GenServer.call(RecursosServer, {:historial, codigo})
  def reiniciar(), do: GenServer.call(RecursosServer, :reiniciar)

  def init(:ok) do
    recursos =
      Almacen.leer_csv(@archivo, &Recurso.de_campos/1)
      |> Enum.into(%{}, fn r -> {r.codigo, r} end)

    movimientos = Almacen.leer_csv(@archivo_movimientos, &Movimiento.de_campos/1)
    {:ok, %{recursos: recursos, movimientos: movimientos}}
  end

  def handle_call({:registrar, recurso, usuario}, _from, estado) do
    if Map.has_key?(estado.recursos, recurso.codigo) do
      {:reply, {:error, "Ya existe un recurso con código #{recurso.codigo}"}, estado}
    else
      detalle = "Registro inicial en #{recurso.ubicacion}"

      estado =
        estado
        |> poner(recurso)
        |> movimiento(Movimiento.crear(recurso.codigo, "entrada", recurso.cantidad, detalle, usuario))

      {:reply, {:ok, recurso}, estado}
    end
  end

  def handle_call({:entrada, codigo, cantidad, usuario}, _from, estado) do
    case buscar(estado, codigo) do
      {:ok, r} ->
        case Recurso.entrada(r, cantidad) do
          {:ok, nuevo} ->
            estado =
              estado
              |> poner(nuevo)
              |> movimiento(Movimiento.crear(codigo, "entrada", cantidad, "Entrada manual", usuario))

            {:reply, {:ok, nuevo}, estado}

          error ->
            {:reply, error, estado}
        end

      error ->
        {:reply, error, estado}
    end
  end

  def handle_call({:salida, codigo, cantidad, tipo, detalle, usuario}, _from, estado) do
    {respuesta, estado} = descontar(estado, codigo, cantidad, tipo, detalle, usuario)
    {:reply, respuesta, estado}
  end

  def handle_call({:reservar, codigo, cantidad, categoria, detalle, usuario}, _from, estado) do
    case buscar(estado, codigo) do
      {:ok, %Recurso{categoria: ^categoria}} ->
        {respuesta, estado} = descontar(estado, codigo, cantidad, "asignacion", detalle, usuario)
        {:reply, respuesta, estado}

      {:ok, r} ->
        {:reply, {:error, "El recurso #{codigo} es de categoría #{r.categoria}, no #{categoria}"}, estado}

      error ->
        {:reply, error, estado}
    end
  end

  def handle_call({:reservar_categoria, categoria, cantidad, zona, detalle, usuario}, _from, estado) do
    candidatos =
      estado.recursos
      |> Map.values()
      |> Enum.filter(fn r -> r.categoria == categoria and r.cantidad >= cantidad end)
      |> Enum.sort_by(fn r -> {r.zona != zona, r.codigo} end)

    case candidatos do
      [] ->
        mensaje = "No hay #{cantidad} unidades de #{categoria} en un mismo recurso " <>
                    "(disponible en total: #{total_categoria(estado, categoria)})"

        {:reply, {:error, mensaje}, estado}

      [recurso | _] ->
        {respuesta, estado} = descontar(estado, recurso.codigo, cantidad, "asignacion", detalle, usuario)
        {:reply, respuesta, estado}
    end
  end

  def handle_call({:transferir, codigo, origen, destino, cantidad, usuario}, _from, estado) do
    case validar_transferencia(estado, codigo, origen, destino, cantidad) do
      {:ok, r, origen_actualizado} ->
        destino_actualizado = recurso_destino(estado, r, codigo, destino, cantidad)

        estado =
          estado
          |> poner(origen_actualizado)
          |> poner(destino_actualizado)
          |> movimiento(Movimiento.crear(codigo, "transferencia", cantidad,
                          "Salida hacia #{destino} (#{destino_actualizado.codigo})", usuario))
          |> movimiento(Movimiento.crear(destino_actualizado.codigo, "transferencia", cantidad,
                          "Entrada desde #{origen} (#{codigo})", usuario))

        {:reply, {:ok, origen_actualizado, destino_actualizado}, estado}

      error ->
        {:reply, error, estado}
    end
  end

  def handle_call(:listar, _from, estado) do
    lista = estado.recursos |> Map.values() |> Enum.sort_by(fn r -> r.codigo end)
    {:reply, lista, estado}
  end

  def handle_call({:obtener, codigo}, _from, estado), do: {:reply, buscar(estado, codigo), estado}

  def handle_call({:historial, codigo}, _from, estado),
    do: {:reply, Enum.filter(estado.movimientos, fn m -> m.recurso == codigo end), estado}

  def handle_call(:reiniciar, _from, _estado), do: {:reply, :ok, %{recursos: %{}, movimientos: []}}

  # ======================= funciones privadas =======================
  defp descontar(estado, codigo, cantidad, tipo, detalle, usuario) do
    case buscar(estado, codigo) do
      {:ok, r} ->
        case Recurso.salida(r, cantidad) do
          {:ok, nuevo} ->
            estado =
              estado
              |> poner(nuevo)
              |> movimiento(Movimiento.crear(codigo, tipo, cantidad, detalle, usuario))

            {{:ok, nuevo}, estado}

          error ->
            {error, estado}
        end

      error ->
        {error, estado}
    end
  end

  defp validar_transferencia(estado, codigo, origen, destino, cantidad) do
    case buscar(estado, codigo) do
      {:ok, r} ->
        cond do
          r.ubicacion != origen -> {:error, "El recurso #{codigo} está en #{r.ubicacion}, no en #{origen}"}
          origen == destino -> {:error, "El origen y el destino deben ser diferentes"}
          true ->
            case Recurso.salida(r, cantidad) do
              {:ok, origen_actualizado} -> {:ok, r, origen_actualizado}
              error -> error
            end
        end

      error ->
        error
    end
  end

  # Si en el destino ya hay un recurso de la misma categoría se suma; si no, se crea uno nuevo
  defp recurso_destino(estado, r, codigo, destino, cantidad) do
    existente =
      estado.recursos
      |> Map.values()
      |> Enum.find(fn x -> x.categoria == r.categoria and x.ubicacion == destino end)

    case existente do
      nil -> %{r | codigo: "#{codigo}-#{destino}", ubicacion: destino, cantidad: cantidad}
      encontrado -> %{encontrado | cantidad: encontrado.cantidad + cantidad}
    end
  end

  defp buscar(estado, codigo) do
    case Map.get(estado.recursos, codigo) do
      nil -> {:error, "No existe el recurso #{codigo}"}
      r -> {:ok, r}
    end
  end

  defp total_categoria(estado, categoria) do
    estado.recursos
    |> Map.values()
    |> Enum.filter(fn r -> r.categoria == categoria end)
    |> Enum.map(fn r -> r.cantidad end)
    |> Enum.sum()
  end

  defp poner(estado, recurso) do
    estado = %{estado | recursos: Map.put(estado.recursos, recurso.codigo, recurso)}
    Almacen.escribir_csv(Map.values(estado.recursos), @archivo, Recurso.titulos(), &Recurso.a_campos/1)
    estado
  end

  defp movimiento(estado, mov) do
    Almacen.agregar_csv(Movimiento.a_campos(mov), @archivo_movimientos, Movimiento.titulos())
    %{estado | movimientos: estado.movimientos ++ [mov]}
  end
end
