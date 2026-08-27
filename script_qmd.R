## -----------------------------------------------------------------------------
#| label: librerias_muestra_2025

library(here)
library(readxl)
library(janitor)
library(tidyverse)
library(gt)
library(sf)
library(tmap)
library(sampling)
library(gtsummary)
library(infer)
library(patchwork)
library(srvyr)
library(survey)
library(cardx)
library(downloadthis)
library(polars)
library(haven)
library(plotly)
library(scales)

i_am("muestra_peb_2025.qmd")

theme_gtsummary_language(
language = "es",
decimal.mark = ",",
big.mark = ".")


## -----------------------------------------------------------------------------
#| label: fig-matricula_seccion
#| fig-cap: Relación entre el tamaño de la matrícula y la cantidad de secciones de los establecimientos

tb_establecimientos_2025 = read_xlsx(here("Inputs", "Nómina de establecimientos 20250720.xlsx")) |>
clean_names()

tb_establecimientos_primaria_2025 = tb_establecimientos_2025 |>
filter(nivel_modalidad == "Primaria")

tb_estab_matri_seccion = tb_establecimientos_2025 |>
select(matricula_inicial_2025, secciones_inicial_2025)

# 1. Cálculo un modelo lineal para obtener los parámetros
modelo = lm(matricula_inicial_2025 ~ secciones_inicial_2025, 
            data = tb_estab_matri_seccion)
coeficientes = coef(modelo)
r_cuadrado = summary(modelo)$r.squared

# Creación de la etiqueta con la ecuación
eq_label = paste0("y = ", round(coeficientes[1], 2), " + ", round(coeficientes[2], 2), "x",
                   "\n (R² = ", round(r_cuadrado, 3), ")")

# 2. Generación del gráfico
fig_matricula_seccion = ggplot(tb_establecimientos_primaria_2025,
   aes(x = secciones_inicial_2025, y = matricula_inicial_2025)) +
  geom_point(alpha = 0.4, color = "midnightblue") +
  # Adición de la línea de tendencia
  geom_smooth(method = "lm", color = "darkred", fill = "lightgray", se = TRUE) +
# Restricción viaul del eje Y a 3000 unidades
  coord_cartesian(ylim = c(0, 3000),
                  xlim = c(0, 75)) +
  # Inserción de los parámetros en el cuerpo del gráfico
  annotate("text", x = Inf, y = -Inf, label = eq_label, 
           hjust = 1.1, vjust = -1.1, size = 4, fontface = "italic", family = "serif") +
  labs(
    #title = "Análisis de Regresión: Matrícula vs. Secciones",
    subtitle = "Ciclo Lectivo 2025",
    x = "Cantidad de secciones",
    y = "Matrícula",
    caption = "Fuente: Elaboración propia basada en nómina de establecimientos"
  ) +
  theme_minimal() +
  theme(text = element_text(family = "serif"))

fig_matricula_seccion


## -----------------------------------------------------------------------------
#| label: tbl-matricula_size_seccion
#| tbl-cap: Comparación de la media y mediana de los establecimientos en función del tamaño de la sección (+- 10 estudiantes)

# Extraigo la matrícula de los establecimientos. Voy a buscar a todos para luego poder hacer join con las secciones

tb_establecimientos_matricula_2025 = tb_establecimientos_2025 |>
clean_names() |>
select(clave, matricula_inicial_2025, nivel_modalidad)

# Agrego informacion de secciones
tb_secciones_2025 = read_xlsx(here("Inputs", "SeccionesdetalladasRA2025.xlsx")) |>
clean_names() |>
mutate(total = as.double(total)) 

tbl_secciones_primaria_2025 = tb_secciones_2025 |>
select(clave, total) |>
left_join(tb_establecimientos_matricula_2025, by = "clave") |>
filter(nivel_modalidad == "Primaria") |>
mutate(secciones_10 = if_else(
 total <= 10, "Chicas", "No chica")) |>
select(secciones_10, matricula_inicial_2025) |>
tbl_summary(by = secciones_10,
           statistic = list(
      matricula_inicial_2025 ~ "{mean} \n {median}"
    ),
    digits = list(matricula_inicial_2025 ~ c(1, 1)),
    label = list(matricula_inicial_2025 ~ "Matrícula Inicial 2025")
  ) |>
  modify_header(label ~ "**Variable de Matrícula**") |>
  bold_labels()

tbl_secciones_primaria_2025


## -----------------------------------------------------------------------------
#| label: tb_muestra_2024
tb_muestra_2024 = read_xlsx(here("Inputs", "Muestra_PrimPE_2023 (diseño)_vf.xlsx"),
sheet = "Muestra vf") |>
clean_names() |>
select(clave) |>
mutate(muestra_2024 = "SI")


## -----------------------------------------------------------------------------
#| label: muestra_2023
#| eval: false
# levels_region = c("01", "02", "03", "04", "05", "06", "07",
#                   "08", "09", "10", "11", "12", "13", "14",
#                   "15", "16", "17", "18", "19", "20", "21",
#                   "22", "23", "24", "25")
# 
# base = read_xlsx(here("Inputs", "base_escuelas_primaria.xlsx")) |>
# clean_names() |>
# mutate(ambito = as_factor(ambito),
#        region = as_factor(region),
#        region = fct_relevel(region, levels_region))


## #C:\Users\dquar\positron_projects\mis_estudiantes_geo\inputs\estudiantes
## 
## import polars as pl
## from pyhere import here
## # Aca voy a buscar el archivo a otro proyecto porque pesa varios gigas
## mis_estudiantes_2025 =(
## pl.read_ipc("C:/Users/dquar/positron_projects/mis_estudiantes_geo/inputs/estudiantes/base_SAT_2025.ipc")
## .select([
##     pl.col("CLAVEESTAB"),
##     pl.col("DESCRIPCION_PLANPROGRAMA"),
##     pl.col("IDALUMNO"),
##     pl.col("NIVEL"),
##     pl.col("AÑO_ESTUDIO")
## ])
## #.filter(pl.col("NIVEL") == "Nivel Primario")
##   .with_columns(
##         pl.col("IDALUMNO").cast(pl.Int64))
## )

## #tb_AUH_2025 = (
## #mis_estudiantes_2025F
##  #   .filter(pl.col("DESCRIPCION_PLANPROGRAMA") == "ASIGNACION UNIVERSAL POR HIJO"))
## 
## # AUH ANTO
## tb_AUH_2025_ANTO = (
##     pl.read_csv(here("Inputs", "AUH_por_idalumno.csv"),
##                             separator=';')
##     .rename({"AUH": "AUH_ANTO"})
##     .join(
##         mis_estudiantes_2025,
##     on="IDALUMNO",
##     how="left"
##     )
##     .filter(pl.col("NIVEL")=="Nivel Primario")
## )
## 
## # Ahora tengo que agregar es tabla a mis_estudiantes
## 
## mis_estudiantes_2025 = mis_estudiantes_2025.join(
##     tb_AUH_2025_ANTO,
##     on="IDALUMNO",
##     how = "left"
## )
## 
## # Agregación para contar casos por establecimiento
## tb_AUH_establecimientos = (
##     mis_estudiantes_2025
##     .group_by("CLAVEESTAB")
##     .agg(
##         pl.col("AUH_ANTO").filter(pl.col("AUH_ANTO") == 1).count().alias("n_AUH"),
##     )
##     .sort("n_AUH", descending=True)
## )
## 
## tb_AUH_establecimientos.write_csv(
##     here("Inputs", "tb_AUH_establecimientos.csv")
## )

## -----------------------------------------------------------------------------
#| label: tb_jornada_completa_2025
# Voy a buscar tb_establecimientos_primaria_2025 y mejoro "jornada completa"
tb_establecimientos_primaria_2025 = tb_establecimientos_primaria_2025 |>
mutate(jornada_completa = if_else(
str_detect(caracteristicas, "completa"), "SI","NO"),
      jornada_completa = if_else(
 is.na(jornada_completa), "NO", jornada_completa))


## -----------------------------------------------------------------------------
marco_muestra = tb_establecimientos_primaria_2025 |>
select(clave, jornada_completa, nivel_modalidad, sector, ambito, matricula_inicial_2025, latitud, longitud) |>
mutate(latitud = as.numeric(latitud),
      longitud = as.numeric(longitud))

#tb_AUH_establecimientos = read_csv(here("Inputs", "tb_AUH_establecimientos.csv")) |>
#rename("clave" = "CLAVEESTAB",
 #     "n_auh" = "n_AUH")

# Este es el archivo enviado por Rosario
tb_AUH_establecimientos = read_xlsx(here("Inputs", "escuelas_AUH_2025.xlsx")) |>
rename("n_auh" = "con AUH")

marco_muestra = marco_muestra |>
left_join(tb_AUH_establecimientos, by = "clave") |>
mutate(auh_pct = (n_auh*100)/matricula_inicial_2025,
       auh_pct = if_else(auh_pct > 100, 100, auh_pct),
       tercil_auh = ntile(auh_pct, 3),
       NSE = case_when(
        tercil_auh == 1 ~ "Alto",
        tercil_auh == 2 ~ "Medio",
        tercil_auh == 3 ~ "Bajo",
        TRUE ~ NA_character_
       )) |>
left_join(tb_muestra_2024, by = "clave")



## -----------------------------------------------------------------------------
#| label: tbl-poblacion_muestra_2024
#| tbl-cap: Comparación parámetros poblacionales de establecimientos vs muestra 2024 
# 1. Generamos la tabla para la Población Total
tbl_poblacion = marco_muestra |>
  select(jornada_completa, sector, ambito, matricula_inicial_2025, auh_pct) |> # Excluimos la columna de la muestra para no sesgar el resumen
  tbl_summary() |>
  modify_header(label = "**Variable**")

# 2. Generamos la tabla exclusivamente para la Muestra
tbl_muestra_2024 = marco_muestra |>
  filter(muestra_2024 == "SI") |>
  select(jornada_completa, sector, ambito, matricula_inicial_2025, auh_pct) |>
  tbl_summary()

# 3. Fusionamos ambas tablas en una sola estructura comparativa
tbl_comparativa = tbl_merge(
    tbls = list(tbl_poblacion, tbl_muestra_2024),
    tab_spanner = c("**Población Total (N = {N})**", "**Muestra 2024(n = {N})**")
  )

tbl_comparativa


## -----------------------------------------------------------------------------
tbl_poblacion_jornada = marco_muestra |>
  select(jornada_completa, matricula_inicial_2025, sector, auh_pct) |> # Excluimos la columna de la muestra para no sesgar el resumen
  tbl_summary(by = jornada_completa) |>
  modify_header(label = "**Variable**")

# 2. Generamos la tabla exclusivamente para la Muestra
tbl_muestra_2024_jornada = marco_muestra |>
  filter(muestra_2024 == "SI") |>
 select(jornada_completa, matricula_inicial_2025, sector, auh_pct) |>
  tbl_summary(by = jornada_completa)

# 3. Fusionamos ambas tablas en una sola estructura comparativa
tbl_comparativa_jornada = tbl_merge(
    tbls = list(tbl_poblacion_jornada, tbl_muestra_2024_jornada),
    tab_spanner = c("**Población Total (N = {N})**", "**Muestra 2024(n = {N})**")
  )

# tbl_comparativa_jornada


## -----------------------------------------------------------------------------
#| label: muestra_cubo_2025

library(BalancedSampling)
library(sampling)



## -----------------------------------------------------------------------------
#| label: muestra_2025_primera etapa

# 1.Arregloe generales al objeto

marco_muestra = marco_muestra |>
drop_na(sector, matricula_inicial_2025, latitud, longitud, ambito, auh_pct) |> # Se sacan los NA
#rowid_to_column() # Número de caso
mutate(muestra_2024_dummy = if_else(is.na(muestra_2024), 0, 1),  # dummy para muestra_2024
      lat_std = scale(latitud), #Escalamiento para well distribution
      lon_std = scale(longitud),
      auh_std = scale(auh_pct))


# 2. Definición de Probabilidades de Inclusión (pi)

n = 676 # Tamaño de muestra deseado. Como referencia se toma uno similar a la muestra anterior
alpha = 21.89 # Rotación cada 4 años. En este cáculo influye la relación de muestreo, esto es, cuanto establecimientos se van a seleccionar en comparación al marco muestral. Cuanto mayor es la relación de muestreo menor es el valro del alpha.


# 3. Calculo de las probabilidades de inclusion
# Este paso no solo es necesario para utilizar el método del cubo sino que también es útil para luego usar estas probabilidades para calcular los "weight_design" en el proceso de calibración.

# Función para ajustar pi de manera que sum(pi) == n. Esto es importante porque ningún caso puede tener más de 1 como probabilidad de inclusión pero, a su vez, si solo se ajusta para que aquellos con más de 1 pasen a tener 1, la cantidad de casos deseada pasa a ser diferente al número de casos seleccionados mediante el cálculo. Es necesario no sólo corregir sino también distribuir esa corrección en las probabilidades de inclusión para que la suma o la masa de todas las probabilidades de inclusión de como resultado el respectivo número muestral deseado.

ajustar_pi = function(weight, n) {
  N = length(weight)
  pi = n * weight / sum(weight)
  
  # Mientras existan pi > 1, aplicamos el ajuste
  while (any(pi > 1)) {
    forzosos = pi >= 1
    pi[forzosos] = 1
    
    n_restante = n - sum(pi[forzosos])
    pi[!forzosos] = n_restante * weight[!forzosos] / sum(weight[!forzosos])
  }
  return(pi)
}

# Aplicación la función
marco_muestra$weight = marco_muestra$matricula_inicial_2025 * (1 + alpha * marco_muestra$muestra_2024_dummy)

# Creo pi_corregido dentro del marco muestral
marco_muestra = marco_muestra |>
mutate(pi_corregido = ajustar_pi(marco_muestra$weight, 676))

pi_corregido = marco_muestra$pi_corregido

# Verificación crucial: debe devolver n, esto es, la cantidad de casos a seleccionar (676)
#sum(pi_corregido)

# 4. Matriz de Variables Auxiliares (Balanced)

# Convierto las variables (y sus categorías) a dummies con model.matrix

X = model.matrix(~ sector + auh_pct + jornada_completa + ambito - 1, 
                 data = marco_muestra)

# Aseguramos que pi_corregido sea parte de las restricciones de balanceo
# Esto obliga al algoritmo a que la suma de unidades (n) sea fija.
X_balanceado = cbind(pi_corregido, X)

# 5. Matriz de Coordenadas (Well distribution)

# Es fundamental que las coordenadas estén en formato numérico.
# Acá si hay que estandarizar. Es vital que Latitud, Longitud y AUH tengan media 0 y desvío 1.
# Esto ya se había realizado antes en la preparación del objeto.

coords = as.matrix(marco_muestra[, c("lat_std", "lon_std", "auh_std")])

# 6. Selección de la Muestra
# lcube intenta balancear X y dispersar en el espacio de coords
set.seed(123) # Para reproducibilidad
indices_muestra = lcube(
    prob = pi_corregido, 
    Xba = X_balanceado, 
    Xsp = coords)

# 1. Inicializamos la columna con valor 0 (ningún establecimiento seleccionado)
marco_muestra$muestra_2025 = 0

# 2. Asignamos el valor 1 únicamente a las filas seleccionadas por lcube
marco_muestra$muestra_2025[indices_muestra] = 1

# 3. Opcional: Convertir a factor para facilitar tabulaciones posteriores
#marco_muestra$muestra_2025 = factor(marco_muestra$muestra_2025, 
 #                                   levels = c(0, 1), 
  #                                  labels = c("NO", "SI"))

#print(length(indices_muestra)) # Debería ser estrictamente 676


## -----------------------------------------------------------------------------
#| label: tbl-poblacion_muestra_2025
#| tbl-cap: Comparación parámetros poblacionales de establecimientos vs muestra 2025 
# 1. Generamos la tabla para la Población Total
tbl_poblacion = marco_muestra |>
  select(sector, ambito, matricula_inicial_2025, jornada_completa, latitud, longitud, auh_pct, muestra_2024) |> # Excluimos la columna de la muestra para no sesgar el resumen
  tbl_summary() |>
  modify_header(label = "**Variable**")

# 2. Generamos la tabla exclusivamente para la Muestra
tbl_muestra_2025 = marco_muestra |>
  filter(muestra_2025 == 1) |>
  select(sector, ambito, matricula_inicial_2025, jornada_completa, latitud, longitud, auh_pct, muestra_2024) |>
  tbl_summary()

# 3. Fusionamos ambas tablas en una sola estructura comparativa
tbl_comparativa_2025 = tbl_merge(
    tbls = list(tbl_poblacion, tbl_muestra_2025),
    tab_spanner = c("**Población Total (N = {N})**", "**Muestra 2025(n = {N})**")
  )

tbl_comparativa_2025


## -----------------------------------------------------------------------------
#| label: fig-mapa_muestra_2025
#| fig-cap: "Distribución de la población de los establecimientos (puntos negros) y de la muestra 2025 (puntos azules)"
#| eval: !expr knitr::is_html_output()
#| cache: true
mapa_marco_muestra = marco_muestra |>
st_as_sf(coords = c("longitud", "latitud"),
         dim = "XY",
         sf_column_name = "geom_escuela",
         crs = 4326) |>
select(ambito)

mapa_muestra_2025 = marco_muestra |>
filter(muestra_2025 == 1) |>
st_as_sf(coords = c("longitud", "latitud"),
         dim = "XY",
         sf_column_name = "geom_escuela",
         crs = 4326) |>
select(ambito)

tmap_mode("view")

fig_muestra_2025 = tm_basemap(server = "CartoDB.Positron",
           alpha = 0.5) +
tm_shape(mapa_marco_muestra,
         name = "Población") +
tm_dots(fill_alpha = 0.20,
        fill = "black") +
tm_shape(mapa_muestra_2025,
         name = "Muestra 2025") +
tm_dots(fill_alpha = 0.9,
        fill = "blue")

fig_muestra_2025



## -----------------------------------------------------------------------------
#| label: fig-mapa_calor_poblacion_muestra
#| fig-cap: Mapa de calor sobre la distribución de los casos. Población y muestra 2025.
# Función para crear el mapa de calor
crear_mapa_calor = function(data, titulo) {
  ggplot(data) +
    # Utilizamos las columnas numéricas directamente
    stat_density_2d(aes(x = longitud, 
                        y = latitud, 
                        fill = after_stat(level)), # Sintaxis moderna de ggplot2
                    geom = "polygon", 
                    alpha = 0.4) +
    # La capa sf se encarga de dibujar los puntos usando la columna 'geometry'
    geom_sf(size = 0.1, alpha = 0.1, color = "black") +
    scale_fill_viridis_c(option = "magma", name = "Densidad") +
    labs(title = titulo, 
      #   subtitle = "Visualización de la intensidad de cobertura",
         x = "Longitud", 
         y = "Latitud") +
    theme_minimal() +
    theme(legend.position = "right",
          panel.grid.major = element_line(color = "grey90"))
}

# Convertimos preservando las columnas originales de coordenadas
marco_sf = st_as_sf(marco_muestra, 
                     coords = c("longitud", "latitud"), 
                     crs = 4326, 
                     remove = FALSE) # <--- Este parámetro es la clave

muestra_sf = subset(marco_sf, muestra_2025 == 1)

# Generar ambos mapas
mapa_poblacion = crear_mapa_calor(marco_sf, "Población Total")
mapa_muestra = crear_mapa_calor(muestra_sf, "Muestra 2025")

# Visualización comparativa
mapa_poblacion + mapa_muestra


## -----------------------------------------------------------------------------
#| label: fig-densidad_auh
#| fig-cap: Distribución de densidad de porcentaje de AUH. Población y muestra 2025.

# 1. Preparación de los datos para la gráfica
# Creamos un dataframe que combine población y muestra
pop_data = data.frame(AUH = marco_muestra$auh_pct, Grupo = "Población")
mue_data = data.frame(AUH = marco_muestra$auh_pct[marco_muestra$muestra_2025 == 1], 
                       Grupo = "Muestra")

plot_data = rbind(pop_data, mue_data)

# 2. Generación del gráfico de densidades superpuestas
fig_densidad_auh = ggplot(plot_data, aes(x = AUH, fill = Grupo, color = Grupo)) +
  geom_density(alpha = 0.3, size = 1) +
  scale_fill_manual(values = c("Población" = "grey70", "Muestra" = "#2c3e50")) +
  scale_color_manual(values = c("Población" = "grey50", "Muestra" = "#2c3e50")) +
  labs(subtitle = "Población total vs. Muestra balanceada y dispersa",
       x = "Porcentaje de Estudiantes con AUH",
       y = "Densidad",
       caption = "Nota: El solapamiento indica la calidad del 'spreading' multivariado.") +
  theme_minimal() +
  theme(legend.position = "bottom",
        text = element_text(family = "serif"))

fig_densidad_auh

# Realización del test K-S
ks_result = ks.test(
  marco_muestra$auh_pct[marco_muestra$muestra_2025 == 1], 
  marco_muestra$auh_pct
)

#print(ks_result)


## -----------------------------------------------------------------------------
#| label: tb-estudiantes_10
# 1. Crear el universo de estudiantes (Simulado)
# Repetimos cada fila del marco según su variable 'size' (matrícula)
estudiantes_poblacion = marco_muestra[rep(seq_len(nrow(marco_muestra)), 
                                           times = marco_muestra$matricula_inicial_2025), ]
estudiantes_poblacion$Origen = "Población de Estudiantes (todos los años)"

# 2. Crear la muestra de estudiantes (Simulada)
# Seleccionamos las escuelas de la muestra y repetimos cada una 10 veces
escuelas_seleccionadas = subset(marco_muestra, muestra_2025 == 1)
estudiantes_muestra = escuelas_seleccionadas[rep(seq_len(nrow(escuelas_seleccionadas)), 
                                                  each = 10), ] # Solo 10 en vez de la matricula
estudiantes_muestra$Origen = "Muestra de Estudiantes (k=10)"

# 3. Consolidar para la comparación

comparativo_estudiantes = rbind(
  estudiantes_poblacion,
  estudiantes_muestra
)



## -----------------------------------------------------------------------------
#| label: tbl-poblacion_estudiantes_vs_muestra_estudiantes
#| tbl-cap: Comparación entre poblaciónes sintéticas de estudiantes
# 1. Generamos la tabla para la Población Total
tbl_muestra_estudiantes = comparativo_estudiantes |>
  select(sector, ambito, matricula_inicial_2025, jornada_completa, latitud, longitud, auh_pct, muestra_2024, Origen) |> # Excluimos la columna de la muestra para no sesgar el resumen
  tbl_summary(by = Origen) |>
  modify_header(label = "**Variable**")
tbl_muestra_estudiantes


## -----------------------------------------------------------------------------
#| label: fig-poblacion_estudiantes_vs_muestra_estudiantes

comparativo_estudiantes = rbind(
  estudiantes_poblacion[, c("auh_pct", "Origen")],
  estudiantes_muestra[, c("auh_pct", "Origen")]
)
ggplot(comparativo_estudiantes, aes(x = auh_pct, fill = Origen, color = Origen)) +
  geom_density(alpha = 0.35, size = 0.8) +
  scale_fill_manual(values = c("Población de Estudiantes" = "#bdc3c7", 
                               "Muestra de Estudiantes (k=10)" = "#e67e22")) +
  scale_color_manual(values = c("Población de Estudiantes" = "#7f8c8d", 
                                "Muestra de Estudiantes (k=10)" = "#d35400")) +
  labs(title = "Simulación del Perfil de Estudiantes",
       subtitle = "Comparación bajo diseño PPS y cuota fija por establecimiento",
       x = "Porcentaje de AUH (Variable del Establecimiento)",
       y = "Densidad de Estudiantes",
       caption = "Nota: La coincidencia de las curvas valida la propiedad de autoponderación.") +
  theme_minimal() +
  theme(legend.position = "bottom")




## -----------------------------------------------------------------------------
#| label: kolmogorov-estudiantes_poblacion
# Realización del test K-S
ks_result_estudiantes = ks.test(
  comparativo_estudiantes$auh_pct[comparativo_estudiantes$Origen == "Muestra de Estudiantes (k=10)"], 
  comparativo_estudiantes$auh_pct[comparativo_estudiantes$Origen == "Población de Estudiantes (todos los años)"]
)

# print(ks_result_estudiantes)


## -----------------------------------------------------------------------------
#| label: insumo_segunda_etapa

# Comienzo filtrando las secciones.
# Le pego los establecimientos de la primera etapa
# Algunos filtros son redundantes pero están por seguridad. Por ejemplo algunas secciones de primaria pueden ser de jardin.
# Filtro por primaria
# Filtro por año
# Filtro por muestra_2025

# Primero me tengo que quedar con sólo los establecimientos que entraron en la primera etapa
# También me tengo que quedar con sólo los anios que entran en ls PEB (3 y 6)

establecimientos_primera_etapa = marco_muestra |>
select(clave, muestra_2025) |>
filter(muestra_2025 == 1) 

insumo_segunda_etapa = tb_secciones_2025 |>
left_join(establecimientos_primera_etapa, by = "clave") |>
filter(muestra_2025 == 1) |>
filter(anio == 3 | anio == 6) |>
filter(descripcionofertaeducativa == "Primaria (1° Y 2° ciclo)")


## -----------------------------------------------------------------------------
#| label: fig-sd_size_secciones_intra_establecimiento
#| fig-cap: Diferencias de tamaño de las secciones para igual establecimiento y año. Media estandarizada en 0 y desvío estándar en cantidad de estudiantes.

#tb_secciones_2025_segunda_etapa = tb_secciones_2025 |>
#left_join(tb_establecimientos_matricula_2025, by = "clave") |>
#filter(nivel_modalidad == "Primaria") |>
#filter(anio == 3 | anio == 6)

# --- 1. Preparación y Métricas de Dispersión ---

analisis_variabilidad = insumo_segunda_etapa |>
  group_by(clave, anio) |>
  # Filtramos grupos con más de una sección para analizar la variabilidad interna
  # Esto es solo para este analisis no para la muestra 
  filter(n() > 1) |> 
  mutate(
    mean_grupo = mean(total, na.rm = TRUE),
    sd_grupo = sd(total, na.rm = TRUE),
    # El Coeficiente de Variación nos da la magnitud relativa del error
    cv_grupo = (sd_grupo / mean_grupo) * 100,
    # Diferencia entre la sección y su promedio grupal
    distancia_media = total - mean_grupo
  ) |>
  ungroup() |>
select(clave, anio, total, mean_grupo, sd_grupo, cv_grupo, distancia_media) |>
arrange(clave, anio)

# --- 2. Visualización: Distribución de la Variabilidad ---

# Gráfico A: ¿Qué tan diferentes son las secciones dentro de un mismo colegio?
# Si la "regla simple" fuera válida, este histograma debería estar muy concentrado en 0.
fig_sd_size_secciones_intra_establecimiento = ggplot(analisis_variabilidad, aes(x = distancia_media)) +
  geom_histogram(bins = 30, fill = "steelblue", color = "white", alpha = 0.8) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  labs(
    x = "Desviación estándar respecto a la media de las secciones (en n estudiantes)",
    y = "Frecuencia de secciones"
  ) +
scale_x_continuous(limits = c(-15, 15),                # Establece el rango visible
    breaks = seq(from = -15, to = 15, by = 2)) + # Define etiquetas cada 5 unidades+
  theme_minimal()

fig_sd_size_secciones_intra_establecimiento


## -----------------------------------------------------------------------------
#| label: muestra_2025_segunda_etapa

set.seed(123) 

# Hay que ver que se hace con los turnos (MANANA/TARDE)

resultado_segunda_etapa = insumo_segunda_etapa |>
  group_by(clave, anio) |> #Esto para que los sorteos no solo se ejecuten por establecimiento sino también por anio (3 y 6)
  # 1. Barajamos las secciones internamente para neutralizar órdenes preexistentes
  sample_frac(1) |>
  mutate(
    # 2. Calculamos la probabilidad proporcional al tamaño de la sección
    prob_seleccion = total / sum(total),
    
    # 3. Generamos un ranking basado en un sorteo con pesos en función del tamaño
    # Esto asegura que las más grandes tengan más chance de quedar en 1er lugar,
    # pero permite que las pequeñas también ocupen ese puesto ocasionalmente.
  orden = rank(- (prob_seleccion * runif(n())))
    # Nota: El uso de runif^(1/p) es una técnica para sorteo PPT. Acá se hace una aplicación más lineal por lo que hubiera estado mejor aplicar algo como rank(- (runif(n())^(1 / prob_seleccion)))
  ) |>
  arrange(clave, anio, orden) |>
  mutate(
    rol = case_when(
      orden == 1 ~ "Principal",
      orden == 2 ~ "Suplente/Complementaria",
      TRUE ~ "Reserva"
    ),
   seccion_mas_grande = if_else(orden == 1 & prob_seleccion == max(prob_seleccion), "SI", "NO")
  ) |>
group_by(clave) |>
mutate(establecimiento_numero = cur_group_id()) |>
ungroup() |>
mutate(instruccion_muestreo = if_else(
      establecimiento_numero %% 2 == 0, 
      "Pruebas de Matemática y Prácticas del Lenguaje de lxs 10 primerxs estudiantes de la lista (por orden alfabético) que realizaron las pruebas PEB",
      "Pruebas de Matemática y Prácticas del Lenguaje de lxs 10 últimos estudiantes de la lista (por orden alfabético) que realizaron las pruebas PEB"
    ),
      muestra_2025_seccion = if_else(orden == 1, "SI", "NO")
  ) |>
select(idseccion, clave, anio, turno, total, muestra_2025, prob_seleccion, orden, rol, seccion_mas_grande, nombre_seccion, establecimiento_numero, instruccion_muestreo, muestra_2025_seccion)


## -----------------------------------------------------------------------------
#| label: tbl-poblacion_muestra_secciones
#| tbl-cap: Población y muestra de secciones
tbl_poblacion_muestra_secciones = resultado_segunda_etapa |>
select(total, anio, muestra_2025_seccion, seccion_mas_grande) |>
rename("tamaño" = total) |>
tbl_summary(by = muestra_2025_seccion,
           statistic = list(
      all_continuous() ~ "{mean} ({sd})}"))

tbl_poblacion_muestra_secciones



## -----------------------------------------------------------------------------
#| label: entrega_final

muestra_2025 = resultado_segunda_etapa |>
select(idseccion, clave, anio, total, orden, rol, nombre_seccion, establecimiento_numero, instruccion_muestreo)

library(writexl)
write_xlsx(muestra_2025,
           here("Outputs", "muestra_2025.xlsx"))


## -----------------------------------------------------------------------------
#| label: muestra_estudiantes_3
#| echo: true
#| code-fold: true
#Voy a buscar los insumos de la muestra de estudiantes
#Como la muestra vino en .sav (SPSS) uso la libreria haven
muestra_estudiantes_3 = read_sav(here("Inputs", "PEB_2025", "PEB_Primaria_3er año_Carga por estudiante_2025_con variables de contexto.sav")) |>
rename(clave = CLAVE) |>
rename(prioridad_seccion = IM2) |>
rename(turno = IM1) |>
rename(ira_mat = Puntaje_Mate) |>
rename(ira_pl = Puntaje_PL) |>
mutate(anio = 3,
       prioridad_seccion = as_factor(prioridad_seccion))
# Creo NSC como etiqueta de Tercil_AUH porque sino es contraintuitivo.
# De todos modos...ese tercil parece calculado en función del marco muestral (tercil del establecimiento en la nomina de establecimientos) y no de la propia muestra. En efecto, las cantidades de cada tercil no forman terciles y muestran que en la muestra hubo una sobrerepresentación de los establecimientos de nivel "Alto")
levels_NSE = c("Bajo", "Medio", "Alto")
muestra_estudiantes_3 = muestra_estudiantes_3 |>
mutate(NSE = case_when(
tercil_AUH == 1 ~ "Alto",
tercil_AUH == 2 ~ "Medio",
tercil_AUH == 3 ~ "Bajo")
       ) |>
mutate(NSE = fct_relevel(NSE, levels_NSE))


## -----------------------------------------------------------------------------
#| label: calib_3_pi_1
#| echo: true
#| code-fold: true
prob_seleccion_primera_etapa = marco_muestra |>
select(clave, pi_corregido)

insumo_calibracion_3 = muestra_estudiantes_3 |>
  # Vinculamos la probabilidad preestablecida del cubo por establecimiento y la denominamos pi_1 para indicar que es la probabilidad de inclusión de la primera etapa
  left_join(prob_seleccion_primera_etapa, by = "clave") |>
rename(pi_1 = pi_corregido)



## -----------------------------------------------------------------------------
#| label: calib_3_pi_2
#| echo: true
#| code-fold: true
#Finalmente, la probabilida de selección de cada sección estaba en el objeto "resultado_segunda_etapa"
prob_seleccion_segunda_etapa = resultado_segunda_etapa |>
rename(prioridad_seccion = rol) |>
rename(size_seccion = total) |>
mutate(prioridad_seccion = case_when(
       prioridad_seccion == "Suplente/Complementaria" ~ "Suplente",
      .default = prioridad_seccion
    ),
    azar_desempate = runif(n())) |>
  group_by(clave, anio) |>
  # 2. Calculamos de forma segura la máxima probabilidad de las Reservas por grupo
  mutate(
    max_prob_reserva = if (any(prioridad_seccion == "Reserva")) {
      max(prob_seleccion[prioridad_seccion == "Reserva"], na.rm = TRUE)
    } else {NA_real_}) |>
  # 3. Aplicamos el criterio de selección
filter(
    # Conservamos siempre todos los "Principal" y "Suplente"
    prioridad_seccion %in% c("Principal", "Suplente") |
    # Para las "Reserva", ordenamos los empates y nos quedamos con el primero
    (prioridad_seccion == "Reserva" & prob_seleccion == max_prob_reserva)) |>
     # Este paso lógico asegura conservar solo el registro con el mayor valor de azar entre los empatados
    arrange(prioridad_seccion, 
    desc(prob_seleccion), 
    desc(azar_desempate), .by_group = TRUE) |>
  # 4. Nos quedamos con máximo una fila por cada tipo de prioridad dentro del establecimiento y año
  distinct(clave, anio, prioridad_seccion, .keep_all = TRUE) |>
  ungroup() |>
select(idseccion, clave, anio, prioridad_seccion, prob_seleccion, size_seccion) 

# Como hay establecimientos que tienen más de una opción de "reserva" (aunque siempre 1 de Principal y 1 de Suplente) me quedo solo con la seccion con mas probabilidad de cada establecimiento.

insumo_calibracion_3 = insumo_calibracion_3 |>
# Existe un establecimiento que incluyo una sección que no estaba en la base de secciones. Le imputo la misma pi_2 que la de la seccion presente. Hago lo mismo con el idseccion
mutate(prioridad_seccion = if_else(clave == "0104PP0002", "Principal", prioridad_seccion)) |>
 left_join(prob_seleccion_segunda_etapa, by = join_by(clave, anio, prioridad_seccion)) |>
rename(pi_2 = prob_seleccion)


## -----------------------------------------------------------------------------
#| label: calib_3_pi_3
#| echo: true
#| code-fold: true
insumo_calibracion_3 = insumo_calibracion_3 |>
add_count(clave, anio, idseccion, name = "pik_estudiantes_seccion") |>
mutate(pi_3_diseno = pik_estudiantes_seccion / size_seccion,
       pi_3 = pmin(pi_3_diseno, 1))


## -----------------------------------------------------------------------------
#| label: calib_3_weight_design
#| echo: true
#| code-fold: true
insumo_calibracion_3 = insumo_calibracion_3 |>
  mutate(
    # PROBABILIDAD DE INCLUSIÓN TOTAL (Producto de todas las etapas)
    pi_total_estudiante = pi_1 * pi_2 * pi_3,
    # PESO BASE INICIAL (Recién aquí aplicamos la inversa para la calibración)
    weight_design = 1 / pi_total_estudiante
  )


## -----------------------------------------------------------------------------
#| label: tbl-calib_3_weight_design_test_1
#| tbl-cap: Chequeos de los ponderadores de diseño
#| echo: true
#| code-fold: true
tbl_weight_design_test_1 = insumo_calibracion_3 |> 
  summarise(
    casos_totales = n(),
    casos_na      = sum(is.na(weight_design)),
    casos_inf     = sum(is.infinite(weight_design)),
    casos_neg     = sum(weight_design < 1, na.rm = TRUE),
    peso_minimo   = min(weight_design, na.rm = TRUE),
    peso_maximo   = max(weight_design, na.rm = TRUE),
    suma_pesos    = sum(weight_design, na.rm = TRUE)
  ) |>
gt()

tbl_weight_design_test_1


## -----------------------------------------------------------------------------
n_poblacion_3 = tb_secciones_2025 |>
  filter(anio == 3) |>
  filter(descripcionofertaeducativa == "Primaria (1° Y 2° ciclo)") |>
  summarise(n_estudiantes_3 = sum(total),
            n_secciones_3   = n_distinct(idseccion, na.rm = TRUE),
            n_establecimientos_3    = n_distinct(clave, na.rm = TRUE))


## -----------------------------------------------------------------------------
#| label: n_poblacion_objetivo_3
#| echo: true
#| code-fold: true
# Hay más de una manera de hacerla. Por un lado está la base de secciones. Esto tiene el beneficio, a pesar de tener algunas secciones sin valor, de poder discriminar el peso de los 3 entre toda la matrícula primaria. Esa proporción es la que se puede utilizar tomando como un mejor indicador de toda la masa de estudiante el dato que sale de la base de establecimientos (marco_muestra)
n_poblacion_3_base_secciones = tb_secciones_2025 |>
filter(anio == 3) |>
filter(descripcionofertaeducativa == "Primaria (1° Y 2° ciclo)") |>
summarise(matricula = sum(total))

n_poblacion_primaria_base_secciones = tb_secciones_2025 |>
filter(descripcionofertaeducativa == "Primaria (1° Y 2° ciclo)") |>
summarise(matricula = sum(total))

ratio_primaria_terceros = n_poblacion_primaria_base_secciones$matricula / 
                          n_poblacion_3_base_secciones$matricula

# Esto estima la matricula_3 de cada establecimiento
marco_muestra = marco_muestra |>
mutate(matricula_3 = matricula_inicial_2025 / ratio_primaria_terceros)

n_poblacion_objetivo_3 = marco_muestra |>
summarise(matricula_3 = sum(matricula_inicial_2025)/ratio_primaria_terceros)


## -----------------------------------------------------------------------------
#| label: tbl-calib_3_weight_design_test_2
#| tbl-cap: Chequeos descomposición weight_design
tbl_weight_3_design_test_2 = insumo_calibracion_3 |> 
  summarise(
    n_muestra = n(),
    # Evaluamos las probabilidades medias de cada etapa   
    media_pi_1 = mean(pi_1, na.rm = TRUE),
    media_pi_2 = mean(pi_2, na.rm = TRUE),
    media_pi_3 = mean(pi_3, na.rm = TRUE),
    
    # Evaluamos los pesos medios que aporta cada etapa
    peso_medio_etapa1 = mean(1 / pi_1, na.rm = TRUE),
    peso_medio_etapa2 = mean(1 / pi_2, na.rm = TRUE),
    peso_medio_etapa3 = mean(1 / pi_3, na.rm = TRUE)
  ) |>
gt()

tbl_weight_3_design_test_2


## -----------------------------------------------------------------------------
#| label: tbl-calib_3_weight_design_test_3
#| tbl-cap: Distribución de weight_design
tbl_calib_3_weight_design_test_3 = insumo_calibracion_3 |> 
  select(weight_design) |> 
  tbl_summary(
    label = list(weight_design ~ "Factor de Expansión (weight_design)"),
    statistic = list(all_continuous() ~ "{mean} ({sd}) | Mediana: {median} [Min: {min}, Max: {max}]"),
    digits = list(all_continuous() ~ c(2, 2, 2, 2, 2))
  ) |> 
  bold_labels()

tbl_calib_3_weight_design_test_3


## -----------------------------------------------------------------------------
#| label: tbl-calib_3_weight_design_test_4
#| tbl-cap: Media del weight_design según diferentes percentiles
tbl_calib_3_weight_design_test_4 = quantile(insumo_calibracion_3$weight_design, 
         probs = c(0, 0.05, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99, 1), 
         na.rm = TRUE) |>
enframe(name = "Percentil", 
        value = "Valor") |> 
  gt() |> 
  fmt_number(columns = Valor, decimals = 2)

tbl_calib_3_weight_design_test_4


## -----------------------------------------------------------------------------
#| label: tbl-calib_3_weight_design_test_5
#| tbl-cap: Media del weight_design según diferentes percentiles

tbl_calib_3_weight_design_test_4 = insumo_calibracion_3 |> 
  ggplot(aes(x = weight_design)) +
  geom_density(
    fill = "#2B4C7E", 
    color = "#1A2E4C", 
    alpha = 0.4, 
    linewidth = 0.7
  ) +
  scale_x_continuous(breaks = breaks_width(width = 100, offset = 0),
     labels = label_comma()) +
  scale_y_continuous(labels = label_scientific()) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(color = "grey30", size = 10)
  ) +
  labs(
    title = "Distribución de densidad de los ponderadores base",
    subtitle = "Variable: weight_design",
    x = "Ponderador de diseño",
    y = "Densidad de probabilidad"
  ) 

ggplotly(tbl_calib_3_weight_design_test_4)


## -----------------------------------------------------------------------------
#| label: no_respuesta
df_no_respuesta_3 = marco_muestra |>
filter(muestra_2025 == 1) |>
mutate(respuesta_muestra = clave %in% insumo_calibracion_3$clave,
# Para no crear "grupos" de no respuesta con muy pocos casos (o con ninguno en la muestra) vamos a "agrupar" los tamaños de la matricula y los porcentajes de auh
decil_size = ntile(matricula_inicial_2025, 3),
decil_auh = ntile(auh_pct, 3))

factores = df_no_respuesta_3 |>
  group_by(decil_size, decil_auh, jornada_completa, ambito, Region, sector) |>
  summarise(
    N_total = n(),
    N_respuesta = sum(respuesta_muestra),
    .groups = "drop"
  ) |>
  mutate(no_respuesta_factor = N_total / N_respuesta)


## -----------------------------------------------------------------------------
#| label: tbl-no_respuesta_3_1
#| tbl-cap: Distribución de la no respuesta según características de los establecimientos
# Preparar el dataframe de la muestra seleccionada
analisis_no_respuesta_3 = marco_muestra |>
  filter(muestra_2025 == 1) |>
  mutate(
    # Convertimos a factor con etiquetas claras para la presentación
    Estado_Respuesta = factor(
      clave %in% insumo_calibracion_3$clave,
      levels = c(TRUE, FALSE),
      labels = c("Respondiente", "No Respondiente")
    )
  )

# Generar la tabla descriptiva comparativa
tbl_tabla_comparativa_3 = analisis_no_respuesta_3 |>
  select(Estado_Respuesta, matricula_inicial_2025, auh_pct, Region, sector, jornada_completa, ambito) |>
  tbl_summary(
    by = Estado_Respuesta,
    label = list(
      auh_pct ~ "% Alumnos con AUH"
    ),
    statistic = list(
      all_continuous() ~ "{mean} ({sd}) [Mediana: {median}]",
      all_categorical() ~ "{n} ({p}%)"
    )
  ) |>
# add_p() |> # Agrega p-values para evaluar significancia (t-test, Wilcoxon, Chi-cuadrado)
add_overall(last = TRUE) |>
  bold_labels()

# Visualizar la tabla
tbl_tabla_comparativa_3


## -----------------------------------------------------------------------------
#| label: fig-no_respuesta_3_size
#| fig-cap: Distribución de la no respuesta según tamaño de la matrícula

# Gráfico para la variable Tamaño de establecimiento
fig_no_respuesta_size_3 = analisis_no_respuesta_3 |>
ggplot(aes(x = matricula_inicial_2025, fill = Estado_Respuesta)) +
  geom_density(alpha = 0.5) +
  scale_fill_manual(values = c("#2b8cbe", "#de2d26")) + # Azul y Rojo sobrios
  labs(
    x = "Matrícula (Cantidad de Alumnos)",
    y = "Densidad",
    fill = "Estado"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")
fig_no_respuesta_size_3_i = ggplotly(fig_no_respuesta_size_3)
fig_no_respuesta_size_3_i


## -----------------------------------------------------------------------------
#| label: fig-no_respuesta_3_auh
#| fig-cap: Distribución de la no respuesta según porcentaje de AUH

# Gráfico para la variable Tamaño de establecimiento
fig_no_respuesta_auh_3 = analisis_no_respuesta_3 |>
ggplot(aes(x = auh_pct, fill = Estado_Respuesta)) +
  geom_density(alpha = 0.5) +
  scale_fill_manual(values = c("#2b8cbe", "#de2d26")) + # Azul y Rojo sobrios
  labs(
    x = "% AUH",
    y = "Densidad",
    fill = "Estado"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")
fig_no_respuesta_auh_3_i = ggplotly(fig_no_respuesta_auh_3)
fig_no_respuesta_auh_3_i


## -----------------------------------------------------------------------------
#| label: tbl-hist_secciones_establecimientos_3
#| tbl-cap: Distribución de seccciones seleccionadas por establecimiento

n_establecimientos_diseno = muestra_2025 |>
summarise(n_establecimientos_diseno= n_distinct(clave))

df_exploracion_campo_3 = insumo_calibracion_3 |>
group_by(clave) |>
summarise(n_secciones_campo = n_distinct(prioridad_seccion),
          n_estudiantes_campo = n()) |>
mutate(
  n_establecimientos = n())

tbl_secciones_establecimientos_3 = df_exploracion_campo_3 |>
tbl_summary(
    include = n_secciones_campo,
    label = list(n_secciones_campo ~ "Secciones por establecimiento"),
    statistic = list(all_categorical() ~ "{n} ({p}%)"),
    digits = list(all_categorical() ~ c(0, 1))
  ) |> 
  # Añadimos un encabezado elegante y el total de N (establecimientos)
  modify_header(label = "**Variable**") |> 
  modify_footnote(everything() ~ NA) |> # Opcional: remueve notas al pie automáticas si prefiere un estilo más limpio
  bold_labels()

tbl_secciones_establecimientos_3


## -----------------------------------------------------------------------------
#| label: fig-hist_estudiantes_establecimientos_3
#| fig-cap: Distribución de estudiantes seleccionados por establecimiento
fig_estudiantes_establecimientos_3 = df_exploracion_campo_3 |>
ggplot(aes(x = n_estudiantes_campo)) +
  geom_histogram(binwidth = 2, fill = "forestgreen", color = "white", alpha = 0.8) +
  labs(
    x = "Cantidad de estudiantes seleccionados",
    y = "Frecuencia (Establecimientos)"
  ) +
  theme_minimal()
fig_estudiantes_establecimientos_3


## -----------------------------------------------------------------------------
#| label: tbl-hist_estudiantes_establecimientos_3
#| tbl-cap: Distribución de estudiantes seleccionados por establecimiento
tbl_estudiantes_establecimientos_3 = df_exploracion_campo_3 |>
tbl_summary(
    include = n_estudiantes_campo,
    label = list(n_estudiantes_campo ~ "Estudiantes por establecimiento"),
    statistic = list(all_categorical() ~ "{n} ({p}%)"),
    digits = list(all_categorical() ~ c(0, 1))
  ) |> 
  # Añadimos un encabezado elegante y el total de N (establecimientos)
  modify_header(label = "**Variable**") |> 
  bold_labels()

tbl_estudiantes_establecimientos_3


## -----------------------------------------------------------------------------
#| label: no_respuesta_propensity_score_3
#| echo: true
#| code-fold: true
df_no_respuesta_3 = marco_muestra |>
filter(muestra_2025 == 1) |>
mutate(respuesta_muestra = as.numeric(clave %in% insumo_calibracion_3$clave))

# Nota: tamaño y porcentaje de AUH ingresan como variables continuas
modelo_propension_3 = glm(
  respuesta_muestra ~ matricula_inicial_2025 + auh_pct + Region * sector + jornada_completa * ambito,
  data = df_no_respuesta_3,
  family = binomial(link = "logit")
)

# Obtener las probabilidades predichas para toda la muestra seleccionada
df_no_respuesta_3 = df_no_respuesta_3 |>
  mutate(prob_respuesta = predict(modelo_propension_3, type = "response"))

# Filtrar los factores para los respondientes y calcular el inverso
factores_modelo_3 = df_no_respuesta_3 |>
  filter(respuesta_muestra == 1) |>
  select(clave, prob_respuesta) |>
  mutate(inv_no_respuesta = 1 / prob_respuesta)

# Aplicar el factor a su base de estudiantes
insumo_calibracion_3 = insumo_calibracion_3 |>
  left_join(factores_modelo_3, by = "clave") |>
  mutate(weight_no_respuesta = weight_design * inv_no_respuesta)



## -----------------------------------------------------------------------------
#| label: tbl-comparacion_pasos_nr_3
#| tbl-cap: Comparación de métricas entre weight_design y weight_no_respuesta
#| echo: true
#| code-fold: true

# Defino el target poblacional como la suma de estudiantes de 3.er año del marco muestral
target_poblacional_3 = n_poblacion_objetivo_3$matricula_3

# Calculo las sumas de ambos ponderadores para usarlas en la tabla
suma_wd  = sum(insumo_calibracion_3$weight_design, na.rm = TRUE)
suma_wnr = sum(insumo_calibracion_3$weight_no_respuesta, na.rm = TRUE)

# Construyo un dataframe con las métricas de resumen para cada ponderador
df_metricas_nr_3 = tibble(
  Indicador = c(
    "Suma de pesos (N estimado)",
    "Media del ponderador",
    "Mediana del ponderador",
    "Desvío estándar",
    "Peso mínimo",
    "Peso máximo",
    "Coeficiente de variación",
    "Target poblacional (N)",
    "Diferencia vs target (%)"
  ),
  peso_diseno = c(
    suma_wd,
    mean(insumo_calibracion_3$weight_design, na.rm = TRUE),
    median(insumo_calibracion_3$weight_design, na.rm = TRUE),
    sd(insumo_calibracion_3$weight_design, na.rm = TRUE),
    min(insumo_calibracion_3$weight_design, na.rm = TRUE),
    max(insumo_calibracion_3$weight_design, na.rm = TRUE),
    sd(insumo_calibracion_3$weight_design, na.rm = TRUE) /
      mean(insumo_calibracion_3$weight_design, na.rm = TRUE),
    target_poblacional_3,
    (suma_wd - target_poblacional_3) / target_poblacional_3 * 100
  ),
  peso_nr = c(
    suma_wnr,
    mean(insumo_calibracion_3$weight_no_respuesta, na.rm = TRUE),
    median(insumo_calibracion_3$weight_no_respuesta, na.rm = TRUE),
    sd(insumo_calibracion_3$weight_no_respuesta, na.rm = TRUE),
    min(insumo_calibracion_3$weight_no_respuesta, na.rm = TRUE),
    max(insumo_calibracion_3$weight_no_respuesta, na.rm = TRUE),
    sd(insumo_calibracion_3$weight_no_respuesta, na.rm = TRUE) /
      mean(insumo_calibracion_3$weight_no_respuesta, na.rm = TRUE),
    target_poblacional_3,
    (suma_wnr - target_poblacional_3) / target_poblacional_3 * 100
  )
)

# Genero la tabla gt con formato
df_metricas_nr_3 |>
  gt() |>
  tab_header(
    title = "Comparación de métricas: weight_design vs weight_no_respuesta",
    subtitle = "Tercer año – PEB 2025"
  ) |>
  cols_label(
    peso_diseno = "Peso de diseño",
    peso_nr = "Peso ajustado por NR"
  ) |>
  fmt_number(
    columns = c(peso_diseno, peso_nr),
    decimals = 2
  ) |>
  tab_style(
    style = cell_fill(color = "#f0f7ff"),
    locations = cells_body(
      rows = Indicador %in% c("Target poblacional (N)", "Diferencia vs target (%)")
    )
  ) |>
  tab_options(table.width = pct(100))


## -----------------------------------------------------------------------------
#| label: tbl-diagnostico_inv_nr_3
#| tbl-cap: Distribución de la probabilidad de respuesta y del factor de no respuesta
#| echo: true
#| code-fold: true

# Calculo los percentiles clave de la probabilidad de respuesta
# y derivo la inversa de esos mismos valores para que cada fila sea coherente
probs_diag = c(0, 0.05, 0.25, 0.50, 0.75, 0.95, 0.99, 1)

prob_quantiles_3 = quantile(
  insumo_calibracion_3$prob_respuesta,
  probs = probs_diag, na.rm = TRUE
)

df_diagnostico_inv_nr_3 = tibble(
  Percentil = c("Mínimo (P0)", "P5", "P25", "P50 (Mediana)",
                "P75", "P95", "P99", "Máximo (P100)"),
  prob_respuesta = prob_quantiles_3,
  inv_no_respuesta = 1 / prob_quantiles_3
)

# Genero la tabla gt
df_diagnostico_inv_nr_3 |>
  gt() |>
  tab_header(
    title = "Distribución del factor de no respuesta",
    subtitle = "Probabilidad de respuesta y su inversa – Tercer año PEB 2025"
  ) |>
  cols_label(
    prob_respuesta = "Prob. Respuesta",
    inv_no_respuesta = "Inversa (1/prob)"
  ) |>
  fmt_number(
    columns = c(prob_respuesta, inv_no_respuesta),
    decimals = 4
  ) |>
  tab_options(table.width = pct(100))


## -----------------------------------------------------------------------------
#| label: tbl-hosmer_lemeshow_nr_3
#| tbl-cap: Diagnóstico tipo Hosmer-Lemeshow del modelo de propensión
#| echo: true
#| code-fold: true

# Agrupo los establecimientos en deciles según su probabilidad predicha
# y comparo la tasa observada vs predicha dentro de cada grupo
tbl_hl_nr_3 = df_no_respuesta_3 |>
  mutate(decil_prob = ntile(prob_respuesta, 10)) |>
  group_by(decil_prob) |>
  summarise(
    N = n(),
    Respondientes = sum(respuesta_muestra),
    Tasa_obs = mean(respuesta_muestra),
    Tasa_pred = mean(prob_respuesta),
    Prob_min = min(prob_respuesta),
    Prob_max = max(prob_respuesta),
    .groups = "drop"
  ) |>
  mutate(Diferencia = Tasa_obs - Tasa_pred)

# Genero la tabla gt
tbl_hl_nr_3 |>
  gt() |>
  tab_header(
    title = "Diagnóstico de calibración: observado vs predicho por decil",
    subtitle = "Modelo de propensión de respuesta – Tercer año PEB 2025"
  ) |>
  cols_label(
    decil_prob = "Decil",
    Respondientes = "Resp.",
    Tasa_obs = "Tasa Obs.",
    Tasa_pred = "Tasa Pred.",
    Prob_min = "Prob. Mín.",
    Prob_max = "Prob. Máx.",
    Diferencia = "Dif."
  ) |>
  fmt_percent(
    columns = c(Tasa_obs, Tasa_pred, Diferencia, Prob_min, Prob_max),
    decimals = 1
  ) |>
  fmt_integer(columns = c(N, Respondientes)) |>
  tab_options(table.width = pct(100))


## -----------------------------------------------------------------------------
#| label: tbl-cruces_nr_interacciones_3
#| tbl-cap: Tasa de respuesta observada vs predicha por cruces de variables
#| echo: true
#| code-fold: true

# Defino una función auxiliar para calcular obs vs pred por cruce de dos variables
calcular_cruce_3 = function(data, var1, var2) {
  data |>
    mutate(
      Cruce = paste0(var1, " × ", var2),
      Categoria = paste(.data[[var1]], "–", .data[[var2]])
    ) |>
    group_by(Cruce, Categoria) |>
    summarise(
      N = n(),
      Respondientes = sum(respuesta_muestra),
      Tasa_obs = mean(respuesta_muestra),
      Tasa_pred = mean(prob_respuesta),
      .groups = "drop"
    ) |>
    mutate(Diferencia = Tasa_obs - Tasa_pred)
}

# Calculo los cruces más relevantes
cruces_nr_3 = bind_rows(
  calcular_cruce_3(df_no_respuesta_3, "Region", "sector"),
  calcular_cruce_3(df_no_respuesta_3, "Region", "ambito"),
  calcular_cruce_3(df_no_respuesta_3, "sector", "jornada_completa"),
  calcular_cruce_3(df_no_respuesta_3, "ambito", "jornada_completa") 
)

# Genero la tabla gt agrupada por cruce
cruces_nr_3 |>
  gt(groupname_col = "Cruce") |>
  tab_header(
    title = "Tasa de respuesta: observada vs predicha por interacciones",
    subtitle = "Cruces de variables no modelados – Tercer año PEB 2025"
  ) |>
  cols_label(
    Categoria = "Categoría",
    Respondientes = "Resp.",
    Tasa_obs = "Tasa Obs.",
    Tasa_pred = "Tasa Pred.",
    Diferencia = "Dif."
  ) |>
  fmt_percent(
    columns = c(Tasa_obs, Tasa_pred, Diferencia),
    decimals = 1
  ) |>
  fmt_integer(columns = c(N, Respondientes)) |>
  tab_style(
    style = cell_text(color = "#c0392b", weight = "bold"),
    locations = cells_body(
      columns = Diferencia,
      rows = abs(Diferencia) > 0.10
    )
  ) |>
  tab_options(
    row_group.background.color = "#f4f4f4",
    table.width = pct(100)
  ) |>
  tab_footnote("Se resaltan en rojo las diferencias mayores a 10 puntos porcentuales.")


## -----------------------------------------------------------------------------
#| label: tbl-impacto_nr_categoricas_3
#| tbl-cap: Proporciones expandidas según tipo de ponderador
#| echo: true
#| code-fold: true

# Preparo un objeto temporal uniendo las variables categóricas del marco muestral
# porque a este punto del documento todavía no están en insumo_calibracion_3
temp_diag_nr_3 = insumo_calibracion_3 |>
  select(clave, weight_design, weight_no_respuesta) |>
  left_join(
    marco_muestra |>
      select(clave, Region, sector, ambito, jornada_completa) |>
      rename(region = Region),
    by = "clave"
  ) |>
  mutate(
    region = as.factor(region),
    sector = as.factor(sector),
    ambito = as.factor(ambito),
    jornada_completa = as.factor(jornada_completa)
  )
# Preparo el dataframe de la muestra seleccionada original (los 673 establecimientos)
# como referencia observada global
temp_diag_original_3 = marco_muestra |>
  filter(muestra_2025 == 1) |>
  select(clave, Region, sector, ambito, jornada_completa) |>
  rename(region = Region) |>
  mutate(
    region = as.factor(region),
    sector = as.factor(sector),
    ambito = as.factor(ambito),
    jornada_completa = as.factor(jornada_completa)
  )

# Creo el diseño muestral con ponderadores de diseño
sv_diag_wd_3 = temp_diag_nr_3 |>
  as_survey_design(ids = 1, weights = weight_design)

# Creo el diseño muestral con ponderadores ajustados por no respuesta
sv_diag_wnr_3 = temp_diag_nr_3 |>
  as_survey_design(ids = 1, weights = weight_no_respuesta)

# Tabla con la muestra seleccionada total observada (referencia original sin ponderar)
tbl_diag_orig_3 = temp_diag_original_3 |>
  tbl_summary(
    include = c(region, sector, ambito, jornada_completa),
    statistic = list(all_categorical() ~ "{p}% (n={n})")
  ) |>
  bold_labels()
# Tabla con weight_design
tbl_diag_wd_3 = sv_diag_wd_3 |>
  tbl_svysummary(
    include = c(region, sector, ambito, jornada_completa),
    statistic = list(all_categorical() ~ "{p}% (n={n_unweighted})")
  ) |>
  bold_labels()

# Tabla con weight_no_respuesta
tbl_diag_wnr_3 = sv_diag_wnr_3 |>
  tbl_svysummary(
    include = c(region, sector, ambito, jornada_completa),
    statistic = list(all_categorical() ~ "{p}% (n={n_unweighted})")
  ) |>
  bold_labels()

# Combino las tres tablas para comparar lado a lado
tbl_impacto_nr_3 = tbl_merge(
  tbls = list(tbl_diag_wd_3, tbl_diag_wnr_3, tbl_diag_orig_3),
  tab_spanner = c("**Peso de diseño**", "**Peso ajustado por NR**", "**Muestra Seleccionada**")
)

tbl_impacto_nr_3


## -----------------------------------------------------------------------------
#| label: totales_discretos_calibracion_marco_muestra_3
#| echo: true
#| code-fold: true
# Antes estba sector pero ahora sector en la interacción con NSE y las ira
calib_marco_muestra_discretos_3 = marco_muestra |>
select(clave, matricula_3, Region, ambito, jornada_completa) |>
rename(region = Region)

df_tot_calib_marco_muestra_discretos_3 = calib_marco_muestra_discretos_3 |>
  # Pivotamos a formato largo (todas son <character>)
  pivot_longer(
    cols = c(ambito, region, jornada_completa),
    names_to = "variable",
    values_to = "categoria"
  ) |>
  # Agrupamos y sumamos la matrícula por celda
  group_by(variable, categoria) |>
  summarise(
     total = sum(matricula_3), 
    .groups = "drop"
  ) |>
  # Nomenclatura estándar para el vector de calibración
  mutate(nombre_parametro = paste0(variable, categoria)) |>
select(nombre_parametro, total)

insumo_calibracion_3 = insumo_calibracion_3 |>
left_join(calib_marco_muestra_discretos_3, by = "clave")



## -----------------------------------------------------------------------------
#| label: totales_continuos_calibracion_marco_muestra_3
#| echo: true
#| code-fold: true
# Calculo una variable, dentro del marco muestra, que indique la proporción de la matricula de 3 ano dentro de la matricula de toda la primaria

calib_marco_muestra_continuos_3 = marco_muestra |>
select(clave, auh_pct, matricula_3) |>
mutate(auh_pct = auh_pct / 100)

df_tot_calib_marco_muestra_continuos_3 = calib_marco_muestra_continuos_3 |>
select(auh_pct, matricula_3) |>
summarise(auh_pct = sum(auh_pct * matricula_3)) |> # Se calcula la masa
  # Sumamos todos los valores ponderados de la población
pivot_longer(cols = everything(), 
             names_to = "nombre_parametro", 
             values_to = "total")  

calib_marco_muestra_continuos_3 = calib_marco_muestra_continuos_3 |>
select(clave, auh_pct)

insumo_calibracion_3 = insumo_calibracion_3 |>
left_join(calib_marco_muestra_continuos_3, by = "clave")


## -----------------------------------------------------------------------------
#| label: totales_continuos_calibracion_censo_peb_3
# Hay que agregar los totales de las notas de las PEB
# Estos totales tienen que representar al total de la población objetivo (no del censo PEB). Tengo que "escalar" la masa utilizando el mismo N que utilizo del marco muestral (o cualquier otro) que se considere como mejor representante de la población objetivo.
# Hay que averiguar si los datos del informe PEB son una media ponderados o no

# Construimos el dataframe directamente con la tabla objetivo publicada
medias_censo_sector_nse = tribble(
  ~sector,   ~NSE,    ~media_ira_mat, ~media_ira_pl,
  "Estatal", "Bajo",  66.4,           68.10,   # Reemplazar PL si tenés la nota publicada de PL
  "Estatal", "Medio", 67.0,           72.08,
  "Estatal", "Alto",  69.7,           75.54,
  "Privado", "Bajo",  68.8,           72.41,
  "Privado", "Medio", 72.0,           76.52,
  "Privado", "Alto",  72.5,           75.93
) |>
  mutate(NSE = factor(NSE, levels = c("Bajo", "Medio", "Alto")))

  
# ==============================================================================
# 2. Matrícula N del marco por celda
# ==============================================================================
matricula_marco_sector_nse = marco_muestra |>
  filter(!is.na(sector), !is.na(NSE)) |>
  group_by(sector, NSE) |>
  summarise(
    n_poblacional_3 = sum(matricula_3, na.rm = TRUE),
    .groups = "drop"
  )
# ==============================================================================
# 3. Construcción del df_tot_calib con los nombres EXACTOS de R model.matrix
# ==============================================================================
df_tot_calib_sector_nse_3 = medias_censo_sector_nse |>
  left_join(matricula_marco_sector_nse, by = c("sector", "NSE")) |>
  mutate(
    total_mat = media_ira_mat * n_poblacional_3,
    total_pl  = media_ira_pl  * n_poblacional_3
  ) |>
  pivot_longer(
    cols = c(total_mat, total_pl),
    names_to = "materia",
    values_to = "total"
  ) |>
  mutate(
    var_continua = if_else(materia == "total_mat", "ira_mat_sec_nse", "ira_pl_sec_nse"),
    # Este formato coincide 1 a 1 con lo que genera model.matrix(~ ... + continua:sector:NSE)
    nombre_parametro = paste0("sector", sector, ":NSE", NSE, ":", var_continua)
  ) |>
  select(nombre_parametro, total)


## -----------------------------------------------------------------------------
#| label: agregacion_ira_muestra_3
# Agrego a la muestra de estudiantes las medias de IRA según sector y NSE
insumo_calibracion_3 = insumo_calibracion_3 |>
group_by(sector, NSE) |>
mutate(
  ira_mat_sec_nse = mean(ira_mat, na.rm = TRUE),
  ira_pl_sec_nse  = mean(ira_pl, na.rm = TRUE)
) |>
ungroup()


## -----------------------------------------------------------------------------
#totales_calibracion = df_totales_unificado_reducido$total
#names(totales_calibracion) = df_totales_unificado_reducido$nombre_parametro
# Las totales de las variables numéricas son más fáciles de agregar a la matrix porque alcanza con sumarlos. En cambio los totales de las variables categóricas es algo más difícil porque hay que hacer los totales para cada categoría. En este sentido, no es lo mismo hacer una calibración para 3 categorías como "Ambito" que para más de 20 como "Región". Al igual que muchas otras funciones (p.e. regresiones) cuando se trabaja con categorías se deja la primera afuera para actúe de intercepto. En este ejemplo Ámbito "Urbano" y Región "1" no están presentes.



## -----------------------------------------------------------------------------
#| label: consolido_totales_3
#| message: false
#| warning: false
#| results: false
#| echo: true
#| code-fold: true

# Unifico todos los totales poblacionales calculados en un único dataframe de referencia
df_totales_unificado_3 = bind_rows(
  tibble(nombre_parametro = "(Intercept)", total = n_poblacion_objetivo_3$matricula_3),
  df_tot_calib_marco_muestra_discretos_3,
  df_tot_calib_marco_muestra_continuos_3,
  df_tot_calib_sector_nse_3
)

# Defino la fórmula que voy a utilizar para calibrar con los promedios de establecimiento
mi_formula = ~ ambito + jornada_completa + region + auh_pct + (sector:NSE):ira_mat_sec_nse + 
               (sector:NSE):ira_pl_sec_nse

# Extraigo la matriz de diseño que R construye para la muestra observada
matriz_muestra = model.matrix(mi_formula, data = insumo_calibracion_3)
nombres_oficiales = colnames(matriz_muestra)


# Construyo el vector de totales haciendo match por el nombre del parámetro.
totales_calibracion_3 = df_totales_unificado_3$total[match(nombres_oficiales, df_totales_unificado_3$nombre_parametro)]
names(totales_calibracion_3) = nombres_oficiales

# Verifico si algún parámetro no encontró su total correspondiente
if (any(is.na(totales_calibracion_3))) {
  warning("Existen parámetros en la matriz de diseño que no tienen total asignado:")
  print(nombres_oficiales[is.na(totales_calibracion_3)])
}

# Defino el tamaño poblacional total para fpc sin renombrar las notas individuales de los alumnos
insumo_calibracion_3 = insumo_calibracion_3 |>
  mutate(fpc = n_poblacion_objetivo_3$matricula_3)

# Areglos de tipo de variables
insumo_calibracion_3 = insumo_calibracion_3 |>
  mutate(sector = as.factor(sector),
         ambito = as.factor(ambito),
         jornada_completa = as.factor(jornada_completa),
         region = as.factor(region))

# Creo el diseño muestral indicando la corrección por no respuesta
insumo_calibracion_3_sv = insumo_calibracion_3 |>
  as_survey_design(ids = id,
                   weights = weight_no_respuesta,
                   fpc = fpc)

# Corro la calibración con el vector de totales ordenado correctamente
muestra_peb_3_cal = calibrate(
  design = insumo_calibracion_3_sv,
  formula = mi_formula,
  population = totales_calibracion_3,
  calfun = "linear",
  bounds = c(0.01, Inf),
  verbose = FALSE
)

# Agrego los ponderadores calibrados
weight_calibrate = weights(muestra_peb_3_cal)


insumo_calibracion_3$weight_calibrate = weight_calibrate


## -----------------------------------------------------------------------------
#| label: tbl-comparacion_calib_poblacion_3
# 1. Creamos el diseño de encuesta para representar a la población objetivo
poblacion_design_3 = marco_muestra |>
  mutate(
    region = as.factor(Region),
    sector = as.factor(sector),
    ambito = as.factor(ambito),
    jornada_completa = as.factor(jornada_completa),
    auh_pct = auh_pct / 100,
    ira_mat = 68.7, # Pag. 7 informe
    ira_pl = 74.5 # Pag. 8 informe
  ) |>
  as_survey_design(ids = 1, weights = matricula_3)

# 2. Tabla para la muestra calibrada (forzando tipo continuo)
tbl_muestra_peb_3_cal_comparacion_mue = muestra_peb_3_cal |>
  tbl_svysummary(  
    include = c(matricula_3, auh_pct, region, sector, ambito, jornada_completa, ira_mat, ira_pl),
    type = list(
      ira_mat ~ "continuous",
      ira_pl ~ "continuous"
    ),
    digits = list(
      all_continuous() ~ c(3, 3), 
      all_categorical() ~ c(1, 0)
    ),
    statistic = list(all_continuous() ~ "{mean} ({mean.std.error})",
                     all_categorical() ~ "{p}% (n={n_unweighted})")
  )

# 3. Tabla para la población (forzando tipo continuo)
tbl_poblacion_peb_3 = poblacion_design_3 |>
  tbl_svysummary(  
    include = c(matricula_3, auh_pct, region, sector, ambito, jornada_completa, ira_mat, ira_pl),
    type = list(
      ira_mat ~ "continuous",
      ira_pl ~ "continuous"
    ),
    digits = list(
      all_continuous() ~ c(3, 3), 
      all_categorical() ~ c(1, 0)
    ),
    statistic = list(all_continuous() ~ "{mean} ({mean.std.error})",
                     all_categorical() ~ "{p}% (n={n_unweighted})")
  )

# 4. Combinación de ambas tablas
tbl_muestra_peb_3_cal_comparacion = tbl_merge(
  tbls = list(tbl_muestra_peb_3_cal_comparacion_mue, tbl_poblacion_peb_3),
  tab_spanner = c("**Muestra Calibrada**", "**Valores Esperados (Población)**")
)

tbl_muestra_peb_3_cal_comparacion


## -----------------------------------------------------------------------------
#| label: chequeos_calidad_calibradores_3
#| message: false
#| warning: false

# 1. Resumen estadístico de los ponderadores
chequeo_pesos_resumen_3 = insumo_calibracion_3 |>
  summarise(
    peso_min              = min(weight_calibrate, na.rm = TRUE),
    peso_max              = max(weight_calibrate, na.rm = TRUE),
    casos_negativos       = sum(weight_calibrate < 0, na.rm = TRUE),
    casos_menores_uno     = sum(weight_calibrate < 1, na.rm = TRUE),
    suma_pesos_diseno     = sum(weight_design, na.rm = TRUE),
    suma_pesos_no_resp    = sum(weight_no_respuesta, na.rm = TRUE),
    suma_pesos_calibrados = sum(weight_calibrate, na.rm = TRUE),
    n_muestra             = n()
  )

# 2. Análisis del ratio (Peso Calibrado / Peso No Respuesta)
insumo_calibracion_3 = insumo_calibracion_3 |>
  mutate(ratio_calib_diseno = weight_calibrate / weight_no_respuesta)

chequeo_ratio_3 = insumo_calibracion_3 |>
  summarise(
    ratio_min = min(ratio_calib_diseno, na.rm = TRUE),
    ratio_p25 = quantile(ratio_calib_diseno, 0.25, na.rm = TRUE),
    ratio_med = median(ratio_calib_diseno, na.rm = TRUE),
    ratio_p75 = quantile(ratio_calib_diseno, 0.75, na.rm = TRUE),
    ratio_max = max(ratio_calib_diseno, na.rm = TRUE),
    ratio_sd  = sd(ratio_calib_diseno, na.rm = TRUE)
  )

# 3. Efecto de diseño de Kish debido a ponderación (Deff_wt)
# n_casos = nrow(insumo_calibracion_3)
# deff_kish = n_casos * sum(insumo_calibracion_3$weight_calibrate^2) / (sum(insumo_calibracion_3$weight_calibrate)^2)

# 4. Creación del dataframe estructurado para la tabla gt
df_calidad_3 = tibble(
  Grupo = c(
    rep("Resumen de Ponderadores", 8), 
    rep("Ratio (Calibrado / No-Respuesta)", 6)
    #, "Efecto de Diseño" # Descomentar cuando se incluya deff_kish
  ),
  Métrica = c(
    "Peso Mínimo", "Peso Máximo", "Casos Negativos (< 0)", "Casos < 1", "Suma de Pesos de Diseño", "Suma de Pesos No-Respuesta", "Suma de Pesos Calibrados", "Tamaño de Muestra (n)",
    "Ratio Mínimo", "Percentil 25 (P25)", "Mediana (P50)", "Percentil 75 (P75)", "Ratio Máximo", "Desviación Estándar (SD)"
    #, "Efecto de diseño por ponderación (Kish Deff_wt)"
  ),
  Valor = c(
    chequeo_pesos_resumen_3$peso_min,
    chequeo_pesos_resumen_3$peso_max,
    chequeo_pesos_resumen_3$casos_negativos,
    chequeo_pesos_resumen_3$casos_menores_uno,
    chequeo_pesos_resumen_3$suma_pesos_diseno,
    chequeo_pesos_resumen_3$suma_pesos_no_resp,
    chequeo_pesos_resumen_3$suma_pesos_calibrados,
    chequeo_pesos_resumen_3$n_muestra,
    chequeo_ratio_3$ratio_min,
    chequeo_ratio_3$ratio_p25,
    chequeo_ratio_3$ratio_med,
    chequeo_ratio_3$ratio_p75,
    chequeo_ratio_3$ratio_max,
    chequeo_ratio_3$ratio_sd
    #, deff_kish
  )
)

# 5. Generación de la tabla gt estética
tbl_calidad_gt_3 = df_calidad_3 |>
  gt(groupname_col = "Grupo") |>
  tab_header(
    title = "Chequeo de Calidad de los Calibradores",
    subtitle = "Métricas del tercer año de primaria PEP 2025"
  ) |>
  fmt_number(
    columns = Valor,
    rows = !(Métrica %in% c("Casos Negativos (< 0)", "Casos < 1", "Tamaño de Muestra (n)")),
    decimals = 3
  ) |>
  fmt_integer(
    columns = Valor,
    rows = Métrica %in% c("Casos Negativos (< 0)", "Casos < 1", "Tamaño de Muestra (n)")
  ) |>
  cols_label(
    Métrica = "Indicador",
    Valor = "Valor"
  ) |>
  tab_options(
    row_group.background.color = "#f4f4f4",
    table.width = pct(100)
  )

tbl_calidad_gt_3


## -----------------------------------------------------------------------------


# 1. Obtenemos los conteos/totales ponderados de la población cruzando sector e ira_mat


df_ira_3 = as_survey(muestra_peb_3_cal) |>
summarize(ira_mat = survey_mean(ira_mat, na.rm = TRUE),
          ira_pl = survey_mean(ira_pl, na.rm = TRUE))

df_NSE_3 = as_survey(muestra_peb_3_cal) |>
group_by(NSE) |>
summarize(ira_mat = survey_mean(ira_mat, na.rm = TRUE),
          ira_pl = survey_mean(ira_pl, na.rm = TRUE))

df_sector_ira_3 = as_survey(muestra_peb_3_cal) |>
group_by(sector) |>
summarize(ira_mat = survey_mean(ira_mat, na.rm = TRUE),
          ira_pl = survey_mean(ira_pl, na.rm = TRUE))

df_NSE_sector_ira_3 = as_survey(muestra_peb_3_cal) |>
group_by(sector, NSE) |>
summarize(ira_mat = survey_mean(ira_mat, na.rm = TRUE),
          ira_pl = survey_mean(ira_pl, na.rm = TRUE))


## -----------------------------------------------------------------------------
#| label: muestra_estudiantes_6
#| echo: true
#| code-fold: true
#Voy a buscar los insumos de la muestra de estudiantes
#Como la muestra vino en .sav (SPSS) uso la libreria haven
muestra_estudiantes_6 = read_sav(here("Inputs", "PEB_2025", "PEB_Primaria_6to año_Carga por estudiante_2025_con variables de contexto.sav")) |>
rename(clave = CLAVE) |>
rename(prioridad_seccion = IM2) |>
rename(turno = IM1) |>
rename(ira_mat = Puntaje_Mate) |>
rename(ira_pl = Puntaje_PL) |>
mutate(anio = 6,
       prioridad_seccion = as_factor(prioridad_seccion))


## -----------------------------------------------------------------------------
#| label: calib_6_pi_1
#| echo: true
#| code-fold: true
prob_seleccion_primera_etapa_6 = marco_muestra |>
select(clave, pi_corregido)

insumo_calibracion_6 = muestra_estudiantes_6 |>
  # Vinculamos la probabilidad preestablecida del cubo por establecimiento y la denominamos pi_1 para indicar que es la probabilidad de inclusión de la primera etapa
  left_join(prob_seleccion_primera_etapa, by = "clave") |>
rename(pi_1 = pi_corregido)



## -----------------------------------------------------------------------------
#| label: calib_6_pi_2
#| echo: true
#| code-fold: true
#Finalmente, la probabilida de selección de cada sección estaba en el objeto "resultado_segunda_etapa"
prob_seleccion_segunda_etapa_6 = resultado_segunda_etapa |>
rename(prioridad_seccion = rol) |>
rename(size_seccion = total) |>
mutate(prioridad_seccion = case_when(
       prioridad_seccion == "Suplente/Complementaria" ~ "Suplente",
      .default = prioridad_seccion
    ),
    azar_desempate = runif(n())) |>
  group_by(clave, anio) |>
  # 2. Calculamos de forma segura la máxima probabilidad de las Reservas por grupo
  mutate(
    max_prob_reserva = if (any(prioridad_seccion == "Reserva")) {
      max(prob_seleccion[prioridad_seccion == "Reserva"], na.rm = TRUE)
    } else {NA_real_}) |>
  # 3. Aplicamos el criterio de selección
filter(
    # Conservamos siempre todos los "Principal" y "Suplente"
    prioridad_seccion %in% c("Principal", "Suplente") |
    # Para las "Reserva", ordenamos los empates y nos quedamos con el primero
    (prioridad_seccion == "Reserva" & prob_seleccion == max_prob_reserva)) |>
     # Este paso lógico asegura conservar solo el registro con el mayor valor de azar entre los empatados
    arrange(prioridad_seccion, 
    desc(prob_seleccion), 
    desc(azar_desempate), .by_group = TRUE) |>
  # 4. Nos quedamos con máximo una fila por cada tipo de prioridad dentro del establecimiento y año
  distinct(clave, anio, prioridad_seccion, .keep_all = TRUE) |>
  ungroup() |>
select(idseccion, clave, anio, prioridad_seccion, prob_seleccion, size_seccion) 

# Como hay establecimientos que tienen más de una opción de "reserva" (aunque siempre 1 de Principal y 1 de Suplente) me quedo solo con la seccion con mas probabilidad de cada establecimiento.

insumo_calibracion_6 = insumo_calibracion_6 |>
# Existe un establecimiento que incluyo una sección que no estaba en la base de secciones. Le imputo la misma pi_2 que la de la seccion presente. Hago lo mismo con el idseccion
mutate(prioridad_seccion = if_else(clave == "0104PP0002", "Principal", prioridad_seccion)) |>
 left_join(prob_seleccion_segunda_etapa, by = join_by(clave, anio, prioridad_seccion)) |>
rename(pi_2 = prob_seleccion)


## -----------------------------------------------------------------------------
#| label: calib_6_pi_3
#| echo: true
#| code-fold: true
insumo_calibracion_6 = insumo_calibracion_6 |>
add_count(clave, anio, idseccion, name = "pik_estudiantes_seccion") |>
mutate(pi_3_diseno = pik_estudiantes_seccion / size_seccion,
       pi_3 = pmin(pi_6_diseno, 1))


## -----------------------------------------------------------------------------
#| label: calib_6_weight_design
#| echo: true
#| code-fold: true
insumo_calibracion_6 = insumo_calibracion_6 |>
  mutate(
    # PROBABILIDAD DE INCLUSIÓN TOTAL (Producto de todas las etapas)
    pi_total_estudiante = pi_1 * pi_2 * pi_3,
    # PESO BASE INICIAL (Recién aquí aplicamos la inversa para la calibración)
    weight_design = 1 / pi_total_estudiante
  )


## -----------------------------------------------------------------------------
#| label: tbl-calib_6_weight_design_test_1
#| tbl-cap: Chequeos de los ponderadores de diseño
#| echo: true
#| code-fold: true
tbl_weight_design_6_test_1 = insumo_calibracion_6 |> 
  summarise(
    casos_totales = n(),
    casos_na      = sum(is.na(weight_design)),
    casos_inf     = sum(is.infinite(weight_design)),
    casos_neg     = sum(weight_design < 1, na.rm = TRUE),
    peso_minimo   = min(weight_design, na.rm = TRUE),
    peso_maximo   = max(weight_design, na.rm = TRUE),
    suma_pesos    = sum(weight_design, na.rm = TRUE)
  ) |>
gt()

tbl_weight_design_6_test_1


## -----------------------------------------------------------------------------
n_poblacion_6 = tb_secciones_2025 |>
  filter(anio == 6) |>
  filter(descripcionofertaeducativa == "Primaria (1° Y 2° ciclo)") |>
  summarise(n_estudiantes_6 = sum(total),
            n_secciones_6 = n_distinct(idseccion, na.rm = TRUE),
            n_establecimientos_6 = n_distinct(clave, na.rm = TRUE))


## -----------------------------------------------------------------------------
#| label: n_poblacion_objetivo_6
#| echo: true
#| code-fold: true
# Hay más de una manera de hacerla. Por un lado está la base de secciones. Esto tiene el beneficio, a pesar de tener algunas secciones sin valor, de poder discriminar el peso de los 3 entre toda la matrícula primaria. Esa proporción es la que se puede utilizar tomando como un mejor indicador de toda la masa de estudiante el dato que sale de la base de establecimientos (marco_muestra)
n_poblacion_6_base_secciones = tb_secciones_2025 |>
filter(anio == 6) |>
filter(descripcionofertaeducativa == "Primaria (1° Y 2° ciclo)") |>
summarise(matricula = sum(total))

n_poblacion_primaria_base_secciones = tb_secciones_2025 |>
filter(descripcionofertaeducativa == "Primaria (1° Y 2° ciclo)") |>
summarise(matricula = sum(total))

ratio_primaria_sextos = n_poblacion_primaria_base_secciones$matricula / 
                          n_poblacion_6_base_secciones$matricula

# Esto estima la matricula_6 de cada establecimiento
marco_muestra = marco_muestra |>
mutate(matricula_6 = matricula_inicial_2025 / ratio_primaria_sextos)

n_poblacion_objetivo_6 = marco_muestra |>
summarise(matricula_6 = sum(matricula_inicial_2025)/ratio_primaria_sextos)

#tot_peb_6 = tibble(
#    ira_mat = 66.7,
#    ira_pl = 73.2
#) |>
#mutate(ira_mat_count = ira_mat * n_poblacion_objetivo_6$matricula_6,
#       ira_pl_count = ira_pl * n_poblacion_objetivo_6$matricula_6)


## -----------------------------------------------------------------------------
#| label: tbl-calib_6_weight_design_test_2
#| tbl-cap: Chequeos descomposición weight_design
tbl_weight_design_6_test_2 = insumo_calibracion_6 |> 
  summarise(
    n_muestra = n(),
    # Evaluamos las probabilidades medias de cada etapa   
    media_pi_1 = mean(pi_1, na.rm = TRUE),
    media_pi_2 = mean(pi_2, na.rm = TRUE),
    media_pi_3 = mean(pi_3, na.rm = TRUE),
    
    # Evaluamos los pesos medios que aporta cada etapa
    peso_medio_etapa1 = mean(1 / pi_1, na.rm = TRUE),
    peso_medio_etapa2 = mean(1 / pi_2, na.rm = TRUE),
    peso_medio_etapa3 = mean(1 / pi_3, na.rm = TRUE)
  ) |>
gt()

tbl_weight_design_6_test_2


## -----------------------------------------------------------------------------
#| label: tbl-calib_6_weight_design_test_3
#| tbl-cap: Distribución de weight_design
tbl_calib_6_weight_design_test_3 = insumo_calibracion_6 |> 
  select(weight_design) |> 
  tbl_summary(
    label = list(weight_design ~ "Factor de Expansión (weight_design)"),
    statistic = list(all_continuous() ~ "{mean} ({sd}) | Mediana: {median} [Min: {min}, Max: {max}]"),
    digits = list(all_continuous() ~ c(2, 2, 2, 2, 2))
  ) |> 
  bold_labels()

tbl_calib_6_weight_design_test_3


## -----------------------------------------------------------------------------
#| label: tbl-calib_6_weight_design_test_4
#| tbl-cap: Media del weight_design según diferentes percentiles
tbl_calib_6_weight_design_test_4 = quantile(insumo_calibracion_6$weight_design, 
         probs = c(0, 0.05, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99, 1), 
         na.rm = TRUE) |>
enframe(name = "Percentil", 
        value = "Valor") |> 
  gt() |> 
  fmt_number(columns = Valor, decimals = 2)

tbl_calib_6_weight_design_test_4


## -----------------------------------------------------------------------------
#| label: no_respuesta_6
df_no_respuesta_6 = marco_muestra |>
filter(muestra_2025 == 1) |>
mutate(respuesta_muestra = clave %in% insumo_calibracion_6$clave,
# Para no crear "grupos" de no respuesta con muy pocos casos (o con ninguno en la muestra) vamos a "agrupar" los tamaños de la matricula y los porcentajes de auh
decil_size = ntile(matricula_inicial_2025, 3),
decil_auh = ntile(auh_pct, 3))

factores = df_no_respuesta_6 |>
  group_by(decil_size, decil_auh, jornada_completa, ambito, Region, sector) |>
  summarise(
    N_total = n(),
    N_respuesta = sum(respuesta_muestra),
    .groups = "drop"
  ) |>
  mutate(no_respuesta_factor = N_total / N_respuesta)


## -----------------------------------------------------------------------------
#| label: tbl-no_respuesta_6_1
#| tbl-cap: Distribución de la no respuesta según características de los establecimientos
# Preparar el dataframe de la muestra seleccionada
analisis_no_respuesta_6 = marco_muestra |>
  filter(muestra_2025 == 1) |>
  mutate(
    # Convertimos a factor con etiquetas claras para la presentación
    Estado_Respuesta = factor(
      clave %in% insumo_calibracion_3$clave,
      levels = c(TRUE, FALSE),
      labels = c("Respondiente", "No Respondiente")
    )
  )

# Generar la tabla descriptiva comparativa
tbl_tabla_comparativa_6 = analisis_no_respuesta_6 |>
  select(Estado_Respuesta, matricula_inicial_2025, auh_pct, Region, sector, jornada_completa, ambito) |>
  tbl_summary(
    by = Estado_Respuesta,
    label = list(
      auh_pct ~ "% Alumnos con AUH"
    ),
    statistic = list(
      all_continuous() ~ "{mean} ({sd}) [Mediana: {median}]",
      all_categorical() ~ "{n} ({p}%)"
    )
  ) |>
# add_p() |> # Agrega p-values para evaluar significancia (t-test, Wilcoxon, Chi-cuadrado)
add_overall(last = TRUE) |>
  bold_labels()

# Visualizar la tabla
tbl_tabla_comparativa_6


## -----------------------------------------------------------------------------
#| label: fig-no_respuesta_6_size
#| fig-cap: Distribución de la no respuesta según tamaño de la matrícula

# Gráfico para la variable Tamaño de establecimiento
fig_no_respuesta_size_6 = analisis_no_respuesta_6 |>
ggplot(aes(x = matricula_inicial_2025, fill = Estado_Respuesta)) +
  geom_density(alpha = 0.5) +
  scale_fill_manual(values = c("#2b8cbe", "#de2d26")) + # Azul y Rojo sobrios
  labs(
    x = "Matrícula (Cantidad de Alumnos)",
    y = "Densidad",
    fill = "Estado"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")
fig_no_respuesta_size_6_i = ggplotly(fig_no_respuesta_size_6)
fig_no_respuesta_size_6_i


## -----------------------------------------------------------------------------
#| label: fig-no_respuesta_6_auh
#| fig-cap: Distribución de la no respuesta según porcentaje de AUH

# Gráfico para la variable Tamaño de establecimiento
fig_no_respuesta_auh_6 = analisis_no_respuesta_6 |>
ggplot(aes(x = auh_pct, fill = Estado_Respuesta)) +
  geom_density(alpha = 0.5) +
  scale_fill_manual(values = c("#2b8cbe", "#de2d26")) + # Azul y Rojo sobrios
  labs(
    x = "% AUH",
    y = "Densidad",
    fill = "Estado"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")
fig_no_respuesta_auh_6_i = ggplotly(fig_no_respuesta_auh_6)
fig_no_respuesta_auh_6_i


## -----------------------------------------------------------------------------
#| label: fig-hist_estudiantes_establecimientos_6
#| fig-cap: Distribución de estudiantes seleccionados por establecimiento
fig_estudiantes_establecimientos_6 = df_exploracion_campo_6 |>
ggplot(aes(x = n_estudiantes_campo)) +
  geom_histogram(binwidth = 2, fill = "forestgreen", color = "white", alpha = 0.8) +
  labs(
    x = "Cantidad de estudiantes seleccionados",
    y = "Frecuencia (Establecimientos)"
  ) +
  theme_minimal()
fig_estudiantes_establecimientos_6


## -----------------------------------------------------------------------------
#| label: tbl-hist_estudiantes_establecimientos_6
#| tbl-cap: Distribución de estudiantes seleccionados por establecimiento
tbl_estudiantes_establecimientos_6 = df_exploracion_campo_6 |>
tbl_summary(
    include = n_estudiantes_campo,
    label = list(n_estudiantes_campo ~ "Estudiantes por establecimiento"),
    statistic = list(all_categorical() ~ "{n} ({p}%)"),
    digits = list(all_categorical() ~ c(0, 1))
  ) |> 
  # Añadimos un encabezado elegante y el total de N (establecimientos)
  modify_header(label = "**Variable**") |> 
  bold_labels()

tbl_estudiantes_establecimientos_6


## -----------------------------------------------------------------------------
#| label: no_respuesta_propensity_score_6
#| echo: true
#| code-fold: true
df_no_respuesta_6 = marco_muestra |>
filter(muestra_2025 == 1) |>
mutate(respuesta_muestra = as.numeric(clave %in% insumo_calibracion_6$clave))

# Nota: tamaño y porcentaje de AUH ingresan como variables continuas
modelo_propension = glm(
  respuesta_muestra ~ matricula_inicial_2025 + auh_pct + Region * sector + jornada_completa * ambito,
  data = df_no_respuesta_6,
  family = binomial(link = "logit")
)

# Obtener las probabilidades predichas para toda la muestra seleccionada
df_no_respuesta_6 = df_no_respuesta_6 |>
  mutate(prob_respuesta = predict(modelo_propension, type = "response"))

# Filtrar los factores para los respondientes y calcular el inverso
factores_modelo_6 = df_no_respuesta_6 |>
  filter(respuesta_muestra == 1) |>
  select(clave, prob_respuesta) |>
  mutate(inv_no_respuesta = 1 / prob_respuesta)

# Aplicar el factor a su base de estudiantes
insumo_calibracion_6 = insumo_calibracion_6 |>
  left_join(factores_modelo_6, by = "clave") |>
  mutate(weight_no_respuesta = weight_design * inv_no_respuesta)


## -----------------------------------------------------------------------------
#| label: tbl-comparacion_pasos_nr_6
#| tbl-cap: Comparación de métricas entre weight_design y weight_no_respuesta
#| echo: true
#| code-fold: true

# Defino el target poblacional como la suma de estudiantes de 3.er año del marco muestral
target_poblacional_6 = n_poblacion_objetivo_6$matricula_6

# Calculo las sumas de ambos ponderadores para usarlas en la tabla
suma_wd  = sum(insumo_calibracion_6$weight_design, na.rm = TRUE)
suma_wnr = sum(insumo_calibracion_6$weight_no_respuesta, na.rm = TRUE)

# Construyo un dataframe con las métricas de resumen para cada ponderador
df_metricas_nr_6 = tibble(
  Indicador = c(
    "Suma de pesos (N estimado)",
    "Media del ponderador",
    "Mediana del ponderador",
    "Desvío estándar",
    "Peso mínimo",
    "Peso máximo",
    "Coeficiente de variación",
    "Target poblacional (N)",
    "Diferencia vs target (%)"
  ),
  peso_diseno_6 = c(
    suma_wd,
    mean(insumo_calibracion_3$weight_design, na.rm = TRUE),
    median(insumo_calibracion_3$weight_design, na.rm = TRUE),
    sd(insumo_calibracion_3$weight_design, na.rm = TRUE),
    min(insumo_calibracion_3$weight_design, na.rm = TRUE),
    max(insumo_calibracion_3$weight_design, na.rm = TRUE),
    sd(insumo_calibracion_3$weight_design, na.rm = TRUE) /
      mean(insumo_calibracion_3$weight_design, na.rm = TRUE),
    target_poblacional_3,
    (suma_wd - target_poblacional_3) / target_poblacional_3 * 100
  ),
  peso_nr_6 = c(
    suma_wnr,
    mean(insumo_calibracion_3$weight_no_respuesta, na.rm = TRUE),
    median(insumo_calibracion_3$weight_no_respuesta, na.rm = TRUE),
    sd(insumo_calibracion_3$weight_no_respuesta, na.rm = TRUE),
    min(insumo_calibracion_3$weight_no_respuesta, na.rm = TRUE),
    max(insumo_calibracion_3$weight_no_respuesta, na.rm = TRUE),
    sd(insumo_calibracion_3$weight_no_respuesta, na.rm = TRUE) /
      mean(insumo_calibracion_3$weight_no_respuesta, na.rm = TRUE),
    target_poblacional_3,
    (suma_wnr - target_poblacional_3) / target_poblacional_3 * 100
  )
)

# Genero la tabla gt con formato
df_metricas_nr_6 |>
  gt() |>
  tab_header(
    title = "Comparación de métricas: weight_design vs weight_no_respuesta",
    subtitle = "Tercer año – PEB 2025"
  ) |>
  cols_label(
    peso_diseno = "Peso de diseño",
    peso_nr = "Peso ajustado por NR"
  ) |>
  fmt_number(
    columns = c(peso_diseno, peso_nr),
    decimals = 2
  ) |>
  tab_style(
    style = cell_fill(color = "#f0f7ff"),
    locations = cells_body(
      rows = Indicador %in% c("Target poblacional (N)", "Diferencia vs target (%)")
    )
  ) |>
  tab_options(table.width = pct(100))


## -----------------------------------------------------------------------------
#| label: tbl-diagnostico_inv_nr
#| tbl-cap: Distribución de la probabilidad de respuesta y del factor de no respuesta
#| echo: true
#| code-fold: true

# Calculo los percentiles clave de la probabilidad de respuesta
# y derivo la inversa de esos mismos valores para que cada fila sea coherente
probs_diag = c(0, 0.05, 0.25, 0.50, 0.75, 0.95, 0.99, 1)

prob_quantiles_6 = quantile(
  insumo_calibracion_6$prob_respuesta,
  probs = probs_diag, na.rm = TRUE
)

df_diagnostico_inv_nr_6 = tibble(
  Percentil = c("Mínimo (P0)", "P5", "P25", "P50 (Mediana)",
                "P75", "P95", "P99", "Máximo (P100)"),
  prob_respuesta = prob_quantiles_6,
  inv_no_respuesta = 1 / prob_quantiles_6
)

# Genero la tabla gt
df_diagnostico_inv_nr_6 |>
  gt() |>
  tab_header(
    title = "Distribución del factor de no respuesta",
    subtitle = "Probabilidad de respuesta y su inversa – Tercer año PEB 2025"
  ) |>
  cols_label(
    prob_respuesta = "Prob. Respuesta",
    inv_no_respuesta = "Inversa (1/prob)"
  ) |>
  fmt_number(
    columns = c(prob_respuesta, inv_no_respuesta),
    decimals = 4
  ) |>
  tab_options(table.width = pct(100))


## -----------------------------------------------------------------------------
#| label: tbl-hosmer_lemeshow_nr_6
#| tbl-cap: Diagnóstico tipo Hosmer-Lemeshow del modelo de propensión
#| echo: true
#| code-fold: true

# Agrupo los establecimientos en deciles según su probabilidad predicha
# y comparo la tasa observada vs predicha dentro de cada grupo
tbl_hl_nr_6 = df_no_respuesta_6 |>
  mutate(decil_prob = ntile(prob_respuesta, 10)) |>
  group_by(decil_prob) |>
  summarise(
    N = n(),
    Respondientes = sum(respuesta_muestra),
    Tasa_obs = mean(respuesta_muestra),
    Tasa_pred = mean(prob_respuesta),
    Prob_min = min(prob_respuesta),
    Prob_max = max(prob_respuesta),
    .groups = "drop"
  ) |>
  mutate(Diferencia = Tasa_obs - Tasa_pred)

# Genero la tabla gt
tbl_hl_nr_6 |>
  gt() |>
  tab_header(
    title = "Diagnóstico de calibración: observado vs predicho por decil",
    subtitle = "Modelo de propensión de respuesta – Tercer año PEB 2025"
  ) |>
  cols_label(
    decil_prob = "Decil",
    Respondientes = "Resp.",
    Tasa_obs = "Tasa Obs.",
    Tasa_pred = "Tasa Pred.",
    Prob_min = "Prob. Mín.",
    Prob_max = "Prob. Máx.",
    Diferencia = "Dif."
  ) |>
  fmt_percent(
    columns = c(Tasa_obs, Tasa_pred, Diferencia, Prob_min, Prob_max),
    decimals = 1
  ) |>
  fmt_integer(columns = c(N, Respondientes)) |>
  tab_options(table.width = pct(100))


## -----------------------------------------------------------------------------
#| label: tbl-cruces_nr_interacciones_6
#| tbl-cap: Tasa de respuesta observada vs predicha por cruces de variables
#| echo: true
#| code-fold: true

# Defino una función auxiliar para calcular obs vs pred por cruce de dos variables
calcular_cruce_6 = function(data, var1, var2) {
  data |>
    mutate(
      Cruce = paste0(var1, " × ", var2),
      Categoria = paste(.data[[var1]], "–", .data[[var2]])
    ) |>
    group_by(Cruce, Categoria) |>
    summarise(
      N = n(),
      Respondientes = sum(respuesta_muestra),
      Tasa_obs = mean(respuesta_muestra),
      Tasa_pred = mean(prob_respuesta),
      .groups = "drop"
    ) |>
    mutate(Diferencia = Tasa_obs - Tasa_pred)
}

# Calculo los cruces más relevantes
cruces_nr_6 = bind_rows(
  calcular_cruce_6(df_no_respuesta_6, "Region", "sector"),
  calcular_cruce_6(df_no_respuesta_6, "Region", "ambito"),
  calcular_cruce_6(df_no_respuesta_6, "sector", "jornada_completa"),
  calcular_cruce_6(df_no_respuesta_6, "ambito", "jornada_completa") 
)

# Genero la tabla gt agrupada por cruce
cruces_nr_6 |>
  gt(groupname_col = "Cruce") |>
  tab_header(
    title = "Tasa de respuesta: observada vs predicha por interacciones",
    subtitle = "Cruces de variables no modelados – Tercer año PEB 2025"
  ) |>
  cols_label(
    Categoria = "Categoría",
    Respondientes = "Resp.",
    Tasa_obs = "Tasa Obs.",
    Tasa_pred = "Tasa Pred.",
    Diferencia = "Dif."
  ) |>
  fmt_percent(
    columns = c(Tasa_obs, Tasa_pred, Diferencia),
    decimals = 1
  ) |>
  fmt_integer(columns = c(N, Respondientes)) |>
  tab_style(
    style = cell_text(color = "#c0392b", weight = "bold"),
    locations = cells_body(
      columns = Diferencia,
      rows = abs(Diferencia) > 0.10
    )
  ) |>
  tab_options(
    row_group.background.color = "#f4f4f4",
    table.width = pct(100)
  ) |>
  tab_footnote("Se resaltan en rojo las diferencias mayores a 10 puntos porcentuales.")


## -----------------------------------------------------------------------------
#| label: tbl-impacto_nr_categoricas_6
#| tbl-cap: Proporciones expandidas según tipo de ponderador
#| echo: true
#| code-fold: true

# Preparo un objeto temporal uniendo las variables categóricas del marco muestral
# porque a este punto del documento todavía no están en insumo_calibracion_3
temp_diag_nr_6 = insumo_calibracion_6 |>
  select(clave, weight_design, weight_no_respuesta) |>
  left_join(
    marco_muestra |>
      select(clave, Region, sector, ambito, jornada_completa) |>
      rename(region = Region),
    by = "clave"
  ) |>
  mutate(
    region = as.factor(region),
    sector = as.factor(sector),
    ambito = as.factor(ambito),
    jornada_completa = as.factor(jornada_completa)
  )
# Preparo el dataframe de la muestra seleccionada original (los 673 establecimientos)
# como referencia observada global
temp_diag_original = marco_muestra |>
  filter(muestra_2025 == 1) |>
  select(clave, Region, sector, ambito, jornada_completa) |>
  rename(region = Region) |>
  mutate(
    region = as.factor(region),
    sector = as.factor(sector),
    ambito = as.factor(ambito),
    jornada_completa = as.factor(jornada_completa)
  )

# Creo el diseño muestral con ponderadores de diseño
sv_diag_wd_6 = temp_diag_nr_6 |>
  as_survey_design(ids = 1, weights = weight_design)

# Creo el diseño muestral con ponderadores ajustados por no respuesta
sv_diag_wnr_6 = temp_diag_nr_6 |>
  as_survey_design(ids = 1, weights = weight_no_respuesta)
# Tabla con la muestra seleccionada total observada (referencia original sin ponderar)
tbl_diag_orig_6 = temp_diag_original_6 |>
  tbl_summary(
    include = c(region, sector, ambito, jornada_completa),
    statistic = list(all_categorical() ~ "{p}% (n={n})")
  ) |>
  bold_labels()
# Tabla con weight_design
tbl_diag_wd_6 = sv_diag_wd_6 |>
  tbl_svysummary(
    include = c(region, sector, ambito, jornada_completa),
    statistic = list(all_categorical() ~ "{p}% (n={n_unweighted})")
  ) |>
  bold_labels()

# Tabla con weight_no_respuesta
tbl_diag_wnr_6 = sv_diag_wnr_6 |>
  tbl_svysummary(
    include = c(region, sector, ambito, jornada_completa),
    statistic = list(all_categorical() ~ "{p}% (n={n_unweighted})")
  ) |>
  bold_labels()

# Combino las tres tablas para comparar lado a lado
tbl_impacto_nr_6 = tbl_merge(
  tbls = list(tbl_diag_wd_6, tbl_diag_wnr_6, tbl_diag_orig_6),
  tab_spanner = c("**Peso de diseño**", "**Peso ajustado por NR**", "**Muestra Seleccionada**")
)

tbl_impacto_nr_6


## -----------------------------------------------------------------------------
#| label: totales_discretos_calibracion_marco_muestra_6
#| echo: true
#| code-fold: true
calib_marco_muestra_discretos_6 = marco_muestra |>
select(clave, matricula_6, Region, ambito, sector, jornada_completa) |>
rename(region = Region)

df_tot_calib_marco_muestra_discretos_6 = calib_marco_muestra_discretos_6 |>
  # Pivotamos a formato largo (todas son <character>)
  pivot_longer(
    cols = c(sector, ambito, region, jornada_completa),
    names_to = "variable",
    values_to = "categoria"
  ) |>
  # Agrupamos y sumamos la matrícula por celda
  group_by(variable, categoria) |>
  summarise(
     total = sum(matricula_), 
    .groups = "drop"
  ) |>
  # Nomenclatura estándar para el vector de calibración
  mutate(nombre_parametro = paste0(variable, categoria)) |>
select(nombre_parametro, total)

insumo_calibracion_6 = insumo_calibracion_6 |>
left_join(calib_marco_muestra_discretos_6, by = "clave")


## -----------------------------------------------------------------------------
#| label: totales_continuos_calibracion_marco_muestra_6
#| echo: true
#| code-fold: true
# Calculo una variable, dentro del marco muestra, que indique la proporción de la matricula de 3 ano dentro de la matricula de toda la primaria

calib_marco_muestra_continuos_6 = marco_muestra |>
select(clave, auh_pct, matricula_6) |>
mutate(auh_pct = auh_pct / 100)

df_tot_calib_marco_muestra_continuos_6 = calib_marco_muestra_continuos_6 |>
select(auh_pct, matricula_6) |>
summarise(auh_pct = sum(auh_pct * matricula_6)) |> # Se calcula la masa
  # Sumamos todos los valores ponderados de la población
pivot_longer(cols = everything(), 
             names_to = "nombre_parametro", 
             values_to = "total")  

calib_marco_muestra_continuos_6 = calib_marco_muestra_continuos_6 |>
select(clave, auh_pct)

insumo_calibracion_36 = insumo_calibracion_6 |>
left_join(calib_marco_muestra_continuos, by = "clave")


## -----------------------------------------------------------------------------
#| label: calib_muestra_estudiantes_6
#| eval: false
# #El objetivo es comenzar a realizar el proceso de calibración sobre el objeto marco_muestra
# muestra_estudiantes_6 = read_sav(here("Inputs", "PEB_2025", "PEB_Primaria_6to año_Carga por estudiante_2025_con variables de contexto.sav")) |>
# rename(clave = CLAVE) |>
# rename(prioridad_seccion = IM2) |>
# rename(turno = IM1) |>
# mutate(anio = 6,
#        prioridad_seccion = as_factor(prioridad_seccion))


## -----------------------------------------------------------------------------
censo_estudiantes_6 = read_xlsx(here("Inputs", "PEB_2025", "PEB2025_Primaria_A6.xlsx"))

# Hago una tabla por establecimiento para agregar ese dato a cada estudiante de la muestra
df_ira_cue_6 = censo_estudiantes_6 |>
mutate(CUE = as.character(CUE)) |>
group_by(CUE) |>
summarise(ira_mat = mean(IRAG_MAT, na.rm = TRUE))

df_tot_ira_mat_6 = censo_estudiantes_6 |>
summarise(ira_mat = mean(IRAG_MAT, na.rm = TRUE),
           ira_pl = mean(IRAG_PL, na.rm = TRUE))


## -----------------------------------------------------------------------------
#| label: consolido_totales_6_propuesta
#| eval: false
#| message: false
#| warning: false
#| results: false
#| echo: true
#| code-fold: true

# # 1. Filtramos el insumo para quedarnos solo con casos que tienen información completa
# # en las variables que utilizaremos para calibrar.
# insumo_calibracion_6_completo = insumo_calibracion_6 |>
#   filter(!is.na(ira_mat), !is.na(ira_pl), !is.na(auh_pct))
# 
# # Unifico todos los totales poblacionales calculados en un único dataframe de referencia
# df_totales_unificado = bind_rows(
#   tibble(nombre_parametro = "(Intercept)", total = n_poblacion_objetivo_3$matricula_3),
#   df_tot_calib_marco_muestra_discretos,
#   df_tot_calib_marco_muestra_continuos,
#   df_tot_ira_mat_peb_3,
#   df_tot_ira_pl_peb_3
# )
# 
# # Defino la fórmula que voy a utilizar para calibrar
# mi_formula = ~ ambito + jornada_completa + region + sector + auh_pct + ira_mat + ira_pl
# 
# # Extraigo la matriz de diseño que R construye para la muestra observada (sin NAs)
# matriz_muestra = model.matrix(mi_formula, data = insumo_calibracion_3_completo)
# nombres_oficiales = colnames(matriz_muestra)
# 
# # Construyo el vector de totales haciendo match por el nombre del parámetro.
# totales_calibracion = df_totales_unificado$total[match(nombres_oficiales, df_totales_unificado$nombre_parametro)]
# names(totales_calibracion) = nombres_oficiales
# 
# # Verifico si algún parámetro no encontró su total correspondiente
# if (any(is.na(totales_calibracion))) {
#   warning("Existen parámetros en la matriz de diseño que no tienen total asignado:")
#   print(nombres_oficiales[is.na(totales_calibracion)])
# }
# 
# # Defino el tamaño poblacional total para fpc en la base filtrada
# insumo_calibracion_3_completo = insumo_calibracion_3_completo |>
#   mutate(fpc = n_poblacion_objetivo_3$matricula_3)
# 
# # Creo el diseño muestral con los casos completos
# insumo_calibracion_3_sv = insumo_calibracion_3_completo |>
#   as_survey_design(ids = id,
#                    weights = weight_no_respuesta,
#                    fpc = fpc)
# 
# # Corro la calibración con el vector de totales ordenado correctamente
# muestra_peb_3_cal_propuesta = calibrate(
#   design = insumo_calibracion_3_sv,
#   formula = mi_formula,
#   population = totales_calibracion,
#   calfun = "linear",
#   verbose = FALSE
# )
# 
# # Evalúo los resultados de la calibración
# tbl_muestra_peb_3_cal_propuesta = muestra_peb_3_cal_propuesta |>
#   tbl_svysummary(
#     include = c(matricula_3, auh_pct, region, sector, ambito, jornada_completa, ira_mat, ira_pl),
#     digits = list(deff = label_style_number(digits = 3),
#                   sd = label_style_number(digits = 3)),
#     statistic = list(all_continuous() ~ "{mean} ({mean.std.error})",
#                      all_categorical() ~ "{p}% (n={n_unweighted})")
#   ) |>
#   add_ci()


## -----------------------------------------------------------------------------
#| eval: false
# # Traigo desde tb_secciones_2025 las matriculas de las secciones de 3 y 6.
# # Esto es importante porque se necesiatn los totales absolutos para la calibracion
# # Luego que traigo esas matricuals uso count y pondero por ese valor de las matriculas
# 
# tot_calib_3 = tot_calib |>
# count(sector, wt = matricula_inicial_2025, name = "sector") |>
# mutate(sector)
# 
# 
# # 1. BASE DE DATOS DE ESTABLECIMIENTOS (Matrícula = Población Objetivo)
# base_establecimientos <- tibble(
#   id_colegio = 1:8,
#   region     = c("Región I", "Región II", "Región III", "Región I", "Región II", "Región III", "Región I", "Región IV"),
#   sector     = c("Público", "Privado", "Público", "Público", "Privado", "Público", "Privado", "Público"),
#   ambito     = c("Urbano", "Urbano", "Rural", "Urbano", "Rural", "Urbano", "Urbano", "Rural"),
#   matricula  = c(450, 120, 800, 310, 150, 620, 90, 400)
# )
# 
# # 2. GENERACIÓN DEL DATAFRAME DE TOTALES DE CONTROL PARA CALIBRACIÓN
# # ------------------------------------------------------------------------------
# totales_control_calibracion = tot_calib |>
#   # Pasamos las variables marginales de interés a un formato largo
#   pivot_longer(
#     cols = c(sector, ambito, region, jornada_completa),
#     names_to = "variable",
#     values_to = "categoria"
#   ) |>
#   # Agrupamos para colapsar los establecimientos en totales de estudiantes
#   group_by(variable, categoria) |>
#   summarise(
#     total_poblacional = sum(matricula_inicial_2025),
#     .groups = "drop"
#   ) |>
#   # Creamos una columna combinada que suele facilitar la asignación del vector
#   mutate(nombre_parametro = paste0(variable, categoria))
# 
# # 2. Total de control para la variable continua (AUH)
# total_continuo_auh <-tot_calib %>%
#   # Multiplicamos el porcentaje por la matrícula para obtener la "masa" de la variable
#   mutate(auh_ponderado = auh_pct * matricula_inicial_2025) %>%
#   # Sumamos todos los valores ponderados de la población
#   summarise(
#     total_poblacional = sum(auh_ponderado, na.rm = TRUE)
#   ) %>%
#   # Asignamos el nombre del parámetro tal como aparece en la matriz de diseño de la muestra
#   mutate(
#     variable         = "auh_pct",
#     categoria        = "continuo",
#     nombre_parametro = "auh_pct"
#   ) %>%
#   select(variable, categoria, total_poblacional, nombre_parametro)
# 
# 
# # 3. VISUALIZACIÓN DEL OBJETO
# print(totales_control_calibracion)
# 
# matricula_clave_3 = tb_secciones_2025 |>
# filter(anio == 3) |>
# filter(descripcionofertaeducativa == "Primaria (1° Y 2° ciclo)") |>
# select(clave, total) |>
# group_by(clave) |>
# summarise(matricula_3 = sum(total))
# 
# marco_muestra = marco_muestra |>
# left_join(matricula_clave_3, by = "clave") |>
# relocate(matricula_3, .after = matricula_inicial_2025)
# 
# # Esas variables hay que incorporarlas a insumo_calibracion
# insumo_calibracion_3 = insumo_calibracion_3 |>
# left_join(tot_calib, by = "clave")
# 
# tot_calib = marco_muestra |>
#   count(sector, wt = matricula, name = "total_estudiantes") %>%
#   mutate(porcentaje = (total_estudiantes / sum(total_estudiantes)) * 100)
# 
# 
# 
# n_poblacion_3$n_estudiantes_3
# 
# 
# 
# # Esas variables hay que incorarlas a insumo_calibration
# 
# 
# # Calculo la cantidad de casos de la población. No de la muestra.
# 
# N = nrow(tot_calib)
# 


## -----------------------------------------------------------------------------
#| eval: false
# totales_calibracion_3 = n_poblacion_3$n_estudiantes_3 # Es el intercepto
# names(totales_calibracion_3) =
# totals = c(
#   tot_calib_marco_muestra_continuos$n_poblacional,
#   tot_calib_marco_muestra_discretos$n_poblacional
# )
# matricula_prop_3 = marco_muestra |>
# summarise(matricula_total = sum(matricula_inicial_2025),
#           matricula_prop_3 = n_poblacion_3$n_estudiantes_3 /matricula_total)
# 
#   tot_peb_3$ira_mat_count,
#   tot_peb_3$ira_pl_count
# totals = unlist(c(nrow(tot_calib),
#            sum(tot_calib$matricula_inicial_2025, na.rm = TRUE),
#            count(tot_calib[tot_calib$ambito == "Rural Disperso", ]),
#            count(tot_calib[tot_calib$ambito == "Rural Agrupado", ]),
#            count(tot_calib[tot_calib$sector == "Privado", ]),
#            count(tot_calib[tot_calib$jornada_completa == "NO", ]),
#            count(tot_calib[tot_calib$region == "02", ]),
#            count(tot_calib[tot_calib$region == "03", ]),
#            count(tot_calib[tot_calib$region == "04", ]),
#            count(tot_calib[tot_calib$region == "05", ]),
#            count(tot_calib[tot_calib$region == "06", ]),
#            count(tot_calib[tot_calib$region == "07", ]),
#            count(tot_calib[tot_calib$region == "08", ]),
#            count(tot_calib[tot_calib$region == "09", ]),
#            count(tot_calib[tot_calib$region == "10", ]),
#            count(tot_calib[tot_calib$region == "11", ]),
#            count(tot_calib[tot_calib$region == "12", ]),
#            count(tot_calib[tot_calib$region == "13", ]),
#            count(tot_calib[tot_calib$region == "14", ]),
#            count(tot_calib[tot_calib$region == "15", ]),
#            count(tot_calib[tot_calib$region == "16", ]),
#            count(tot_calib[tot_calib$region == "17", ]),
#            count(tot_calib[tot_calib$region == "18", ]),
#            count(tot_calib[tot_calib$region == "19", ]),
#            count(tot_calib[tot_calib$region == "20", ]),
#            count(tot_calib[tot_calib$region == "21", ]),
#            count(tot_calib[tot_calib$region == "22", ]),
#            count(tot_calib[tot_calib$region == "23", ]),
#            count(tot_calib[tot_calib$region == "24", ]),
#            count(tot_calib[tot_calib$region == "25", ])))
# 
# totales_estudiantes = c(
# `(intercept)` = n_poblacion_3$n_estudiantes_3,
# `ambito
# 
# )


## -----------------------------------------------------------------------------
# eval: false
# Por ahora el objetivo es visualizar distintos aspectos de la no respuesta. Por ejemplo, indagar en la distribución de la no respuesta. Como regla general (aunque puede ser equivocada) vamos a realizar una serie de gráficos de densidad para ver si la no respuesta se distribuye de manera homogénea. La idea es comparar la media de casos por establecimiento. Dado que por diseño todos los establecimientos deberían tener 10, el alejamiento de ese número podría ser un proxy para indicar la no respuesta. Luego se puede realizar este mismo análisis con diferentes covariables.

chequeos_no_respuesta = insumo_calibracion_3 |>
  group_by(clave) |>
  summarise(
    total_estudiantes = n(),
    total_no_respuesta = sum(is.na(ira_mat) | is.na(ira_pl)),
    proporcion_no_respuesta = total_no_respuesta / total_estudiantes
  ) |>
  ungroup()


