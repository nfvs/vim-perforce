" perforce.vim - Perforce
" Author:		Nuno Santos <https://github.com/nfvs>
" Version:		0.1

if exists("g:vim_perforce_loaded") || &cp
  finish
endif
let g:vim_perforce_loaded = 1

if !exists('g:vim_perforce_executable')
  let g:vim_perforce_executable = 'p4'
endif

" Available commands

command P4Info call perforce#P4CallInfo()
command P4Edit call perforce#P4CallEdit()

" Utilities

function! s:throw(string) abort
  let v:errmsg = 'vim-perforce: ' . a:string
  throw v:errmsg
endfunction

function! s:msg(string) abort
  echomsg 'vim-perforce: ' . a:string
endfunction

function! s:warn(str) abort
  echohl WarningMsg
  call s:msg(a:str)
  echohl None
  let v:warningmsg = a:str
endfunction

function! s:err(str) abort
  echoerr 'vim-perforce: ' . a:str
endfunction

" Events

augroup vim_perforce
  autocmd!
  autocmd FileChangedRO * nested call perforce#P4CallEditWithPrompt()
augroup END

" P4 functions

function! perforce#P4CallInfo()
  let output = system(g:vim_perforce_executable . ' info')
  echo output
endfunction

function! perforce#P4CallEditWithPrompt()
  let ok = confirm('File is read only. Attempt to open in Perforce?', "&Yes\n&No", 1, 'Question')
  if ok == 1
    let res = perforce#P4CallEdit()
    " We need to redraw in case of an error, to dismiss the
    " W10 warning 'editing a read-only file'.
    if res == 1
      redraw
    endif
  endif
endfunction

function! perforce#P4CallEdit()
  let output = system(g:vim_perforce_executable . ' edit ' . expand('%:p'))
  let ok = matchstr(output, 'opened for edit')
  if empty(ok)
    call s:err('Unable to open file for edit.')
    call s:msg(output)
    return 1
  endif
endfunction
