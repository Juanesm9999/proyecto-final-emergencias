defmodule AsignacionConcurrenteTest do
  use ExUnit.Case, async: false
  import Ayuda

  setup do
    Emergencias.reiniciar_todo()
    coordinador = nuevo_cliente()
    como(coordinador, "connect laura 1234 coordinador centro")
    como(coordinador, "register_zone centro \"Centro\" critico 100")
    %{coordinador: coordinador}
  end

  test "flujo del enunciado: 30 + 25 litros sobre 50 disponibles, solo uno se confirma", %{coordinador: c} do
    como(c, "register_resource R001 agua 50 litros centro_acopio_1 centro")
    como(c, "register_need agua 30 critica centro \"Punto sector 3\"")
    como(c, "register_need agua 25 alta centro \"Familias\"")

    # Dos usuarios piden al mismo tiempo, cada uno desde su propio proceso
    tareas = [
      Task.async(fn -> NecesidadesServer.asignar("N001", "agua", 30, "laura") end),
      Task.async(fn -> NecesidadesServer.asignar("N002", "agua", 25, "pedro") end)
    ]

    resultados = Enum.map(tareas, &Task.await/1)
    exitosos = Enum.filter(resultados, fn r -> match?({:ok, _, _}, r) end)

    assert Enum.count(exitosos) == 1
    {:ok, r} = RecursosServer.obtener("R001")
    assert r.cantidad in [20, 25]
  end

  test "100 procesos piden 10 unidades de un recurso con 50: se asignan exactamente 50", %{coordinador: c} do
    como(c, "register_resource R002 alimentos 50 kg centro_acopio_1 centro")

    for i <- 1..100, do: NecesidadesServer.registrar("alimentos", "10", "media", "centro", "familia #{i}", "u", "")

    resultados =
      1..100
      |> Enum.map(fn i -> Task.async(fn -> NecesidadesServer.asignar(Util.siguiente_id("N", i - 1), "R002", 10, "u") end) end)
      |> Enum.map(&Task.await/1)

    assert Enum.count(resultados, fn r -> match?({:ok, _, _}, r) end) == 5
    assert {:ok, %Recurso{cantidad: 0}} = RecursosServer.obtener("R002")
  end

  test "una misma necesidad no consume recursos dos veces aunque se pida al mismo tiempo", %{coordinador: c} do
    como(c, "register_resource R004 agua 100 litros bodega centro")
    como(c, "register_need agua 40 critica centro \"Hospital\"")

    resultados =
      1..10
      |> Enum.map(fn _ -> Task.async(fn -> NecesidadesServer.asignar("N001", "agua", 40, "u") end) end)
      |> Enum.map(&Task.await/1)

    assert Enum.count(resultados, fn r -> match?({:ok, _, _}, r) end) == 1
    assert {:ok, %Recurso{cantidad: 60}} = RecursosServer.obtener("R004")
  end

  test "ingresos simultáneos no superan la capacidad del albergue", %{coordinador: c} do
    como(c, "register_shelter A01 \"Albergue\" centro 3")

    resultados =
      1..15
      |> Enum.map(fn i -> Task.async(fn -> AlberguesServer.ingresar("A01", "doc#{i}") end) end)
      |> Enum.map(&Task.await/1)

    assert Enum.count(resultados, fn r -> match?({:ok, _}, r) end) == 3
  end

  test "un reporte de mascota no se resuelve dos veces", %{coordinador: c} do
    como(c, "report_pet lost perro Luna negra mediana centro 300")
    como(c, "report_pet found perro desconocido negra mediana centro 301")

    resultados =
      1..5
      |> Enum.map(fn _ -> Task.async(fn -> MascotasServer.confirmar("MAS001", "MAS002") end) end)
      |> Enum.map(&Task.await/1)

    assert Enum.count(resultados, fn r -> match?({:ok, _, _}, r) end) == 1
  end
end
