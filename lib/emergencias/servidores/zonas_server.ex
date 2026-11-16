defmodule ZonasServer do
  @moduledoc "GenServer de zonas, sectores y puntos de atención (lista plana con padre)."
  use GenServer

  @archivo "zonas.csv"
  # tipo -> tipo que debe tener su padre
  @padre_requerido %{"zona" => nil, "sector" => "zona", "punto" => "sector"}

  def start_link(_), do: GenServer.start_link(ZonasServer, :ok, name: ZonasServer)

  def registrar(codigo, nombre, tipo, nivel, afectados, padre),
    do: GenServer.call(ZonasServer, {:registrar, codigo, nombre, tipo, nivel, afectados, padre})

  def listar(), do: GenServer.call(ZonasServer, :listar)
  def arbol(codigo), do: GenServer.call(ZonasServer, {:arbol, codigo})
  def existe?(codigo), do: GenServer.call(ZonasServer, {:existe, codigo})
  def reiniciar(), do: GenServer.call(ZonasServer, :reiniciar)

  def init(:ok), do: {:ok, Almacen.leer_csv(@archivo, &Zona.de_campos/1)}

  def handle_call({:registrar, codigo, nombre, tipo, nivel, afectados, padre}, _from, zonas) do
    resultado =
      cond do
        Enum.any?(zonas, fn z -> z.codigo == codigo end) ->
          {:error, "Ya existe una zona/sector/punto con código #{codigo}"}

        not padre_valido?(zonas, tipo, padre) ->
          {:error, "El #{tipo} debe pertenecer a un(a) #{@padre_requerido[tipo]} existente"}

        true ->
          Zona.crear(codigo, nombre, tipo, nivel, afectados, padre)
      end

    case resultado do
      {:ok, zona} ->
        zonas = zonas ++ [zona]
        Almacen.escribir_csv(zonas, @archivo, Zona.titulos(), &Zona.a_campos/1)
        {:reply, {:ok, zona}, zonas}

      error ->
        {:reply, error, zonas}
    end
  end

  def handle_call(:listar, _from, zonas), do: {:reply, zonas, zonas}
  def handle_call({:arbol, codigo}, _from, zonas), do: {:reply, Algoritmos.construir_arbol(zonas, codigo), zonas}
  def handle_call({:existe, codigo}, _from, zonas), do: {:reply, Enum.any?(zonas, fn z -> z.codigo == codigo end), zonas}
  def handle_call(:reiniciar, _from, _zonas), do: {:reply, :ok, []}

  defp padre_valido?(_zonas, "zona", _padre), do: true

  defp padre_valido?(zonas, tipo, padre) do
    Enum.any?(zonas, fn z -> z.codigo == padre and z.tipo == @padre_requerido[tipo] end)
  end
end
