# Swapping Between Header and Source Files

This plugin allows for quickly swapping between header and source files.  It
is intended to be used for languages like C or C++. It might work for other
languages having a similar structure too, since you can specify custom
patterns to swap between files.

## Example

With the default swap patterns

```
let g:swapc_patterns = [
 \ [ '#{prefix}/src/#{sub}/${file}.?{cc,c,cpp,cxx,C}', 
 \   '#{prefix}/include/#{sub}/${file}.?{hh,h,hpp,hxx,H}' ] ]
```

one can switch between files

```
some/prefix/src/some/folders/file.h
some/prefix/include/some/folders/file.c
```

using shortcut `<Leader>6`.
