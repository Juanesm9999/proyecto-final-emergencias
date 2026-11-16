defmodule RecursosServerTest do
  use ExUnit.Case, async: false
  import Ayuda

  setup do
    Emergencias.reiniciar_todo()
    c = nuevo_cliente()
    como(c, "connect laura 1 coordinador centro")
    %{c: c}
  end

  test "salidas simultáneas de inventario nunca dejan cantidades negativas", %{c: c} do
    como(c, "register_resource R003 medicamentos 7 cajas bodega")

    resultados =
      1..20
      |> Enum.map(fn _ -> Task.async(fn -> RecursosServer.salida("R003", 1, "u") end) end)
      |> Enum.map(&Task.await/1)

    assert Enum.count(resultados, fn r -> match?({:ok, _}, r) end) == 7
    assert {:ok, %Recurso{cantidad: 0}} = RecursosServer.obtener("R003")
  end

  test "una transferencia descuenta del origen y suma en el destino", %{c: c} do
    como(c, "register_resource R001 agua 200 litros centro_acopio_1")
    assert como(c, "transfer_resource R001 centro_acopio_1 albergue_2 30") =~ "Transferidos 30 litros"
    assert {:ok, %Recurso{cantidad: 170}} = RecursosServer.obtener("R001")
    assert {:ok, %Recurso{cantidad: 30}} = RecursosServer.obtener("R001-albergue_2")
    assert como(c, "transfer_resource R001 centro_acopio_1 albergue_2 500") =~ "Inventario insuficiente"
  end

  test "si el GenServer se cae, el supervisor lo reinicia y recupera los datos del CSV", %{c: c} do
    como(c, "register_resource R1 agua 80 litros bodega")
    como(c, "register_resource R2 alimentos 5 kg \"bodega, sur\"")
    como(c, "resource_out R1 30")

    viejo = Process.whereis(RecursosServer)
    Process.exit(viejo, :kill)
    :timer.sleep(100)
    nuevo = Process.whereis(RecursosServer)

    assert nuevo != viejo
    assert {:ok, %Recurso{cantidad: 50}} = RecursosServer.obtener("R1")
    assert {:ok, %Recurso{ubicacion: "bodega, sur"}} = RecursosServer.obtener("R2")
    assert Enum.count(RecursosServer.historial("R1")) == 2
  end
end
