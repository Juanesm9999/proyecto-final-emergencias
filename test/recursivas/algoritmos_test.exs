defmodule AlgoritmosTest do
  use ExUnit.Case, async: true

  test "las estadísticas de una zona se acumulan recursivamente con sus sectores y puntos" do
    {:ok, z} = Zona.crear("centro", "Centro", "zona", "medio", "100", "")
    {:ok, s1} = Zona.crear("s1", "Sector 1", "sector", "critico", "50", "centro")
    {:ok, s2} = Zona.crear("s2", "Sector 2", "sector", "bajo", "30", "centro")
    {:ok, p1} = Zona.crear("p1", "Punto 1", "punto", "alto", "20", "s1")

    arbol = Algoritmos.construir_arbol([z, s1, s2, p1], "centro")
    assert %{afectados: 200, sectores: 2, puntos: 1, nivel_max: "critico"} = Algoritmos.estadisticas(arbol)
    assert Enum.sort(Algoritmos.codigos(arbol)) == ["centro", "p1", "s1", "s2"]
  end

  test "las necesidades se ordenan por prioridad y luego por antigüedad" do
    crear = fn id, prioridad ->
      {:ok, n} = Necesidad.crear(id, "agua", "10", prioridad, "centro", "", "u", "")
      n
    end

    lista = [crear.("N001", "baja"), crear.("N002", "critica"), crear.("N003", "alta"), crear.("N004", "critica")]
    ordenadas = Enum.map(Algoritmos.ordenar_por_prioridad(lista), fn n -> n.id end)
    assert ordenadas == ["N002", "N004", "N003", "N001"]
  end

  test "las coincidencias de mascotas se buscan entre perdidas y encontradas" do
    {:ok, perdida} = Mascota.crear("M1", "lost", "perro", "Luna", "negra", "mediana", "norte", "300", "collar rojo")
    {:ok, encontrada} = Mascota.crear("M2", "found", "perro", "desconocido", "negra", "mediana", "norte", "301", "collar")
    {:ok, gato} = Mascota.crear("M3", "found", "gato", "Luna", "negra", "mediana", "norte", "302", "")

    assert [{90, %Mascota{id: "M1"}, %Mascota{id: "M2"}}] = Algoritmos.buscar_coincidencias([perdida, encontrada, gato])
  end

  test "el parser separa un comando respetando el texto entre comillas" do
    assert Parser.tokenizar(~s(send_family_message 123 "Estoy bien, en el albergue")) ==
             ["send_family_message", "123", "Estoy bien, en el albergue"]

    assert Parser.tokenizar("  list_needs   zona=centro ") == ["list_needs", "zona=centro"]
  end
end
