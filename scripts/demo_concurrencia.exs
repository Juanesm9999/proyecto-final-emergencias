# Demostración del conflicto concurrente del enunciado.
# Ejecutar con:  mix run scripts/demo_concurrencia.exs
#
# Laura (30 litros) y Pedro (25 litros) piden al MISMO tiempo agua de un recurso
# que solo tiene 50 litros. Después, 20 procesos intentan sacar 10 litros cada uno de 100.

defmodule DemoConcurrencia do
  @coordinador {:servicio_respuesta, :demo@localhost}

  def main() do
    Emergencias.reiniciar_todo()
    preparar()

    Util.mostrar_mensaje("\n--- Laura y Pedro asignan al mismo tiempo (dos procesos) ---")
    conflicto_laura_pedro()

    Util.mostrar_mensaje("\n--- 20 procesos intentan sacar 10 litros cada uno de un recurso con 100 ---")
    muchas_salidas()
  end

  defp preparar() do
    [
      "connect admin admin administrador centro",
      "register_zone centro \"Zona Centro\" critico 1200",
      "register_resource R001 agua 50 litros centro_acopio_1 centro",
      "register_need agua 30 critica centro \"Punto de atención sector 3\"",
      "register_need agua 25 alta centro \"Familias sector 2\""
    ]
    |> Enum.each(fn linea -> linea |> (&Comandos.ejecutar(@coordinador, &1)).() |> Util.mostrar_mensaje() end)
  end

  defp conflicto_laura_pedro() do
    [
      Task.async(fn -> {"laura", NecesidadesServer.asignar("N001", "agua", 30, "laura")} end),
      Task.async(fn -> {"pedro", NecesidadesServer.asignar("N002", "agua", 25, "pedro")} end)
    ]
    |> Enum.map(&Task.await/1)
    |> Enum.each(&mostrar_resultado/1)

    {:ok, r} = RecursosServer.obtener("R001")
    Util.mostrar_mensaje("Inventario final de R001: #{r.cantidad} litros (nunca se asignaron 55)")
  end

  defp mostrar_resultado({quien, {:ok, n, r}}),
    do: Util.mostrar_mensaje("#{quien}: OK, #{n.id} recibió #{n.asignada} litros (quedan #{r.cantidad})")

  defp mostrar_resultado({quien, {:error, mensaje}}),
    do: Util.mostrar_mensaje("#{quien}: RECHAZADO -> #{mensaje}")

  defp muchas_salidas() do
    Comandos.ejecutar(@coordinador, "register_resource R002 agua 100 litros bodega centro")
    |> Util.mostrar_mensaje()

    resultados =
      1..20
      |> Enum.map(fn i -> Task.async(fn -> RecursosServer.salida("R002", 10, "proceso#{i}") end) end)
      |> Enum.map(&Task.await/1)

    exitos = Enum.count(resultados, fn r -> match?({:ok, _}, r) end)
    {:ok, r2} = RecursosServer.obtener("R002")
    Util.mostrar_mensaje("Salidas confirmadas: #{exitos} de 20 · rechazadas: #{20 - exitos} · inventario final: #{r2.cantidad}")
  end
end

DemoConcurrencia.main()
