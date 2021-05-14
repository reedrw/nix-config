let

  attrs = ( x: builtins.removeAttrs x [ "__functor" ] );

in (sources: builtins.map (key: builtins.getAttr key (attrs sources) ) (builtins.attrNames (attrs sources) ) )
