" MergeWithRegister/Indent.vim: Merge text without common indent.
"
" DEPENDENCIES:
"
" Copyright: (C) 2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! MergeWithRegister#Indent#Encode( context, contextKey ) abort
    let l:indentLevel = ingo#indent#GetIndentLevel(1)
    let a:context[a:contextKey].indentLevel = l:indentLevel
    call ingo#indent#RangeSeveralTimes(1, line('$'), '<', l:indentLevel)
endfunction

function! MergeWithRegister#Indent#Decode( context, contextKey ) abort
    let l:indentLevel = a:context[a:contextKey].indentLevel
    call ingo#indent#RangeSeveralTimes(1, line('$'), '>', l:indentLevel)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
