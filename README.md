# perforce.vim

Vim Perforce integration for the 21st century!

No relation to [Tom Slee's](http://www.vim.org/scripts/script.php?script_id=167) or [Hari Krishna Dara's](http://vim.sourceforge.net/scripts/script.php?script_id=240) plugins.

## Installation

Vundle is the recommended way to install vim-perforce. Add this line to your .vimrc:

    Bundle 'nfvs/vim-perforce'

Then run `:PluginInstall` inside Vim.

## Usage

When trying to modify a read-only file, a prompt will appear to open the file in Perforce. The file will be opened in the default changelist.

Available commands:

 * `:P4Info` -- Display perforce information
 * `:P4Edit` -- Start editing the current file (opened in the default changelist)
 * `:P4Revert` -- Revert the current file
 * `:P4MoveToChangelist` -- Move the current file to a different changelist

## License

Copyright (C) Nuno Santos. Distributed under the same terms as Vim itself. See `:help license`.
