" MergeWithRegister/Indent.vim: Merge text without common indent.
"
" DEPENDENCIES:
"
" Copyright: (C) 2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! MergeWithRegister#Indent#Encode( context, contextKey ) abort
    if a:contextKey ==# 'text' && &l:filetype == a:context.filetype
	" Apply the original buffer's indent settings to the text scratch
	" buffer, if it still has the same filetype. The original buffer may
	" have had manually overridden indent settings.
	for l:indentSetting in keys(a:context.originalIndentSettings)
	    execute printf('let &l:%s = a:context.originalIndentSettings[l:indentSetting]', l:indentSetting)
	endfor
    endif

    let l:indentLevel = ingo#indent#GetIndentLevel(1)
    let a:context[a:contextKey].indentLevel = l:indentLevel
    call ingo#indent#RangeSeveralTimes(1, line('$'), '<', l:indentLevel)
endfunction

function! MergeWithRegister#Indent#Decode( context, contextKey ) abort
    let l:indentLevel = a:context[a:contextKey].indentLevel
    call ingo#indent#RangeSeveralTimes(1, line('$'), '>', l:indentLevel)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
