# perforce.vim

Vim Perforce integration for the 21st century!

No relation to [Tom Slee's](http://www.vim.org/scripts/script.php?script_id=167) or [Hari Krishna Dara's](http://vim.sourceforge.net/scripts/script.php?script_id=240) plugins.


## Installation

Vundle is the recommended way to install vim-perforce. Add this line to your .vimrc:

    Bundle 'nfvs/vim-perforce'

Then run `:PluginInstall` inside Vim.


## Usage

By default, when trying to save a read-only file, a prompt to open the file for edit in Perforce is displayed.

Additionally, the following commands are available:

##### :P4info
Display perforce information.

##### :P4edit
Start editing the current file (opened in the default changelist).

##### :P4revert
Revert the current file (a confirmation prompt is displayed).

##### :P4movetocl
Move the current file to a different changelist.


## Settings

The following settings can be set in your `.vimrc` file:

##### g:perforce\_open\_on\_change _(default: 0)_
Prompt to open the file for edit in Perforce when starting to modify a read-only file.

##### g:perforce\_open\_on\_save _(default: 1)_
Prompt to open the file for edit in Perforce when trying to write a read-only file (with :w!).

##### g:perforce\_auto\_source\_dirs _(default: [])_
Restrict Perforce automatic operations (save/change read-only files) to a limited set of directories. Please note that on Windows backslashes need to be escaped. Example:

`let g:perforce_auto_source_dirs = ['C:\\Users\\nfvs\\Perforce']`

##### g:perforce\_use\_relative\_paths _(default: 0)_
Send relative file paths to Perforce so it can automatically detect which root to use (useful when sharing a Perforce repository between Linux and Windows or when using Cygwin).


## License

Copyright (C) 2015 Nuno Santos. Distributed under the same terms as Vim itself. See `:help license`.
