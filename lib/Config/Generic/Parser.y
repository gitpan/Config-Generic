# -*- generic -*-
# Grammatikdefinition für die Konfigurationsdatei
# Compile with perl -MParse::RecDescent - Parser.y Config::Generic::Parser 

{
use Config::Generic::Directive;
use Config::Generic::NamedSection;
use Config::Generic::UnnamedSection;
}

# Bezeichnung für Directiven und Sektionen
identifier:
            /[a-zA-Z][a-zA-Z0-9_-]*/

# Bezeichnung für Argumente und Sektionsnamen
argument:
            <perl_quotelike>
            { if($item[1]->[1] eq "\"") {
                  $return = $item[1]->[2];
              } else {
                  undef;
              }
            }

          | /[^\s,<>]+/

# Argumentliste
argumentlist:
            <leftop:argument "," argument>  { $return = $item[1]; } <score: -@{$item[1]}>
          | argument(s)                     { $return = $item[1]; } <score: -@{$item[1]}>
            
# Direktive mit ein oder mehreren Argumenten
directive:
            identifier ('=')(?) argumentlist
            { $return = new Config::Generic::Directive($item{identifier}, $item[3],
                                      $thisline); }


# Unbenannte Sektion
unnamed_section:
            <rulevar: $startline>
          | "<" identifier ">" <commit> { $startline=$thisline; } "\n" 
            element(s)
            "<" "/" "$item{identifier}" ">" 
            { $return = new Config::Generic::UnnamedSection($item{identifier}, $item[7],
                                                            $startline); }
          | <error?> <reject>

# Benannte Sektion
named_section:
            <rulevar: $startline>
          | "<" identifier argument <commit> ">" { $startline=$thisline; } "\n" 
            element(s)
            "<" "/" "$item{identifier}" ">" 
            { $return = new Config::Generic::NamedSection($item{identifier}, $item{argument},
                                                      $item[8], $startline); }
          | <error?> <reject>

# Ein Konfigurationselement
element:
            ("\n")(s) { $return = undef; 1; }
          | "#" <commit> <resync> ("\n")(s) { $return = undef; 1;}
          | directive ("\n")(s)
            { $return = $item{directive}; }
          | unnamed_section ("\n")(s)
            { $return = $item{unnamed_section}; }
          | named_section ("\n")(s)
            { $return = $item{named_section}; }
          | <error>


# Die gesamte Konfigurationsdatei
startrule: <skip:'[ \t]*'> element(s) eofile
           { $return = new Config::Generic::UnnamedSection("__root__", $item[2],
                                                        0); }
eofile: /^\Z/
