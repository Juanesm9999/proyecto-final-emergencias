defmodule Interfaz do
  @moduledoc "Interfaz de texto: convierte los datos en las respuestas que ve el usuario."

  def necesidad(n) do
    ref = if n.referencia == "", do: "", else: " | ref #{n.referencia}"

    "#{n.id} | #{n.tipo} | #{n.asignada}/#{n.cantidad} | prioridad #{n.prioridad} | zona #{n.zona} | " <>
      "#{n.estado} | por #{n.responsable}#{ref} | #{n.descripcion}"
  end

  def recurso(r) do
    zona = if r.zona == "", do: "", else: " | zona #{r.zona}"
    "#{r.codigo} | #{r.nombre} (#{r.categoria}) | #{r.cantidad} #{r.unidad} | #{r.ubicacion}#{zona}"
  end

  def persona(p) do
    albergue = if p.albergue == "", do: "", else: " | albergue #{p.albergue}"
    "#{p.documento} | #{p.nombre} | #{p.edad} años | zona #{p.zona} | #{p.estado}#{albergue}"
  end

  def mascota(m) do
    nombre = if m.nombre == "", do: "sin nombre", else: m.nombre
    extra = if m.coincidencia == "", do: "", else: " | con #{m.coincidencia}"

    "#{m.id} | #{m.tipo} | #{m.especie} #{nombre} | #{m.color} #{m.tamano} | zona #{m.zona} | " <>
      "contacto #{m.contacto} | #{m.estado}#{extra}"
  end

  def albergue(a) do
    "#{a.codigo} | #{a.nombre} | zona #{a.zona} | ocupación #{Albergue.ocupacion(a)}/#{a.capacidad} | " <>
      "cupos #{Albergue.cupos(a)}"
  end

  def detalle_albergue(a, recursos, necesidades) do
    ocupantes = Enum.join(Albergue.lista_ocupantes(a), ", ")

    [
      "Albergue #{a.codigo} - #{a.nombre} (zona #{a.zona})",
      "Ocupación: #{Albergue.ocupacion(a)}/#{a.capacidad} (#{Albergue.porcentaje(a)}%) · cupos disponibles: #{Albergue.cupos(a)}",
      "Ocupantes: #{if ocupantes == "", do: "ninguno", else: ocupantes}",
      "Recursos en el albergue:",
      lineas(recursos, &recurso/1),
      "Necesidades asociadas:",
      lineas(necesidades, &necesidad/1)
    ]
    |> Enum.join("\n")
  end

  def estado_zona(arbol, codigos) do
    est = Algoritmos.estadisticas(arbol)
    en_zona? = fn codigo -> Enum.member?(codigos, codigo) end

    necesidades = Enum.filter(NecesidadesServer.listar(), fn n -> en_zona?.(n.zona) end)
    recursos = Enum.filter(RecursosServer.listar(), fn r -> en_zona?.(r.zona) end)
    albergues = Enum.filter(AlberguesServer.listar(), fn a -> en_zona?.(a.zona) end)
    personas = Enum.filter(PersonasServer.listar(), fn p -> en_zona?.(p.zona) end)
    mascotas = Enum.filter(MascotasServer.listar(), fn m -> en_zona?.(m.zona) and m.estado != "resuelta" end)

    "Estado de #{arbol.zona.codigo} - #{arbol.zona.nombre}\n" <>
      Algoritmos.dibujar(arbol) <>
      "Estadísticas acumuladas (recursivas): afectados #{est.afectados} · sectores #{est.sectores} · " <>
      "puntos #{est.puntos} · nivel más grave #{est.nivel_max}\n" <>
      "Necesidades: #{conteo_por(necesidades, fn n -> n.estado end)}\n" <>
      "Recursos: #{conteo_suma(recursos)}\n" <>
      "Albergues: #{Enum.count(albergues)} · Personas reportadas: #{Enum.count(personas)} · " <>
      "Reportes de mascotas abiertos: #{Enum.count(mascotas)}"
  end

  # Una categoría es crítica si no hay nada o si la demanda pendiente es mayor que lo disponible
  def recursos_criticos([], []), do: "No hay recursos ni necesidades registradas"

  def recursos_criticos(recursos, necesidades) do
    demanda =
      necesidades
      |> Enum.filter(fn n -> n.estado == "pendiente" end)
      |> Enum.group_by(fn n -> n.tipo end, &Necesidad.pendiente/1)
      |> Enum.into(%{}, fn {tipo, cantidades} -> {tipo, Enum.sum(cantidades)} end)

    disponible =
      recursos
      |> Enum.group_by(fn r -> r.categoria end, fn r -> r.cantidad end)
      |> Enum.into(%{}, fn {categoria, cantidades} -> {categoria, Enum.sum(cantidades)} end)

    (Map.keys(demanda) ++ Map.keys(disponible))
    |> Enum.uniq()
    |> Enum.map(fn categoria -> linea_critica(categoria, Map.get(disponible, categoria, 0), Map.get(demanda, categoria, 0)) end)
    |> Enum.sort()
    |> Enum.map(fn {_estado, linea} -> linea end)
    |> Enum.join("\n")
    |> (&("Recursos críticos (demanda pendiente mayor que lo disponible):\n" <> &1)).()
  end

  def resumen(d) do
    ocupados = d.albergues |> Enum.map(&Albergue.ocupacion/1) |> Enum.sum()
    capacidad = d.albergues |> Enum.map(fn a -> a.capacidad end) |> Enum.sum()
    criticas = Enum.count(d.necesidades, fn n -> n.estado == "pendiente" and n.prioridad == "critica" end)
    conectados = d.conectados |> Enum.map(fn u -> u.usuario end) |> Enum.uniq() |> Enum.join(", ")

    "===== RESUMEN GLOBAL =====\n" <>
      "Recursos restantes: #{conteo_suma(d.recursos)}\n" <>
      "Necesidades: #{conteo_por(d.necesidades, fn n -> n.estado end)}\n" <>
      "Necesidades pendientes críticas: #{criticas}\n" <>
      "Personas: #{conteo_por(d.personas, fn p -> p.estado end)}\n" <>
      "Mensajes: #{conteo_por(d.mensajes, fn m -> m.estado end)}\n" <>
      "Mascotas: #{conteo_por(d.mascotas, fn m -> m.estado end)}\n" <>
      "Albergues: #{Enum.count(d.albergues)} · ocupación total #{ocupados}/#{capacidad}\n" <>
      "Usuarios conectados: #{conectados}"
  end

  defp linea_critica(categoria, hay, falta) do
    estado = if hay == 0 or falta > hay, do: "CRÍTICO", else: "suficiente"
    {estado, "#{categoria}: disponible #{hay} · demanda pendiente #{falta} · #{estado}"}
  end

  # "atendida 1, pendiente 2"
  defp conteo_por([], _campo), do: "ninguno"

  defp conteo_por(lista, campo) do
    lista
    |> Enum.group_by(campo)
    |> Enum.map(fn {valor, elementos} -> "#{valor} #{Enum.count(elementos)}" end)
    |> Enum.sort()
    |> Enum.join(", ")
  end

  # "agua 20 litros, alimentos 40 kg"
  defp conteo_suma([]), do: "ninguno"

  defp conteo_suma(recursos) do
    recursos
    |> Enum.group_by(fn r -> {r.categoria, r.unidad} end, fn r -> r.cantidad end)
    |> Enum.map(fn {{categoria, unidad}, cantidades} -> "#{categoria} #{Enum.sum(cantidades)} #{unidad}" end)
    |> Enum.sort()
    |> Enum.join(", ")
  end

  defp lineas([], _formato), do: "  (ninguno)"

  defp lineas(lista, formato) do
    lista
    |> Enum.map(fn elemento -> "  " <> formato.(elemento) end)
    |> Enum.join("\n")
  end
end
