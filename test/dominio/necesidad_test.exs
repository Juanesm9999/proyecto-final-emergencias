defmodule NecesidadTest do
  use ExUnit.Case, async: true

  test "una necesidad atendida no recibe recursos y los estados siguen transiciones válidas" do
    {:ok, n} = Necesidad.crear("N001", "agua", "10", "alta", "centro", "", "u", "")
    assert {:error, _} = Necesidad.cambiar_estado(n, "atendida")
    {:ok, n} = Necesidad.cambiar_estado(n, "en_atencion")
    {:ok, n} = Necesidad.cambiar_estado(n, "atendida")
    assert {:error, _} = Necesidad.puede_recibir(n, 5)
    assert {:error, _} = Necesidad.cambiar_estado(n, "atendida")
  end

  test "no se asigna más de lo que la necesidad requiere" do
    {:ok, n} = Necesidad.crear("N001", "agua", "10", "alta", "centro", "", "u", "")
    assert {:error, _} = Necesidad.puede_recibir(n, 11)
    n = Necesidad.registrar_asignacion(n, 10)
    assert n.estado == "asignada"
    assert {:error, _} = Necesidad.puede_recibir(n, 1)
  end

  test "una persona reunificada no cambia de estado y se guarda el historial" do
    {:ok, p} = Persona.crear("1", "Andrés", "norte", "localizada", "30")
    {:ok, p} = Persona.cambiar_estado(p, "reunificada", "laura")
    assert Enum.count(p.historial) == 1
    assert {:error, _} = Persona.cambiar_estado(p, "localizada", "laura")
  end
end
