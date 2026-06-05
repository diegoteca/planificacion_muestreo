// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "a4",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [Taller Muestreo],
  author: "Recursos Didácticos y Tecnológicos para la Enseñanza",
  date: "1 de junio de 2026",
  lang: "es",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
  list-of-figure-title: "Índice de figuras",
  list-of-table-title: "Índice de tablas",
  supplement-chapter: "Cap.",
)


// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

= Introducción
<sec-introduccion>
En este curso/taller vamos a ir interactuando entre algo de teoría, algo de datos y algo de código. Generalmente, vamos a trabajar con un solo insumo empírico que es una base de datos de establecimientos educativos de nivel primario de gestión estatal de la provincia de Buenos Aires. Con este insumo en una primera instancia nos vamos a focalizar en una serie de #emph[diseños] clásicos de muestreo y en la construcción de ponderadores. En una segunda instancia vamos a ver diseños que implican:

a) Alguna combinación en más de un paso de estos diseños clásicos (muestras complejas) o

b) diseños de un solo paso cuyos supuestos o modo de proceder son algo diferentes al de los clásicos (p.e. diseños balanceados y bien distribuidos).

Finalmente, se verán algunas estrategias de calibración que, en principio, al ser instancias post-diseños, pueden ser aplicadas/combinadas con cualquiera de los anteriores diseños.

El código con que vamos a procesar los datos a lo largo del taller va a ser en lenguaje R. R es un lenguaje de programación que parece una opción razonable tanto para el diseño de la muestra como su posterior calibración y análisis de los datos. Si bien diseños de métodos de muestreo relativamente simples son posibles de realizarse en varios otros lenguajes la situación se complica un poco a medida que se quieren utilizar, y luego analizar, diseños más complejos. En esta última situación, ya no es posible conseguir librerías especializadas en muchos lenguajes aparte de R, Python, Julia y SAS.

Dentro del ecosistema de R, ejemplos de librerías para analizar datos producidos con diseños muestrales pueden considerarse #link("https://r-survey.r-forge.r-project.org/survey/")[survey], #link("https://bschneidr.github.io/svrep/")[svrep] y su correspondiente versión tidy #link("http://gdfe.co/srvyr/")[srvyr]. Estas librerías generalmente agregan meta-información al dataframe original que hace referencia al modo o diseño en que fue realizada la muestra. Esta información luego es utilizada para realizar estimaciones puntuales con sus respectivos errores estandard, intervalos de confianza o coeficientes de variación. La librería survey es una librería madura mantenida principalmente por #link("https://en.wikipedia.org/wiki/Thomas_Lumley_(statistician)")[Thomas Lumley] (un personaje conocido dentro de la comunidad estadística en general y en la en R en particular). La librería srvyr puede considerarse como su sucesora más moderna, aunque como lo destacan sus propios autores, se trata de una librería más amigable para el usuario en donde la mayoría del trabajo sucio lo sigue haciendo por detrás la librería survey. Algo similar resulta entre la relación entre survey y svrep ya que esta última se puede considerar una extensión de la primera para el cálculo de ponderadores replicados (#emph[replicate weights]). Algo importante a destacar es la compatibilidad entre las 3 librerías y que, a pesar de la diferencia generacional (Lumley es el mayor) existe una relación afectuosa entre los diferentes autores. En efecto, #link("https://github.com/bschneidr")[Ben Schneider], el creador de la librería svrep, es un asiduo contribuidor de los 3 paquetes antes nombrados.#footnote[Más adelante veremos que indagar sobre la precisión de la estimación es posible pero difícil en las muestras realizadas con el método del cubo. Por esta razón, si bien es posible comparar la precisión de estas muestras contra, por ejemplo, el muestreo por azar simple, acá esto se tomará como un supuesto y se remite al lector a fuentes en donde se prueba lo anterior \[#cite(<brus2022>, form: "prose"), cap. 9\]@schneider2024. El principal problema es que, por ahora, las librerías de análisis de datos de encuestas (p.e. #emph[survey]) todavía no tienen el instrumental adecuado para especificar este tipo de diseños y, por lo tanto, para calcular la precisión de sus estimaciones.]

Ejemplos de librerías que sirven para el diseño de las muestras y su posterior ajuste son #link("https://cran.r-project.org/web/packages/sampling/index.html")[sampling], #link("https://envisim.se/balancedsampling")[balanced sampling] y #link("https://cran.r-project.org/web/packages/Spbsampling/index.html")[spbsampling]. Al igual que con las librerías anteriores, aquí también existe relación entre los diferentes autores. La librería sampling es una librería madura creada bajo la tutela de Yver Tillé, que es otro personaje bastante conocido tanto en el mundo de la estadística académica como dentro de los organismos oficiales de estadística de diferentes países. La librería balanced sampling hace mucho de las funciones que la librería sampling, pero es más moderna (corre en C#super[\++]) y es mantenida por #link("https://scholar.google.com/citations?user=JkMAOUEAAAAJ&hl=sv")[Anton Grafstrom] que ha escrito con Tillé. Por otro lado, la librería spbsampling se especializa en muestreos espaciales (balanced sampling también tiene funciones para eso), se ejecuta en C#super[\++] y es mantenida por #link("https://scholar.google.com/citations?user=h_Rnt4kAAAAJ&hl=it")[Roberto Benedetti]. Tanto Benedetti como Grafstrom se reconocen entre ellos y algo interesante es que si, bien ambos han trabajado con institutos oficiales de estadística, ambos se especializan en organismos de agricultura. De ahí que ambos muestren interés en la dimensión espacial de los diseños muestrales porque esta es útil a la hora de, por ejemplo, diseñar una buena muestra de la vegetación de un bosque.#footnote[El ejemplo y el respectivo código fue adaptado del libro "Spatial sampling with R" @brus2022.]

Por último, para el cálculo de los tamaños muestrales con diferentes diseños (y otras yerbas) puede consultarse la librería #link("https://cran.r-project.org/web/packages/PracTools/index.html")[PracTools]. No se trata de una libraría muy sofisticada como algunas de las anteriores pero se trata de una librería útil y relativamente bien documentada. Un dato no menor es que uno de sus autores es #link("https://scholar.google.com/citations?user=6Q5RKeAAAAAJ&hl=en")[Richard Valliant] que, a su turno, es uno de los mayores exponentes de un enfoque importante dentro del mundo del muestreo como es el "#emph[Model Assisted Sampling]". #footnote[En este sentido, más que nada por razones pedagógicas, aquí se han elegido como covariables, un conjunto de variables con poco margen de no respuesta. Esto se debe a que, si se hubieran escogido covariables con una alta tasa de no respuesta, se presenta el problema de contra que conjunto de datos testear las bondades de la técnica del balanceo. Esto es así dado que si los resultados de la técnica del cubo se comparan contra los totales poblacionales de los colegios (#ref(<tbl-parametros_base>, supplement: [Tabla])) es esperable que los resultados vayan a ser diferentes porque, estrictamente, el balanceo se realiza solo sobre los establecimientos que tienen la información auxiliar pertinente. Lo mismo, #emph[mutatis mutandis], si se compara la técnica del balanceo con la respectiva muestra de azar simple de toda la población de colegios (#ref(<tbl-azar_simple>, supplement: [Tabla])).]

== Librerías utilizadas
<librerías-utilizadas>
Abajo hay un código para instalar y cargar las librerías que vamos a utilizar. El código se encarga de cargar las librerías y de instalar las mismas en el caso de que no se encuentren previamente instaladas. Esto es específicamente para R y la parte muestral.

La sección de las aplicaciones prácticas, principalmente por cuestiones de confidencialidad, no son reproducibles. Por otro lado, algunos #emph[chunks] incuyen código de Pyhton.

#part[Diseños muestrales]
= Cuándo y por qué hacer muestras
<cuándo-y-por-qué-hacer-muestras>
Una muestra es una parte de un todo. En los muestreos que aspiran a ser (en algún grado) representativos lo que se intenta lograr es que esa parte que se seleccione no sea muy diferente al todo o, como decían los romanos, que sea legítimo tomar una parte como el todo (#emph[pars pro toto]). En este sentido, lo que vamos a hablar aquí sobre muestreo tiene mayor pertinencia cuando en la investigación se intenta maximizar la #strong[representatividad], pero por alguna razón no es posible o conveniente la realización de un censo de todas las partes que conforman ese todo. Por otro lado, diseñar muestras también puede ser importante cuando se necesitan construir grupos de tratamiento y control en diseños experimentales, especialmente en los diseños experimentales aleatorios @kish1987. En efecto, la vinculación entre la bibliografía de los diseños muestrales y los diseños experimentales suele ser útil si se aspira a entender las razones (y no solo saber ejecutarlas en la práctica) de algunas recomendaciones metodológicas, ya que muchos de los conceptos más abstractos son compartidos por ambas \[#cite(<hedlin2015>, form: "prose")\]@fienberg1988.

#block[
#callout(
body: 
[
Las muestras que aspiran a ser representativas intentan captar la heterogeneidad de una determinada población para poder hablar legítimamente del todo a través de solo una parte.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
En algunas situaciones, más usuales en las ciencias naturales, la representatividad a veces se logra sin un mayor esfuerzo por parte del investigador por lo que no suele ser explícitamente un objetivo de la investigación sino un supuesto más o menos implícito a lo largo de ella. En otras palabras, la hipótesis de la homogeneidad forma parte del modelo mediante el cual se intenta aprendeder de la realidad. Entender la razón de esto último puede ayudar a hacer más transparente alguna especificidad de las ciencias sociales en este punto. En efecto, muchos investigadores consideran que en los niveles más bajos de la realidad (p.e. niveles estudiados por la física y la química) existe una mayor homogeneidad de los referentes básicos que estudian esas disciplinas. En cambio, en los niveles más superiores (p.e. niveles estudiados por ejemplo por la psicología y las ciencias sociales) la variabilidad inherentes de los referentes estudiados hace que sea necesario prestar especial atención al problema de la representatividad, En este sentido, el investigador suele realizar acciones específicas para poder captar la heterogeneidad que surge a nivel poblacional debido a la variabilidad individual de los referentes estudiados y, en ese camino, suele venir en ayuda el diseño muestral.

De manera derivada, lo anterior es una de las razones por lo cual el método experimental ha sido bastante exitoso en la historia de las ciencias naturales, ya que con unos pocos experimentos sus resultados se pueden inferir a su respectiva #strong[población] empírica actual. No solo eso. Muchas veces también se puede inferir a lo que a veces se denomina su #strong[universo] que estaría compuesto no solo por la población actual sino también por la clase de esas poblaciones pasadas y futuras. Este tipo de problemáticas son conocidas por diferentes disciplinas. Desde la epistemología a veces se los relaciona con el problema de los universales @klima2022 y desde la metodología se lo relaciona con el problema de la #strong[validez externa] de las investigaciones @campbell1963. \
\
A modo de ejemplo, un físico que investiga el impacto del calor en el átomo de carbono puede tener una razonable confianza que el átomo de carbono que está hoy estudiando no solo es muy similar a los otros átomos de carbono actuales en la Tierra (población) sino que también es similar a los pasados y los futuros átomos de carbono (universo). También puede tener confianza que los átomos de carbono encontrados en la Tierra son similares a los existentes en el resto del universo. En el otro extremo, este tipo de suposiciones en general son difíciles de mantener en el nivel social.

Estas diferencias en cuanto a la validez externa no son tan marcadas cuanto se analiza la dimensión de la #strong[validez interna] de las investigaciones. En la jerga de la bibliografía de los diseños de investigación se suele afirmar que en todas las investigaciones que se quiera realizar inferencias causales, independientemente si se trata de investigaciones físicas o sociales, el investigador se debe asegurar, en la fase de diseño de la investigación, de controlar o aleatorizar el conjunto de factores extraños que le sugiera/n la o las teorías utilizadas. Esto es lo que precisamente le asegurará que aquellos factores extraños no sigan existiendo como factores perturbadores que puedan invalidar las inferencias internas o locales en el momento de las conclusiones @kish1987. En el último tiempo la visión anterior se ha expandido aún más permitiendo mayor seguridad en diseños observacionales en situaciones en donde no es posible un diseño experimental aleatorio lo que es sumamente importante en el dominio de las ciencias sociales @pearl2018a@morgan2015.

Dada la introducción anterior, ahora estamos en condiciones de expresar lo mismo pero en términos más simples:

#block[
#callout(
body: 
[
Donde no hay heterogeneidad con seguridad no hay problemas de representatividad. Si hay heterogeneidad, y el investigador no realiza acciones en su diseño para incluir esa heterogeneidad en su investigación, la misma sufrirá de un problema de representatividad que derivará en un problema de #strong[validez externa].

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
== ¿Muestras de qué?
<muestras-de-qué>
\
Un primer paso importante cuando uno se preocupa por la representatividad es entender sobre qué población de referentes y de unidades de observación/experimentación uno va a querer predicar sus inferencias. Para eso hay que analizar:~ \
\
a) La clase de referencia de los conceptos utilizados que nos dirá el/los tipo/s de referente/s a investigar (individuos, organizaciones, etc.). Esto a veces se suele denominar #strong[universo] o dominio de la teoría @bunge1974a.

b) Los objetivos de la investigación que nos indicaran, entre otras cuestiones, el alcance (usualmente especificando tiempo y espacio) de los referentes anteriores junto con otras características pertinentes de cada unidad de observación/experimentación. Usualmente los objetivos remiten a una población empírica que podrá grande o pequeña, homogénea o heterogénea, dispersa o aglomerada, etc.~ \
\
Dentro del muestreo al conjunto formado por todos los objetos reales que cumplan las condiciones de los puntos "a" y "b" se lo denomina #strong[población]#footnote[Expresado en términos de propiedades generales y específicas podría afirmarse que las~#strong[propiedades generales], como su nombre lo indica, sirven para construir #strong[géneros] y todos los objetos reales que pertenecen a ese género tienen el mismo valor en todas sus propiedades generales. Ejemplo: Todo objeto real que se clasifique como "persona" deberá cumplir una serie de propiedades generales que hacen a la esencia de "persona" y se incluyen en su definición. Ser estudiante o residir en la provincia de Buenos Aires no pertenece a un valor de una propiedad general de las personas. En cambio, mamífero descendiente del mono, sí. Las propiedades generales son necesarias para identificar la clase de referencia, pero no suficientes para construir la población sobre la cual se realizará la muestra.~

Las~#strong[propiedades específicas,] también como su nombre lo sugiere#strong[,]~sirven para construir #strong[especies de los géneros] en función de los diferentes valores en las propiedades específicas. Tiempo y espacio son típicas propiedades específicas que ayudan recortar al universo anterior delimitando una población empírica. Luego pueden existir otras propiedades específicas (como las anteriores de ser estudiante o vivir en Buenos Aires) que sirven para seguir delimitando aún más nuestra población.].~En nuestra vida cotidiana, aunque sea solo por vivir en un tiempo y espacio determinado (y aun si somos investigadores de profesión) usualmente solo tenemos posibilidad de acceso empírico a un subconjunto de aquella población. Para empeorar las cosas, en las ciencias sociales muchas poblaciones son muy numerosas, heterogéneas y/u otras se encuentran muy separadas espacialmente lo que dificulta y hace costoso llegar a cada una de las partes de aquellas. En el extremo, a veces el investigador tiene el problema adicional de trabajar con poblaciones "invisibles" de las que se sabe o se presupone que existen, pero no se tienen datos agregados de ella y/o es sumamente difícil identificar/contactar a miembros de ella.~Ante esta situación el investigador tiene 2 grandes opciones:

a) Se ajustan los objetivos de la investigación, especialmente en lo tocante al grado de alcance o generalidad de la investigación, hasta un punto que efectivamente la definición de la unidad de análisis construya una población en la que se pueda abordable empíricamente a cada una de las unidades que la componen y/o

b) Se realiza una~#strong[muestra]~de aquella población.

En este sentido, en este taller se le prestará atención a las estrategias tipo ‘b' como un modo de conocer el todo a través de solo una parte de aquel. Más adelante también veremos que hay estrategias más eficientes que otras para con ‘poco' inferir ‘bastante', aun cuando, en muchos casos, no se sepa a ciencia cierta si ese ‘bastante' es ‘suficiente'. En otras palabras, se verán las distintas características de diferentes diseños muestrales que aspiran a algún grado de representatividad con el objetivo de comprender cuál de ellos puede ser más idóneo en función de los objetivos, el presupuesto y los datos disponibles en cada caso.~ \
\
Existen varios criterios para clasificar a las muestras. Siguiendo una clasificación clásica @neyman1934, todos los que se basan en algún modo en la aleatoriedad (#emph[random]), ponen el acento en el #strong[proceso] de la muestra y se las puede clasificar como #strong[muestras probabilísticas]. Otros, como todos los que se basan en cuotas ponen más acento en las acciones y chequeos basados en las intenciones (#emph[purposive]) del~#strong[resultado o producto final.] Aquí, más que usar el término de muestras intencionales de Neyman vamos a preferir el más amplio de muestras no probabilísticas, ya que también engloba a otros diseños que tienen la similitud, al menos a primera vista, de no ser probabilísticos @baker2013. Ejemplos pueden considerarse las muestras basadas en el criterio de saturación y la heterogeneidad observada, los muestreos por conveniencia, los muestreos por matcheo (en donde las cuotas de Neyman serían un ejemplo), los muestreos basados en redes, usuales para el estudio de poblaciones invisibles (en donde el bola de nieve o snowball sería un ejemplo).

Finalmente en el último tiempo, y en parte por el avance de una mayor disponibilidad de información secundaria, cada vez existen más métodos que permiten incorporar esa mayor información secundaria como información auxiliar (#emph[auxiliary information]) tanto en el diseño de la muestra como en el posterior ajuste de los estimadores de la misma. Este último proceso en particular se suele denominar calibración. Ambos usos de la información secundaria (tanto si se usan para el diseño #emph[ex-ante] o para el ajuste de los estimadores #emph[ex-post]) son ejemplos de diseños muestrales asistidos por modelos que derivan de información secundaria (#emph[model assisted]).

En el útimo párrafo, casi al pasar, se ha comentado que "en el último tiempo" ha habido cambios en el mundo del muestreo. Más allá que se pueda afirmar que en algunos momentos haya habido más cambios que otros, la historia de la incorporación de las diferentes teorías de muestreo en la estadística como disciplina (antes dominada por aplicaciones sobre poblaciones enteras o censos) o en el diseño de investigaciones (antes dominada por diseños experimentales) es sumamente interesante y recomendable @hacking2004@hacking2006@gigerenzer1997.

= La domesticación del azar como medio para lograr muestras (aproximadamente) representativas
<la-domesticación-del-azar-como-medio-para-lograr-muestras-aproximadamente-representativas>
Si ser muy profundos en cuanto a la teoría del muestreo o en cuanto a su justificación más académica en lo que sigue se intenta recordar que sucede si se realizan muestras aleatorias dentro de una población. Este enfoque tiene mucho que ver con lo que se suele denominar “#emph[Design Based Sample”] en la literatura sobre muestreo#emph[.] Básicamente, en línea con la clasificación de Neyman anteriormente utilizada, son muestras que ponen énfasis en el proceso aleatorio de la selección de los casos. Es una escuela clásica dentro del muestreo y tiene muchas subvariantes. Algunas de ellas las veremos más adelante pero ahora nos concentraremos en la parte que tienen en común toda ellas. Para eso vamos a simular que hacemos muchas muestras aleatorias simples sobre una población imaginaria no muy grande (\<2000). Primero haremos, o más bien repetiremos, muestras relativamente pequeñas y luego haremos muestras algo más grandes.

Para tener una mejor experiencia de este simulador es aconsejable su ejecución a través de este #link("https://planificacion-muestreo.netlify.app/simulador_teorema_limite_central.html")[link].

Con este programa podemos jugar de varias formas. Aquí nos interesa las siguientes.

+ En primer lugar ver que pasa, en los términos de la figura "datos acumulativos de las muestras" cuando realizamos muchas muestras sobre una misma población (p.e. Población = "Opción 3"). Como veremos, estas distribuciones, en especial si la muestra contiene más de 30 casos, converge hacia un patrón de distribución "normal". Lo interesante es que esta distribución emerge, con mayor o menor rapidez, de manera independiente de la forma de la población (Ver punto 2). También se puede probar escogiendo diferentes tamaños de las muestras (p.e. Tamaño de la muestra = 30 y 200).

+ Por otro lado se puede probar que sucede si, se hace el ejercicio anterior en diferentes poblaciones (p.e. con Población = "Opción 6"). Como se observará siempre se obtiene una distribución "normal" aunque en mayor tiempo y con una mayor varianza.

== Población
<población>
Como se anticipó en la introducción, nuestra #strong[población] será una población de establecimientos educativos de gestión estatal de nivel primario. Cada uno de los integrantes de esta población se pueden considerar como #strong[unidades de selección], el subconjunto finalmente seleccionado será la #strong[muestra] y la cantidad de los miembros seleccionados será el #strong[tamaño de la muestra]. En este caso, como se observa en #ref(<tbl-escuelas>, supplement: [Tabla]), se tiene información variada sobre cada una de las escuelas. Como veremos más adelante, tener más información sobre las unidades de selección puede ayudar para la efectiva realización de diferentes diseños muestrales. Algunos de esos diseños servirán cuando el objetivo sea tener una muestra de escuelas (muestreos de una sola etapa) y otros, generalmente más complejos, podrán servir como un primer paso para luego realizar una muestra a estudiantes, directivos, etc. (muestreos polietápicos).

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 53,
  align: (left,center,left,left,center,right,right,right,right,left,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); clave], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); region], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); nombre\_distrito], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); localidad], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ambito], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); cueanexo], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); matricula], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); secciones], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); matri\_seccion], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); jornada], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); porc\_auh\_2023], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); indice\_de\_vulnerabilidad], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); prueba2\_23\_pd\_l\_a3\_irdg], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); prueba2\_23\_pd\_l\_a4\_irdg], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); prueba2\_23\_pd\_l\_a6\_irdg], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); prueba2\_23\_mat\_a3\_irdg], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); prueba2\_23\_mat\_a4\_irdg], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); prueba2\_23\_mat\_a6\_irdg], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); prueba1\_23\_pd\_l\_a3\_irdg], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); prueba1\_23\_pd\_l\_a6\_irdg], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); prueba1\_23\_mat\_a3\_irdg], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); prueba1\_23\_mat\_a6\_irdg], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); sondeo\_primero], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); sondeo\_segundo], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); indice\_presencialidad\_total], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); indice\_presencialidad\_marzo], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); indice\_presencialidad\_abril], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); indice\_presencialidad\_mayo], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); indice\_presencialidad\_junio], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); indice\_presencialidad\_julio], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); indice\_presencialidad\_agosto], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); direct\_con\_0\_y\_1\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); direct\_con\_2\_y\_3\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); direct\_con\_4\_a\_6\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); direct\_con\_7\_a\_9\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); direct\_con\_10\_y\_11\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); direct\_con\_12\_a\_14\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); direct\_con\_15\_y\_16\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); direct\_con\_17\_a\_19\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); direct\_con\_20\_y\_21\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); direct\_con\_22\_y\_23\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); direct\_con\_24\_anos\_o\_mas], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); mg\_con\_0\_y\_1\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); mg\_con\_2\_y\_3\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); mg\_con\_4\_a\_6\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); mg\_con\_7\_a\_9\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); mg\_con\_10\_y\_11\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); mg\_con\_12\_a\_14\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); mg\_con\_15\_y\_16\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); mg\_con\_17\_a\_19\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); mg\_con\_20\_y\_21\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); mg\_con\_22\_y\_23\_anos], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); mg\_con\_24\_anos\_o\_mas],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0001PP0001], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[01], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[La Plata], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[LA PLATA], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[060882200], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[678], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[24], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[28.25000], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[JS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[43.72414], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.1294078], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69.44444], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[79.11504], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[75.70146], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[63.16872], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[62.00935], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[78.61635], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[68.79167], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[52.70270], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[55.16055], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[81.460177], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[60.74747], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[76.80882], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9366830], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9057018], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9166667], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9090909], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.941176470588235], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[100], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11.111111], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7.407407], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.81481], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.814815], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.814815], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7.407407], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.703704], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.703704], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7.407407], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7.407407], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7.407407],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0001PP0002], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[01], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[La Plata], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[LA PLATA], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[060881800], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[424], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[30.28571], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[JC], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[44.71744], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.0677139], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[62.32439], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[64.45312], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[60.83333], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[74.54780], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[50.07813], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[63.79630], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[62.61364], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[62.50000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[58.045977], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[76.0769229999999], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[51.00000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[66.45370], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.8851541], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.7481203], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.8857143], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9188312], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.88235294117647], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.928571428571428], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[100], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.882353], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11.76471], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[17.647059], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.882353], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.882353], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11.764706], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[41.176471],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0001PP0003], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[01], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[La Plata], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ANGEL ETCHEVERRY], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[060886200], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[464], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[23.20000], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[JS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[67.61711], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.7271001], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[54.22980], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[61.34615], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[81.15942], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[64.39394], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[53.61842], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[77.69841], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57.72152], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[79.44444], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[55.640244], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[88.4154929999999], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[58.39394], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[53.43284], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.0000000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.0000000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.0000000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.0000000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[100], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9.523810], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.28571], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.761905], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9.523810], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.761905], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.285714], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[28.571429], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.285714],
)}
], caption: figure.caption(
position: top, 
[
Información de la base de escuelas
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-escuelas>


Como puede observarse se trata de una base de escuelas en el sentido que en cada fila hay un establecimiento diferente que contiene una serie de propiedades de los mismos en cada una de las columnas. Algunas de esas propiedades se podrían considerar como intrínsecas de cada escuela (clave, región, ámbito, etc.), otras pueden considerarse como propiedades agregadas de los establecimientos en el sentido que devienen de agregaciones de los estudiantes que son parte de cada escuela (p.e. prueba\_x) o de los directivos de los mismos (p.e. direct\_x). Estas distinciones son importantes cuando se quiere realizar una muestra porque esto indica límites y posibilidades sobre a qué población se puede realizar una "buena" muestra desde este archivo. En este contexto, la información de este archivo es particularmente buena para realizar una muestra de colegios pero quizá no tan apropiada para realizar una muestra de estudiantes o directivos… al menos si se lo compara, respectivamente, con tener acceso a una lista de estudiantes o una de directivos. Como veremos más adelante, si se tiene en mente este último punto es posible minimizar algunos de esos problemas aplicando algunas estrategias (p.e. seleccionar pocos estudiantes de cada colegio seleccionado) o, de forma más explícita, hacer una muestra proporcional al tamaño de la matrícula de cada establecimiento.#footnote[Si el conjunto de los estudiantes (así como los maestros y los directivos) de la provincia hubiera sido sorteado para ingresar a cualquier colegio de la provincia y si todos los colegios tendrían la misma matrícula (así como maestros y directivos), realizar una muestra aleatoria de colegios con el objetivo de realizar una muestra aleatoria de estudiantes (o de maestros y directivos) no sería un mayor problema. El primer criterio tiene que ver con las diferencias de cada colegio y el segundo con el modo de agregar esas diferencias en una muestra cuyo primer paso es la selección de unidades agregadas (colegios) para estimar valores de unidades de selección menores (estudiantes, maestras y directivos).]

Por ahora trabajaremos con este archivo para realizar diferentes tipos de muestras de establecimientos educativos. Un plus pedagógico de esta estrategia es que vamos a tener a mano los valores de las estimaciones de las diferentes muestras que se vayan realizando y los respectivos valores de los parámetros poblaciones para comparar resultados. Algunos de esos valores poblacionales se podrán considerar como información secundaria en el sentido que el interés de la muestra no es estimar esos parámetros. Otros de esos valores se los podrá considerar como los parámetros a estimar en la muestra. Esta última situación no es la usual porque si ya se tiene el parámetro poblacional no es necesario la realización de una muestra para su estimación.

Dentro de los parámetros poblacionales vamos a calcular los siguientes:

- Matrícula

- Secciones

- Sondeo primero

- Sondeo segundo

- Región

- Ámbito

Algunas de las variables anteriores son categóricas (región, ámbito) y otras no. Vamos a ver que esto importa porque no es lo mismo estimar un parámetro continuo que uno categórico. Dentro de estos últimos tampoco es lo mismo estimar una variable con 25 categorías (p.e. región) que una variable categórica de 3 categorías (p.e. ámbito).

En la #ref(<tbl-parametros_base>, supplement: [Tabla]) puede observarse algunos de los valores de estos parámetros. Para el caso de las variables continuas (Matrícula, Secciones, sondeo primero, sondeo segundo) se ha calculado la media junto con los valores del primer y tercer cuartil. En el caso de las variables categóricas (región, ámbito) se han calculado los respectivos porcentajes de cada categoría. Esta distinción es importante porque mientras algunas muestras se esfuerzan por estimar medidas de tendencia central, otras se esfuerzan por estimar medidas de dispersión central y otras intentan hacer ambos tipos de estimaciones. Otra distinción importante es la anteriormente mencionada sobre la población que se quiera muestrear. Por ejemplo, el valor de la media del primer sondeo puede ser útil para estimar si la media de la #strong[población de colegios] arroja un valor similar que la media de la/s muestra/s realizada/s de esos colegios. Sin embargo, no hay que olvidar que esos datos, sí con ellos se quiere referir a la #strong[población de estudiantes], habría que ponderarlos por la matrícula de cada colegio, esto es, habría que calcular su media ponderada.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (50%, 50%),
  align: (left,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[267,9],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[secciones], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,2],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_primero], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57,3],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[560],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_segundo], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69,5],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[570],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[region], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,5% (189)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~02], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (223)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~03], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (210)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~04], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1% (213)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~05], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (194)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~06], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (148)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~07], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (138)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~08], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (149)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~09], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9% (205)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (224)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (166)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (155)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1% (131)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~14], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1% (169)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~15], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2% (174)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~16], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (125)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~17], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,2% (133)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~18], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (160)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~19], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (118)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~20], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (159)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~21], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (117)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~22], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (153)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~23], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (153)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~24], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (196)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~25], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (166)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ambito], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Urbano], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65,4% (2.727)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Disperso], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[25,7% (1.073)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Agrupado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8% (368)],
  table.hline(),
  table.footer(table.cell(colspan: 2)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] Media; % (n)],),
)}
], caption: figure.caption(
position: top, 
[
Valores poblacionales de las escuelas
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-parametros_base>


Estos parámetros "conocidos" van a tener 2 funciones en este taller. Por un lado, nos van a servir para cotejar, #emph[ex-ante,] la media de las medias muestrales realizadas con azar simple y, por otro lado, nos pueden servir, #emph[ex-post], para mejorar las muestras concretas efectivamente obtenidas. Esto último, más allá de las técnicas específicas que se utilicen, es importante por lo siguiente:

Las muestras que se hacen en la realidad son "únicas" o "individuales" en el sentido que no se repiten. En cambio, una buena parte de la teoría del muestreo supone una distribución de muestras (como las simulaciones anteriores en donde se realizaban varias muestras de una misma población). La mayoría de las veces el investigador que sale a campo dispone de solo una muestra y el objetivo es que "esa" muestra (y no cualquier otra posible) sea de las mejores y no de las peores. En este sentido, es útil tener herramientas que permitan saber si la muestra es de las buenas o de las malas y, si se trata de este último caso, como mejorarlas.

== Muestreo por azar simple
<sec-azar_simple>
Dentro de los métodos aleatorios el método del azar simple (#emph[random sampling]) es un método tradicional y particularmente útil desde un punto de vista pedagógico para comenzar ya que muchos otros métodos son variaciones (usualmente más complejas) de este. El método del azar simple es el que intuitivamente se ha utilizado en la simulación anterior.

Desde una perspectiva amplia, en la actualidad se podría afirmar que este método de muestreo se encuentra en el medio de un continuo de situaciones en cuando al grado de información exigida para su realización. Lo "único" que pide es una lista de "contactos" de la población que se quiere analizar. La razón por la que "único" se encuentra entre comillas es la siguiente: La necesidad de la una lista puede ser algo exigente en algunas investigaciones (p.e. poblaciones invisibles) aunque algo insuficiente para otras (p.e. diseños con muestras estratificadas). La idea de "contacto" es algo polisémica, pero aquí apunta a que el caso seleccionado se pueda contactar de alguna forma (p.e. dirección de domicilio, mail, celular, etc.) para realizarle las observaciones/mediciones correspondientes.

A continuación vamos a realizar unas 1000 muestras de 300 casos cada una sobre el total de las 4168 escuelas. Esto es una relación entre el tamaño de la población y la muestra de casi el 14%. Hacemos esta cantidad de muestras para observar la distribución de los valores de las medias de cada muestra y ver si sucede algo similar a lo encontrado en el simulador anterior. Para facilitar la comparación lo haremos solo con las variables numéricas y dejaremos de lado las categóricas como Ámbito y Región. El resultado de estas simulaciones se puede observar en la #ref(<tbl-medias_muestrales_azar_simple>, supplement: [Tabla]).

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 2,
  align: (left,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 1.000]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[269 (15)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[secciones], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,18 (0,49)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_primero], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57,27 (0,95)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_segundo], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69,53 (0,91)],
  table.hline(),
  table.footer(table.cell(colspan: 2)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] Media (DE)],),
)}
], caption: figure.caption(
position: top, 
[
Medias de las medias muestrales
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-medias_muestrales_azar_simple>


Como se puede comparar entre #ref(<tbl-parametros_base>, supplement: [Tabla]) y #ref(<tbl-medias_muestrales_azar_simple>, supplement: [Tabla]) los valores entre los parámetros poblacionales y la media de las estimaciones muestrales coincide. No solo eso. También podemos chequear que la distribución de esas medias sigue una distribución aproximadamente normal. Esto es lo que precisamente hacemos en la #ref(<fig-medias_muestrales_azar_simple>, supplement: [Figura]).

#figure([
#box(image("azar_files/figure-typst/fig-medias_muestrales_azar_simple-1.svg"))
], caption: figure.caption(
position: top, 
[
Distribución de las medias muestrales
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-medias_muestrales_azar_simple>


En la figura anterior se observa que la distribución de las 1000 muestras que tomamos, si bien se aproximan, no son idénticas a una distribución normal. Seguramente, si haríamos más muestras nos acercaríamos aún más a una distribución muestral pero quizá este ejemplo baste para explicitar el siguiente punto: Si haríamos muchas muestras vamos a saber con cierta seguridad que la media de las muestras será aproximadamente similar al parámetro poblacional. Sin embargo, quedan abiertas otras preguntas como ¿Qué sucede si solo tomamos una sola muestra? ¿Cómo sabemos si nuestra (única) muestra es de las buenas o de las malas? ¿Cómo sabemos que nuestra muestra no es alguna de las que están en el extremo izquierdo o derecho de la #ref(<fig-medias_muestrales_azar_simple>, supplement: [Figura])?

Ahí es donde entra la ayuda de las librerías específicas. En la introducción se había comentado sobre la existencia de librerías específicas para el análisis de datos muestrales. Estas librerías le van a prestar atención a varios detalles del proceso de selección y nos van a pedir que los explicitemos. Por ejemplo, El tipo de muestras que nos van a interesar generalmente son "sin reemplazo" en el sentido que no queremos que, por ejemplo, un mismo colegio aparezca dos veces seleccionado en una muestra de colegios. También, casi todas las librerías de este estilo, nos van a pedir información de algunos totales de la población para construir ponderadores y otras librerías nos a pedir esos ponderadores utilizarlos en el análisis de los datos. En el caso de una muestra aleatoria simple ese ponderador, al menos en la fase de diseño, suele ser la probabilidad inversa de haber ingresado en la muestra ($N \/ n$, donde $N$ es el tamaño de la población y $n$ el tamaño de la muestra). En este tipo de diseño el valor del ponderador es el mismo para todas las unidades seleccionadas.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,center,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: center, colspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Azar simple]
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Parámetro Pob.]
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[95% CI]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[276,6 (2,9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[271, 282], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[267,9],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[secciones], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,6 (0,1)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11, 12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,2],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_primero], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[56,2 (0,2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[56, 57], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57,3],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[472], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[560],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_segundo], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69,8 (0,2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69, 70], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69,5],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[556], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[570],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[region], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0%, 2,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,5% (189)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~02], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,3% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,8%, 6,9%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (223)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~03], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9%, 5,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (210)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~04], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7,0% (n=21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,5%, 7,6%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1% (213)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~05], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3%, 3,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (194)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~06], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3%, 4,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (148)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~07], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3%, 4,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (138)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~08], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9%, 5,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (149)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~09], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,7% (n=20)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,1%, 7,2%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9% (205)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,7% (n=20)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,1%, 7,2%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (224)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,9%, 4,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (166)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0%, 2,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (155)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3%, 3,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1% (131)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~14], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1% (169)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~15], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2% (174)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~16], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7%, 2,3%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (125)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~17], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,2% (133)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~18], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7%, 3,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (160)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~19], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3%, 3,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (118)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~20], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3%, 4,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (159)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~21], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7%, 2,3%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (117)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~22], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (153)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~23], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2%, 5,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (153)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~24], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7%, 3,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (196)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~25], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9%, 5,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (166)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ambito], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Urbano], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[67,0% (n=201)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[66%, 68%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65,4% (2.727)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Disperso], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20,3% (n=61)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19%, 21%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[25,7% (1.073)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Agrupado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12,7% (n=38)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12%, 13%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8% (368)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9],
  table.hline(),
  table.footer(table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] Media (SE); % (n=n (unweighted))],
    table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2]] Media; % (n)],
    table.cell(colspan: 4)[Abreviacion: CI = Intervalo de confianza],),
)}
], caption: figure.caption(
position: top, 
[
Estimaciones con azar simple
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-azar_simple>


Ahora que estamos analizando solo una muestra podemos empezar a ver algunas distancias entre los parámetros poblaciones y las estimaciones que surgen de la muestra. Esto es especialmente más notorio en los casos de las categorías menos difundidas de las variables categóricas como puede ser algunas de las regiones.

== Muestreo Sistemático
<muestreo-sistemático>
El muestreo sistemático no ofrece muchas diferencias apreciables de cálculo con el azar simple aunque tiene una diferencia logística importante. No es necesario tener en el momento del diseño una lista centralizada de "contactos" a quien seleccionar. Esto hace que el muestreo sistemático, especialmente en muestras polietápicas, sea un buen candidato a aplicar en las últimas instancias de selección en donde cada encuestador, evaluador o #emph[data entry], de manera descentralizada, sí tiene acceso, #emph[in situ], a esa información. Es importante, de todos modos, explictar el supuesto que la lista en cuestión no esconda un sesgo particular en su orden o, ante esta presuposición, poder reordenarla bajo algún criterio que fuerce el azar. De todos modos, ante la existencia de algún patrón subyacente, el muestreo sistemático, versus opciones como "elegir a los x primeros (o últimos)" parece mejor equipado. Sin embargo, estas últimas opciones tienen el beneficio de (usualmente) ser más simples de implementar para el operador final.

Como ejemplo podemos analizar la siguiente situación. Se quiere realizar una muestra de estudiantes y a) no se cuenta con información nominal en el momento del diseño de la muestra aunque b) sí se cuenta con una buena base de los colegios y c) se asume que dentro de cada colegio sí existe acceso a una lista de contactos de los estudiantes. En este contexto, se puede sortear una cantidad de colegios en una primera etapa (p.e. mediante la técnica #ref(<sec-pps>, supplement: [Sec.])) y luego, en una segunda etapa, se puede indicar al directivo, encuestador, etc. de cada escuela seleccionada que, una vez con acceso a la lista de estudiantes, seleccione una $X$ cantidad de los mismos. Para realizar esa última selección el proceso será sortear al primer estudiante, seleccionarlo y luego, desde allí, saltar $K$ estudiantes para seleccionar al segundo estudiante y así sucesivamente. En general, $K$ representa el cociente entre el tamaño de la población a seleccionar $N$ como el tamaño de la lista de estudiantes del colegio seleccionado y el tamaño de la muestra $n$ como la cantidad de estudiantes que se quiere seleccionar de esa lista.

$ K = N / n $

Siguiendo este ejemplo, supongamos que el encuestador tenga que elegir 5 estudiantes de una lista de 50. En ese caso se podría aplicar el siguiente código:

Cambiando lo que haya que cambiar, el código anterior también se podría aplicar si se quiere utilizar para seleccionar los 300 establecimientos que antes se habían seleccionado con el diseño del azar simple.

== Muestreo Estratificado
<sec-estratificado>
El muestreo estratificado es un tipo de muestreo que se realiza sobre la base de estratos que, en principio, cumplen el criterio de que sean parecidos en su interior y diferentes entre ellos. Otra característica distintiva de los estratos es que estos son discretos, esto es, pueden tener, a lo sumo, un orden entre ellos, pero los límites entre ellos son puntuales más que continuos.

Si se recuerda los comentarios realizados en la introducción, cuanto menos heterogeneidad exista entre las unidades a seleccionar menor es el problema de la representatividad. Esto es precisamente lo que intenta aprovechar la idea del muestreo estratificado. En el extremo, si todos los miembros de cada estrato son iguales entre sí y los tamaños o cantidad de casos de cada estrato también son iguales entre sí, solo habría que seleccionar a un caso por estrato como razón suficiente para obtener una muestra representativa de la población. Si los tamaños de los estratos fueran diferentes también se podría seleccionar un caso por estrato, pero la condición para que esta muestra sea representativa es que luego se incluyan ponderadores diferentes para cada estrato de la muestra en función de la inversa de la probabilidad de entrar en la muestra. Esta diferencia, es la diferencia central entre el muestreo estratificado proporcional y el no proporcional con asignación óptima que veremos más adelante.

Para que el muestreo estratificado produzca ventajas (en comparación con el azar simple) los estratos deben tener una heterogeneidad interna menor a la heterogeneidad del conjunto de la población aunque aquella se encuentre lejos del ejemplo extremo del párrafo anterior. Los estratos conforman subpoblaciones mutuamente excluyentes y exhaustivas de toda población aunque se pueden construir los mismos en función de datos categóricos, agregaciones de datos continuos (p.e. agrupaciones de años de antigüedad) o espaciales (p.e. Regiones). En una base de datos educativa puede haber muchas variables que pueden ser considerados como estratos. En este caso, a modo de ejemplo, nos quedaremos con "Ámbito" que posee 3 categorías que asumimos, como diría Platón en el Fedro, que cortan la realidad por sus articulaciones naturales @platón2002[pág. 55]. Por otro lado, utilizar "Ámbito" como estrato tiene otra virtud pedagógica que deviene de la diferente distribución porcentual de cada categoría. Esto lo hace un buen candidato para mostrar la utilidad del muestreo estratificado en su versión proporcional y no proporcional, ya que la categoría "Rural Agrupado" posee un menor porcentaje de casos y, a igualdad de otras condiciones, veremos como eso dificulta su posterior análisis. Veremos también que para decidir entre estos tipos de diseño también será útil indagar en el significado de un término clásico del muestreo como es el "dominio" de estimación.

A veces los estratos se construyen con base en antecedentes teóricos, pero nada impide que estos sean constructos estadísticos con un significado no muy claro como los que se pueden producir luego de un análisis de clústers @everitt2011. Tampoco la técnica tiene una limitación en cuanto a la cantidad de categorías. Cabe aclarar que cualquier estrato debe ser capaz de construirse tanto a nivel poblacional como posible de identificarse/seleccionarse a nivel muestral. En este sentido, más allá si tiene un origen más teórico o estadístico es claro que esta técnica exige tener acceso empírico a una mayor cantidad de variables en comparación con, por ejemplo, el azar simple.

=== Estratos con asignación proporcional
<sec-estrato_proporcional>
En este subtipo de muestreo estratificado utilizaremos la variable "Ámbito" como estrato y respetaremos, aproximadamente, la distribución que ese estrato posee en la población. Decimos "aproximadamente" porque aquí siempre existe un factor de redondeo que deviene de la necesidad de realizar la muestra sobre una cantidad de casos discretos. Esta última necesidad hace que, al igual que cuando se intenta respetar las proporciones de los votos de una elección para la renovación de bancas de la Cámara de Diputados, casi siempre existan pequeñas diferencias entre las proporciones poblacionales y las muestrales.

Seleccionada la muestra ahora le especifico los detalles del diseño mediante la librería survey o srvyr.

Y luego realizo la #ref(<tbl-estratificado_teo_prop>, supplement: [Tabla]) con la información de algunas variables y esa misma tabla lo comparo con los valores de la #ref(<tbl-azar_simple>, supplement: [Tabla]) que refería al diseño con azar simple.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (left,center,center,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: center, colspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Estratificado P.]
    ]], table.cell(align: center, colspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Azar simple]
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[95% CI]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[95% CI]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[262,3 (1,9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[258, 266], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[276,6 (2,9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[271, 282],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[28], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[secciones], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10,9 (0,1)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11, 11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,6 (0,1)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11, 12],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[28], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_primero], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57,9 (0,2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[58, 58], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[56,2 (0,2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[56, 57],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[712], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[472], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_segundo], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69,8 (0,2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69, 70], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69,8 (0,2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69, 70],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[572], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[556], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[region], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3%, 3,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0%, 2,7%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~02], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,3% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,8%, 6,9%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,3% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,8%, 6,9%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~03], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,3% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,8%, 6,9%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9%, 5,8%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~04], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,3% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,8%, 6,9%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7,0% (n=21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,5%, 7,6%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~05], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,6% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2%, 5,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3%, 3,0%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~06], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3%, 4,1%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~07], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,9%, 4,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3%, 4,1%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~08], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9%, 5,8%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~09], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,7% (n=20)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,1%, 7,2%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,5%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,7% (n=20)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,1%, 7,2%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3%, 3,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,9%, 4,8%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7%, 3,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0%, 2,7%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3%, 4,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3%, 3,0%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~14], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,6%, 5,5%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,4%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~15], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,4% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,9%, 4,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0%, 3,7%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~16], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0%, 2,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7%, 2,3%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~17], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,6%, 5,5%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0%, 3,7%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~18], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,6%, 5,5%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7%, 3,4%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~19], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0%, 2,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3%, 3,0%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~20], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,5%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3%, 4,1%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~21], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,1%, 1,6%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7%, 2,3%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~22], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3%, 5,2%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,4%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~23], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,6%, 5,5%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2%, 5,1%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~24], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3%, 3,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7%, 3,4%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~25], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7%, 3,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9%, 5,8%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ambito], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Urbano], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65,4% (n=197)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65%, 65%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[67,0% (n=201)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[66%, 68%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Disperso], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[25,7% (n=77)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26%, 26%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20,3% (n=61)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19%, 21%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Agrupado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8% (n=26)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8%, 8,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12,7% (n=38)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12%, 13%],
  table.hline(),
  table.footer(table.cell(colspan: 5)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] Media (DE); % (n sin ponderar)],
    table.cell(colspan: 5)[Abreviacion: CI = Intervalo de confianza],),
)}
], caption: figure.caption(
position: top, 
[
Tablas comparativas entre resultados azar simple y estratificado
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-estratificado_teo_prop>


Una característica importante de este tipo de muestreo es que sus factores de expansión o expansores, al menos en la fase de diseño, son iguales para todos los estratos. Esto suele ser una pequeña ventaja para el momento del análisis ya que requiere mano de obra algo menos especializada.

=== Estratos con asignación no proporcional
<sec-estrato_no_proporcional>
En el tipo de diseño anterior hubo una variable (Ámbito) que se usó para estratificar la muestra. En ese caso, salvo variaciones menores debido a los factores de redondeo antes comentados, las proporciones de la muestra respetan las proporciones poblacionales. Eso es lo que precisamente se intenta modificar con el muestreo con una asignación no proporcional. Usualmente, la idea que está detrás de esta estrategia es poder reducir el desvío estándar de aquellos estratos que más suman al desvío estándar de toda la muestra. El desvío estándar de cada estrato es una función entre la heterogeneidad propia de cada estrato (p.e. que tán iguales son entre sí los establecimientos "Rural Agrupado") con la cantidad de casos de ese estrato (a mayor cantidad de casos menor desviación estándar). Si en la muestra se respeta la proporción original de la población (aun en el caso de que los establecimientos de ámbitos urbanos tengan una misma heterogeneidad que el resto) es claro que los estratos rurales poseen una distribución muy baja y, por lo tanto, nos vamos a quedar con pocos casos en la muestra y, de manera derivada, con un alto error estándar en esos análisis. La propuesta original de Neyman @neyman1934 justamente trata de como asignar de manera eficiente (desde el punto de vista estadístico) la cantidad de casos a cada estrato, haciendo que, para nuestro ejemplo, los estratos rurales se encuentren sobrerrepresentados y los urbanos subrepresentados. Esta estrategia permite que, para una igual cantidad de casos que un muestreo estratificado proporcional, se puedan hacer inferencias (bastante) más confiables para dominios de estimación más pequeños a cambio de perder (un poco) de confiabilidad en los dominios de estimación más grandes#footnote[Un dominio o subclase de estimación es una partición de la población o de la muestra sobre la cual se espera realizar inferencias. A veces se usa la denominación que los dominios denotan subpoblaciones (de la población) y las subclases reflejan esas divisiones en la muestra @kish1980[p.~209]. En cualquier caso es conveniente introducir estos dominios en el diseño de la muestra para poder controlar su tamaño poblacional @brus2022[cap. 14]. En el ejemplo del cuerpo del texto se asume que esos dominios de estimación coinciden con los estratos aunque esto no tiene nada de necesario.].

La contraparte de esta ventaja es que ahora es necesario construir expansores diferentes para cada estrato para que se le devuelva la probabilidad que se encontraba en la población. En este sentido, el factor de expansión del estrato urbano será mayor al de los estratos rurales.

Aquí, para extremar esta lógica, vamos a realizar una muestra como si la distribución de la variable Ámbito fuera igual para sus 3 categorías.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (left,center,center,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: center, colspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Estratificado P]
    ]], table.cell(align: center, colspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Estratificado no P]
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[95% CI]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[95% CI]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[262,3 (1,9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[258, 266], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[271 (2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[267, 275],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[28], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[38], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[secciones], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10,9 (0,1)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11, 11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11, 11],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[28], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[38], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_primero], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57,9 (0,2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[58, 58], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57, 58],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[712], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[577], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_segundo], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69,8 (0,2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69, 70], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[70 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69, 70],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[572], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[533], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[region], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3%, 3,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8%, 4,6%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~02], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,3% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,8%, 6,9%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,9% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,5%, 4,4%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~03], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,3% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,8%, 6,9%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,6% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2%, 5,0%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~04], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,3% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,8%, 6,9%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,5% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7,9%, 9,1%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~05], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,6% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2%, 5,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,6% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,1%, 7,2%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~06], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,4% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,9%, 6,9%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~07], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,9%, 4,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=5)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,9%, 3,7%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~08], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0% (n=3)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7%, 2,3%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~09], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,9% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,5%, 4,4%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,5%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,6% (n=20)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1%, 6,1%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3%, 3,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,5%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7%, 3,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,5% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,2%, 1,7%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3%, 4,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,5% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1%, 4,0%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~14], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,6%, 5,5%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,4%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~15], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,4% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,9%, 4,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3% (n=24)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,9%, 4,7%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~16], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0%, 2,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,4%, 3,1%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~17], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,6%, 5,5%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,4% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0%, 4,8%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~18], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,6%, 5,5%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,5% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,2%, 4,0%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~19], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0%, 2,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,6% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,2%, 2,9%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~20], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,5%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7%, 3,4%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~21], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,1%, 1,6%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,1% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,8%, 2,4%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~22], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3%, 5,2%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8%, 3,5%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~23], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,6%, 5,5%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,6% (n=26)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1%, 5,0%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~24], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3%, 3,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,8% (n=22)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3%, 6,3%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~25], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7%, 3,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,1% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,8%, 2,4%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ambito], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Urbano], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65,4% (n=197)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65%, 65%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65% (n=100)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65%, 65%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Disperso], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[25,7% (n=77)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26%, 26%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26% (n=100)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26%, 26%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Agrupado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8% (n=26)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8%, 8,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8% (n=100)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8%, 8,8%],
  table.hline(),
  table.footer(table.cell(colspan: 5)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] Media (DE); % (n sin ponderar)],
    table.cell(colspan: 5)[Abreviacion: CI = Intervalo de confianza],),
)}
], caption: figure.caption(
position: top, 
[
Tablas comparativas entre muestra estraificada proporcional y no propocional
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-estratificado_teo_no_prop>


== Muestreo por Clústers
<sec-clusters>
El muestreo por clúster es otra manera de aplicar el azar para diseñar muestras. A diferencia del muestreo estratificado en el muestreo por clúster el investigador considera a estos como "racimos" de casos que, usualmente, se encuentran cercanos geográficamente pero no necesariamente socialmente o, más en general, no son homogéneos en las variables de estudio. En efecto, la ventaja de este tipo de muestreo es que abarata costos en la ejecución de muestras espacialmente extensas y especialmente si en ese espacio extenso hay numerosos racimos de casos como, por ejemplo, una multitud de pequeños poblados urbanos de 50.000 personas. El precio que usualmente se paga (a igual cantidad de casos) es un aumento en el error standard pero, justamente, el quid de la cuestión es que dado la baja del costo unitario de cada caso ahora es posible, con igual presupuesto, agregar más casos a la muestra para bajar la precisión hasta el valor deseado.

== Muestreo Proporcional al Tamaño (PPS)
<sec-pps>
Muchas veces, especialmente en diseños polietápicos, se desea que en la primera etapa las unidades de selección (llamadas justamente unidades de selección primarias) sean escogidas en función de alguna variable que sirva como indicador de su tamaño. Esta técnica se suele denominar muestreo proporcional al tamaño (PPS)#footnote[La sigla PPS viene de la expresión "#strong[P]robability #strong[P]roportional to #strong[S]ize" que es como se lo conoce en la bibliografía de muestreo.] y puede considerarse como un caso especial del muestreo por clústers @lumley2010[pág. 46]. En el caso de unidades geográficas esa variable podrá ser el tamaño espacial o área (p.e. km#super[2]) y en variables no espaciales podrá ser la cantidad de personas (p.e. votantes en distritos). En el caso de una muestra de colegios, variables como el tamaño de la matrícula pueden ser buenas candidatas a utilizar en este tipo de muestras.

Un PPS, por diseño, va a otorgar una mayor probabilidad de salir en la muestra a los colegios con mayor matrícula y estos pueden poseer características particulares como, por ejemplo, encontrarse abrumadoramente en ámbitos urbanos. De este modo ya podemos intuir que, con respecto a la población de establecimientos, una muestra PPS (sin ponderar) obtendrá como resultado una sobrerrepresentación de los #strong[establecimientos] de ámbito urbano y, estarán sobrerrepresentados aquellos establecimeintos con mayor matrícula. Aunque parezca algo paradójico esto es justamente para darles a todos los #strong[estudiantes] (y no solo los del ámbito urbano) una misma chance de salir en la muestra. Esto último depende, especialmente en un diseño polietápico, que se haga efectivamente después de haber realizado la selección primaria, esto es, que se haga después de la primera etapa.

A pesar de cierta idea intuitiva acerca del objetivo del muestreo PPS, su efectiva aplicación (especialmente en muestreos sin reemplazo) tiene sus complejidades a nivel de los algoritmos a utilizar. Esto en parte es algo compartido por todos los muestreos sin reemplazo (versus los con reemplazos) pero aquí está presente la dificultad adicional de que las probabilidades de inclusión son diferentes. En efecto, el muestreo PPS puede ser considerado como un tipo de muestreo con probabilidades de inclusión diferentes (#emph[unequal probabilities]) pero con la particularidad que esas probabilidades diferentes se calculan en función del tamaño de las unidades a seleccionar en primera instancia. A continuación vamos a utilizar un algoritmo que tiene que ver con la idea de "#emph[local pivotal]" que vamos a ver con mayor profundidad cuando veamos las muestras bien dispersas (#ref(<sec-bien_distribuido>, supplement: [Sec.]))#footnote[Existen otros algoritmos para realizar un muestreo PPS. Muchos de ellos son algoritmos especializados en probabilidades desiguales (en donde la desigualdad por tamaño sería un caso especial) por lo que muchos de sus nombres suelen empezar con UP (#emph[unequal probabilities]). Algunos son los siguientes: UPtille, UPpivotal, UPpoisson @tillé2023.].

Para visualizar esto vamos primero vamos a construir a realizar 2 ejemplos. Uno en donde se realiza un PPS en donde luego solo se expande por un ponderador que simula que todos los establecimientos tenían las mismas chances de haber entrado (o, expresado de otro modo, que expande pero no pondera) y otro en donde, a esa misma muestra, se la pondera por la probabilidad inversa de haber ingresado en la muestra, esto es, un ponderador que haga pesar menos a aquellos establecimientos con mayor tamaño. Siguiendo con el ejemplo de los colegios, si el proceso es seleccionar los colegios por tamaño y luego realizar un censo (esto es, ninguna muestra) de estudiantes dentro de cada uno de los colegios seleccionados, tanto los colegios como los estudiantes de ámbito urbano se encontrarán sobrerrepresentados por lo que un ponderador que tenga en cuenta las probabilidades inversas en función del tamaño puede ser útil.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,center,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[PPS expandida pero no ponderada]
    ]], table.cell(align: center, colspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[PPS ponderada por PI en función del tamaño]
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.159]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.012]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[95% CI]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[529,5 (2,90)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[277,7 (9,08)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[260, 296],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[secciones], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19,7 (0,08)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,6 (0,34)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11, 12],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_primero], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[54,1 (0,13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[58,6 (1,12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[56, 61],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[83], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[153], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_segundo], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[67,9 (0,12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[74,2 (0,65)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[73, 75],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[97], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[678], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[region], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,3% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2%, 5,3%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~02], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7,0% (n=21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,5% (n=21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0%, 5,0%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~03], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9,7% (n=29)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,5% (n=29)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0%, 6,1%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~04], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13,7% (n=41)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7,6% (n=41)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,9%, 8,3%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~05], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7,0% (n=21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,4% (n=21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0%, 3,7%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~06], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,9%, 3,8%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~07], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,6% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,2%, 3,0%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~08], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,7% (n=17)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (n=17)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,5%, 3,2%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~09], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,3% (n=34)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9% (n=34)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,4%, 5,4%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,7%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1%, 4,1%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,5% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8%, 4,3%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,9% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0%, 5,0%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~14], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,9%, 2,6%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~15], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,4% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8%, 4,1%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~16], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,0% (n=0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,0% (n=0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,00%, 0,00%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~17], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,7% (n=2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,95%, 1,7%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~18], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14,6% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11%, 18%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~19], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,2% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,98%, 1,5%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~20], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,6% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,2%, 2,0%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~21], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3%, 2,1%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~22], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,6% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3%, 1,8%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~23], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,9% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1%, 5,0%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~24], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,7% (n=2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,4% (n=2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,33%, 0,58%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~25], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7% (n=5)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14,0% (n=5)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10%, 19%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ambito], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Urbano], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[95,3% (n=286)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[62,1% (n=286)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[58%, 66%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Disperso], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7% (n=5)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[25,2% (n=5)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[21%, 30%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Agrupado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12,7% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11%, 15%],
  table.hline(),
  table.footer(table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] Media (EST); % (n sin ponderar)],
    table.cell(colspan: 4)[Abreviacion: CI = Intervalo de confianza],),
)}
], caption: figure.caption(
position: top, 
[
Tablas comparativas entre PPS con ponderador y sin ponderador
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-pps_ponderadores>


En efecto, en la #ref(<tbl-pps_ponderadores>, supplement: [Tabla]) puede observarse que si trabajamos en una muestra PPS solo expandiendo pero sin ponderar (primera tabla desde la izquierda) vemos como el valor promedio de la matrícula es alto (529) y que la abrumadora mayoría de los establecimientos seleccionados son del ámbito urbano (95%). Si luego analizamos la muestra ponderada por la probabilidad inversa en función del tamaño vemos como la mayoría de los valores se acercan a los valores conocidos de la población, especialmente aquellos que refieren a propiedades intrínsecas de los establecimientos como la región y el ámbito. Sin embargo, esta operación tiene sus riesgos porque hace depender mucho al ponderador de la matrícula y esta puede ser sumamente heterogénea. Por poner un ejemplo, en el muestreo PPS fueron seleccionados 5 establecimientos de la región 25 que es una región que se caracteriza por tener un porcentaje de establecimientos rurales mayor a la media (alrededor del 40% son urbanos). Pero dado que en el PPS los establecimientos más grandes tienen más chances de entrar en la muestra se seleccionaron 4 establecimientos urbanos (con matrícula típica de ámbitos urbanos) y solo 1 de ámbito rural. En este contexto el ponderador luego hace que esos 4 pesen menos y que ese único establecimiento rural (que tiene una matrícula de 7 estudiantes) pese mucho más que lo que descuentan los 4 urbanos. El resultado es que la región 25, cuando se trabaja con el ponderador, salta desde un 1,7% sin ponderar hasta un 14% ponderado. Algo similar sucede con la región 18. Por esta razón, es interesante también observar que en muchos casos el intervalo de confianza con la muestra ponderada se expande (p.e. región 18 y 25). Esto se debe a que el ponderador ahora hace pesar más en la estimación a situaciones en donde se encuentran pocos casos y, por lo tanto, al estar basadas en menos casos esas estimaciones poseen un margen de error mayor.

Si en cambio, luego en una segunda etapa, se realiza un muestro de una cantidad fija (p.e. 10 estudiantes por colegio seleccionado) la muestra de colegios sin ponderar seguirá sobrerrepresentando a los #strong[establecimientos] del ámbito urbano pero tiene muchas chances de representar aceptablemente a la población de #strong[estudiantes]. Esto último justamente una de las características más aprecidas del PPS en diseños polietápicos. En efecto, aplicado al mundo educativo, puede ser algo buscado explícitamente si se utiliza la selección de los colegios como unidades de selección primarias y luego a los estudiantes como unidades de selección secundaria o final. En otras palabras, se trata de un efecto buscado por diseño, justamente porque ahora el objetivo está puesto en lograr una muestra representativa de la población de estudiantes a través de una población de establecimientos que contiene variables agregadas de los estudiantes.

Para fijar las ideas, en el ejemplo anterior se seleccionarían en primera instancia unos 300 establecimientos, luego se obtendría una muestra final de 3000 estudiantes porque en la segunda instancia se seleccionaron 10 estudiantes por establecimiento. Una virtud práctica de este último ejemplo es que, aparte de reducir costos de logística en comparación a un muestreo por azar simple de un solo paso (porque se van a menos unidades de selección primarias), es que otorga un mismo ponderador a cada caso seleccionado (se dice que la muestra es autoponderada) lo que facilita muchos análisis posteriores. Esto es un típico ejemplo de muestra compleja en donde la muestra se realiza en más de una etapa y en cada una de ellas se utilizan técnicas diferentes.

En relación con lo anterior y de manera aparentemente paradójica, la muestra PPS sin ponderar estima mejor las variables agregadas como el valor del primer y segundo sondeo que un análisis censal de toda la población de colegios (como se hizo en #ref(<tbl-parametros_base>, supplement: [Tabla])). Lo paradógico de esto es que una muestra, esto es, una parte de un todo, logre un mejor acercamiento a un respectivo parámetro poblacional que un censo, esto es, un registro de cada una de las partes del todo. La solución a esta paradoja es entender que la #ref(<tbl-parametros_base>, supplement: [Tabla]) hace referencia a la población de colegios y, en ese sentido, sus valores son correctos. Ahora bien, si con esos datos (censales, pero de la población de establecimientos) se quiere hacer afirmaciones sobre la población de estudiantes la información de la #ref(<tbl-parametros_base>, supplement: [Tabla]) no es la más idónea o, al menos, hay que tratarla de manera diferente. En las variables que se pueden considerar como variables agregadas de estudiantes (p.e. sondeo\_primero, sondeo\_segundo) más que calcular la media habría que haber calculado la media ponderada por matrícula y ese cálculo sería un mejor estimador de la media de las notas de la población de estudiantes En ese caso, el resultado de ese cálculo sí se podría considerar como un parámetro de la población de estudiantes y contra esos valores se debería comparar las estimaciones del diseño PPS sin ponderar. Esto precisamente se puede observar en la #ref(<tbl-media_ponderada_notas_estudiantes>, supplement: [Tabla]).

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,center,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[PPS sin ponderar]
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Pob. media ponderada]
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Pob. media sin ponderar]
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_primero], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[54], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[54], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_segundo], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[68], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[68], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[70],
)}
], caption: figure.caption(
position: top, 
[
Medias de las notas según tipo de muestra y población
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-media_ponderada_notas_estudiantes>


#figure([
], caption: figure.caption(
position: top, 
[
Tablas comparativas entre PPS y estratificado propocional
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-pps>


= Muestreos balanceados y bien distribuidos
<muestreos-balanceados-y-bien-distribuidos>
== Muestras Balanceadas (por el método del cubo)
<sec-cubo>
Las muestras balanceadas son un método particular dentro del espectro de las técnicas disponibles en la que felizmente se juntan las potencialidades del enfoque del "#emph[Design Based]" y del "#emph[Model Assisted]". Este tipo de técnica permite diseñar muestras balanceadas en el sentido que las medias muestrales de las covariables sean (aproximadamente) iguales a las medias poblacionales de esas covariables. Esto, como mínimo, es una estrategia efectiva para evitar caer en el pequeño subconjunto de muestras aleatorias que son muy sesgadas @tillé2011[pág. 221]. En este sentido, se recuerda que cuando realizamos diseños por azar tenemos chances (si bien bajas) de obtener muestras muy sesgadas. El muestreo balanceado evita esta situación y, la mayoría de las veces (siempre que las covariables disponibles estén empíricamente relacionadas con las variables de estudio) suele ofrecer muestras con las que luego es posible realizar una estimación con una mayor precisión que las realizadas con el azar simple. Si se agregan más covariables al diseño y, nuevamente, estas se encuentran linealmente relacionadas con las variables de estudio, el estimador de la media poblacional también mejorará aún más su precisión.#footnote[Más adelante veremos que indagar sobre la precisión de la estimación es posible pero difícil en las muestras realizadas con el método del cubo. Por esta razón, si bien es posible comparar la precisión de estas muestras contra, por ejemplo, el muestreo por azar simple, acá esto se tomará como un supuesto y se remite al lector a fuentes en donde se prueba lo anterior \[#cite(<brus2022>, form: "prose"), cap. 9\]@schneider2024. El principal problema es que, por ahora, las librerías de análisis de datos de encuestas (p.e. #emph[survey]) todavía no tienen el instrumental adecuado para especificar este tipo de diseños y, por lo tanto, para calcular la precisión de sus estimaciones.]

Lo anterior puede considerarse un viejo #emph[desideratum] de los diseños muestrales aunque antes no había disponible algún algoritmo de cálculo aplicable de una manera generalizable y precisa que pudiera ser ejecutado o calculado de manera viable @deville2004. Eso es lo que precisamente logra el método del cubo. De manera alternativa, las muestras balanceadas pueden ser vistas como un tipo de calibración (#ref(<sec-calibracion>, supplement: [Cap.])) que se encuentra integrada en el diseño de la muestra, y por lo tanto se trata de un proceso #emph[ex-ante] la ejecución de la misma, más que algo #emph[ex-post] a la misma como la estimación de los estimadores @tillé2011[pág. 216].

Por lo tanto, el contexto actual de:

#block[
#set enum(numbering: "a)", start: 1)
+ un mayor acceso a fuentes secundarias de datos y
+ una mayor capacidad computacional,
]

parece ser un contexto particularmente propicio para la aplicación y difusión de este tipo de diseños porque, justamente, se trata de un diseño demandante en cuanto a datos secundarios (en forma de información auxiliar o covariables) y demandante con respecto a recursos computacionales (para ejecutar el algoritmo del método del cubo).

Antes de pasar a la aplicación de este diseño con la base de establecimientos de nivel primario vamos a considerar un ejemplo trivial con variables espaciales en donde se puede simular fácilmente la linealidad de la variable de estudio con respecto a otras covariables. Esto también servirá como un anticipo para cuando intentaremos incorporar explícitamente variables espaciales (a través de coordenadas) en la muestra (#ref(<sec-bien_distribuido>, supplement: [Sec.])).#footnote[El ejemplo y el respectivo código fue adaptado del libro "Spatial sampling with R" @brus2022.]

Supongamos una población como un bosque en donde tenemos alguna variable continua que nos interesa investigar. Supongamos además que, a efectos pedagógicos, nosotros sabemos la distribución de esa variable y, para forzar el pensamiento espacial, vamos a suponer que esa variable continua es una representación de la densidad de la vegetación de cada celda de una grilla de coordenadas. El valor de esa densidad lo vamos a visualizar indicando un valor amarillo para sus valores más altos y azul para sus valores más bajos. Con respecto a las grillas que representan distintas partes del bosque se las puede ubicar con un valor en el eje "Hacia el Norte" y otro valor en el eje "Hacia el Este".

Este ejemplo espacial es útil porque permite construir y visualizar fácilmente la linealidad de las covariables o variables auxiliares ("Hacia el Norte" y "Hacia el Este") con la variable de estudio ("Densidad de la vegetación"). En el caso de la #ref(<fig-muestreo_cube_ejemplo>, supplement: [Figura]) se observa como a medida que vamos hacia el Norte la vegetación es algo más espesa. Lo mismo puede decirse en cuanto si vamos hacia el Este. En este sentido, el valor más alto de densidad se encuentra en la intersección de los valores más altos de los ejes anteriores o, expresado de manera alternativa, en el cuadrante superior derecho de la población. Esto quiere decir que estas variables auxiliares se encuentran empíricamente relacionadas de #strong[#emph[forma lineal]] con el valor de la densidad de vegetación.

#figure([
#box(image("cubo_files/figure-typst/fig-muestreo_cube_ejemplo-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Muestra balanceada 'Hacia el Este' (E) y 'Hacia el Este y el Norte' (E y N)
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-muestreo_cube_ejemplo>


Por otro lado, en la #ref(<fig-muestreo_cube_ejemplo>, supplement: [Figura]) también se observan las 2 muestras balanceadas de la población descritas en el párrafo anterior. Cada muestra posee 4 casos representados por los cuadrados blancos. La de la izquierda se encuentra balanceada solamente por el eje "Hacia el Este" y, acorde con esto, los casos seleccionados se esparcen de Este al Oeste. La muestra de la derecha, en cambio, se encuentra balanceada por ambos ejes por lo que la distribución de los casos seleccionados no solo varían de Esta a Oeste, sino que también lo hacen de Norte a Sur. En este sentido específico, se puede afirmar que la segunda muestra es más balanceada que la primera y, de manera intuitiva, se puede afirmar que aquella es más representativa que esta.

== Muestras Balanceadas sobre base de establecimientos
<sec-cubo-establecimientos>
Ahora pasaremos a aplicar este diseño a la base de escuelas que venimos trabajando. Esta vez vamos a incorporar una mayor cantidad de información secundaria que se encuentra disponible en la base de establecimientos. Como en muchas otras técnicas, la introducción de más variables no es garantía de un mejor resultado, ya que en este caso la agregación de más variables, especialmente si no están linealmente relacionadas con las variables de estudio, puede ser contraproducente @tillé2011[pág. 222]. Ese es precisamente una de las utilidades del ejemplo anterior de la #ref(<fig-muestreo_cube_ejemplo>, supplement: [Figura]), ya que en él era fácil construir y visualizar la linealidad de la relación entre las covariables y la variable de estudio. Por esta razón, en este proceso de selección es clave tener claras las variables de estudio, para luego determinar qué covariables de la información secundaria disponible es conveniente incluir.

En este caso, nos focalizaremos en diferentes tipos de objetivos para demostrar la flexibilidad de la técnica. En primer lugar, nos interesará tener una muestra de los establecimientos desde la base de los establecimientos (#ref(<sec-cubo_colegios>, supplement: [Sec.])) y luego una muestra de los estudiantes desde esa misma base (#ref(<sec-cubo_estudiantes>, supplement: [Sec.])).

Las lista de covariables que serán incluidas, con fines más metodológicos que teóricos, serán las siguientes:

- Matrícula

- Secciones

- Región

- Ámbito

La lista anterior funciona a modo de ejemplo aunque tiene la virtud de trabajar con información secundaria casi completa, ya que se trata de variables con muy baja tasa de no respuesta. En efecto, aquí usaremos estas covariables tanto cuando nos interese averiguar características de los establecimientos como de los estudiantes, pero un análisis más real implicaría usar un conjunto diferente para cada muestra. La razón de esto es al ser diferentes las variables de estudio también podrían/deberían ser las covariables disponibles y/o usadas.

Dicho lo anterior parece pertinente el siguiente comentario. Cuando algunos establecimientos no tienen datos en algunas de las covariables utilizadas estos no forman parte de la muestra. Esto recuerda algo que se había comentado cuando se vio el muestreo por azar simple (#ref(<sec-azar_simple>, supplement: [Sec.])). El muestreo por azar simple solo exige una lista (y/o algún dato que luego permita su contacto empírico) de los miembros de la población. El método del cubo exige, además, el acceso a otras variables de la población en cuestión en forma de información auxiliar. Si existen casos que no tienen esa información, estos no podrán ingresar a la muestra y esto tiene diferentes tipos de consecuencias.

La primera consecuencia es que el investigador se puede enfrentar a la disyuntiva sobre si se prefiere a) usar covariables completas (en el sentido que no tienen casos faltantes) pero con una menor relación con la/s variable/s de estudio o si se prefiere b) covariables incompletas pero más fuertemente relacionadas con estas últimas. Siempre pensando en casos algo extremos, en el primer caso el balanceo será efectivo, pero quizá contraproducente porque balanceará la muestra con variables que no se encuentran empíricamente relacionadas con la variable de estudio. En el segundo caso se aumentan los problemas de cobertura (#emph[undercoverage error]) y se disminuye la precisión de la muestra por trabajar con menos casos.

Para poner un ejemplo, las variables "sondeo\_primero" y "sondeo\_segundo" podrían ser opciones como covariables (siempre igual dependiendo de que se quiera investigar) pero tienen una alta tasa de no respuesta o de dato faltante (+ de 550 casos). Y parece ser que esta ausencia de datos se distribuye de manera desigual entre la población de los establecimientos, ya que los mismos se concentran en establecimientos con una matrícula de menos de 10 estudiantes. En este caso su uso como covariables generaría un sesgo (#emph[bias]) muestral por el problema de la falta de cobetura porque los casos que integran la muestra (p.e. Ámbito Urbano) son diferentes a los que no integran (p.e. Ámbitos Rurales). En otras palabras, la ausencia de datos no es aleatoria por lo que los van a quedar dentro de la muestra serán, por diseño, diferentes a los que quedaran fuera de la misma.#footnote[En este sentido, más que nada por razones pedagógicas, aquí se han elegido como covariables, un conjunto de variables con poco margen de no respuesta. Esto se debe a que, si se hubieran escogido covariables con una alta tasa de no respuesta, se presenta el problema de contra que conjunto de datos testear las bondades de la técnica del balanceo. Esto es así dado que si los resultados de la técnica del cubo se comparan contra los totales poblacionales de los colegios (#ref(<tbl-parametros_base>, supplement: [Tabla])) es esperable que los resultados vayan a ser diferentes porque, estrictamente, el balanceo se realiza solo sobre los establecimientos que tienen la información auxiliar pertinente. Lo mismo, #emph[mutatis mutandis], si se compara la técnica del balanceo con la respectiva muestra de azar simple de toda la población de colegios (#ref(<tbl-azar_simple>, supplement: [Tabla])).]

=== Muestra Balanceada - Población Establecimientos
<sec-cubo_colegios>
En esta primera aplicación del muestreo del cubo con la base de establecimientos vamos a tener como objetivo tener una muestra de la población de establecimientos y no, por ejemplo, de los estudiantes. En el primer caso, en principio, las probabilidades de inclusión son iguales para cada establecimiento. Como veremos más adelante (#ref(<sec-cubo_estudiantes>, supplement: [Sec.])) esta técnica también permite realizar muestras con diferentes probabilidades de inclusión.

En la #ref(<tbl-cubo_colegios>, supplement: [Tabla]) se puede observar los resultados de la muestra balanceada para colegios. En esta tabla los resultados se comparan contra los resultados anteriores de la muestra de azar simple y los respectivos totales poblacionales. Como se aclaró anteriormente en estas tablas no se van a incluir ni el error estándar ni los intervalos de confianza dada lo incómodo de su cálculo y posterior visualización en tablas. De todos modos, se alcanza a visualizar que en muchas de las variables analizadas existe una pequeña mejora con la excepción de algunas categorías de la variable Región.#footnote[Es posible que parte de los mayores sesgos en algunas categorías de la variable Región se deban a que la falta de datos en algunas de las covariables elegidas sea desigual según Región. De todos modos, la cantidad de casos (establecimientos) que no tenían las covariables completas era 9.]

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,center,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Balanceo Colegios]
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Azar Simple]
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Pob. Colegios]
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.159]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[269,2], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[276,6], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[267,9],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[secciones], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,2], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,6], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,2],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_primero], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57,4], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[56,2], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57,3],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[610], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[472], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[560],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_segundo], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69,1], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69,8], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69,5],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[638], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[556], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[570],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[region], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,5% (189)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~02], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,3% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (223)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~03], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (210)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~04], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7,0% (n=21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1% (213)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~05], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (194)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~06], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (148)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~07], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (138)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~08], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (149)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~09], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,7% (n=20)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9% (205)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,0% (n=18)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,7% (n=20)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (224)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,0% (n=18)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (166)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (155)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1% (131)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~14], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1% (169)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~15], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2% (174)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~16], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (125)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~17], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,0% (n=18)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,2% (133)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~18], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (160)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~19], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (118)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~20], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (159)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~21], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (117)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~22], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (153)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~23], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (153)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~24], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (196)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~25], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7% (n=5)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (166)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ambito], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Urbano], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[64,0% (n=192)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[67,0% (n=201)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65,4% (2.727)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Disperso], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[28,7% (n=86)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20,3% (n=61)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[25,7% (1.073)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Agrupado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7,3% (n=22)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12,7% (n=38)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8% (368)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9],
  table.hline(),
  table.footer(table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] Media (DE); % (n sin ponderar)],
    table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2]] Media; % (n)],),
)}
], caption: figure.caption(
position: top, 
[
Estimaciones con muestra balanceada para colegios
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-cubo_colegios>


=== Muestra Balanceada - Población Estudiantes
<sec-cubo_estudiantes>
En esta pequeña sección vamos a observar la flexibilidad de la técnica del cubo obteniendo una muestra en donde las probabilidades de inclusión son diferentes. En este caso particular se aplicará el criterio que esas probabilidades sean proporcionales al tamaño de la matrícula aunque, claro está, esas probabilidades de inclusión diferentes podrían ser diferentes. Por ejemplo, se podría especificar que en una muestra tipo panel, que los establecimientos que entraron en la muestra el año pasado tengan más chances de (volver a) entrar en la misma. Esto tiene consecuencias similares a lo visto en el muestreo PPS (#ref(<sec-pps>, supplement: [Sec.])) en donde, por diseño, los establecimientos con mayor matrícula tienen una mayor chance de ser incluidos en la muestra. La diferencia con el muestreo PPS es que el muestreo balanceado permite, además, un trabajar con un conjunto de otras covariables que, nuevamente, reducen las chances que la muestra finalmente seleccionada sean una de las pocas (muy) sesgadas.

A continuación, en la #ref(<tbl-cubos_matricula_comparacion>, supplement: [Tabla]) puede observarse como esta muestra tiene resultados aceptables en cuanto a su cercanía con los respectivos parámetros poblacionales (que fueron ponderados por el valor de la matrícula). En cuanto a su comparación con la muestra PPS sin ponderar no parece registrarse mejoras sustanciales dado que, por azar, la muestra PPS ya era lo suficientemente buena. La diferencia es que la técnica de balanceo, gracias al algoritmo del cubo, #strong[asegura] que no saldrá una mala muestra mientras que con el PPS se trata de confiar en que uno no tendrá mala suerte para que, por azar, se produzca una mala muestra.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,center,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Cubo Matrícula]
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[PPS sin ponderar]
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Pob. matricula]
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[524,4], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[529,5], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[524,2],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[secciones], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19,7], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19,7], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19,6],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_primero], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[54,0], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[54,1], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[53,8],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_segundo], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[68,0], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[67,9], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[67,7],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[region], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,3% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,3% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,8% (n=189)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~02], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,7% (n=26)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7,0% (n=21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7,9% (n=222)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~03], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,7% (n=26)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9,7% (n=29)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9,9% (n=210)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~04], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9,3% (n=28)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13,7% (n=41)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9,2% (n=213)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~05], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10,7% (n=32)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7,0% (n=21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9,5% (n=194)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~06], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2% (n=148)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~07], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=138)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~08], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,0% (n=18)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,7% (n=17)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,1% (n=149)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~09], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10,0% (n=30)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,3% (n=34)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10,5% (n=204)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1% (n=221)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9,0% (n=27)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,3% (n=166)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,4% (n=155)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,5% (n=131)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~14], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,0% (n=3)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7% (n=169)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~15], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7% (n=172)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~16], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,0% (n=3)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,0% (n=0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,9% (n=125)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~17], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,0% (n=3)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,7% (n=2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,8% (n=133)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~18], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0% (n=160)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~19], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,9% (n=118)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~20], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,0% (n=3)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,8% (n=159)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~21], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,0% (n=3)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,9% (n=117)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~22], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (n=153)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~23], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,9% (n=151)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~24], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,7% (n=2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,7% (n=2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,1% (n=196)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~25], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7% (n=5)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7% (n=5)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,4% (n=166)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ambito], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Urbano], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[96,3% (n=289)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[95,3% (n=286)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[96,1% (n=2.723)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Disperso], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,3% (n=4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7% (n=5)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,9% (n=1.070)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Agrupado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,1% (n=366)],
)}
], caption: figure.caption(
position: top, 
[
Comparación muestra balanceada por la matrícula y muestra PPS sin ponderar y poblacion de establecimientos ponderada por matrícula
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-cubos_matricula_comparacion>


== Muestreos bien distribuidos
<sec-bien_distribuido>
Como se dijo en la #ref(<sec-cubo>, supplement: [Sec.]), en los muestreos balanceados por el método del cubo el esfuerzo está en que los valores de la tendencia central de los estimadores de determinadas variables de la muestra se acerquen a los valores de #strong[tendencia central] de las covariables existentes como información secundaria, esto es, a los parámetros conocidos de la población. En el muestreo bien distribuido o bien extendido (#emph[well spread]) es objetivo es similar, pero con una restricción adicional que implica que #strong[la distribución] de la/s covariable/s de la muestra se acerque a la distribución de la/s covariable/s en la población. El precio de esta mejora es que se debe conocer la distribución de esas variables en la población algo que, hasta ahora, nunca habían requerido los diseños anteriores. En el caso particular de la distribución espacial el diseño exige la introducción de las coordenadas de cada miembro de la población y no solo el promedio poblacional de ellas.

En este contexto cobra importancia el ejemplo inicial de la #ref(<fig-muestreo_cube_ejemplo>, supplement: [Figura]) en donde se usaron covariables espaciales. Allí, de manera intuitiva, se asoció que una muestra bien distribuida es una muestra balanceada. Esta afirmación, útil como una primera aproximación, es verdadera pero su inversa no. En otras palabras, toda muestra balanceada no es, necesariamente, una muestra bien distribuida, pero toda muestra bien distribuida sí es, necesariamente, una muestra balanceada.

A continuación trabajaremos con la misma muestra balanceada de colegios de la sección anterior, pero le agregaremos la condición de que esa muestra #emph[también] sea bien distribuida en los valores de las coordenadas geográficas de los establecimientos. Para eso primero agregaremos las coordenadas a la base de los establecimientos y luego nos quedaremos con solo aquellos establecimientos que tengan las coordenadas.

Agregadas las coordenadas ahora se puede aplicar la técnica del cubo con el adicional que el balanceo no solo se realice por los valores de tendencia central de la sección anterior, sino también con los valores de dispersión de las coordenadas de los establecimientos.

En cierto sentido, la inclusión de las variables "Ámbito" y "Región" en el diseño balanceado (#ref(<sec-cubo_colegios>, supplement: [Sec.])) ya mejoraban la distribución geográfica o espacial de la muestra (con respecto a una muestra de azar simple) pero lo hacían focalizándose en sus valores de tendencia central. Los valores de las coordenadas permiten una información de un grano más fino sobre la distribución espacial de la muestra lo que no es un dato menor. Si se asume que el espacio es una especie de meta-variable en las ciencias sociales @small2019, controlar la muestra por el espacio ayuda a controlar una serie de otras características que poseen eficacia causal, pero que usualmente son inobservables o de difícil registro. Expresado en la jerga del diseño estadístico de las investigaciones, este tipo de mejoras ayudan a que dentro del conjunto de variables extrañas al comienzo de la investigación, gracias al diseño de la misma, pasen ser variables controladas en vez de pasar a ser variables perturbadoras @kish1987. De todos modos, cabe destacar que las coordenadas son de los establecimientos y no de los estudiantes o, más en general, de las personas. El supuesto implícito es que la ubicación de los establecimientos guarda una relación estrecha con la ubicación de los estudiantes.

Desde un costado más operativo el algoritmo que se utiliza es el algoritmo del "#emph[local cube]" @tillé2013 que ya había sido utilizado en el muestro PPS. Este algoritmo penaliza si se seleccionan 2 casos "localmente" cercanos entre sí y luego de haber seleccionado un caso hay pocas chances que se seleccione otro caso muy cercano. La idea de distancia entre los casos es abstracta aunque en nuestro ejemplo se puede interpretar como distancia espacial.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,center,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Bien distribuida]
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Balanceo colegios]
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Pob. Colegios]
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.156]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.159]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[268,0 (2,8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[269,2], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[267,9],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[secciones], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,1 (0,1)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,2], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,2],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_primero], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[58,0 (0,2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57,4], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57,3],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_segundo], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[68,5 (0,2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69,1], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69,5],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[region], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,5% (189)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~02], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,7% (n=17)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (223)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~03], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (210)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~04], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1% (213)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~05], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (194)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~06], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (148)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~07], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (138)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~08], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (149)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~09], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9% (205)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,0% (n=18)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (224)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,0% (n=18)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (166)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (155)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1% (131)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~14], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1% (169)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~15], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2% (174)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~16], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (125)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~17], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,0% (n=18)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,2% (133)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~18], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (160)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~19], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (118)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~20], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (159)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~21], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (117)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~22], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (153)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~23], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (153)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~24], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (196)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~25], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7% (n=5)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (166)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ambito], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Urbano], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65,0% (n=195)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[64,0% (n=192)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65,4% (2.727)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Disperso], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26,7% (n=80)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[28,7% (n=86)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[25,7% (1.073)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Agrupado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,3% (n=25)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7,3% (n=22)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8% (368)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[610], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[560],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[638], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[570],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9],
  table.hline(),
  table.footer(table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] Media (DE); % (n sin ponderar)],
    table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2]] Media; % (n)],),
)}
], caption: figure.caption(
position: top, 
[
Comparación entre muestra bien distribuida, balanceada y población de establecimientos
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-bien_distribuida>


Como puede observarse en #ref(<tbl-bien_distribuida>, supplement: [Tabla]), al usarse la distribución de las coordenadas como covariables se aprecia una leve mejora en los valores que tienen una fuerte influencia espacial (p.e "Ambito" y "Región"). Sin embargo, una manera más visual de captar esta mejora es, al igual que en la #ref(<fig-muestreo_cube_ejemplo>, supplement: [Figura]), a través de un mapa como el de la #strong[?\@fig-mapa\_bien\_distribuida].

= Calibración
<sec-calibracion>
La estrategia de la calibración está compuesta por un conjunto de prácticas que aspiran a lograr objetivos similares al proceso del balanceo del cubo pero con métodos cualitativamente diferentes. La principal diferencia radica en que la calibración se realiza #emph[ex-post] la ejecución de la muestra (o sea, en el momento de la estimación) y no #emph[ex-ante] (o sea, en el momento del diseño) @deville2004[pág. 907]. Esto es una diferencia fundamental que emparenta a la calibración con el enfoque del "#emph[Model Assisted]" y la aleja del "#emph[Design Based]"#footnote[En cambio el balanceo, si bien en su origen tiene una fuerte vinculación con el enfoque del "Model Assisted", no se encuentra tan alejado del "design based" dado que el algoritmo del cubo selecciona muestras balanceadas dentro del conjunto de muestras aleatorias @tillé2010[pág. 39].]. En efecto, tanto el balanceo como la calibración pueden considerarse prácticas relativamente generales que, en su interior, incluyen otras prácticas más específicas. Esto es lo que habilita a afirmar que, por ejemplo, la estratificación es un caso particular del balanceo así como la post-estratificación es un caso particular de la calibración @tillé2011[pág. 223].

Otra diferencia entre el balanceo y la calibración es que para realizar la calibración en algunas situaciones (esto depende de la técnica específica seleccionada) solo es necesario los totales de la población y no, como en el balanceo, los valores de cada unidad que compone esa población.

Las características anteriores hacen que el proceso de calibración sea muy útil en momentos en donde existe conocimientos sobre algunos totales de la población y no se haya podido controlar mucho el proceso de diseño de la muestra (p.e. diseños no probabilistas) o diseños probabilistas pero con una alta tasa de no respuesta. Estas características hacen al proceso de calibración algo muy deseado para muchas investigaciones contemporáneas en donde pueda admitirse que se conocen algunos parámetros poblacionales y, por ejemplo, se ha realizado una muestra que se difundió de manera virtual a través de un link que circuló por diferentes redes sociales. Esto deja en pie la discusión sobre que "tan buenos" podrán ser los resultados de esa investigación, pero no parece haber muchas dudas que la investigación del ejemplo anterior será mejor si se le realiza un proceso de calibración mientras que será peor si no se realiza ese proceso.#footnote[Este tipo de discusiones ha enfrentado (y por ahora continúa enfrentando) a los representantes de los enfoques de la "#emph[design based sample]" y del "#emph[model assisted]". Los primeros suelen dudar de los beneficios de aplicar la calibración sobre diseños no probabilísticos aunque no suelen tener objeciones cuando la calibración se realiza sobre diseños probabilísticos @elliott2017. En el fondo lo que está en juego son los grados de garantía que ofrece cada técnica acerca de la representatividad y esto no solo incluya la discusión sobre las heterogeneidades observables (algo mantenido por ambos enfoques) sino también sobre las heterogeneidades no observables (algo históricamente mantenido por el enfoque de la "#emph[design]").]

En cuanto a su pertinencia, siempre que haya disponibilidad de tiempo (y el saber necesario para realizarlo) es aconsejable realizar una calibración. Esto es cierto al menos porque el balanceo tiene el problema del redondeo (las muestras son muestras de números enteros) y la calibración no, ya que puede construirse calibradores con números racionales. Por esta misma razón, aun cuando se haya realizado una muestra con un diseño por balanceo, es recomendable calibrar con los totales de las variables que se usaron en el proceso de balanceo.

Detalladas algunas diferencias entre la calibración y el balanceo ahora se pasa a diferenciar la calibración (de una muestra) de la imputación (de variables específicas).

- En cuanto a su producto, la calibración produce como resultado un calibrador (o un nuevo ponderador en la situación que el diseño de la muestra ya cuente con un ponderador) que es único para cada caso seleccionado en la muestra. En cambio la imputación, al menos como acá se la está entendiendo, es un proceso que tiene como objetivo estimar el valor faltante de una variable de los casos que respondieron de forma incompleta la muestra. En este sentido, un caso efectivamente seleccionado en la muestra puede tener más un valor imputado (p.e. para la variable ingresos y para la variable autopercepción de género) y, en cambio, otro caso puede que no tenga ninguno (p.e. si ese caso tuvo respuestas en todas las variables). En otros contextos se suele diferenciar a ambos procesos afirmando que la calibración ayuda a mitigar el problema del #emph[unit-not-response] y la imputación ayuda a mitigar el problema del #emph[ítem-not-response] \[#cite(<lumley2010>, form: "prose"), pág. 136\]@lundström2009[pág. 9].

- En cuanto a los insumos, la calibración necesita los totales poblacionales y, en cambio, la imputación necesita los valores de las otras variables que el caso a imputar ha respondido así como los valores de las covariables y la variable a imputar de los otros casos.

- En cuanto al momento de la investigación, siempre que se usen ambos procesos, usualmente primero se imputa los casos particulares de las variables que se considera pertinente y luego se calibra la muestra incluyendo los valores de los casos imputados. Este orden es particularmente importante si se confía en el proceso de la imputación y la/s variable/s imputadas son parte del proceso de calibración como covariables.

Por último, a veces se suele asimilar como sinónimos en término calibración con el término post-estratificación. Más arriba ya se había comentado que el segundo puede considerarse como un caso particular (aunque quizás el más difundido) del primero en donde solo se utilizan variables categóricas (estratos) para el proceso de la calibración. Lo mismo puede afirmarse del método menos difundido del "raking" que permite la calibración de múltiples variables categóricas sin la necesidad de realizar cruces entre ellas con el riesgo de no tener casos en la muestra de algunas de las celdas de los múltiples cruces @lumley2010[pág. 139]. Por esta razón, aquí usaremos directamente el método de la calibración por ser el más general, ya que permite la inclusión tanto de variables categóricas como continuas y no presenta los riesgos de la post-calibración en cuanto a la posible ausencia de casos frutos de los cruces de las variables categóricas.

A continuación vamos a trabajar con 2 ejemplos alternativos. Uno, en donde la calibración se realiza sobre la muestra aleatoria simple y otra que se realiza sobre la muestra balanceada y bien distribuida. En función de lo visto anteriormente (#ref(<sec-azar_simple>, supplement: [Sec.]), #ref(<sec-cubo>, supplement: [Sec.]) y #ref(<sec-bien_distribuido>, supplement: [Sec.])) ya sabemos que ambas calibraciones van a partir desde un punto de inicio diferente. Veremos que tanta distancia entre sí y con respecto a los parámetros poblaciones van a tener los respectivos puntos de llegada (esto es, las estimaciones de ambas muestras) luego de realizar la calibración. En otras palabras, la muestra balanceada y bien distribuida ya se encontraba (en general) bastante cerca de los parámetros poblacionales por lo que, a priori, cuenta con alguna ventaja desde su puesto de largada.

== Calibración muestra azar simple
<calibración-muestra-azar-simple>
Comenzaremos haciendo la calibración sobre nuestra muestra realizada por azar simple y su resultado lo comparemos con la respectiva muestra de azar simple (sin calibrar) y con los respectivos parámetros poblacionales. Vamos a ver que, en comparación con otras técnicas, la mayor flexibilidad de la calibración se paga con una mayor especificación de los parámetros de sus funciones#footnote[En otras palabras, si ya se sabe de antemano que se va a realizar una post-estratificación es más simple utilizar una función específica para post-estratificar (p.e. la función "poststratify" de la librería survey o "poststrata" de la librería sampling).].

Para eso vamos a recuperar el objeto con el cual le informábamos a R que habíamos realizado una muestra aleatoria simple (#ref(<sec-azar_simple>, supplement: [Sec.])). Ese va a ser nuestro primer insumo al cual le vamos a realizar la calibración y para eso es importante el proceso de la selección y armado de las covariables. Esta parte es similar en espíritu a lo realizado en el proceso de balanceo, pero la parte operativa tiene pequeñas diferencias como se observa en el siguiente código.

#block[
#Skylighting(([#NormalTok("Sample:  [1] \"(Intercept)\"          \"matricula\"            \"ambitoRural Disperso\"");],
[#NormalTok(" [4] \"ambitoRural Agrupado\" \"region02\"             \"region03\"            ");],
[#NormalTok(" [7] \"region04\"             \"region05\"             \"region06\"            ");],
[#NormalTok("[10] \"region07\"             \"region08\"             \"region09\"            ");],
[#NormalTok("[13] \"region10\"             \"region11\"             \"region12\"            ");],
[#NormalTok("[16] \"region13\"             \"region14\"             \"region15\"            ");],
[#NormalTok("[19] \"region16\"             \"region17\"             \"region18\"            ");],
[#NormalTok("[22] \"region19\"             \"region20\"             \"region21\"            ");],
[#NormalTok("[25] \"region22\"             \"region23\"             \"region24\"            ");],
[#NormalTok("[28] \"region25\"            ");],
[#NormalTok("Popltn:  [1] \"\"  \"\"  \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\"");],
[#NormalTok("[20] \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\"");],));
]
#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (16.67%, 16.67%, 16.67%, 16.67%, 16.67%, 16.67%),
  align: (left,center,center,center,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: center, colspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    AS Calibrado
    ]], table.cell(align: center, colspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    AS sin calibrar
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    Poblacion
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[95% CI]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[95% CI]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[267 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[267, 267], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[276,6 (2,9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[271, 282], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[267,9],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[secciones], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11, 11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,6 (0,1)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11, 12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,2],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_primero], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[56, 57], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[56,2 (0,2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[56, 57], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57,3],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[568], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[472], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[560],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_segundo], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[70 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69, 70], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69,8 (0,2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69, 70], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69,5],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[647], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[556], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[570],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[region], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,5% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,5%, 4,5%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0%, 2,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,5% (189)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~02], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4%, 5,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,3% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,8%, 6,9%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (223)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~03], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0%, 5,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9%, 5,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (210)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~04], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1% (n=21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1%, 5,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7,0% (n=21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,5%, 7,6%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1% (213)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~05], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7%, 4,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3%, 3,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (194)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~06], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 3,6%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3%, 4,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (148)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~07], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3%, 3,3%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3%, 4,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (138)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~08], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 3,6%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9%, 5,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (149)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~09], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9% (n=20)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9%, 4,9%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,7% (n=20)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,1%, 7,2%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9% (205)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (n=20)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4%, 5,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,7% (n=20)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,1%, 7,2%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (224)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0%, 4,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,9%, 4,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (166)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0%, 2,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (155)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1%, 3,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3%, 3,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1% (131)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~14], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1%, 4,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1% (169)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~15], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2%, 4,2%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2% (174)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~16], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0%, 3,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7%, 2,3%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (125)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~17], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,2% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,2%, 3,2%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,2% (133)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~18], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8%, 3,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7%, 3,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (160)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~19], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8%, 2,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3%, 3,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (118)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~20], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8%, 3,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3%, 4,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (159)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~21], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8%, 2,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,7%, 2,3%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (117)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~22], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 4,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (153)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~23], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2%, 5,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (153)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~24], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7%, 4,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7%, 3,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (196)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~25], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0%, 4,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9%, 5,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (166)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ambito], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Urbano], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65% (n=201)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65%, 65%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[67,0% (n=201)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[66%, 68%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65,4% (2.727)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Disperso], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26% (n=61)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26%, 26%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20,3% (n=61)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19%, 21%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[25,7% (1.073)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Agrupado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8% (n=38)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8%, 8,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12,7% (n=38)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12%, 13%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8% (368)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9],
  table.hline(),
  table.footer(table.cell(colspan: 6)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] Media (SE); % (n=n (unweighted))],
    table.cell(colspan: 6)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2]] Media; % (n)],
    table.cell(colspan: 6)[Abreviacion: CI = Intervalo de confianza],),
)}
], caption: figure.caption(
position: top, 
[
Calibración muestra azar simple
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-azar_simple_calibrado>


Como puede observarse en #ref(<tbl-azar_simple_calibrado>, supplement: [Tabla]) la calibración ha mejorado sensiblemente la muestra de azar simple en casi todas las variables, aún en aquellas que no se usaron activamente en la matriz de calibración. En efecto, en la mayoría de las variables los valores de la muestra calibrada se acercan mucho a los parámetros poblacionales.

Un paso adicional que se puede realizar si luego se quiere trabajar en una planilla de cálculo o, más en general, por fuera de R, es agregar los respectivos ponderadores del proceso de calibración al objeto para así tenerlos como una variable más. En este sentido, la base de datos con los casos seleccionados de la muestras ahora pasaría a tener 2 variables especiales que servirían para el proceso de expansión de la muestra a la población. Uno, un ponderador que ya existía luego de haber realizado el azar simple (y que era igual para todos los casos) y otro recientemente agregado, el calibrador, que es específico para cada caso.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 7,
  align: (right,right,center,right,right,right,right,),
  table.header(table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); matricula], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); secciones], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ambito], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); sondeo\_primero], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); sondeo\_segundo], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); pond\_weight], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); cal\_weight],),
  table.hline(),
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[100], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[42.46154], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[52.88889], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.89333], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12.51390],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[122], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57.11538], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[50.27273], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.89333], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.50510],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[78], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[79.93750], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[75.41667], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.89333], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[23.16509],
)}
], caption: figure.caption(
position: top, 
[
Ponderadores y calibradores. Base muestra azar simple.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-base_muestra_AS_cal>


== Calibración muestra bien distribuida
<sec-cal_bien_distribuida>
En el caso de la calibración de la muestra bien distribuida el proceso de calibración es similar con la diferencia que cambia el insumo al cual se le realiza la calibración. Aquí el código es un poco más simple porque se reutiliza la matriz de covariables construida para la calibración de la muestra de azar simple.

#block[
#Skylighting(([#NormalTok("Sample:  [1] \"(Intercept)\"          \"matricula\"            \"ambitoRural Disperso\"");],
[#NormalTok(" [4] \"ambitoRural Agrupado\" \"region02\"             \"region03\"            ");],
[#NormalTok(" [7] \"region04\"             \"region05\"             \"region06\"            ");],
[#NormalTok("[10] \"region07\"             \"region08\"             \"region09\"            ");],
[#NormalTok("[13] \"region10\"             \"region11\"             \"region12\"            ");],
[#NormalTok("[16] \"region13\"             \"region14\"             \"region15\"            ");],
[#NormalTok("[19] \"region16\"             \"region17\"             \"region18\"            ");],
[#NormalTok("[22] \"region19\"             \"region20\"             \"region21\"            ");],
[#NormalTok("[25] \"region22\"             \"region23\"             \"region24\"            ");],
[#NormalTok("[28] \"region25\"            ");],
[#NormalTok("Popltn:  [1] \"\"  \"\"  \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\"");],
[#NormalTok("[20] \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\" \"n\"");],));
]
#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (left,center,center,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: center, colspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    BD calibrado
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    BD sin calibrar
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    Poblacion
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[95% CI]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.156]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[3]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[267 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[267, 267], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[268,0 (2,8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[267,9],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[secciones], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11, 11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,1 (0,1)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,2],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_primero], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[58 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[58, 58], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[58,0 (0,2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57,3],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[478], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[560],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_segundo], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[68, 69], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[68,5 (0,2)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69,5],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[543], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[570],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[region], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,5% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,5%, 4,5%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,5% (189)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~02], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (n=17)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4%, 5,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,7% (n=17)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (223)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~03], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0%, 5,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (210)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~04], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1%, 5,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1% (213)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~05], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7%, 4,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,3% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (194)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~06], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 3,6%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (148)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~07], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3%, 3,3%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (138)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~08], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 3,6%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (149)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~09], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9%, 4,9%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9% (205)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4%, 5,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (224)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0%, 4,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (166)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (155)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1%, 3,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1% (131)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~14], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1%, 4,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1% (169)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~15], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2%, 4,2%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2% (174)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~16], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0%, 3,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (125)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~17], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,2% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,2%, 3,2%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,2% (133)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~18], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8%, 3,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (160)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~19], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8%, 2,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (118)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~20], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8%, 3,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (159)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~21], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8%, 2,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (117)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~22], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (153)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~23], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (153)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~24], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7%, 4,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (196)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~25], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0%, 4,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (166)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ambito], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Urbano], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65% (n=195)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65%, 65%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65,0% (n=195)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65,4% (2.727)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Disperso], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26% (n=80)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26%, 26%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26,7% (n=80)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[25,7% (1.073)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Agrupado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8% (n=25)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8%, 8,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,3% (n=25)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8% (368)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9],
  table.hline(),
  table.footer(table.cell(colspan: 5)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] Media (SE); % (n=n (unweighted))],
    table.cell(colspan: 5)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2]] Media (DE); % (n sin ponderar)],
    table.cell(colspan: 5)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[3]] Media; % (n)],
    table.cell(colspan: 5)[Abreviacion: CI = Intervalo de confianza],),
)}
], caption: figure.caption(
position: top, 
[
Calibración muestra bien distribuida
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-bien_distribuida_cal>


Al igual que con la calibración de la base de la muestra de azar simple, aquí vamos a extraer los calibradores para luego agregarlos a la base de datos.

Es interesante destacar, como se observa en la #ref(<tbl-base_muestra_BD_cal>, supplement: [Tabla]) (y a diferencia de lo visto en la #ref(<tbl-azar_simple_calibrado>, supplement: [Tabla])) que acá no sólo los calibradores son diferentes entre sí sino que también lo eran ponderadores de la muestra bien distribuida.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 7,
  align: (right,right,center,right,right,right,right,),
  table.header(table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); matricula], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); secciones], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ambito], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); sondeo\_primero], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); sondeo\_segundo], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); pond\_weight], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); cal\_weight],),
  table.hline(),
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[533], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[24], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[58.11111], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[70.60484], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.85333], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.46208],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[668], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[24], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[38.02857], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[73.39394], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.85333], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.32084],
  table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[340], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[60.08219], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[85.81707], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.85333], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.66400],
)}
], caption: figure.caption(
position: top, 
[
Ponderadores y calibradores. Base muestra bien distribuida.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-base_muestra_BD_cal>


== Comparación calibración muestra balanceada y azar simple
<comparación-calibración-muestra-balanceada-y-azar-simple>
Finalmente vamos a realizar una comparación entre los resultados de los procesos de calibración antes realizados y los respectivos parámetros poblacionales. Esto es lo que precisamente se observa en la #ref(<tbl-comp_calibraciones>, supplement: [Tabla]).

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (16.67%, 16.67%, 16.67%, 16.67%, 16.67%, 16.67%),
  align: (left,center,center,center,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: center, colspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    BD calibrado
    ]], table.cell(align: center, colspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    AS calibrado
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    Poblacion
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[95% CI]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[95% CI]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 4.168]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[267 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[267, 267], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[267 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[267, 267], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[267,9],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[secciones], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11, 11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11, 11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,2],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_primero], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[58 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[58, 58], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[56, 57], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57,3],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[478], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[568], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[560],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sondeo\_segundo], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[68, 69], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[70 (0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69, 70], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69,5],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[543], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[647], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[570],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[region], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,5% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,5%, 4,5%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,5% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,5%, 4,5%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,5% (189)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~02], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (n=17)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4%, 5,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (n=19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4%, 5,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (223)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~03], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0%, 5,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0%, 5,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,0% (210)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~04], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1%, 5,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1% (n=21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1%, 5,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1% (213)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~05], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7%, 4,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7%, 4,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (194)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~06], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 3,6%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 3,6%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (148)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~07], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3%, 3,3%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3%, 3,3%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,3% (138)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~08], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 3,6%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6%, 3,6%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,6% (149)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~09], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9%, 4,9%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9% (n=20)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9%, 4,9%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,9% (205)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4%, 5,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (n=20)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4%, 5,4%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4% (224)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0%, 4,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=13)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0%, 4,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (166)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (155)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1%, 3,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1%, 3,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,1% (131)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~14], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1%, 4,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1%, 4,1%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,1% (169)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~15], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2% (n=15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2%, 4,2%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2%, 4,2%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,2% (174)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~16], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0%, 3,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0%, 3,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,0% (125)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~17], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,2% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,2%, 3,2%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,2% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,2%, 3,2%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,2% (133)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~18], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8%, 3,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8%, 3,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (160)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~19], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8%, 2,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (n=8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8%, 2,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (118)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~20], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8%, 3,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (n=11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8%, 3,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,8% (159)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~21], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8%, 2,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (n=6)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8%, 2,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,8% (117)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~22], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (153)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~23], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7%, 3,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,7% (153)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~24], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7%, 4,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (n=9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7%, 4,7%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,7% (196)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~25], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0%, 4,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (n=16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0%, 4,0%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0% (166)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ambito], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Urbano], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65% (n=195)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65%, 65%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65% (n=201)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65%, 65%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65,4% (2.727)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Disperso], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26% (n=80)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26%, 26%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26% (n=61)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26%, 26%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[25,7% (1.073)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Agrupado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8% (n=25)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8%, 8,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8% (n=38)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8%, 8,8%], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,8% (368)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9],
  table.hline(),
  table.footer(table.cell(colspan: 6)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] Media (SE); % (n=n (unweighted))],
    table.cell(colspan: 6)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2]] Media; % (n)],
    table.cell(colspan: 6)[Abreviacion: CI = Intervalo de confianza],),
)}
], caption: figure.caption(
position: top, 
[
Comparación entre calibración de las muestras bien distribuidas, de azar simple y los respectivos parámetros poblacionales
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-comp_calibraciones>


En la #ref(<tbl-comp_calibraciones>, supplement: [Tabla]) puede observarse como ambas estrategias de calibración parecen igual de eficaces ya que ambas arrojan resultados muy similares entre sí y, a su vez, muy similares con los parámetros poblacionales. En este contexto se recuerda que, si bien los valores finales son muy similares, la mejora realizada en el proceso de calibración es mayor sobre el diseño de azar simple ya que esa muestra no era tan precisa como la muestra bien distribuida y, por lo tanto, existía la oportunidad de mejorar bastante.

#part[Aplicaciones prácticas]
= Muestra PEB 2025
<muestra-peb-2025>
Las pruebas PEB (Pruebas Escolares Bonaerenses) son un programa orientado a mejorar la enseñanza y el aprendizaje de Matemática y Prácticas del Lenguaje en el nivel Primario, tanto en el sector estatal como en el privado, que se puso en marcha en 2022 en la Provincia de Buenos Aires @subsecretaría2025[pág. 5].

Desde el punto de vista metodológico que tiene que ver con cuestiones muestrales es pertinente destacar que estas pruebas aspiran a ser realizadas al total de los estudiantes aunque luego se registran sus resultados a través de dos componentes diferentes. Un primer componente censal aunque con datos agregados y un segundo componente muestral con datos nominales. Lo que se detalla a continuación es el proceso de selección muestral de este segundo componente nominal. Primero lo haremos haciendo referencia a la muestra diseñada en 2023 y luego para la de 2025.

== Muestra 2023
<muestra-2023>
Para tener como referencia vamos a intentar representar el método de selección de la muestra que se utiliza desde 2023. Primero la vamos a intentar describir y luego clasificar.

=== Descripción
<descripción>
Un resumen descriptivo de la misma es la siguiente afirmación:

"En paralelo, se relevaron resultados por estudiante en una muestra probabilística de 680 escuelas. Para cada institución, se solicitó información sobre las respuestas a las actividades de 5 estudiantes seleccionados al azar por las y los docentes de cada sección" @subsecretaría2024[pág. 18].

Más en detalle también se afirma "La construcción de la muestra siguió un diseño probabilístico, con selección sistemática de las unidades de muestreo. Previo a la selección, en el marco muestral (nómina de establecimientos de nivel primario) se agruparon los establecimientos en estratos constituidos por el cruce de las variables “dependencia de los establecimientos educativos” (provincial y resto-incluyendo en este último grupo a los establecimientos privados, municipales y nacionales), “porcentaje de estudiantes con AUH”, “presencia o no de jornada completa” y “ámbito”. Luego, se ordenaron los establecimientos por estrato, y se realizó una selección sistemática siguiendo la fracción de muestreo correspondiente" @subsecretaría2024[pág. 18].

La descripción anterior alcanzaría para una descricpión de la selección de establecimientos. Pero todavía falta el paso que describe la selección de los estudiantes:

"Para cada sección de los años de estudio evaluados, se solicitó la selección de las/los primeros o últimos estudiantes de la lista (por orden alfabético) que hayan realizado la prueba. En secciones pequeñas (de hasta 10 estudiantes), se requirió la carga de información de todas y todos los estudiantes" @subsecretaría2024[pág. 18].

#block[
#callout(
body: 
[
No hace falta aclarar que intentar reconstruir una muestra a partir de descripciones en prosa suele ser una actividad arriesgada. Esto se debe a que puede haber confusiones entre los objetivos de la muestra, las acciones que se hicieron en el momento del diseño, las que efectivamente se hicieron en campo y, algo no menos importante, los términos que se usan para describir todo lo anterior.

Hay veces que, aunque parezca paradógico, para alguien que tiene que clasificar a una muestra, es preferible que le digan paso a paso que hicieron en un lenguaje cercano al sentido común sin usar términos propios de la jerga del muestreo. La razón es que en muestreo hay términos que tienen un significado particular que no es el mismo que tienen en otras disciplinas no tan lejanas. Por ejemplo, la palabra "estratificación" tanto en ciencias sociales con en el lenguaje común, suele tener una connotación ordinal, pero en muestreo tiene una connotación muy particular y no necesariamente ordinal. Del mismo modo, alguien con experiencia en análisis de datos entiende por "análisis de clústers (o conglomerados)" algo muy diferente a lo que un muestrista entiende cuando afirma que se realizó un "diseño muestral por conglomerados".

Lo anterior se complica porque es usual que en los diseños muestrales de las ciencias sociales se hagan diseños polietápicos lo que hace que, por ejemplo, circulen afirmaciones como "muestreo estratificado por conglomerados". En este caso es posible suponer más de una manera de entender esta afirmación y, #emph[a posteriori], más de una manera de haber diseñado o ejecutado esa muestra. Por ejemplo, ¿Se ejecutó primero en campo la parte de los conglomerados y luego se seleccionó por estratos? ¿O se hizo al revés? ¿El orden escrito se refiere a la "ejecución" de los pasos o refiere que momento se "diseñó" cada parte del diseño?

]
, 
title: 
[
Precaución
]
, 
background_color: 
rgb("#ffe5d0")
, 
icon_color: 
rgb("#FC5300")
, 
icon: 
none
, 
body_background_color: 
white
)
]
=== Clasificación
<clasificación>
En función de la bibliografía/léxico usado en las secciones anteriores se podría realizar los siguientes comentarios sobre las afirmaciones anteriores:

Antes que nada se observa una particularidad importante. En las PEB efectivamente se va a (casi) todas las unidades de la población de estudiantes. La muestra es solo para ver a cuáles de ellos se "registra" de forma individual. Esto es algo particular porque muchas de las técnicas de muestreo están pensadas para justamente evitar ir a todas las unidades de la población o, en su defecto, para a que a una determinada subpoblación (muestra) se le pueda hacer más preguntas, mediciones, ensayos, etc. que hacen más extensa y profunda y, por lo general, más onerosa la investigación. En lo que acá respecta, lo oneroso no parece la prueba en sí, sino su posterior carga nominal. Esto hace (re)pensar cuál es la población de la muestra:

¿Es la población de estudiantes de todo el nivel primario?

¿Es la población de estudiantes de algunos años específicos de nivel primario (p.e. 3 y 6) a los cuales se les piensa realizar las PEB?

¿Es la población de estudiantes de algunos años específicos de nivel primario (p.e. 3 y 6) a los que efectivamente se les realizó las PEB?

Cabe destacar que en una muestra típica solo se podría decidir entre las primeras dos poblaciones porque, como se comentó arriba, muchas veces uno de los objetivos de la muestra es evitar "ir" o "medir" a cada componente de la población. Sin embargo, en la PEB es posible también decidir que la tercera población sea la más idónea. En efecto, más allá de los posibles problemas de conseguir datos de esa población es claro que no tiene mucho sentido seleccionar estudiantes o secciones que no pertenecen a los establecimientos del "censo" previo.

Dejando estas cuestiones referidas sobre qué población se debería hacer la muestra, el diseño muestral anterior se podría #strong[clasificar] del siguiente modo:

- Un diseño #strong[polietápico]. En una primera etapa se seleccionan a los establecimientos y luego, en una segunda etapa, se seleccionan a los estudiantes de ese establecimiento a través de sus respectivas secciones. Se suele afirmar que los establecimientos son la unidad de selección primaria y los estudiantes son la unidad de selección secundaria y final. Es importante destacar que los establecimientos cumplen la función de ser un #strong[conglomerado] en este diseño. En otras palabras, cada establecimiento es como un racimo (#emph[cluster]) en donde se agrupan secciones y estudiantes. Por cuestiones logísticas es útil seleccionar primero a los establecimientos y luego a los estudiantes que están en su interior. En esta descripción no decimos nada sobre las secciones porque en las descripciones de arriba parecería que ellas no se "seleccionan" aunque más adelante diremos algo sobre esto.

- En la primera etapa se hace un diseño muestral #strong[estratificado] de establecimientos con asignación proporcional mediante un método de selección sistemático. Este diseño primero crea una serie de categorías discretas en las que se presume que la varianza de la/s variables a estimar son algo menor a la varianza promedio de toda la población. Esto permite una ganancia estadística que se puede usar tanto para aumentar la precisión de la estimación o para reducir la cantidad de casos de la muestra. Cuanto se logre esto último es una cuestión que depende de la asociación de las variables seleccionadas para construir los estratos con las variables a estimar. Lo que también (parcialmente) asegura este diseño es que se incluyan en la muestra casos de estratos chicos en tamaño que, mediante un diseño por azar simple, podrían quedar subrepresentados en la muestra.

- Decimos que la #strong[estratificación es de una asignación proporcional] porque la cantidad de casos a seleccionar para cada estrato estará en línea con los tamaños de estratos (no con los tamaños de los establecimientos). Esta muestra, al menos en este paso, intenta replicar la distribución porcentual de los estratos.

- Dentro de cada estrato la selección es #strong[sistemática], y por lo tanto, probabilística.

- En la segunda etapa se aplica una regla que apunta a resolver dos cuestiones diferentes. A "cuantos" y "a quienes" se le van a cargar los datos nominales. Respecto al "cuantos" parece que se resuelve con la regla de cargar todos los casos para las secciones de hasta 10 estudiantes y 5 para el resto. Aunque quizá pase más desapercibido, en esta seguda etapa las secciones cumplen la función de estrato, por lo que la segunda etapa se podría decir que se trata de una selección de estudiantes #strong[estratificada] por las secciones. En cambio, el "a quienes" se resuelve mediante una regla que selecciona a los "primeros o últimos estudiantes de la lista (por orden alfabético)". Esta regla tiene el beneficio de ser simple (siendo esto un punto a favor) aunque, en principio, es #strong[no probabilística] en el sentido que no se trata de selección por azar simple ni sistemática, etc. Su carácter no probabilísitica, no asegura que sea sesgada.

Si la #strong[clasificación] anterior es correcta se podrían hacer también los siguientes comentarios sobre esa muestra:

La afirmación "Para cada institución, se solicitó información sobre las respuestas a las actividades de 5 estudiantes seleccionados al azar por las y los docentes de cada sección" no parece coincidir con lo realizado. Lo que la muestra selecciona al azar son "establecimientos" pero no "estudiantes".

La regla sobre la discrecionalidad para que el docente elija los 5 primeros o los 5 últimos induce una dosis de arbitrariedad. La traducción de sí esto en un sesgo (o no) es una cuestión que, de forma aproximada, se puede resolver de forma empírica#footnote[Cuanto (o no) esta regla no probabilística es un sesgo en la muestra es una cuestión empírica. Una manera de generar un testeo podría ser la comparación de las medias porcentuales de la poseción de AUH, a nivel de sección y establecimiento, de los primeros 5 estudiantes con la media del respectivo grupo conformado por la sección y el establecimiento. Esto se puede hacer partiendo de una base nominal de estudiante y ordenando los apellidos por orden alfábetico para cada sección y establecimiento. En el primer caso, se calcula la media de los 5 primeros de cada grupo y en la segunda se incluyen a todos los estudiantes de cada grupo. Al realizar el cálculo a nivel de cada sección no solo se puede testear si ambas medias coinciden, sino que también se puede calcular su respectivo desvío.]. Por otro lado, si se asume que cada docente eligirá siempre al "mejor" grupo (comparando a los 5 primeros versus los 5 últimos) esto no generará un mayor problema en las comparaciónes entre establecimientos, secciones, etc. pero, posiblemente, sesge todos los resultados nominales de las pruebas hacia "arriba". En principio, esto se podría testear empíricamente comparando las medias de las notas muestrales de cada sección/establecimiento con las medias de las respectivas notas censales de las mismas secciones/establecimientos que entraron en la muestra.

En este diseño, al menos en su primera etapa, los estudiantes de los establecimientos más grandes tienen menores chances de salir en la muestra. Si esto no se corrige mediante ponderadores (#emph[ex-ante]) o calibradores (#emph[ex-post]) explícitos esto podría generar un sesgo en los análisis de los resultados. En otras palabras, si cada establecimiento dentro de un estrato tuvo la misma probabilidad de ser elegido de forma independientemente de su matrícula, entonces para esa primera etapa #strong[la probabilidad final de selección para un estudiante no es constante].

Algo de esto se corrige en la segunda etapa. Acá influye que la regla de cargar los datos sea por #strong[sección] y no por #strong[establecimiento]. Esta regla es la que legitima entender a la muestra anterior como una muestra polietápica en donde en la segunda etapa se usa un diseño estratificado por sección.

A primera vista las secciones podrían ser consideradas como conglomerados en donde seleccionar estudiantes de su interior asumiendo alguna ventaja logística si se selecciona solo una de ellas, por ejemplo, por azar simple. Sin embargo, la acción anterior podría ser conveniente si se asume que las secciones (de un mismo establecimiento) poseen una similar heterogeneidad con respecto a al variable de estudio (p.e. las notas en las PEB). De todos modos, dada la peculariedad de las PEB, la ventaja logística residiría en que hay menos docentes/administrativos que contactar y, no menos importante, menos por controlar después. Acá no habría nada de ventaja logísitica, por ejemplo, desde el punto de vista geográfico. La razón es que, por un lado, "ya se fue" a evaluar a cada estudiante y ahora quedaría decidir los datos de quien se registra de modo nominal.

Si se pasa al otro extremo de seleccionar a todas las secciones del establecimiento elegido (como efectivamente se hizo en la muestra 2024) no hay tal etapa de "selección" a nivel de las secciones. En ese caso las etapas de selección de la muestra son a nivel de los establecimientos y a nivel de los estudiantes, pasando por alto el nivel de las secciones. En efecto, la acción de ir a todas las secciones es #emph[como si] se hubiera tenido la intención de estratificar debido, quizás, a la sospecha de una posible escasa similitud entre las secciones de un mismo establecimiento. Siguiendo este modo de razonar, el investigador se asegura que los estudiantes sean seleccionados a través de diferentes secciones cumpliendo el deseo de un muestrista que estratifica para que luego se seleccionen los casos dentro de cada estrato. Hace unas líneas se dijo "#emph[como si]" hubiera tenido la intención de estratificar porque, estrictamente, no sabemos si se estratificó por la razón de reducir el error de la estimación (lo usual en esta técnica) o por si, por el contrario y/o de forma complementaria, por la consecuencia que trae usar este método en las probabilidades de selección de los estudiantes de los establecimientos con mayor matrícula.

De esta manera, a pesar de no ser la típica consecuencia buscada de la estratificación, aquellos establecimientos con mayor cantidad de secciones (y en general con mayor matrícula) pueden tener una mayor chances de incluir a sus estudiantes en la muestra. En efecto, en la #ref(<fig-matricula_seccion>, supplement: [Figura]) se observa una relación estrecha entre el tamaño de la matrícula y la cantidad de secciones del establecimiento.

#figure([
#box(image("muestra_peb_2025_files/figure-typst/fig-matricula_seccion-1.svg"))
], caption: figure.caption(
position: top, 
[
Relación entre el tamaño de la matrícula y la cantidad de secciones de los establecimientos
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-matricula_seccion>


Sin embargo, hacer un "censo" para las secciones pequeñas hace que se aumente la chance de seleccionar estudiantes de secciones pequeñas que, en general, pertenecen a establecimientos con una menor matrícula. A continuación se muestra en la #ref(<tbl-matricula_size_seccion>, supplement: [Tabla]) como las secciones de hasta 10 estudiantes suelen pertenecen a establecimientos con una media y una mediana de la matrícula muy por debajo de la que poseen las secciones más grandes.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,center,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Variable de Matrícula]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Chicas] \
    N = 7.026#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[No chica] \
    N = 65.866#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Matrícula Inicial 2025], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[61,9 16,0], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[461,6 430,0],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0],
  table.hline(),
  table.footer(table.cell(colspan: 3)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] Media Mediana],),
)}
], caption: figure.caption(
position: top, 
[
Comparación de la media y mediana de los establecimientos en función del tamaño de la sección (+- 10 estudiantes)
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-matricula_size_seccion>


En cualquier caso, las reglas identificadas de la selección de los estudiantes parece tener efectos contrapuestos y es algo difícil de estimar el impacto de cada uno por separado. En particular es difícil de construir ponderadores que anticipen (#emph[ex-ante]) el sesgo de estas decisiones. Claro que siempre se podrá recurrir al recurso de los calibradores (#emph[ex-post]) para usarlos al momento del análisis, aunque parece una estrategia algo arriesgada.

Una opción que se puede tener cuenta en estos casos es la inclusión del tamaño de la matrícula en la probabilidad de seleccionar al establecimiento en la primera etapa. Esta estrategia puede tener más de un beneficio. Uno de ellos es que permite una regla simple para la segunda etapa. En efecto, se podría registrar una misma cantidad de estudiantes por establecimiento de forma independiente a la cantidad de secciones. Esto tiene el beneficio adicional que, siguiendo ese diseño, la muestra se vuelve autoponderada lo que facilita los análisis posteriores. Claro está que serán necesario la construcción de calibradores que corrijan la no-respuesta, pero esto es un escenario cualitativamente diferente al descripto en el párrafo anterior. En este contexto, si la muestra no tiene, #emph[a posteriori], problemas de no-respuesta, no sería necesario la construcción de calibradores. Sin entrar en detalles (porque en parte se entremezclan un lenguaje de intenciones u objetivos con un lenguaje de métodos) se podría decir que se podrían aprovechar algunas de las características que ofrece el método conocido como muestreo proporcional al tamaño (#ref(<sec-pps>, supplement: [Sec.])).

Por último algunos comentarios van en línea sobre el espectro de inferencias posibles con la muestra 2023. En la biblografía sobre muestreo se suele hacer una distinción clásica entre los #strong[estratos] y los #strong[dominios] de estimación (#ref(<sec-estratificado>, supplement: [Sec.])). Los primeros se suelen usar en el diseño (#emph[ex-ante]) con la presunción de que en la población existen "clases" discretas que son parecidas en su interior y diferentes entre sí. Si esto es así, su inclusión en el diseño trae mejoras en la precisión en la estimación. En cambio, los dominios tienen que ver con los objetivos o intenciones posteriores del investigador para con la muestra. Por ejemplo, aun el contexto en que se tenga la hipótesis que los establecimientos y los estudiantes rurales poseen fuertes particularidades en contrapoisición a los urbanos. Un escenario es la inclusión de "ambito" como variable para la estratificación y otro escenario es que se quieran realizar inferencias para cada ámbito. En este último caso se dice que los diferentes ámbitos son dominios de estimación de la muestra.

Cuando los estratos con los cuales se diseñan las muestras tienen una cantidad de casos similares la distinción con los dominios se vuelve algo ociosa. En cambio, cuando los estratos tienen diferentes números de casos (p.e. Urbano vs.~Rural Agrupado) y luego se desea realizar estimaciones para todos los estratos, es importante la utilidad de la distinción. La razón es que un muestreo estratificado proporcional ayudará poco para tener buenas estimaciones de los dominos pequeños (p.e. Rural Agrupado). En esos casos puede ser preferible un muestreo estratificado con asignación no proporcional óptima @neyman1934.

=== Evaluación actual de la muestra usada en 2024
<evaluación-actual-de-la-muestra-usada-en-2024>
Desde el momento en que se diseñó la muestra (2023), la población de estudiantes y establecimientos fue cambiando. En especial, es notorio el aumento de establecimientos con jornada completa en los últimos años. Estos cambios poblacionales pueden sugerir dudas acerca de la adecuación de una muestra que fue diseñada para representar a una población con otras características. A pesar de estos supuestos razonables, la muestra actual no parece ---al menos en lo que respecta a los establecimientos--- haber quedado desfasada para captar el incremento de la jornada completa. Más en particular, se observa una pequeña sobrerepresentación de los establecimientos con jornada completa en esta primera etapa de la muestra. Esto puede deberse a que la expansión de la jornada completa se dío principalmente en establecimientos con matrícula no muy grandes que es justamente el tipo de establecimeintos en donde la muestra anterior parecía tener más casos. A continuación, en la #ref(<tbl-poblacion_muestra_2024>, supplement: [Tabla]), se comparan parámetros poblacionales de los establecimientos con las respectivas estimaciones de la muestra.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Variable]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Población Total (N = 5884)]
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Muestra 2024(n = 669)]
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 5.884]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 669]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[jornada\_completa], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~NO], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.757 (81%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[493 (74%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.127 (19%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[176 (26%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sector], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Estatal], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.189 (71%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[487 (73%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Privado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.695 (29%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[182 (27%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ambito], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Agrupado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[372 (6,3%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[77 (12%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Disperso], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.064 (18%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[133 (20%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Urbano], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.448 (76%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[459 (69%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula\_inicial\_2025], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[256 (82 -- 429)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[234 (75 -- 413)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[auh\_pct], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[32 (13 -- 50)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[32 (14 -- 50)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[48], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4],
  table.hline(),
  table.footer(table.cell(colspan: 3)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] n (%); Mediana (Q1 -- Q3)],),
)}
], caption: figure.caption(
position: top, 
[
Comparación parámetros poblacionales de establecimientos vs muestra 2024
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-poblacion_muestra_2024>


== Muestra 2025
<sec-muestra_peb_2025>
Teniendo en mente las características destacadas de la muestra anterior, ahora vamos a pasar a describir los objetivos de la muestra de 2025. En general se conservan muchos de ellos aunque también se agregan otros. Esto hace que, en términos de las técnicas empleadas para llegar a esos objetivos, se exceda el léxico clásico de la estratificación y la conglomeración. Los objetivos son:

+ Incluir los mismos criterios (actualizados a valores de 2025) que anteriormente se incluyeron en la construcción de los estratos para la construcción de una muestra #strong[balanceada]. Esto son:

  a) Sector (Estatal/Privado)

  b) Porcentaje de estudiantes con AUH

  c) Presencia de jornada completa

  d) Ámbito

  La idea de estos es que la muestra (de estudiantes y no de establecimientos) se acerque a los valores de tendencia central de esas variables. En otras palabras, que la muestra se encuentra balanceada en un punto óptimo que reduzca las distancias con las diferentes medidas de tendencia central de las variables anteriores.

+ Dado que algunas variables numéricas se encuentran disponibles como marco muestral para cada establecimeinto también se va a implementar una muestra (balanceada y) #strong[bien distribuida]. En otras palabras, el objetivo es también exigir una convergencia con la distribución (esto es, no solo con sus valores de tendencia central) de las siguientes variables:

  a) Latitud

  b) Longitud

  c) Porcentaje de AUH

+ En términos de las #strong[probabilidades de inclusión] se esperan cumplir con las siguientes restricciones:

  3.1. Otorgarle una mayor probabilidad de entrar a la primera etapa a los establecimientos que entraron en la muestra anterior. La idea es hacer un diseño compatible con una muestra tipo panel que se renueve (aproximadamente) por cuartos en cada edición. De esta manera, ningun establecimiento estaría más de 4 años seguidos y, de manera complementaria, el cuarto que se renueva permitiría ajustar la muestra a los cambios poblacionales sucedidos en el último año.

  3.2. Otorgarle una probabilidad de entrar en la primera etapa a los establecimientos en función del tamaño de la matrícula.

  3.3. Otorgarle una probabilidad de entrar en la segunda etapa a las secciones en función del tamaño de las mismas.

El punto 3.2 y el punto 3.3 merecen algo más de justificación porque pueden parecer contraintuitivos. En efecto, que en la primera etapa los establecimientos sean seleccionados en función del tamaño de la matrícula permite que, para la segunda etapa de la muestra, se pueda tener una regla simple como la asignación de un número fijo de estudiantes para cada establecimiento. Esto, además, permite (en ausencia de problemas de no-respuesta) hacer análisis con una muestra autoponderada. Más concretamente se aspira a registrar 10 estudiantes de cada establecimiento.

En los establecimientos en donde haya más de una sección, se puede armar un orden de prioridad entre las secciones disponibles y quedarse, en principio, solo con la que mayor prioridad obtenga. Previamente se puede generar un número para cada caso/establecimiento seleccionado que ordene a los establecimientos en función de algún criterio (p.e. matrícula). Algunos establecimientos obtendran un número par y otros tendrán uno impar. En este sentido, una vez sorteada la sección, se usa el valor del número anterior para indicar el modo de selección de los 10 estudiantes. Si ese establecimiento posee un número par, se elige a los primeros 10 estudiantes. Si ese establecimeinto posee un número impar, se elige los últimos 10 estudiantes. Si la sección seleccionada se agota sin llegar a los 10 casos se pasa a la sección siguiente en el orden de prioridad siguiendo luego el mismo criterio de selección de los estudiantes que en la sección anterior.

De este modo se tiene una regla no arbitraria (en el sentido que no decide el docente o el establecimiento qué caso cargar), la misma parece ser probabilística y, de manera derivada, permite trabajar (en ausencia de problemas de no-respuesta) con los datos sin ponderar.

== Primera Etapa
<primera-etapa>
Teniendo presente las restricciones anteriores se realizó una primera etapa de la muestra a nivel de establecimientos. Se recuerda que la muestra aspira a ser una muestra de estudiantes más que de establecimientos por lo que algunas desviaciones en esta etapa son más esperables que otras. En particular, es esperable que la media de la matrícula de los establecimientos seleccionados sea mayor a la media de la matrícula de la población de establecimientos. Algunos de los resultados, principalmente en cuanto a valores de tendencia central, se pueden ver en la #ref(<tbl-poblacion_muestra_2025>, supplement: [Tabla]).

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Variable]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Población Total (N = 5836)]
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Muestra 2025(n = 675)]
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 5.836]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 675]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sector], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Estatal], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.157 (71%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[438 (65%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Privado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.679 (29%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[237 (35%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ambito], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Agrupado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[371 (6,4%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[23 (3,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Disperso], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.039 (18%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20 (3,0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Urbano], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.426 (76%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[632 (94%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula\_inicial\_2025], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[257 (85 -- 430)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[390 (268 -- 553)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[jornada\_completa], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~NO], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.711 (81%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[572 (85%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.125 (19%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[103 (15%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[latitud], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-34,77 (-35,81 -- -34,59)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-34,72 (-34,92 -- -34,56)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[longitud], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-58,69 (-59,78 -- -58,40)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-58,61 (-58,82 -- -58,38)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[auh\_pct], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[32 (13 -- 50)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[37 (16 -- 53)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[muestra\_2024], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[665 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[433 (100%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.171], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[242],
  table.hline(),
  table.footer(table.cell(colspan: 3)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] n (%); Mediana (Q1 -- Q3)],),
)}
], caption: figure.caption(
position: top, 
[
Comparación parámetros poblacionales de establecimientos vs muestra 2025
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-poblacion_muestra_2025>


== Distribución a nivel de establecimientos
<distribución-a-nivel-de-establecimientos>
Dado que la muestra no es solo balanceada en sus medidas de tendencia central, sino también en la distribución de otras covariables ahora veremos justamente como la distribución de la muestra difiere, en las variables latitud, longitud (#strong[?\@fig-mapa\_muestra\_2025]) y porcentaje de AUH (#ref(<fig-densidad_auh>, supplement: [Figura])), de la distribución de las mismas a nivel del marco muestral.

#figure([
#box(image("muestra_peb_2025_files/figure-typst/fig-mapa_calor_poblacion_muestra-1.svg"))
], caption: figure.caption(
position: top, 
[
Mapa de calor sobre la distribución de los casos. Población y muestra 2025.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-mapa_calor_poblacion_muestra>


#figure([
#box(image("muestra_peb_2025_files/figure-typst/fig-densidad_auh-1.svg"))
], caption: figure.caption(
separator: "", 
position: top, 
[
#block[
]
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-densidad_auh>


== Simulación a nivel de estudiantes
<simulación-a-nivel-de-estudiantes>
Dado que en el actual diseño se emplea una muestra en donde la probabilidad de inclusión deviene en parte del tamaño del establecimiento es esperable, como se anticipó más arriba, encontrar diferencias entre las tendencias centrales de algunas variables consideradas importantes entre la muestra de establecimientos y la población de los mismos. Por esta razón, partiendo del marco muestral de los establecimientos vamos a crear una población sintética de estudiantes en función de la matrícula de cada uno de ellos. Luego vamos a comparar esa población con otra población de estudiantes asumiendo que se seleccionan "x" estudiantes por cada establecimiento seleccionado (10 en este caso).

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,center,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Variable]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Muestra de Estudiantes (k=10)] \
    N = 6.750#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Población de Estudiantes] \
    N = 1.666.253#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[sector], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Estatal], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.380 (65%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.081.271 (65%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Privado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.370 (35%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[584.982 (35%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ambito], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Agrupado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[230 (3,4%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[22.877 (1,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Disperso], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[200 (3,0%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[21.001 (1,3%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Urbano], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6.320 (94%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.622.375 (97%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula\_inicial\_2025], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[390 (268 -- 553)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[452 (313 -- 624)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[jornada\_completa], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~NO], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.720 (85%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.485.455 (89%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.030 (15%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[180.798 (11%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[latitud], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-34,72 (-34,92 -- -34,56)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-34,72 (-34,88 -- -34,57)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[longitud], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-58,61 (-58,82 -- -58,38)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-58,59 (-58,79 -- -58,36)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[auh\_pct], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[37 (16 -- 53)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[38 (18 -- 54)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[muestra\_2024], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.330 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[182.586 (100%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Desconocido], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.420], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.483.667],
  table.hline(),
  table.footer(table.cell(colspan: 3)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] n (%); Mediana (Q1 -- Q3)],),
)}
], caption: figure.caption(
position: top, 
[
Comparación entre poblaciónes sintéticas de estudiantes
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-poblacion_estudiantes_vs_muestra_estudiantes>


#figure([
#box(image("muestra_peb_2025_files/figure-typst/fig-poblacion_estudiantes_vs_muestra_estudiantes-1.svg"))
], caption: figure.caption(
separator: "", 
position: top, 
[
#block[
]
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-poblacion_estudiantes_vs_muestra_estudiantes>


Cabe destacar que si se realiza algún test estadístico entre ambas distribuciones (p.e. Kolmogorov-Smirnov) se observa un aceptable ajuste entre ambas distribuciones lo que sugiere que la muestra logra "copiar" aceptablemente la distribución (y no solo la tendencia central) poblacional de la variable posesión de AUH.

== Segunda etapa
<segunda-etapa>
En esta segunda etapa aparece una cuestión particular a considerar. Se trata del tamaño de las secciones de los establecimientos como algo diferente a la cantidad de secciones del mismo. Con respecto a la muestra de 2024, esto es un problema algo nuevo porque el diseño de la muestra 2025 aspira a, efectivamente, seleccionar #emph[algunas] secciones dentro de los establecimientos en vez de ir a #emph[todas].

Antes vimos que si la probabilidad de inclusión de un establecimiento en la primera etapa de la muestra depende del tamaño de la matrícula eso permite que la cantidad de estudiantes a seleccionar en la segunda etapa pueda ser única para todos los establecimientos. Dado que en la mayoría de los establecimientos existe más de una sección para cada año (3#super[ro] y 6#super[to]) nos encontramos con el problema de como seleccionar a las propias secciones. Expresado en léxico muestral, ahora las secciones se convierten en una segunda etapa de selección. En este sentido, el problema del tamaño de los establecimientos en la primera etapa se traduce al problema del tamaño de cada sección en la segunda etapa. Si solo se realiza un sorteo por azar simple dentro de cada establecimiento para seleccionar a las secciones, los estudiantes de las secciones más grandes van a tener una menor chance de salir en la muestra que los estudiantes de secciones chicas. En funcion de esto podría ser pertinente que, a la hora de realizar el sorteo de las secciones, se incluya en la probabilidad de inclusión el tamaño de la sección (Punto 3.3). Para tener de referencia, los establecimientos seleccionados en 2025 poseen, en promedio, más secciones que los seleccionados en 2024. Si se cuenta los diferentes turnos ahora hay que seleccionar entre 2,8 secciones en cada establecimiento para cada año. En cambio, este valor para la muestra de 2024 fue de alrededor de 2,2 secciones por cada establecimiento/año seleccionado en su respectiva primera etapa.

Sin embargo, el problema no se trata solo de que antes se iba a #emph[todas] las secciones #emph[entre las pocas] del establecimiento elegido y ahora a se vaya a #emph[algunas entre muchas]. Un problema adicional es el siguiente. Supongamos que se tenga en mente la hipótesis que la relación en cuanto al ratio estudiantes/docente sea importante con respecto a los aprendizajes. En ese caso, una regla simple como la de "seleccione siempre a la sección más grande del establecimiento" sería, en presencia de la hipótesis anterior, una regla que, artificialmente, bajaría el promedio de las notas PEB por cenirse a las secciones en donde ese ratio es mayor. La regla anterior se podría mantener si, dentro de cada establecimiento y dentro de cada año seleccionado, hubiera muy poca diferencia de tamaño entre sus diferentes secciones. Esta hipótesis, si bien razonable dentro de ciertos parámetros, es extrema. Por otro lado, asumir que sea usual la situación en donde un establecimiento tenga 3 secciones en 6#super[to] grado, de las cuales una tenga un tamaño de 10 estudiantes, otra de 20 y otra de 30, también parece ser algo extremo. Podría ser algo más probable esta situación en los establecimientos de jornada simple en donde habría que seleccionar secciones tanto de la tarde como de la mañana. También puede ser algo más probable de encontrarse esta situación en 6#super[to] más que en 3#super[ro]. Sin embargo, aun asumiendo que estos últimos casos pueden ser más probables en jornada simple y en 6#super[to] es difícil anticipar su peso en el conjunto de las secciones.

Lo anterior puede analizarce de modo empírico de dos modos diferentes. Primero analizaremos la distribución, medida a través de la desviación estándar, de todas las secciones con respecto a su respectiva media de tamaño para su mismo establecimiento y año. Esto nos va a permitir captar la heterogeneridad en función de la misma unidad que se utiliza para calcular la media que, en este caso, es la cantidad de estudiantes. En la #ref(<fig-sd_size_secciones_intra_establecimiento>, supplement: [Figura]) se observa como, si bien con una distribución normal, existen divergencias con respecto a la media. Esto asegura que, si se seleccionara siempre a las secciones más grandes del tandem establecimiento/año, efectivamente la muestra estaría compuesta casi exclusivamente por secciones que se encuentran por encima de su respectiva media. Claro está que la mayoría de ellas estaría compuesta por secciones que sobrepasan por pocos estudiantes (2 estudiantes) a su respectiva media.

#figure([
#box(image("muestra_peb_2025_files/figure-typst/fig-sd_size_secciones_intra_establecimiento-1.svg"))
], caption: figure.caption(
position: top, 
[
Diferencias de tamaño de las secciones para igual establecimiento y año. Media estandarizada en 0 y desvío estándar en cantidad de estudiantes.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-sd_size_secciones_intra_establecimiento>


De todos modos, para evitar que la muestra de secciones se pueble exclusivamente de las secciones más mayoritarias, más que implementar la regla simple de "seleccionar la sección más grande" vamos a implementar, como se había anticipado anteriormente, un criterio probabilístico en función del tamaño de la sección. De este modo, a nivel agregado sí se van a seleccionar con mayor probabilidad las secciones más grandes, pero también, en una menor probabilidad, se van a incluir como primera opción algunas secciones que no cumplan ese criterio.

En la #ref(<tbl-poblacion_muestra_secciones>, supplement: [Tabla]) puede observarse como al tiempo que se respeta la tendencia central del tamaño de las secciones, la mayoría de las veces (60%) se ha seleccionado a la sección más numerosa aunque, justamente, no siempre. De este modo se respeta el principio que las secciones más numerosas sean más seleccionadas (y de ese modo se equiparan las probabilidades de los estudiantes que están en ellas) pero también se seleccionan secciones no numerosas para de ese modo evitar el sesgo de seleccionar las secciones con mayor ratio de estudiantes/docentes.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,center,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[NO] \
    N = 2.384#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[SI] \
    N = 1.346#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[tamaño], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26 (6)}], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26 (7)}],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[anio], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~3], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.196 (50%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[673 (50%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~6], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.188 (50%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[673 (50%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[seccion\_mas\_grande], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~NO], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.384 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[534 (40%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[812 (60%)],
  table.hline(),
  table.footer(table.cell(colspan: 3)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] Media (DE)}; n (%)],),
)}
], caption: figure.caption(
position: top, 
[
Población y muestra de secciones
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-poblacion_muestra_secciones>


= Muestra EJAyAM
<muestra-ejayam>
== Objetivos
<objetivos>
El objetivo es realizar una muestra representativa de estudiantes jóvenes, adultos y adultos mayores (EJAyAM) de la provincia de Buenos Aires.

Expresado en el lenguaje clásico de los márgenes de error, la precisión de los resultados con la se espera poder realizar inferencias son en general de:

- Nivel de confianza: 90%

- P: 50%

pero con los siguientes márgenes de error específicos:

- Sobre los establecimientos FINES a nivel regional con un margen de error del 5%.

- En el resto de los establecimientos (EPA y CENSA) se espera poder hacer inferencias a nivel de Gran Área con un margen de error del 3%.

- En el caso de los CEBAS, dado su pequeño tamaño poblacional, se espera realizar un relevamiento censal. Por esta razón no habrá márgen de error para esta categoría.

Si se asume que los diferentes tipos de establecimientos son "Estratos" muestrales, se podría pensar

3% por estrato-gran área,

4% por estrato-región agrupada.

5% por estrato-región

Por ahora no diremos algo más específico con referencia a los medios para lograr ese objetivo. La razón de esto es, justamente, distinguir los objetivos del estudio de los medios para lograrlos. Incluso más adelante vamos a proponer una manera alternativa de proponer los objetivos de la muestra basada en el léxico del coeficiente de variación (#emph[CV]) que puede considerarse como un error estándar relativo @valliant2018[pág. 3]. El cómo enunciar los objetivos de una muestra no algo banal. En efecto, suele haber diferencias entre las disciplinas a la hora de que pedirle a una muestra. Por ejemplo, en contextos epidemiológicos es usual hablar de #emph[power requirements] aunque lo usual en las ciencias sociales es hablar sobre #emph[precision goals] @valliant2018[pág. 8].

Para esto se espera realizar un diseño muestral polietápico en donde en una primera etapa seleccione a los establecimeintos y luego a los estudiantes que concurren a ellos.

Los estudiantes pueden pertenecer a los siguientes #strong[tipos de establecimientos]:

- Nivel Primario. Se incluyen solo a los EPA. Se excluyen a los centros de alfabetización y a los CEPA.

- Nivel Secundario de oferta institucional. Estos pueden ser CENS o SEBAS.

- Nivel Secundario por fuera de la oferta institucional. Son los establecimientos FINES.

#figure([
#block[
#box(image("muestra_adultos_files\\figure-typst\\dot-figure-1.png", height: 3.6in, width: 5in))

]
], caption: figure.caption(
position: top, 
[
Establecimientos de educación adulta y población objetivo
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-tipos_establecimientos>


== Resultados esperados
<resultados-esperados>
Encuesta de perfil de lxs estudiantes de la modalidad de EJAyAM

Población objetivo: Estudiantes EPA (solo sedes) de nivel Primario y de todas las ofertas de nivel Secundario (CENS, CEBAS, FINES) de gestión estatal (oficial).

Diseño de la muestra

\-Tipo de muestreo: estratificado polietápico y por conglomerados con selección proporcional al tamaño y sistemática

\-Estratos:

Por oferta (EPA, CENS, CEBAS, FINES) y

por área:

1) CEBAS: Censal •

2) EPA y CENS: AMBA (R01 a R11) e Interior (R12 a R25) •

3) FINES: Por región o agregado de regiones (16, 21, 22 y 23; 15, 17, 24 y 25).

\-Etapas de selección: •

1° Unidades de servicios / Sedes: Proporcional al tamaño (matrícula), con orden sistemático por IVSE-T. •

2° Secciones: Todas las secciones de los establecimientos seleccionados. •

3° Estudiantes: 5 primeros o últimos de cada sección.

== Tamaño de la muestra
<tamaño-de-la-muestra>
deff=2 para EPA y CENS

deff= 1,5 para FINES y CEBAS.

Se estima la realización de unas 14.000 encuestas (algo más de 7.000 en FINES, cerca de 3.000 en EPA y CENS y 600 en CEBAS) en aproximadamente 2.700 secciones (cerca de 1/4 del total).

El margen de error para el total provincial sería del 1% para FINES, del 2% para EPA y CENS y del 3% para CEBAS, ubicándose en torno al 1,2% para el total del nivel secundario y del total de ambos niveles de la modalidad.

#figure([
#box(image("images/paste-1.png", width: 7.76042in))
], caption: figure.caption(
position: bottom, 
[
#box(image("images/paste-2.png"))
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)


=== Clasificación
<clasificación-1>
El presente diseño muestral, a diferencia de #ref(<sec-muestra_peb_2025>, supplement: [Sec.]), no tiene que ser compatible o mejorar en algunos puntos específicos de un diseño muestral anterior. Por otro lado, en este caso sí hay exigencias o restricciones específicas en cuanto a la precisión estadística del resultado esperado. En otras situaciones relativamente similares, esas exigencias/restricciones se explicitan o se traducen en términos de costo operativo o económico del estilo "Nosotros podemos/queremos una muestra de X casos" o "Recolectar tal tipo de caso nos cuesta más que tal u otro así que, en lo posible, tenga eso en cuenta dentro del diseño".

== Afinando la población objetivo
<afinando-la-población-objetivo>
Más allá que se cuente previamente o se construya especialmente para la ocasión, siempre es importante saber el origen del marco muestral. La indagación sobre este punto no solo aclara que entra dentro de él, sino también que queda fuera de él y porque. En este sentido, no es lo mismo que el marco muestral deje afuera algo deseado, pero impráctico de obtener que, por otro lado, algo que si bien desde lejos parecía cercano a la población objetivo, desde el principio se prefirió no incluir. En el primer caso, se mantiene la definición intensiva de la población objetivo, pero se restringue la extensión empírica del marco muestral creando una distancia entre uno y otro. En el segundo caso, lo que se cambia/ajusta es la definición de la población objetivo y se evita una distancia entre lo deseado/buscado y lo realizable con el marco muestral disponible.

Aplicado lo anterior al presente problema, la cuestión es discernir a qué tipo de estudiante se desea alcanzar y a cuáles no. A primera vista se puede suponer que la población objetivo (#emph[target population]) son los estudiantes #strong[adultos] de nivel primario y secundario de la provincia de Buenos Aires.

Sin embargo, como se observa en #ref(<tbl-poblacion_objetivo>, supplement: [Tabla]), existen una serie de establecimientos de educacion de jóvenes y adultos que quedan por fuera de la población objetivo de esta muestra. Más concretamente, existe un 19% que no posee todas las características necesarias.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (50%, 50%),
  align: (left,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Characteristic]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 3,822]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Población Objetivo], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,078 (81%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~NO], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[744 (19%)],
  table.hline(),
  table.footer(table.cell(colspan: 2)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] n (%)],),
)}
], caption: figure.caption(
position: top, 
[
Población objetivo dentro del universo de establecimiento de educación adulta
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-poblacion_objetivo>


Entre las características que se tuvieron en cuenta se encuentran en la confección de la población objetivo se encuentra la dependencia y el tipo de establecimiento. Como se observa en #ref(<tbl-poblacion_objetivo_criterios>, supplement: [Tabla]) todos los establecimientos de la población objetivo son de dependencia oficial. Dada que la presencia de otros tipos de dependencia en la educación adulta es muy baja, este criterio no es crítico desde el punto de vista empírico.

Esto no significa que todos los establecimientos de dependencia oficial pertenecen a la población objetivo. En efecto, existe un 19% de establecimientos de dependencia oficial que no pertenecen a la población objetivo. Dentro del nivel primario, se trata de los establecimientos CEPA (671) y los centros de alfabetización (45) y dentro del nivel secundario de aquellos establecimientos denominados "Escuelas de educación media o secundaria". Los que sí entran a la población objetivo, siempre que sean de dependencia oficial, son los establecimientos FINES, los CENS, los EPA y los CEBAS.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,center,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Characteristic]], table.cell(align: bottom + center, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Overall] \
    N = 3,822#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: center, colspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Población Objetivo]
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[NO] \
    N = 744#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[SI] \
    N = 3,078#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Tipo de establecimiento], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,190 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,190 (100%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~CEPA], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[671 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[671 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~CENS], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[541 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7 (1.3%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[534 (99%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~EPA], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[336 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 (0.6%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[334 (99%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~ALFABETIZACION], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[45 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[45 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~CEBAS], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20 (100%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~ESC. EDU. MEDIA], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~ESC. EDU. SECUNDARIA], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Dependencia], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Oficial], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,794 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[716 (19%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,078 (81%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Privada], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[23 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[23 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Nacional], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Municipal], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)],
  table.hline(),
  table.footer(table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] n (%)],),
)}
], caption: figure.caption(
position: top, 
[
Distribución de tipos de establecimiento de educación adulta
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-poblacion_objetivo_criterios>


Dado que se cuenta con un marco muestral flexible en el cual ya se han detectado que establecimientos podrían entrar en la muestra, lo interesante es ajustar la población objetivo al marco muestral entregado. No se trata de un simple juego de palabras. Si se detectan o sospechan diferencias apreciables entre la población objetivo y el marco muestral, antes o después, será aconsejable realizar alguna intervención para corregir o aminorar esa distancia. En cambio, si el marco muestral se ajusta a la población objetivo algunas de las anteriores intervenciones no serán necesarias o recomendadas.

Sin embargo, ahora veremos que en realidad se trata de una subpoblación más específica porque la población que finalmente tiene posibilidades de entrar a la muestra es un subconjunto de aquel conjunto. Y dada que contamos con un marco muestral flexible la razón de no inclusión no es por falta de información en el marco.

Esto hace que el investigador concentre las energías en otras partes de la investigación. En

== Marco muestral
<marco-muestral>
Una vez definida la población objetivo comenzamos a mejorar el marco muestral. Decimos que comenzamos a "mejorar" porque, por suerte, ya tenemos un marco muestral básico que nos permite identificar a las unidades de selección primarias (#emph[PSU] en inglés). Decimos "por suerte" porque una característica particularmente interesante de trabajar en grandes organizaciones, que no es lo usual por fuera de ellas, es la posibilidad de trabajar con un marco muestral (#emph[sampling frame]) que se ajuste bastante bien a la población objetivo (#emph[population target]). Por ejemplo, en una universidad o colegio podemos tener un listado de estudiantes relativamente actualizado. En cambio, en otro tipo de investigaciones, los investigadores suelen dedicar un tiempo considerable a conseguir un marco muestral que o bien sobrerrepresente o subrepresente empíricamente a la población objetivo. Cabe recordar que el marco muestral no es solo una lista de elementos a seleccionar sino también alguna información que ayude a su contacto/localización. Tener una lista de DNI para cada uno de los miembros del marco muestral es una ayuda, pero no es muy útil si esa información no viene anexada con algún dato que permita contactar/localizar a los DNI efectivamente seleccionados en la muestra.

Al pasar antes dijimos que el marco muestral básico con el que vamos a trabajar nos permite identificar a las unidades de selección primarias. En otras palabras, vamos a trabajar con un listado de establecimientos y no de estudiantes y vamos a desarrollar un muestreo polietápico en donde en primera instancia (de ahí lo de unidades "primarias") se seleccionan establecimientos y recien luego se seleccioan secciones y/o estudiantes.

Para la selección de las unidades de seleccion, existen dos tipos generales de marcos muestrales: directos e indirectos @valliant2018[pág. 6]. Los marcos muestrales que contienen una lista de las unidades de observación finales se denominan #strong[marcos directos]. Estos marcos facilitan/permiten los diseños de una sola etapa. Por ejemplo, si se tiene una lista de estudiantes y algún contacto virtual (p.e. mail), se puede realizar un diseño en una sola etapa. En ese caso, no será necesario seleccionar primero a unidades de selección primarias como, por ejemplo, los establecimientos educativos.

Los #strong[marcos indirectos], en cambio, requieren de mucha menor información, pero permiten realizar la selección de las unidades de selección primarias (#emph[clusters] o conglomerados) y se utilizan en diseños polietápicos. Los marcos indirectos necesariamente se usan en diseños polietápicos, pero los marcos directos se pueden usar tanto en diseños de una sola etapa o, vía agregación de su información, en diseños polietápicos.

Volviendo a nuestro marco muestral el mismo es del tipo indirecto y, suponemos, que es de una muy buena calidad en términos de su ajuste a la población objetivo. Sin embargo, ahora veremos con mayor detalle la información auxiliar que tendremos de las covariables presente en él, para sí poder realizar un mejor diseño muestral.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji")); table(
  columns: 28,
  align: (left,right,right,left,right,left,right,right,left,left,left,left,left,left,left,left,left,left,right,right,left,left,left,left,left,right,left,right,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); tipo], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); region], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); region\_n], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); distrito], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); distrito\_n], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); area], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); cue], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); anexo], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); clave\_provincial], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); dependencia], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); tipo\_de\_organizacion], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); sede\_anexo\_extension], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); escuela\_sede], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); nombre\_del\_establecimiento], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ambito], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); matricula\_estimada], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); modalidad], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); nivel], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); matricula], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); secciones], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); population\_target], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); universo\_excl], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); estrato\_oferta], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); estrato\_geo], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); estrato], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ivse], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); tipo\_est\_adulto], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); estudiante\_seccion],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[22], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[22], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Bahía Blanca], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[INTERIOR], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[616446], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0008DS0030], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. Nº 30 \"ENFERMERAS 1982 POR MALVINAS\"], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[48], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.071], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16.00000],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[08], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Merlo], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[71], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CONURBANO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[616233], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0071DS0029], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. Nº29], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[102], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.199], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[17.00000],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[01], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[La Plata], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[INTERIOR], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[620508], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0001DS0048], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. Nº48 \"DR. RENÉ FAVALORO\"], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.274], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16.00000],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Escobar], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[116], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[INTERIOR], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[616870], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0116DS0037], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. Nº37], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[54], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.295], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[18.00000],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[09], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[José C. Paz], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[132], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CONURBANO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[619103], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0132DS0039], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. Nº39], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[96], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.300], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16.00000],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[04], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Berazategui], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[119], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CONURBANO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[614624], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0119DS0017], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. Nº17], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[86], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.337], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.33333],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9 de Julio], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[76], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[INTERIOR], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[615601], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0076DS0019], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. Nº19], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[39], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.374], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.00000],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[07], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[General San Martín], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[45], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CONURBANO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[609445], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0045DS0002], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. Nº2 \"EDUCADOR PAULO FREIRE\"], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[89], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.396], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.83333],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[02], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Avellaneda], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CONURBANO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[610303], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0005DS0010], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. Nº10], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[124], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.419], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20.66667],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[02], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Lanús], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[111], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CONURBANO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[620507], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0111DS0049], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. Nº49], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[43], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.420], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.33333],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[08], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Morón], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[100], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CONURBANO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[616437], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0100DS0028], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. Nº28], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[109], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.422], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[18.16667],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[01], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[La Plata], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[INTERIOR], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[609006], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0001DS0001], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. Nº1 \"FLOREAL FERRARA\"], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[256], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.457], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[28.44444],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[05], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Esteban Echeverría], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[30], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CONURBANO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[620534], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0030DS0041], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. Nº41], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[33], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.571], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11.00000],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[06], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Tigre], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[55], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CONURBANO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[616870], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0055DS2370], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[EXTENSION], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0116DS0037], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO DE BACHILLERATO DE ADULTOS CON ORIENTACIÓN EN SALUD PÚBLICA N°37 - EXTENSIÓN], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[61], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.658], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20.33333],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[San Antonio de Areco], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[94], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[INTERIOR], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[619088], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0094DS0047], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. Nº47], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[33], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.765], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16.50000],
)}
], caption: figure.caption(
position: top, 
[
Características del marco muestral
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-sampling_frame>


Como vemos tenemos información auxiliar a nivel de cada establecimiento tanto de variables discretas como continuas:

Variables discretas:

- Distrito

- Región

- Región Agrupada

- Ámbito

- Área

- Nivel

- Tipo de establecimiento

Variables continuas:

- Matrícula

- Secciones

- Medai de estudiantes por sección

- IVSE

Para tener una idea de las distribuciones de estas variables vamos a realizar un análisis exploratorio de datos. Primero lo haremos a nivel de los establecimientos (#strong[?\@sec-marco\_muestral\_establecimientos]) y luego lo haremos a nivel de los estudiantes (#strong[?\@sec-marco\_muestral\_estudiantes]). Para esto, vamos a realizar un análisis descriptivo de cada una de las variables discretas y continuas. Para las variables discretas vamos a mostrar su distribución en términos de frecuencias y porcentajes. Para las variables continuas, vamos a mostrar su distribución a través de histogramas o gráficos de densidad.

#figure([
], caption: figure.caption(
position: top, 
[
Análisis exploratorio variables discretas - Nivel establecimientos
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-explo_marco_discretas_establecimientos>


#figure([
], caption: figure.caption(
position: top, 
[
Análisis exploratorio variables discretas - Nivel estudiantes
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-explo_marco_discretas_estudiantes>


#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Establecimientos]
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Estudiantes]
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 3.078]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 198,427]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Región], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[237 (7,7%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14,506 (7.3%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~02], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[268 (8,7%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16,889 (8.5%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~03], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[305 (9,9%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20,878 (11%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~04], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[236 (7,7%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[17,803 (9.0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~05], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[266 (8,6%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[18,388 (9.3%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~06], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[102 (3,3%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7,457 (3.8%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~07], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[136 (4,4%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,044 (4.1%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~08], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[163 (5,3%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12,100 (6.1%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~09], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[163 (5,3%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14,100 (7.1%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[162 (5,3%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,430 (4.2%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[145 (4,7%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11,029 (5.6%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[75 (2,4%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,635 (2.3%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[47 (1,5%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,850 (1.4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~14], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[66 (2,1%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,679 (1.9%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~15], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[51 (1,7%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,611 (1.3%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~16], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[34 (1,1%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,517 (0.8%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~17], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[36 (1,2%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,383 (0.7%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~18], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[86 (2,8%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,915 (2.0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~19], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[190 (6,2%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9,528 (4.8%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~20], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[72 (2,3%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,146 (1.6%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~21], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[45 (1,5%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,807 (0.9%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~22], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[66 (2,1%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,797 (2.4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~23], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[38 (1,2%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,517 (0.8%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~24], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[32 (1,0%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,282 (1.2%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~25], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57 (1,9%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,136 (2.6%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ámbito], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Urbano], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.044 (99%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[192,227 (97%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Agrupado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15 (0,5%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[616 (0.3%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Disperso], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19 (0,6%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,584 (2.8%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Área], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~CONURBANO], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.593 (52%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[111,749 (56%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~INTERIOR], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.485 (48%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[86,678 (44%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Nivel], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[888 (29%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[123,378 (62%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Secundario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.190 (71%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[75,049 (38%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Tipo de establecimiento], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~CEBAS], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20 (0,6%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,590 (0.8%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~CENS], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[534 (17%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[80,793 (41%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~EPA], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[334 (11%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[40,995 (21%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.190 (71%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[75,049 (38%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Matrícula], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[33 (17 -- 87)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[123 (64, 208)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Secciones], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0 (1,0 -- 5,0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6 (3, 11)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Estudiante por sección], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[17 (13 -- 23)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20 (15, 25)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[IVSE], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,50 (0,25 -- 0,74)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.50 (0.23, 0.75)],
  table.hline(),
  table.footer(table.cell(colspan: 3)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] n (%); Mediana (Q1 -- Q3)],
    table.cell(colspan: 3)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2]] n (%); Median (Q1, Q3)],),
)}
], caption: figure.caption(
position: top, 
[
Comparación exploratorio del marco muestral. Nivel establecimieno y nivel estudiantes
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-comparacion>


#figure([
#box(image("muestra_adultos_files/figure-typst/fig-comparacion-1.svg"))
], caption: figure.caption(
position: top, 
[
Comparación exploratorio del marco muestral. Nivel establecimieno y nivel estudiantes
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-comparacion>


\`\`\`{r.content-visible when-format="html"} \#| label: fig\_mapa\_distritos \#| fig-cap: Mapa según distrito \# Quiero realizar un mapa con tmap en version "view" con las coordenadas de los distritos (columan geom\_depto) y la cantidad de estudiantes por distrito (matricula). Para esto, tengo que agrupar el dataframe por distrito y sumar la cantidad de estudiantes por distrito. Luego, tengo que unir el dataframe con el dataframe espacial de los distritos para poder graficar el mapa. tmap\_mode("view") \# Le agrego la geometría de los distritos. No lo agrego antes para no saturar a df\_estudiantes

df\_sampling\_frame = df\_sampling\_frame |\> mutate(distrito = str\_to\_upper(distrito)) |\> mutate(distrito = str\_replace\_all(distrito, "Á", "A")) |\> mutate(distrito = str\_replace\_all(distrito, "É", "E")) |\> mutate(distrito = str\_replace\_all(distrito, "Í", "I")) |\> mutate(distrito = str\_replace\_all(distrito, "Ó", "O")) |\> mutate(distrito = str\_replace\_all(distrito, "Ú", "U")) |\> left\_join(df\_sf\_distritos, by = "distrito") |\> relocate(fna, .after = distrito)

df\_mapa\_distritos = df\_sampling\_frame |\> group\_by(distrito) |\> summarise(matricula = sum(matricula), secciones = sum(secciones)) |\> mutate(pct\_matricula = matricula / sum(matricula) \* 100) |\> left\_join(df\_sf\_distritos, by = "distrito") |\> st\_as\_sf()

fig\_mapa = tm\_shape(df\_mapa\_distritos) + tm\_polygons( fill = "pct\_matricula", fill.scale = tm\_scale\_intervals(values = "Blues", style = "quantile"), fill.legend = tm\_legend(title = "% matrícula") ) + tm\_layout( title = "Porcentaje de matrícula por distrito" ) + tm\_view( legend.outside = TRUE )

fig\_mapa

#Skylighting(([],
[#NormalTok("## Tamaño de la muestra");],
[],
[#NormalTok("El tamaño de una muestra no suele ser algo fácil de responder en un diseño con múltiples objetivos y estimadores [@valliant2018, pág. 26]. Una situación similar es cuando no se sabe bien para qué se va a usar la muestra, pero no se duda que diferentes investigadores van a intentar contestar diferentes preguntas de investigación con ella. Esto último es una de las razones por las cuales muchas veces es preferible expresar los objetios estadísticos en términos de un coeficiente de variación (*CV*). Este es adimensional (no posee unidades) y puede usarse para comparar la relativa precisión de las estimaciones de diferentes tipos de cantidades o variables [@valliant2018, pág. 27]. En otras palabras, nos permite comparar la precisión de variables discretas (como la tasa de ocupación de los estudiantes) con variables cuantitativas continuas (como el promedio de ingresos del hogar o la edad promedio), algo que resulta imposible utilizando márgenes de error absolutos.");],
[],
[#NormalTok("Las principales agencias oficiales de estadística (como el INDEC en Argentina, INEGI en México o Eurostat) suelen evaluar la calidad y la factibilidad de publicación de sus estimaciones a partir de los límites de sus $CV$: un $CV \\le 10\\%$ se cataloga como una estimación de excelente precisión, mientras que estimaciones con un $CV > 20\\%$ se consideran no publicables por su alta variabilidad.");],
[],
[#NormalTok("Muchas veces suele solicitarse un determinado **Margen de Error absoluto** ($MdE$), asumiendo un escenario de máxima varianza para una proporción teórica ($p = 50\\%$). Sin embargo, en comparación con el CV presenta **el peligro del error absoluto en proporciones pequeñas.** Si fijamos un margen de error absoluto del $3\\%$ (0,03) para medir un fenómeno de alta prevalencia en torno al $50\\%$, el intervalo resultante ($47\\% - 53\\%$) es sumamente preciso. Pero si queremos estimar un fenómeno de baja prevalencia (por ejemplo, estudiantes de la modalidad con alguna condición socioeducativa o de salud particular que represente un $5\\%$), un margen absoluto del $3\\%$ nos daría un intervalo de estimación de $[2\\%, 8\\%]$. En esos casos, el **error relativo** aumenta a niveles que suele afectar severamente la utilidad de esas estimaciones. Al fijar un objetivo de $CV$, el error estándar se evalúa siempre en términos relativos ($CV = SE(\\hat{p}) / p$), lo que garantiza que la calidad y precisión de la estimación sea robusta tanto para proporciones mayoritarias como para minoritarias.");],
[],
[#NormalTok("### Traducción de Margen de Error a Coeficiente de Variación");],
[],
[#NormalTok("Para ser consistente tanto con el pedido de precisión original (Nivel de confianza del $90\\%$, $p=50\\%$ y márgenes de error de $3\\%$, $4\\%$ y $5\\%$) como con el supuesto de la superioridad de los CV, podemos establecer la siguiente equivalencia teórica. Si recordamos que el margen de error absoluto es:");],
[],
[#NormalTok("$d = z_{1-\\alpha/2} \\cdot SE(\\hat{p})$");],
[],
[#NormalTok("bajo un diseño de máxima varianza donde $p = 0,5$ y un nivel de confianza del $90\\%$ (con un valor crítico $z_{0,95} \\approx 1,645$), la relación matemática para el $CV$ es:");],
[],
[#NormalTok("$$CV(\\hat{p}) = \\frac{SE(\\hat{p})}{p} = \\frac{d}{p \\cdot z_{1-\\alpha/2}} = \\frac{d}{0,5 \\cdot 1,645} \\approx \\frac{d}{0,8225}$$ {#eq-margen-cv}");],
[],
[],
[#NormalTok("::: {.cell}");],
[],
[#NormalTok(":::");],
[],
[],
[],
[#NormalTok("::: {#tbl-traduccion_mde_cv .cell tbl-cap='Traducción de MdE a CV'}");],
[#NormalTok("::: {.cell-output-display}");],
[],
[#NormalTok("```{=html}");],
[#NormalTok("<div id=\"cnsdxozdii\" style=\"padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;\">");],
[#NormalTok("<style>#cnsdxozdii table {");],
[#NormalTok("  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';");],
[#NormalTok("  -webkit-font-smoothing: antialiased;");],
[#NormalTok("  -moz-osx-font-smoothing: grayscale;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii thead, #cnsdxozdii tbody, #cnsdxozdii tfoot, #cnsdxozdii tr, #cnsdxozdii td, #cnsdxozdii th {");],
[#NormalTok("  border-style: none;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii p {");],
[#NormalTok("  margin: 0;");],
[#NormalTok("  padding: 0;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_table {");],
[#NormalTok("  display: table;");],
[#NormalTok("  border-collapse: collapse;");],
[#NormalTok("  line-height: normal;");],
[#NormalTok("  margin-left: auto;");],
[#NormalTok("  margin-right: auto;");],
[#NormalTok("  color: #333333;");],
[#NormalTok("  font-size: 16px;");],
[#NormalTok("  font-weight: normal;");],
[#NormalTok("  font-style: normal;");],
[#NormalTok("  background-color: #FFFFFF;");],
[#NormalTok("  width: auto;");],
[#NormalTok("  border-top-style: solid;");],
[#NormalTok("  border-top-width: 2px;");],
[#NormalTok("  border-top-color: #A8A8A8;");],
[#NormalTok("  border-right-style: none;");],
[#NormalTok("  border-right-width: 2px;");],
[#NormalTok("  border-right-color: #D3D3D3;");],
[#NormalTok("  border-bottom-style: solid;");],
[#NormalTok("  border-bottom-width: 2px;");],
[#NormalTok("  border-bottom-color: #A8A8A8;");],
[#NormalTok("  border-left-style: none;");],
[#NormalTok("  border-left-width: 2px;");],
[#NormalTok("  border-left-color: #D3D3D3;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_caption {");],
[#NormalTok("  padding-top: 4px;");],
[#NormalTok("  padding-bottom: 4px;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_title {");],
[#NormalTok("  color: #333333;");],
[#NormalTok("  font-size: 125%;");],
[#NormalTok("  font-weight: initial;");],
[#NormalTok("  padding-top: 4px;");],
[#NormalTok("  padding-bottom: 4px;");],
[#NormalTok("  padding-left: 5px;");],
[#NormalTok("  padding-right: 5px;");],
[#NormalTok("  border-bottom-color: #FFFFFF;");],
[#NormalTok("  border-bottom-width: 0;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_subtitle {");],
[#NormalTok("  color: #333333;");],
[#NormalTok("  font-size: 85%;");],
[#NormalTok("  font-weight: initial;");],
[#NormalTok("  padding-top: 3px;");],
[#NormalTok("  padding-bottom: 5px;");],
[#NormalTok("  padding-left: 5px;");],
[#NormalTok("  padding-right: 5px;");],
[#NormalTok("  border-top-color: #FFFFFF;");],
[#NormalTok("  border-top-width: 0;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_heading {");],
[#NormalTok("  background-color: #FFFFFF;");],
[#NormalTok("  text-align: center;");],
[#NormalTok("  border-bottom-color: #FFFFFF;");],
[#NormalTok("  border-left-style: none;");],
[#NormalTok("  border-left-width: 1px;");],
[#NormalTok("  border-left-color: #D3D3D3;");],
[#NormalTok("  border-right-style: none;");],
[#NormalTok("  border-right-width: 1px;");],
[#NormalTok("  border-right-color: #D3D3D3;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_bottom_border {");],
[#NormalTok("  border-bottom-style: solid;");],
[#NormalTok("  border-bottom-width: 2px;");],
[#NormalTok("  border-bottom-color: #D3D3D3;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_col_headings {");],
[#NormalTok("  border-top-style: solid;");],
[#NormalTok("  border-top-width: 2px;");],
[#NormalTok("  border-top-color: #D3D3D3;");],
[#NormalTok("  border-bottom-style: solid;");],
[#NormalTok("  border-bottom-width: 2px;");],
[#NormalTok("  border-bottom-color: #D3D3D3;");],
[#NormalTok("  border-left-style: none;");],
[#NormalTok("  border-left-width: 1px;");],
[#NormalTok("  border-left-color: #D3D3D3;");],
[#NormalTok("  border-right-style: none;");],
[#NormalTok("  border-right-width: 1px;");],
[#NormalTok("  border-right-color: #D3D3D3;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_col_heading {");],
[#NormalTok("  color: #333333;");],
[#NormalTok("  background-color: #FFFFFF;");],
[#NormalTok("  font-size: 100%;");],
[#NormalTok("  font-weight: normal;");],
[#NormalTok("  text-transform: inherit;");],
[#NormalTok("  border-left-style: none;");],
[#NormalTok("  border-left-width: 1px;");],
[#NormalTok("  border-left-color: #D3D3D3;");],
[#NormalTok("  border-right-style: none;");],
[#NormalTok("  border-right-width: 1px;");],
[#NormalTok("  border-right-color: #D3D3D3;");],
[#NormalTok("  vertical-align: bottom;");],
[#NormalTok("  padding-top: 5px;");],
[#NormalTok("  padding-bottom: 6px;");],
[#NormalTok("  padding-left: 5px;");],
[#NormalTok("  padding-right: 5px;");],
[#NormalTok("  overflow-x: hidden;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_column_spanner_outer {");],
[#NormalTok("  color: #333333;");],
[#NormalTok("  background-color: #FFFFFF;");],
[#NormalTok("  font-size: 100%;");],
[#NormalTok("  font-weight: normal;");],
[#NormalTok("  text-transform: inherit;");],
[#NormalTok("  padding-top: 0;");],
[#NormalTok("  padding-bottom: 0;");],
[#NormalTok("  padding-left: 4px;");],
[#NormalTok("  padding-right: 4px;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_column_spanner_outer:first-child {");],
[#NormalTok("  padding-left: 0;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_column_spanner_outer:last-child {");],
[#NormalTok("  padding-right: 0;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_column_spanner {");],
[#NormalTok("  border-bottom-style: solid;");],
[#NormalTok("  border-bottom-width: 2px;");],
[#NormalTok("  border-bottom-color: #D3D3D3;");],
[#NormalTok("  vertical-align: bottom;");],
[#NormalTok("  padding-top: 5px;");],
[#NormalTok("  padding-bottom: 5px;");],
[#NormalTok("  overflow-x: hidden;");],
[#NormalTok("  display: inline-block;");],
[#NormalTok("  width: 100%;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_spanner_row {");],
[#NormalTok("  border-bottom-style: hidden;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_group_heading {");],
[#NormalTok("  padding-top: 8px;");],
[#NormalTok("  padding-bottom: 8px;");],
[#NormalTok("  padding-left: 5px;");],
[#NormalTok("  padding-right: 5px;");],
[#NormalTok("  color: #333333;");],
[#NormalTok("  background-color: #FFFFFF;");],
[#NormalTok("  font-size: 100%;");],
[#NormalTok("  font-weight: initial;");],
[#NormalTok("  text-transform: inherit;");],
[#NormalTok("  border-top-style: solid;");],
[#NormalTok("  border-top-width: 2px;");],
[#NormalTok("  border-top-color: #D3D3D3;");],
[#NormalTok("  border-bottom-style: solid;");],
[#NormalTok("  border-bottom-width: 2px;");],
[#NormalTok("  border-bottom-color: #D3D3D3;");],
[#NormalTok("  border-left-style: none;");],
[#NormalTok("  border-left-width: 1px;");],
[#NormalTok("  border-left-color: #D3D3D3;");],
[#NormalTok("  border-right-style: none;");],
[#NormalTok("  border-right-width: 1px;");],
[#NormalTok("  border-right-color: #D3D3D3;");],
[#NormalTok("  vertical-align: middle;");],
[#NormalTok("  text-align: left;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_empty_group_heading {");],
[#NormalTok("  padding: 0.5px;");],
[#NormalTok("  color: #333333;");],
[#NormalTok("  background-color: #FFFFFF;");],
[#NormalTok("  font-size: 100%;");],
[#NormalTok("  font-weight: initial;");],
[#NormalTok("  border-top-style: solid;");],
[#NormalTok("  border-top-width: 2px;");],
[#NormalTok("  border-top-color: #D3D3D3;");],
[#NormalTok("  border-bottom-style: solid;");],
[#NormalTok("  border-bottom-width: 2px;");],
[#NormalTok("  border-bottom-color: #D3D3D3;");],
[#NormalTok("  vertical-align: middle;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_from_md > :first-child {");],
[#NormalTok("  margin-top: 0;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_from_md > :last-child {");],
[#NormalTok("  margin-bottom: 0;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_row {");],
[#NormalTok("  padding-top: 8px;");],
[#NormalTok("  padding-bottom: 8px;");],
[#NormalTok("  padding-left: 5px;");],
[#NormalTok("  padding-right: 5px;");],
[#NormalTok("  margin: 10px;");],
[#NormalTok("  border-top-style: solid;");],
[#NormalTok("  border-top-width: 1px;");],
[#NormalTok("  border-top-color: #D3D3D3;");],
[#NormalTok("  border-left-style: none;");],
[#NormalTok("  border-left-width: 1px;");],
[#NormalTok("  border-left-color: #D3D3D3;");],
[#NormalTok("  border-right-style: none;");],
[#NormalTok("  border-right-width: 1px;");],
[#NormalTok("  border-right-color: #D3D3D3;");],
[#NormalTok("  vertical-align: middle;");],
[#NormalTok("  overflow-x: hidden;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_stub {");],
[#NormalTok("  color: #333333;");],
[#NormalTok("  background-color: #FFFFFF;");],
[#NormalTok("  font-size: 100%;");],
[#NormalTok("  font-weight: initial;");],
[#NormalTok("  text-transform: inherit;");],
[#NormalTok("  border-right-style: solid;");],
[#NormalTok("  border-right-width: 2px;");],
[#NormalTok("  border-right-color: #D3D3D3;");],
[#NormalTok("  padding-left: 5px;");],
[#NormalTok("  padding-right: 5px;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_stub_row_group {");],
[#NormalTok("  color: #333333;");],
[#NormalTok("  background-color: #FFFFFF;");],
[#NormalTok("  font-size: 100%;");],
[#NormalTok("  font-weight: initial;");],
[#NormalTok("  text-transform: inherit;");],
[#NormalTok("  border-right-style: solid;");],
[#NormalTok("  border-right-width: 2px;");],
[#NormalTok("  border-right-color: #D3D3D3;");],
[#NormalTok("  padding-left: 5px;");],
[#NormalTok("  padding-right: 5px;");],
[#NormalTok("  vertical-align: top;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_row_group_first td {");],
[#NormalTok("  border-top-width: 2px;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_row_group_first th {");],
[#NormalTok("  border-top-width: 2px;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_summary_row {");],
[#NormalTok("  color: #333333;");],
[#NormalTok("  background-color: #FFFFFF;");],
[#NormalTok("  text-transform: inherit;");],
[#NormalTok("  padding-top: 8px;");],
[#NormalTok("  padding-bottom: 8px;");],
[#NormalTok("  padding-left: 5px;");],
[#NormalTok("  padding-right: 5px;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_first_summary_row {");],
[#NormalTok("  border-top-style: solid;");],
[#NormalTok("  border-top-color: #D3D3D3;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_first_summary_row.thick {");],
[#NormalTok("  border-top-width: 2px;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_last_summary_row {");],
[#NormalTok("  padding-top: 8px;");],
[#NormalTok("  padding-bottom: 8px;");],
[#NormalTok("  padding-left: 5px;");],
[#NormalTok("  padding-right: 5px;");],
[#NormalTok("  border-bottom-style: solid;");],
[#NormalTok("  border-bottom-width: 2px;");],
[#NormalTok("  border-bottom-color: #D3D3D3;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_grand_summary_row {");],
[#NormalTok("  color: #333333;");],
[#NormalTok("  background-color: #FFFFFF;");],
[#NormalTok("  text-transform: inherit;");],
[#NormalTok("  padding-top: 8px;");],
[#NormalTok("  padding-bottom: 8px;");],
[#NormalTok("  padding-left: 5px;");],
[#NormalTok("  padding-right: 5px;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_first_grand_summary_row {");],
[#NormalTok("  padding-top: 8px;");],
[#NormalTok("  padding-bottom: 8px;");],
[#NormalTok("  padding-left: 5px;");],
[#NormalTok("  padding-right: 5px;");],
[#NormalTok("  border-top-style: double;");],
[#NormalTok("  border-top-width: 6px;");],
[#NormalTok("  border-top-color: #D3D3D3;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_last_grand_summary_row_top {");],
[#NormalTok("  padding-top: 8px;");],
[#NormalTok("  padding-bottom: 8px;");],
[#NormalTok("  padding-left: 5px;");],
[#NormalTok("  padding-right: 5px;");],
[#NormalTok("  border-bottom-style: double;");],
[#NormalTok("  border-bottom-width: 6px;");],
[#NormalTok("  border-bottom-color: #D3D3D3;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_striped {");],
[#NormalTok("  background-color: rgba(128, 128, 128, 0.05);");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_table_body {");],
[#NormalTok("  border-top-style: solid;");],
[#NormalTok("  border-top-width: 2px;");],
[#NormalTok("  border-top-color: #D3D3D3;");],
[#NormalTok("  border-bottom-style: solid;");],
[#NormalTok("  border-bottom-width: 2px;");],
[#NormalTok("  border-bottom-color: #D3D3D3;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_footnotes {");],
[#NormalTok("  color: #333333;");],
[#NormalTok("  background-color: #FFFFFF;");],
[#NormalTok("  border-bottom-style: none;");],
[#NormalTok("  border-bottom-width: 2px;");],
[#NormalTok("  border-bottom-color: #D3D3D3;");],
[#NormalTok("  border-left-style: none;");],
[#NormalTok("  border-left-width: 2px;");],
[#NormalTok("  border-left-color: #D3D3D3;");],
[#NormalTok("  border-right-style: none;");],
[#NormalTok("  border-right-width: 2px;");],
[#NormalTok("  border-right-color: #D3D3D3;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_footnote {");],
[#NormalTok("  margin: 0px;");],
[#NormalTok("  font-size: 90%;");],
[#NormalTok("  padding-top: 4px;");],
[#NormalTok("  padding-bottom: 4px;");],
[#NormalTok("  padding-left: 5px;");],
[#NormalTok("  padding-right: 5px;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_sourcenotes {");],
[#NormalTok("  color: #333333;");],
[#NormalTok("  background-color: #FFFFFF;");],
[#NormalTok("  border-bottom-style: none;");],
[#NormalTok("  border-bottom-width: 2px;");],
[#NormalTok("  border-bottom-color: #D3D3D3;");],
[#NormalTok("  border-left-style: none;");],
[#NormalTok("  border-left-width: 2px;");],
[#NormalTok("  border-left-color: #D3D3D3;");],
[#NormalTok("  border-right-style: none;");],
[#NormalTok("  border-right-width: 2px;");],
[#NormalTok("  border-right-color: #D3D3D3;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_sourcenote {");],
[#NormalTok("  font-size: 90%;");],
[#NormalTok("  padding-top: 4px;");],
[#NormalTok("  padding-bottom: 4px;");],
[#NormalTok("  padding-left: 5px;");],
[#NormalTok("  padding-right: 5px;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_left {");],
[#NormalTok("  text-align: left;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_center {");],
[#NormalTok("  text-align: center;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_right {");],
[#NormalTok("  text-align: right;");],
[#NormalTok("  font-variant-numeric: tabular-nums;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_font_normal {");],
[#NormalTok("  font-weight: normal;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_font_bold {");],
[#NormalTok("  font-weight: bold;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_font_italic {");],
[#NormalTok("  font-style: italic;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_super {");],
[#NormalTok("  font-size: 65%;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_footnote_marks {");],
[#NormalTok("  font-size: 75%;");],
[#NormalTok("  vertical-align: 0.4em;");],
[#NormalTok("  position: initial;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_asterisk {");],
[#NormalTok("  font-size: 100%;");],
[#NormalTok("  vertical-align: 0;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_indent_1 {");],
[#NormalTok("  text-indent: 5px;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_indent_2 {");],
[#NormalTok("  text-indent: 10px;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_indent_3 {");],
[#NormalTok("  text-indent: 15px;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_indent_4 {");],
[#NormalTok("  text-indent: 20px;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .gt_indent_5 {");],
[#NormalTok("  text-indent: 25px;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii .katex-display {");],
[#NormalTok("  display: inline-flex !important;");],
[#NormalTok("  margin-bottom: 0.75em !important;");],
[#NormalTok("}");],
[],
[#NormalTok("#cnsdxozdii div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {");],
[#NormalTok("  height: 0px !important;");],
[#NormalTok("}");],
[#NormalTok("</style>");],
[#NormalTok("<table class=\"gt_table\" data-quarto-disable-processing=\"false\" data-quarto-bootstrap=\"false\">");],
[#NormalTok("  <thead>");],
[#NormalTok("    <tr class=\"gt_heading\">");],
[#NormalTok("      <td colspan=\"3\" class=\"gt_heading gt_title gt_font_normal\" style>Equivalencia de Objetivos de Precisión</td>");],
[#NormalTok("    </tr>");],
[#NormalTok("    <tr class=\"gt_heading\">");],
[#NormalTok("      <td colspan=\"3\" class=\"gt_heading gt_subtitle gt_font_normal gt_bottom_border\" style>Conversión de Margen de Error Absoluto a Coeficiente de Variación (90% Confianza, p=50%)</td>");],
[#NormalTok("    </tr>");],
[#NormalTok("    <tr class=\"gt_col_headings\">");],
[#NormalTok("      <th class=\"gt_col_heading gt_columns_bottom_border gt_left\" rowspan=\"1\" colspan=\"1\" scope=\"col\" id=\"Objetivo\">Dominio de Estimación</th>");],
[#NormalTok("      <th class=\"gt_col_heading gt_columns_bottom_border gt_right\" rowspan=\"1\" colspan=\"1\" scope=\"col\" id=\"MdE_Original\">Margen de Error (MdE)</th>");],
[#NormalTok("      <th class=\"gt_col_heading gt_columns_bottom_border gt_right\" rowspan=\"1\" colspan=\"1\" scope=\"col\" id=\"CV_Objetivo_Pct\">CV Objetivo</th>");],
[#NormalTok("    </tr>");],
[#NormalTok("  </thead>");],
[#NormalTok("  <tbody class=\"gt_table_body\">");],
[#NormalTok("    <tr><td headers=\"Objetivo\" class=\"gt_row gt_left\">TE/Área</td>");],
[#NormalTok("<td headers=\"MdE_Original\" class=\"gt_row gt_right\">3.0%</td>");],
[#NormalTok("<td headers=\"CV_Objetivo_Pct\" class=\"gt_row gt_right\">3.65%</td></tr>");],
[#NormalTok("    <tr><td headers=\"Objetivo\" class=\"gt_row gt_left\">TE/Región</td>");],
[#NormalTok("<td headers=\"MdE_Original\" class=\"gt_row gt_right\">4.0%</td>");],
[#NormalTok("<td headers=\"CV_Objetivo_Pct\" class=\"gt_row gt_right\">4.86%</td></tr>");],
[#NormalTok("    <tr><td headers=\"Objetivo\" class=\"gt_row gt_left\">TE/Región agrup.</td>");],
[#NormalTok("<td headers=\"MdE_Original\" class=\"gt_row gt_right\">5.0%</td>");],
[#NormalTok("<td headers=\"CV_Objetivo_Pct\" class=\"gt_row gt_right\">6.08%</td></tr>");],
[#NormalTok("  </tbody>");],
[#NormalTok("  ");],
[#NormalTok("</table>");],
[#NormalTok("</div>");],));
::: :::

== Cálculo del DEFF y del ESS
<cálculo-del-deff-y-del-ess>
La existencia de #emph[clusters] o conglomerados espaciales permite reducir los costos logísticos tanto en términos de transporte (especialmente en diseños presenciales) y reduce el costo de elaborar listas de direcciones/contactos de las unidades de selección finales (especialmente en diseños polietápicos). Mediante la combinación de ambos mecansmos, se reduce el costo unitario de realizar encuestas. A cambio, suele generar mayores varianzas para un tamaño de muestra determinado en comparación con una muestra de azar simple @valliant2018[pág. 4].

Dos medidas sencillas, pero extremadamente útiles para expresar el efecto de usar #emph[clusters] o conglomerados en las estimaciones de la encuesta, son el #strong[efecto del diseño] (#emph[deff o design effect]) y el #strong[tamaño efectivo de la muestra] (#emph[ess o effective size sample]) @kish1965.

Con base en la estrategia anterior de convertir los márgenes de error (#emph[MdE]) en coeficientes de variación (#emph[CV]), ahora vamos a pasar a modelar el efecto del diseño ($D E F F$) a partir de diferentes supuestos y escenarios. Esto tendrá una función más pedagógica que instrumental en el diseño de la muestra. La razón es que el $D E F F$ es específico para cada estimador que se quiera calcular por lo que, salvo que se quiera realizar un diseño complejo para estimar una sola variable, desde un punto de vista estrictamente estadístico, se deberían calcular un $D E F F$ para cada estimación. Cuando decimos específico queremos decir que su valor es variable para diferentes estimadores dentro de un mismo diseño muestral. En este caso, podría haber un #emph[DEFF] para la matrícula y un DEFF diferente para el índice de vulnerabilidad territorial. Otro punto negativo del #emph[DEFF] es que no siempre es relevante en muestras en donde las varinzas difieren a través de los estratos, en donde los subgrupos son seleccionados intencionalmente a diferentes porcentajes o donde diferentes subgrupos poseen diferentes tasas de respuesta @zipf.

Dicho estos puntos negativos sobre el #emph[DEFF], cable aclarar que se trata de un concepto muy intuitivo para captar que se pierde y que se gana con un diseño polietápido (versus un aleatorio simple), pero también sirve para comparar entre diferentes diseños polietápicos. Gracias a él, se entiende por qué la #strong[estratificación] es más efectiva cuando los elementos de cada estrato son homogéneos dentro de cada estrato, pero diferente entre estratos @kish1965[pág. 76]. Del mismo modo, también es intuitivo para comprender que a mayor homogeneidad dentro de un #strong[cluster o conglomerado] mayor aumento del #emph[DEFF] dado que los casos llegan a su saturación teórica más rápidamente. En otras palabras, se llega más rápido a la situación en donde cada nuevo caso marginal aporta información cada menos nueva y cada vez más redundante. Por esta razón, si se asume que los cluster son muy homogéneos en su interior, no es buena idea seleccionar muchos casos en cada uno de ellos, porque muchos de ellos se repetiran y aportarán información redundante. De la misma manera, en una muestra polietápica por timbreo, y a igualdad de cantidad de casos totales, la precisión de las estimaciones mejora si se usan más puntos muestras con menos personas en cada uno de ellos.

Expresado de modo alternativo, el #emph[DEFF] permite comprender los pros y contras de jugar el juego de cuantos casos más baratos (por estar más juntos espacialmente) estoy dispuesto a agregar para compensar, casi con seguridad, su peor eficiencia estadística (por ser más homogéneos entre sí). En este contexto, el #emph[DEFF] permite optimizar el tipo de diseño polietápico a seguir.

La definición típica del DEFF, debido a su creador Leslie Kish, es que el mismo es la razón de la varianzade un estimador en una muestra compleja sobre la varianza de ese mismo estimador en una muestra de muestreo simple @kish1965[pág. 75].

== El Efecto del Diseño (#emph[deff]) y la Correlación Intracluster ($rho$)
<el-efecto-del-diseño-deff-y-la-correlación-intracluster-rho>
Como se ha reflexionado en la sección anterior, si los clusters son muy homogéneos en su interior, no tiene sentido seleccionar muchos estudiantes por establecimiento porque nos aportarán información redundante. Esta homogeneidad interna se modela formalmente mediante la #strong[Correlación Intracluster] ($rho$ o #emph[ICC]) @lumley2010[pág. 51]:

- #strong[Si] $rho = 0$: Los estudiantes dentro de una misma escuela son tan heterogéneos como si los hubiéramos seleccionado al azar en toda la provincia. No hay "efecto de pertenencia escolar". Cada encuesta adicional nos aporta mucha información nueva.
- #strong[Si] $rho = 1$: Todos los estudiantes de una escuela son idénticos. Ir a encuestar al segundo, tercero o quinto estudiante de la misma escuela no nos aporta nada de información nueva.

En encuestas socioeducativas de perfil estudiantil en América Latina, el valor empírico de $rho$ suele oscilar entre $0 \, 02$ y $0 \, 10$ @valliant2018[pág. 247]@grosh1996[pág. 58-59]. Para nuestro diseño, utilizaremos un valor de $rho = 0 \, 1$, el cual representa una hipótesis conservadora, pero sumamente realista que nos protege de subestimar el error muestral.

Para estimar formalmente este incremento en la varianza (el $d e f f$), utilizamos la ecuación clásica de Kish:

$ d e f f = 1 + \( b - 1 \) rho $

Donde $b$ representa el tamaño del cluster. En este caso sería la cantidad de estudiantes seleccionados por escuela.

=== Rediseño de la segunda etapa para garantizar la autoponderación y reducir el deff
<rediseño-de-la-segunda-etapa-para-garantizar-la-autoponderación-y-reducir-el-deff>
El requerimiento sugería relevar #strong[todas las secciones] de cada escuela seleccionada. A pesar de que en este tipo de establecimientos parece haber pocos con muchas secciones (#strong[?\@fig-explo\_marco\_continuas]), esto puede generar que el número de estudiantes encuestados por escuela variara drásticamente. Esto tendría el efecto de afectar la preciada #strong[autoponderación] de una muestra PPS, creando la necesidad tanto de construir ponderadores como de utilizarlos al momento del análisis. Por otro lado, incrementaría el tamaño medio de los estudiantes por cada cluster/establecimiento aumentado el parámetro ($b$) y, de ese modo, disparando el $d e f f$ y requiriendo un tamaño de muestra total mayor.

Para solucionar esto, se propone rediseñar la segunda etapa del muestreo de la siguiente manera:

\1. En cada escuela seleccionada en la primera etapa, #strong[se sortea de manera estrictamente aleatoria una única (1) sección] (con probabilidad $1 \/ B_i$, donde $B_i$ es la cantidad de secciones de la sede $i$).

\2. Dentro de esa sección sorteada, #strong[se seleccionan exactamente 5 estudiantes] ($b = 5$).

Al mantener el tamaño de cluster fijo y constante en $b = 5$ estudiantes para todas las escuelas, se logran dos ventajas metodológicas:

- Se #strong[garantiza una muestra estrictamente autoponderada.] La razón es queal multiplicar la probabilidad de la primera etapa (PPS proporcional a la matrícula) con el sorteo de una sección en la segunda etapa ($1 \/ B_i$), la probabilidad final de selección del estudiante se vuelve constante. Podremos analizar los datos directamente sin necesidad de ponderadores complejos.

- #strong[Minimizamos el Efecto del Diseño:] Al reducir el cluster a solo 5 alumnos, el $d e f f$ se reduce drásticamente: $ d e f f = 1 + \( 5 - 1 \) dot.op 0 \, 1 = 1 + 4 dot.op 0 \, 1 = 1 \, 4 $

Un $d e f f$ de $1 \, 4$ significa que se necesitan un $40 %$ más de casos que un muestreo aleatorio simple, reduciendo el tamaño de muestra total necesario en campo en comparación con el supuesto inicial de $d e f f = 2 \, 0$.

=== Simulación del impacto de la Correlación Intracluster ($rho$) y el tamaño del cluster ($b$)
<simulación-del-impacto-de-la-correlación-intracluster-rho-y-el-tamaño-del-cluster-b>
Para comprender de manera intuitiva y didáctica cómo interactúan el tamaño del cluster por escuela ($b$) y la homogeneidad de las instituciones ($rho$), se realiza una simulación que calcula el $d e f f$ y evalúa el tamaño de muestra teórico final requerido bajo escenarios alternativos de diseño para estimar una proporción con $C V = 3 \, 65 %$ que era la estipulada para el cruce tipo de establecimiento y área (#strong[?\@tbl-traduccion\_mde\_cv]).

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji")); table(
  columns: 7,
  align: (left,right,right,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 7, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); Simulación Comparativa de Escenarios de Diseño Muestral],
    table.cell(align: center, colspan: 7, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Impacto en el tamaño muestral requerido para una precisión de CV = 3,65% (MdE = 3%)],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Estrategia de Selección], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Estudiantes por Sede (b)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Homogeneidad Escolar (Rho)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Efecto de Diseño (Deff)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Total Estudiantes (n)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Tamaño Efectivo (ESS)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Total Sedes a Visitar],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Diseño 1 sección (b=5)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.08], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[203], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[188], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[41],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Diseño 1 sección (b=5)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.40], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[263], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[188], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[53],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Diseño 1 sección (b=5)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[18%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.72], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[323], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[188], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Diseño 2 secciones (b=10)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.18], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[221], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[187], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[22],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Diseño 2 secciones (b=10)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.90], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[357], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[188], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[36],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Diseño 2 secciones (b=10)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[18%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.62], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[492], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[188], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[49],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Diseño 3 secciones (b=15)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.28], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[240], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[188], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Diseño 3 secciones (b=15)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.40], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[450], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[187], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[30],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Diseño 3 secciones (b=15)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[18%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.52], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[661], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[188], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[44],
)}
], caption: figure.caption(
position: top, 
[
Simulación del impacto de la correlación intracluster (rho) y el tamaño del cluster por escuela (b) en la cantidad de casos finales
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-simulacion_deff>


Como se observa claramente en la tabla simulada, a medida que aumentamos el número de estudiantes por escuela ($b$), el $d e f f$ aumenta drásticamente. Esto es especialmente cierto cuando se acompaña de altos valores de correlaciones intraclusters ($rho$).

Por ejemplo, si asumiéramos el escenario tradicional de relevar todas las secciones con un promedio de $b = 15$ encuestas por escuela (3 secciones y 5 estudiantes por cada una de ellas) y una homogeneidad escolar del $8 %$, el $d e f f$ se dispararía a $2 \, 12$, exigiéndonos encuestar a $398$ estudiantes para lograr la misma precisión que con $248$ estudiantes usando el diseño propuesto de $b = 5$ ($d e f f = 1 \, 32$).

Aunque concentrar más estudiantes por escuela reduce la cantidad de sedes físicas a visitar (pasa de $50$ a $27$ sedes), la cantidad de cuestionarios a procesar es más del doble. Por ende, nuestro diseño con $b = 5$ representa un equilibrio óptimo entre viabilidad logística de campo y economía de recursos analíticos.

== Cálculo del tamaño de muestra por estrato (#NormalTok("PracTools");)
<cálculo-del-tamaño-de-muestra-por-estrato-practools>
Una vez que hemos determinado los coeficientes de variación ($C V$) objetivos de precisión para cada cruce de tipo de establecimiento y división geográfica, y habiendo modelado el efecto de diseño empírico ($d e f f = 1 \, 4$) derivado de la selección de una sección y 5 estudiantes por establecimiento, pasamos a calcular el tamaño de muestra teórico.

Para esto, utilizaremos la función #NormalTok("nProp"); de la librería #NormalTok("PracTools");. Esta función estima el tamaño mínimo de muestra en un diseño de Muestreo Aleatorio Simple (MAS) para una proporción en un escenario de máxima varianza ($p = 0 \, 5$). Luego, multiplicaremos ese tamaño por nuestro $d e f f = 1 \, 4$ para obtener el tamaño final de estudiantes y, dividiendo por 5, la cantidad de sedes a seleccionar:

#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 6,
  align: (left,right,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 6, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); Tamaños de Muestra Requeridos por Dominio de Inferencia],
    table.cell(align: center, colspan: 6, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Cálculo de alumnos y sedes físicas a seleccionar (5 estudiantes por establecimiento)],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Dominio de Estimación], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Margen de Error (MdE)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); CV Objetivo], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Deff], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Estudiantes Requeridos (n)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Sedes a Seleccionar],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENS/EPA por Área (AMBA/Interior)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.0%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.65%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.4], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1053], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[211],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[FINES por Región Individual], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.0%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6.08%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.4], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[379], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[76],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[FINES por Región Agrupada], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.0%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.86%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.4], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[592], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[119],
)}
En la siguiente sección, procederemos a segmentar nuestro marco muestral (#NormalTok("df_sampling_frame");) real por cada estrato de diseño e identificar cuántos alumnos y sedes le corresponden empíricamente en la muestra física.

== Asignación empírica de la muestra y corrección por población finita (FPC)
<asignación-empírica-de-la-muestra-y-corrección-por-población-finita-fpc>
Una vez calculados los tamaños muestrales teóricos bajo el supuesto de universos infinitos o muy grandes, el paso metodológico fundamental es confrontar estos requerimientos con el tamaño real de nuestro marco muestral (#NormalTok("df_sampling_frame");).

En este diseño polietápico, la primera etapa de selección se realizará utilizando #strong[Probabilidad Proporcional al Tamaño (PPS)] en función de la matrícula de cada establecimiento. La selección PPS tiene la inmensa ventaja de otorgar mayor probabilidad de inclusión a las escuelas grandes (que concentran a la mayor cantidad de estudiantes del universo). En la segunda etapa, al sortear exactamente una sección y seleccionar un número fijo de 5 estudiantes, logramos que la muestra sea estrictamente #strong[autoponderada] a nivel de estudiante.

Sin embargo, al analizar el marco muestral real, nos enfrentamos a dos particularidades del universo que exigen una intervención metodológica: 1. #strong[La Corrección por Población Finita (FPC):] Cuando el tamaño de muestra de sedes calculado ($n_h$) representa una fracción significativa del total de sedes disponibles en el universo de ese estrato ($N_h$, por ejemplo, más del $5 %$), la varianza del estimador disminuye porque conocemos a una porción muy grande de la población. Para evitar un sobremuestreo innecesario y costoso, corregimos el tamaño muestral aplicando el factor de población finita: $ n_(upright("corregido") \, h) = frac(n_h, 1 + n_h / N_h) $ 2. #strong[Estratos pequeños e inferencia regional:] En ofertas como FINES en regiones del interior muy pequeñas, el requerimiento teórico de precisión regional (5% MdE, que exige unas 76 sedes por región) puede superar la cantidad física de sedes disponibles en el universo de esa región. En esos casos, el estrato se vuelve automáticamente #strong[censal] (se seleccionan todas las sedes del estrato, asignándoles probabilidad de inclusión $pi_i = 1$).

A continuación, he escrito el código en R para estructurar los estratos en nuestro marco real, calcular los tamaños finales corregidos de estudiantes y sedes, y preparar la asignación empírica:

#Skylighting(([#CommentTok("#| label: asignacion_muestra_real");],
[],
[#CommentTok("# 1. Definimos los estratos de diseño en nuestro marco real");],
[#NormalTok("df_marco_estratificado ");#OtherTok("=");#NormalTok(" df_sampling_frame ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#CommentTok("# Construimos el estrato de diseño");],
[#NormalTok("    ");#AttributeTok("estrato_diseno =");#NormalTok(" ");#FunctionTok("case_when");#NormalTok("(");],
[#NormalTok("      tipo_est_adulto ");#SpecialCharTok("==");#NormalTok(" ");#StringTok("\"CEBAS\"");#NormalTok(" ");#SpecialCharTok("~");#NormalTok(" ");#StringTok("\"CEBAS - Censal\"");#NormalTok(",");],
[#NormalTok("      tipo_est_adulto ");#SpecialCharTok("==");#NormalTok(" ");#StringTok("\"FINES\"");#NormalTok(" ");#SpecialCharTok("~");#NormalTok(" ");#FunctionTok("paste0");#NormalTok("(");#StringTok("\"FINES - Región \"");#NormalTok(", region),");],
[#NormalTok("      tipo_est_adulto ");#SpecialCharTok("%in%");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"CENS\"");#NormalTok(", ");#StringTok("\"EPA\"");#NormalTok(") ");#SpecialCharTok("~");#NormalTok(" ");#FunctionTok("paste0");#NormalTok("(tipo_est_adulto, ");#StringTok("\" - \"");#NormalTok(", area),");],
[#NormalTok("      ");#AttributeTok(".default =");#NormalTok(" ");#StringTok("\"Otros\"");],
[#NormalTok("    )");],
[#NormalTok("  )");],
[],
[#CommentTok("# 2. Obtenemos el tamaño del universo (N de sedes y matrícula total) por estrato");],
[#NormalTok("resumen_universo ");#OtherTok("=");#NormalTok(" df_marco_estratificado ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(estrato_diseno, tipo_est_adulto, region, area) ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("N_sedes_universo =");#NormalTok(" ");#FunctionTok("n");#NormalTok("(),");],
[#NormalTok("    ");#AttributeTok("Matricula_universo =");#NormalTok(" ");#FunctionTok("sum");#NormalTok("(matricula, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok(".groups =");#NormalTok(" ");#StringTok("\"drop\"");],
[#NormalTok("  )");],
[],
[#CommentTok("# 3. Asignamos los requerimientos teóricos de alumnos y sedes a cada estrato");],
[#CommentTok("# CENS/EPA = 3% MdE, FINES individual = 5% MdE");],
[#NormalTok("resumen_asignacion ");#OtherTok("=");#NormalTok(" resumen_universo ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#CommentTok("# Asignamos el tamaño de muestra teórico de sedes (antes de FPC)");],
[#NormalTok("    ");#AttributeTok("sedes_teoricas_n =");#NormalTok(" ");#FunctionTok("case_when");#NormalTok("(");],
[#NormalTok("      tipo_est_adulto ");#SpecialCharTok("==");#NormalTok(" ");#StringTok("\"CEBAS\"");#NormalTok(" ");#SpecialCharTok("~");#NormalTok(" N_sedes_universo, ");#CommentTok("# Censal");],
[#NormalTok("      tipo_est_adulto ");#SpecialCharTok("%in%");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"CENS\"");#NormalTok(", ");#StringTok("\"EPA\"");#NormalTok(") ");#SpecialCharTok("~");#NormalTok(" muestra_te_area");#SpecialCharTok("$");#NormalTok("n_sedes,");],
[#NormalTok("      tipo_est_adulto ");#SpecialCharTok("==");#NormalTok(" ");#StringTok("\"FINES\"");#NormalTok(" ");#SpecialCharTok("~");#NormalTok(" muestra_fines_individual");#SpecialCharTok("$");#NormalTok("n_sedes,");],
[#NormalTok("      ");#AttributeTok(".default =");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    ),");],
[#NormalTok("    ");#CommentTok("# Aplicamos la Corrección por Población Finita (FPC)");],
[#NormalTok("    ");#AttributeTok("sedes_corregidas_n =");#NormalTok(" ");#FunctionTok("case_when");#NormalTok("(");],
[#NormalTok("      tipo_est_adulto ");#SpecialCharTok("==");#NormalTok(" ");#StringTok("\"CEBAS\"");#NormalTok(" ");#SpecialCharTok("~");#NormalTok(" N_sedes_universo,");],
[#NormalTok("      ");#CommentTok("# Si el tamaño requerido supera o iguala al universo, se vuelve censal");],
[#NormalTok("      sedes_teoricas_n ");#SpecialCharTok(">=");#NormalTok(" N_sedes_universo ");#SpecialCharTok("~");#NormalTok(" N_sedes_universo,");],
[#NormalTok("      ");#CommentTok("# De lo contrario, aplicamos la fórmula del FPC");],
[#NormalTok("      ");#AttributeTok(".default =");#NormalTok(" ");#FunctionTok("ceiling");#NormalTok("(sedes_teoricas_n ");#SpecialCharTok("/");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#SpecialCharTok("+");#NormalTok(" (sedes_teoricas_n ");#SpecialCharTok("/");#NormalTok(" N_sedes_universo)))");],
[#NormalTok("    ),");],
[#NormalTok("    ");#CommentTok("# Calculamos la muestra de estudiantes correspondiente (5 por sede)");],
[#NormalTok("    ");#AttributeTok("estudiantes_muestra_n =");#NormalTok(" ");#FunctionTok("if_else");#NormalTok("(tipo_est_adulto ");#SpecialCharTok("==");#NormalTok(" ");#StringTok("\"CEBAS\"");#NormalTok(", ");],
[#NormalTok("                                    sedes_corregidas_n ");#SpecialCharTok("*");#NormalTok(" ");#DecValTok("5");#NormalTok(", ");#CommentTok("# Asumiendo 5 para simular");],
[#NormalTok("                                    sedes_corregidas_n ");#SpecialCharTok("*");#NormalTok(" ");#DecValTok("5");#NormalTok(")");],
[#NormalTok("  )");],
[],
[#CommentTok("# 4. Formateamos y presentamos los primeros estratos para análisis");],
[#NormalTok("resumen_asignacion ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(tipo_est_adulto ");#SpecialCharTok("!=");#NormalTok(" ");#StringTok("\"CEBAS\"");#NormalTok(") ");#SpecialCharTok("|>");#NormalTok(" ");#CommentTok("# Excluimos CEBAS para visualizar los muestreables");],
[#NormalTok("  ");#FunctionTok("arrange");#NormalTok("(tipo_est_adulto, region) ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("slice_head");#NormalTok("(");#AttributeTok("n =");#NormalTok(" ");#DecValTok("15");#NormalTok(") ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("select");#NormalTok("(estrato_diseno, N_sedes_universo, Matricula_universo, sedes_teoricas_n, sedes_corregidas_n, estudiantes_muestra_n) ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("gt");#NormalTok("() ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("tab_header");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"Asignación de Muestra por Estrato y Corrección FPC (Primeras 15 celdas)\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("subtitle =");#NormalTok(" ");#StringTok("\"Comparación entre requerimiento teórico inicial y tamaño corregido por población finita\"");],
[#NormalTok("  ) ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("cols_label");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("estrato_diseno =");#NormalTok(" ");#StringTok("\"Estrato de Diseño\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("N_sedes_universo =");#NormalTok(" ");#StringTok("\"Sedes Universo (N)\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("Matricula_universo =");#NormalTok(" ");#StringTok("\"Matrícula Universo\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("sedes_teoricas_n =");#NormalTok(" ");#StringTok("\"Sedes Teóricas (n)\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("sedes_corregidas_n =");#NormalTok(" ");#StringTok("\"Sedes Corregidas (FPC)\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("estudiantes_muestra_n =");#NormalTok(" ");#StringTok("\"Alumnos Muestra\"");],
[#NormalTok("  )");],));
Como se observará en los resultados de la simulación empírica en el marco real, la aplicación de la #strong[Corrección por Población Finita (FPC)] es una herramienta de optimización de recursos fundamental. En estratos donde el universo de sedes es acotado, la corrección reduce sustancialmente el número de establecimientos físicos a visitar, manteniendo exactamente la misma precisión estadística exigida.

=== Próximos pasos metodológicos: Hacia muestras balanceadas y el Método del Cubo
<próximos-pasos-metodológicos-hacia-muestras-balanceadas-y-el-método-del-cubo>
Una vez que hemos asignado de forma clásica la muestra por estratos y sabemos cuántas sedes necesitamos de cada uno, el gran desafío es la #strong[estrategia de selección física de los establecimientos].

Si bien podríamos optar por una selección sistemática clásica PPS ordenada unidimensionalmente por el IVSE-T, este enfoque presenta limitaciones para asegurar que la muestra represente adecuadamente la riqueza y heterogeneidad territorial de la provincia. Por ello, en la siguiente sección evaluaremos una alternativa de vanguardia: #strong[El Método del Cubo (#NormalTok("lcube");)] para la selección de muestras balanceadas y bien distribuidas espacialmente.

El método del cubo nos permitirá forzar a que la muestra de sedes seleccionada represente de forma óptima tanto a las variables categóricas de oferta y región, como a la distribución continua de latitud, longitud e Índice de Vulnerabilidad Territorial simultáneamente.

== Selección de la Primera Etapa: Método del Cubo (#NormalTok("lcube");) y Probabilidad Proporcional al Tamaño (PPS)
<selección-de-la-primera-etapa-método-del-cubo-lcube-y-probabilidad-proporcional-al-tamaño-pps>
Dada la ausencia de coordenadas geográficas precisas (latitud y longitud) en este marco muestral, se propone una estrategia metodológica adaptada que explota al máximo la variable continua del #strong[Índice de Vulnerabilidad Territorial (IVT/IVSE)] (#NormalTok("ivse"); en nuestro dataset).

El #strong[Método del Cubo] se implementará bajo la siguiente estructura lógica de dos dimensiones:

+ #strong[Balanceo (Tendencia Central en #NormalTok("Xba");):] Obligamos al algoritmo a que los valores medios estimados de la muestra coincidan de forma exacta con los parámetros conocidos del universo. Balancearemos por:
  - #strong[Ámbito] (Urbano/Rural).
  - #strong[Tipo de Establecimiento] (CENS / EPA / FINES).
  - #strong[Área] (AMBA / Interior).
  - #strong[La media del IVT (IVSE):] Garantizando que el promedio de vulnerabilidad de las sedes de la muestra represente fielmente al promedio provincial.
+ #strong[Esparcimiento y Dispersión (#NormalTok("Xsp"); usando el IVT):] Para asegurar que la muestra esté #strong[bien distribuida] a lo largo de todo el espectro socioeducativo (y no concentrada únicamente en escuelas de vulnerabilidad "promedio"), utilizaremos el #strong[IVT estandarizado] como variable continua de esparcimiento en #NormalTok("Xsp");. Esto obligará al algoritmo a dispersar la selección cubriendo de forma óptima desde las sedes con vulnerabilidad muy baja hasta aquellas con vulnerabilidad crítica.

=== Probabilidades de Inclusión PPS y Sedes Auto-representadas
<probabilidades-de-inclusión-pps-y-sedes-auto-representadas>
En un muestreo PPS, la probabilidad de selección de la sede $i$ en el estrato $h$ se define como: $ pi_(i h) = n_(upright("corregida") \, h) dot.op upright("Matrícula")_(i h) / upright("Matrícula Total")_h $

Sin embargo, en escuelas sumamente grandes, esta probabilidad teórica puede resultar mayor a $1$. Estos casos se denominan metodológicamente #strong[sedes auto-representadas] (o de selección forzosa). Debemos identificarlas de forma iterativa, asignarles una probabilidad de inclusión fija de exactamente $1$, y recalcular las probabilidades de inclusión del resto de las sedes con la matrícula remanente para que la suma final de las probabilidades coincida exactamente con nuestro tamaño de muestra asignado.

A continuación, he escrito el código en R para realizar el ajuste iterativo de probabilidades PPS y ejecutar la selección definitiva utilizando el Método del Cubo:

#Skylighting(([#CommentTok("#| label: seleccion_primera_etapa_cubo");],
[],
[#CommentTok("# 1. Limpieza y preparación de variables continuas y estandarización del IVT (IVSE)");],
[#NormalTok("df_marco_seleccion ");#OtherTok("=");#NormalTok(" df_marco_estratificado ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#CommentTok("# Eliminamos sedes que no tengan cargada la matrícula (universo real)");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(");#SpecialCharTok("!");#FunctionTok("is.na");#NormalTok("(matricula), matricula ");#SpecialCharTok(">");#NormalTok(" ");#DecValTok("0");#NormalTok(") ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#CommentTok("# Estandarizamos el IVT (media 0, desviación 1) para un esparcimiento estable");],
[#NormalTok("    ");#AttributeTok("ivse_std =");#NormalTok(" ");#FunctionTok("scale");#NormalTok("(ivse)[, ");#DecValTok("1");#NormalTok("]");],
[#NormalTok("  )");],
[],
[#CommentTok("# 2. Función iterativa para calcular y ajustar las probabilidades de inclusión PPS");],
[#NormalTok("calcular_pi_pps ");#OtherTok("=");#NormalTok(" ");#ControlFlowTok("function");#NormalTok("(matricula_vector, n_sedes_muestra) {");],
[#NormalTok("  N ");#OtherTok("=");#NormalTok(" ");#FunctionTok("length");#NormalTok("(matricula_vector)");],
[#NormalTok("  ");],
[#NormalTok("  ");#CommentTok("# Si la cantidad de sedes requeridas supera o iguala al universo del estrato, todos tienen pi = 1");],
[#NormalTok("  ");#ControlFlowTok("if");#NormalTok("(n_sedes_muestra ");#SpecialCharTok(">=");#NormalTok(" N) {");],
[#NormalTok("    ");#FunctionTok("return");#NormalTok("(");#FunctionTok("rep");#NormalTok("(");#DecValTok("1");#NormalTok(", N))");],
[#NormalTok("  }");],
[#NormalTok("  ");],
[#NormalTok("  ");#CommentTok("# Inicializamos las probabilidades PPS iniciales");],
[#NormalTok("  pi ");#OtherTok("=");#NormalTok(" n_sedes_muestra ");#SpecialCharTok("*");#NormalTok(" (matricula_vector ");#SpecialCharTok("/");#NormalTok(" ");#FunctionTok("sum");#NormalTok("(matricula_vector))");],
[#NormalTok("  ");],
[#NormalTok("  ");#CommentTok("# Ajustamos de manera iterativa para las escuelas auto-representadas (pi >= 1)");],
[#NormalTok("  ");#ControlFlowTok("while");#NormalTok(" (");#FunctionTok("any");#NormalTok("(pi ");#SpecialCharTok(">");#NormalTok(" ");#DecValTok("1");#NormalTok(")) {");],
[#NormalTok("    forzosos ");#OtherTok("=");#NormalTok(" pi ");#SpecialCharTok(">=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("    pi[forzosos] ");#OtherTok("=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("    ");],
[#NormalTok("    n_restante ");#OtherTok("=");#NormalTok(" n_sedes_muestra ");#SpecialCharTok("-");#NormalTok(" ");#FunctionTok("sum");#NormalTok("(pi[forzosos])");],
[#NormalTok("    ");#ControlFlowTok("if");#NormalTok("(n_restante ");#SpecialCharTok("<=");#NormalTok(" ");#DecValTok("0");#NormalTok(") {");],
[#NormalTok("      pi[");#SpecialCharTok("!");#NormalTok("forzosos] ");#OtherTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("      ");#ControlFlowTok("break");],
[#NormalTok("    }");],
[#NormalTok("    ");],
[#NormalTok("    pi[");#SpecialCharTok("!");#NormalTok("forzosos] ");#OtherTok("=");#NormalTok(" n_restante ");#SpecialCharTok("*");#NormalTok(" (matricula_vector[");#SpecialCharTok("!");#NormalTok("forzosos] ");#SpecialCharTok("/");#NormalTok(" ");#FunctionTok("sum");#NormalTok("(matricula_vector[");#SpecialCharTok("!");#NormalTok("forzosos]))");],
[#NormalTok("  }");],
[#NormalTok("  ");#FunctionTok("return");#NormalTok("(pi)");],
[#NormalTok("}");],
[],
[#CommentTok("# 3. Calculamos la probabilidad de inclusión (pi) para cada sede en su estrato correspondiente");],
[#NormalTok("df_marco_seleccion ");#OtherTok("=");#NormalTok(" df_marco_seleccion ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("left_join");#NormalTok("(resumen_asignacion ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("select");#NormalTok("(estrato_diseno, sedes_corregidas_n), ");#AttributeTok("by =");#NormalTok(" ");#StringTok("\"estrato_diseno\"");#NormalTok(") ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(estrato_diseno) ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("pi_pps =");#NormalTok(" ");#FunctionTok("calcular_pi_pps");#NormalTok("(matricula, ");#FunctionTok("first");#NormalTok("(sedes_corregidas_n))");],
[#NormalTok("  ) ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("ungroup");#NormalTok("()");],
[],
[#CommentTok("# 4. Construcción de Matrices para el Algoritmo del Cubo (lcube)");],
[#CommentTok("# Creamos la matriz de balanceo categórico y continuo");],
[#NormalTok("X_balanceo ");#OtherTok("=");#NormalTok(" ");#FunctionTok("model.matrix");#NormalTok("(");#SpecialCharTok("~");#NormalTok(" tipo_est_adulto ");#SpecialCharTok("+");#NormalTok(" ambito ");#SpecialCharTok("+");#NormalTok(" area ");#SpecialCharTok("+");#NormalTok(" ivse ");#SpecialCharTok("-");#NormalTok(" ");#DecValTok("1");#NormalTok(", ");],
[#NormalTok("                          ");#AttributeTok("data =");#NormalTok(" df_marco_seleccion)");],
[],
[#CommentTok("# Agregamos la probabilidad de inclusión como la primera columna para fijar el n muestral");],
[#NormalTok("Xba_final ");#OtherTok("=");#NormalTok(" ");#FunctionTok("cbind");#NormalTok("(df_marco_seleccion");#SpecialCharTok("$");#NormalTok("pi_pps, X_balanceo)");],
[],
[#CommentTok("# Matriz de Esparcimiento basada en la dispersión continua del IVT (IVSE estandarizado)");],
[#NormalTok("Xsp_esparcimiento ");#OtherTok("=");#NormalTok(" ");#FunctionTok("as.matrix");#NormalTok("(df_marco_seleccion");#SpecialCharTok("$");#NormalTok("ivse_std)");],
[],
[#CommentTok("# 5. Ejecución del Algoritmo del Cubo (lcube)");],
[#FunctionTok("set.seed");#NormalTok("(");#DecValTok("42");#NormalTok(") ");#CommentTok("# Fijamos semilla para reproducibilidad");],
[],
[#CommentTok("# Seleccionamos la muestra física");],
[#NormalTok("indices_muestra_cubo ");#OtherTok("=");#NormalTok(" ");#FunctionTok("lcube");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("prob =");#NormalTok(" df_marco_seleccion");#SpecialCharTok("$");#NormalTok("pi_pps, ");],
[#NormalTok("  ");#AttributeTok("Xba =");#NormalTok(" Xba_final, ");],
[#NormalTok("  ");#AttributeTok("Xsp =");#NormalTok(" Xsp_esparcimiento");],
[#NormalTok(")");],
[],
[#CommentTok("# Registramos la selección en nuestro dataset del marco");],
[#NormalTok("df_marco_seleccion");#SpecialCharTok("$");#NormalTok("seleccionada_primera_etapa ");#OtherTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("df_marco_seleccion");#SpecialCharTok("$");#NormalTok("seleccionada_primera_etapa[indices_muestra_cubo] ");#OtherTok("=");#NormalTok(" ");#DecValTok("1");],
[],
[#CommentTok("# 6. Tabla resumen de las escuelas efectivamente seleccionadas en la muestra");],
[#NormalTok("resumen_muestra_final ");#OtherTok("=");#NormalTok(" df_marco_seleccion ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(seleccionada_primera_etapa ");#SpecialCharTok("==");#NormalTok(" ");#DecValTok("1");#NormalTok(") ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(tipo_est_adulto, area) ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("Sedes_Seleccionadas =");#NormalTok(" ");#FunctionTok("n");#NormalTok("(),");],
[#NormalTok("    ");#AttributeTok("Matricula_Promedio =");#NormalTok(" ");#FunctionTok("round");#NormalTok("(");#FunctionTok("mean");#NormalTok("(matricula)),");],
[#NormalTok("    ");#AttributeTok("IVSE_Promedio =");#NormalTok(" ");#FunctionTok("round");#NormalTok("(");#FunctionTok("mean");#NormalTok("(ivse, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("), ");#DecValTok("2");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok(".groups =");#NormalTok(" ");#StringTok("\"drop\"");],
[#NormalTok("  )");],
[],
[#NormalTok("resumen_muestra_final ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("gt");#NormalTok("() ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("tab_header");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"Sedes Seleccionadas en la Primera Etapa (Muestra del Cubo)\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("subtitle =");#NormalTok(" ");#StringTok("\"Consolidado por Tipo de Establecimiento y Área Geográfica\"");],
[#NormalTok("  ) ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("cols_label");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("tipo_est_adulto =");#NormalTok(" ");#StringTok("\"Tipo de Establecimiento\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("area =");#NormalTok(" ");#StringTok("\"Área Geográfica\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("Sedes_Seleccionadas =");#NormalTok(" ");#StringTok("\"Sedes en Muestra\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("Matricula_Promedio =");#NormalTok(" ");#StringTok("\"Matrícula Promedio\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("IVSE_Promedio =");#NormalTok(" ");#StringTok("\"IVT Promedio\"");],
[#NormalTok("  )");],));
Este algoritmo garantiza que nuestra muestra no solo cumple perfectamente con el tamaño físico establecido tras las correcciones de población finita, sino que está excepcionalmente balanceada y bien esparcida a lo largo de toda la vulnerabilidad socioeducativa de la provincia.

#show: appendices.with("Anexos", hide-parent: true)
#heading(level: 1, numbering: none)[Anexos]
= Referencias Bibliográficas
<referencias-bibliográficas>
#block[
] <refs>



#set bibliography(style: "apa7.csl")

#bibliography(("references.bib"))

