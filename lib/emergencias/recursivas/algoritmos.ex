defmodule Algoritmos do
  @moduledoc """
  Algoritmos recursivos propios del proyecto.

  1. Árbol zona -> sectores -> puntos: construir_arbol, estadisticas, codigos, dibujar.
  2. Orden de necesidades por prioridad (ordenamiento por inserción).
  3. Puntaje de similitud de mascotas (suma recorriendo los criterios).
  4. Búsqueda de coincidencias entre mascotas perdidas y encontradas.

  Otras funciones recursivas del proyecto: Parser.recorrer/4 (separar un comando en palabras),
  Serializador.convertir_lineas/3 (leer archivos), NecesidadesServer.atender/4 (attend_pending)
  y NodoCliente.ejecutar_lineas/1 y ciclo/0 (cliente).
  """

  # ======================= 1. ÁRBOL DE ZONAS =======================

  # Devuelve %{zona: zona, hijos: [arbol, ...]} a partir de la lista plana de zonas
  def construir_arbol(zonas, codigo) do
    case Enum.find(zonas, fn z -> z.codigo == codigo end) do
      nil -> nil
      zona -> %{zona: zona, hijos: hijos(zonas, codigo)}
    end
  end

  defp hijos(zonas, codigo_padre) do
    zonas
    |> Enum.filter(fn z -> z.padre == codigo_padre end)
    |> Enum.map(fn hijo -> construir_arbol(zonas, hijo.codigo) end)
  end

  # Acumula afectados, número de sectores y puntos, y el nivel más grave de todo el árbol
  def estadisticas(nil), do: %{afectados: 0, sectores: 0, puntos: 0, nivel_max: "bajo"}

  def estadisticas(%{zona: zona, hijos: hijos}) do
    base = %{
      afectados: zona.afectados,
      sectores: if(zona.tipo == "sector", do: 1, else: 0),
      puntos: if(zona.tipo == "punto", do: 1, else: 0),
      nivel_max: zona.nivel
    }

    sumar_hijos(hijos, base)
  end

  defp sumar_hijos([], acumulado), do: acumulado

  defp sumar_hijos([hijo | resto], acumulado) do
    del_hijo = estadisticas(hijo)

    sumar_hijos(resto, %{
      afectados: acumulado.afectados + del_hijo.afectados,
      sectores: acumulado.sectores + del_hijo.sectores,
      puntos: acumulado.puntos + del_hijo.puntos,
      nivel_max: Zona.nivel_mas_grave(acumulado.nivel_max, del_hijo.nivel_max)
    })
  end

  # Todos los códigos del subárbol (la zona, sus sectores y sus puntos)
  def codigos(nil), do: []

  def codigos(%{zona: zona, hijos: hijos}) do
    Enum.reduce(hijos, [zona.codigo], fn hijo, acumulado -> acumulado ++ codigos(hijo) end)
  end

  # Árbol como texto con sangría
  def dibujar(arbol), do: dibujar(arbol, 0)

  defp dibujar(nil, _profundidad), do: ""

  defp dibujar(%{zona: z, hijos: hijos}, profundidad) do
    sangria = String.duplicate("   ", profundidad)
    linea = "#{sangria}- [#{z.tipo}] #{z.codigo} #{z.nombre} | nivel #{z.nivel} | afectados #{z.afectados}\n"

    hijos
    |> Enum.map(fn hijo -> dibujar(hijo, profundidad + 1) end)
    |> Enum.join("")
    |> (&(linea <> &1)).()
  end

  # ======================= 2. ORDEN POR PRIORIDAD =======================

  # Más urgente primero; a igual prioridad, la más antigua (id menor) primero
  def ordenar_por_prioridad([]), do: []
  def ordenar_por_prioridad([n | resto]), do: insertar(n, ordenar_por_prioridad(resto))

  defp insertar(n, []), do: [n]

  defp insertar(n, [primera | resto] = lista) do
    if va_antes?(n, primera), do: [n | lista], else: [primera | insertar(n, resto)]
  end

  defp va_antes?(a, b) do
    Necesidad.peso(a.prioridad) > Necesidad.peso(b.prioridad) or
      (Necesidad.peso(a.prioridad) == Necesidad.peso(b.prioridad) and a.id <= b.id)
  end

  # ======================= 3. PUNTAJE DE MASCOTAS =======================

  # Suma el peso de cada criterio [{campo, peso}, ...] en el que las dos mascotas coinciden
  def sumar_criterios([], _a, _b, total), do: total

  def sumar_criterios([{campo, peso} | resto], a, b, total) do
    puntos = if Mascota.iguales?(campo, a, b), do: peso, else: 0
    sumar_criterios(resto, a, b, total + puntos)
  end

  # ======================= 4. COINCIDENCIAS DE MASCOTAS =======================

  # Devuelve [{puntaje, perdida, encontrada}] de mayor a menor puntaje
  def buscar_coincidencias(reportes) do
    abiertos = Enum.filter(reportes, fn r -> r.estado != "resuelta" end)
    perdidas = Enum.filter(abiertos, fn r -> r.tipo == "perdida" end)
    encontradas = Enum.filter(abiertos, fn r -> r.tipo == "encontrada" end)

    perdidas
    |> comparar(encontradas, [])
    |> Enum.sort_by(fn {puntos, _p, _e} -> puntos end, &>=/2)
  end

  defp comparar([], _encontradas, acumulado), do: acumulado

  defp comparar([perdida | resto], encontradas, acumulado) do
    nuevas =
      encontradas
      |> Enum.map(fn e -> {Mascota.puntaje(perdida, e), perdida, e} end)
      |> Enum.filter(fn {puntos, _p, _e} -> puntos >= Mascota.umbral() end)

    comparar(resto, encontradas, nuevas ++ acumulado)
  end
end
