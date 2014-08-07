" perforce.vim - Perforce
" Author:       Nuno Santos <https://github.com/nfvs>
" Version:      0.1

if exists("g:vim_perforce_loaded") || &cp
  finish
endif
let g:vim_perforce_loaded = 1

if !exists('g:vim_perforce_executable')
  let g:vim_perforce_executable = 'p4'
endif

" Available commands

command P4info call perforce#P4CallInfo()
command P4edit call perforce#P4CallEdit()
command P4revert call perforce#P4CallRevert()
command P4movetocl call perforce#P4CallPromptMoveToChangelist()

" Settings

" g:perforce_open_on_change (0|1, default: 0)
" Try to open the file in perforce when modifying a read-only file
if !exists('g:perforce_open_on_change')
  let g:perforce_open_on_change = 0
endif
" g:perforce_open_on_save (0|1, default: 1)
" Try to open the file in perforce when saving a read-only file (:w!)
if !exists('g:perforce_open_on_save')
  let g:perforce_open_on_save = 1
endif
" g:perforce_auto_source_dirs (default: [])
" Limit auto operations to a restricted set of directories
if !exists('g:perforce_auto_source_dirs ')
  let g:perforce_auto_source_dirs = []
endif

" Events

augroup vim_perforce
  autocmd!
  if g:perforce_open_on_change == 1
    autocmd FileChangedRO * nested call perforce#P4CallEditWithPrompt()
  endif
  if g:perforce_open_on_save == 1
    autocmd BufWritePre * nested call perforce#OnBufWriteCmd()
  endif
augroup END

" Utilities

function! s:P4Shell(cmd)
  return system(g:vim_perforce_executable . ' ' . a:cmd)
endfunction

function! s:P4ShellCurrentBuffer(cmd)
  let filename = expand('%:p')
  "return system(g:vim_perforce_executable . ' ' . a:cmd . ' ' . filename)
  return s:P4Shell(a:cmd . ' ' . filename)
endfunction

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

function! s:IsPathInP4(dir)
  let a:is_inside_path = 1  " by default assume it is a P4 dir
  if !empty(g:perforce_auto_source_dirs)
    let a:is_inside_path = 0
    for path in g:perforce_auto_source_dirs
      if a:dir =~ path
        let a:is_inside_path = 1
        break
      endif
    endfor
  endif
  if ! a:is_inside_path
    call s:msg('File is not under a Perforce directory.')
  endif
  return a:is_inside_path
endfunction

" P4 functions

function! perforce#P4GetUser()
  let output = s:P4Shell('info')
  let m = matchlist(output, "User name: \\([a-zA-Z]\\+\\).*")
  return m[1]
endfunction

function! perforce#P4CallInfo()
  let output = s:P4Shell('info')
  echo output
endfunction

" Called by autocmd
function! perforce#OnBufWriteCmd()
  if &readonly
    call perforce#P4CallEditWithPrompt()
  endif
endfunction

" Called by autocmd
function! perforce#P4CallEditWithPrompt()
  if ! s:IsPathInP4(expand('%:p:h'))
    return
  endif
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
  setlocal modifiable
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

function! perforce#P4GetUserPendingChangelists()
  let user = perforce#P4GetUser()
  if !empty(user)
    let output = s:P4Shell('changes -s pending -u ' . user)
    if v:shell_error != 0
      return ''
    endif
    return output
  endif
endfunction

" Move to changelist! Workflow:
" 1) The P4MoveToChangelist command calls P4CallPromptMoveToChangelist, which
" displays a new temp. buffer with a list of changelists
" 2) By selecting one with <cr>, P4ConfirmMoveToChangelist is called, with
" the CL string as parameter (the same string returned by p4). This string is
" then parsed, and the CL number extracted
" 3) P4CallMoveToChangelist is called, with the CL number as arg, which does
" the actual moving.
function! perforce#P4CallPromptMoveToChangelist()
  let user = perforce#P4GetUser()
  if empty(user)
    call s:warn('Unable to retrieve P4 user')
    return
  endif
  " Create temp buffer
  if exists("t:p4sbuf") && bufwinnr(t:p4sbuf) > 0
    execute "keepjumps " . bufwinnr(t:p4sbuf) . "wincmd W"
    execute 'normal ggdG'
  else
    silent! belowright new
    silent! resize 10
    silent! setlocal buftype=nowrite bufhidden=wipe nobuflisted noswapfile nonumber
    let t:p4sbuf=bufnr('%')
  end
  nnoremap <buffer> <silent> q      : <C-U>bdelete!<CR>
  nnoremap <buffer> <silent> <esc>  : <C-U>bdelete!<CR>
  nnoremap <buffer> <silent> <CR>   : exe perforce#P4ConfirmMoveToChangelist(getline('.')) <CR>
  " Populate buffer with existing Changelists
  let user_cls = perforce#P4GetUserPendingChangelists()
  if empty(user_cls)
    bdelete!
    call s:err('Unable to retrieve list of pending changelists.')
    return 1
  endif
  execute "normal! GiDefault changelist\<cr>" . user_cls . "\<esc>ddgg"
endfunction

function! perforce#P4ConfirmMoveToChangelist(changelist_str)
  " We have the P4 CL, now parse the CL number and close the temp buffer
  if exists("t:p4sbuf") && bufwinnr(t:p4sbuf) > 0
    bdelete!
  endif
  if a:changelist_str == "Default changelist"
    call perforce#P4CallMoveToChangelist('default')
  else
    let m = matchlist(a:changelist_str, "Change \\([0-9]\\+\\) .*")
    if m[1]
      call perforce#P4CallMoveToChangelist(m[1])
    endif
  endif
endfunction

function! perforce#P4CallMoveToChangelist(changelist)
  " read-only files haven't been opened yet
  if &readonly
    let output = s:P4ShellCurrentBuffer('edit -c ' . a:changelist)
  else
    let output = s:P4ShellCurrentBuffer('reopen -c ' . a:changelist)
  endif
  if v:shell_error != 0
    call s:err('Unable to move file to Changelist ' . a:changelist)
    return 1
  endif
  e!
endfunction
