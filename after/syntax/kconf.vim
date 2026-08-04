" Vim syntax file for Kconfig fragment files such as prj.conf.

if exists("b:current_syntax")
  finish
endif

syn case match

syn match kconfComment "#.*$" contains=@Spell
syn match kconfKey "^\s*\zs\%(CONFIG_\)\=\w\+\ze\s*="
syn match kconfOperator "="
syn region kconfString start=+"+ skip=+\\"+ end=+"+
syn match kconfNumber "\<\%(0x\x\+\|\d\+\)\>"
syn keyword kconfBoolean y n m

hi def link kconfComment Comment
hi def link kconfKey Identifier
hi def link kconfOperator Operator
hi def link kconfString String
hi def link kconfNumber Number
hi def link kconfBoolean Boolean

let b:current_syntax = "kconf"
