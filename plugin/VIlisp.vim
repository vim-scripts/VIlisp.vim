
" Last updated: Thu Feb 14 23:45:13 EST 2002 

" only load the first time
if exists( "g:VIlisp_loaded" )
  finish
else
  let g:VIlisp_loaded = 1
endif

" ###################################################################
" ###################################################################
" functions


function! VIlisp_goto_buffer_or_window( buff )
  if -1 == bufwinnr( a:buff )
    exe "bu" a:buff
  else
    exe bufwinnr( a:buff ) . "wincmd w"
  endif
endfunction


function! VIlisp_load_syntax()
  if !exists( "b:current_syntax" ) || b:current_syntax != "lisp"
    set syntax=lisp
  endif
endfunction

function! VIlisp_get_pos()
  " what buffer are we in?
  let bufname = bufname( "%" )

  " get current position
  let c_cur = wincol()
  let l_cur = line( "." )
  normal H
  let l_top = line( "." )

  let pos = bufname . "|" . l_top . "," . l_cur . "," . c_cur

  " go back
  exe "normal " l_cur . "G" . c_cur . "|"

  return( pos )
endfunction


function! VIlisp_goto_pos( pos )
  let mx = '\(\f\+\)|\(\d\+\),\(\d\+\),\(\d\+\)'
  let bufname = substitute( a:pos, mx, '\1', '' )
  let l_top = substitute( a:pos, mx, '\2', '' )
  let l_cur = substitute( a:pos, mx, '\3', '' )
  let c_cur = substitute( a:pos, mx, '\4', '' )

  exe "bu" bufname
  exe "normal " . l_top . "Gzt" . l_cur . "G" . c_cur . "|"
endfunction


function! VIlisp_yank( motion )
  let p = VIlisp_get_pos()
  let old_l = @l
  exec 'normal "ly' . a:motion
  let value = @l
  let @l = old_l
  call VIlisp_goto_pos( p )
  return( value )
endfunction


" copy an expression to a buffer
function! VIlisp_send_sexp_to_buffer( sexp, buffer )
  let p = VIlisp_get_pos()

  " go to the given buffer, go to the bottom
  exe "bu" a:buffer
  silent normal G

  " tried append() -- doesn't work the way I need it to
  let old_l = @l
  let @l = a:sexp
  silent exe "put l"
  " normal "lp
  let @l = old_l

  call VIlisp_goto_pos( p )
endfunction
  

" destroys contents of VIlisp_scratch buffer
function! VIlisp_send_to_lisp( sexp )
  let p = VIlisp_get_pos()

  " goto VIlisp_scratch, delete it, put sexp, write it to lisp
  exe "bu" g:VIlisp_scratch
  exe "%d"
  normal 1G

  " tried append() -- doesn't work the way I need it to
  let old_l = @l
  let @l = a:sexp
  normal "lP
  let @l = old_l

  exe 'w >>' s:pipe_name

  call VIlisp_goto_pos( p )
endfunction


" Actually evals current top level form
function! VIlisp_eval_defun_lisp()
  " save position
  let p = VIlisp_get_pos()

  " find defun
"   if search( "^(defun", "bW" ) > 0
"     call VIlisp_send_to_lisp( VIlisp_yank( "%" ) )
"   endif
  normal 99[(
  call VIlisp_send_to_lisp( VIlisp_yank( "%" ) )

  " fix cursor position, in case of error below
  call VIlisp_goto_pos( p )
endfunction


function! VIlisp_eval_next_sexp_lisp()
  " save position
  let pos = VIlisp_get_pos()

  " find & yank current sexp
  normal [(
  let sexp = VIlisp_yank( "%" )
  call VIlisp_send_to_lisp( sexp )
  call VIlisp_goto_pos( pos )
endfunction


function! VIlisp_eval_block() range
  " save position
  let pos = VIlisp_get_pos()

  " yank current visual block
  let old_l = @l
  '<,'> yank l
  let sexp = @l
  let @l = old_l

  call VIlisp_send_to_lisp( sexp )
  call VIlisp_goto_pos( pos )
endfunction


function! VIlisp_copy_sexp_to_test()
  " save position
  let pos = VIlisp_get_pos()

  " find & yank current sexp
  normal [(
  call VIlisp_send_sexp_to_buffer( VIlisp_yank( "%" ), g:VIlisp_test )

  call VIlisp_goto_pos( pos )
endfunction



" ###################################################################
" ###################################################################
" startup stuff
let g:VIlisp_scratch = $HOME. "/.VIlisp_scratch"
let g:VIlisp_test = $HOME . '/.VIlisp_test'
let s:pipe_name = $HOME . '/.lisp-pipe'

exe "new" g:VIlisp_scratch
doauto lisp BufRead x.lsp
set syntax=lisp
set buftype=nowrite
set bufhidden=hide
set nobuflisted
set noswapfile
hide

exe "new" g:VIlisp_test
doauto lisp BufRead x.lsp
set syntax=lisp
" set buftype=nofile
set bufhidden=hide
set nobuflisted
" set noswapfile
hide

augroup VIlisp
    au!

    " autocmd BufEnter VIlisp* call VIlisp_load_syntax()
    autocmd BufLeave .VIlisp_* set nobuflisted
    autocmd BufLeave *.lsp,*.lisp let VIlisp_last_lisp = bufname( "%" )
augroup END

" hide from the user that we created and deleted (hid, really) a couple of
" buffers
exe 'normal '

" ###################################################################
" ###################################################################
" mappings

" ###################################################################
" Interact with Lisp interpreter

" send top-level sexp to lisp: eval s-exp
map ,es :call VIlisp_eval_defun_lisp()<cr>

" send current s-exp to lisp: eval current
map ,ec :call VIlisp_eval_next_sexp_lisp()<cr>

" eval block
map ,eb :call VIlisp_eval_block()<cr>

" reset interpreter
map ,ri :call VIlisp_send_to_lisp( "q\n" )<cr>

" ###################################################################
" Dunno?

" copy current s-exp to test buffer: Copy to Test
map ,ct :call VIlisp_copy_sexp_to_test()<cr>


" ###################################################################
" load/compile files

" load file: Load File; Load Any File, Load Compiled File
map ,lf :call VIlisp_send_to_lisp( "(load \"" . expand( "%:p" ) . "\")\n")<cr>
map ,laf :call VIlisp_send_to_lisp( "(load \"" . expand( "%:p:r" ) . "\")\n")<cr>
map ,lcf ,laf

" compile file: Compile File; Compile & Load File
map ,cf :call VIlisp_send_to_lisp( "(compile-file \"" . expand( "%:p" ) . "\")\n")<cr>
map ,clf ,cf,laf

" ###################################################################
" Move around among buffers

" goto test or scratch buffer
map ,tb :call VIlisp_goto_buffer_or_window( g:VIlisp_test )<cr>
map ,wtb :sb <bar> call VIlisp_goto_buffer_or_window( g:VIlisp_test )<cr>
map ,sb :exe "bu" g:VIlisp_scratch<cr>

" return to VIlisp_last_lisp -- "Test Return"
map ,tr :call VIlisp_goto_buffer_or_window( VIlisp_last_lisp )<cr>

" return to "lisp buffer", or "last buffer", even
map ,lb ,tr

" ###################################################################
" Mark & format code

" mark the current top-level sexpr: Mark Sexp
map ,ms 99[(V%

" format current, format sexp
map ,fc [(=%`'
map ,fs 99,fc

" ###################################################################
" Add & delete code

" remove my ,ilu mapping, which makes the ,il mapping slow
if maparg( ",ilu" ) != ""
    unmap ,ilu
endif

" Put a list around the current form: Insert List
map ,il [(%a)<esc>h%i(

" comment current -- doesn't work correctly on some forms
map ,cc m`[(i<cr><esc>v%<esc>a<cr><esc>:'<,'>s/^/; /<cr>``%/(<cr>


" ###################################################################
" Do stuff with VIlisp

" reload this file -- can't do this in a function
map ,rvil :exe "unlet! g:VIlisp_loaded <bar> so ~/lisp/VIlisp.vim"<cr>

