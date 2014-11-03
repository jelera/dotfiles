#!/bin/bash
###############################################################################
#         Name: init.sh
#        Usage: ./init.sh
#
#  Description: Simple script to autocreate the symlinks for my dotfiles and
#               copy some helper programs to /usr/local/bin
#
# Last Updated: Mon 03 Nov 2014 12:59:15 PM CST
#
#    Tested on: Ubuntu 14.04 LTS Trusty Tahr
#               CentOS 7 / Red Hat Enterprise Linux 7
#               Mac OS X Mountain Lion
#
#   Maintainer: Jose Elera (https://github.com/jelera)
#
#      License: MIT
#               Copyright (c) 2014 Jose Elera Campana
#
#               Permission is hereby granted, free of charge, to any person
#               obtaining a copy of this software and associated documentation
#               files (the "Software"), to deal in the Software without
#               restriction, including without limitation the rights to use,
#               copy, modify, merge, publish, distribute, sublicense, and/or
#               sell copies of the Software, and to permit persons to whom the
#               Software is furnished to do so, subject to the following
#               conditions:
#
#               The above copyright notice and this permission notice shall be
#               included in all copies or substantial portions of the Software.
#
#               THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#               EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
#               OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#               NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
#               HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#               WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#               FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#               OTHER DEALINGS IN THE SOFTWARE.
###############################################################################

##---------------------------------------------------------------------------//
##
## => HELPER FUNCTIONS
##
##---------------------------------------------------------------------------//
function color_echo(){
	# Usage  : color_echo "string" color
	# Credit : http://stackoverflow.com/a/23006365/428786
	local exp=$1;
	local color=$2;
	if ! [[ $color =~ '^[0-9]$' ]] ; then
		case $(echo $color | tr '[:upper:]' '[:lower:]') in
			black) color=0 ;;
			red) color=1 ;;
			green) color=2 ;;
			yellow) color=3 ;;
			blue) color=4 ;;
			magenta) color=5 ;;
			cyan) color=6 ;;
			white|*) color=7 ;; # white or invalid color
		esac
	fi
	tput setaf $color;
	echo $exp
	tput sgr0;
}


color_echo "#######" green
color_echo "init.sh" green
color_echo "#######" green
echo
color_echo "MAKE SURE, YOU CLONE THIS GIT REPO" red
color_echo "INSIDE THE ~/.config DIRECTORY" red
sleep 2


##---------------------------------------------------------------------------//
##
## => BACKUP OLD DOTFILES
##
##---------------------------------------------------------------------------//
echo
color_echo "Backup the old dotfiles (up to 2 times) ..." cyan
if [ -d ~/.old.dotfiles ]; then
	if [ -d /tmp/old.dotfiles ]; then
		rm -rf /tmp/old.dotfiles
	fi
	mv -f ~/.old.dotfiles /tmp/old.dotfiles
fi
mkdir -p ~/.old.dotfiles

if [[ -f ~/.profile || -L ~/.profile ]]; then
	mv -f ~/.profile ~/.old.dotfiles
fi
if [[ -f ~/.bashrc || -L ~/.bashrc ]]; then
	mv -f ~/.bashrc ~/.old.dotfiles
fi
if [[ -f ~/.zshrc || -L ~/.zshrc ]]; then
	mv -f ~/.zshrc ~/.old.dotfiles
fi
if [[ -f ~/.gitconfig || -L ~/.gitconfig ]]; then
	mv -f ~/.gitconfig ~/.old.dotfiles
fi
if [[ -f ~/.gitignore_global || -L ~/.gitignore_global ]]; then
	mv -f ~/.gitignore_global ~/.old.dotfiles
fi
if [[ -f ~/.tmux.conf || -L ~/.tmux.conf ]]; then
	mv -f ~/.tmux.conf ~/.old.dotfiles
fi
if [[ -f ~/.vimrc || -L ~/.vimrc ]]; then
	mv -f ~/.vimrc ~/.old.dotfiles
fi
if [[ -d ~/.vim || -L ~/.vim ]]; then
	mv -f ~/.vim ~/.old.dotfiles
fi
if [[ -d ~/.bin || -L ~/.bin ]]; then
	mv -f ~/.bin ~/.old.dotfiles
fi
if [[ -d ~/.oh-my-zsh || -L ~/.oh-my-zsh ]]; then
	mv -f ~/.oh-my-zsh ~/.old.dotfiles
fi

echo
color_echo "You can find them at ~/.old.dotfiles" cyan
sleep 1.5


##---------------------------------------------------------------------------//
##
## => INSTALL OH-MY-ZSH
##
##---------------------------------------------------------------------------//
echo
color_echo "Installing oh-my-zsh ..." cyan
git clone git://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
sleep 1


##---------------------------------------------------------------------------//
##
## => CREATING THE SYMLINKS
##
##---------------------------------------------------------------------------//
echo
color_echo "Creating the Symlinks ..." cyan
ln -s $HOME/.config/dotfiles/bin               $HOME/.bin
ln -s $HOME/.config/dotfiles/bash/bashrc       $HOME/.bashrc
ln -s $HOME/.config/dotfiles/bash/bash_profile $HOME/.profile

ln -s $HOME/.config/dotfiles/gitconfig/gitconfig  $HOME/.gitconfig
ln -s $HOME/.config/dotfiles/gitconfig/gitignore  $HOME/.gitignore_global

ln -s $HOME/.config/dotfiles/tmux/tmux.conf    $HOME/.tmux.conf

ln -s $HOME/.config/dotfiles/zsh/zshrc         $HOME/.zshrc
sleep 1


##---------------------------------------------------------------------------//
##
## => SETTING UP VIM
##
##---------------------------------------------------------------------------//
echo
color_echo "Checking if dotvim repo is installed..." cyan
color_echo "If it is... it will be moved to .old.dotfiles dir" red
sleep 2
if [[ -d ~/.config/dotfiles/vim || -L ~/.config/dotfiles/vim ]]; then
	mv -f ~/.config/dotfiles/vim ~/.old.dotfiles
fi

color_echo "Setting up Vim ..." cyan
# Cloning my dotvim repo and create the symlinks
git clone git@github.com:jelera/vimconfig.git ~/.config/dotfiles/vim
ln -s $HOME/.config/dotfiles/vim     $HOME/.vim

# Making the directories for backup, swap and undo
echo
color_echo "Making directories within .vim for backup, swap and undo ..." cyan
mkdir -p ~/.vim/.cache
mkdir -p ~/.vim/.cache/backup
mkdir -p ~/.vim/.cache/swap
mkdir -p ~/.vim/.cache/undo
mkdir -p ~/.vim/.cache/unite
mkdir -p ~/.vim/.cache/junk

# Install Neobundle
echo
color_echo "Installing Neobundle for managing Vim Plugins ..." cyan
mkdir -p ~/.vim/bundle
git clone https://github.com/Shougo/neobundle.vim ~/.vim/bundle/neobundle.vim
sleep 1


##---------------------------------------------------------------------------//
##
## => COPYING THE HELPER PROGRAMS TO /usr/local/bin
##
##---------------------------------------------------------------------------//
echo
color_echo "Copying helper programs to /usr/local/bin/  ..." cyan

# This script is needed for advanced tmux vim integration
# Tested with Ubuntu Linux 14.04 LTS / CentOS 7 / RHEL 7
sudo cp $HOME/.config/dotfiles/bin/tmux-vim-select-pane /usr/local/bin/

# xcape adds extra remap to single keypress
sudo cp $HOME/.config/dotfiles/bin/xcape /usr/local/bin/

# vcprompt displays the current working VCS branch (git/hg)
sudo cp $HOME/.config/dotfiles/bin/vcprompt /usr/local/bin/
sleep 1

echo
color_echo "#####################################################" green
color_echo "Finished making the symlinks and cloning my vim setup" green
color_echo "#####################################################" green
