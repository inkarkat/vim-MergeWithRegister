" MergeWithRegister.vim: Merge text with the contents of a register.
"
" DEPENDENCIES:
"   - Requires Vim 7.0 or higher.
"
" Copyright: (C) 2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

" Avoid installing twice or when in unsupported Vim version.
if exists('g:loaded_MergeWithRegister') || (v:version < 700)
    finish
endif
let g:loaded_MergeWithRegister = 1

let s:save_cpo = &cpo
set cpo&vim

"- configuration ---------------------------------------------------------------

if ! exists('g:MergeWithRegister_UseDiff')
    let g:MergeWithRegister_UseDiff = 1
endif
if ! exists('g:MergeWithRegister_ScratchSplitCommand')
    let g:MergeWithRegister_ScratchSplitCommand = 'rightbelow new'
endif
if ! exists('g:MergeWithRegister_SecondSplitCommand')
    let g:MergeWithRegister_SecondSplitCommand = 'rightbelow vnew'
endif


"- mappings --------------------------------------------------------------------

" This mapping repeats naturally, because it just sets global things, and Vim is
" able to repeat the g@ on its own.
nnoremap <expr> <Plug>MergeWithRegisterOperator MergeWithRegister#OperatorExpression()
" But we need repeat.vim to get the expression register re-evaluated: When Vim's
" . command re-invokes 'opfunc', the expression isn't re-evaluated, an
" inconsistency with the other mappings. We creatively use repeat.vim to sneak
" in the expression evaluation then.
nnoremap <silent> <Plug>MergeWithRegisterExpressionSpecial :<C-u>let g:MergeWithRegister#expr = getreg('=')<Bar>execute 'normal!' v:count1 . '.'<CR>

" This mapping needs repeat.vim to be repeatable, because it consists of
" multiple steps (visual selection + 'c' command inside
" MergeWithRegister#Operator).
nnoremap <silent> <Plug>MergeWithRegisterLine
\ :<C-u>call setline('.', getline('.'))<Bar>
\execute 'silent! call repeat#setreg("\<lt>Plug>MergeWithRegisterLine", v:register)'<Bar>
\call MergeWithRegister#SetRegister()<Bar>
\if MergeWithRegister#IsExprReg()<Bar>
\    let g:MergeWithRegister#expr = getreg('=')<Bar>
\endif<Bar>
\call MergeWithRegister#SetCount()<Bar>
\execute 'normal! V' . v:count1 . "_\<lt>Esc>"<Bar>
\call MergeWithRegister#Operator('visual', "\<lt>Plug>MergeWithRegisterLine", 1)<CR>

" Repeat not defined in visual mode, but enabled through visualrepeat.vim.
vnoremap <silent> <Plug>MergeWithRegisterVisual
\ :<C-u>call setline('.', getline('.'))<Bar>
\execute 'silent! call repeat#setreg("\<lt>Plug>MergeWithRegisterVisual", v:register)'<Bar>
\call MergeWithRegister#SetRegister()<Bar>
\if MergeWithRegister#IsExprReg()<Bar>
\    let g:MergeWithRegister#expr = getreg('=')<Bar>
\endif<Bar>
\call MergeWithRegister#Operator('visual', "\<lt>Plug>MergeWithRegisterVisual")<CR>

" A normal-mode repeat of the visual mapping is triggered by repeat.vim. It
" establishes a new selection at the cursor position, of the same mode and size
" as the last selection.
" If [count] is given, that number of lines is used / the original size is
" multiplied accordingly. This has the side effect that a repeat with [count]
" will persist the expanded size, just as it should.
" First of all, the register must be handled, though.
nnoremap <silent> <Plug>MergeWithRegisterVisual
\ :<C-u>call setline('.', getline('.'))<Bar>
\execute 'silent! call repeat#setreg("\<lt>Plug>MergeWithRegisterVisual", v:register)'<Bar>
\call MergeWithRegister#SetRegister()<Bar>
\if MergeWithRegister#IsExprReg()<Bar>
\    let g:MergeWithRegister#expr = getreg('=')<Bar>
\endif<Bar>
\execute 'normal!' MergeWithRegister#VisualMode()<Bar>
\call MergeWithRegister#Operator('visual', "\<lt>Plug>MergeWithRegisterVisual")<CR>


if ! hasmapto('<Plug>MergeWithRegisterOperator', 'n')
    nmap mr <Plug>MergeWithRegisterOperator
endif
if ! hasmapto('<Plug>MergeWithRegisterLine', 'n')
    nmap mrr <Plug>MergeWithRegisterLine
endif
if ! hasmapto('<Plug>MergeWithRegisterVisual', 'x')
    xmap mr <Plug>MergeWithRegisterVisual
endif

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
