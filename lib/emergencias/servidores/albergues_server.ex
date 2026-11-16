defmodule AlberguesServer do
  @moduledoc """
  GenServer de albergues. El ingreso se valida dentro de handle_call, así dos
  ingresos simultáneos nunca superan la capacidad y una persona no queda en dos albergues.
  """
  use GenServer

  @archivo "albergues.csv"

  def start_link(_), do: GenServer.start_link(AlberguesServer, :ok, name: AlberguesServer)

  def registrar(codigo, nombre, zona, capacidad), do: GenServer.call(AlberguesServer, {:registrar, codigo, nombre, zona, capacidad})
  def obtener(codigo), do: GenServer.call(AlberguesServer, {:obtener, codigo})
  def listar(), do: GenServer.call(AlberguesServer, :listar)
  def ingresar(codigo, documento), do: GenServer.call(AlberguesServer, {:ingresar, codigo, documento})
  def retirar(codigo, documento), do: GenServer.call(AlberguesServer, {:retirar, codigo, documento})
  def reiniciar(), do: GenServer.call(AlberguesServer, :reiniciar)

  def init(:ok) do
    albergues =
      Almacen.leer_csv(@archivo, &Albergue.de_campos/1)
      |> Enum.into(%{}, fn a -> {a.codigo, a} end)

    {:ok, albergues}
  end

  def handle_call({:registrar, codigo, nombre, zona, capacidad}, _from, albergues) do
    if Map.has_key?(albergues, codigo) do
      {:reply, {:error, "Ya existe un albergue con código #{codigo}"}, albergues}
    else
      case Albergue.crear(codigo, nombre, zona, capacidad) do
        {:ok, a} -> {:reply, {:ok, a}, guardar(albergues, a)}
        error -> {:reply, error, albergues}
      end
    end
  end

  def handle_call({:obtener, codigo}, _from, albergues), do: {:reply, buscar(albergues, codigo), albergues}
  def handle_call(:listar, _from, albergues), do: {:reply, Map.values(albergues), albergues}

  def handle_call({:ingresar, codigo, documento}, _from, albergues) do
    otro =
      albergues
      |> Map.values()
      |> Enum.find(fn a -> a.codigo != codigo and MapSet.member?(a.ocupantes, documento) end)

    case buscar(albergues, codigo) do
      {:ok, a} ->
        if otro != nil do
          {:reply, {:error, "La persona #{documento} ya está en el albergue #{otro.codigo}"}, albergues}
        else
          case Albergue.ingresar(a, documento) do
            {:ok, actualizado} -> {:reply, {:ok, actualizado}, guardar(albergues, actualizado)}
            error -> {:reply, error, albergues}
          end
        end

      error ->
        {:reply, error, albergues}
    end
  end

  def handle_call({:retirar, codigo, documento}, _from, albergues) do
    case buscar(albergues, codigo) do
      {:ok, a} ->
        case Albergue.retirar(a, documento) do
          {:ok, actualizado} -> {:reply, {:ok, actualizado}, guardar(albergues, actualizado)}
          error -> {:reply, error, albergues}
        end

      error ->
        {:reply, error, albergues}
    end
  end

  def handle_call(:reiniciar, _from, _albergues), do: {:reply, :ok, %{}}

  defp buscar(albergues, codigo) do
    case Map.get(albergues, codigo) do
      nil -> {:error, "No existe el albergue #{codigo}"}
      a -> {:ok, a}
    end
  end

  defp guardar(albergues, a) do
    albergues = Map.put(albergues, a.codigo, a)
    Almacen.escribir_csv(Map.values(albergues), @archivo, Albergue.titulos(), &Albergue.a_campos/1)
    albergues
  end
end
