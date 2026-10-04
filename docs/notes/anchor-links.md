# Enlaces ancla (¶) de nbconvert

Estado actual y una alternativa pendiente de decidir.

## Qué pasa

`nbconvert` añade un enlace con el símbolo `¶` tras cada título del notebook
(`<a class="anchor-link" href="#...">¶</a>`).

## Cómo se trata hoy (dos sitios)

| Dónde | Cómo | Dónde está el código |
|---|---|---|
| Vista web | Se oculta con CSS | `assets/stylesheets/notebook_preview.css`, regla `.notebook-preview-content .anchor-link` |
| Exportación (PDF, ODT, DOCX) | Se eliminan del HTML antes de exportar | `NbconvertService.strip_anchor_links`, llamado desde `prepare_for_export` |

El CSS no sirve en las exportaciones: el generador de informes de cosmoSys
pasa el HTML por LibreOffice sin ninguna hoja de estilos de Redmine, así que
sin `strip_anchor_links` el `¶` aparecía en el documento.

El HTML guardado en la caché conserva los enlaces; solo se retiran al exportar.

## Alternativa más limpia (no implementada)

Quitar los enlaces una sola vez al convertir, en `NbconvertService.convert`,
junto a `normalize_image_data_uris`, y borrar la regla CSS y
`strip_anchor_links`.

- Ventaja: una sola implementación; el HTML en caché ya sale limpio para la web
  y para las exportaciones.
- Coste: se pierde el enlace ancla en la web (ya estaba oculto con CSS, así que
  no cambia lo que se ve) y hay que regenerar la caché de los notebooks ya
  convertidos.
- Riesgo: ninguno conocido. Los enlaces `¶` no los usa nada más del plugin.

## Decisión

Pendiente. Mientras tanto se mantiene el tratamiento doble de arriba.
