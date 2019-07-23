MERGE WITH REGISTER
===============================================================================
_by Ingo Karkat_

DESCRIPTION
------------------------------------------------------------------------------

With the ReplaceWithRegister.vim plugin, you can replace an existing text
with the contents of a register. For that, the target text already has to
exist in its desired form. If just the indentation is off, you can use
the ReplaceWithSameIndentRegister.vim companion that keeps the original
indent.

This plugin is a further generalization of replacing text (or the current
selection) with something in a register. It opens two scratch buffers, one
with the extracted text from the current buffer, the other with the register
contents. You can then freely make edits to both, copying lines from the
register contents to the text (as a selective variant of ReplaceWithRegister),
or updating the register contents with the extracted text (assuming you've
chosen a writable register), back and forth, until you (optionally) commit
your changes with :write and :close the scratch buffers.

- As in the command-line-window, you have all Vim commands available. Global
  adaptations are simpler there than doing those edits after pasting into the
  buffer, as you can just use the :% range to target the entire buffer, e.g.
  with :substitute.
- By default, the two buffers start in diff-mode to facilitate easy data
  exchange.
- If you're dealing with single-line contents, the plugin offers to
  temporarily unjoin into separate lines (this is automatically undone at the
  end), to make data exchange easier for you.
- To avoid being disturbed by differences in indent, there are mapping
  variants that temporarily remove common indent.
- Any register can serve as the second partner; writable registers can also be
  updated. Through the expression register quote=, you can even reference
  content from other buffers, Vim variables, or dynamic content generated by a
  function or external command, enabling you to build integrations that let
  you selectively access frequently used content.

### SEE ALSO

- ReplaceWithRegister.vim ([vimscript #2703](http://www.vim.org/scripts/script.php?script_id=2703)) implements the straightforward
  case of replacing text with entire register contents.
- ReplaceWithSameIndentRegister.vim ([vimscript #5046](http://www.vim.org/scripts/script.php?script_id=5046)) is a companion plugin
  for the special case of replacing lines while keeping the original indent.
- RepeatableYank.vim ([vimscript #4238](http://www.vim.org/scripts/script.php?script_id=4238)) streamlines the appending of content to
  a register; this plugin can include (and also edit) data at arbitrary
  locations inside the register contents.

USAGE
------------------------------------------------------------------------------

    [count]["x]mr{motion}   Merge {motion} text with the contents of register x.
                            This opens two scratch buffers (split in the same tab,
                            or in a separate tab if there already are diff
                            windows), one with the original text from the buffer
                            and one with the register contents. If either just
                            consists of a single line, it asks for a split pattern
                            and then temporarily unjoins the contents (keeping the
                            separators at each line's end), and automatically
                            rejoins when done. diff-mode can be automatically
                            enabled (g:MergeWithRegister_UseDiff), and you can
                            pick and exchange contents between both. A :write
                            will cause an update of the underlying data. :quit
                            or :close of any of the two diff buffers will end
                            the merge session. If the original text has been
                            modified and written, the original ({motion}) area
                            will be updated.
    [count]["x]mrr          Merge [count] lines with the contents of register x.
                            To replace from the cursor position to the end of the
                            line use ["x]mr$
    {Visual}["x]mr          Merge the selection with the contents of register x.

    [count]["x]mR{motion}   Merge {motion} text with the contents of register x
                            while ignoring any common indent (after potentially
                            splitting a single line). When updating, the indent is
                            adjusted to the first replaced line (like pasting with
                            ]p).
    [count]["x]mRR          Merge [count] lines with the contents of register x
                            while ignoring any common indent.
    {Visual}["x]mR          Merge the selection with the contents of register x
                            while ignoring any common indent.

INSTALLATION
------------------------------------------------------------------------------

The code is hosted in a Git repo at
    https://github.com/inkarkat/vim-MergeWithRegister
You can use your favorite plugin manager, or "git clone" into a directory used
for Vim packages. Releases are on the "stable" branch, the latest unstable
development snapshot on "master".

This script is also packaged as a vimball. If you have the "gunzip"
decompressor in your PATH, simply edit the \*.vmb.gz package in Vim; otherwise,
decompress the archive first, e.g. using WinZip. Inside Vim, install by
sourcing the vimball or via the :UseVimball command.

    vim MergeWithRegister*.vmb.gz
    :so %

To uninstall, use the :RmVimball command.

### DEPENDENCIES

- Requires Vim 7.0 or higher.
- Requires the ingo-library.vim plugin ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)), version 1.039 or
  higher.

CONFIGURATION
------------------------------------------------------------------------------

For a permanent configuration, put the following commands into your vimrc:

By default, 'diff' will be automatically enabled on both scratch buffers. To
turn this off:

    let g:MergeWithRegister_UseDiff = 0

The split command to open the first scratch buffer (for the original text from
the buffer):

    let g:MergeWithRegister_ScratchSplitCommand = 'rightbelow new'

The split command to open the second scratch buffer (for the register
contents):

    let g:MergeWithRegister_SecondSplitCommand = 'rightbelow vnew'

If you want to use different mappings, map your keys to the
&lt;Plug&gt;(MergeWithRe...) mapping targets _before_ sourcing the script (e.g. in
your vimrc):

    nmap <Leader>m  <Plug>MergeWithRegisterOperator
    nmap <Leader>mm <Plug>MergeWithRegisterLine
    xmap <Leader>m  <Plug>MergeWithRegisterVisual
    nmap <Leader>M  <Plug>MergeWithReIndentOperator
    nmap <Leader>MM <Plug>MergeWithReIndentLine
    xmap <Leader>M  <Plug>MergeWithReIndentVisual

CONTRIBUTING
------------------------------------------------------------------------------

Report any bugs, send patches, or suggest features via the issue tracker at
https://github.com/inkarkat/vim-MergeWithRegister/issues or email (address
below).

HISTORY
------------------------------------------------------------------------------

##### GOAL
First published version.

##### 0.01    10-Jul-2019
- Started development.

------------------------------------------------------------------------------
Copyright: (C) 2019 Ingo Karkat -
The [VIM LICENSE](http://vimdoc.sourceforge.net/htmldoc/uganda.html#license) applies to this plugin.

Maintainer:     Ingo Karkat &lt;ingo@karkat.de&gt;