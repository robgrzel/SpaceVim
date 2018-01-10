"=============================================================================
" iedit.vim --- iedit mode for SpaceVim
" Copyright (c) 2016-2017 Shidong Wang & Contributors
" Author: Shidong Wang < wsdjeg at 163.com >
" URL: https://spacevim.org
" License: MIT license
"=============================================================================

let s:stack = []
let s:index = -1
let s:cursor_col = -1
let s:mode = ''
let s:hi_id = ''

" prompt

let s:symbol_begin = ''
let s:symbol_cursor = ''
let s:symbol_end = ''

let s:VIMH = SpaceVim#api#import('vim#highlight')
let s:STRING = SpaceVim#api#import('data#string')

let s:cursor_stack = []


function! s:highlight_cursor() abort
  let info = {
        \ 'name' : 'SpaceVimGuideCursor',
        \ 'guibg' : synIDattr(synIDtrans(synID(line('.'), col('.'), 1)), 'guifg'),
        \ 'guifg' : synIDattr(synIDtrans(synID(line('.'), col('.'), 1)), 'guibg'),
        \ 'ctermbg' : synIDattr(synIDtrans(synID(line('.'), col('.'), 1)), 'ctermfg'),
        \ 'ctermfg' : synIDattr(synIDtrans(synID(line('.'), col('.'), 1)), 'ctermbg'),
        \ }
  hi def link SpaceVimGuideCursor Cursor
  call s:VIMH.hi(info)
  let s:cursor_hi = matchaddpos('SpaceVimGuideCursor', s:cursor_stack) 
endfunction

function! s:remove_cursor_highlight() abort
  try
    call matchdelete(s:cursor_hi)
  catch
  endtry
endfunction

function! SpaceVim#plugins#iedit#start(...)
  let save_tve = &t_ve
  setlocal t_ve=
  let s:mode = 'n'
  let w:spacevim_iedit_mode = s:mode
  let w:spacevim_statusline_mode = 'in'
  let begin = get(a:000, 0, 1)
  let end = get(a:000, 1, line('$'))
  let symbol = expand('<cword>')
  call s:parse_symbol(begin, end, symbol)
  call s:highlight_cursor()
  redrawstatus!
  while 1
    let char = getchar()
    redraw!
    if s:mode ==# 'n' && char == 27
      break
    endif
    call s:handle(s:mode, char)
  endwhile
  let s:stack = []
  let s:cursor_stack = []
  let s:index = -1
  let s:mode = ''
  let w:spacevim_iedit_mode = s:mode
  let w:spacevim_statusline_mode = 'in'
  let &t_ve = save_tve
  call s:remove_cursor_highlight()
  try
    call matchdelete(s:hi_id)
  catch
  endtry
  let s:hi_id = ''
endfunction


function! s:handle(mode, char) abort
  if a:mode ==# 'n'
    call s:handle_normal(a:char)
  elseif a:mode ==# 'i'
    call s:handle_insert(a:char)
  endif
endfunction


function! s:handle_normal(char) abort
  if a:char ==# 105
    let s:mode = 'i'
    let w:spacevim_iedit_mode = s:mode
    let w:spacevim_statusline_mode = 'ii'
    redrawstatus!
  elseif a:char == 97
    silent! call s:remove_cursor_highlight()
    let s:mode = 'i'
    let w:spacevim_iedit_mode = s:mode
    let w:spacevim_statusline_mode = 'ii'
    let s:symbol_begin = s:symbol_begin . s:symbol_cursor
    if !empty(s:symbol_cursor)
      noautocmd normal! l
    endif
    let s:symbol_cursor = matchstr(s:symbol_end, '^.')
    let s:symbol_end = substitute(s:symbol_end, '^.', '', 'g')
    silent! call s:highlight_cursor()
    redrawstatus!
  endif
endfunction

function! s:handle_insert(char) abort
  silent! call s:remove_cursor_highlight()
  if a:char == 27
    let s:mode = 'n'
    let w:spacevim_iedit_mode = s:mode
    let w:spacevim_statusline_mode = 'in'
    silent! call s:highlight_cursor()
    redraw!
    redrawstatus!
    return
  elseif a:char == 23
    exe 'noautocmd normal! ' . len(s:symbol_begin) . 'h'
    let s:symbol_begin = ''
  elseif a:char == 11
    exe 'noautocmd normal! ' . (len(s:symbol_cursor) + len(s:symbol_end)) . 'l'
    let s:symbol_cursor = ''
    let s:symbol_end = ''
  else
    noautocmd normal! l
    let s:symbol_begin .=  nr2char(a:char)
  endif
  call s:replace_symbol(s:symbol_begin . s:symbol_cursor . s:symbol_end)
  silent! call s:highlight_cursor()
endfunction

function! s:parse_symbol(begin, end, symbol) abort
  let len = len(a:symbol)
  let cursor = [line('.'), col('.')]
  for l in range(a:begin, a:end)
    let line = getline(l)
    let idx = s:STRING.strAllIndex(line, a:symbol)
    for pos_c in idx
      call add(s:stack, [l, pos_c + 1, len])
      call add(s:cursor_stack, [l, cursor[1], 1])
      if l == cursor[0] && pos_c <= cursor[1] && pos_c + len >= cursor[1]
        let s:index = len(s:stack) - 1
        let s:symbol_begin = line[pos_c : cursor[1] - 1]
        let s:symbol_cursor = line[ cursor[1] - 1 : cursor[1] - 1]
        let s:symbol_end = line[ cursor[1] : pos_c + len]
      endif
    endfor
  endfor
  let s:hi_id = matchaddpos('Underlined', s:stack)
endfunction

function! s:replace_symbol(symbol) abort
  call matchdelete(s:hi_id)
  let len = len(s:stack)
  for idx in range(len)
    let pos = s:stack[len-1-idx]
    let line = getline(pos[0])
    let begin = line[:pos[1]]
    let end = line[pos[1] + pos[2]:]
    let line = begin . a:symbol . end
    call setline(pos[0], line)
    let s:stack[len-1-idx][2] = len(a:symbol)
  endfor
  let s:hi_id = matchaddpos('Underlined', s:stack)
endfunction