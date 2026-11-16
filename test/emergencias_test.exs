defmodule EmergenciasTest do
  use ExUnit.Case, async: false
  import Ayuda

  setup do
    Emergencias.reiniciar_todo()
    :ok
  end

  # Pruebas de los comandos de punta a punta (sesión, permisos y validación de entradas)

  test "connect registra un usuario nuevo y luego valida su contraseña" do
    c = nuevo_cliente()
    assert como(c, "connect ana clave1 voluntario centro") =~ "registrado"
    como(c, "disconnect")
    assert como(c, "connect ana otra voluntario centro") =~ "Contraseña incorrecta"
    assert como(c, "connect ana clave1 voluntario centro") =~ "Bienvenido"
  end

  test "sin sesión no se puede ejecutar ningún comando" do
    assert como(nuevo_cliente(), "list_needs") =~ "Debe conectarse"
  end

  test "las operaciones se restringen según el tipo de usuario" do
    ciudadano = nuevo_cliente()
    como(ciudadano, "connect juan 1 ciudadano centro")
    assert como(ciudadano, "register_resource R1 agua 10 litros x") =~ "no tiene permiso"
    assert como(ciudadano, "summary") =~ "no tiene permiso"

    admin = nuevo_cliente()
    como(admin, "connect root 1 administrador centro")
    :timer.sleep(50)
    assert como(admin, "activity juan") =~ "connect"
  end

  test "las entradas inválidas no modifican el estado" do
    c = nuevo_cliente()
    como(c, "connect laura 1 coordinador centro")
    como(c, "register_zone centro \"Centro\" alto 10")
    assert como(c, "register_resource R1 agua -5 litros bodega") =~ "negativo"
    assert como(c, "register_resource R1 agua diez litros bodega") =~ "número entero"
    assert como(c, "register_need volar 3 alta centro \"x\"") =~ "Tipo de necesidad inválido"
    assert como(c, "register_need agua 3 alta zona_fantasma \"x\"") =~ "no está registrada"
    assert como(c, "register_zone centro \"Repetida\" alto 1") =~ "Ya existe"
    assert RecursosServer.listar() == []
  end

  test "disconnect cierra la sesión del usuario" do
    c = nuevo_cliente()
    como(c, "connect laura 1 coordinador centro")
    assert Enum.count(SesionesSupervisor.conectados()) == 1
    como(c, "disconnect")
    assert SesionesSupervisor.conectados() == []
    assert como(c, "whoami") =~ "Debe conectarse"
  end
end
