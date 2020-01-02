" perforce.vim - Perforce
" Author:       Nuno Santos <https://github.com/nfvs>
" Version:      0.1

" Enable autoread, as P4 changes files attributes, and without it we may not
" be able to catch all FileChangedRO events.
set autoread

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
" g:perforce_use_relative_paths (0|1, default: 0)
" Use relative paths as arguments to perforce
if !exists('g:perforce_use_relative_paths')
  let g:perforce_use_relative_paths = 0
endif
" g:perforce_use_cygpath (0|1, default: 0)
" Use cygpath to translate paths from cygwin to absolute windows paths
if !exists('g:perforce_use_cygpath')
  let g:perforce_use_cygpath = 0
endif
" g:perforce_prompt_on_open
" Prompt when a file is opened either on change or on save
if !exists('g:perforce_prompt_on_open')
  let g:perforce_prompt_on_open = 1
endif
" g:perforce_debug
" Print debugging information
if !exists('g:perforce_debug')
  let g:perforce_debug = 0
endif

" Events

augroup vim_perforce
  autocmd!
  if g:perforce_open_on_change
    if g:perforce_prompt_on_open
      autocmd FileChangedRO * nested call perforce#P4CallEditWithPrompt()
    else
      autocmd FileChangedRO * nested call perforce#P4CallEdit()
    endif
  endif
  if g:perforce_open_on_save
    autocmd BufWritePre * nested call perforce#OnBufWriteCmd()
  endif
augroup END

" Utilities

function! s:P4Shell(cmd, ...)
  call s:debug(g:vim_perforce_executable . ' ' . a:cmd . ' ' . join(a:000, " "))
  return substitute(call('system', [g:vim_perforce_executable . ' ' . a:cmd] + a:000), '\_s*$', '', '')
endfunction

function! s:P4ShellCurrentBuffer(cmd, ...)
  if g:perforce_use_relative_paths
    let l:filename = expand('%')
  else
    let l:filename = expand('%:p')
  endif
  if g:perforce_use_cygpath
	  let l:filename = system('cygpath -wa ' . shellescape(l:filename) . ' | tr -d \\n')
  endif
  return call('s:P4Shell', [a:cmd . ' ' . shellescape(l:filename)] + a:000)
endfunction

function! s:P4OutputHasError(output)
  if !empty(matchstr(a:output, "not under client\'s root")) || !empty(matchstr(a:output, "not on client"))
    call s:warn("File not under perforce client\'s root.")
    return 1
  elseif !empty(matchstr(a:output, "not opened on this client"))
    call s:warn('File not opened for edit.')
    return 1
  endif
  return 0
endfunction

function! s:throw(string) abort
  let v:errmsg = 'vim-perforce: ' . a:string
  throw v:errmsg
endfunction

function! s:msg(...) abort
  for l:message in a:000
    echomsg 'vim-perforce: ' . l:message
  endfor
endfunction

function! s:warn(...) abort
  echohl WarningMsg
  for l:message in a:000
    echomsg 'vim-perforce: ' . l:message
  endfor
  echohl None
  let v:warningmsg = a:000[0]
endfunction

function! s:err(...) abort
  for l:message in a:000
    echoerr 'vim-perforce: ' . l:message
  endfor
endfunction

function! s:debug(string) abort
  if g:perforce_debug
    echomsg 'vim-perforce: ' . a:string
  endif
endfunction

function! s:IsPathInP4(dir)
  let l:is_inside_path = 1  " by default assume it is a P4 dir
  if !empty(g:perforce_auto_source_dirs)
    let l:is_inside_path = 0
    for l:path in g:perforce_auto_source_dirs
      if a:dir =~ l:path || shellescape(a:dir) =~ shellescape(l:path)
        let l:is_inside_path = 1
        break
      endif
    endfor
  endif
  if ! l:is_inside_path
    call s:msg('File is not under a Perforce directory.')
  endif
  return l:is_inside_path
endfunction

" P4 functions

function! perforce#P4GetUser()
  let l:output = s:P4Shell('info')
  let l:m = matchlist(output, "User name: \\([a-zA-Z]\\+\\).*")
  if len(l:m) > 1 && !empty(l:m[1])
    return l:m[1]
  endif
endfunction

function! perforce#P4CallInfo()
  let l:output = s:P4Shell('info')
  echo l:output
endfunction

" Called by autocmd
function! perforce#OnBufWriteCmd()
  if &readonly
    if g:perforce_prompt_on_open
      call perforce#P4CallEditWithPrompt()
    else
      call perforce#P4CallEdit()
    endif
  endif
endfunction

" Called by autocmd
function! perforce#P4CallEditWithPrompt()
  if g:perforce_use_relative_paths
    let l:path = expand('%:h')
  else
    let l:path = expand('%:p:h')
  endif
  if g:perforce_use_cygpath
	  let l:path = system('cygpath -wa ' . shellescape(l:path) . ' | tr -d \\n')
  endif
  if ! s:IsPathInP4(l:path)
    return
  endif
  let l:ok = confirm('File is read only. Attempt to open in Perforce?', "&Yes\n&No", 1, 'Question') == 1
  if l:ok
    let l:res = perforce#P4CallEdit()
    " We need to redraw in case of an error, to dismiss the
    " W10 warning 'editing a read-only file'.
    if !res
      redraw
    endif
  endif
endfunction

function! perforce#P4CallEdit()
  let l:output = s:P4ShellCurrentBuffer('edit')
  if s:P4OutputHasError(l:output) == 1
    return 1
  endif
  if v:shell_error
    call s:err('Unable to open file for edit.', l:output)
    return 1
  endif
  silent! setlocal noreadonly autoread modifiable
  call s:msg('File open for edit.')
endfunction

function! perforce#P4CallRevert()
  let l:output = s:P4ShellCurrentBuffer('diff -f -sa')
  if s:P4OutputHasError(l:output) == 1
    return 1
  endif
  " If the file hasn't changed (no output), don't ask for confirmation
  if empty(l:output) && !&modified
    let l:do_revert = 1
  else
    let l:do_revert = confirm('Revert this file in Perforce and lose all changes?', "&Yes\n&No", 2, 'Question') == 1
  endif
  if !l:do_revert
    return
  endif
  let l:output = s:P4ShellCurrentBuffer('revert')
  if s:P4OutputHasError(l:output) == 1
    return 1
  elseif v:shell_error
    call s:err('Unable to revert file.', l:output)
    return 1
  else
    call s:msg('File reverted.')
    silent! e!
  endif
endfunction

function! perforce#P4GetUserPendingChangelists()
  let l:user = perforce#P4GetUser()
  if !empty(user)
    let l:output = s:P4Shell('changes -s pending -u ' . l:user)
    if v:shell_error
      return ''
    endif
    return l:output
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
  let l:user = perforce#P4GetUser()
  if empty(l:user)
    call s:warn('Unable to retrieve P4 user')
    return
  endif
  let l:user_cls = perforce#P4GetUserPendingChangelists()
  if empty(l:user_cls)
    bdelete!
    call s:err('Unable to retrieve list of pending changelists.')
    return 1
  endif
  " Create temp buffer
  if exists("t:p4sbuf") && bufwinnr(t:p4sbuf) > 0
    execute "keepjumps " . bufwinnr(t:p4sbuf) . "wincmd W"
    execute 'normal ggdG'
  else
    silent! belowright new 'Move to changelist'
    silent! resize 10
    silent! setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nonumber
    let t:p4sbuf=bufnr('%')
  end
  nnoremap <buffer> <silent> q      : <C-U>bdelete!<CR>
  nnoremap <buffer> <silent> <esc>  : <C-U>bdelete!<CR>
  nnoremap <buffer> <silent> <CR>   : exe perforce#P4ConfirmMoveToChangelist(getline('.')) <CR>
  " Populate buffer with existing Changelists
  execute "normal! GiNew changelist\<cr>default\<cr>" . l:user_cls . "\<esc>ddgg2gg"
  silent! setlocal nowrite autoread nomodifiable
endfunction

function! perforce#P4ConfirmMoveToChangelist(changelist_str)
  " We have the P4 CL, now parse the CL number and close the temp buffer
  if exists("t:p4sbuf") && bufwinnr(t:p4sbuf) > 0
    bdelete!
  endif
  let l:target_cl = ""
  if a:changelist_str == "default"
    let l:target_cl = 'default'
  elseif a:changelist_str == "New changelist"
    call inputsave()
    let l:new_cl_description = input('Enter new Changelist name: ')
    call inputrestore()
    redraw
    if empty(l:new_cl_description)
      call s:warn('No changelist description entered, aborting.')
      return
    endif
    let target_cl = perforce#P4CreateChangelist(l:new_cl_description)
  else
    let l:m = matchlist(a:changelist_str, "Change \\([0-9]\\+\\) .*")
    if len(l:m) > 1 && !empty(l:m[1])
      let target_cl = l:m[1]
    endif
  endif
  if !empty(l:target_cl)
    call perforce#P4CallMoveToChangelist(l:target_cl)
  endif
endfunction

function! perforce#P4CallMoveToChangelist(changelist)
  " read-only files haven't been opened yet
  if &readonly
    let l:output = s:P4ShellCurrentBuffer('edit -c ' . a:changelist)
  else
    let l:output = s:P4ShellCurrentBuffer('reopen -c ' . a:changelist)
  endif
  if v:shell_error
    call s:err('Unable to move file to Changelist ' . a:changelist)
    return 1
  endif
  silent! setlocal noreadonly modifiable
endfunction

function! perforce#P4CreateChangelist(description)
  let l:tmp = s:P4Shell('change -o')
  " Insert description, and remove existing files, since by default p4 adds
  " all existing files in the default CL to the new CL
  let l:new_cl_data = substitute(l:tmp, '<enter description here>', a:description, 'g')
  let l:new_cl_data = substitute(l:new_cl_data, 'Files:\n\(\s\+[^\n]*\n\)\+\n', '', '')
  let l:res = s:P4Shell('change -i', l:new_cl_data)
  if v:shell_error
    call s:err('Error creating new changelist.')
    return ''
  endif
  let l:new_cl = matchlist(l:res, 'Change \([0-9]\+\) created\.')
  if len(l:new_cl) > 1 && !empty(l:new_cl[1])
    call s:msg('Changelist ' . l:new_cl[1] . ' created.')
    return l:new_cl[1]
  endif
  return ''
endfunction
