// howtogit cover page (typst engine, recon --cover-template).
// recon injects metadata bindings before this template: title, subtitle,
// author, version, date (empty string if unset). The title lockup below is
// fixed (the "$ how to git" terminal-prompt brand); subtitle/version/date/
// author come from the --doc-* flags.
//
// NOTE: a bare `$` starts math mode in typst — the prompt dollar must be `\$`.

#align(center + horizon)[
  #text(34pt, font: "DejaVu Sans Mono", weight: "bold")[
    #text(fill: luma(138))[\$] how to #text(fill: rgb("#f05033"))[git]#box(fill: rgb("#f05033"), width: 0.5em, height: 0.95em, baseline: 15%)
  ]
  #v(1.4em)
  #text(17pt, fill: luma(60))[#subtitle]
  #v(1.6em)
  #line(length: 38%, stroke: 0.6pt + luma(170))
  #v(1.2em)
  #text(11pt, font: "DejaVu Sans Mono", fill: luma(90))[#version #h(1.5em) #date #h(1.5em) #author]
]
