defmodule MascotaTest do
  use ExUnit.Case, async: true

  test "el puntaje de mascotas usa varios atributos y exige la misma especie" do
    {:ok, perdida} = Mascota.crear("M1", "lost", "perro", "Luna", "negra", "mediana", "norte", "300", "collar rojo")
    {:ok, encontrada} = Mascota.crear("M2", "found", "perro", "desconocido", "negra", "mediana", "norte", "301", "collar")
    {:ok, gato} = Mascota.crear("M3", "found", "gato", "Luna", "negra", "mediana", "norte", "302", "")

    assert Mascota.puntaje(perdida, encontrada) == 90
    assert Mascota.puntaje(perdida, gato) == 0
  end

  test "solo se confirma una perdida con una encontrada de la misma especie" do
    {:ok, perdida} = Mascota.crear("M1", "lost", "perro", "Luna", "negra", "mediana", "norte", "300", "")
    {:ok, otra_perdida} = Mascota.crear("M2", "lost", "perro", "Max", "negra", "mediana", "norte", "301", "")
    {:ok, encontrada} = Mascota.crear("M3", "found", "perro", "?", "negra", "mediana", "norte", "302", "")

    assert {:error, _} = Mascota.confirmar_pareja(perdida, otra_perdida)
    assert {:ok, %Mascota{estado: "resuelta"}, %Mascota{estado: "resuelta"}} = Mascota.confirmar_pareja(perdida, encontrada)
  end
end
