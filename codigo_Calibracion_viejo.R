```{r}
#| eval: false
# Verificamos la estructura (es exactamente idéntica a la salida del summarise)
medias_censo_sector_nse

censo_estudiantes_3 = read_xlsx(here("Inputs", "PEB_2025", "PEB2025_Primaria_A3.xlsx")) |>
clean_names() |>
rename(sector = supervision) |>
mutate(sector = if_else(sector == "GE", "Estatal", "Privado"),
       weight_total = if_else(is.na(estudiantes_mat), estudiantes_pl, estudiantes_mat),
       weight_presentes = if_else(is.na(respondentes_mat), respondentes_pl, respondentes_mat))

# Traigo al censo los valores de AUH desde el marco muestral para sí poder construir el NSE en el censo

tb_claves = tb_establecimientos_primaria_2025 |>
select(clave, cue_num_6, cui_principal) |>
rename(cue = cue_num_6)

levels_NSE = c("Bajo", "Medio", "Alto")

tb_clave_auh = marco_muestra |>
select(clave, auh_pct) |>
mutate(tercil_AUH = ntile(auh_pct, 3), 
       NSE = case_when(
           tercil_AUH == 1 ~ "Alto",
           tercil_AUH == 2 ~ "Medio",
           tercil_AUH == 3 ~ "Bajo")
       ) |>
mutate(NSE = fct_relevel(NSE, levels_NSE))

tb_claves_auh = tb_claves |>
left_join(tb_clave_auh, by = "clave")

censo_estudiantes_3 = censo_estudiantes_3 |>
left_join(tb_claves_auh, by = "cue") 

#censo_estudiantes_3_sv = censo_estudiantes_3 |>
#as_survey_design(ids = 1,
#          weights = weight)

# Estos son los valores a lso que deberían acercarse las medias de los IRA.
# Serían 12 datos en total. 6 por matmetica y 6 por PL.

tbl_ira_mat_sector_NSE = censo_estudiantes_3 |>
tbl_continuous(include = c(sector, NSE, irag_mat),
             by = sector,
             variable = irag_mat,
             statistic = ~ "{mean}",
             digits = everything() ~ 1) |>
add_overall(last = TRUE)
tbl_ira_mat_sector_NSE

df_ira_sector_NSE = censo_estudiantes_3 |>
group_by(sector, NSE) |>
summarise(ira_mat_nse_sector = weighted.mean(irag_mat, weight_presentes, na.rm = TRUE),
          ira_pl_nse_sector = weighted.mean(irag_pl, weight_presentes, na.rm = TRUE))


```

```{r}
#| eval: false
# Definimos df_ira_cue_3 para que esté disponible para el left_join de abajo

df_ira_cue_3 = censo_estudiantes_3 |>
  clean_names() |>
  mutate(cue = as.character(cue)) |>
  group_by(cue) |>
  summarise(
    ira_mat_estab = mean(irag_mat, na.rm = TRUE),
    ira_pl_estab = mean(irag_pl, na.rm = TRUE),
    .groups = "drop"
  )


# Traemos las variables del marco de establecimientos para usar como predictoras
# Vinculamos vía CUE (que obtenemos de tb_establecimientos_2025 usando clave)
df_establecimientos_clave_cue = tb_establecimientos_primaria_2025 |>
  select(clave, cue_num_6, matricula_inicial_2025, secciones_inicial_2025, region, ambito, sector, jornada_completa) |>
  rename(cue = cue_num_6) |>
  mutate(
    cue = as.character(cue),
    region = as.factor(region),
    ambito = as.factor(ambito),
    sector = as.factor(sector),
    jornada_completa = as.factor(jornada_completa),
    relacion_mat_secc = if_else(secciones_inicial_2025 > 0, matricula_inicial_2025 / secciones_inicial_2025, 0)
  )

# Unimos la tabla de notas censales con informacion de la nomina de los establecimientos
insumo_regresion = df_establecimientos_clave_cue |>
  left_join(df_ira_cue_3, by = "cue")

# 1. Imputación de Matemática (ira_mat_estab) usando Lengua y las variables del marco
modelo_mat = lm(
  ira_mat_estab ~ ira_pl_estab + sector + ambito + region + jornada_completa + matricula_inicial_2025 + relacion_mat_secc,
  data = insumo_regresion,
  na.action = na.exclude
)

# 2. Imputación de Lengua (ira_pl_estab) por si hubiera NAs usando Matemática y las variables del marco
modelo_pl = lm(
  ira_pl_estab ~ ira_mat_estab + sector + ambito + region + jornada_completa + matricula_inicial_2025 + relacion_mat_secc,
  data = insumo_regresion,
  na.action = na.exclude
)

# Realizamos las predicciones
pred_mat = predict(modelo_mat, newdata = insumo_regresion)
pred_pl = predict(modelo_pl, newdata = insumo_regresion)

# Reemplazamos los NAs con las predicciones del modelo
output_regresion = insumo_regresion |>
  mutate(
    imputado_mat = is.na(ira_mat_estab) & !is.na(pred_mat),
    ira_mat_estab = if_else(is.na(ira_mat_estab), pred_mat, ira_mat_estab),
    imputado_pl = is.na(ira_pl_estab) & !is.na(pred_pl),
    ira_pl_estab = if_else(is.na(ira_pl_estab), pred_pl, ira_pl_estab)
  )

# Si quedara algún NA remanente (ej. si no hay datos de Lengua tampoco), usamos una imputación simple por la media global del censo
media_global_mat = mean(output_regresion$ira_mat_estab, na.rm = TRUE)
media_global_pl = mean(output_regresion$ira_pl_estab, na.rm = TRUE)

# Construyo los totales poblacionales esperados
# Para que sea consistente con la variable que tiene el estudiante (ira_mat_estab),
# calculamos la media poblacional ponderada por la matrícula estimada de 3er año sobre todo el censo.
df_tot_ira_3 = output_regresion |>
  mutate(matricula_3 = matricula_inicial_2025 / relacion_mat_secc) |>
  summarise(
    ira_mat = sum(ira_mat_estab * matricula_3, na.rm = TRUE) / sum(matricula_3, na.rm = TRUE),
    ira_pl = sum(ira_pl_estab * matricula_3, na.rm = TRUE) / sum(matricula_3, na.rm = TRUE)
  )

df_tot_ira_mat_peb_3 = tibble(
  nombre_parametro = "ira_mat_estab",
  total = df_tot_ira_3$ira_mat * n_poblacion_objetivo_3$matricula_3
)

df_tot_ira_pl_peb_3 = tibble(
  nombre_parametro = "ira_pl_estab",
  total = df_tot_ira_3$ira_pl * n_poblacion_objetivo_3$matricula_3
)

output_regresion = output_regresion |>
  mutate(
    ira_mat_estab = if_else(is.na(ira_mat_estab), media_global_mat, ira_mat_estab),
    ira_pl_estab = if_else(is.na(ira_pl_estab), media_global_pl, ira_pl_estab)
  )

# Limpiamos el dataframe final de promedios por establecimiento para hacer join
df_ira_cue_3_imputado = output_regresion |>
  select(clave, cue, ira_mat_estab, ira_pl_estab)

# Agregamos estos datos imputados a nivel de establecimiento al insumo de calibración
# Usamos 'clave' para asociar directamente con la muestra de estudiantes
insumo_calibracion_3 = insumo_calibracion_3 |>
  left_join(df_ira_cue_3_imputado |> select(clave, cue, ira_mat_estab, ira_pl_estab), by = "clave")

# Totales consistentes calculados arriba
# --- NUEVO ENFOQUE: IMPUTACIÓN PREVIA DE LAS NOTAS INDIVIDUALES ---
# En la muestra de estudiantes (insumo_calibracion_3), si Puntaje_Mate o Puntaje_PL son NA,
# los imputamos con el promedio de su establecimiento (ira_mat_estab o ira_pl_estab)
insumo_calibracion_3 = insumo_calibracion_3 |>
  mutate(
    ira_mat = if_else(is.na(ira_mat), ira_mat_estab, ira_mat),
    ira_pl = if_else(is.na(ira_pl), ira_pl_estab, ira_pl)
  ) |>
relocate(ira_mat_estab, .after = "ira_mat") |>
relocate(ira_pl_estab, .after = "ira_pl")

# Construyo los totales poblacionales esperados consistentes directamente del censo
# Como la calibración se hará sobre las notas individuales de los alumnos (ira_mat, ira_pl),
# el total poblacional es la media del censo ponderada por la cantidad de respondientes que efectivamente rindieron cada prueba.
df_tot_ira_3 = censo_estudiantes_3 |>
  summarise(
    ira_mat = weighted.mean(IRAG_MAT, w = Respondentes_MAT, na.rm = TRUE),
    ira_pl = weighted.mean(IRAG_PL, w = Respondentes_PL, na.rm = TRUE)
  )

df_tot_ira_mat_peb_3 = tibble(
  nombre_parametro = "ira_mat",
  total = df_tot_ira_3$ira_mat * n_poblacion_objetivo_3$matricula_3
)

df_tot_ira_pl_peb_3 = tibble(
  nombre_parametro = "ira_pl",
  total = df_tot_ira_3$ira_pl * n_poblacion_objetivo_3$matricula_3
)
```

```{r}
#| eval: false
# Media censal de las IRA ponderador por el tamaño del establecimiento

df_ira_censales_3 = censo_estudiantes_3 |>
summarise(
    # Media ponderada por el peso muestral o la matrícula
    ira_mat_ponderado = weighted.mean(IRAG_MAT, w = Estudiantes_MAT, na.rm = TRUE),
    ira_mat_sin_ponderar = mean(IRAG_MAT, na.rm = TRUE),
    ira_pl_ponderado = weighted.mean(IRAG_PL, w = Estudiantes_PL, na.rm = TRUE),
    ira_pl_sin_ponderar = mean(IRAG_PL, na.rm = TRUE)
     )


df_ira_censales_sector_3 = censo_estudiantes_3 |>
group_by(Supervision) |>
summarise(
    # Media ponderada por el peso muestral o la matrícula
    ira_mat_ponderado = weighted.mean(IRAG_MAT, w = Estudiantes_MAT, na.rm = TRUE),
    ira_mat_sin_ponderar = mean(IRAG_MAT, na.rm = TRUE),
    ira_pl_ponderado = weighted.mean(IRAG_PL, w = Estudiantes_PL, na.rm = TRUE),
    ira_pl_sin_ponderar = mean(IRAG_PL, na.rm = TRUE)
     )

# Hago una tabla por establecimiento para agregar ese dato a cada estudiante de la muestra
df_ira_cue_3 = censo_estudiantes_3 |>
  clean_names() |>
  mutate(cue = as.character(cue)) |>
  group_by(cue) |>
  summarise(
    ira_mat_estab = mean(irag_mat, na.rm = TRUE),
    ira_pl_estab = mean(irag_pl, na.rm = TRUE),
    .groups = "drop"
  )
```
```{r}
#| label: tbl-tot_peb_3_xestab
#| tbl-cap: Totales de las IRA por establecimiento

tbl_ira_cue_3 = df_ira_cue_3 |>
pivot_longer(
    cols = c(ira_mat_estab, ira_pl_estab),
    names_to = "indicador",
    values_to = "valor"
  ) |>
  group_by(indicador) |>
  summarise(
    total_cue = n(),
    casos_validos = sum(!is.na(valor)),
    casos_na = sum(is.na(valor)),
    pct_na = (casos_na / total_cue) * 100
  ) |>
gt()

tbl_ira_cue_3
```