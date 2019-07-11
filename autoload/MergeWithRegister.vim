" MergeWithRegister.vim: Merge text with the contents of a register.
"
" DEPENDENCIES:
"   - ingo-library.vim plugin
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
function! s:Operator( type, ... )
    let l:pasteText = getreg(s:register, 1) " Expression evaluation inside function context may cause errors, therefore get unevaluated expression when s:register ==# '='.
    let l:regType = getregtype(s:register)
    let l:isCorrected = s:CorrectForRegtype(a:type, s:register, l:regType, l:pasteText)
    try
	call s:MergeWithRegister(a:type, (a:0 ? a:1 : ''), (a:0 >= 2 && a:2))
    finally
	if l:isCorrected
	    " Undo the temporary change of the register.
	    " Note: This doesn't cause trouble for the read-only registers :, .,
	    " %, # and =, because their regtype is always 'v'.
	    call setreg(s:register, l:pasteText, l:regType)
	endif
    endtry
endfunction
function! MergeWithRegister#Operator( ... )
    let s:context = {
    \   'visualRepeatMapping': "\<Plug>MergeWithRegisterVisual"
    \}
    call call('s:Operator', a:000)
endfunction
function! MergeWithRegister#OperatorExpression( opfunc )
    call MergeWithRegister#SetRegister()
    let &opfunc = a:opfunc

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



function! s:MergeWithRegister( type, repeatMapping, isUseRepeatCount )
    call extend(s:context,  {
    \   'type': a:type,
    \   'repeatMapping': a:repeatMapping,
    \   'register': {},
    \})
    if a:type ==# 'visual'
	call extend(s:context, {
	\   'isUseRepeatCount': a:isUseRepeatCount,
	\   'text': {
	\       'previousLineNum': line("'>") - line("'<") + 1,
	\   },
	\   'startPos': getpos("'<"),
	\   'endPos': getpos("'>"),
	\   'mode': visualmode(),
	\})

	let s:context.text.contents = (&selection ==# 'exclusive' && getpos("'<") == getpos("'>") ?
	\   '' :
	\   ingo#selection#Get()
	\)
    else
	call extend(s:context, {
	\   'text': {
	\       'previousLineNum': line("']") - line("'[") + 1,
	\   },
	\   'startPos': getpos("'["),
	\   'endPos': getpos("']"),
	\   'mode': a:type[0],
	\})

	if ingo#pos#IsOnOrAfter(getpos("'[")[1:2], getpos("']")[1:2])
	    let s:context.text.contents = ''
	else
	    " Note: Need to use an "inclusive" selection to make `] include
	    " the last moved-over character.
	    let l:save_selection = &selection
	    set selection=inclusive
	    try
		let s:context.text.contents = ingo#register#KeepRegisterExecuteOrFunc(
		    \'execute "silent normal! g`[' . (a:type ==# 'line' ? 'V' : 'v') . 'g`]y" | return @"'
		\)
	    finally
		let &selection = l:save_selection
	    endtry
	endif
    endif

    call s:StartMerge()
endfunction
function! s:StartMerge() abort
    let s:context.buffers = []
    let s:context.filetype = &l:filetype
    let s:context.currentBuffer = ingo#window#switches#WinSaveCurrentBuffer(1)
    let s:context.previousWinNr = winnr('#') ? winnr('#') : 1
    let l:register = s:GetRegisterContents()
    let l:name = expand('%:t') | if empty(l:name) | let l:name = 'unnamed' | endif
    let l:tabPrefixCommand = (g:MergeWithRegister_UseDiff && ingo#window#special#HasDiffWindow() ? 'tab ' : '') " DWIM: Open scratch buffers in a separate tab page if we're already diffing here.

    try
	call s:OpenScratch(
	\   'text',
	\   1, l:tabPrefixCommand . g:MergeWithRegister_ScratchSplitCommand,
	\   l:name, s:context.text.contents,
	\   function('MergeWithRegister#WriteText')
	\)
	call s:OpenScratch(
	\   'register',
	\   ingo#register#IsWritable(s:register), g:MergeWithRegister_SecondSplitCommand,
	\   'register ' . s:register, s:GetRegisterContents(),
	\   function('MergeWithRegister#WriteRegister')
	\)
	wincmd p
    catch /^MergeWithRegister:/
	call ingo#msg#CustomExceptionMsg('MergeWithRegister')
    endtry
endfunction
function! s:SplitContentsIntoLines( contextKey, contents ) abort
    let l:contents = substitute(a:contents, '\n$', '', '')
    if l:contents =~# '\n'
	let l:lines = split(l:contents, '\n', 1)
    else
	if &cmdheight > 1
	    redraw! " Clear the previous echoed line.XXX: Somehow need to force a redraw here.
	    call ingo#avoidprompt#Echo(l:contents)
	endif
	let l:splitPattern = input('Enter separator pattern to temporarily split the single line: ', get(s:context, 'splitPattern', ''))
	if empty(l:splitPattern)
	    let l:lines = [l:contents]
	else
	    let s:context.splitPattern = l:splitPattern
	    let s:context[a:contextKey].splitPattern = l:splitPattern
	    let l:lines = split(l:contents, printf('\%%(%s\)\zs', l:splitPattern), 1)
	    let s:context[a:contextKey].elementNum = len(l:lines)
	endif
    endif
    return l:lines
endfunction
function! s:OpenScratch( contextKey, isWritable, splitCommand, name, contents, Writer ) abort
    let l:lines = s:SplitContentsIntoLines(a:contextKey, a:contents)
    if ! has_key(s:context[a:contextKey], 'previousLineNum') | let s:context[a:contextKey].previousLineNum = len(l:lines) | endif  " Also tally the previous number of lines in the register; we already know s:context.previousLineNum.

    if ! (a:isWritable ?
    \   ingo#buffer#scratch#CreateWithWriter(a:name, a:Writer, l:lines, a:splitCommand) :
    \   ingo#buffer#scratch#Create('', a:name, 0, l:lines, a:splitCommand)
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

function! s:GetScratchLines( contextKey ) abort
    let l:lines = getline(1, line('$'))
    return (has_key(s:context[a:contextKey], 'splitPattern') ?
    \   [len(l:lines), [join(l:lines, '')]] :
    \   [len(l:lines), l:lines]
    \)
endfunction
function! MergeWithRegister#WriteText() abort
    let [l:elementNum, l:lines] = s:GetScratchLines('text')
    let s:context.result = join(l:lines, "\n") . (s:context.mode =~# '^[lV]$' ? "\n" : '')
    setlocal nomodified
    call s:ReportForContextKey('text', 'Replacing', l:elementNum, len(l:lines), 'text')
endfunction
function! MergeWithRegister#WriteRegister() abort
    let [l:elementNum, l:lines] = s:GetScratchLines('register')
    call setreg(s:register, l:lines, getregtype(s:register)[0]) " Keep the original regtype (but not the width of a blockwise selection!).
    setlocal nomodified
    call s:ReportForContextKey('register', 'Updated', l:elementNum, len(l:lines), 'register ' . s:register)
endfunction
function! MergeWithRegister#EndMerge() abort
    if ! exists('s:context') | return | endif   " Safety check for being invoked multiple times.

    for l:bufNr in s:context.buffers
	let l:winNr = bufwinnr(l:bufNr)
	if l:winNr == -1 | continue | endif
	noautocmd execute l:winNr . 'wincmd w'
	silent! noautocmd close!    | " Use :noautocmd to avoid triggering us again recursively from the other scratch buffer.
    endfor

    try
	call ingo#window#switches#WinRestoreCurrentBuffer(s:context.currentBuffer, 1)
	let l:originalWinNr = winnr()
	execute s:context.previousWinNr . 'wincmd w'
	execute l:originalWinNr . 'wincmd w'
    catch /^WinRestoreCurrentBuffer:/
	call ingo#msg#ErrorMsg('Cannot locate original buffer')
	return
    endtry

    if has_key(s:context, 'result')
	call ingo#register#KeepRegisterExecuteOrFunc(function('MergeWithRegister#MergeResult'), s:context.result, s:context.mode)
    else
	echomsg printf('No update to %s%d line%s',
	\   (s:context.type ==# 'visual' ? 'selected ' : ''),
	\   s:context.text.previousLineNum, (s:context.text.previousLineNum == 1 ? '' : 's')
	\)
    endif

    if ! empty(s:context.repeatMapping)
	if s:context.isUseRepeatCount
	    silent! call repeat#set(s:context.repeatMapping, s:count)
	else
	    silent! call repeat#set(s:context.repeatMapping)
	endif
    elseif s:register ==# '='
	" Employ repeat.vim to have the expression re-evaluated on repetition of
	" the operator-pending mapping.
	silent! call repeat#set("\<Plug>MergeWithRegisterExpressionSpecial")
    endif
    silent! call visualrepeat#set(s:context.visualRepeatMapping)

    unlet s:context
endfunction
function! MergeWithRegister#MergeResult( result, mode ) abort
    " With a put in visual mode, the selected text will be replaced with the
    " contents of the register. This works better than first deleting the
    " selection into the black-hole register and then doing the insert; as
    " "d" + "i/a" has issues at the end-of-the line (especially with blockwise
    " selections, where "v_o" can put the cursor at either end), and the "c"
    " commands has issues with multiple insertion on blockwise selection and
    " autoindenting.
    " With a put in visual mode, the previously selected text is put in the
    " unnamed register, so we need to save and restore that.
    call setreg('"', a:result, a:mode)
    if s:register ==# '='
	call s:CorrectForRegtype(s:context.type, '"', getregtype('"'), a:result)
    endif

    if empty(s:context.text.contents)
	" In case of an empty text / selection, just paste before the cursor
	" position.
	silent normal! P
    elseif s:context.type ==# 'visual'
	if (s:context.startPos != getpos("'<") ||
	\   s:context.endPos != getpos("'>") ||
	\   s:context.mode != visualmode()
	\)
	    " Recreate the initial selection in case it was clobbered (which is
	    " unlikely, but nothing prevents the user from going back to the
	    " original window and selecting new things).
	    call ingo#selection#Set(s:context.startPos, s:context.endPos, s:context.mode)
	endif
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
    redraw  " Clear previous "Replacing ..." message.
    call s:Report('Replaced', s:context.text.previousLineNum, l:newLineNum)
endfunction

function! s:Report( action, oldLineNum, newLineNum, ... ) abort
    let l:what = (a:0 >= 2 && ! empty(a:2) ? a:2 : 'line')
    echomsg printf('%s %d %s%s%s',
    \   a:action,
    \   a:oldLineNum, l:what, (a:oldLineNum == 1 ? '' : 's'),
    \   (a:0 ? ' in ' . a:1 : '')
    \) . (a:oldLineNum == a:newLineNum ?
    \   '' :
    \   printf(' with %d %s%s', a:newLineNum, l:what, (a:newLineNum == 1 ? '' : 's'))
    \)
endfunction
function! s:ReportForContextKey( contextKey, action, elementNum, newLineNum, what ) abort
    if has_key(s:context[a:contextKey], 'elementNum')
	call s:Report(a:action, s:context[a:contextKey].elementNum, a:elementNum, a:what, 'element')
    else
	call s:Report(a:action, s:context[a:contextKey].previousLineNum, a:newLineNum, a:what)
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
