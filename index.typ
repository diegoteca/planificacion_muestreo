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
  numbering: "true",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [Taller Muestreo],
  author: "Recursos Didácticos y Tecnológicos para la Enseñanza",
  date: "14 de junio de 2026",
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

Dentro del ecosistema de R, ejemplos de librerías para analizar datos producidos con diseños muestrales pueden considerarse #link("https://r-survey.r-forge.r-project.org/survey/")[survey], #link("https://bschneidr.github.io/svrep/")[svrep] y su correspondiente versión tidy #link("http://gdfe.co/srvyr/")[srvyr]. Estas librerías generalmente agregan meta-información al dataframe original que hace referencia al modo o diseño en que fue realizada la muestra. Esta información luego es utilizada para realizar estimaciones puntuales con sus respectivos errores estandard, intervalos de confianza o coeficientes de variación. La librería survey es una librería madura mantenida principalmente por #link("https://en.wikipedia.org/wiki/Thomas_Lumley_(statistician)")[Thomas Lumley] (un personaje conocido dentro de la comunidad estadística en general y en la en R en particular). La librería srvyr puede considerarse como su sucesora más moderna, aunque como lo destacan sus propios autores, se trata de una librería más amigable para el usuario en donde la mayoría del trabajo sucio lo sigue haciendo por detrás la librería survey. Algo similar resulta entre la relación entre survey y svrep ya que esta última se puede considerar una extensión de la primera para el cálculo de ponderadores replicados (#emph[replicate weights]). Algo importante a destacar es la compatibilidad entre las 3 librerías y que, a pesar de la diferencia generacional (Lumley es el mayor) existe una relación afectuosa entre los diferentes autores. En efecto, #link("https://github.com/bschneidr")[Ben Schneider], el creador de la librería svrep, es un asiduo contribuidor de los 3 paquetes antes nombrados.#footnote[Existen más librerías que pueden considerarse como extensiones de survey. #link("https://cran.r-project.org/web/packages/robsurvey/index.html")[robsurvey], para la realización de estimaciones robustas, es otro ejemplo.]

Ejemplos de librerías que sirven para el diseño de las muestras y su posterior ajuste son #link("https://cran.r-project.org/web/packages/sampling/index.html")[sampling], #link("https://envisim.se/balancedsampling")[balanced sampling] y #link("https://cran.r-project.org/web/packages/Spbsampling/index.html")[spbsampling]. Al igual que con las librerías anteriores, aquí también existe relación entre los diferentes autores. La librería sampling es una librería madura creada bajo la tutela de Yver Tillé, que es otro personaje bastante conocido tanto en el mundo de la estadística académica como dentro de los organismos oficiales de estadística de diferentes países. La librería balanced sampling hace mucho de las funciones que la librería sampling, pero es más moderna (corre en C#super[\++]) y es mantenida por #link("https://scholar.google.com/citations?user=JkMAOUEAAAAJ&hl=sv")[Anton Grafstrom] que ha escrito con Tillé. Por otro lado, la librería spbsampling se especializa en muestreos espaciales (balanced sampling también tiene funciones para eso), se ejecuta en C#super[\++] y es mantenida por #link("https://scholar.google.com/citations?user=h_Rnt4kAAAAJ&hl=it")[Roberto Benedetti]. Tanto Benedetti como Grafstrom se reconocen entre ellos y algo interesante es que si, bien ambos han trabajado con institutos oficiales de estadística, ambos se especializan en organismos de agricultura. De ahí que ambos muestren interés en la dimensión espacial de los diseños muestrales porque esta es útil a la hora de, por ejemplo, diseñar una buena muestra de la vegetación de un bosque.#footnote[Para aquel que le interesa agregar explícitamente la dimensión espacial en los diseños muestrales puede consultar la obra de Dick Brus "#link("https://dickbrus.github.io/SpatialSamplingwithR/")[Spatial sampling with R]". Brus, un geólogo ahora ya retirado, es una eminencia mundial en la temática de los muestreos de suelo (#emph[soil sampling]) y más en general, de los muestreos espaciales.]

Por último, para el cálculo de los tamaños muestrales con diferentes diseños (y otras yerbas) puede consultarse la librería #link("https://cran.r-project.org/web/packages/PracTools/index.html")[PracTools]. No se trata de una libraría muy sofisticada como algunas de las anteriores pero se trata de una librería útil y relativamente bien documentada. Un dato no menor es que uno de sus autores es #link("https://scholar.google.com/citations?user=6Q5RKeAAAAAJ&hl=en")[Richard Valliant] que, a su turno, es uno de los mayores exponentes de un enfoque importante dentro del mundo del muestreo como es el "#emph[Model Assisted Sampling]". #footnote[Otras librerías que existen dentro del ecosistema de R pero que no veremos aquí son #link("https://barcaroli.github.io/SamplingStrata/")[SamplingStrata] y #link("https://csblatvia.github.io/surveyplanning/")[surveyplanning].]

== Librerías utilizadas
<librerías-utilizadas>
Abajo hay un código para instalar y cargar las librerías que vamos a utilizar. El código se encarga de cargar las librerías y de instalar las mismas en el caso de que no se encuentren previamente instaladas. Esto es específicamente para R y la parte muestral.

La sección de las aplicaciones prácticas, principalmente por cuestiones de confidencialidad, no son reproducibles. Por otro lado, algunos #emph[chunks] incuyen código de Pyhton.

#part[Diseños muestrales]
= Cuándo y por qué hacer muestras
<cuándo-y-por-qué-hacer-muestras>
Una muestra es una parte de un todo. En los muestreos que aspiran a ser (en algún grado) representativos lo que se intenta lograr es que esa parte que se seleccione no sea muy diferente al todo o, como decían los romanos, que sea legítimo tomar una parte como el todo (#emph[pars pro toto]). En este sentido, lo que vamos a hablar aquí sobre muestreo tiene mayor pertinencia cuando en la investigación se intenta maximizar la #strong[representatividad], pero por alguna razón no es posible o conveniente la realización de un censo de todas las partes que conforman ese todo. Por otro lado, diseñar muestras también puede ser importante cuando se necesitan construir grupos de tratamiento y control en diseños experimentales, especialmente en los diseños experimentales aleatorios \(Kish, 1987). En efecto, la vinculación entre la bibliografía de los diseños muestrales y los diseños experimentales suele ser útil si se aspira a entender las razones (y no solo saber ejecutarlas en la práctica) de algunas recomendaciones metodológicas, ya que muchos de los conceptos más abstractos son compartidos por ambas \[Hedlin (2015)\]\(Fienberg & Tanur, 1988).

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

De manera derivada, lo anterior es una de las razones por lo cual el método experimental ha sido bastante exitoso en la historia de las ciencias naturales, ya que con unos pocos experimentos sus resultados se pueden inferir a su respectiva #strong[población] empírica actual. No solo eso. Muchas veces también se puede inferir a lo que a veces se denomina su #strong[universo] que estaría compuesto no solo por la población actual sino también por la clase de esas poblaciones pasadas y futuras. Este tipo de problemáticas son conocidas por diferentes disciplinas. Desde la epistemología a veces se los relaciona con el problema de los universales \(Klima, 2022) y desde la metodología se lo relaciona con el problema de la #strong[validez externa] de las investigaciones \(Campbell & Stanley, 1963). \
\
A modo de ejemplo, un físico que investiga el impacto del calor en el átomo de carbono puede tener una razonable confianza que el átomo de carbono que está hoy estudiando no solo es muy similar a los otros átomos de carbono actuales en la Tierra (población) sino que también es similar a los pasados y los futuros átomos de carbono (universo). También puede tener confianza que los átomos de carbono encontrados en la Tierra son similares a los existentes en el resto del universo. En el otro extremo, este tipo de suposiciones en general son difíciles de mantener en el nivel social.

Estas diferencias en cuanto a la validez externa no son tan marcadas cuanto se analiza la dimensión de la #strong[validez interna] de las investigaciones. En la jerga de la bibliografía de los diseños de investigación se suele afirmar que en todas las investigaciones que se quiera realizar inferencias causales, independientemente si se trata de investigaciones físicas o sociales, el investigador se debe asegurar, en la fase de diseño de la investigación, de controlar o aleatorizar el conjunto de factores extraños que le sugiera/n la o las teorías utilizadas. Esto es lo que precisamente le asegurará que aquellos factores extraños no sigan existiendo como factores perturbadores que puedan invalidar las inferencias internas o locales en el momento de las conclusiones \(Kish, 1987). En el último tiempo la visión anterior se ha expandido aún más permitiendo mayor seguridad en diseños observacionales en situaciones en donde no es posible un diseño experimental aleatorio lo que es sumamente importante en el dominio de las ciencias sociales \(Morgan & Winship, 2015; Pearl, 2018).

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
a) La clase de referencia de los conceptos utilizados que nos dirá el/los tipo/s de referente/s a investigar (individuos, organizaciones, etc.). Esto a veces se suele denominar #strong[universo] o dominio de la teoría \(Bunge, 1974).

b) Los objetivos de la investigación que nos indicaran, entre otras cuestiones, el alcance (usualmente especificando tiempo y espacio) de los referentes anteriores junto con otras características pertinentes de cada unidad de observación/experimentación. Usualmente los objetivos remiten a una población empírica que podrá grande o pequeña, homogénea o heterogénea, dispersa o aglomerada, etc.~ \
\
Dentro del muestreo al conjunto formado por todos los objetos reales que cumplan las condiciones de los puntos "a" y "b" se lo denomina #strong[población]#footnote[Expresado en términos de propiedades generales y específicas podría afirmarse que las~#strong[propiedades generales], como su nombre lo indica, sirven para construir #strong[géneros] y todos los objetos reales que pertenecen a ese género tienen el mismo valor en todas sus propiedades generales. Ejemplo: Todo objeto real que se clasifique como "persona" deberá cumplir una serie de propiedades generales que hacen a la esencia de "persona" y se incluyen en su definición. Ser estudiante o residir en la provincia de Buenos Aires no pertenece a un valor de una propiedad general de las personas. En cambio, mamífero descendiente del mono, sí. Las propiedades generales son necesarias para identificar la clase de referencia, pero no suficientes para construir la población sobre la cual se realizará la muestra.~

Las~#strong[propiedades específicas,] también como su nombre lo sugiere#strong[,]~sirven para construir #strong[especies de los géneros] en función de los diferentes valores en las propiedades específicas. Tiempo y espacio son típicas propiedades específicas que ayudan recortar al universo anterior delimitando una población empírica. Luego pueden existir otras propiedades específicas (como las anteriores de ser estudiante o vivir en Buenos Aires) que sirven para seguir delimitando aún más nuestra población.].~En nuestra vida cotidiana, aunque sea solo por vivir en un tiempo y espacio determinado (y aun si somos investigadores de profesión) usualmente solo tenemos posibilidad de acceso empírico a un subconjunto de aquella población. Para empeorar las cosas, en las ciencias sociales muchas poblaciones son muy numerosas, heterogéneas y/u otras se encuentran muy separadas espacialmente lo que dificulta y hace costoso llegar a cada una de las partes de aquellas. En el extremo, a veces el investigador tiene el problema adicional de trabajar con poblaciones "invisibles" de las que se sabe o se presupone que existen, pero no se tienen datos agregados de ella y/o es sumamente difícil identificar/contactar a miembros de ella.~Ante esta situación el investigador tiene 2 grandes opciones:

a) Se ajustan los objetivos de la investigación, especialmente en lo tocante al grado de alcance o generalidad de la investigación, hasta un punto que efectivamente la definición de la unidad de análisis construya una población en la que se pueda abordable empíricamente a cada una de las unidades que la componen y/o

b) Se realiza una~#strong[muestra]~de aquella población.

En este sentido, en este taller se le prestará atención a las estrategias tipo ‘b' como un modo de conocer el todo a través de solo una parte de aquel. Más adelante también veremos que hay estrategias más eficientes que otras para con ‘poco' inferir ‘bastante', aun cuando, en muchos casos, no se sepa a ciencia cierta si ese ‘bastante' es ‘suficiente'. En otras palabras, se verán las distintas características de diferentes diseños muestrales que aspiran a algún grado de representatividad con el objetivo de comprender cuál de ellos puede ser más idóneo en función de los objetivos, el presupuesto y los datos disponibles en cada caso.~ \
\
Existen varios criterios para clasificar a las muestras. Siguiendo una clasificación clásica \(Neyman, 1934), todos los que se basan en algún modo en la aleatoriedad (#emph[random]), ponen el acento en el #strong[proceso] de la muestra y se las puede clasificar como #strong[muestras probabilísticas]. Otros, como todos los que se basan en cuotas ponen más acento en las acciones y chequeos basados en las intenciones (#emph[purposive]) del~#strong[resultado o producto final.] Aquí, más que usar el término de muestras intencionales de Neyman vamos a preferir el más amplio de muestras no probabilísticas, ya que también engloba a otros diseños que tienen la similitud, al menos a primera vista, de no ser probabilísticos \(Baker et~al., 2013). Ejemplos pueden considerarse las muestras basadas en el criterio de saturación y la heterogeneidad observada, los muestreos por conveniencia, los muestreos por matcheo (en donde las cuotas de Neyman serían un ejemplo), los muestreos basados en redes, usuales para el estudio de poblaciones invisibles (en donde el bola de nieve o snowball sería un ejemplo).

Finalmente en el último tiempo, y en parte por el avance de una mayor disponibilidad de información secundaria, cada vez existen más métodos que permiten incorporar esa mayor información secundaria como información auxiliar (#emph[auxiliary information]) tanto en el diseño de la muestra como en el posterior ajuste de los estimadores de la misma. Este último proceso en particular se suele denominar calibración. Ambos usos de la información secundaria (tanto si se usan para el diseño #emph[ex-ante] o para el ajuste de los estimadores #emph[ex-post]) son ejemplos de diseños muestrales asistidos por modelos que derivan de información secundaria (#emph[model assisted]).

En el útimo párrafo, casi al pasar, se ha comentado que "en el último tiempo" ha habido cambios en el mundo del muestreo. Más allá que se pueda afirmar que en algunos momentos haya habido más cambios que otros, la historia de la incorporación de las diferentes teorías de muestreo en la estadística como disciplina (antes dominada por aplicaciones sobre poblaciones enteras o censos) o en el diseño de investigaciones (antes dominada por diseños experimentales) es sumamente interesante y recomendable \(Gigerenzer et~al., 1997; Hacking, 1990/2004, 2006).

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
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
La estratificación es un método que permite el uso de información auxiliar en el diseño muetral \(Tillé, 2020, pág. 65). Esta definición tipo paraguas va de la mano de que la información auxiliar del marco muestral es necesaria para la construcción de estratos que, en principio, cumplen el criterio de que sean similares en su interior y diferentes entre ellos. Otra característica distintiva de los estratos es que estos son discretos, esto es, pueden tener, a lo sumo, un orden entre ellos, pero los límites entre ellos son puntuales más que continuos.#footnote[Más adelante veremos que existe un método denominado "estratificación implícita" que, si bien se considera una opción de muestreo sistemático, en la práctica se trata de un modo de agregar una varaible cuantitativa a la estratificación \(Cochran, 1977, pág. 205).] Como regla general, si existe información auxiliar dsponible, (casi) siempre es una buena idea estratifcar (\(Tillé, 2020, pág. 65)

Si se recuerda los comentarios realizados en la introducción, cuanto menos heterogeneidad exista entre las unidades a seleccionar menor es el problema de la representatividad. Esto es precisamente una idea que inetentan lo que intentan aprovechar la mayoría de los diseños estratificados. En el extremo, si todos los miembros de cada estrato son iguales entre sí y los tamaños o cantidad de casos de cada estrato también son iguales entre sí, solo habría que seleccionar a un caso por estrato como razón suficiente para obtener una muestra representativa de la población. Si los tamaños de los estratos fueran diferentes también se podría seleccionar un caso por estrato, pero la condición para que esta muestra sea representativa es que luego se incluyan ponderadores diferentes para cada estrato de la muestra en función de la inversa de la probabilidad de entrar en la muestra. Esta diferencia, es la diferencia central entre el muestreo estratificado proporcional y el no proporcional con asignación óptima que veremos más adelante.

Para que el muestreo estratificado produzca ventajas en términos de precisión (en comparación con el azar simple) los estratos deben tener una heterogeneidad interna menor a la heterogeneidad del conjunto de la población aunque aquella se encuentre lejos del ejemplo extremo del párrafo anterior. Los estratos conforman subpoblaciones mutuamente excluyentes y exhaustivas de toda población aunque se pueden construir los mismos en función de datos categóricos, agregaciones de datos continuos (p.e. agrupaciones de años de antigüedad) o espaciales (p.e. Regiones). En una base de datos educativa puede haber muchas variables que pueden ser considerados candidatos para la formación de estratos. En este caso, a modo de ejemplo, nos quedaremos con "Ámbito" que posee 3 categorías que asumimos, como diría Platón en el Fedro, que cortan la realidad por sus articulaciones naturales \(Platón, 2002 \[370AVC\], pág. 55). Por otro lado, utilizar "Ámbito" como estrato tiene otra virtud pedagógica que deviene de la diferente distribución porcentual de cada categoría. Esto lo hace un buen candidato para mostrar algunas características del muestreo estratificado en su versión proporcional y no proporcional, ya que la categoría "Rural Agrupado" posee un menor porcentaje de casos y, a igualdad de otras condiciones, veremos como eso dificulta su posterior análisis si se mantienen en la muestra las proporciones originales de la población. Veremos también que para decidir entre estos tipos de diseño también será útil indagar en el significado de un término clásico del muestreo como es el "dominio" de estimación.

A veces los estratos se construyen con base en antecedentes teóricos, pero nada impide que estos sean constructos estadísticos con un significado no muy claro como los que se pueden producir luego de un análisis de clústers \(Everitt et~al., 2011). Tampoco la técnica tiene una limitación en cuanto a la cantidad de categorías. Cabe aclarar que cualquier estrato debe ser capaz de construirse tanto a nivel poblacional como posible de identificarse/seleccionarse a nivel muestral. En este sentido, más allá si tiene un origen más teórico o estadístico, es claro que, como la muestra la definición de Tillé de más arriba, esta técnica exige tener acceso empírico a una mayor cantidad de variables en comparación con, por ejemplo, el azar simple.

=== Estratos con asignación proporcional
<sec-estrato_proporcional>
En este subtipo de muestreo estratificado utilizaremos la variable "Ámbito" como estrato y respetaremos, aproximadamente, la distribución que ese estrato posee en la población. Decimos "aproximadamente" porque aquí siempre existe un factor de redondeo que deviene de la necesidad de realizar la muestra sobre una cantidad de casos discretos. Esta última necesidad hace que, al igual que cuando se intenta respetar las proporciones de los votos de una elección para la renovación de bancas de la Cámara de Diputados, casi siempre existan pequeñas diferencias entre las proporciones poblacionales y las muestrales.

Seleccionada la muestra ahora le especifico los detalles del diseño mediante la librería survey o srvyr.

Y luego realizo la #ref(<tbl-estratificado_teo_prop>, supplement: [Tabla]) con la información de algunas variables y esa misma tabla lo comparo con los valores de la #ref(<tbl-azar_simple>, supplement: [Tabla]) que refería al diseño con azar simple.

#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
En el tipo de diseño anterior hubo una variable (Ámbito) que se usó para estratificar la muestra. En ese caso, salvo variaciones menores debido a los factores de redondeo antes comentados, las proporciones de la muestra respetan las proporciones poblacionales. Eso es lo que precisamente se intenta modificar con el muestreo con una asignación no proporcional. Usualmente, la idea que está detrás de esta estrategia es poder reducir el desvío estándar de aquellos estratos que más suman al desvío estándar de toda la muestra. El desvío estándar de cada estrato es una función entre la heterogeneidad propia de cada estrato (p.e. que tán iguales son entre sí los establecimientos "Rural Agrupado") con la cantidad de casos de ese estrato (a mayor cantidad de casos menor desviación estándar). Si en la muestra se respeta la proporción original de la población (aun en el caso de que los establecimientos de ámbitos urbanos tengan una misma heterogeneidad que el resto) es claro que los estratos rurales poseen una distribución muy baja y, por lo tanto, nos vamos a quedar con pocos casos en la muestra y, de manera derivada, con un alto error estándar en esos análisis. La propuesta original de Neyman \(Neyman, 1934) justamente trata de como asignar de manera eficiente (desde el punto de vista estadístico) la cantidad de casos a cada estrato, haciendo que, para nuestro ejemplo, los estratos rurales se encuentren sobrerrepresentados y los urbanos subrepresentados. Esta estrategia permite que, para una igual cantidad de casos que un muestreo estratificado proporcional, se puedan hacer inferencias (bastante) más confiables para dominios de estimación más pequeños a cambio de perder (un poco) de confiabilidad en los dominios de estimación más grandes#footnote[Un dominio o subclase de estimación es una partición de la población o de la muestra sobre la cual se espera realizar inferencias. A veces se usa la denominación que los dominios denotan subpoblaciones (de la población) y las subclases reflejan esas divisiones en la muestra \(Kish, 1980, p. 209). En cualquier caso es conveniente introducir estos dominios en el diseño de la muestra para poder controlar su tamaño poblacional \(Brus, 2022, Capítulo 14). En el ejemplo del cuerpo del texto se asume que esos dominios de estimación coinciden con los estratos aunque esto no tiene nada de necesario.].

La contraparte de esta ventaja es que ahora es necesario construir expansores diferentes para cada estrato para que se le devuelva la probabilidad que se encontraba en la población. En este sentido, el factor de expansión del estrato urbano será mayor al de los estratos rurales.

Aquí, para extremar esta lógica, vamos a realizar una muestra como si la distribución de la variable Ámbito fuera igual para sus 3 categorías.

#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
Muchas veces, especialmente en diseños polietápicos, se desea que en la primera etapa las unidades de selección (llamadas justamente unidades de selección primarias) sean escogidas en función de alguna variable que sirva como indicador de su tamaño. Esta técnica se suele denominar muestreo proporcional al tamaño (PPS)#footnote[La sigla PPS viene de la expresión "#strong[P]robability #strong[P]roportional to #strong[S]ize" que es como se lo conoce en la bibliografía de muestreo.] y puede considerarse como un caso especial del muestreo por clústers \(Lumley, 2010, pág. 46). En el caso de unidades geográficas esa variable podrá ser el tamaño espacial o área (p.e. km#super[2]) y en variables no espaciales podrá ser la cantidad de personas (p.e. votantes en distritos). En el caso de una muestra de colegios, variables como el tamaño de la matrícula pueden ser buenas candidatas a utilizar en este tipo de muestras.

Un PPS, por diseño, va a otorgar una mayor probabilidad de salir en la muestra a los colegios con mayor matrícula y estos pueden poseer características particulares como, por ejemplo, encontrarse abrumadoramente en ámbitos urbanos. De este modo, ya podemos intuir que, con respecto a la población de establecimientos, una muestra PPS (sin ponderar) obtendrá como resultado (quizá no buscado) una sobrerrepresentación de los #strong[establecimientos] de ámbito urbano al tiempo que también habrá una sobrerrepresentación (esta vez buscada) de aquellos establecimientos con mayor matrícula. Aunque parezca algo paradójico, esto es justamente para darles a todos los #strong[estudiantes] (y no solo los del ámbito urbano) una misma chance de salir en la muestra. Esto último depende, especialmente en un diseño polietápico, que se haga efectivamente después de haber realizado la selección primaria, esto es, que se haga después de la primera etapa.

A pesar de cierta idea intuitiva acerca del objetivo del muestreo PPS, su efectiva aplicación (especialmente en muestreos sin reemplazo) tiene sus complejidades a nivel de los algoritmos a utilizar. Esto en parte es algo compartido por todos los muestreos sin reemplazo (versus los con reemplazos), pero aquí está presente la dificultad adicional de que las probabilidades de inclusión son diferentes. En efecto, el muestreo PPS puede ser considerado como un tipo de muestreo con probabilidades de inclusión diferentes (#emph[unequal probabilities]), pero con la particularidad específica que esas probabilidades diferentes se calculan en función del tamaño de las unidades a seleccionar en primera instancia. A continuación vamos a utilizar un algoritmo que tiene que ver con la idea de "#emph[local pivotal]" que vamos a ver con mayor profundidad cuando veamos las muestras bien dispersas (#ref(<sec-bien_distribuido>, supplement: [Sec.]))#footnote[Existen otros algoritmos para realizar un muestreo PPS. Muchos de ellos son algoritmos especializados en probabilidades desiguales (en donde la desigualdad por tamaño sería un caso especial) por lo que muchos de sus nombres suelen empezar con UP (#emph[unequal probabilities]). Algunos son los siguientes: UPtille, UPpivotal, UPpoisson \(Tillé & Matei, 2023).].

Para visualizar esto vamos primero vamos a construir a realizar 2 ejemplos. Uno en donde se realiza un PPS en donde luego solo se expande por un ponderador que simula que todos los establecimientos tenían las mismas chances de haber entrado (o, expresado de otro modo, que expande pero no pondera) y otro en donde, a esa misma muestra, se la pondera por la probabilidad inversa de haber ingresado en la muestra, esto es, un ponderador que haga pesar menos a aquellos establecimientos con mayor tamaño. Siguiendo con el ejemplo de los colegios, si el proceso es seleccionar los colegios por tamaño y luego realizar un censo (esto es, ninguna muestra) de estudiantes dentro de cada uno de los colegios seleccionados, tanto los colegios como los estudiantes de ámbito urbano se encontrarán sobrerrepresentados por lo que un ponderador que tenga en cuenta las probabilidades inversas en función del tamaño puede ser útil.

#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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


En efecto, en la #ref(<tbl-pps_ponderadores>, supplement: [Tabla]) puede observarse que si trabajamos en una muestra PPS solo expandiendo, pero sin ponderar (primera tabla desde la izquierda) vemos como el valor promedio de la matrícula es alto (529) y que la abrumadora mayoría de los establecimientos seleccionados son del ámbito urbano (95%). Si luego analizamos la muestra ponderada por la probabilidad inversa en función del tamaño vemos como la mayoría de los valores se acercan a los valores conocidos de la población, especialmente aquellos que refieren a propiedades intrínsecas de los establecimientos como la región y el ámbito. Sin embargo, esta operación tiene sus riesgos porque hace depender mucho al ponderador de la matrícula y esta puede ser sumamente heterogénea. Por poner un ejemplo, en el muestreo PPS fueron seleccionados 5 establecimientos de la región 25 que es una región que se caracteriza por tener un porcentaje de establecimientos rurales mayor a la media (alrededor del 40% son urbanos). Pero dado que en el PPS los establecimientos más grandes tienen más chances de entrar en la muestra se seleccionaron 4 establecimientos urbanos (con matrícula típica de ámbitos urbanos) y solo 1 de ámbito rural. En este contexto el ponderador luego hace que esos 4 pesen menos y que ese único establecimiento rural (que tiene una matrícula de 7 estudiantes) pese mucho más que lo que descuentan los 4 urbanos. El resultado es que la región 25, cuando se trabaja con el ponderador, salta desde un 1,7% sin ponderar hasta un 14% ponderado. Algo similar sucede con la región 18. Por esta razón, es interesante también observar que en muchos casos el intervalo de confianza con la muestra ponderada se expande (p.e. región 18 y 25). Esto se debe a que el ponderador ahora hace pesar más en la estimación a situaciones en donde se encuentran pocos casos y, por lo tanto, al estar basadas en menos casos esas estimaciones poseen un margen de error mayor.

Si en cambio, luego en una segunda etapa, se realiza un muestro de una cantidad fija (p.e. 10 estudiantes por colegio seleccionado) la muestra de colegios sin ponderar seguirá sobrerrepresentando a los #strong[establecimientos] del ámbito urbano pero tiene muchas chances de representar aceptablemente a la población de #strong[estudiantes]. Esto último justamente una de las características más aprecidas del PPS en diseños polietápicos. En efecto, aplicado al mundo educativo, puede ser algo buscado explícitamente si se utiliza la selección de los colegios como unidades de selección primarias y luego a los estudiantes como unidades de selección secundaria o final. En otras palabras, se trata de un efecto buscado por diseño, justamente porque ahora el objetivo está puesto en lograr una muestra representativa de la población de estudiantes a través de una población de establecimientos que contiene variables agregadas de los estudiantes.

Para fijar las ideas, en el ejemplo anterior se seleccionarían en primera instancia unos 300 establecimientos, luego se obtendría una muestra final de 3000 estudiantes porque en la segunda instancia se seleccionaron 10 estudiantes por establecimiento. Una virtud práctica de este último ejemplo es que, aparte de reducir costos de logística en comparación a un muestreo por azar simple de un solo paso (porque se van a menos unidades de selección primarias), es que otorga un mismo ponderador a cada caso seleccionado (se dice que la muestra es autoponderada) lo que facilita muchos análisis posteriores. Esto es un típico ejemplo de muestra compleja en donde la muestra se realiza en más de una etapa y en cada una de ellas se utilizan técnicas diferentes.

En relación con lo anterior y de manera aparentemente paradójica, la muestra PPS sin ponderar estima mejor las variables agregadas como el valor del primer y segundo sondeo que un análisis censal de toda la población de colegios (como se hizo en #ref(<tbl-parametros_base>, supplement: [Tabla])). Lo paradógico de esto es que una muestra, esto es, una parte de un todo, logre un mejor acercamiento a un respectivo parámetro poblacional que un censo, esto es, un registro de cada una de las partes del todo. La solución a esta paradoja es entender que la #ref(<tbl-parametros_base>, supplement: [Tabla]) hace referencia a la población de colegios y, en ese sentido, sus valores son correctos. Ahora bien, si con esos datos (censales, pero de la población de establecimientos) se quiere hacer afirmaciones sobre la población de estudiantes la información de la #ref(<tbl-parametros_base>, supplement: [Tabla]) no es la más idónea o, al menos, hay que tratarla de manera diferente. En las variables que se pueden considerar como variables agregadas de estudiantes (p.e. sondeo\_primero, sondeo\_segundo) más que calcular la media habría que haber calculado la media ponderada por matrícula y ese cálculo sería un mejor estimador de la media de las notas de la población de estudiantes En ese caso, el resultado de ese cálculo sí se podría considerar como un parámetro de la población de estudiantes y contra esos valores se debería comparar las estimaciones del diseño PPS sin ponderar. Esto precisamente se puede observar en la #ref(<tbl-media_ponderada_notas_estudiantes>, supplement: [Tabla]).

#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
Las muestras balanceadas son un método particular dentro del espectro de las técnicas disponibles en la que felizmente se juntan las potencialidades del enfoque del "#emph[Design Based]" y del "#emph[Model Assisted]". En este contexto, Tillé afirma que:

#quote(block: true)[
"En un diseño muestral balanceado, las probabilidades de inclusión son decididas antes de la muestra. Un muestreo balanceado puede ser visto como un tipo de calibración que es directamente integrada dentro del diseño de la muestra" \(Tillé, 2011, pág. 216).
]

Este tipo de técnica permite diseñar muestras balanceadas en el sentido que las medias muestrales de las covariables sean (aproximadamente) iguales a las medias poblacionales de esas covariables. Esto, como mínimo, es una estrategia efectiva para evitar caer en el pequeño subconjunto de muestras aleatorias que son muy sesgadas \(Tillé, 2011, pág. 221). En este sentido, se recuerda que cuando realizamos diseños por azar tenemos chances (si bien bajas) de obtener muestras muy sesgadas. El muestreo balanceado evita esta situación y, la mayoría de las veces (siempre que las covariables disponibles estén empíricamente relacionadas con las variables de estudio) suele ofrecer muestras con las que luego es posible realizar una estimación con una mayor precisión que las realizadas con el azar simple. Si se agregan más covariables al diseño y, nuevamente, estas se encuentran linealmente relacionadas con las variables de estudio, el estimador de la media poblacional también mejorará aún más su precisión.#footnote[Más adelante veremos que indagar sobre la precisión de la estimación es posible pero difícil en las muestras realizadas con el método del cubo. Por esta razón, si bien es posible comparar la precisión de estas muestras contra, por ejemplo, el muestreo por azar simple, acá esto se tomará como un supuesto y se remite al lector a fuentes en donde se prueba lo anterior \[Brus (2022), cap. 9\]\(Schneider, 2024). El principal problema es que, por ahora, las librerías de análisis de datos de encuestas (p.e. #emph[survey]) todavía no tienen el instrumental adecuado para especificar este tipo de diseños y, por lo tanto, para calcular la precisión de sus estimaciones.]

Lo anterior puede considerarse un viejo #emph[desideratum] de los diseños muestrales aunque antes no había disponible algún algoritmo de cálculo aplicable de una manera generalizable y precisa que pudiera ser ejecutado o calculado de manera viable \(Deville & Tillé, 2004). Eso es lo que precisamente logra el método del cubo. De manera alternativa, las muestras balanceadas pueden ser vistas como un tipo de calibración (#ref(<sec-calibracion>, supplement: [Cap.])) que se encuentra integrada en el diseño de la muestra, y por lo tanto se trata de un proceso #emph[ex-ante] la ejecución de la misma, más que algo #emph[ex-post] a la misma como la estimación de los estimadores \(Tillé, 2011, pág. 216).

Por lo tanto, el contexto actual de:

#block[
#set enum(numbering: "a)", start: 1)
+ un mayor acceso a fuentes secundarias de datos y
+ una mayor capacidad computacional,
]

parece ser un contexto particularmente propicio para la aplicación y difusión de este tipo de diseños porque, justamente, se trata de un diseño demandante en cuanto a datos secundarios (en forma de información auxiliar o covariables) y demandante con respecto a recursos computacionales (para ejecutar el algoritmo del método del cubo).

Antes de pasar a la aplicación de este diseño con la base de establecimientos de nivel primario vamos a considerar un ejemplo trivial con variables espaciales en donde se puede simular fácilmente la linealidad de la variable de estudio con respecto a otras covariables. Esto también servirá como un anticipo para cuando intentaremos incorporar explícitamente variables espaciales (a través de coordenadas) en la muestra (#ref(<sec-bien_distribuido>, supplement: [Sec.])).#footnote[El ejemplo y el respectivo código fue adaptado del libro "Spatial sampling with R" \(Brus, 2022).]

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
Ahora pasaremos a aplicar este diseño a la base de escuelas que venimos trabajando. Esta vez vamos a incorporar una mayor cantidad de información secundaria que se encuentra disponible en la base de establecimientos. Como en muchas otras técnicas, la introducción de más variables no es garantía de un mejor resultado, ya que en este caso la agregación de más variables, especialmente si no están linealmente relacionadas con las variables de estudio, puede ser contraproducente \(Tillé, 2011, pág. 222). Ese es precisamente una de las utilidades del ejemplo anterior de la #ref(<fig-muestreo_cube_ejemplo>, supplement: [Figura]), ya que en él era fácil construir y visualizar la linealidad de la relación entre las covariables y la variable de estudio. Por esta razón, en este proceso de selección es clave tener claras las variables de estudio, para luego determinar qué covariables de la información secundaria disponible es conveniente incluir.

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
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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

En cierto sentido, la inclusión de las variables "Ámbito" y "Región" en el diseño balanceado (#ref(<sec-cubo_colegios>, supplement: [Sec.])) ya mejoraban la distribución geográfica o espacial de la muestra (con respecto a una muestra de azar simple) pero lo hacían focalizándose en sus valores de tendencia central. Los valores de las coordenadas permiten una información de un grano más fino sobre la distribución espacial de la muestra lo que no es un dato menor. Si se asume que el espacio es una especie de meta-variable en las ciencias sociales \(Small & Adler, 2019), controlar la muestra por el espacio ayuda a controlar una serie de otras características que poseen eficacia causal, pero que usualmente son inobservables o de difícil registro. Expresado en la jerga del diseño estadístico de las investigaciones, este tipo de mejoras ayudan a que dentro del conjunto de variables extrañas al comienzo de la investigación, gracias al diseño de la misma, pasen ser variables controladas en vez de pasar a ser variables perturbadoras \(Kish, 1987). De todos modos, cabe destacar que las coordenadas son de los establecimientos y no de los estudiantes o, más en general, de las personas. El supuesto implícito es que la ubicación de los establecimientos guarda una relación estrecha con la ubicación de los estudiantes.

Desde un costado más operativo el algoritmo que se utiliza es el algoritmo del "#emph[local cube]" \(Tillé & Grafström, 2013) que ya había sido utilizado en el muestro PPS. Este algoritmo penaliza si se seleccionan 2 casos "localmente" cercanos entre sí y luego de haber seleccionado un caso hay pocas chances que se seleccione otro caso muy cercano. La idea de distancia entre los casos es abstracta aunque en nuestro ejemplo se puede interpretar como distancia espacial.

#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
La estrategia de la calibración está compuesta por un conjunto de prácticas que aspiran a lograr objetivos similares al proceso del balanceo del cubo pero con métodos cualitativamente diferentes. La principal diferencia radica en que la calibración se realiza #emph[ex-post] la ejecución de la muestra (o sea, en el momento de la estimación) y no #emph[ex-ante] (o sea, en el momento del diseño) \(Deville & Tillé, 2004, pág. 907). Esto es una diferencia fundamental que emparenta a la calibración con el enfoque del "#emph[Model Assisted]" y la aleja del "#emph[Design Based]"#footnote[En cambio el balanceo, si bien en su origen tiene una fuerte vinculación con el enfoque del "Model Assisted", no se encuentra tan alejado del "design based" dado que el algoritmo del cubo selecciona muestras balanceadas dentro del conjunto de muestras aleatorias \(Tillé, 2010, pág. 39).]. En efecto, tanto el balanceo como la calibración pueden considerarse prácticas relativamente generales que, en su interior, incluyen otras prácticas más específicas. Esto es lo que habilita a afirmar que, por ejemplo, la estratificación es un caso particular del balanceo así como la post-estratificación es un caso particular de la calibración \(Tillé, 2011, pág. 223).

Otra diferencia entre el balanceo y la calibración es que para realizar la calibración en algunas situaciones (esto depende de la técnica específica seleccionada) solo es necesario los totales de la población y no, como en el balanceo, los valores de cada unidad que compone esa población.

Las características anteriores hacen que el proceso de calibración sea muy útil en momentos en donde existe conocimientos sobre algunos totales de la población y no se haya podido controlar mucho el proceso de diseño de la muestra (p.e. diseños no probabilistas) o diseños probabilistas pero con una alta tasa de no respuesta. Estas características hacen al proceso de calibración algo muy deseado para muchas investigaciones contemporáneas en donde pueda admitirse que se conocen algunos parámetros poblacionales y, por ejemplo, se ha realizado una muestra que se difundió de manera virtual a través de un link que circuló por diferentes redes sociales. Esto deja en pie la discusión sobre que "tan buenos" podrán ser los resultados de esa investigación, pero no parece haber muchas dudas que la investigación del ejemplo anterior será mejor si se le realiza un proceso de calibración mientras que será peor si no se realiza ese proceso.#footnote[Este tipo de discusiones ha enfrentado (y por ahora continúa enfrentando) a los representantes de los enfoques de la "#emph[design based sample]" y del "#emph[model assisted]". Los primeros suelen dudar de los beneficios de aplicar la calibración sobre diseños no probabilísticos aunque no suelen tener objeciones cuando la calibración se realiza sobre diseños probabilísticos \(Elliott & Valliant, 2017). En el fondo lo que está en juego son los grados de garantía que ofrece cada técnica acerca de la representatividad y esto no solo incluya la discusión sobre las heterogeneidades observables (algo mantenido por ambos enfoques) sino también sobre las heterogeneidades no observables (algo históricamente mantenido por el enfoque de la "#emph[design]").]

En cuanto a su pertinencia, siempre que haya disponibilidad de tiempo (y el saber necesario para realizarlo) es aconsejable realizar una calibración. Esto es cierto al menos porque el balanceo tiene el problema del redondeo (las muestras son muestras de números enteros) y la calibración no, ya que puede construirse calibradores con números racionales. Por esta misma razón, aun cuando se haya realizado una muestra con un diseño por balanceo, es recomendable calibrar con los totales de las variables que se usaron en el proceso de balanceo.

Detalladas algunas diferencias entre la calibración y el balanceo ahora se pasa a diferenciar la calibración (de una muestra) de la imputación (de variables específicas).

- En cuanto a su producto, la calibración produce como resultado un calibrador (o un nuevo ponderador en la situación que el diseño de la muestra ya cuente con un ponderador) que es único para cada caso seleccionado en la muestra. En cambio la imputación, al menos como acá se la está entendiendo, es un proceso que tiene como objetivo estimar el valor faltante de una variable de los casos que respondieron de forma incompleta la muestra. En este sentido, un caso efectivamente seleccionado en la muestra puede tener más un valor imputado (p.e. para la variable ingresos y para la variable autopercepción de género) y, en cambio, otro caso puede que no tenga ninguno (p.e. si ese caso tuvo respuestas en todas las variables). En otros contextos se suele diferenciar a ambos procesos afirmando que la calibración ayuda a mitigar el problema del #emph[unit-not-response] y la imputación ayuda a mitigar el problema del #emph[ítem-not-response] \[Lumley (2010), pág. 136\]\(Lundström & Särndal, 2009, pág. 9).

- En cuanto a los insumos, la calibración necesita los totales poblacionales y, en cambio, la imputación necesita los valores de las otras variables que el caso a imputar ha respondido así como los valores de las covariables y la variable a imputar de los otros casos.

- En cuanto al momento de la investigación, siempre que se usen ambos procesos, usualmente primero se imputa los casos particulares de las variables que se considera pertinente y luego se calibra la muestra incluyendo los valores de los casos imputados. Este orden es particularmente importante si se confía en el proceso de la imputación y la/s variable/s imputadas son parte del proceso de calibración como covariables.

Por último, a veces se suele asimilar como sinónimos en término calibración con el término post-estratificación. Más arriba ya se había comentado que el segundo puede considerarse como un caso particular (aunque quizás el más difundido) del primero en donde solo se utilizan variables categóricas (estratos) para el proceso de la calibración. Lo mismo puede afirmarse del método menos difundido del "raking" que permite la calibración de múltiples variables categóricas sin la necesidad de realizar cruces entre ellas con el riesgo de no tener casos en la muestra de algunas de las celdas de los múltiples cruces \(Lumley, 2010, pág. 139). Por esta razón, aquí usaremos directamente el método de la calibración por ser el más general, ya que permite la inclusión tanto de variables categóricas como continuas y no presenta los riesgos de la post-calibración en cuanto a la posible ausencia de casos frutos de los cruces de las variables categóricas.

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
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
Las pruebas PEB (Pruebas Escolares Bonaerenses) son un programa orientado a mejorar la enseñanza y el aprendizaje de Matemática y Prácticas del Lenguaje en el nivel Primario, tanto en el sector estatal como en el privado, que se puso en marcha en 2022 en la Provincia de Buenos Aires \(Subsecretaría, 2025, pág. 5).

Desde el punto de vista metodológico que tiene que ver con cuestiones muestrales es pertinente destacar que estas pruebas aspiran a ser realizadas al total de los estudiantes aunque luego se registran sus resultados a través de dos componentes diferentes. Un primer componente censal aunque con datos agregados y un segundo componente muestral con datos nominales. Lo que se detalla a continuación es el proceso de selección muestral de este segundo componente nominal. Primero lo haremos haciendo referencia a la muestra diseñada en 2023 y luego para la de 2025.

== Muestra 2023
<muestra-2023>
Para tener como referencia vamos a intentar representar el método de selección de la muestra que se utiliza desde 2023. Primero la vamos a intentar describir y luego clasificar.

=== Descripción
<descripción>
Un resumen descriptivo de la misma es la siguiente afirmación:

"En paralelo, se relevaron resultados por estudiante en una muestra probabilística de 680 escuelas. Para cada institución, se solicitó información sobre las respuestas a las actividades de 5 estudiantes seleccionados al azar por las y los docentes de cada sección" \(Subsecretaría, 2024, pág. 18).

Más en detalle también se afirma "La construcción de la muestra siguió un diseño probabilístico, con selección sistemática de las unidades de muestreo. Previo a la selección, en el marco muestral (nómina de establecimientos de nivel primario) se agruparon los establecimientos en estratos constituidos por el cruce de las variables “dependencia de los establecimientos educativos” (provincial y resto-incluyendo en este último grupo a los establecimientos privados, municipales y nacionales), “porcentaje de estudiantes con AUH”, “presencia o no de jornada completa” y “ámbito”. Luego, se ordenaron los establecimientos por estrato, y se realizó una selección sistemática siguiendo la fracción de muestreo correspondiente" \(Subsecretaría, 2024, pág. 18).

La descripción anterior alcanzaría para una descricpión de la selección de establecimientos. Pero todavía falta el paso que describe la selección de los estudiantes:

"Para cada sección de los años de estudio evaluados, se solicitó la selección de las/los primeros o últimos estudiantes de la lista (por orden alfabético) que hayan realizado la prueba. En secciones pequeñas (de hasta 10 estudiantes), se requirió la carga de información de todas y todos los estudiantes" \(Subsecretaría, 2024, pág. 18).

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
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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

Cuando los estratos con los cuales se diseñan las muestras tienen una cantidad de casos similares la distinción con los dominios se vuelve algo ociosa. En cambio, cuando los estratos tienen diferentes números de casos (p.e. Urbano vs.~Rural Agrupado) y luego se desea realizar estimaciones para todos los estratos, es importante la utilidad de la distinción. La razón es que un muestreo estratificado proporcional ayudará poco para tener buenas estimaciones de los dominos pequeños (p.e. Rural Agrupado). En esos casos puede ser preferible un muestreo estratificado con asignación no proporcional óptima \(Neyman, 1934).

=== Evaluación actual de la muestra usada en 2024
<evaluación-actual-de-la-muestra-usada-en-2024>
Desde el momento en que se diseñó la muestra (2023), la población de estudiantes y establecimientos fue cambiando. En especial, es notorio el aumento de establecimientos con jornada completa en los últimos años. Estos cambios poblacionales pueden sugerir dudas acerca de la adecuación de una muestra que fue diseñada para representar a una población con otras características. A pesar de estos supuestos razonables, la muestra actual no parece ---al menos en lo que respecta a los establecimientos--- haber quedado desfasada para captar el incremento de la jornada completa. Más en particular, se observa una pequeña sobrerepresentación de los establecimientos con jornada completa en esta primera etapa de la muestra. Esto puede deberse a que la expansión de la jornada completa se dío principalmente en establecimientos con matrícula no muy grandes que es justamente el tipo de establecimeintos en donde la muestra anterior parecía tener más casos. A continuación, en la #ref(<tbl-poblacion_muestra_2024>, supplement: [Tabla]), se comparan parámetros poblacionales de los establecimientos con las respectivas estimaciones de la muestra.

#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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

El punto 3.2 y el punto 3.3 merecen algo más de justificación porque pueden parecer contraintuitivos. En efecto, que en la primera etapa los establecimientos sean seleccionados en función del tamaño de la matrícula permite que, para la segunda etapa de la muestra, se pueda tener una regla simple como la asignación de un número fijo de estudiantes para cada establecimiento. Esto, además, permite (en ausencia de problemas de no-respuesta) hacer análisis con una muestra autoponderada. Más concretamente, se aspira a registrar 10 estudiantes de cada establecimiento.

En los establecimientos en donde haya más de una sección, se puede armar un orden de prioridad entre las secciones disponibles y quedarse, en principio, solo con la que mayor prioridad obtenga. Previamente se puede generar un número para cada caso/establecimiento seleccionado que ordene a los establecimientos en función de algún criterio (p.e. matrícula). Algunos establecimientos obtendran un número par y otros tendrán uno impar. En este sentido, una vez sorteada la sección, se usa el valor del número anterior para indicar el modo de selección de los 10 estudiantes. Si ese establecimiento posee un número par, se elige a los primeros 10 estudiantes. Si ese establecimeinto posee un número impar, se elige los últimos 10 estudiantes. Si la sección seleccionada se agota sin llegar a los 10 casos se pasa a la sección siguiente en el orden de prioridad siguiendo luego el mismo criterio de selección de los estudiantes que en la sección anterior.

De este modo se tiene una regla no arbitraria (en el sentido que no decide el docente o el establecimiento qué caso cargar), la misma parece ser probabilística y, de manera derivada, permite trabajar (en ausencia de problemas de no-respuesta) con los datos sin ponderar.

== Primera Etapa
<primera-etapa>
Teniendo presente las restricciones anteriores se realizó una primera etapa de la muestra a nivel de establecimientos. Se recuerda que la muestra aspira a ser una muestra de estudiantes más que de establecimientos por lo que algunas desviaciones en esta etapa son más esperables que otras. En particular, es esperable que la media de la matrícula de los establecimientos seleccionados sea mayor a la media de la matrícula de la población de establecimientos. Algunos de los resultados, principalmente en cuanto a valores de tendencia central, se pueden ver en la #ref(<tbl-poblacion_muestra_2025>, supplement: [Tabla]).

#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
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
== Introducción
<introducción>
El objetivo es realizar una muestra de los estudiantes jóvenes, adultos y adultos mayores (EJAyAM) que asisten, en 2026, a establecimientos de dependencia oficial en la provincia de Buenos Aires. Como se verá a continuación, esta aplicación en interesante porque, entre otras cuestiones:

- Tensiona la percepción de los dominios de estimación como sinónimos de los estratos de una muestra.

- En parte relacionado con el punto anterior, se verá de forma explícita las virtudes de distinguir entre los objetivos o fines de la muestra con los modos o medios para cumplir con ellos.

- Por último, se verá que, al menos al principio o #emph[a priori] (y con las limitaciones propias del que esto escribe) no queda claro que "medios" son los más óptimos para conseguir los "fines" propuestos.

El presente diseño muestral, a diferencia de #ref(<sec-muestra_peb_2025>, supplement: [Sec.]), no tiene que ser compatible o mejorar en algunos puntos específicos de un diseño muestral anterior. Por otro lado, en este caso sí hay exigencias o restricciones específicas en cuanto a la precisión estadística del resultado esperado sobre diferentes dominios de estimación.

En otras situaciones relativamente similares, esas exigencias/restricciones se explicitan o se traducen en términos de costo operativo o económico del estilo "Nosotros podemos/queremos una muestra de X casos" o "Recolectar tal tipo de caso nos cuesta más que tal u otro así que, en lo posible, tenga eso en cuenta dentro del diseño". Si bien no se trata de una investigación que se espera realizar de manera virtual (lo que haría que su coste fuera muy marginal) se trata de una investigación en donde la organización posee una capacidad destacable para acceder a los diferentes establecimientos educativos aunque su capacidad para acceder a los estudiantes sea algo menor. Veremos que estos detalles serán importantes para definir algunos puntos particualres del diseño muestral.

En cualquier caso, en el diseño de una muestra siempre es importante distinguir cuáles son los objetivos, cuáles son las restricciones y cuáles son los márgenes de maniobra para obetener una solución relativamente óptima al problema \(Valliant et~al., 2018, Capítulo 5).

El orden de presentación será el siguiente. Se comenzará enunciando los objetivos originales de la muestra (#ref(<sec-objetivos_muestra_adultos>, supplement: [Sec.])) lo que, a su turno, facilitará el proceso de delimitar la población objetivo (#ref(<sec-poblacion_objetivo_muestra_adultos>, supplement: [Sec.])). Posteriormente, se presentará de manera exploratoria algunas características del marco muestral (#ref(<sec-marco_muestral_adultos>, supplement: [Sec.])). Todo lo anterior permitirá aportar información para estimar las dimensiones de los dominios de estimación, de manera posterior a una distinción semántica previa entre estos y los estratos (#ref(<sec-adultos_dominios_estimacion>, supplement: [Sec.])).

Dado los diferentes objetivos en danza se pasa a una sección en donde se analizan simulaciones que intentan visibilizar los efectos de los cambios de algunos parámetros claves de un diseño polietápico (#ref(<sec-alternativas_adultos>, supplement: [Sec.])). Finalmente, en la sección #ref(<sec-diseno_muestra_adultos>, supplement: [Sec.]), se detalla el diseño finalmente ejecutado.

== Objetivos
<sec-objetivos_muestra_adultos>
A diferencia de otras investigaciones, en la presente y solamente teniendo como contexto la información que se comunicó para el diseño de la muestra, no se sabe bien cuál es el objetivo de la investigación, aunque si se tienen algunas precisiones para con los objetivos de la muestra. Esta distinción es importante porque algunas decisiones de diseño muestral son más óptimas cuando se tienen algunos objetivos específicos, pero también pueden producir un efecto de sobreadaptación (#emph[overfitting]) si luego se quiere utilizar la muestra para fines diferentes a los originalmente previstos.

Expresado en el lenguaje clásico de los márgenes de error, como regla general se comunicó que la precisión de las inferencias sean con:

- Un nivel de confianza de 90%

- Una heterogeneidad para las proporciones de $P = 50$

Sin embargo, la complejidad de esta muestra es que, con estos supuestos de fondo, los márgenes de error que se piden son diversos para diferentes subpoblaciones que surguen o se construyen, en general, mediante un cruce entre otras variables disponibles en el marco muestral. Algunos de esos cruces tienen la particularidad que implican variables que podrían considerarse como jerárquicas (p.e. Región y Distrito) lo que plantea sus problemas particulares (ver #ref(<sec-adultos_dominios_estimacion>, supplement: [Sec.])). Finalmente, en el pedido original se pide explícitamente poder hacer inferencias para:

- Establecimientos FINES a nivel de regiones agregadas con un margen de error del 5%.

- Establecimientos EPA y CENS se espera poder hacer inferencias a nivel de Gran Área con un margen de error del 3%.

Por otro lado, para otra serie de establecimientos se espera, dada su escasa presencia en la población, una recolección censal de los mismos. Por esta razón no habrá márgen de error predeterminado para estos casos. Se incluyen en esta situación a:

- Establecimientos CEBAS

- Establecimientos EPA y FINES en situación de encierro.

Implíctamente, la idea que está por detrás de esto último es que, a para aquellos tipos de establecimientos que tienen una mayor incidencia en la población, se espera una mayor exigencia en cuanto a la precisión de la estimación, especialmente en términos de desagregaciones espaciales.

Por ahora no diremos algo más específico con referencia a los medios para lograr estos objetivos. La razón de esto es, justamente, distinguir los objetivos del estudio de los medios para lograrlos. Incluso los mismos objetivos se podrían expresar de manera alternativa basándose en el léxico del coeficiente de variación (#emph[CV]) que puede considerarse como un error estándar relativo \(Valliant et~al., 2018, pág. 3). El cómo enunciar los objetivos de una muestra no algo banal. En efecto, suele haber diferencias entre las disciplinas a la hora de que pedirle a una muestra. Por ejemplo, en contextos epidemiológicos es usual hablar de #emph[power requirements] aunque lo usual en las ciencias sociales es hablar sobre #emph[precision goals] \(Valliant et~al., 2018, pág. 8). Más adelante veremos que esta distinción será pertinente para esta muestra.

== Población objetivo
<sec-poblacion_objetivo_muestra_adultos>
La población objetivo (#emph[target population]) es la población a la cual se va a intentar realizar, explícitamente, las inferencias (totales o agregadas) con los análisis de los datos de la muestra. Por esta razón, es aconsejable pensarla y mantenerla firme en mente durante el diseño de la muestra, para entre otras cuestiones, anticipar potenciales divergencias con otros tipos de poblaciones como, por ejemplo, el marco muestral o la población efectivamente muestrada \(Kish, 1987, pág. 30).

En este contexto, más allá que se cuente previamente o se construya especialmente para la ocasión, siempre es importante saber el origen del marco muestral. La indagación sobre este punto infroma sobre las posibles divergencias entre la población objetivo y el marco muestral. En este sentido, no es lo mismo que el marco muestral deje afuera algo deseado, pero impráctico de obtener que, por otro lado, algo que si bien desde lejos parecía cercano a la población objetivo, luego se prefirió no incluir. En el primer caso, se mantiene la definición intensiva de la población objetivo, pero se restringue la extensión empírica del marco muestral creando una distancia entre uno y otro (p.e problemas de cobertura). En el segundo caso, lo que se cambia/ajusta es la definición misma de la población objetivo y se evita una distancia entre lo deseado/buscado y lo realizable con el marco muestral disponible.

Aplicado lo anterior al presente problema, una cuestión a discernir es el nivel de población objetivo. En este caso, más allá que la parte del león de un diseño como el presente se le lleve como seleccionar a los establecimientos, el objetivo (de ahí lo de poblacion objetivo) es obtener una muestra de los estudiantes #strong[adultos] de nivel primario y secundario de la provincia de Buenos Aires.

Sin embargo, como se observa en #ref(<tbl-poblacion_objetivo>, supplement: [Tabla]), existen una serie de establecimientos (y por ende, sus estudiantes) de educacion de jóvenes y adultos que, a pesar de ser establecimientos de estudiantes adultos, quedan por fuera de la población objetivo de esta muestra. Más concretamente, existe un 19% que no posee todas las características necesarias.

#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 9.75pt); table(
  columns: (50%, 50%),
  align: (left,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 3.958]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Población Objetivo, n (%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.211 (81%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~NO], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[747 (19%)],
)}
], caption: figure.caption(
position: top, 
[
Población objetivo dentro del universo de establecimiento de educación adulta de la provincia de Buenos Aires
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-poblacion_objetivo>


Entre las características que se tuvieron en cuenta se encuentran en la confección de la población objetivo se encuentra la dependencia y el tipo de establecimiento. Como se observa en #ref(<tbl-poblacion_objetivo_criterios>, supplement: [Tabla]) todos los establecimientos de la población objetivo son de dependencia oficial. Dada que la presencia de otros tipos de dependencia en la educación adulta es muy baja, este criterio no parece ser muy crítico desde un punto de vista empírico.

Sin embargo, esto no significa que todos los establecimientos de dependencia oficial de educación de adutlos pertenecen a la población objetivo. En efecto, existe un 19% de estos que no pertenecen a la población objetivo. Dentro del nivel primario, se trata de los establecimientos CEPA (671) y los centros de alfabetización (45) y dentro del nivel secundario se trata de aquellos establecimientos denominados "Escuelas de educación media o secundaria". Los que sí entran a la población objetivo, siempre que sean de dependencia oficial, son los establecimientos FINES, los CENS, los EPA y los CEBAS.

#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 9.75pt); table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,center,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: bottom + center, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Total] \
    N = 3.958], table.cell(align: center, colspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Población Objetivo]
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[NO] \
    N = 747], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[SI] \
    N = 3.211],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Tipo de establecimiento, n (%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.319 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.319 (100%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~CEPA], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[671 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[669 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 (0,3%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~CENS], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[542 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7 (1,3%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[535 (99%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~EPA], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[337 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 (0,6%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[335 (99%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~ALFABETIZACION], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[50 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[50 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~CEBAS], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20 (100%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~ESC. EDU. MEDIA], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~ESC. EDU. SECUNDARIA], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Dependencia, n (%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Oficial], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.930 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[719 (18%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.211 (82%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Privada], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[23 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[23 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Nacional], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Municipal], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 (100%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 (0%)],
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


En la #ref(<fig-diagram_poblacion_objetivo>, supplement: [Figura]) se intenta sintetizar parte de los comentarios anteriores. Esta contiene el agregado, no menor desde lo institucional (pero menos importante para el diseño muestral), de la distinción dentro del nivel secundario entre la oferta instituciaonal (CENS y CBEBAS) y la oferta extrainstitucional (FINES).

#figure([
#block[
#box(image("muestra_adultos_files\\figure-typst\\dot-figure-1.png", height: 3.6in, width: 4in))

]
], caption: figure.caption(
position: top, 
[
Establecimientos de educación adulta y población objetivo
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-diagram_poblacion_objetivo>


== Marco muestral
<sec-marco_muestral_adultos>
Una vez definida la población objetivo comenzamos a trabajar para mejorar el marco muestral recibido. Decimos que comenzamos a "mejorar" porque, por suerte, ya tenemos un marco muestral básico que nos permite identificar a las unidades de selección primarias (#emph[PSU] en inglés). Decimos "por suerte" porque una característica particularmente interesante de trabajar en grandes organizaciones, que no es lo usual por fuera de ellas, es la posibilidad de trabajar con un marco muestral (#emph[sampling frame]) que se ajuste bastante bien a la población objetivo (#emph[population target]). Por ejemplo, en una universidad o colegio podemos tener un listado de estudiantes relativamente actualizado. En este caso, el marco muestral es a nivel de los establecimientos y está equipado con información auxiliar que se usará explícitamente en el diseño muestral.

En cambio, en otro tipo de investigaciones, los investigadores suelen dedicar un tiempo considerable a conseguir un marco muestral que o bien sobrerrepresente o subrepresente empíricamente a la población objetivo. Cabe recordar que el marco muestral no es solo una lista de elementos a seleccionar, sino que también debe contar con alguna información que ayude a su contacto/localización. Tener una lista de DNI para cada uno de los miembros del marco muestral de personas es una ayuda, pero no es muy útil si esa información no viene anexada con algún dato que permita contactar/localizar a los DNI efectivamente seleccionados en la muestra.

Antes anticipamos dijimos el marco muestral básico con el que vamos a trabajar nos permite identificar a las unidades de selección primarias. En otras palabras, vamos a trabajar con un listado de establecimientos y no de estudiantes y vamos a desarrollar un muestreo polietápico en donde en primera instancia (de ahí lo de unidades "primarias") se seleccionan establecimientos y recien luego se seleccionan secciones y/o estudiantes.

Para la selección de las unidades de seleccion, existen dos tipos generales de marcos muestrales: directos e indirectos \(Valliant et~al., 2018, pág. 6). Los marcos muestrales que contienen una lista de las unidades de observación finales se denominan #strong[marcos directos]. Estos marcos facilitan/permiten los diseños de una sola etapa. Por ejemplo, si se tiene una lista de estudiantes y algún contacto virtual (p.e. mail), se puede perfectamente realizar un diseño en una sola etapa. En ese caso, no será necesario seleccionar primero a unidades de selección primarias como, por ejemplo, los establecimientos educativos.

Los #strong[marcos indirectos], en cambio, requieren de mucha menor información, se pueden construir con datos agregados y permiten realizar la selección de las unidades de selección primarias (#emph[clusters] o conglomerados). Este tipo de marcos se utilizan típicamente en diseños polietápicos. En cambio, los marcos directos se pueden usar tanto en diseños de una sola etapa o, vía agregación de su información, en diseños polietápicos.

Volviendo a nuestro marco muestral el mismo es del tipo #strong[indirecto] y, suponemos, que es de una muy buena calidad en términos de su ajuste a la población objetivo. La posibilidad de contar con información auxiliar sobre cada uno de los establecimientos, que a continuación comenzaremos a explorar, permite la realización de una serie de diseños que de otra manera serían inviables de llevar a la práctica.

Como vemos en la #ref(<tbl-sampling_frame>, supplement: [Tabla]) tenemos información auxiliar a nivel de cada establecimiento tanto de variables discretas como continuas:

Variables #strong[discretas]:

- Distrito

- Región

- Región Agrupada

- Ámbito

- Área

- Nivel

- Tipo de establecimiento

- Condición de encierro

Variables #strong[continuas]:

- Matrícula

- Secciones

- Media de estudiantes por sección

- índice de vulnerabilidad socioecómico - IVSE

#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol")); table(
  columns: 36,
  align: (left,left,center,right,right,left,right,center,right,right,left,left,left,left,left,left,center,left,left,left,center,right,right,left,center,left,left,left,right,right,left,left,left,right,left,right,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); codigo], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); tipo], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); region], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); region\_n], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); region\_agrupada], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); distrito], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); distrito\_n], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); area], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); cue], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); anexo], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); clave], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); dependencia], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); tipo\_de\_organizacion], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); sede\_anexo\_extension], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); escuela\_sede], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); nombre], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ambito], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); matricula\_estimada], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); modalidad], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); nivel], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); encierro], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); matricula], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); secciones], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); population\_target], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); universo\_excl], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); estrato\_oferta], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); estrato\_geo], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); dominio], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ivse], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ece], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); distrito\_boleto], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); criterio\_seleccion], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); casos\_seleccionar\_lista], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); fines\_direccion], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); tipo\_est\_adulto], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); estudiante\_seccion],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0043DS0011], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[GENERAL PUEYRREDON], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[43], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[INTERIOR], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[609259], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0043DS0011], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. N 11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[97], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.06337987], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SIN], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENSO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[PRIMEROS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16.16667],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0008DS0030], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[22], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[22], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16-21-22-23], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[BAHIA BLANCA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[INTERIOR], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[616446], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0008DS0030], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. N 30 \"ENFERMERAS 1982 POR MALVINAS\"], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[48], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.09438071], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SIN], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENSO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[PRIMEROS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16.00000],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0062DS0016], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[02], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[02], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[LOMAS DE ZAMORA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[62], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[AMBA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[614623], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0062DS0016], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S N 16], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[63], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.09611583], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CON], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENSO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[PRIMEROS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10.50000],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0111DS0049], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[02], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[02], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[LANUS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[111], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[AMBA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[620507], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0111DS0049], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. N 49], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[43], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.14383187], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CON], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENSO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ULTIMOS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.33333],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0100DS0028], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[08], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[08], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[MORON], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[100], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[AMBA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[616437], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0100DS0028], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. N 28], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[109], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.15550203], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CON], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENSO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ULTIMOS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[18.16667],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0032DS0013], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[04], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[04], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[FLORENCIO VARELA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[32], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[AMBA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[608715], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0032DS0013], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. N 13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[82], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.17282251], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CON], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENSO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[PRIMEROS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[27.33333],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0001DS0001], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[01], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[01], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[LA PLATA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[INTERIOR], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[609006], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0001DS0001], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. N 1 \"FLOREAL FERRARA\"], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[256], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.17714942], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CON], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENSO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[PRIMEROS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[28.44444],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0030DS0041], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[05], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[05], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ESTEBAN ECHEVERRIA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[30], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[AMBA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[620534], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0030DS0041], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. N 41], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[33], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.18888588], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CON], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENSO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ULTIMOS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11.00000],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0094DS0047], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SAN ANTONIO DE ARECO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[94], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[INTERIOR], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[619088], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0094DS0047], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. N 47], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[33], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.18974226], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SIN], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENSO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ULTIMOS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16.50000],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0076DS0019], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15-17-24-25], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9 DE JULIO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[76], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[INTERIOR], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[615601], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0076DS0019], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. N 19], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[39], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.19851275], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SIN], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENSO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ULTIMOS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.00000],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0055DS2370], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[06], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[06], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[TIGRE], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[55], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[AMBA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[616870], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0055DS2370], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[EXTENSION], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0116DS0037], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. N°37 - EXTENSIÓN], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[61], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.20705157], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CON], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENSO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ULTIMOS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20.33333],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0001DS0048], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[01], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[01], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[LA PLATA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[INTERIOR], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[620508], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0001DS0048], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. N 48 \"DR. RENÉ FAVALORO\"], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.25350336], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CON], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENSO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ULTIMOS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16.00000],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0045DS0002], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[07], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[07], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[GENERAL SAN MARTIN], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[45], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[AMBA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[609445], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0045DS0002], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. N 2 \"EDUCADOR PAULO FREIRE\"], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[89], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.28876384], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CON], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENSO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ULTIMOS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.83333],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0005DS0010], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[02], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[02], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[AVELLANEDA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[AMBA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[610303], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0005DS0010], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. N 10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[124], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.29353985], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CON], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENSO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[PRIMEROS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20.66667],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0071DS0029], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Un.Serv.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[08], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[08], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[MERLO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[71], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[AMBA], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[616233], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0071DS0029], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oficial], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENTRO ESPECIALIZADO PARA ADULTOS CON ORIENTACIÓN EN SALUD (CEBAS)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SEDE], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[C.E.B.A.S. N 29], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Urbano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Educación de Jóvenes y Adultos], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[102], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[UNICO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS\_UNICO], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.34991110], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CON], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CENSO], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ULTIMOS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[CEBAS], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[17.00000],
)}
], caption: figure.caption(
position: top, 
[
Macro muestral con información auxiliar
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-sampling_frame>


Para tener una idea de las distribuciones de estas variables vamos a realizar un análisis exploratorio de las mismas. Para esto, vamos a realizar un análisis descriptivo de cada una de las variables discretas y continuas tanto a nivel de la población de establecimientos como a nivel de la población (sintética) de los estudiantes. Para las variables discretas vamos a mostrar su distribución en términos de tablas de frecuencias y porcentajes. Para las variables continuas, vamos a mostrar su distribución a través de histogramas o gráficos de densidad.

Como puede observarse en #ref(<tbl-comparacion>, supplement: [Tabla]), de las 25 regiones, algunas poseen menos del 1% de los estudiantes (p.e. 16, 17, 21, 23). Estas regiones son buenas candidatas para agruparse con otras regiones para facilitar la estimación en subpoblaciones espaciales. Eso es lo que se hace con la variable "Región agrupada" que logra el modesto avance de que las regiones más pequeñas en términos de estudiantes sean la 13 (1.4%) y la 20 (1.6%).

Para lo que respecta a los dominios de estimacion (#ref(<sec-adultos_dominios_estimacion>, supplement: [Sec.])) la agregación de "Gran Área" no parece mostrar una agrupación muy desbalanceada (58% vs.~42%). Esto asegura, en la práctica, que con una buena representación de la variable "Región Agrupada" en el camino también se obtiene una aceptable distribución de la variable "Gran Área".

En cuanto a la variable "Tipo de establecimiento" se observa la siguiente distribución. La situación más problemática parece ser los CEBAS que poseen menos del 1% de los estudiantes. A diferencia que con las regiones, con los tipos de establecientos no es posible una agregació mayor

En cuanto a los niveles tampoco parece haber mayores problemas aunque, estrictamente, esta variable no está incluida dentro de los dominios de estimación.

#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Establecimientos]
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Estudiantes]
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 3.211]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 205.828]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Región], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[242 (7,5%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15.254 (7,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~02], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[271 (8,4%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[17.390 (8,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~03], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[360 (11%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[21.093 (10%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~04], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[255 (7,9%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[18.473 (9,0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~05], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[274 (8,5%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19.053 (9,3%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~06], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[103 (3,2%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8.160 (4,0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~07], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[144 (4,5%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9.111 (4,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~08], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[190 (5,9%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12.278 (6,0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~09], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[175 (5,5%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.346 (7,0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[158 (4,9%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8.786 (4,3%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[152 (4,7%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11.207 (5,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[77 (2,4%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.859 (2,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[52 (1,6%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.869 (1,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~14], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[61 (1,9%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.753 (1,8%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~15], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[51 (1,6%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.636 (1,3%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~16], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[35 (1,1%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.599 (0,8%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~17], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[33 (1,0%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.521 (0,7%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~18], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[82 (2,6%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.177 (2,0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~19], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[183 (5,7%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9.848 (4,8%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~20], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[74 (2,3%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.355 (1,6%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~21], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[42 (1,3%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.898 (0,9%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~22], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69 (2,1%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.936 (2,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~23], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[38 (1,2%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.616 (0,8%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~24], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[32 (1,0%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.352 (1,1%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~25], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[58 (1,8%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.258 (2,6%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Región Agrupada], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[242 (7,5%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15.254 (7,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~02], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[271 (8,4%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[17.390 (8,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~03], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[360 (11%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[21.093 (10%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~04], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[255 (7,9%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[18.473 (9,0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~05], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[274 (8,5%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19.053 (9,3%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~06], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[103 (3,2%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8.160 (4,0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~07], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[144 (4,5%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9.111 (4,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~08], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[190 (5,9%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12.278 (6,0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~09], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[175 (5,5%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.346 (7,0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[158 (4,9%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8.786 (4,3%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[152 (4,7%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11.207 (5,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[77 (2,4%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.859 (2,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[52 (1,6%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.869 (1,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~14], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[61 (1,9%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.753 (1,8%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~15-17-24-25], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[174 (5,4%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11.767 (5,7%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~16-21-22-23], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[184 (5,7%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10.049 (4,9%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~18], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[82 (2,6%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.177 (2,0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~19], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[183 (5,7%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9.848 (4,8%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~20], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[74 (2,3%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.355 (1,6%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ámbito], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Urbano], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.176 (99%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[199.608 (97%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Agrupado], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15 (0,5%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[616 (0,3%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Rural Disperso], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20 (0,6%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.604 (2,7%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Gran Área], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~AMBA], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.772 (55%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[119.904 (58%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~INTERIOR], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.439 (45%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[85.924 (42%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Nivel], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Primario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[892 (28%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[123.548 (60%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Secundario], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.319 (72%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[82.280 (40%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Tipo de establecimiento], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~CEBAS], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20 (0,6%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.590 (0,8%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~CENS], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[535 (17%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[80.853 (39%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~CEPA], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 (\<0,1%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[50 (\<0,1%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~EPA], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[335 (10%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[41.055 (20%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.319 (72%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[82.280 (40%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Matrícula], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[33 (19 -- 80)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[119 (57 -- 203)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Secciones], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0 (1,0 -- 4,0)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6,0 (3,0 -- 11,0)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Estudiante por sección], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19 (14 -- 24)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[20 (16 -- 26)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Condición de encierro], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~SI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[82 (2,6%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[18.637 (9,1%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~NO], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.129 (97%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[187.191 (91%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[IVSE], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,48 (0,32 -- 0,65)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,47 (0,30 -- 0,63)],
  table.hline(),
  table.footer(table.cell(colspan: 3)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] n (%); Mediana (Q1 -- Q3)],),
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


Por último, antes de pasar a la siguiente sección, analizaremos la relación entre la cantidad de secciones y el tamaño de los establecimientos. Esto nos puede anticipar una idea de como se comportarían diferentes diseños muestrales en función de como seleccionen o censen a las secciones de cada establecimiento seleccionado en la primera etapa.

#figure([
#box(image("muestra_adultos_files/figure-typst/fig-matricula_seccion-1.svg"))
], caption: figure.caption(
position: top, 
[
Relación entre el tamaño de la matrícula y la cantidad de secciones de los establecimientos
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-matricula_seccion>


== Dominios de estimación
<sec-adultos_dominios_estimacion>
Muchas veces el concepto de #strong[estrato] se confunde con el de #strong[dominio de estimación]. Parte de esta confusión tiene su origen que en muchas investigaciones ambos conceptos son coextensivos. Sin embargo, para parte de la bibliografía, se trata de dos conceptos con significados diferentes. El estrato es más una herramienta, en especial en comparación para con el azar simple, para mejorar la precisión de las estimaciones y/o controlar el tamaño muestral de los dominios de estimación \(Kish, 1965, pág. 76-77). En cambio, el dominio de estimación tiene más que ver con los objetivos que se espera que la muestra estime de la población. En otras palabras, el primero es un medio (entre otros) y el segundo un fin (entre otros). El problema es que, usualmente, en el contexto de tener como objetivos varios dominios de estimación, es un buen medio crear un estrato para cada uno de ellos \(Tillé, 2020, pág. 79). En efecto, como señala Valliant y cía, una pregunta sumamente legítima es "¿Si los dominios serán importantes para el análisis, por qué no hacer que cada dominio sea un estrato de diseño y que entonces el tamaño muestral de cada uno pueda ser controlado?" \(Valliant et~al., 2018, pág. 70). La respuesta es que algunas veces el muestreo estratificado no es la mejor respuesta y lo difícil es saber o anticipar cuando hay otras mejores opciones.

Dado que parte de la confusión tiene que ver por su gran coextensión puede ser útil pensar en situaciones en donde estos conceptos no sean, justamente, coextensivos. Por un lado, puede que el dominio de estimación sea la propia población total (como algo diferente a alguna subpoblación de ella). En ese caso se puede construir estratos para realizar un diseño estratificado simplemente porque este diseño, al menos en comparación con el azar simple, es más eficiente. En este ejemplo hay estratos y no hay dominios de estimación como subpoblaciones. En cualquier caso, lo importante es que en este ejemplo hay más estratos que dominios de estimación y, por lo tanto, en este ejemplo ambos conceptos no serían coextensivos.

Otro ejemplo podría ser donde efectivamente sí haya varios dominios de estimación, esto es, se desea realizar inferencias para diversas subpoblaciones, pero no se realice un diseño estratificado. Para muchos este ejemplo puede resultar forzado porque suponen que se trata de un ejemplo ficticio en donde se asume cierta ignorancia del diseñador de la muestra. El supuesto por detrás de esta opinión es que si bien puede ser realizable la combinación que propone el ejemplo, la misma se encuentra fuera lo óptimo y de ahí que se considere como un caso forzado. Sin embargo, esto no siempre es así. Puede que existan algunos casos en donde se requiera múltiples dominios de estimación y donde el mejor medio para ese fin no sea la construcción de múltiples estratos. Diseños como el balanceado o el bien distribuido (#ref(<sec-cubo>, supplement: [Sec.])) no necesitan, explícitamente, la construcción de estratos y puede, en algunos casos, ser más aconsejables que un diseño estratificado.

Dejando las similitudes extensivas y volviendo a las diferencias intensivas o de sentido entre ambos conceptos, los dominios de estimación son partes de la población para los cuales diferentes estimaciones son planificadas en el diseño muestral \(Kish, 1965, pág. 77). Estas suelen tener como referentes a la propia población y no a una muestra de la misma \(Kish, 1987, pág. 34). Esto no quiere decir que todo dominio de estimación tenga como objetivo estimar un valor de toda la población. Claro que es posible (y usual) tener dominios de estimación que impliquen alguna subdivisión de la población o, de forma más precisa, alguna subpoblación. Lo que quiere afirmar Kish es que esa subpoblación tiene como referente a la población y no a la muestra.

Muchas veces los dominios de estimación se estipulan en función de criterios administrativos/políticos. Usualmente, este es el caso de los dominios distritales o regionales. Esta distinción, muchas veces (pero no siempre) puede también implicar similitudes y diferencias sociales por detrás. Si esto es así, estamos en presencia de buenos candidatos para que esos dominios también se consideren como estratos, dado que su construcción agrupará casos relativamente más similares entre sí que si se hubieran elegido al azar dentro de toda la población. El punto crítico de la afirmación anterior es el "pero no siempre" que, nuevamente, habilita la distinción entre dominios de estimación y estratos. Para poner un ejemplo, los distritos de General Pueyrredón y Bahía Blanca son distritos que contienen tanto población urbana como rural dentro de sus límites. En efecto, cada uno de ellos contiene una gran ciudad en su interior con su respectivo conurbano. En otras palabras, es clara su utilización como dominio de estimación, pero no es clara la utilización de esos casos, en términos de asegurar una menor heterogeneidad de alguna variable de interés, dentro de un estrato denominado como "Interior" como algo diferente a "AMBA".

En cualquier caso, la explicitación de los dominios de estimación en conjunción con alguna otra preferencia (en este caso la preferencia sobre determinados niveles de precisión de esas estimaciones), funciona como variables críticas a la hora de decidir sobre el combo de diseño y tamaño muestral \(Kish, 1965, Capítulo 8). En muchas situaciones es útil representar estas descripciones como objetivos y restricciones dentro de un problema de optimización multicriterio \(Valliant et~al., 2018, Capítulo 5).

=== Dominios de estimación originales
<sec-adultos_dominios_originales>
A continuación, en la #ref(<tbl-dominios_comparacion>, supplement: [Tabla]), se explicita los dominios de estimación. En general parecen ser una combinación de cuestiones de tipo de oferta educativa y diferentes agrupaciones espaciales. En total son 26 dominios de estimación que se encuentran ordenadas en función del porcentaje de establecimientos. Como regla general, para los dominios espaciales se espera un margen de error de:

- 5 pp.~para los análisis a nivel de Región Agregada

- 3 pp.~para los análisis a nivel de Gran Área

#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 9.75pt); table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,center,center,),
  table.header(table.cell(align: bottom + left, rowspan: 2, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Establecimientos]
    ]], table.cell(align: center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #block[
    #strong[Estudiantes]
    ]],
    table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 3.211]#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N = 205.828]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Dominio, n (%)], table.cell(align: horizon + center, fill: rgb("#808080"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#ffffff"));  \
  ], table.cell(align: horizon + center, fill: rgb("#808080"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#ffffff"));  \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~CENS\_AMBA], table.cell(align: horizon + center, fill: rgb("#08306b"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#ffffff")); 330 (10%)], table.cell(align: horizon + center, fill: rgb("#08306b"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#ffffff")); 51.175 (25%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R03], table.cell(align: horizon + center, fill: rgb("#0a539d"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#ffffff")); 289 (9,0%)], table.cell(align: horizon + center, fill: rgb("#d0e2f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 11.126 (5,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R05], table.cell(align: horizon + center, fill: rgb("#3b8ac2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#ffffff")); 223 (6,9%)], table.cell(align: horizon + center, fill: rgb("#cfe1f2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 11.546 (5,6%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R04], table.cell(align: horizon + center, fill: rgb("#529ccc"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#ffffff")); 200 (6,2%)], table.cell(align: horizon + center, fill: rgb("#deebf7"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 7.498 (3,6%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~EPA\_AMBA], table.cell(align: horizon + center, fill: rgb("#549dcd"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#ffffff")); 198 (6,2%)], table.cell(align: horizon + center, fill: rgb("#77b4d8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 24.834 (12%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R02], table.cell(align: horizon + center, fill: rgb("#58a0ce"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#ffffff")); 194 (6,0%)], table.cell(align: horizon + center, fill: rgb("#e4eff9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 6.113 (3,0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R01], table.cell(align: horizon + center, fill: rgb("#6baed6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 175 (5,5%)], table.cell(align: horizon + center, fill: rgb("#e9f2fa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 4.816 (2,3%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~CENS\_INTERIOR], table.cell(align: horizon + center, fill: rgb("#79b5d9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 165 (5,1%)], table.cell(align: horizon + center, fill: rgb("#a0cbe2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 19.658 (9,6%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R19], table.cell(align: horizon + center, fill: rgb("#94c4df"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 144 (4,5%)], table.cell(align: horizon + center, fill: rgb("#eaf2fb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 4.602 (2,2%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R10], table.cell(align: horizon + center, fill: rgb("#a3cce3"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 132 (4,1%)], table.cell(align: horizon + center, fill: rgb("#eef5fc"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 3.532 (1,7%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R08], table.cell(align: horizon + center, fill: rgb("#a6cde4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 129 (4,0%)], table.cell(align: horizon + center, fill: rgb("#e9f2fb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 4.690 (2,3%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R09], table.cell(align: horizon + center, fill: rgb("#aed1e6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 121 (3,8%)], table.cell(align: horizon + center, fill: rgb("#e8f1fa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 5.148 (2,5%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R15172425], table.cell(align: horizon + center, fill: rgb("#b7d5ea"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 112 (3,5%)], table.cell(align: horizon + center, fill: rgb("#f1f7fd"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 2.800 (1,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R11], table.cell(align: horizon + center, fill: rgb("#b8d5ea"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 111 (3,5%)], table.cell(align: horizon + center, fill: rgb("#e8f1fa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 5.110 (2,5%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R16212223], table.cell(align: horizon + center, fill: rgb("#bed8ec"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 105 (3,3%)], table.cell(align: horizon + center, fill: rgb("#f2f8fe"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 2.448 (1,2%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~EPA\_INTERIOR], table.cell(align: horizon + center, fill: rgb("#c6dbef"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 97 (3,0%)], table.cell(align: horizon + center, fill: rgb("#deebf7"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 7.654 (3,7%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R07], table.cell(align: horizon + center, fill: rgb("#c8dcf0"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 95 (3,0%)], table.cell(align: horizon + center, fill: rgb("#f0f7fd"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 2.934 (1,4%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R06], table.cell(align: horizon + center, fill: rgb("#deebf7"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 58 (1,8%)], table.cell(align: horizon + center, fill: rgb("#f5f9fe"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 1.915 (0,9%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R18], table.cell(align: horizon + center, fill: rgb("#e0ecf8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 56 (1,7%)], table.cell(align: horizon + center, fill: rgb("#f4f9fe"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 2.074 (1,0%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R20], table.cell(align: horizon + center, fill: rgb("#e4eff9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 50 (1,6%)], table.cell(align: horizon + center, fill: rgb("#f6faff"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 1.584 (0,8%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R12], table.cell(align: horizon + center, fill: rgb("#e4eff9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 49 (1,5%)], table.cell(align: horizon + center, fill: rgb("#f6faff"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 1.568 (0,8%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~ECE-EPA\_UNICO], table.cell(align: horizon + center, fill: rgb("#e8f1fa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 43 (1,3%)], table.cell(align: horizon + center, fill: rgb("#dae8f6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 8.677 (4,2%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~ECE-CENS\_UNICO], table.cell(align: horizon + center, fill: rgb("#ebf3fb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 39 (1,2%)], table.cell(align: horizon + center, fill: rgb("#d5e5f4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 9.960 (4,8%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R14], table.cell(align: horizon + center, fill: rgb("#ebf3fb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 39 (1,2%)], table.cell(align: horizon + center, fill: rgb("#f7fbff"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 1.293 (0,6%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~FINES\_R13], table.cell(align: horizon + center, fill: rgb("#ecf4fb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 37 (1,2%)], table.cell(align: horizon + center, fill: rgb("#f6fbff"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 1.483 (0,7%)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~CEBAS\_UNICO], table.cell(align: horizon + center, fill: rgb("#f7fbff"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 20 (0,6%)], table.cell(align: horizon + center, fill: rgb("#f6faff"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(fill: rgb("#000000")); 1.590 (0,8%)],
  table.hline(),
  table.footer(table.cell(colspan: 3)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1]] n (%)],),
)}
], caption: figure.caption(
position: top, 
[
Comparacion dominios de estimación. Nivel establecimientos y nivel estudiantes.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-dominios_comparacion>


La #ref(<tbl-dominios_comparacion>, supplement: [Tabla]) está también coloreada en función de la cantidad o porcentaje de cada columna. Esto sirve para percibir, entre otras cuestiones, los cambios de distribuciones a nivel de establecimientos en comparación con el nivel de los estudiantes. Dado que estos dominios son, en principio disyuntos o mutuamente excluyentes (aunque más adelante veremos que esto se puede relajar por la relación jerárquica de algunas variables) es claro que esto tensiona en demasía al diseño muestral. Si todos estos dominios tuvieran un mismo peso en la población estaríamos hablando de dominios que no superarían, en promedio, el 4% (100/26) en la población. En la práctica, a nivel de los establecimientos tenemos más de 18 dominios por debajo del 5%. Ese número sube a más de 20 dominios en el nivel de los estudiantes.

Esto último sucede porque a nivel de los estudiantes existe una mayor variabilidad en la distribución de los dominios. Por ejemplo, los CENS de AMBA concentran el 25% de los estudiantes (con el 10% de los establecimientos) y los EPA de AMBA concentran al 12% (con el 6% de los establecimientos).

También puede observarse que, como regla general, los establecimientos FINES poseen un menor tamaño o matrícula de los establecimientos. Inversamente, los CENS y EPA, incluso los de condición de encierro, poseen una media de estudiantes mayor a los FINES y por eso aumentan su porcentaje a nivel de estudiantes.

=== Comentarios sobre los dominios
<comentarios-sobre-los-dominios>
Más allá de lo expresado explícitamente en la sección anterior, es pertinente realizar las siguientes aclaraciones. En este diseño muestral en particular, los dominios de estimacion se pueden interpretar como una combinación de variables categóricas o discretas, pero con la característica que dos de ellas son variables que se encuentran jerárquicamente relacionadas. Otra complejidad relacionada es que no se espera la misma precisión para todos los dominios (#ref(<sec-objetivos_muestra_adultos>, supplement: [Sec.])). Nos explicamos.

Las variables que se han tenido en cuenta en los dominios de estimación son: \

- El tipo de organización (EPA, CEBAS, CENS, FINES)

- Condición de Encierro (SI, NO)

- La Región Agrupada (19 regiones)

- Gran Área (AMBA, INTERIOR)

Se puede discutir, quizá de modo bizantino, si estas 4 "variables" son diferentes o algunas son agrupaciones (p.e Gran Área) de otra variable más desagregada (p.e. Regiones Agrupada) o si es mejor entender algunas de ellas (p.e. Condición de encierro) como una condición previa que, luego de cruzarlos con los diferentes tipos de organización (p.e. CENS o EPA), produce una nueva variable que se podría denominar "Tipo de establecimiento" (p.e. ECE-CENS o ECE-EPA).

Con respecto a la relación entre "Gran Área" y "Regiones Agrupadas" nos inclinamos por afirmar que se tratan de dos variables jerárquicas porque "Gran Área" se puede considerar como una mayor agregación de la propia agrupación de regiones. Claramente, más allá de su posible relación con un centro de decisión política/administrativa, ambas se relacionan con cuestiones espaciales y, por lo tanto, también pueden suponerse como una agrupación particular de las 25 regiones y estas, a su turno, como una agregación de los distritos. Esta situación jerárquica no es menor porque la variable distrito también se encuentra disponible en el marco muestral.#footnote[Cabe destacar que algunas construcciones de la variable "Gran Área" no son simplemente una agregación de regiones sino, más específicamente, solo una agregación de distritos. Por ejemplo, a veces se utiliza el criterio que algunos distritos de la Region 5 pertenecen a la categoría AMBA (p.e. Almirante Brown) y otros pertenecen a la categoria "Interior" (p.e. San Vicente). En este caso, como se trata de una agregación explícita de regiones, la variable "Gran Área" puede considerarse como una variable jerárquica de distrito y también de regiones.]

La cuestión de la #strong[jerarquía de las variables] es importante en el diseño muestral por lo siguiente. En principio, si se obtiene una muestra balanceada a nivel de los distritos, esta también, de forma necesaria, lo será a nivel de las regiones, de las regiones agrupadas y de las grandes áreas. El camino inverso es probable pero nada seguro. Una muestra balanceada a nivel de las grandes áreas tiene chances de serlo para niveles inferiores, pero no existe ninguna seguridad. Pongamos un ejemplo para que se entienda mejor el problema. Supongamos que priorizamos el objetivo de tener una buena estimación a nivel de Gran Área y establecimientos EPA. Podría ser el caso que casi todos los establecimientos seleccionados en la categoría "AMBA" caigan en el distrito de "La Matanza" lo que desbalancea la muestra a nivel región y distrito. Esto no implica que la estimación "Gran Área - EPA" tenga algún problema en particular, pero si implica que en el diseño de la muestra no se hace nada en particualr para evitar los desbalanceso a nivel de region y distrito. Por esta razón, la existencia de variables jerárquicas en los dominios de estimación permite, vía una estrategia "#emph[botton-up]", una selección de establecimientos que, al tiempo que cumple los requisitos que exigen los dominios de estimación, también la hacen robusta a otros niveles y, de manera derivada, para responder otras preguntas de investigación diferentes a las originales.

=== Dominios en el espacio
<dominios-en-el-espacio>
En parte por los comentarios sobre la relación jerarquica de los dominios, a continuación vamos a realizar una serie de mapas para que estos nos ayuden a visualizar las diferentes zonas espaciales en función del tipo de organización. Estricamente, los dominios de estimación anteriores vinieron ya construidos en una columna que se llamaban "estrato\_oferta". Ahora nos va a interesar su visualización espacial a un nivel levemente más agregado, ya que se trata de usar otra variable que tiene que con el "tipo de organización".

De esta manera, esperamos observar, de un modo diferente a la #ref(<tbl-dominios_comparacion>, supplement: [Tabla]) como se distribuyen los diferentes tipos de establecimientos educativos a lo largo de las diferentes agrupaciones espaciales.

Ahora haremos lo mismo, pero a nivel de "Gran Área".

Lo importante de los mapas anteriores es la visualización de distribuciones extremase en el espacio. Lo importante es destacar tanto las áreas que acumulen una excesiva porción de los casos como, de manera inversa, aquellas en donde casi no existan casos.

== Alternativas muestrales
<sec-alternativas_adultos>
Para cumplir con lo anterior, no parece haber muchas dudas de que es necesario la realización de un #strong[muestreo polietápico] en donde en una primera etapa seleccione a los establecimientos y luego a los estudiantes que concurren a ellos. La principal justificación de esta afirmación es que se desea estimar algunas características de los estudiantes y no se tiene un marco muestral de los mismos, aunque sí de sus establecimientos. En algunos diseños específicos podrá quedar la duda sobre como tratar a las secciones de cada establecimiento o si esa acción se debe considerar como una "etapa" más en el diseño muestral.

Por otro lado, dado que seguramente se querrán hacer afirmaciones tanto a nivel de los estudiantes como también, mediante alguna agregación de los resultados, a nivel de los establecimientos, parece conveniente utilizar un muestreo #strong[PPS]. Este tipo de diseño es particularmente robusto cuando se piensa realizar inferencias a ambos niveles \(Kish, 1965, Capítulo 7; Kish, 1965, pág. 422).

Tampoco parece haber muchas dudas acerca de la relativa utilidad de evitar la proporcionalidad a ultranza. Esto parece claro dado que, como se observó en la sección #ref(<sec-adultos_dominios_estimacion>, supplement: [Sec.]), existen algunos dominios de estimación sumamente pequeños en la población. En esos casos parece razonable la realización de un cuasi censo de sus establecimientos y/o estudiantes según el caso.

Las dudas comienzan a aprecer en otros aspectos del diseño muestral. Por ejemplo:

- ¿Cuánto se prioriza la precisión de los estimadores univariados (p.e. Region) y cuanto la precisión de los dominios de estimación explicitados con todos son cruces de variables (p.e. Región y Tipo de establecimiento)? A igual cantidad de casos totales, un diseño que prioriza la precisión los dominios de estimación pequeños (p.e. #emph[power allocation] \(Bankier, 1988)) reduce la precisión de los estimadores totales porque aumenta la variabildad de los ponderadores. En cambio, si se valoran más los estimadores univaridos, existen diseños que lo logran a cambio de no necesariamente aumentar la cantidad de casos en los dominios más pequeños (p.e. a la Neyman \(Neyman, 1934))

- En palabra de Kish “Antes de decidir sobre un muestreo desproporcionado, deberíamos al menos

- ¿Cuántos establecimientos seleccionar y cuantos estudiantes por cada establecimiento? A igualdad de condiciones es claro que, por ejemplo, para una muestra de 10.000 estudiantes no es lo mismo seleccionar a 5 estudiantes de 2000 establecimientos que 10 de 1000, 15 de 666 o 20 de 500. Sin embargo, la influencia de la varianza intercluster es diferente según el diseño que se seleccione. Por otro lado, dado que se trata de una población de algo más de 3000 establecimientos el impacto del fpc (#emph[finite population correction]) en la primera etapa cambia fuertemente en función de que se elijan 500, 1000 o 2000 establecimientos.

- ¿Se tiene que seleccionar una cantidad fija de estudiantes para todos los establecimientos seleccionados en la primera etapa? Es claro que si nos alejamos de una misma cantidad de estudiantes por establecimiento seleccionado nos alejamos de unos de los beneficios de un muestreo PPS que es la posibilidad de una muestra autoponderada. Dado que algunos dominios de estimación implican un tratamiento censal, es claro que de todas formas para el momento de los análisis se iban a utilizar algunos ponderadores (como algo diferente a los expansores). La duda es ¿Cuánto usar este tipo de mecanismos en las demás situaciones en donde se pensaba hacer una muestra (más que un censo)?

- Por último, entre las especificaciones se indicaba que se debía hacer un muestreo sistemático luego de haber ordenado por la variable IVSE. Claramente, esto parece más un consejo de medios más que de fines, pero invita a pensar el porqué de esa decisión y esto, a su turno, puede aydar a entender algún fin latente. Esta estrategia suele denominarise "estratificación implícita", ya que esa ordenación con la selección posterior sistemática es una manera simple de generar "estratos" como resultado partiendo, o al menos usando en algún momento de su construcción, una variable continua \(Cochran, 1977, pág. 205; Valliant et~al., 2018, pág. 63).

Dada una respuesta clara para las preguntas anteriores, no suele ser un mayor problema a CUALES establecimientos se debe selecionar. Sin embargo, es difícil anticipar una rápida respuesta a estas preguntas porque los niveles de precision finalmente alcanzados por la muestra varían en función de la #emph[efectiva] varianza entre los establecimientos. Aclaramos lo de #emph[efectiva] porque y eso implica no usar un cálculo #emph[DEFF,] sino más bien simular muestras específicas sintéticas. Que se prefiera de forma sinere una muestra de 1000 establecimientos y 5 estudiantes por cada uno o si prefiere una de 5000 establecimientos y 10 estudiantes por cada uno u otra de 1000 estudiantes y 10 estudiantes por cada uno.

Hay diferentes medios disponibles. Si se enfatiza en maximizar los variados dominios de estimación provistos se resienteen los totales. En general cuanta mayor dispersión existe entre los ponderadores menor seguridad en las estiamcion de los totales.

Los estudiantes pueden pertenecer a los siguientes #strong[tipos de establecimientos]:

- Nivel Primario. Se incluyen solo a los EPA. Se excluyen a los centros de alfabetización y a los CEPA.

- Nivel Secundario de oferta institucional. Estos pueden ser CENS o SEBAS.

- Nivel Secundario por fuera de la oferta institucional. Son los establecimientos FINES.

El tamaño de una muestra no suele ser algo fácil de responder en un diseño con múltiples objetivos y estimadores \(Valliant et~al., 2018, pág. 26). Una situación similar es cuando no se sabe bien para qué finalmente se va a usar la muestra, pero no se duda que diferentes investigadores van a intentar contestar diversas preguntas de investigación con ella. Esto último es una de las razones por las cuales muchas veces es preferible expresar los objetivos estadísticos en términos de un coeficiente de variación (#emph[CV]). Este es adimensional (no posee unidades) y puede usarse para comparar la relativa precisión de las estimaciones de diferentes tipos de cantidades o variables \(Valliant et~al., 2018, pág. 27). En otras palabras, nos permite comparar la precisión de las categorías de las variables discretas (como las categorías de género) con variables cuantitativas continuas (como la edad promedio).

Las principales agencias oficiales de estadística (como el INDEC en Argentina, INEGI en México o Eurostat) suelen evaluar la calidad y la factibilidad de publicación de sus estimaciones a partir de los límites de sus $C V$: un $C V lt.eq 10 %$ se cataloga como una estimación de excelente precisión, mientras que estimaciones con un $C V > 20 %$ se consideran no publicables por su alta variabilidad.

Muchas veces suele solicitarse un determinado #strong[Margen de Error absoluto] ($M d E$), asumiendo un escenario de máxima varianza para una proporción teórica ($p = 50 %$). Sin embargo, en comparación con el CV presenta #strong[el peligro del error absoluto en proporciones pequeñas.] Si fijamos un margen de error absoluto del $3 %$ (0,03) para medir un fenómeno de alta prevalencia en torno al $50 %$, el intervalo resultante ($47 % - 53 %$) es sumamente preciso. Pero si queremos estimar un fenómeno de baja prevalencia (por ejemplo, estudiantes de la modalidad con alguna condición socioeducativa o de salud particular que represente un $5 %$), un margen absoluto del $3 %$ nos daría un intervalo de estimación de $\[ 2 % \, 8 % \]$. En esos casos, el #strong[error relativo] aumenta a niveles que suele afectar severamente la utilidad de esas estimaciones. Al fijar un objetivo de $C V$, el error estándar se evalúa siempre en términos relativos ($C V = S E \( hat(p) \) \/ p$), lo que garantiza que la calidad y precisión de la estimación sea robusta tanto para proporciones mayoritarias como para minoritarias.

=== Traducción de Margen de Error a Coeficiente de Variación
<traducción-de-margen-de-error-a-coeficiente-de-variación>
Para ser consistente tanto con el pedido de precisión original (Nivel de confianza del $90 %$, $p = 50 %$ y márgenes de error de $3 %$, $4 %$ y $5 %$) como con el supuesto de la superioridad de los CV, podemos establecer la siguiente equivalencia teórica.

El margen de error absoluto se relaciona con el error estándar de la siguiente manera:

$M O E = e = z_(1 - alpha \/ 2) dot.op S E \( hat(p) \)$

y, por otro lado, el CV es:

$C V = frac(S E, M e d i a)$

bajo un diseño de máxima varianza donde $p = 0 \, 5$ y un nivel de confianza del $90 %$ (con un valor crítico $z_(0 \, 95) approx 1 \, 645$), la relación matemática para el $C V$ es:

#math.equation(block: true, numbering: equation-numbering, [ $ C V \( hat(p) \) = frac(S E \( hat(p) \), p) = frac(M O E, p dot.op z_(1 - alpha \/ 2)) = frac(M O E, 0 \, 5 dot.op 1 \, 645) approx frac(M O E, 0 \, 8225) $ ])<eq-margen-cv>

#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 12pt); table(
  columns: 3,
  align: (left,right,right,),
  table.header(table.cell(align: center, colspan: 3, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); Equivalencia de Objetivos de Precisión],
    table.cell(align: center, colspan: 3, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Conversión de Margen de Error Absoluto a Coeficiente de Variación (90% Confianza, p=50%)],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Dominio de Estimación], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Margen de Error (MOE)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); CV Objetivo],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[TE/Área], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.0%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.65%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[TE/Región], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.0%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.86%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[TE/Región agrup.], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.0%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6.08%],
)}
], caption: figure.caption(
position: top, 
[
Traducción de MOE a CV
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-traduccion_moe_cv>


=== Cálculo del DEFF y del ESS
<cálculo-del-deff-y-del-ess>
La existencia de #emph[clusters] o conglomerados espaciales permite reducir los costos logísticos tanto en términos de transporte (especialmente en diseños presenciales) y reduce el costo de elaborar listas de direcciones/contactos de las unidades de selección finales (especialmente en diseños polietápicos). Mediante la combinación de ambos mecansmos, se reduce el costo unitario de realizar encuestas. A cambio, suele generar mayores varianzas para un tamaño de muestra determinado en comparación con una muestra de azar simple \(Valliant et~al., 2018, pág. 4).

Dos medidas sencillas, pero extremadamente útiles para expresar el efecto de usar #emph[clusters] o conglomerados en las estimaciones de la encuesta, son el #strong[efecto del diseño] (#emph[deff o design effect]) y el #strong[tamaño efectivo de la muestra] (#emph[ess o effective size sample]) \(Kish, 1965).

Con base en la estrategia anterior de convertir los márgenes de error (#emph[MdE]) en coeficientes de variación (#emph[CV]), ahora vamos a pasar a modelar el efecto del diseño ($D E F F$) a partir de diferentes supuestos y escenarios. Esto tendrá una función más pedagógica que instrumental en el diseño de la muestra. La razón es que el $D E F F$ es #strong[específico para cada estimador] que se quiera calcular por lo que, salvo que se quiera realizar un diseño complejo para estimar una sola variable, desde un punto de vista estrictamente estadístico, se deberían calcular un $D E F F$ para cada estimación. Cuando decimos específico queremos decir que su valor es variable para diferentes estimadores dentro de un mismo diseño muestral. En este caso, podría haber un #emph[DEFF] para la matrícula y un DEFF diferente para el índice de vulnerabilidad territorial. Otro punto negativo del #emph[DEFF] es que no siempre es relevante en muestras en donde las varianzas difieren a través de los estratos, en donde los subgrupos son seleccionados intencionalmente a diferentes porcentajes o donde diferentes subgrupos poseen diferentes tasas de respuesta \(Zipf & Valliant, s.~f.).

Dicho estos puntos negativos sobre el #emph[DEFF], cable aclarar que se trata de un concepto muy intuitivo para captar que se pierde y que se gana con un diseño polietápido (versus un aleatorio simple), pero también sirve para comparar entre diferentes diseños polietápicos. Gracias a él, se entiende cuanto se gana en la #strong[estratificación] cuando los elementos de cada estrato son homogéneos dentro de cada estrato, pero diferente entre estratos \(Kish, 1965, pág. 76). Del mismo modo, también es intuitivo para comprender que a mayor homogeneidad dentro de un #strong[cluster o conglomerado] mayor aumento del #emph[DEFF] dado que los casos llegan a su saturación teórica más rápidamente. En otras palabras, se llega más rápido a la situación en donde cada nuevo caso marginal aporta información cada menos nueva y cada vez más redundante. Por esta razón, si se asume que los #emph[cluster] son muy homogéneos en su interior, no es buena idea seleccionar muchos casos en cada uno de ellos, porque rápidamente parte de ellos se repetiran y comenzaran a aportar información redundante. De la misma manera, en una muestra polietápica por timbreo, y a igualdad de cantidad de casos totales, la precisión de las estimaciones mejora si se usan más puntos muestras con menos personas en cada uno de ellos.

Expresado de modo alternativo, el #emph[DEFF] permite comprender los pros y contras de jugar el juego de cuantos casos más baratos (por estar más juntos espacialmente) estoy dispuesto a agregar para compensar, casi con seguridad, su peor eficiencia estadística (por ser más homogéneos entre sí). Lo anterior se complementa con cuanto se mejora por la estratificación. En este contexto, el #emph[DEFF] permite optimizar el tipo de diseño polietápico a seguir.

La definición típica del #emph[DEFF], debido a su creador Leslie Kish, es que el mismo es la razón de la varianza de un estimador en una muestra compleja sobre la varianza de ese mismo estimador en una muestra de muestreo simple \(Kish, 1965, pág. 75). Una vez calculado el DEFF, es posible calcular el ESS. Este significa a cuántas personas de un muestreo aleatorio simple (perfecto e ideal) equivale realmente tu muestra actual realizada con un diseño complejo. Este es útil, entre otras razones, porque los cálculos necesarios para una muestra aleatoria simple son relativamente fáciles de construir.

=== El Efecto del Diseño (#emph[deff]) y la Correlación Intracluster ($rho$)
<el-efecto-del-diseño-deff-y-la-correlación-intracluster-rho>
Como se ha analizado en la sección anterior, si los #emph[clusters] (acá establecimientos) son muy homogéneos en su interior, no tiene sentido seleccionar muchos estudiantes por establecimiento porque nos aportarán información redundante. Esta homogeneidad interna se modela formalmente mediante la #strong[Correlación Intracluster] ($rho$ o #emph[ICC]) \(Lumley, 2010, pág. 51):

- #strong[Si] $rho = 0$: Los estudiantes dentro de una misma escuela son tan heterogéneos como si los hubiéramos seleccionado al azar en toda la provincia. No hay "efecto de pertenencia escolar". Cada encuesta adicional nos aporta mucha información nueva.
- #strong[Si] $rho = 1$: Todos los estudiantes de una escuela son idénticos. Ir a encuestar al segundo, tercero o quinto estudiante de la misma escuela no nos aporta nada de información nueva.

En encuestas socioeducativas de perfil estudiantil en América Latina, el valor empírico de $rho$ suele oscilar entre $0 \, 02$ y $0 \, 10$ \(Valliant et~al., 2018, pág. 247; Grosh & Muñoz, 1996, pág. 58-59). Para nuestro diseño, utilizaremos un valor de $rho = 0 \, 1$, el cual representa una hipótesis conservadora, pero sumamente realista que nos protege de subestimar el error muestral.

Para estimar formalmente este incremento en la varianza (el $d e f f$), utilizamos la ecuación clásica de Kish:

$ d e f f = 1 + \( b - 1 \) rho $

Donde $b$ representa el tamaño del cluster. En este caso sería la cantidad de estudiantes seleccionados por escuela.

=== Rediseño de la segunda etapa para garantizar la autoponderación y reducir el #emph[DEFF]
<rediseño-de-la-segunda-etapa-para-garantizar-la-autoponderación-y-reducir-el-deff>
El requerimiento sugería relevar #strong[todas las secciones] de cada escuela seleccionada. A pesar de que en este tipo de establecimientos parece haber pocos con muchas secciones (#ref(<fig-comparacion>, supplement: [Figura])), esto puede generar que el número de estudiantes encuestados por escuela variara drásticamente. Esto tendría el efecto de afectar la preciada #strong[autoponderación] de una muestra PPS, creando la necesidad tanto de construir ponderadores como de utilizarlos al momento del análisis. Por otro lado, incrementaría el tamaño medio de los estudiantes por cada cluster/establecimiento aumentado el parámetro ($b$) y, de ese modo, también aumentando el $d e f f$ y requiriendo un tamaño de muestra total mayor.

Para solucionar esto, se propone rediseñar la segunda etapa del muestreo de la siguiente manera:

\1. En cada escuela seleccionada en la primera etapa, #strong[se sortea de manera estrictamente aleatoria una única (1) sección] (con probabilidad $1 \/ B_i$, donde $B_i$ es la cantidad de secciones de la sede $i$).

\2. Dentro de esa sección sorteada, #strong[se seleccionan exactamente 5 estudiantes] ($b = 5$).

Al mantener el tamaño de cluster fijo y constante en $b = 5$ estudiantes para todas las escuelas, se logran dos ventajas metodológicas:

- Se #strong[garantiza una muestra estrictamente autoponderada.] La razón es queal multiplicar la probabilidad de la primera etapa (PPS proporcional a la matrícula) con el sorteo de una sección en la segunda etapa ($1 \/ B_i$), la probabilidad final de selección del estudiante se vuelve constante. Podremos analizar los datos directamente sin necesidad de ponderadores complejos.

- #strong[Minimizamos el Efecto del Diseño:] Al reducir el cluster a solo 5 alumnos, el $d e f f$ se reduce drásticamente: $ d e f f = 1 + \( 5 - 1 \) dot.op 0 \, 1 = 1 + 4 dot.op 0 \, 1 = 1 \, 4 $

Un $d e f f$ de $1 \, 4$ significa que se necesitan un $40 %$ más de casos que un muestreo aleatorio simple, reduciendo el tamaño de muestra total necesario en campo en comparación con el supuesto inicial de $d e f f = 2 \, 0$.

=== Simulación del impacto de la Correlación Intracluster ($rho$) y el tamaño del cluster ($b$)
<simulación-del-impacto-de-la-correlación-intracluster-rho-y-el-tamaño-del-cluster-b>
Para comprender de manera intuitiva y didáctica cómo interactúan el tamaño del cluster por escuela ($b$) y la homogeneidad de las instituciones ($rho$), se realiza una simulación que calcula el $d e f f$ y evalúa el tamaño de muestra teórico final requerido bajo escenarios alternativos de diseño para estimar una proporción con $C V = 3 \, 65 %$ que era la estipulada para el cruce tipo de establecimiento y área (#ref(<tbl-traduccion_moe_cv>, supplement: [Tabla])).

#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol")); table(
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

== Diseño muestra
<sec-diseno_muestra_adultos>
Teniendo en mente, por un lado, la distribución poblacional, esto es, la distribución del marco muestral y, por otro lado, los objetivos de estimación, es claro que, para algunos dominios de estimación no es una buena estrategia hacer una muestra al azar de toda la población. La razón es que algunos dominios de estimación implican pocos casos y estos tendrán pocas chances de estar incluidos en la muestra final. De manera derivada, #emph[ceteris paribus,] sus márgenes de error o sus coeficientes de variación, serán mayores a los aceptables en los objetivos. Esta situación también se expresaría a través de un muestreo estratitificado proporcional.

Por esta razón es esperable que esos dominios de estimación pequeños obtengan un trato diferencial en el proceso de selección para asegurar una cantidad mínima que permita realizar las inferencias con los niveles de precisión requeridos. Si se sigue dentro de las opciones de los diseños estratificados es posible pensar en alguna versión de asignación que óptimiza la reducción de la varianza total (p.e. a la Neyman \(Neyman, 1934)) y nos alejaríamos de una estratificación proporcional. También es posible pensar en un diseño basado en la asignación de potencia (#emph[power allocation]) \(Bankier, 1988). Algo más alejados, porque implicaría romper fuertemente con la lógica de los dominios de estimación antes presentados, sería usar estratos muestrales que surgan de un análisis multivariado previo para crear #emph[clusters] que minimicen la intra-varianza y maximicen la extra-varianza \(Dalenius, 1950; Dalenius & Hodges, 1957, 1959).

¿Cuáles son los pros y contras de este movimiento? Se recuerda que el contexto son:

- Múltiples dominios de estimación explícitos

- Algunos de ellos incluyen variables jerárquicas

- El uso y los estimadores a estimar todavía son desconocidos

La realización de un diseño estratificado no proporcional tiene el riesgo que su resultado es muy dependiente de cuál sea la variable objetivo \(Tillé, 2020, pág. 75). En contextos en donde exista más de una variable de interés (lo usual en muchas investigaciones sociales) y/o en casos en donde se presuma que determinada fuente primaria luego será utilizada como fuente secundaria por otros investigadores con objetivos que todavía se desconocen, se debe analizar los pros y contras de esta elección. Por ejemplo, algunos análisis estadísticos complejos (todavía) no permiten incorporar los valores de los ponderadores/expansores en sus cálculos.

Por otro lado, cuanto más estratos se construyan, más preciso será el estimador. Sin embargo, cabe advertir que un caso por cada estrato no es un buen diseño muestral \(Tillé, 2020, pág. 77). La razón de esto es que, usualmente, el estimador de la varianza se convierte cada vez más inestable como el número de estatos se acrecienta por la pérdida de grados de libertad derivada de la estimación de la media de los estratos.

Si se compararan 2 muestras. Ambas con la misma cantidad de casos. Ambas con un ponderador para cada caso.

Los dominios de estimación que parecen cumplir ese criterio son:

CEBAS

ECE-CENS

ECE-EPA

El objetivo de esta sección es ver cuanto de un diseño eficiente a nivel pobacional nos acerca a los objetivos de precisión de los dominios de estimación más intermedios como, por ejemplo:

CENS-AMBA

CENS-INTERIOR

EPA-AMBA

EPA-INTERIOR

Por poner un ejemplo si se logra obtener una muestra que se ajuste a los parámetros conocidos de los distritos, esta deberá acercarse también a las de las regiones, así como también a las regiones agrupadas y, en última instancia, a nivel de Gran Área. En cambio, el camino inverso está lejos de garantizarce. Por ejemplo podría ser que, por azar, los casos de AMBA se seleccionen todos dentro de La Matanza, o que los de INTERIOR se seleccionen mayoriamente dentro de Bahía Blanca o General Pueyerredón. Es claro que en estos casos, una buena muestra a nivel de Gran Área no asegura una buena muestra a niveles inferiores.

Salvo la excepción de las CEBAS, que por su baja cantidad de casos de forma necesaria se necesitará una encuesta casi censal, la situación parece diferente en los otros tipos de establecimientos. En este contexto, la duda es que tan lejos se está de lograr los objetivos de los dominios de estimación con sus niveles de precisión si se realiza una muestra que solo se preocupe por ser representativa del resto de los establecimientos educativos a nivel de las regiones agrupadas.

Para eso vamos a probar con una muestra balanceada y bien distribuida por el método del cubo. La idea de estos es que la muestra (de estudiantes y no de establecimientos) se acerque a los valores de tendencia central de esas variables. En otras palabras, que la muestra se encuentra #strong[balanceada] en un punto óptimo que reduzca las distancias con las diferentes medidas de #strong[tendencia central] de las variables anteriores.

Dado que algunas variables numéricas se encuentran disponibles como marco muestral para cada establecimeinto también se va a implementar una muestra #strong[bien distribuida]. En otras palabras, el objetivo es también exigir una convergencia con la #strong[distribución] (esto es, no solo con sus valores de tendencia central) de las siguientes variables:

== Construcción de ponderadores
<construcción-de-ponderadores>
== Testeo Muestra
<testeo-muestra>
Si se asume que los diferentes tipos de establecimientos son "Estratos" de la oferta, se podría pensar que se aspira a un margen de error de:

3% por estrato-Gran Área,

4% por estrato-región agrupada.

5% por estrato-región

Ahora voy probando los resultados de la muestra con la precisión esperada para cda dominio de estimación

==== CENSALES
<censales>
#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 9.75pt); table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,center,center,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[CEBAS] \
    N = 20], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[ECE-CENS] \
    N = 40], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[ECE-EPA] \
    N = 44],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula, Media ± DE], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[80 ± 51], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[255 ± 170], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[202 ± 128],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ivse, Media ± DE], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,28 ± 0,17], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,54 ± 0,20], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,54 ± 0,19],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[area, % (% (unweighted)) deff Design effect se SE(%) n], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~AMBA], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[60 (60) deff 43,8 se 0,087 12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[31 (31) deff 44,9 se 0,059 12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[28 (28) deff 45,0 se 0,054 12],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~INTERIOR], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[40 (40) deff 43,8 se 0,087 8], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[69 (69) deff 44,9 se 0,059 27], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[72 (72) deff 45,0 se 0,054 31],
)}
], caption: figure.caption(
position: top, 
[
Estimaciones para casos censales
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-analisis_censales>


==== GRAN ÁREA
<gran-área>
#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 9.75pt); table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,center,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[CENS] \
    N = 495], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[EPA] \
    N = 301],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula, Media ± DE], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[146 ± 107], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[109 ± 64],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ivse, Media ± DE], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,42 ± 0,21], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,45 ± 0,20],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[area, % (% (unweighted)) deff Design effect se SE(%) n], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~AMBA], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[54 (51) deff 2,82 se 0,022 268], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[54 (52) deff 2,28 se 0,031 163],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~INTERIOR], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[46 (49) deff 2,82 se 0,022 227], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[46 (48) deff 2,28 se 0,031 138],
)}
], caption: figure.caption(
position: top, 
[
Estimaciones para grandes áreas
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-analisis_gran_area>


==== REGION AGRUPADA
<region-agrupada>
#figure([
#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol") , size: 9.75pt); table(
  columns: (50%, 50%),
  align: (left,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Característica]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[FINES] \
    N = 2.312],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[matricula, Media ± DE], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[36 ± 34],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ivse, Media ± DE], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0,51 ± 0,22],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[region\_agrupada, % (% (unweighted)) deff Design effect se SE(%) n], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~01], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,6 (6,2) deff 1,68 se 0,014 198],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~02], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,2 (5,0) deff 1,94 se 0,014 189],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~03], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12 (8,0) deff 1,75 se 0,016 282],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~04], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8,1 (6,2) deff 1,57 se 0,013 187],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~05], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9,6 (10) deff 1,26 se 0,013 222],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~06], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,9 (3,0) deff 1,15 se 0,007 68],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~07], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,0 (4,3) deff 1,07 se 0,008 92],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~08], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,9 (6,2) deff 1,21 se 0,010 136],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~09], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,1 (5,0) deff 1,24 se 0,009 118],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~10], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,7 (6,2) deff 1,01 se 0,009 132],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~11], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,6 (5,4) deff 1,13 se 0,008 106],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~12], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,3 (3,7) deff 0,741 se 0,005 53],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~13], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,9 (3,7) deff 0,554 se 0,004 44],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~14], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,8 (4,1) deff 0,455 se 0,003 42],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~15-17-24-25], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,3 (3,9) deff 2,22 se 0,013 121],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~16-21-22-23], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4,4 (3,4) deff 1,79 se 0,010 102],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~18], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,0 (4,1) deff 0,625 se 0,004 46],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~19], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5,4 (6,9) deff 0,963 se 0,008 125],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~20], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,1 (4,3) deff 0,506 se 0,004 49],
)}
], caption: figure.caption(
position: top, 
[
Estimaciones para regiones agrupadas
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-analisis_region_agrupada>


Ahora vamos a empezar a evaluar a los valores de la muestra con respecto a los valores de la población. En una primera instancia esto lo haremos con los valores sin ponderar y luego lo haremos con valores ponderados. La razón de esta distinción es que, en principio, una de las fortalezas del diseño elegido es que la media de los valores de los ponderadores sería menor a la media de los valores de esos ponderadores si se hubiera seleccionado algún diseño muestral estratificado no proporcional.

Ahora hacemos lo mismo pero a nivel de región agregada. Esperablemente, una buena distribución a nivel de distritos debería producir una todavía más aceptable distribución a nivel de regiones agregadas.

Ahora vamos a testear la distribución (y no solo sus valores centrales) de la variable IVSE. Esta variable es particularmente importante porque es la variable índice que aspira incluir en la muestra una serie de desigualdades sociales que, de otra forma, se colarían por detrás afectando la utilidad de la misma para diferentes usos.

#figure([
#box(image("muestra_adultos_files/figure-typst/fig-densidad_ivse_poblacion_muestra-1.svg"))
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
<fig-densidad_ivse_poblacion_muestra>


Basándonos en los datos de la figura #ref(<fig-densidad_ivse_poblacion_muestra>, supplement: [Figura]), ahora vamos a testear estadísticamente si la diferencia entre ambas distribuciones es significativa.

#block[
#block[
#Skylighting(([],
[#NormalTok("    Asymptotic two-sample Kolmogorov-Smirnov test");],
[],
[#NormalTok("data:  df_insumo_cubo$ivse[df_insumo_cubo$muestra_adultos == 1] and df_insumo_cubo$ivse");],
[#NormalTok("D = 0.067557, p-value = 0.0006888");],
[#NormalTok("alternative hypothesis: two-sided");],));
]
]
Ahora vamos a realizar la misma operación pero a nivel de cada región agregada.

#figure([
#box(image("muestra_adultos_files/figure-typst/fig-densidad_ivse_poblacion_muestra_regiones-1.svg"))
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
<fig-densidad_ivse_poblacion_muestra_regiones>


#{set text(font: ("Segoe UI", "Roboto", "Arial", "sans-serif", "Segoe UI Emoji", "Segoe UI Symbol")); table(
  columns: 6,
  align: (left,right,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 6, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); Comparativa de Estadísticas: Población vs. Muestra],
    table.cell(align: center, colspan: 6, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Medias, Coeficientes de Variación y Proporciones para Variables Clave],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Grupo], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Media IVSE], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); CV IVSE], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Prop. Ámbito Urbano], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Prop. Ámbito Rural], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Prop. Tipo Est. Adulto],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Población], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.4890562], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.4505759], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9891000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Muestra], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.4567435], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.4654779], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.9791667], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0],
)}
#show: appendices.with("Anexos", hide-parent: true)
#heading(level: 1, numbering: none)[Anexos]
= Referencias Bibliográficas
<referencias-bibliográficas>
#block[
#block[
Baker, R., Brick, M., Bates, N., Battaglia, M., Couper, M., Dever, J., Gile, K., & Tourangeau, R. (2013). #emph[Report of the AAPOR task force on non-probability sampling].

] <ref-baker2013>
#block[
Bankier, M. (1988). Power Allocation. Determining sample sizes for subnational areas. #emph[The American Statistician], #emph[42]\(3), 174-177.

] <ref-bankier1988>
#block[
Brus, D. (2022). #emph[Spatial sampling with R]. Chapman & Hall /CRC.

] <ref-brus2022>
#block[
Bunge, M. (1974). #emph[Semantics]. Dordrecht. Reidel.

] <ref-bunge1974a>
#block[
Campbell, D., & Stanley, J. (1963). #emph[Experimental and quasi-experimental designs for research]. Houghton Mifflin Company.

] <ref-campbell1963>
#block[
Cochran, W. (1977). #emph[Sampling techniques]. John Wiley & Sons.

] <ref-cochran1977>
#block[
Dalenius, T. (1950). The problem of optimum stratification. #emph[Skandinavisk Aktuarietidskrift], #emph[33], 203-213.

] <ref-dalenius1950>
#block[
Dalenius, T., & Hodges, J. (1957). The choice of stratification points. #emph[Skandinavisk Aktuarietidskrift], (40), 198-203.

] <ref-dalenius1957>
#block[
Dalenius, T., & Hodges, J. (1959). Minimum variance stratification. #emph[Journal of the American Statistical Association], (54).

] <ref-dalenius1959>
#block[
Deville, J., & Tillé, Y. (2004). Efficient balanced sampling: The cube method. #emph[Biometrika], #emph[91]\(4), 893-912.

] <ref-deville2004>
#block[
Elliott, M., & Valliant, R. (2017). Inference for nonprobability samples. #emph[Statistical Science], #emph[32]\(2), 249-264.

] <ref-elliott2017>
#block[
Everitt, B., Landau, S., Leese, M., & Stahl, D. (2011). #emph[Cluster Analysis] (5 Edition). Wiley.

] <ref-everitt2011>
#block[
Fienberg, S., & Tanur, J. (1988). From the inside out and the outside in: Combining experimental and sampling structures. #emph[The Canadian Journal of Statistics], #emph[16]\(2), 135-151.

] <ref-fienberg1988>
#block[
Gigerenzer, G., Swijtink, Z., Porter, T., Beatty, J., & Krüger, L. (1997). #emph[The empire of chance]. Cambridge University Press.

] <ref-gigerenzer1997>
#block[
Grosh, M., & Muñoz, J. (1996). #emph[A Manual for Planning and Implementing the Living Standards Measurement Study Survey]. The World Bank.

] <ref-grosh1996>
#block[
Hacking, I. (2004). #emph[The taming of chance]. Cambridge University Press. (Obra original publicada en 1990)

] <ref-hacking2004>
#block[
Hacking, I. (2006). #emph[The emergence of probability: A philosophical study of early ideas about probability, induction and statistical inference]. Cambridge University Press.

] <ref-hacking2006>
#block[
Hedlin, D. (2015). #emph[Why are design in survey sampling ad design of randomised experiments separate areas of statistical science?]

] <ref-hedlin2015>
#block[
Kish, L. (1965). #emph[Survey Sampling]. John Wiley & Sons.

] <ref-kish1965>
#block[
Kish, L. (1980). Design and estimations for domains. #emph[The Statistician], #emph[29]\(4), 209-222.

] <ref-kish1980>
#block[
Kish, L. (1987). #emph[Statistical design for research]. John Wiley.

] <ref-kish1987>
#block[
Klima, G. (2022). #emph[The medieval problem of universals] (E. Zalta, Ed.; Spring 2022). Stanford University.

] <ref-klima2022>
#block[
Lumley, T. (2010). #emph[Complex surveys. A guide to analysis using R]. John Wiley & Sons.

] <ref-lumley2010>
#block[
Lundström, S., & Särndal, C. E. (2009). #emph[Calibration of weights in surveys with nonresponse and frame imperfections].

] <ref-lundström2009>
#block[
Morgan, S., & Winship, C. (2015). #emph[Counterfactuals and Causal Inference] (Second Edition). Cambridge University Press.

] <ref-morgan2015>
#block[
Neyman, J. (1934). On the Two Different Aspects of the Representative Method: The Method of Stratified Sampling and the Method of Purposive Selection. #emph[Journal of the Royal Statistical Society], #emph[97]\(4), 558-625.

] <ref-neyman1934>
#block[
Pearl, J. (2018). #emph[The book of why]. New York. Basic Books.

] <ref-pearl2018a>
#block[
Platón. (2002 \[370AVC\]). #emph[Phaedrus]. Oxford University Press.

] <ref-platón2002>
#block[
Schneider, B. (2024). #emph[Simulation-based variance estimation for the cube method]. #link("https://www.practicalsignificance.com/posts/cube-method-simulating-joint-probs/")

] <ref-schneider2024>
#block[
Small, M., & Adler, L. (2019). The role os space in the formation of social ties. #emph[Anual Review of Sociology], #emph[45], 111-132.

] <ref-small2019>
#block[
Subsecretaría, de planeamiento. (2024). #emph[PRUEBAS ESCOLARES BONAERENSES EN EL NIVEL PRIMARIO Resultados de Matemática y de Prácticas del Lenguaje en 3°, 5° y 6°].

] <ref-subsecretaría2024>
#block[
Subsecretaría, de planeamiento. (2025). #emph[Qué son las pruebas escolares bonaerenses? Evaluación formativa para la mejora de la enseñanza y de los aprendizajes]. Subsecretaría de Planeamiento, Dirección Provincial de Evaluación e Investigación.

] <ref-subsecretaría2025>
#block[
Tillé, Y. (2010). #emph[Balanced sampling by means of the cube method].

] <ref-tillé2010>
#block[
Tillé, Y. (2011). Ten years of balanced sampling with the cube method: An appraisal. #emph[Survey Methodology], #emph[37]\(2), 215-226.

] <ref-tillé2011>
#block[
Tillé, Y. (2020). #emph[Sampling and estimation from finite populations]. John Wiley & Sons.

] <ref-tillé2020>
#block[
Tillé, Y., & Grafström, A. (2013). Doubly balanced spatial sampling with spreading and restitution of auxiliary totals. #emph[Environmetrics], #emph[24]\(2), 120-131.

] <ref-tillé2013>
#block[
Tillé, Y., & Matei, A. (2023). #emph[Package \"sampling\"].

] <ref-tillé2023>
#block[
Valliant, R., Dever, J., & Kreuter, F. (2018). #emph[Practical Tools for Designing and Weighting Survey Samples] (Second Edition). Springer.

] <ref-valliant2018>
#block[
Zipf, G., & Valliant, R. (s.~f.). #emph[Design Effects and Effective Sample Size].

] <ref-zipf>
] <refs>



