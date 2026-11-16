defmodule RecursoTest do
  use ExUnit.Case, async: true

  test "el inventario nunca queda en negativo" do
    {:ok, r} = Recurso.crear("R1", "agua", "10", "litros", "centro_acopio", "", "")
    assert {:error, _} = Recurso.salida(r, 11)
    assert {:ok, %Recurso{cantidad: 0}} = Recurso.salida(r, 10)
  end

  test "las cantidades inválidas se rechazan antes de crear el recurso" do
    assert {:error, _} = Recurso.crear("R2", "agua", "-5", "litros", "x", "", "")
    assert {:error, _} = Recurso.crear("R3", "agua", "diez", "litros", "x", "", "")
  end
end
