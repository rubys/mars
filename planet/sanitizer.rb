module Planet::Sanitizer

# This module provides sanitization of XHTML+MathML+SVG
# and of inline style attributes.
#
# Snapshot of the constants from
# http://golem.ph.utexas.edu/~distler/code/instiki/svn/changes

  require 'set'

  acceptable_elements = Set.new %w[a abbr acronym address area article aside
      audio b big blockquote br button canvas caption center cite code
      col colgroup command datalist dd del details dfn dialog dir div dl dt
      em fieldset figcaption figure font footer form h1 h2 h3 h4 h5 h6 header
      hgroup hr i img input ins kbd label legend li map mark menu meter nav
      ol optgroup option p pre progress q rp rt ruby s samp section select small
      source span strike strong sub summary sup table tbody td textarea tfoot
      th thead time tr tt u ul var video wbr]
      
  mathml_elements = Set.new %w[annotation annotation-xml maction math menclose merror
      mfrac mfenced mi mmultiscripts mn mo mover mpadded mphantom mprescripts mroot
      mrow mspace msqrt mstyle msub msubsup msup mtable mtd mtext mtr munder
      munderover none semantics]
      
  svg_elements = Set.new %w[a animate animateColor animateMotion animateTransform
      circle clipPath defs desc ellipse feGaussianBlur filter font-face
      font-face-name font-face-src foreignObject g glyph hkern linearGradient
      line marker mask metadata missing-glyph mpath path pattern polygon
      polyline radialGradient rect set stop svg switch text textPath title tspan use]
      
  acceptable_attributes = Set.new %w[abbr accept accept-charset accesskey action
      align alt autocomplete axis bgcolor border cellpadding cellspacing char charoff
      checked cite class clear cols colspan color compact contenteditable contextmenu
      controls coords datetime dir disabled draggable enctype face for formaction frame
      headers height high href hreflang hspace icon id ismap label list lang longdesc
      loop low max maxlength media method min multiple name nohref noshade nowrap open
      optimumpattern placeholder poster preload pubdate radiogroup readonly rel
      required rev reversed rows rowspan rules spellcheck scope
      selected shape size span src start step style summary tabindex target title
      type usemap valign value vspace width wrap xml:lang]

  mathml_attributes = Set.new %w[actiontype align close
      columnalign columnlines columnspacing columnspan depth display
      displaystyle encoding equalcolumns equalrows fence fontstyle fontweight
      frame height linethickness lspace mathbackground mathcolor mathvariant
      maxsize minsize notation open other rowalign
      rowlines rowspacing rowspan rspace scriptlevel selection separator
      separators stretchy width xlink:href xlink:show xlink:type xmlns
      xmlns:xlink]

  svg_attributes = Set.new %w[accent-height accumulate additive alphabetic
       arabic-form ascent attributeName attributeType baseProfile bbox begin
       by calcMode cap-height class clip-path clip-rule color
       color-interpolation-filters color-rendering
       content cx cy d dx dy descent display dur end fill fill-opacity fill-rule
       filterRes filterUnits font-family font-size font-stretch font-style
       font-variant font-weight from fx fy g1 g2 glyph-name gradientUnits
       hanging height horiz-adv-x horiz-origin-x id ideographic k keyPoints
       keySplines keyTimes lang marker-end marker-mid marker-start
       markerHeight markerUnits markerWidth maskContentUnits maskUnits
       mathematical max method min name offset opacity orient origin
       overline-position overline-thickness panose-1 path pathLength
       patternContentUnits patternTransform patternUnits points
       preserveAspectRatio primitiveUnits r refX refY repeatCount repeatDur
       requiredExtensions requiredFeatures restart rotate rx ry se:connector
       se:nonce slope spacing
       startOffset stdDeviation stemh stemv stop-color stop-opacity
       strikethrough-position strikethrough-thickness stroke stroke-dasharray
       stroke-dashoffset stroke-linecap stroke-linejoin stroke-miterlimit
       stroke-opacity stroke-width systemLanguage target text-anchor
       to transform type u1 u2 underline-position underline-thickness
       unicode unicode-range units-per-em values version viewBox
       visibility width widths x x-height x1 x2 xlink:actuate
       xlink:arcrole xlink:href xlink:role xlink:show xlink:title xlink:type
       xml:base xml:lang xml:space xmlns xmlns:xlink xmlns:se y y1 y2 zoomAndPan]
       
  attr_val_is_uri = Set.new %w[href src cite action formaction longdesc xlink:href xml:base]
  
  svg_attr_val_allows_ref = Set.new %w[clip-path color-profile cursor fill
      filter marker marker-start marker-mid marker-end mask stroke]

  svg_allow_local_href = Set.new %w[altGlyph animate animateColor animateMotion
      animateTransform cursor feImage filter linearGradient pattern
      radialGradient textpath tref set use]
    
  acceptable_css_properties = Set.new %w[azimuth background-color
      border-bottom-color border-collapse border-color border-left-color
      border-right-color border-top-color clear color cursor direction
      display elevation float font font-family font-size font-style
      font-variant font-weight height letter-spacing line-height overflow
      pause pause-after pause-before pitch pitch-range richness speak
      speak-header speak-numeral speak-punctuation speech-rate stress
      text-align text-decoration text-indent unicode-bidi vertical-align
      voice-family volume white-space width]

  acceptable_css_keywords = Set.new %w[auto aqua black block blue bold both bottom
      brown center collapse dashed dotted fuchsia gray green !important
      italic left lime maroon medium none navy normal nowrap olive pointer
      purple red right solid silver teal top transparent underline white
      yellow]

  acceptable_svg_properties = Set.new %w[fill fill-opacity fill-rule stroke
      stroke-width stroke-linecap stroke-linejoin stroke-opacity]
      
  acceptable_protocols = Set.new %w[ed2k ftp http https irc mailto news gopher nntp
      telnet webcal xmpp callto feed urn aim rsync tag ssh sftp rtsp afs]
      
      SHORTHAND_CSS_PROPERTIES = Set.new %w[background border margin padding]
      VOID_ELEMENTS = Set.new %w[img br hr link meta area base basefont 
                    col frame input isindex param]

      ALLOWED_ELEMENTS = acceptable_elements + mathml_elements + svg_elements  unless defined?(ALLOWED_ELEMENTS)
      ALLOWED_ATTRIBUTES = acceptable_attributes + mathml_attributes + svg_attributes unless defined?(ALLOWED_ATTRIBUTES)
      ALLOWED_CSS_PROPERTIES = acceptable_css_properties unless defined?(ALLOWED_CSS_PROPERTIES)
      ALLOWED_CSS_KEYWORDS = acceptable_css_keywords unless defined?(ALLOWED_CSS_KEYWORDS)
      ALLOWED_SVG_PROPERTIES = acceptable_svg_properties unless defined?(ALLOWED_SVG_PROPERTIES)
      ALLOWED_PROTOCOLS = acceptable_protocols unless defined?(ALLOWED_PROTOCOLS)
      ATTR_VAL_IS_URI = attr_val_is_uri unless defined?(ATTR_VAL_IS_URI)
      SVG_ATTR_VAL_ALLOWS_REF = svg_attr_val_allows_ref unless defined?(SVG_ATTR_VAL_ALLOWS_REF)
      SVG_ALLOW_LOCAL_HREF = svg_allow_local_href unless defined?(SVG_ALLOW_LOCAL_HREF)

end
