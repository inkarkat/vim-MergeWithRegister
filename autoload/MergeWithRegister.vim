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
function! s:GetRegisterContents() abort
    return (s:register ==# '=' ? g:MergeWithRegister#expr : getreg(s:register))
endfunction
function! s:MergeWithRegister( type )
    if a:type ==# 'visual'
	let s:context = {
	\   'type': a:type,
	\   'previousLineNum': line("'>") - line("'<") + 1,
	\   'startPos': getpos("'<"),
	\   'endPos': getpos("'>"),
	\   'mode': visualmode(),
	\}

	if &selection ==# 'exclusive' && getpos("'<") == getpos("'>")
	    let s:context.text = ''
	else
	    let s:context.text = ingo#selection#Get()
	endif
    else
	let s:context = {
	\   'type': a:type,
	\   'previousLineNum': line("']") - line("'[") + 1,
	\   'startPos': getpos("'["),
	\   'endPos': getpos("']"),
	\   'mode': '',
	\}

	if ingo#pos#IsOnOrAfter(getpos("'[")[1:2], getpos("']")[1:2])
	    let s:context.text = ''
	else
	    " Note: Need to use an "inclusive" selection to make `] include
	    " the last moved-over character.
	    let l:save_selection = &selection
	    set selection=inclusive
	    try
		let s:context.text = ingo#register#KeepRegisterExecuteOrFunc(
		    \'execute "silent normal! g`[' . (a:type ==# 'line' ? 'V' : 'v') . 'g`]y" | return @"'
		\)
	    finally
		let &selection = l:save_selection
	    endtry
	endif
    endif

    call s:StartMerge()
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



function! s:StartMerge() abort
    let s:context.buffers = []
    let s:context.filetype = &l:filetype
    let s:context.winId = win_getid()   " TODO: Better impl
    let l:text = s:context.text
    let l:register = s:GetRegisterContents()
    let l:name = expand('%:t') | if empty(l:name) | let l:name = 'unnamed' | endif

    try
	call s:OpenScratch(1, g:MergeWithRegister_ScratchSplitCommand, l:name, s:context.text, function('MergeWithRegister#WriteText'))
	call s:OpenScratch(ingo#register#IsWritable(s:register), g:MergeWithRegister_SecondSplitCommand, 'register ' . s:register, s:GetRegisterContents(), function('MergeWithRegister#WriteRegister'))
	wincmd p
    catch /^MergeWithRegister:/
	call ingo#msg#CustomExceptionMsg('MergeWithRegister')
    endtry
endfunction
function! s:OpenScratch( isWritable, splitCommand, name, contents, Writer ) abort
    if ! (a:isWritable ?
    \   ingo#buffer#scratch#CreateWithWriter(a:name, a:Writer, split(a:contents, '\n', 1), a:splitCommand) :
    \   ingo#buffer#scratch#Create('', a:name, 0, split(a:contents, '\n', 1), a:splitCommand)
    \)
	throw 'MergeWithRegister: Failed to open scratch buffer for ' . a:name
    endif
    call add(s:context.buffers, bufnr(''))

    " Detect the filetype the contents, and fall back to the original buffer's
    " filetype.
    filetype detect
    if empty(&l:filetype) | let &l:filetype = s:context.filetype | endif

    if g:MergeWithRegister_UseDiff | setl diff | endif

    augroup MergeWithRegister
	autocmd! BufHidden,BufUnload <buffer> call MergeWithRegister#EndMerge()
    augroup END
endfunction

function! MergeWithRegister#WriteText() abort
    let l:lines = getline(1, line('$'))
    let s:context.result = join(l:lines, "\n")
    setlocal nomodified
    call s:Report(0, 'Replacing', len(l:lines), 'text')
endfunction
function! MergeWithRegister#WriteRegister() abort
    let l:lines = getline(1, line('$'))
    call setreg(s:register, join(l:lines, "\n"), getregtype(s:register)[0]) " Keep the original regtype (but not the width of a blockwise selection!).
    setlocal nomodified
    call s:Report(0, 'Updated', len(l:lines), 'register ' . s:register)
endfunction
function! MergeWithRegister#EndMerge() abort
    for l:bufNr in s:context.buffers
	let l:winNr = bufwinnr(l:bufNr)
	if l:winNr == -1 | continue | endif
	noautocmd execute l:winNr . 'wincmd w'
	silent! noautocmd close!    | " Use :noautocmd to avoid triggering us again recursively from the other scratch buffer.
    endfor

    call win_gotoid(s:context.winId)   " TODO: Better impl
endfunction
function! MergeWithRegister#Merged() abort
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
	let l:result = get(s:context, 'result', 'TODO')
	call setreg('"', l:result)
	if s:register ==# '='
	    call s:CorrectForRegtype(s:context.type, '"', getregtype('"'), l:result)
	endif

	if empty(s:context.text)
	    " In case of an empty text / selection, just paste before the cursor
	    " position.
	    silent normal! P
	elseif s:context.type ==# 'visual'
	    " TODO: Reestablish selection.
	    silent normal! gvp
	else
	    call ingo#change#Set(s:context.startPos, s:context.endPos)

	    " Note: Need to use an "inclusive" selection to make `] include
	    " the last moved-over character.
	    let l:save_selection = &selection
	    set selection=inclusive
	    try
		execute 'silent normal! g`[' . (s:context.type ==# 'line' ? 'V' : 'v') . 'g`]p'
	    finally
		let &selection = l:save_selection
	    endtry
	endif

	let l:newLineNum = line("']") - line("'[") + 1
	call s:Report(&report, 'Replaced', l:newLineNum)
    finally
	call setreg('"', l:save_reg, l:save_regmode)
	let &clipboard = l:save_clipboard
    endtry
endfunction

function! s:Report( report, action, newLineNum, ... ) abort
    if s:context.previousLineNum >= a:report || a:newLineNum >= a:report
	echomsg printf('%s %d line%s%s', a:action, s:context.previousLineNum, (s:context.previousLineNum == 1 ? '' : 's'), (a:0 ? ' in ' . a:1 : '')) .
	    \(s:context.previousLineNum == a:newLineNum ? '' : printf(' with %d line%s', a:newLineNum, (a:newLineNum == 1 ? '' : 's')))
    endif
endfunction

" Debugging
function! MergeWithRegister#Context() abort
    echomsg '****' s:register string(s:context)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
