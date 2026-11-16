defmodule Comandos do
  @moduledoc """
  Interpreta una línea de texto enviada por un cliente y la ejecuta.

  Flujo: tokenizar -> verificar sesión -> verificar permiso -> ejecutar -> texto de respuesta.
  Los servicios devuelven {:ok, ...} / {:error, mensaje}; aquí solo se convierten en texto.
  """

  # Campos por los que se puede filtrar en cada listado (texto -> campo del struct)
  @filtros_necesidades %{"zona" => :zona, "tipo" => :tipo, "prioridad" => :prioridad, "estado" => :estado}
  @filtros_recursos %{"categoria" => :categoria, "zona" => :zona, "ubicacion" => :ubicacion}
  @filtros_mascotas %{"especie" => :especie, "zona" => :zona, "estado" => :estado, "tipo" => :tipo}

  # Nombres en español de cada comando (se pueden usar los dos idiomas)
  @en_espanol %{
    "ayuda" => "help",
    "conectar" => "connect",
    "desconectar" => "disconnect",
    "quien_soy" => "whoami",
    "usuarios" => "users",
    "actividad" => "activity",
    "registrar_zona" => "register_zone",
    "registrar_sector" => "register_sector",
    "registrar_punto" => "register_point",
    "listar_zonas" => "list_zones",
    "estado_zona" => "zone_status",
    "registrar_necesidad" => "register_need",
    "listar_necesidades" => "list_needs",
    "necesidades_pendientes" => "pending_needs",
    "actualizar_necesidad" => "update_need",
    "asignar_recurso" => "assign_resource",
    "atender_pendientes" => "attend_pending",
    "registrar_recurso" => "register_resource",
    "entrada_recurso" => "resource_in",
    "salida_recurso" => "resource_out",
    "listar_recursos" => "list_resources",
    "historial_recurso" => "resource_history",
    "transferir_recurso" => "transfer_resource",
    "recursos_criticos" => "critical_resources",
    "reportar_persona" => "report_person",
    "actualizar_persona" => "update_person",
    "buscar_persona" => "find_person",
    "historial_persona" => "person_history",
    "enviar_mensaje" => "send_family_message",
    "listar_mensajes" => "list_family_messages",
    "entregar_mensaje" => "deliver_message",
    "reportar_mascota" => "report_pet",
    "listar_mascotas" => "list_pets",
    "coincidencias_mascotas" => "match_pets",
    "confirmar_coincidencia" => "confirm_match",
    "registrar_albergue" => "register_shelter",
    "listar_albergues" => "list_shelters",
    "consultar_albergue" => "check_shelter",
    "registrar_ingreso" => "register_entry",
    "registrar_salida" => "register_exit",
    "reporte_albergues" => "shelters_report",
    "resumen" => "summary"
  }

  def ejecutar(cliente, linea) do
    case Parser.tokenizar(linea) do
      [] -> "Escriba un comando. Use help (o ayuda) para ver la lista."
      [comando | argumentos] -> despachar(cliente, traducir(comando), argumentos, linea)
    end
  end

  # Si el comando está en español se cambia por su nombre en inglés; si no, queda igual
  defp traducir(comando), do: Map.get(@en_espanol, comando, comando)

  # "register_need" -> "registrar_necesidad"
  defp en_espanol(comando) do
    case Enum.find(@en_espanol, fn {_es, en} -> en == comando end) do
      {es, _en} -> es
      nil -> comando
    end
  end

  defp despachar(cliente, "help", _argumentos, _linea) do
    case SesionesSupervisor.obtener(cliente) do
      nil -> ayuda_sin_sesion()
      usuario -> ejecutar_comando("help", [], usuario, cliente)
    end
  end

  defp despachar(cliente, "connect", argumentos, _linea), do: conectar(cliente, argumentos)

  defp despachar(cliente, comando, argumentos, linea) do
    case SesionesSupervisor.obtener(cliente) do
      nil ->
        "Debe conectarse primero: connect usuario contraseña tipo zona"

      usuario ->
        if Validaciones.permitido?(usuario.tipo, comando) do
          respuesta = ejecutar_comando(comando, argumentos, usuario, cliente)
          ActividadServer.registrar(usuario.usuario, linea)
          respuesta
        else
          "El rol #{usuario.tipo} no tiene permiso para '#{comando}' (o el comando no existe). Use help."
        end
    end
  end

  defp ayuda_sin_sesion() do
    "Comandos sin sesión: connect (conectar) usuario contraseña tipo zona [\"nombre completo\"]\n" <>
      "Tipos de usuario: #{Enum.join(Usuario.tipos(), ", ")}\n" <>
      "Conéctese y vuelva a escribir help para ver los comandos de su rol."
  end

  # ======================= USUARIOS =======================
  defp conectar(cliente, [usuario, clave, tipo, zona | resto]) do
    nombre = Enum.join(resto, " ")

    case UsuariosServer.conectar(usuario, clave, tipo, zona, nombre) do
      {:ok, u, como} ->
        SesionesSupervisor.iniciar(cliente, u)
        ActividadServer.registrar(u.usuario, "connect (#{como})")
        accion = if como == :registrado, do: "Usuario registrado y conectado", else: "Bienvenido de nuevo"
        "#{accion}: #{u.nombre} (#{u.tipo}, zona #{u.zona})" <> crear_zona_principal(u)
      {:error, mensaje} ->
        "Error: " <> mensaje
    end
  end

  # Un usuario ya registrado puede conectarse solo con usuario y contraseña
  defp conectar(cliente, [usuario, clave]), do: conectar(cliente, [usuario, clave, "ciudadano", "-"])

  defp conectar(_cliente, _argumentos), do: uso("connect usuario contraseña tipo zona [\"nombre completo\"]")

  defp ejecutar_comando("help", _args, usuario, _cliente) do
    usuario.tipo
    |> Validaciones.comandos_permitidos()
    |> Enum.map(fn comando -> "  #{comando} (#{en_espanol(comando)})" end)
    |> Enum.join("\n")
    |> (&("Comandos disponibles para #{usuario.tipo} (inglés / español):\n" <> &1)).()
  end

  defp ejecutar_comando("disconnect", _args, usuario, cliente) do
    SesionesSupervisor.cerrar(cliente)
    "Hasta pronto, #{usuario.nombre}. Sesión cerrada."
  end

  defp ejecutar_comando("whoami", _args, u, _c), do: "#{u.usuario} · #{u.nombre} · #{u.tipo} · zona #{u.zona}"

  defp ejecutar_comando("users", _args, _u, _c) do
    conectados = Enum.map(SesionesSupervisor.conectados(), fn u -> u.usuario end)

    UsuariosServer.listar()
    |> Enum.sort_by(fn u -> u.usuario end)
    |> Enum.map(fn u ->
      estado = if Enum.member?(conectados, u.usuario), do: "conectado", else: "desconectado"
      "#{u.usuario} | #{u.nombre} | #{u.tipo} | #{u.zona} | #{estado}"
    end)
    |> lista_o("No hay usuarios")
  end

  defp ejecutar_comando("activity", args, _u, _c) do
    args
    |> Enum.at(0)
    |> ActividadServer.listar()
    |> Enum.take(-30)
    |> Enum.map(fn {fecha, u, accion} -> "#{fecha} | #{u} | #{accion}" end)
    |> lista_o("No hay actividad registrada")
  end

  # ======================= ZONAS =======================
  defp ejecutar_comando("register_zone", [codigo, nombre, nivel | resto], _u, _c),
    do: registrar_zona(codigo, nombre, "zona", nivel, Enum.at(resto, 0, "0"), "")

  defp ejecutar_comando("register_zone", _a, _u, _c), do: uso("register_zone codigo \"nombre\" nivel [afectados]")

  defp ejecutar_comando("register_sector", [codigo, nombre, nivel, afectados, zona], _u, _c),
    do: registrar_zona(codigo, nombre, "sector", nivel, afectados, zona)

  defp ejecutar_comando("register_sector", _a, _u, _c), do: uso("register_sector codigo \"nombre\" nivel afectados zona")

  defp ejecutar_comando("register_point", [codigo, nombre, nivel, afectados, sector], _u, _c),
    do: registrar_zona(codigo, nombre, "punto", nivel, afectados, sector)

  defp ejecutar_comando("register_point", _a, _u, _c), do: uso("register_point codigo \"nombre\" nivel afectados sector")

  defp ejecutar_comando("list_zones", _args, _u, _c) do
    zonas = ZonasServer.listar()

    zonas
    |> Enum.filter(fn z -> z.tipo == "zona" end)
    |> Enum.map(fn z -> zonas |> Algoritmos.construir_arbol(z.codigo) |> Algoritmos.dibujar() end)
    |> Enum.join("")
    |> String.trim()
    |> vacio_o("No hay zonas registradas")
  end

  defp ejecutar_comando("zone_status", [codigo], _u, _c) do
    case ZonasServer.arbol(codigo) do
      nil -> "Error: No existe la zona #{codigo}"
      arbol -> Interfaz.estado_zona(arbol, Algoritmos.codigos(arbol))
    end
  end

  defp ejecutar_comando("zone_status", _a, _u, _c), do: uso("zone_status codigo")

  # ======================= NECESIDADES =======================
  defp ejecutar_comando("register_need", [tipo, cantidad, prioridad, zona, descripcion | resto], u, _c) do
    case zona_existe(zona) do
      :ok ->
        tipo
        |> NecesidadesServer.registrar(cantidad, prioridad, zona, descripcion, u.usuario, Enum.at(resto, 0, ""))
        |> respuesta(fn n -> "Necesidad registrada: " <> Interfaz.necesidad(n) end)

      error ->
        mostrar_error(error)
    end
  end

  defp ejecutar_comando("register_need", _a, _u, _c),
    do: uso("register_need tipo cantidad prioridad zona \"descripcion\" [albergue/referencia]")

  defp ejecutar_comando("list_needs", args, _u, _c) do
    filtros = filtros(args)

    NecesidadesServer.listar()
    |> Enum.filter(fn n -> cumple?(n, filtros, @filtros_necesidades) end)
    |> Algoritmos.ordenar_por_prioridad()
    |> Enum.map(&Interfaz.necesidad/1)
    |> lista_o("No hay necesidades con esos filtros")
  end

  defp ejecutar_comando("pending_needs", _args, u, c), do: ejecutar_comando("list_needs", ["estado=pendiente"], u, c)

  defp ejecutar_comando("update_need", [id, estado], _u, _c) do
    id
    |> NecesidadesServer.cambiar_estado(estado)
    |> respuesta(fn n -> "Necesidad actualizada: " <> Interfaz.necesidad(n) end)
  end

  defp ejecutar_comando("update_need", _a, _u, _c), do: uso("update_need id estado (asignada, en_atencion, atendida, cancelada)")

  defp ejecutar_comando("assign_resource", [id, recurso, cantidad], u, _c) do
    case Validaciones.entero_positivo(cantidad, "cantidad") do
      {:ok, numero} ->
        id
        |> NecesidadesServer.asignar(recurso, numero, u.usuario)
        |> respuesta(fn {n, r} ->
          "Asignados #{numero} #{r.unidad} de #{r.codigo} (quedan #{r.cantidad}) a #{n.id}. " <>
            "Necesidad: #{n.asignada}/#{n.cantidad}, estado #{n.estado}"
        end)

      error ->
        mostrar_error(error)
    end
  end

  defp ejecutar_comando("assign_resource", _a, _u, _c), do: uso("assign_resource id_necesidad categoria|codigo_recurso cantidad")

  defp ejecutar_comando("attend_pending", _args, u, _c) do
    NecesidadesServer.atender_pendientes(u.usuario)
    |> Enum.map(&resultado_atencion/1)
    |> lista_o("No hay necesidades pendientes")
  end

  # ======================= RECURSOS =======================
  defp ejecutar_comando("register_resource", [codigo, categoria, cantidad, unidad, ubicacion | resto], u, _c) do
    zona = Enum.at(resto, 0, "")
    nombre = Enum.at(resto, 1, "")
    zona_valida = if zona == "", do: :ok, else: zona_existe(zona)

    case zona_valida do
      :ok ->
        case Recurso.crear(codigo, categoria, cantidad, unidad, ubicacion, zona, nombre) do
          {:ok, recurso} ->
            recurso
            |> RecursosServer.registrar(u.usuario)
            |> respuesta(fn r -> "Recurso registrado: " <> Interfaz.recurso(r) end)

          error ->
            mostrar_error(error)
        end

      error ->
        mostrar_error(error)
    end
  end

  defp ejecutar_comando("register_resource", _a, _u, _c),
    do: uso("register_resource codigo categoria cantidad unidad ubicacion [zona] [\"nombre\"]")

  defp ejecutar_comando("resource_in", [codigo, cantidad], u, _c),
    do: mover_inventario(&RecursosServer.entrada/3, codigo, cantidad, u, "Entrada registrada")

  defp ejecutar_comando("resource_out", [codigo, cantidad], u, _c),
    do: mover_inventario(&RecursosServer.salida/3, codigo, cantidad, u, "Salida registrada")

  defp ejecutar_comando("resource_in", _a, _u, _c), do: uso("resource_in codigo cantidad")
  defp ejecutar_comando("resource_out", _a, _u, _c), do: uso("resource_out codigo cantidad")

  defp ejecutar_comando("list_resources", args, _u, _c) do
    filtros = filtros(args)

    RecursosServer.listar()
    |> Enum.filter(fn r -> cumple?(r, filtros, @filtros_recursos) end)
    |> Enum.map(&Interfaz.recurso/1)
    |> lista_o("No hay recursos con esos filtros")
  end

  defp ejecutar_comando("resource_history", [codigo], _u, _c) do
    RecursosServer.historial(codigo)
    |> Enum.map(fn m -> "#{m.fecha} | #{m.tipo} | #{m.cantidad} | #{m.detalle} | #{m.usuario}" end)
    |> lista_o("No hay movimientos para #{codigo}")
  end

  defp ejecutar_comando("resource_history", _a, _u, _c), do: uso("resource_history codigo")

  defp ejecutar_comando("transfer_resource", [codigo, origen, destino, cantidad], u, _c) do
    case Validaciones.entero_positivo(cantidad, "cantidad") do
      {:ok, numero} ->
        codigo
        |> RecursosServer.transferir(origen, destino, numero, u.usuario)
        |> respuesta(fn {o, d} ->
          "Transferidos #{numero} #{o.unidad}: #{o.codigo} en #{o.ubicacion} queda con #{o.cantidad}; " <>
            "#{d.codigo} en #{d.ubicacion} queda con #{d.cantidad}"
        end)

      error ->
        mostrar_error(error)
    end
  end

  defp ejecutar_comando("transfer_resource", _a, _u, _c), do: uso("transfer_resource codigo origen destino cantidad")

  defp ejecutar_comando("critical_resources", _args, _u, _c),
    do: Interfaz.recursos_criticos(RecursosServer.listar(), NecesidadesServer.listar())

  # ======================= PERSONAS Y FAMILIARES =======================
  defp ejecutar_comando("report_person", [documento, nombre, zona, estado | resto], u, _c) do
    case zona_existe(zona) do
      :ok ->
        documento
        |> PersonasServer.reportar(nombre, zona, estado, Enum.at(resto, 0, "0"), u.usuario)
        |> respuesta(fn p -> "Persona registrada: " <> Interfaz.persona(p) end)

      error ->
        mostrar_error(error)
    end
  end

  defp ejecutar_comando("report_person", _a, _u, _c), do: uso("report_person documento \"nombre\" zona estado [edad]")

  defp ejecutar_comando("update_person", [documento, estado], u, _c) do
    documento
    |> PersonasServer.cambiar_estado(estado, u.usuario)
    |> respuesta(fn p -> "Estado actualizado: " <> Interfaz.persona(p) end)
  end

  defp ejecutar_comando("update_person", _a, _u, _c), do: uso("update_person documento estado")

  defp ejecutar_comando("find_person", [criterio], _u, _c) do
    {campo, valor} =
      case String.split(criterio, "=", parts: 2) do
        [campo, valor] -> {campo, valor}
        [documento] -> {"documento", documento}
      end

    PersonasServer.buscar(campo, valor)
    |> Enum.map(&Interfaz.persona/1)
    |> lista_o("No se encontraron personas")
  end

  defp ejecutar_comando("find_person", _a, _u, _c), do: uso("find_person documento | nombre=texto | zona=z | estado=e")

  defp ejecutar_comando("person_history", [documento], _u, _c) do
    case PersonasServer.obtener(documento) do
      {:ok, p} ->
        p.historial
        |> Enum.map(fn {fecha, anterior, nuevo, usuario} -> "#{fecha} | #{anterior} -> #{nuevo} | por #{usuario}" end)
        |> lista_o("Sin historial")

      error ->
        mostrar_error(error)
    end
  end

  defp ejecutar_comando("send_family_message", [documento, contenido], u, _c) do
    u.usuario
    |> PersonasServer.enviar_mensaje(documento, contenido)
    |> respuesta(fn m -> "Mensaje #{m.id} guardado para #{documento}" end)
  end

  defp ejecutar_comando("send_family_message", _a, _u, _c), do: uso("send_family_message documento \"mensaje\"")

  defp ejecutar_comando("list_family_messages", [documento], _u, _c) do
    PersonasServer.mensajes(documento)
    |> Enum.map(fn m -> "#{m.id} | #{m.fecha} | de #{m.remitente} | #{m.estado} | #{m.contenido}" end)
    |> lista_o("No hay mensajes para #{documento}")
  end

  defp ejecutar_comando("deliver_message", [id], _u, _c) do
    id
    |> PersonasServer.entregar_mensaje()
    |> respuesta(fn m -> "Mensaje #{m.id} marcado como entregado" end)
  end

  # ======================= MASCOTAS =======================
  defp ejecutar_comando("report_pet", [tipo, especie, nombre, color, tamano, zona, contacto | resto], _u, _c) do
    case zona_existe(zona) do
      :ok ->
        tipo
        |> MascotasServer.reportar(especie, nombre, color, tamano, zona, contacto, Enum.join(resto, " "))
        |> respuesta(fn m -> "Reporte registrado: " <> Interfaz.mascota(m) end)

      error ->
        mostrar_error(error)
    end
  end

  defp ejecutar_comando("report_pet", _a, _u, _c),
    do: uso("report_pet lost|found especie nombre color tamaño zona contacto [\"características\"]")

  defp ejecutar_comando("list_pets", args, _u, _c) do
    filtros = filtros(args)

    MascotasServer.listar()
    |> Enum.filter(fn m -> cumple?(m, filtros, @filtros_mascotas) end)
    |> Enum.map(&Interfaz.mascota/1)
    |> lista_o("No hay reportes con esos filtros")
  end

  defp ejecutar_comando("match_pets", _args, _u, _c) do
    MascotasServer.buscar_coincidencias()
    |> Enum.map(fn {puntos, p, e} ->
      "Puntaje #{puntos}: perdida #{p.id} (#{p.nombre}, #{p.color}, #{p.tamano}, #{p.zona}) <-> " <>
        "encontrada #{e.id} (#{e.nombre}, #{e.color}, #{e.tamano}, #{e.zona})"
    end)
    |> lista_o("No hay coincidencias con puntaje >= #{Mascota.umbral()}")
  end

  defp ejecutar_comando("confirm_match", [id1, id2], _u, _c) do
    id1
    |> MascotasServer.confirmar(id2)
    |> respuesta(fn {a, b} -> "Coincidencia confirmada: #{a.id} y #{b.id} quedan resueltos" end)
  end

  defp ejecutar_comando("confirm_match", _a, _u, _c), do: uso("confirm_match id_perdida id_encontrada")

  # ======================= ALBERGUES =======================
  defp ejecutar_comando("register_shelter", [codigo, nombre, zona, capacidad], _u, _c) do
    case zona_existe(zona) do
      :ok ->
        codigo
        |> AlberguesServer.registrar(nombre, zona, capacidad)
        |> respuesta(fn a -> "Albergue registrado: " <> Interfaz.albergue(a) end)

      error ->
        mostrar_error(error)
    end
  end

  defp ejecutar_comando("register_shelter", _a, _u, _c), do: uso("register_shelter codigo \"nombre\" zona capacidad")

  defp ejecutar_comando("list_shelters", _args, _u, _c) do
    AlberguesServer.listar()
    |> Enum.sort_by(fn a -> a.codigo end)
    |> Enum.map(&Interfaz.albergue/1)
    |> lista_o("No hay albergues")
  end

  defp ejecutar_comando("check_shelter", [codigo], _u, _c) do
    case AlberguesServer.obtener(codigo) do
      {:ok, a} ->
        recursos = Enum.filter(RecursosServer.listar(), fn r -> r.ubicacion == codigo end)
        necesidades = Enum.filter(NecesidadesServer.listar(), fn n -> n.referencia == codigo end)
        Interfaz.detalle_albergue(a, recursos, necesidades)

      error ->
        mostrar_error(error)
    end
  end

  defp ejecutar_comando("register_entry", [codigo, documento], u, _c) do
    case AlberguesServer.ingresar(codigo, documento) do
      {:ok, a} ->
        nota = actualizar_persona_albergue(documento, codigo, u)
        "Ingreso registrado en #{a.codigo}. Ocupación #{Albergue.ocupacion(a)}/#{a.capacidad}" <> nota

      error ->
        mostrar_error(error)
    end
  end

  defp ejecutar_comando("register_exit", [codigo, documento], _u, _c) do
    case AlberguesServer.retirar(codigo, documento) do
      {:ok, a} ->
        PersonasServer.asignar_albergue(documento, "")
        "Salida registrada de #{a.codigo}. Ocupación #{Albergue.ocupacion(a)}/#{a.capacidad}"

      error ->
        mostrar_error(error)
    end
  end

  defp ejecutar_comando(comando, _a, _u, _c) when comando in ["register_entry", "register_exit", "check_shelter"],
    do: uso("#{comando} codigo_albergue [documento]")

  defp ejecutar_comando("shelters_report", _args, _u, _c) do
    AlberguesServer.listar()
    |> Enum.sort_by(&Albergue.porcentaje/1, &>=/2)
    |> Enum.map(fn a -> "#{a.codigo} #{a.nombre}: #{Albergue.porcentaje(a)}% (#{Albergue.ocupacion(a)}/#{a.capacidad})" end)
    |> lista_o("No hay albergues")
  end

  # ======================= RESUMEN =======================
  defp ejecutar_comando("summary", _args, _u, _c) do
    Interfaz.resumen(%{
      recursos: RecursosServer.listar(),
      necesidades: NecesidadesServer.listar(),
      personas: PersonasServer.listar(),
      mensajes: PersonasServer.todos_los_mensajes(),
      mascotas: MascotasServer.listar(),
      albergues: AlberguesServer.listar(),
      conectados: SesionesSupervisor.conectados()
    })
  end

  defp ejecutar_comando(comando, _a, _u, _c), do: "Uso incorrecto de #{comando}. Use help."

  # ======================= FUNCIONES DE APOYO =======================
  defp registrar_zona(codigo, nombre, tipo, nivel, afectados, padre) do
    codigo
    |> ZonasServer.registrar(nombre, tipo, nivel, afectados, padre)
    |> respuesta(fn z -> "#{etiqueta(z.tipo)}: #{z.codigo} #{z.nombre} (nivel #{z.nivel}, afectados #{z.afectados})" end)
  end

  defp etiqueta("zona"), do: "Zona registrada"
  defp etiqueta("sector"), do: "Sector registrado"
  defp etiqueta("punto"), do: "Punto de atención registrado"

  defp resultado_atencion({:ok, n, r}), do: "OK  #{n.id} (#{n.prioridad}) recibió #{n.cantidad} #{r.unidad} de #{r.codigo}"
  defp resultado_atencion({:error, n, mensaje}), do: "NO  #{n.id} (#{n.prioridad}): #{mensaje}"

  defp mover_inventario(funcion, codigo, cantidad, u, texto) do
    case Validaciones.entero_positivo(cantidad, "cantidad") do
      {:ok, numero} -> funcion.(codigo, numero, u.usuario) |> respuesta(fn r -> "#{texto}: " <> Interfaz.recurso(r) end)
      error -> mostrar_error(error)
    end
  end

  # Al ingresar a un albergue, la persona queda en estado en_albergue si la transición es válida
  defp actualizar_persona_albergue(documento, codigo, u) do
    case PersonasServer.asignar_albergue(documento, codigo) do
      {:ok, %Persona{estado: "en_albergue"}} ->
        ""

      {:ok, _persona} ->
        case PersonasServer.cambiar_estado(documento, "en_albergue", u.usuario) do
          {:ok, _} -> ". Estado de la persona: en_albergue"
          {:error, mensaje} -> ". (Estado sin cambio: #{mensaje})"
        end

      {:error, _} ->
        ". (La persona no está registrada en el sistema)"
    end
  end

  # Un coordinador o administrador que se conecta con una zona nueva la deja registrada,
  # así puede trabajar en ella de inmediato (como en el ejemplo del enunciado)
  defp crear_zona_principal(%Usuario{tipo: tipo, zona: zona}) when tipo in ["coordinador", "administrador"] do
    if ZonasServer.existe?(zona) do
      ""
    else
      case ZonasServer.registrar(zona, zona, "zona", "medio", "0", "") do
        {:ok, _zona} -> "\nLa zona #{zona} no existía y se registró automáticamente (nivel medio)"
        {:error, _mensaje} -> ""
      end
    end
  end

  defp crear_zona_principal(_usuario), do: ""

  defp zona_existe(zona) do
    if ZonasServer.existe?(zona), do: :ok, else: {:error, "La zona #{zona} no está registrada"}
  end


  # ["zona=centro", "prioridad=critica"] -> %{"zona" => "centro", "prioridad" => "critica"}
  defp filtros(args) do
    args
    |> Enum.map(fn texto -> String.split(texto, "=", parts: 2) end)
    |> Enum.filter(fn partes -> Enum.count(partes) == 2 end)
    |> Enum.into(%{}, fn [campo, valor] -> {campo, valor} end)
  end

  # Un filtro con un campo que no existe se ignora
  defp cumple?(registro, filtros, campos) do
    Enum.all?(filtros, fn {campo, valor} ->
      case Map.get(campos, campo) do
        nil -> true
        atomo -> to_string(Map.get(registro, atomo)) == valor
      end
    end)
  end

  defp respuesta({:ok, a, b}, formato), do: formato.({a, b})
  defp respuesta({:ok, valor}, formato), do: formato.(valor)
  defp respuesta({:error, mensaje}, _formato), do: "Error: " <> mensaje

  defp mostrar_error({:error, mensaje}), do: "Error: " <> mensaje

  defp lista_o([], vacio), do: vacio
  defp lista_o(lineas, _vacio), do: Enum.join(lineas, "\n")

  defp vacio_o("", vacio), do: vacio
  defp vacio_o(texto, _vacio), do: texto

  defp uso(texto), do: "Uso: " <> texto
end
