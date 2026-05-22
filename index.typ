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
  date: "22 de mayo de 2026",
  lang: "es",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
  list-of-figure-title: "Índice de figuras",
  list-of-table-title: "Índice de tablas",
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

Dentro del ecosistema de R, ejemplos de librerías para analizar datos producidos con diseños muestrales pueden considerarse #link("https://r-survey.r-forge.r-project.org/survey/")[survey], #link("https://bschneidr.github.io/svrep/")[svrep] y su correspondiente versión tidy #link("http://gdfe.co/srvyr/")[srvyr]. Estas librerías generalmente agregan meta-información al dataframe original que hace referencia al modo o diseño en que fue realizada la muestra. Esta información luego es utilizada para realizar estimaciones puntuales con sus respectivos errores estandard, intervalos de confianza o coeficientes de variación. La librería survey es una librería madura mantenida principalmente por #link("https://en.wikipedia.org/wiki/Thomas_Lumley_(statistician)")[Thomas Lumley] (un personaje conocido dentro de la comunidad estadística en general y en la en R en particular). La librería srvyr puede considerarse como su sucesora más moderna, aunque como lo destacan sus propios autores, se trata de una librería más amigable para el usuario en donde la mayoría del trabajo sucio lo sigue haciendo por detrás la librería survey. Algo similar resulta entre la relación entre survey y svrep ya que esta última se puede considerar una extensión de la primera para el cálculo de ponderadores replicados (#emph[replicate weights]). Algo importante a destacar es la compatibilidad entre las 3 librerías y que, a pesar de la diferencia generacional (Lumley es el mayor) existe una relación afectuosa entre los diferentes autores. En efecto, #link("https://github.com/bschneidr")[Ben Schneider], el creador de la librería svrep, es un asiduo contribuidor de los 3 paquetes antes nombrados.#footnote[Existen más librerías que pueden considerarse como extensiones de survey. #link("https://cran.r-project.org/web/packages/robsurvey/index.html")[robsurvey], para la realización de estimaciones robustas, es otro ejemplo.]

Ejemplos de librerías que sirven para el diseño de las muestras y su posterior ajuste son #link("https://cran.r-project.org/web/packages/sampling/index.html")[sampling], #link("https://envisim.se/balancedsampling")[balanced sampling] y #link("https://cran.r-project.org/web/packages/Spbsampling/index.html")[spbsampling]. Al igual que con las librerías anteriores, aquí también existe relación entre los diferentes autores. La librería sampling es una librería madura creada bajo la tutela de Yver Tillé, que es otro personaje bastante conocido tanto en el mundo de la estadística académica como dentro de los organismos oficiales de estadística de diferentes países. La librería balanced sampling hace mucho de las funciones que la librería sampling, pero es más moderna (corre en C#super[\++]) y es mantenida por #link("https://scholar.google.com/citations?user=JkMAOUEAAAAJ&hl=sv")[Anton Grafstrom] que ha escrito con Tillé. Por otro lado, la librería spbsampling se especializa en muestreos espaciales (balanced sampling también tiene funciones para eso), se ejecuta en C#super[\++] y es mantenida por #link("https://scholar.google.com/citations?user=h_Rnt4kAAAAJ&hl=it")[Roberto Benedetti]. Tanto Benedetti como Grafstrom se reconocen entre ellos y algo interesante es que si, bien ambos han trabajado con institutos oficiales de estadística, ambos se especializan en organismos de agricultura. De ahí que ambos muestren interés en la dimensión espacial de los diseños muestrales porque esta es útil a la hora de, por ejemplo, diseñar una buena muestra de la vegetación de un bosque.#footnote[Para aquel que le interesa agregar explícitamente la dimensión espacial en los diseños muestrales puede consultar la obra de Dick Brus "#link("https://dickbrus.github.io/SpatialSamplingwithR/")[Spatial sampling with R]". Brus, un geólogo ahora ya retirado, es una eminencia mundial en la temática de los muestreos de suelo (#emph[soil sampling]) y más en general, de los muestreos espaciales.]

Por último, para el cálculo de los tamaños muestrales con diferentes diseños (y otras yerbas) puede consultarse la librería #link("https://cran.r-project.org/web/packages/PracTools/index.html")[PracTools]. No se trata de una libraría muy sofisticada como algunas de las anteriores pero se trata de una librería útil y relativamente bien documentada. Un dato no menor es que uno de sus autores es #link("https://scholar.google.com/citations?user=6Q5RKeAAAAAJ&hl=en")[Richard Valliant] que, a su turno, es uno de los mayores exponentes de un enfoque importante dentro del mundo del muestreo como es el "#emph[Model Assisted Sampling]". #footnote[Otras librerías que existen dentro del ecosistema de R pero que no veremos aquí son #link("https://barcaroli.github.io/SamplingStrata/")[SamplingStrata] y #link("https://csblatvia.github.io/surveyplanning/")[surveyplanning].]

== Librerías utilizadas
<librerías-utilizadas>
Abajo hay un código para instalar y cargar las librerías que vamos a utilizar. El código se encarga de cargar las librerías y de instalar las mismas en el caso de que no se encuentren previamente instaladas. Esto es específicamente para R y la parte muestral.

La sección de las aplicaciones prácticas, principalmente por cuestiones de confidencialidad, no son reproducibles. Por otro lado, algunos #emph[chunks] incuyen código de Pyhton.

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
#box(image("muestra_2025_files/figure-typst/fig-matricula_seccion-1.svg"))
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
<muestra-2025>
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
#box(image("muestra_2025_files/figure-typst/fig-mapa_calor_poblacion_muestra-1.svg"))
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
#box(image("muestra_2025_files/figure-typst/fig-densidad_auh-1.svg"))
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
#box(image("muestra_2025_files/figure-typst/fig-poblacion_estudiantes_vs_muestra_estudiantes-1.svg"))
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
#box(image("muestra_2025_files/figure-typst/fig-sd_size_secciones_intra_establecimiento-1.svg"))
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


= Referencias Bibliográficas
<referencias-bibliográficas>
#block[
] <refs>



#set bibliography(style: "apa7.csl")

#bibliography(("references.bib"))

