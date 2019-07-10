" MergeWithRegister.vim: Merge text with the contents of a register.
"
" DEPENDENCIES:
"   - repeat.vim (vimscript #2136) autoload script (optional)
"   - visualrepeat.vim (vimscript #3848) autoload script (optional)
"   - visualrepeat/reapply.vim autoload script (optional)
"
" Copyright: (C) 2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"

function! MergeWithRegister#SetRegister()
    let s:register = v:register
endfunction
function! MergeWithRegister#SetCount()
    let s:count = v:count
endfunction
function! MergeWithRegister#IsExprReg()
    return (s:register ==# '=')
endfunction

function! s:CorrectForRegtype( type, register, regType, pasteText )
    if a:type ==# 'visual' && visualmode() ==# "\<C-v>" || a:type[0] ==# "\<C-v>"
	" Adaptations for blockwise replace.
	let l:pasteLnum = len(split(a:pasteText, "\n"))
	if a:regType ==# 'v' || a:regType ==# 'V' && l:pasteLnum == 1
	    " If the register contains just a single line, temporarily duplicate
	    " the line to match the height of the blockwise selection.
	    let l:height = line("'>") - line("'<") + 1
	    if l:height > 1
		call setreg(a:register, join(repeat(split(a:pasteText, "\n"), l:height), "\n"), "\<C-v>")
		return 1
	    endif
	elseif a:regType ==# 'V' && l:pasteLnum > 1
	    " If the register contains multiple lines, paste as blockwise.
	    call setreg(a:register, '', "a\<C-v>")
	    return 1
	endif
    elseif a:regType ==# 'V' && a:pasteText =~# '\n$'
	" Our custom operator is characterwise, even in the
	" MergeWithRegisterLine variant, in order to be able to replace less
	" than entire lines (i.e. characterwise yanks).
	" So there's a mismatch when the replacement text is a linewise yank,
	" and the replacement would put an additional newline to the end.
	" To fix that, we temporarily remove the trailing newline character from
	" the register contents and set the register type to characterwise yank.
	call setreg(a:register, strpart(a:pasteText, 0, len(a:pasteText) - 1), 'v')

	return 1
    endif

    return 0
endfunction
function! s:PreparePasteRegister( type, save_reg, save_regmode ) abort
    if s:register ==# '"'
	" The unnamed register has been used for retrieving the original text,
	" we need to restore it now.
	call setreg('"', a:save_reg, a:save_regmode)
	return s:register
    elseif s:register ==# '='
	" Cannot evaluate the expression register within a function; unscoped
	" variables do not refer to the global scope. Therefore, evaluation
	" happened earlier in the mappings.
	" To get the expression result into the buffer, we use the unnamed
	" register; this will be restored, anyway.
	call setreg('"', g:MergeWithRegister#expr)
	call s:CorrectForRegtype(a:type, '"', getregtype('"'), g:MergeWithRegister#expr)
	" Must not clean up the global temp variable to allow command
	" repetition.
	"unlet g:MergeWithRegister#expr
	return  '"'
    else
	return s:register
    endif
endfunction
function! s:MergeWithRegister( type )
    " With a put in visual mode, the selected text will be replaced with the
    " contents of the register. This works better than first deleting the
    " selection into the black-hole register and then doing the insert; as
    " "d" + "i/a" has issues at the end-of-the line (especially with blockwise
    " selections, where "v_o" can put the cursor at either end), and the "c"
    " commands has issues with multiple insertion on blockwise selection and
    " autoindenting.
    " With a put in visual mode, the previously selected text is put in the
    " unnamed register, so we need to save and restore that.
    let l:save_clipboard = &clipboard
    set clipboard= " Avoid clobbering the selection and clipboard registers.
    let l:save_reg = getreg('"')
    let l:save_regmode = getregtype('"')

    try
	if a:type ==# 'visual'
"****D echomsg '**** visual' string(getpos("'<")) string(getpos("'>"))
	    let l:previousLineNum = line("'>") - line("'<") + 1
	    if &selection ==# 'exclusive' && getpos("'<") == getpos("'>")
		if ! s:Merge('', s:PreparePasteRegister(a:type, l:save_reg, l:save_regmode)) | return | endif
		" In case of an empty selection, just paste before the cursor
		" position; reestablishing the empty selection would override
		" the current character, a peculiarity of how selections work.
		silent normal! P
	    else
		silent normal! gvy
		let l:text = @"
		if ! s:Merge(l:text, s:PreparePasteRegister(a:type, l:save_reg, l:save_regmode)) | return | endif
		silent normal! gvp
	    endif
	else
"****D echomsg '**** operator' string(getpos("'[")) string(getpos("']"))
	    let l:previousLineNum = line("']") - line("'[") + 1
	    if ingo#pos#IsOnOrAfter(getpos("'[")[1:2], getpos("']")[1:2])
		if ! s:Merge('', s:PreparePasteRegister(a:type, l:save_reg, l:save_regmode)) | return | endif
		silent normal! P
	    else
		" Note: Need to use an "inclusive" selection to make `] include
		" the last moved-over character.
		let l:save_selection = &selection
		set selection=inclusive
		try
		    execute 'silent normal! g`[' . (a:type ==# 'line' ? 'V' : 'v') . 'g`]y'
		    let l:text = @"
		    if ! s:Merge(l:text, s:PreparePasteRegister(a:type, l:save_reg, l:save_regmode)) | return | endif
		    execute 'silent normal! g`[' . (a:type ==# 'line' ? 'V' : 'v') . 'g`]p'
		finally
		    let &selection = l:save_selection
		endtry
	    endif
	endif

	let l:newLineNum = line("']") - line("'[") + 1
	if l:previousLineNum >= &report || l:newLineNum >= &report
	    echomsg printf('Replaced %d line%s', l:previousLineNum, (l:previousLineNum == 1 ? '' : 's')) .
	    \   (l:previousLineNum == l:newLineNum ? '' : printf(' with %d line%s', l:newLineNum, (l:newLineNum == 1 ? '' : 's')))
	endif
    finally
	call setreg('"', l:save_reg, l:save_regmode)
	let &clipboard = l:save_clipboard
    endtry
endfunction
function! MergeWithRegister#Operator( type, ... )
    let l:pasteText = getreg(s:register, 1) " Expression evaluation inside function context may cause errors, therefore get unevaluated expression when s:register ==# '='.
    let l:regType = getregtype(s:register)
    let l:isCorrected = s:CorrectForRegtype(a:type, s:register, l:regType, l:pasteText)
    try
	call s:MergeWithRegister(a:type)
    finally
	if l:isCorrected
	    " Undo the temporary change of the register.
	    " Note: This doesn't cause trouble for the read-only registers :, .,
	    " %, # and =, because their regtype is always 'v'.
	    call setreg(s:register, l:pasteText, l:regType)
	endif
    endtry

    if a:0
	if a:0 >= 2 && a:2
	    silent! call repeat#set(a:1, s:count)
	else
	    silent! call repeat#set(a:1)
	endif
    elseif s:register ==# '='
	" Employ repeat.vim to have the expression re-evaluated on repetition of
	" the operator-pending mapping.
	silent! call repeat#set("\<Plug>MergeWithRegisterExpressionSpecial")
    endif
    silent! call visualrepeat#set("\<Plug>MergeWithRegisterVisual")
endfunction
function! MergeWithRegister#OperatorExpression()
    call MergeWithRegister#SetRegister()
    set opfunc=MergeWithRegister#Operator

    let l:keys = 'g@'

    if ! &l:modifiable || &l:readonly
	" Probe for "Cannot make changes" error and readonly warning via a no-op
	" dummy modification.
	" In the case of a nomodifiable buffer, Vim will abort the normal mode
	" command chain, discard the g@, and thus not invoke the operatorfunc.
	let l:keys = ":call setline('.', getline('.'))\<CR>" . l:keys
    endif

    if v:register ==# '='
	" Must evaluate the expression register outside of a function.
	let l:keys = ":let g:MergeWithRegister#expr = getreg('=')\<CR>" . l:keys
    endif

    return l:keys
endfunction

function! MergeWithRegister#VisualMode()
    let l:keys = "1v\<Esc>"
    silent! let l:keys = visualrepeat#reapply#VisualMode(0)
    return l:keys
endfunction

function! s:Merge( text, register ) abort
    echomsg '****' string(a:text) '->' getreg(a:register)
    call setreg('"', getreg(a:register)[0:2] . a:text[0:2])
    call setreg(s:register, '[' . getreg(a:register) . ']')
    return 1
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
