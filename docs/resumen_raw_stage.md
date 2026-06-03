# Resumen Raw -> Stage

Este documento resume como quedan los campos en la capa `staging` a partir de `raw`, que datos se normalizan, filtran o convierten de tipo, y que decisiones de saneamiento se toman.

## Criterio general

En `raw`, los CSV se preservan como copia fiel de los archivos originales. No se cambian nombres de campos, no se eliminan registros, no se combinan archivos y no se agregan datos calculados.

Ademas, todas las columnas se leen inicialmente como texto. La decision es que `raw` sea una capa auditable y que toda interpretacion del dato ocurra recien en `staging`.

## Usuarios

El modelo final `stg_usuarios` junta los padrones de 2022, 2023 y 2024 en una sola estructura comun.

| Campo final | Tipo de dato final | Saneamiento aplicado |
| --- | --- | --- |
| `id_usuario` | Numero entero grande | En 2022/2023 viene con el nombre `"ID_usuario"` y en 2024 como `id_usuario`. Se unifica el nombre y se convierte a numero. |
| `genero_usuario` | Texto | Se conserva el valor original. Los valores esperados son `MALE`, `FEMALE` y `OTHER`. |
| `edad_usuario` | Numero entero, puede quedar nulo | Primero se limpian separadores como comas. Despues se convierte a numero. Solo se conserva si esta entre `16` y `100`; si queda fuera de ese rango, se guarda como nulo. |
| `fecha_alta` | Fecha | Se convierte desde texto a fecha. |
| `hora_alta` | Hora | Se convierte desde texto a hora. |
| `tiene_dni` | Verdadero/falso, puede quedar nulo | En 2022/2023, `Yes` pasa a verdadero y `No` pasa a falso. En 2024 el archivo no trae esa informacion, por lo que queda nulo. |
| `anio_archivo` | Numero entero chico | Se agrega el anio del archivo de origen: `2022`, `2023` o `2024`. Sirve para trazabilidad. |

### Decisiones de saneamiento en usuarios

- La edad invalida no elimina al usuario: solo se deja la edad como nula.
- El rango valido de edad es `[16, 100]`: `16` por la edad minima del servicio y `100` como tope superior razonable.
- Valores como `"1,019"` se interpretan como `1019`, pero despues quedan nulos por estar fuera de rango.
- No se intenta reconstruir edades que parecen anios de nacimiento.
- `tiene_dni` nulo en 2024 significa "dato no provisto por el CSV", no "no tiene DNI".
- `stg_usuarios` conserva todos los registros de los tres anios; no aplica eliminacion de duplicados.

## Recorridos

El modelo final `stg_recorridos` junta los recorridos de 2022, 2023 y 2024. Cada anio se limpia primero por separado porque los archivos no tienen exactamente el mismo formato.

| Campo final | Tipo de dato final | Saneamiento aplicado |
| --- | --- | --- |
| `id_recorrido` | Numero entero grande | En 2022/2023 se remueve el sufijo `BAEcobici`; en 2024 se convierte a numero sin esa limpieza. |
| `id_usuario` | Numero entero grande | En 2022/2023 se remueve `BAEcobici`; en 2024 se remueve el sufijo `.0`. |
| `duracion_seg` | Numero entero, puede quedar nulo | En 2022/2023 se limpian separadores de miles y luego se convierte a numero. En 2024 se convierte directamente. No se eliminan valores extremos. |
| `fecha_origen` | Fecha y hora | Se convierte desde texto a fecha y hora. |
| `fecha_destino` | Fecha y hora, puede quedar nula | Se convierte desde texto a fecha y hora cuando el dato esta disponible. Puede quedar nula en recorridos sin cierre. |
| `id_estacion_origen` | Numero entero chico | En 2022/2023 se remueve `BAEcobici`; en 2024 se convierte a numero sin esa limpieza. |
| `nombre_estacion_origen` | Texto | Se conserva el valor original. |
| `direccion_estacion_origen` | Texto | Se conserva el valor original. |
| `lat_estacion_origen` | Numero decimal, puede quedar nulo | Se convierte desde texto a numero decimal. |
| `long_estacion_origen` | Numero decimal, puede quedar nulo | Se convierte desde texto a numero decimal. |
| `id_estacion_destino` | Numero entero chico, puede quedar nulo | Misma logica que la estacion de origen. Puede quedar nulo si el dato no esta disponible. |
| `nombre_estacion_destino` | Texto | Se conserva el valor original. |
| `direccion_estacion_destino` | Texto | Se conserva el valor original. |
| `lat_estacion_destino` | Numero decimal, puede quedar nulo | Se convierte desde texto a numero decimal. |
| `long_estacion_destino` | Numero decimal, puede quedar nulo | Se convierte desde texto a numero decimal. |
| `modelo_bicicleta` | Texto | Se conserva el valor original. Los valores esperados son `FIT` e `ICONIC`. |
| `genero_usuario` | Texto, puede quedar nulo | Se unifican distintas variantes del nombre del campo de origen en un solo campo final. |
| `anio_archivo` | Numero entero chico | Se agrega el anio del archivo de origen: `2022`, `2023` o `2024`. Sirve para trazabilidad. |

### Decisiones de saneamiento en recorridos

- Se descartan columnas de indice sin valor analitico, como `column00` y `X`.
- Los sufijos `BAEcobici` y `.0` se consideran artefactos del archivo de origen, no informacion real del dominio.
- `duracion_seg` se convierte a numero, pero no se filtra.
- Se conservan recorridos con `duracion_seg = 0` y `fecha_destino` nula, porque representan recorridos sin cierre al momento de exportar el archivo.
- Se conservan viajes de mas de 24 horas, porque pueden representar bicis no devueltas y son una senial util para BI o ML.
- `fecha_destino` puede quedar nula.
- `id_estacion_destino` puede quedar nulo en casos puntuales donde el recorrido tiene cierre pero falta la estacion destino.
- No se exige que todos los usuarios de recorridos existan en `stg_usuarios`, porque el padron contiene altas del periodo y hay usuarios historicos que viajaron pero no figuran en esos padrones.
- En el modelo final se elimina un unico registro duplicado identico detectado en 2024.

## Resumen de decisiones globales

- `raw` preserva fidelidad del CSV y no interpreta datos.
- `staging` concentra conversiones de tipo, renombres, normalizacion y saneamiento.
- Se prefiere conservar filas y marcar valores problematicos como nulos cuando el resto de la fila sigue siendo util.
- Los valores extremos que tienen significado operativo se preservan para que BI o ML decidan como tratarlos.
- Las diferencias entre anios se resuelven en modelos separados por anio, manteniendo el modelo final como una combinacion simple de esos resultados.
