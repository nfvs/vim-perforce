" perforce.vim - Perforce
" Author:		    Nuno Santos <https://github.com/nfvs>
" Version:		  0.1

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
command P4Revert call perforce#P4CallRevert()

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
  echomsg 'vim-perforce: ' . a:str
  echohl None
  let v:warningmsg = a:str
endfunction

function! s:err(str) abort
  echoerr 'vim-perforce: ' . a:str
endfunction

function! s:P4ShellCurrentBuffer(cmd)
  let filename = expand('%:p')
  return system(g:vim_perforce_executable . ' ' . a:cmd . ' ' . filename)
endfunction

" Events

augroup vim_perforce
  autocmd!
  autocmd FileChangedRO * nested call perforce#P4CallEditWithPrompt()
augroup END

" P4 functions

function! perforce#P4CallInfo()
  let output = s:P4ShellCurreentBuffer('info')
  echo output
endfunction

" Should only be called from FileChangedRO autocmd
function! perforce#P4CallEditWithPrompt()
  let ok = confirm('File is read only. Attempt to open in Perforce?', "&Yes\n&No", 1, 'Question')
  if ok == 1
    let res = perforce#P4CallEdit()
    " We need to redraw in case of an error, to dismiss the
    " W10 warning 'editing a read-only file'.
    if res != 1
      redraw
    endif
  endif
endfunction

function! perforce#P4CallEdit()
  let output = s:P4ShellCurrentBuffer('edit')
  if v:shell_error != 0
    call s:err('Unable to open file for edit.')
    return 1
  endif
  setlocal noreadonly
  setlocal autoread
  call s:msg('File open for edit.')
endfunction

function! perforce#P4CallRevert()
  let output = s:P4ShellCurrentBuffer('diff -f -sa')
  if !empty(matchstr(output, "not under client\'s root"))
    call s:warn('File not under P4.')
    return
  endif
  " If the file hasn't changed (no output), don't ask for confirmation
  if empty(output)
    let do_revert = 1
  else
    let do_revert = confirm('Revert this file in Perforce and lose all changes?', "&Yes\n&No", 2, 'Question')
  endif
  if do_revert == 1
    let output = s:P4ShellCurrentBuffer('revert')
    if v:shell_error != 0
      call s:err('Unable to revert file.')
      return 1
    endif
    e!
  endif
endfunction
